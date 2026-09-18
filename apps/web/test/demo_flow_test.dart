import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:navi_web/engine/reroute_engine.dart';
import 'package:navi_web/main.dart';
import 'package:navi_web/models/signals.dart';
import 'package:navi_web/state/demo_store.dart';

void main() {
  test('child actions update the parent-facing journey and events', () {
    final store = DemoStore();
    expect(store.phase, JourneyPhase.idle);
    expect(store.events, isEmpty);

    store.start();
    expect(store.statusLabel, 'On the way');
    expect(store.events.first.type, 'started');
    expect(store.parentPush, isNotNull);

    store.showReroute(); // bus 10 not running → bus 291
    expect(store.routeChanged, isTrue);
    expect(store.activeRoute.id, 'school-bus291');
    expect(store.originalRoute?.id, 'school-bus10');
    expect(store.events.first.type, 'route');
    expect(store.childScreen, ChildScreen.alert);

    store.dismissAlert();
    expect(store.childScreen, ChildScreen.walk);
    store.nextStep(); // at the stop
    expect(store.phase, JourneyPhase.waiting);
    store.nextStep(); // on the bus
    store.nextStep(); // reaching
    expect(store.phase, JourneyPhase.reaching);
    store.offVehicle();
    expect(store.phase, JourneyPhase.finalWalk);
    expect(store.events.any((event) => event.type == 'arrived'), isFalse);

    store.nextStep();
    expect(store.phase, JourneyPhase.awaitingConfirmation);
    store.confirmArrival();
    expect(store.phase, JourneyPhase.arrived);
    expect(store.events.first.type, 'arrived');
    store.dispose();
  });

  test('child signal becomes a parent alert and a reply reaches the watch', () {
    final store = DemoStore();
    store.start();
    store.requestHelp();
    expect(store.childScreen, ChildScreen.help);

    store.sendSignal(ChildSignalKind.scared);
    expect(store.childScreen, ChildScreen.helpSent);
    expect(store.helpRequested, isTrue);
    expect(store.alerts.first.urgency, Urgency.critical);
    expect(store.parentPush!.critical, isTrue);
    expect(store.events.first.type, 'help');
    expect(store.flow.any((f) => f.from == FlowActor.child && f.kind == FlowKind.signal), isTrue);
    expect(store.flow.any((f) => f.to == FlowActor.parent && f.kind == FlowKind.notification), isTrue);

    store.replyToChild('Stay there, I am coming 🚗');
    expect(store.childScreen, ChildScreen.message);
    expect(store.childMessages.first.text, contains('coming'));
    store.acknowledgeAlert(store.alerts.first);
    expect(store.helpRequested, isFalse);
    store.dispose();
  });

  test('typed disruption reroutes immediately and notifies the parent', () {
    final store = DemoStore();
    store.selectDestination('grandma');
    expect(store.activeRoute.id, 'grandma-rail');

    expect(store.applyDisruptionText('purple line closed'), isTrue);
    expect(store.routeChanged, isFalse); // irrelevant: NEL is not on the route

    expect(store.applyDisruptionText('red line delayed'), isTrue);
    expect(store.routeChanged, isTrue);
    expect(store.activeRoute.id, 'grandma-rail-bus88');
    expect(store.childScreen, ChildScreen.alert);
    expect(store.parentPush!.title, 'Route changed automatically');
    expect(store.events.first.type, 'route');

    expect(store.applyDisruptionText('hello there'), isFalse);
    expect(store.dashboardError, isNotNull);
    store.dispose();
  });

  test('scripted scenarios land in the expected state', () {
    final store = DemoStore();
    store.runScenario('redline');
    expect(store.selectedDestinationId, 'grandma');
    expect(store.phase, JourneyPhase.waiting); // between legs, about to board CCL
    expect(store.currentLegIndex, 2);
    expect(store.disruptions.single.lineId, 'CCL');
    expect(store.decision, isNotNull);
    expect(store.decision!.action, isNot(DecisionAction.keep));
    expect(store.childScreen, ChildScreen.alert);

    store.runScenario('scared');
    expect(store.alerts.first.urgency, Urgency.critical);
    expect(store.disruptions, isEmpty);

    store.runScenario('lost');
    expect(store.childScreen, ChildScreen.message);
    store.dispose();
  });

  testWidgets('combined demo shares the child start with parent status', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1200, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(const NaviApp(live: false, motion: false));
    await tester.tap(find.text('Combined demo'));
    await tester.pumpAndSettle();
    expect(find.text('Maya has no active journey'), findsOneWidget);

    await tester.tap(find.text('Start Journey'));
    await tester.pumpAndSettle();
    expect(find.text('On the way'), findsOneWidget);
    expect(find.text('Walk to stop'), findsOneWidget);
    await tester.pump(const Duration(seconds: 8)); // let the push banner expire
  });

  testWidgets('demo lab injects a disruption and shows it in the flow', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1400, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(const NaviApp(live: false, motion: false));
    await tester.tap(find.text('Demo lab'));
    await tester.pumpAndSettle();
    expect(find.text('Disruption dashboard'), findsOneWidget);

    await tester.ensureVisible(find.text('Bus 10 not running'));
    await tester.tap(find.text('Bus 10 not running'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Decision: reroute'), findsOneWidget);
    expect(find.text('New way to go').evaluate().isNotEmpty || find.textContaining('New way to go').evaluate().isNotEmpty, isTrue);
    await tester.pump(const Duration(seconds: 8));
  });
}
