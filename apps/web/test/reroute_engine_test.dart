import 'package:flutter_test/flutter_test.dart';
import 'package:navi_web/engine/demo_network.dart';
import 'package:navi_web/engine/reroute_engine.dart';
import 'package:navi_web/models/disruption.dart';
import 'package:navi_web/models/route_models.dart';

void main() {
  const engine = RerouteEngine();
  final parser = DisruptionParser(lines: DemoNetwork.lines, knownStations: DemoNetwork.stations);
  Disruption d(String text) => parser.parse(text, nowMinutes: 9 * 60)!;

  RerouteDecision run({
    required String dest,
    required String route,
    required String text,
    JourneyPosition position = const JourneyPosition(legIndex: 0, aboard: false, started: false),
    List<Disruption> others = const [],
    int now = 9 * 60,
    int required = 10 * 60,
    int buffer = 10,
  }) {
    final candidates = DemoNetwork.candidatesFor(dest);
    final r = candidates.firstWhere((c) => c.id == route);
    final dis = d(text);
    return engine.evaluate(
      route: r,
      candidates: candidates,
      disruption: dis,
      active: [...others, dis],
      position: position,
      nowMinutes: now,
      requiredArrivalMinutes: required,
      bufferMinutes: buffer,
    );
  }

  group('relevance', () {
    test('a line the route does not use changes nothing', () {
      final r = run(dest: 'school', route: 'school-bus10', text: 'red line delayed');
      expect(r.action, DecisionAction.keep);
    });

    test('a segment outside the remaining journey is ignored', () {
      final r = run(dest: 'tuition', route: 'tuition-ewl', text: 'green line closed between Eunos and Paya Lebar');
      expect(r.action, DecisionAction.keep);
    });

    test('a small delay is suppressed, not alerted', () {
      final r = run(dest: 'school', route: 'school-bus10', text: 'bus 10 delayed 3 min');
      expect(r.action, DecisionAction.info);
      expect(r.childTitle, isEmpty);
    });

    test('weather and crowding only inform', () {
      expect(run(dest: 'school', route: 'school-bus10', text: 'heavy rain').action, DecisionAction.info);
      expect(run(dest: 'grandma', route: 'grandma-rail', text: 'circle line crowded').action, DecisionAction.info);
    });
  });

  group('rerouting', () {
    test('red line delay before leaving swaps the last rail leg for a bus', () {
      final r = run(dest: 'grandma', route: 'grandma-rail', text: 'red line delayed');
      expect(r.action, DecisionAction.reroute);
      expect(r.alternative!.id, 'grandma-rail-bus88');
      expect(r.affectedLegIndex, 3);
      expect(r.childMessage, contains('Then Bus 88 to Ang Mo Kio Int'));
    });

    test('aboard the Circle line, only routes sharing the ridden legs are actionable', () {
      final r = run(
        dest: 'grandma',
        route: 'grandma-rail',
        text: 'red line closed',
        position: const JourneyPosition(legIndex: 2, aboard: true, started: true),
      );
      expect(r.action, DecisionAction.reroute);
      expect(r.alternative!.id, 'grandma-rail-bus88');
      expect(r.rejected.map((x) => x.candidate.id), contains('grandma-bus22'));
      expect(r.childMessage, contains('Bus 88'));
    });

    test('aboard the affected train: closure holds, delay stays', () {
      final hold = run(
        dest: 'grandma',
        route: 'grandma-rail',
        text: 'red line closed',
        position: const JourneyPosition(legIndex: 3, aboard: true, started: true),
      );
      expect(hold.action, DecisionAction.holdAboard);
      expect(hold.childMessage, contains('next station'));
      final stay = run(
        dest: 'grandma',
        route: 'grandma-rail',
        text: 'red line delayed 12 min',
        position: const JourneyPosition(legIndex: 3, aboard: true, started: true),
      );
      expect(stay.action, DecisionAction.delay);
      expect(stay.addedMinutes, 12);
    });

    test('green line closure removes both rail options and picks the direct bus', () {
      final r = run(dest: 'grandma', route: 'grandma-rail', text: 'green line closed');
      expect(r.action, DecisionAction.reroute);
      expect(r.alternative!.id, 'grandma-bus22');
    });

    test('a walk over the child limit is rejected even though it avoids the disruption', () {
      final r = run(dest: 'school', route: 'school-bus10', text: 'bus 10 not running');
      expect(r.action, DecisionAction.reroute);
      expect(r.alternative!.id, 'school-bus291');
      final walk = r.rejected.firstWhere((x) => x.candidate.id == 'school-walk');
      expect(walk.why, contains('19 min'));
    });

    test('relaxed limits let the walk win when it is quicker', () {
      const relaxed = RerouteEngine(limits: ChildLimits(maxWalkMinutesPerLeg: 25));
      final candidates = DemoNetwork.candidatesFor('school');
      final dis = d('bus 10 not running');
      final r = relaxed.evaluate(
        route: candidates.first,
        candidates: candidates,
        disruption: dis,
        active: [dis],
        position: const JourneyPosition(legIndex: 0, aboard: false, started: false),
        nowMinutes: 9 * 60,
        requiredArrivalMinutes: 10 * 60,
        bufferMinutes: 10,
      );
      expect(r.alternative!.id, 'school-walk');
    });
  });

  group('timing', () {
    test('delay with no alternative before leaving means leave earlier', () {
      final candidates = DemoNetwork.candidatesFor('tuition');
      final route = candidates.first; // 22 min
      const required = 16 * 60 + 30;
      const buffer = 10;
      const now = required - buffer - 22; // leaving right on time
      final r = run(
        dest: 'tuition',
        route: route.id,
        text: 'green line delayed 20 min',
        others: [d('bus 10 not running')],
        now: now,
        required: required,
        buffer: buffer,
      );
      expect(r.action, DecisionAction.leaveEarlier);
      expect(r.addedMinutes, 20);
      expect(r.childMessage, contains('20 minutes earlier'));
    });

    test('delay that fits inside the buffer just updates the arrival', () {
      final r = run(
        dest: 'tuition',
        route: 'tuition-ewl',
        text: 'green line delayed 6 min',
        others: [d('bus 10 not running')],
        now: 15 * 60,
        required: 16 * 60 + 30,
        position: const JourneyPosition(legIndex: 1, aboard: false, started: true),
      );
      expect(r.action, DecisionAction.delay);
      expect(r.parentMessage, contains('new estimated arrival'));
    });

    test('closure with nothing suitable escalates', () {
      final r = run(
        dest: 'tuition',
        route: 'tuition-ewl',
        text: 'green line closed',
        others: [d('bus 10 not running')],
        position: const JourneyPosition(legIndex: 1, aboard: false, started: true),
      );
      expect(r.action, DecisionAction.noRoute);
      expect(r.childMessage, contains('Mum has been told'));
    });
  });
}
