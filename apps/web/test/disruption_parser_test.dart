import 'package:flutter_test/flutter_test.dart';
import 'package:navi_web/engine/demo_network.dart';
import 'package:navi_web/models/disruption.dart';
import 'package:navi_web/models/route_models.dart';
import 'package:navi_web/models/signals.dart';
import 'package:navi_web/engine/signal_mapper.dart';

void main() {
  final parser = DisruptionParser(lines: DemoNetwork.lines, knownStations: DemoNetwork.stations);
  Disruption? p(String s) => parser.parse(s, nowMinutes: 480);

  test('colour names map to lines with a default delay', () {
    final d = p('Red line delayed')!;
    expect(d.lineId, 'NSL');
    expect(d.kind, DisruptionKind.delay);
    expect(d.delayMinutes, 15);
    expect(p('green line closed')!.lineId, 'EWL');
    expect(p('orange line delayed')!.lineId, 'CCL');
    expect(p('yellow line delayed')!.lineId, 'CCL');
    expect(p('blue line')!.lineId, 'DTL');
    expect(p('purple line closed')!.lineId, 'NEL');
    expect(p('brown line delayed')!.lineId, 'TEL');
  });

  test('line names, ids and station segments are recognised', () {
    final d = p('Green line closed between Tampines and Bedok')!;
    expect(d.lineId, 'EWL');
    expect(d.kind, DisruptionKind.closure);
    expect(d.stations, ['Tampines', 'Bedok']);
    expect(p('NSL suspended')!.kind, DisruptionKind.closure);
    expect(p('north-south line 8 minutes late')!.delayMinutes, 8);
    expect(p('East-West Line breakdown')!.lineId, 'EWL');
  });

  test('buses, weather, crowding and nonsense', () {
    final bus = p('bus 10 delayed 8 min')!;
    expect(bus.serviceNo, '10');
    expect(bus.lineId, isNull);
    expect(bus.delayMinutes, 8);
    expect(p('service 291 not running')!.kind, DisruptionKind.closure);
    expect(p('heavy rain')!.kind, DisruptionKind.weather);
    expect(p('Circle line crowded')!.kind, DisruptionKind.crowding);
    expect(p('hello there'), isNull);
    expect(p(''), isNull);
  });

  test('relevance uses stops when a segment is given', () {
    final d = p('green line closed between Eunos and Paya Lebar')!;
    const short = RouteLeg(
      mode: LegMode.rail, lineId: 'EWL', from: 'Tampines', to: 'Bedok',
      stops: ['Tampines', 'Simei', 'Tanah Merah', 'Bedok'], minutes: 10,
    );
    const long = RouteLeg(
      mode: LegMode.rail, lineId: 'EWL', from: 'Tampines', to: 'Paya Lebar',
      stops: ['Tampines', 'Bedok', 'Eunos', 'Paya Lebar'], minutes: 14,
    );
    expect(d.affects(short), isFalse);
    expect(d.affects(long), isTrue);
    expect(p('heavy rain')!.affects(const RouteLeg(mode: LegMode.walk, from: 'a', to: 'b', minutes: 3)), isTrue);
  });

  test('child signals map to urgency and plain reassurance', () {
    const s = ChildSignal(kind: ChildSignalKind.scared, atMinutes: 500, stageLabel: 'waiting at Tampines', locationLabel: 'Tampines station');
    final a = SignalMapper.map(s, id: 'x');
    expect(a.urgency, Urgency.critical);
    expect(a.title, contains('unsafe'));
    expect(a.detail, contains('waiting at Tampines'));
    expect(a.childReassurance, contains('Mum has been told'));
    expect(a.suggestedActions.first, startsWith('Call'));
    expect(SignalMapper.map(const ChildSignal(kind: ChildSignalKind.checkIn, atMinutes: 1, stageLabel: 's', locationLabel: 'l'), id: 'y').urgency, Urgency.normal);
  });
}
