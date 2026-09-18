import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:navi_web/demo_store.dart';
import 'package:navi_web/main.dart';

void main() {
  test('child actions update the parent-facing journey and events', () {
    final store = DemoStore();
    expect(store.phase, JourneyPhase.idle);
    expect(store.events, isEmpty);

    store.start();
    expect(store.statusLabel, 'On the way');
    expect(store.events.first.type, 'started');

    store.showReroute();
    expect(store.routeChanged, isTrue);
    expect(store.events.first.type, 'route');

    store.setPhase(JourneyPhase.reaching, ChildScreen.reaching);
    store.offVehicle();
    expect(store.phase, JourneyPhase.finalWalk);
    expect(store.events.any((event) => event.type == 'arrived'), isFalse);

    store.confirmArrival();
    expect(store.phase, JourneyPhase.arrived);
    expect(store.events.first.type, 'arrived');
    store.dispose();
  });

  testWidgets('combined demo shares the child start with parent status', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1200, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(const NaviApp());
    await tester.tap(find.text('Combined demo'));
    await tester.pumpAndSettle();
    expect(find.text('Maya has no active journey'), findsOneWidget);

    await tester.tap(find.text('Start Journey'));
    await tester.pumpAndSettle();
    expect(find.text('On the way'), findsOneWidget);
    expect(find.text('Walk to stop'), findsOneWidget);
  });
}
