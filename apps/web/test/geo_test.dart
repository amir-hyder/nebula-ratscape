import 'package:flutter_test/flutter_test.dart';
import 'package:navi_web/engine/demo_network.dart';
import 'package:navi_web/engine/geo.dart';
import 'package:navi_web/models/route_models.dart';

void main() {
  test('distance, bearing and interpolation', () {
    const a = LatLng(1.3530, 103.9450);
    const b = LatLng(1.3530, 103.9550); // ~1.1 km east
    expect(Geo.distanceM(a, b), closeTo(1112, 15));
    expect(Geo.bearingDeg(a, b), closeTo(90, 0.5));
    final pts = [a, b];
    final cum = Geo.cumulative(pts);
    final mid = Geo.pointAt(pts, cum, cum.last / 2);
    expect(mid.lon, closeTo(103.95, 1e-6));
    expect(Geo.turnDeg(350, 10), 20);
    expect(Geo.turnDeg(10, 350), -20);
  });

  test('guidance announces the next bend with distance', () {
    // North 100 m, then east 100 m, then north again.
    const pts = [LatLng(1.3500, 103.9000), LatLng(1.3509, 103.9000), LatLng(1.3509, 103.9009), LatLng(1.3518, 103.9009)];
    final cum = Geo.cumulative(pts);
    final g = Guidance.next(pts, cum, 20);
    expect(g.kind, TurnKind.right);
    expect(g.distanceM, closeTo(80, 3));
    final g2 = Guidance.next(pts, cum, 120);
    expect(g2.kind, TurnKind.left);
    final end = Guidance.next(pts, cum, 250);
    expect(end.kind, TurnKind.arrive);
    expect(Guidance.next(pts, cum, 0).kind, TurnKind.start);
  });

  test('fixtures are hydrated with geometry so the watch can navigate offline', () {
    final c = DemoNetwork.hydrate(DemoNetwork.candidatesFor('school').first);
    expect(c.legs.every((l) => l.hasGeometry), isTrue);
    expect(c.legs.first.points.length, greaterThanOrEqualTo(3));
    expect(c.legs[1].points.length, 4); // 4 bus stops
  });

  test('OneMap JSON becomes a RouteCandidate', () {
    final c = RouteCandidate.fromJson({
      'id': 'onemap-transit-0-abc',
      'source': 'onemap',
      'legs': [
        {'mode': 'walk', 'from': 'Origin', 'to': 'Tampines', 'minutes': 2, 'points': [[1.353, 103.945], [1.3533, 103.9452]], 'steps': [{'direction': 'DEPART', 'street': 'Tampines Central 1', 'distanceM': 100, 'lat': 1.353, 'lon': 103.945}], 'fromLatLon': [1.353, 103.945], 'toLatLon': [1.3533, 103.9452]},
        {'mode': 'rail', 'lineId': 'EWL', 'from': 'Tampines', 'to': 'City Hall', 'minutes': 26, 'waitMinutes': 3, 'stops': ['Tampines', 'Simei', 'City Hall'], 'stopCodes': ['EW2', 'EW3', 'EW13'], 'points': [[1.3533, 103.9452], [1.2931, 103.8520]]},
        {'mode': 'bus', 'serviceNo': '13', 'from': 'A', 'to': 'B', 'minutes': 5, 'stops': ['A', 'B'], 'stopCodes': ['66069', null], 'points': []},
      ],
    }, destinationId: 'grandma');
    expect(c.live, isTrue);
    expect(c.legs[1].lineId, 'EWL');
    expect(c.legs[1].boardingStopCode, 'EW2');
    expect(c.legs[2].serviceNo, '13');
    expect(c.legs.first.steps.first.street, 'Tampines Central 1');
    expect(c.totalMinutes, 36);
    expect(c.transfers, 1);
  });
}
