import 'package:flutter/material.dart';

import '../engine/reroute_engine.dart';
import '../models/conditions.dart';
import '../models/route_models.dart';
import '../models/signals.dart';
import '../state/demo_store.dart';
import '../widgets/nav_map.dart';
import '../widgets/route_map.dart';
import '../widgets/ui_kit.dart';

/// Watch-shaped child view. Every screen shows one instruction at a time in
/// words a primary school child can read, with one big button.
class ChildView extends StatelessWidget {
  const ChildView({super.key, required this.store});
  final DemoStore store;

  @override
  Widget build(BuildContext context) => Column(
    mainAxisSize: MainAxisSize.min,
    children: [
      const Padding(
        padding: EdgeInsets.only(bottom: 10),
        child: Text(
          'CHILD WATCH · SIMULATED',
          style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, letterSpacing: 1.1, color: Navi.muted),
        ),
      ),
      Container(
        width: 240,
        height: 360,
        padding: const EdgeInsets.all(13),
        decoration: BoxDecoration(
          color: const Color(0xFF0C0C0E),
          borderRadius: BorderRadius.circular(46),
          border: Border.all(color: const Color(0xFF29292B), width: 2),
          boxShadow: const [BoxShadow(color: Color(0x33000000), blurRadius: 18, offset: Offset(0, 8))],
        ),
        child: Container(
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(34),
            gradient: _isUrgent
                ? const LinearGradient(colors: [Color(0xFFFFE4E1), Color(0xFFFFF1F0)])
                : const LinearGradient(colors: [Color(0xFFE0F2F1), Color(0xFFF0F4F8), Color(0xFFECEFF1)]),
          ),
          child: Column(
            children: [
              const SizedBox(height: 7),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(9, 3, 9, 11),
                  child: _content(),
                ),
              ),
            ],
          ),
        ),
      ),
    ],
  );

  bool get _isUrgent =>
      store.childScreen == ChildScreen.alert &&
      (store.decision?.action == DecisionAction.holdAboard || store.decision?.action == DecisionAction.noRoute);

  Widget _content() {
    final leg = store.activeRoute.legs.isEmpty ? null : store.currentLeg;
    final title = switch (store.childScreen) {
      ChildScreen.home => '',
      ChildScreen.destinations => 'Where to?',
      ChildScreen.route => 'Route to ${store.selectedDestination.name}',
      ChildScreen.loading => 'Finding route',
      ChildScreen.walk => 'Walk to stop',
      ChildScreen.waiting => 'Wait for ${leg?.vehicleWord ?? 'bus'}',
      ChildScreen.onboard => 'On the way',
      ChildScreen.reaching => 'Reaching soon',
      ChildScreen.finalWalk => 'Final walk',
      ChildScreen.arrival => 'Have you arrived?',
      ChildScreen.confirmed => 'Arrived safely',
      ChildScreen.help => 'What is wrong?',
      ChildScreen.helpSent => 'Mum knows',
      ChildScreen.message => 'Message from Mum',
      ChildScreen.unavailable => 'Location unavailable',
      ChildScreen.noRoute => 'No suitable route',
      ChildScreen.alert => 'Journey update',
    };
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (store.childScreen == ChildScreen.home)
          Row(
            children: [
              const SizedBox(width: 4),
              Text(store.nowLabel, style: const TextStyle(fontSize: 10, color: Navi.muted, fontWeight: FontWeight.w700)),
              const Expanded(
                child: Center(
                  child: Text('NAVI', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w900, color: Navi.tealDark)),
                ),
              ),
              const SizedBox(width: 30),
            ],
          )
        else
          Row(
            children: [
              InkWell(
                onTap: () => store.childScreen == ChildScreen.help
                    ? store.childGo(store.returnFromHelp)
                    : store.active
                    ? store.dismissMessage()
                    : store.childGo(ChildScreen.home),
                child: const Icon(Icons.chevron_left, size: 19, color: Navi.tealDark),
              ),
              Expanded(
                child: Text(
                  title,
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w900, color: Navi.ink),
                ),
              ),
              Text(store.nowLabel, style: const TextStyle(fontSize: 9, color: Navi.muted)),
            ],
          ),
        const SizedBox(height: 7),
        switch (store.childScreen) {
          ChildScreen.home => _home(),
          ChildScreen.destinations => _destinations(),
          ChildScreen.route => _route(),
          ChildScreen.loading => _loading(),
          ChildScreen.walk => _walk(),
          ChildScreen.waiting => _waiting(),
          ChildScreen.onboard => _onboard(),
          ChildScreen.reaching => _reaching(),
          ChildScreen.finalWalk => _finalWalk(),
          ChildScreen.arrival => _arrival(),
          ChildScreen.confirmed => _confirmed(),
          ChildScreen.help => _helpMenu(),
          ChildScreen.helpSent => _helpSent(),
          ChildScreen.message => _message(),
          ChildScreen.unavailable => _error(
            'Location is unavailable. Ask for help or try again.',
            () => store.setFailure(location: false),
          ),
          ChildScreen.noRoute => _error(
            'We could not find a suitable route. Ask for help.',
            () => store.setFailure(route: false),
          ),
          ChildScreen.alert => _alert(),
        },
        if (const {
          ChildScreen.walk,
          ChildScreen.waiting,
          ChildScreen.onboard,
          ChildScreen.reaching,
          ChildScreen.finalWalk,
          ChildScreen.arrival,
          ChildScreen.route,
          ChildScreen.alert,
        }.contains(store.childScreen))
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Center(
              child: InkWell(
                onTap: store.requestHelp,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: Navi.red.withAlpha(22),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Text(
                    '🆘 Need help?',
                    style: TextStyle(fontSize: 10, color: Navi.red, fontWeight: FontWeight.w800),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _glass(Widget child, {Color? tint}) => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(8),
    decoration: BoxDecoration(
      color: tint ?? const Color(0xD9FFFFFF),
      borderRadius: BorderRadius.circular(14),
      border: Border.all(color: Colors.white70),
    ),
    child: child,
  );

  Widget _button(String label, VoidCallback onTap, {bool secondary = false, Color? color}) => Padding(
    padding: const EdgeInsets.only(top: 7),
    child: SizedBox(
      width: double.infinity,
      height: secondary ? 34 : 42,
      child: FilledButton(
        onPressed: onTap,
        style: FilledButton.styleFrom(
          backgroundColor: color ?? (secondary ? Colors.white70 : Navi.teal),
          foregroundColor: secondary ? Navi.tealDark : Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 4),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
          textStyle: TextStyle(fontSize: secondary ? 12 : 13, fontWeight: FontWeight.w800),
        ),
        child: FittedBox(fit: BoxFit.scaleDown, child: Text(label)),
      ),
    ),
  );

  Widget _small(String text, {Color color = Navi.secondary, bool bold = false, double size = 11, TextAlign? align}) => Text(
    text,
    textAlign: align,
    style: TextStyle(fontSize: size, color: color, fontWeight: bold ? FontWeight.w800 : FontWeight.w500, height: 1.25),
  );

  Widget _nextSteps({int skip = 0, int take = 2}) {
    final legs = store.remainingLegs.skip(skip).take(take).toList();
    if (legs.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _small('THEN', color: Navi.muted, bold: true, size: 9),
          for (final l in legs)
            _small('${l.mode == LegMode.walk ? '🚶' : l.mode == LegMode.bus ? '🚌' : '🚆'} ${l.childLabel} · ${l.totalMinutes} min', size: 10),
        ],
      ),
    );
  }

  Widget _home() {
    final leaveIn = store.leaveInMinutes;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _glass(
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _small('${store.selectedDestination.emoji} ${store.selectedDestination.name}', color: Navi.ink, bold: true, size: 13),
              _small('Arrive by ${store.schedule?.arrivalTime ?? '—'}'),
              Row(
                children: [
                  _small('Leave ', color: Navi.ink),
                  Flexible(
                    child: _small(
                      store.leaveEarlier
                          ? 'EARLIER · ${store.leaveTime}'
                          : leaveIn <= 0
                          ? 'NOW'
                          : 'IN $leaveIn MIN',
                      color: store.leaveEarlier ? Navi.red : Navi.tealDark,
                      bold: true,
                      size: 14,
                    ),
                  ),
                ],
              ),
              if (store.phase == JourneyPhase.arrived)
                _small('You arrived at ${store.selectedDestination.name} ✅', color: Navi.tealDark, size: 10),
              if (store.weather != null)
                _small('${store.weather!.emoji} ${store.weather!.childLine}', size: 10,
                    color: store.weather!.raining ? Navi.amber : Navi.secondary, bold: store.weather!.raining),
            ],
          ),
        ),
        _button('Start Journey', store.start),
        _button('Change place', () => store.childGo(ChildScreen.destinations), secondary: true),
        const SizedBox(height: 8),
        _small('TODAY', color: Navi.muted, bold: true, size: 10),
        for (final d in store.destinations.take(3))
          if (d.schedules.isNotEmpty)
            Row(
              children: [
                _small('${d.emoji} ${d.name}'),
                const Spacer(),
                _small(d.schedules.first.arrivalTime, color: Navi.tealDark, bold: true),
              ],
            ),
        const SizedBox(height: 5),
        Center(
          child: InkWell(
            onTap: store.requestHelp,
            child: _small('🆘 Need help?', color: Navi.red, size: 10, bold: true),
          ),
        ),
      ],
    );
  }

  Widget _destinations() => Column(
    children: [
      for (final d in store.destinations)
        Padding(
          padding: const EdgeInsets.only(bottom: 6),
          child: InkWell(
            onTap: () => store.selectDestination(d.id),
            child: _glass(
              Row(
                children: [
                  Text(d.emoji),
                  const SizedBox(width: 6),
                  Expanded(child: _small(d.name, color: Navi.ink, bold: true, size: 12)),
                  const Icon(Icons.chevron_right, size: 14),
                ],
              ),
            ),
          ),
        ),
    ],
  );

  Widget _route() => Column(
    children: [
      _glass(
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _small('From where you are', bold: true, color: Navi.ink),
            _small(store.planning ? 'Asking OneMap…' : store.routeSource, size: 9,
                color: store.activeRoute.live ? Navi.tealDark : Navi.muted),
            const SizedBox(height: 5),
            _small(store.activeRoute.summary, bold: true, color: Navi.tealDark, size: 10),
            _small(
              'Arrive ${store.estimatedArrival} · ${store.activeRoute.totalMinutes} min · ${store.activeRoute.transfers} change${store.activeRoute.transfers == 1 ? '' : 's'}',
              size: 9,
            ),
          ],
        ),
      ),
      const SizedBox(height: 6),
      RouteStripMap(
        route: store.activeRoute,
        original: store.routeChanged ? store.originalRoute : null,
        affectedLegIndex: store.decision?.affectedLegIndex ?? -1,
        compact: true,
      ),
      _button(store.active ? 'Continue' : 'Start Journey', store.active ? store.dismissMessage : store.start),
    ],
  );

  Widget _loading() => Column(
    children: [
      const SizedBox(height: 20),
      const CircularProgressIndicator(),
      const SizedBox(height: 8),
      _small('Finding a route to ${store.selectedDestination.name}'),
    ],
  );

  Widget _walk() {
    final leg = store.currentLeg;
    final next = store.currentLegIndex + 1 < store.activeRoute.legs.length
        ? store.activeRoute.legs[store.currentLegIndex + 1]
        : null;
    return Column(
      children: [
        NavMap3D(
          path: leg.points,
          position: store.childPosition,
          headingDeg: store.headingDeg,
          guidance: store.guidance,
          metresLeft: store.metresLeft,
          destinationLabel: leg.to,
          features: store.walkFeatures,
        ),
        const SizedBox(height: 5),
        if (next != null)
          _small(
            '${next.mode == LegMode.bus ? '🚌' : '🚆'} ${next.label} from ${leg.to}',
            color: Navi.tealDark,
            bold: true,
            size: 10,
          ),
        _button(
          store.legEndReached ? 'I’m here ✅' : 'I’m at the ${next?.stopWord ?? 'stop'}',
          store.nextStep,
          color: store.legEndReached ? const Color(0xFF16A34A) : null,
        ),
      ],
    );
  }

  /// Transit legs: which vehicle, how many stops, where to get off.
  Widget _ride(RouteLeg leg, {required bool waiting}) {
    final colour = legColour(leg);
    final stops = leg.stops.isEmpty ? [leg.from, leg.to] : leg.stops;
    final passed = waiting ? 0 : store.stopsPassed;
    final left = stops.length - 1 - passed;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: const Color(0xEEFFFFFF),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: colour.withAlpha(120), width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                decoration: BoxDecoration(color: colour, borderRadius: BorderRadius.circular(8)),
                child: Text(
                  leg.mode == LegMode.bus ? '🚌 ${leg.serviceNo}' : '🚆 ${leg.lineId}',
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 12),
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: _small(waiting ? 'Wait at ${leg.from}' : 'Riding to ${leg.to}', color: Navi.ink, bold: true, size: 11),
              ),
            ],
          ),
          const SizedBox(height: 7),
          SizedBox(
            height: 34,
            child: Row(
              children: [
                for (var i = 0; i < stops.length; i++) ...[
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: i == stops.length - 1 ? 14 : 9,
                        height: i == stops.length - 1 ? 14 : 9,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: i <= passed ? colour : Colors.white,
                          border: Border.all(color: i == stops.length - 1 ? const Color(0xFF16A34A) : colour, width: 2),
                        ),
                      ),
                    ],
                  ),
                  if (i < stops.length - 1)
                    Expanded(
                      child: Container(height: 3, color: i < passed ? colour : colour.withAlpha(70)),
                    ),
                ],
              ],
            ),
          ),
          _small(
            waiting
                ? '${stops.length - 1} stop${stops.length - 1 == 1 ? '' : 's'} · about ${leg.minutes} min'
                : left <= 1
                ? 'Next stop: get off! 🛎️'
                : '$left stops to go',
            color: left <= 1 && !waiting ? Navi.red : Navi.secondary,
            bold: left <= 1 && !waiting,
            size: 10.5,
          ),
          _small('🏁 Get off at ${leg.to}', color: Navi.ink, bold: true, size: 12),
          if (waiting && leg.mode == LegMode.rail && store.boardingCrowd != CrowdLevel.unknown)
            _small(
              '${store.boardingCrowd.emoji} Platform: ${store.boardingCrowd.word}${store.boardingCrowd == CrowdLevel.high ? ' · stand near the door' : ''} · live LTA',
              color: Color(store.boardingCrowd.colour),
              bold: true,
              size: 10,
            ),
        ],
      ),
    );
  }

  Widget _waiting() {
    final leg = store.currentLeg;
    final delayed = store.decision?.action == DecisionAction.delay ? store.decision!.addedMinutes : 0;
    final liveBus = store.liveArrivals.isEmpty ? null : store.liveArrivals.first;
    final arrival = liveBus != null && liveBus.minutes.isNotEmpty
        ? 'Next ${leg.vehicleWord}: ${liveBus.minutes.take(2).map((m) => m == 0 ? 'now' : '$m min').join(' · ')} · live LTA'
        : 'Next ${leg.vehicleWord}: ${leg.waitMinutes + delayed} min · then ${leg.waitMinutes + delayed + 7} min';
    return Column(
      children: [
        _ride(leg, waiting: true),
        const SizedBox(height: 5),
        _small(arrival, color: delayed > 0 ? Navi.red : Navi.tealDark, bold: true, size: 10.5),
        if (delayed > 0) _small('Late by $delayed min. That is okay.', size: 10, color: Navi.red),
        _button('I’m on the ${leg.vehicleWord}', store.nextStep),
      ],
    );
  }

  Widget _onboard() {
    final leg = store.currentLeg;
    return Column(
      children: [
        _ride(leg, waiting: false),
        const SizedBox(height: 5),
        _small('Arrive ${store.estimatedArrival}', color: Navi.tealDark, bold: true, size: 10.5),
        _button('Show reaching soon', store.nextStep),
      ],
    );
  }

  Widget _reaching() {
    final leg = store.currentLeg;
    return Column(
      children: [
        _glass(
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _small('Reaching ${leg.to} soon', color: Navi.ink, bold: true, size: 15),
              _small('Listen for the announcement. Look at the ${leg.stopWord} sign.'),
              _small('Alighting time is approximate.', size: 9),
            ],
          ),
        ),
        _button('I’m off the ${leg.vehicleWord}', store.offVehicle),
      ],
    );
  }

  Widget _finalWalk() {
    final leg = store.currentLeg;
    return Column(
      children: [
        NavMap3D(
          path: leg.points,
          position: store.childPosition,
          headingDeg: store.headingDeg,
          guidance: store.guidance,
          metresLeft: store.metresLeft,
          destinationLabel: store.selectedDestination.name,
          features: store.walkFeatures,
        ),
        const SizedBox(height: 5),
        _small('🏁 ${store.selectedDestination.emoji} ${store.selectedDestination.name}', color: Navi.ink, bold: true, size: 11),
        _button(
          store.legEndReached ? 'I’m here ✅' : 'I’m at the destination',
          store.nextStep,
          color: store.legEndReached ? const Color(0xFF16A34A) : null,
        ),
      ],
    );
  }

  Widget _arrival() => Column(
    children: [
      _glass(
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _small('Are you at ${store.selectedDestination.name}?', color: Navi.ink, bold: true, size: 13),
            _small('Only you can confirm your arrival.'),
          ],
        ),
      ),
      _button('Yes, I’m here ✅', store.confirmArrival),
    ],
  );

  Widget _confirmed() => Column(
    children: [
      const Icon(Icons.check_circle, color: Color(0xFF16A34A), size: 43),
      _small('You told Mum you arrived.', color: Navi.ink, bold: true, size: 12, align: TextAlign.center),
      _small('Well done! 🎉', size: 11, align: TextAlign.center),
      _button('Home', () => store.childGo(ChildScreen.home)),
    ],
  );

  /// Big, plain buttons. The child taps what is happening; NAVI does the rest.
  Widget _helpMenu() => Column(
    children: [
      for (final k in ChildSignalKind.values)
        Padding(
          padding: const EdgeInsets.only(bottom: 5),
          child: SizedBox(
            height: 36,
            width: double.infinity,
            child: FilledButton(
              onPressed: () => store.sendSignal(k),
              style: FilledButton.styleFrom(
                backgroundColor: k == ChildSignalKind.scared
                    ? Navi.red
                    : k == ChildSignalKind.checkIn
                    ? Colors.white
                    : Colors.white,
                foregroundColor: k == ChildSignalKind.scared ? Colors.white : Navi.ink,
                padding: const EdgeInsets.symmetric(horizontal: 8),
                alignment: Alignment.centerLeft,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                textStyle: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w800),
              ),
              child: Text('${k.emoji}  ${k.childButton}'),
            ),
          ),
        ),
      _button('Back', () => store.childGo(store.returnFromHelp), secondary: true),
    ],
  );

  Widget _helpSent() {
    final a = store.latestAlert;
    return Column(
      children: [
        _glass(
          Column(
            children: [
              Text(a?.kind.emoji ?? '💚', style: const TextStyle(fontSize: 26)),
              const SizedBox(height: 4),
              _small(a?.childReassuranceLive ?? 'Mum has been told.', color: Navi.ink, bold: true, size: 11.5, align: TextAlign.center),
            ],
          ),
          tint: const Color(0xEEFFFFFF),
        ),
        _button('OK', store.dismissMessage),
      ],
    );
  }

  Widget _message() {
    final m = store.childMessages.isEmpty ? null : store.childMessages.first;
    return Column(
      children: [
        _glass(
          Column(
            children: [
              const Text('💬', style: TextStyle(fontSize: 26)),
              const SizedBox(height: 4),
              _small(m?.text ?? '', color: Navi.ink, bold: true, size: 13, align: TextAlign.center),
              const SizedBox(height: 3),
              _small('from Mum · ${m == null ? '' : hhmm(m.atMinutes)}', size: 9),
            ],
          ),
          tint: const Color(0xFFE0F2F1),
        ),
        _button('OK 👍', store.dismissMessage),
      ],
    );
  }

  Widget _error(String message, VoidCallback retry) => Column(
    children: [
      _glass(_small(message, color: Navi.red, bold: true)),
      _button('Try again', retry),
    ],
  );

  Widget _alert() {
    final d = store.decision;
    if (d == null) return _route();
    final urgent = d.action == DecisionAction.holdAboard || d.action == DecisionAction.noRoute;
    return Column(
      children: [
        _glass(
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _small(d.childTitle, color: urgent ? Navi.red : Navi.amber, bold: true, size: 15),
              const SizedBox(height: 3),
              _small(d.childMessage, color: Navi.ink, bold: true, size: 11.5),
              if (d.changesRoute) ...[
                const SizedBox(height: 6),
                RouteStripMap(
                  route: store.activeRoute,
                  original: store.originalRoute,
                  affectedLegIndex: d.affectedLegIndex,
                  compact: true,
                ),
                _nextSteps(skip: store.active ? 1 : 0, take: 3),
              ],
              if (d.action == DecisionAction.delay || d.action == DecisionAction.leaveEarlier)
                _small('New arrival time ${store.estimatedArrival}', size: 10, color: Navi.secondary),
            ],
          ),
          tint: urgent ? const Color(0xEEFFF1F0) : null,
        ),
        _button('OK, got it', store.dismissAlert, color: urgent ? Navi.red : Navi.teal),
      ],
    );
  }
}
