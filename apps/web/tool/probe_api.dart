// ignore_for_file: avoid_print
// Dev probe: dart run tool/probe_api.dart  (backend must be running)
import 'package:navi_web/engine/geo.dart';
import 'package:navi_web/services/navi_api.dart';

Future<void> main() async {
  final api = NaviApi();
  final sw = Stopwatch()..start();
  print('health: ${await api.health()} (${sw.elapsedMilliseconds} ms)');
  final routes = await api.routes(
    origin: const LatLng(1.3530, 103.9450),
    destination: const LatLng(1.3516, 103.9491),
    destinationId: 'school',
    departMinutes: 7 * 60,
  );
  print('routes: ${routes.length} in ${sw.elapsedMilliseconds} ms');
  for (final r in routes) {
    print('  ${r.id} ${r.summary} ${r.totalMinutes} min pts=${r.legs.map((l) => l.points.length).toList()} steps=${r.legs.map((l) => l.steps.length).toList()}');
  }
}
