import 'package:flutter_test/flutter_test.dart';
import 'package:navi_web/engine/geo.dart';
import 'package:navi_web/models/conditions.dart';
import 'package:navi_web/models/signals.dart';
import 'package:navi_web/engine/signal_mapper.dart';

void main() {
  test('weather nowcast maps to child wording and rain flag', () {
    final dry = WeatherNow.fromJson({'area': 'Tampines', 'forecast': 'Partly Cloudy (Day)', 'rainfallMm': 0, 'raining': false, 'heavy': false, 'advice': 'Dry', 'validPeriod': '4 pm to 6 pm'});
    expect(dry.raining, isFalse);
    expect(dry.childLine, 'Partly Cloudy (Day) in Tampines.');
    final wet = WeatherNow.fromJson({'area': 'Bedok', 'forecast': 'Thundery Showers', 'rainfallMm': 6.2, 'raining': true, 'heavy': true, 'advice': 'Heavy'});
    expect(wet.heavy, isTrue);
    expect(wet.childLine, contains('Umbrella'));
    expect(wet.emoji, '⛈️');
  });

  test('crowd levels parse from both LTA codes and words, never colour alone', () {
    expect(CrowdLevelX.parse('h'), CrowdLevel.high);
    expect(CrowdLevelX.parse('moderate'), CrowdLevel.moderate);
    expect(CrowdLevelX.parse(null), CrowdLevel.unknown);
    expect(CrowdLevel.high.word, 'Very crowded');
    const c = StationCrowding(lineId: 'EWL', levels: {'EW2': CrowdLevel.high}, fetchedAt: '');
    expect(c.at('EW2'), CrowdLevel.high);
    expect(c.at('EW3'), CrowdLevel.unknown);
  });

  test('OSM features carry kind, glyph and distance', () {
    final f = OsmFeature.fromJson({'kind': 'crossing', 'label': 'Zebra crossing', 'lat': 1.35, 'lon': 103.94});
    expect(f.emoji, '🚸');
    expect(f.at, const LatLng(1.35, 103.94));
    final s = OsmFeature.fromJson({'kind': 'police', 'label': 'Police post', 'name': 'Tampines NPC', 'lat': 1.35, 'lon': 103.94, 'distanceM': 210});
    expect(s.distanceM, 210);
    expect(s.emoji, '👮');
  });

  test('a nearby safe place is added to the child reassurance', () {
    final alert = SignalMapper.map(
      const ChildSignal(kind: ChildSignalKind.scared, atMinutes: 1, stageLabel: 'waiting', locationLabel: 'stop'),
      id: 'a',
    );
    expect(alert.childReassuranceLive, alert.childReassurance);
    alert.safePlace = const OsmFeature(kind: 'convenience', label: 'Convenience store', name: '7-Eleven', at: LatLng(1, 2), distanceM: 84);
    expect(alert.childReassuranceLive, contains('Go to 7-Eleven (84 m)'));
  });
}
