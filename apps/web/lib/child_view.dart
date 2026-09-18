import 'package:flutter/material.dart';

import 'demo_store.dart';
import 'ui_kit.dart';

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
          'CHILD VIEW · SIMULATED',
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w800,
            letterSpacing: 1.1,
            color: Navi.muted,
          ),
        ),
      ),
      Container(
        width: 232,
        height: 276,
        padding: const EdgeInsets.all(13),
        decoration: BoxDecoration(
          color: const Color(0xFF0C0C0E),
          borderRadius: BorderRadius.circular(43),
          border: Border.all(color: const Color(0xFF29292B), width: 2),
          boxShadow: const [
            BoxShadow(
              color: Color(0x33000000),
              blurRadius: 18,
              offset: Offset(0, 8),
            ),
          ],
        ),
        child: Container(
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(33),
            gradient: const LinearGradient(
              colors: [Color(0xFFE0F2F1), Color(0xFFF0F4F8), Color(0xFFECEFF1)],
            ),
          ),
          child: Column(
            children: [
              const SizedBox(height: 7),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(8, 3, 8, 11),
                  child: _content(),
                ),
              ),
            ],
          ),
        ),
      ),
    ],
  );

  Widget _content() {
    final title = switch (store.childScreen) {
      ChildScreen.home => '',
      ChildScreen.destinations => 'Where to?',
      ChildScreen.route => 'Route to ${store.selectedDestination.name}',
      ChildScreen.loading => 'Finding route',
      ChildScreen.walk => 'Walk to stop',
      ChildScreen.waiting => 'Wait for bus',
      ChildScreen.onboard => 'On the way',
      ChildScreen.reaching => 'Reaching soon',
      ChildScreen.finalWalk => 'Final walk',
      ChildScreen.arrival => 'Have you arrived?',
      ChildScreen.confirmed => 'Arrived safely',
      ChildScreen.help => 'Need help?',
      ChildScreen.unavailable => 'Location unavailable',
      ChildScreen.noRoute => 'No suitable route',
      ChildScreen.alert => 'Journey update',
    };
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (store.childScreen == ChildScreen.home)
          const Center(
            child: Text(
              'NAVI',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w900,
                color: Navi.tealDark,
              ),
            ),
          )
        else
          Row(
            children: [
              InkWell(
                onTap: () => store.childGo(ChildScreen.home),
                child: const Icon(
                  Icons.chevron_left,
                  size: 19,
                  color: Navi.tealDark,
                ),
              ),
              Expanded(
                child: Text(
                  title,
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w900,
                    color: Navi.ink,
                  ),
                ),
              ),
              const SizedBox(width: 19),
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
          ChildScreen.help => _help(),
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
        if (store.childScreen != ChildScreen.help &&
            store.childScreen != ChildScreen.confirmed &&
            store.childScreen != ChildScreen.home)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Center(
              child: InkWell(
                onTap: store.requestHelp,
                child: const Text(
                  'Need Help?',
                  style: TextStyle(
                    fontSize: 10,
                    color: Navi.muted,
                    decoration: TextDecoration.underline,
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _glass(Widget child) => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(8),
    decoration: BoxDecoration(
      color: const Color(0xD9FFFFFF),
      borderRadius: BorderRadius.circular(14),
      border: Border.all(color: Colors.white70),
    ),
    child: child,
  );
  Widget _button(String label, VoidCallback onTap, {bool secondary = false}) =>
      Padding(
        padding: const EdgeInsets.only(top: 7),
        child: SizedBox(
          width: double.infinity,
          height: secondary ? 34 : 42,
          child: FilledButton(
            onPressed: onTap,
            style: FilledButton.styleFrom(
              backgroundColor: secondary ? Colors.white70 : Navi.teal,
              foregroundColor: secondary ? Navi.tealDark : Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 4),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(30),
              ),
              textStyle: TextStyle(
                fontSize: secondary ? 12 : 13,
                fontWeight: FontWeight.w800,
              ),
            ),
            child: FittedBox(fit: BoxFit.scaleDown, child: Text(label)),
          ),
        ),
      );
  Widget _small(
    String text, {
    Color color = Navi.secondary,
    bool bold = false,
    double size = 11,
  }) => Text(
    text,
    style: TextStyle(
      fontSize: size,
      color: color,
      fontWeight: bold ? FontWeight.w800 : FontWeight.w500,
    ),
  );
  Widget _home() => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      _glass(
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _small(
              '${store.selectedDestination.emoji} ${store.selectedDestination.name}',
              color: Navi.ink,
              bold: true,
              size: 13,
            ),
            _small(
              'Arrive by ${store.selectedDestination.schedules.isEmpty ? '—' : store.selectedDestination.schedules.first.arrivalTime}',
            ),
            Row(
              children: [
                _small('Leave in ', color: Navi.ink),
                Flexible(
                  child: _small(
                    store.leaveEarlier
                        ? 'EARLIER · ${store.leaveTime}'
                        : '12 MIN',
                    color: store.leaveEarlier ? Navi.red : Navi.tealDark,
                    bold: true,
                    size: 14,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
      _button('Start Journey', store.start),
      _button(
        'Navigate',
        () => store.childGo(ChildScreen.destinations),
        secondary: true,
      ),
      const SizedBox(height: 8),
      _small('TODAY', color: Navi.muted, bold: true, size: 10),
      Row(
        children: [
          _small('Home'),
          const Spacer(),
          _small('3:30 PM', color: Navi.tealDark, bold: true),
        ],
      ),
      const SizedBox(height: 5),
      Center(
        child: InkWell(
          onTap: store.requestHelp,
          child: _small('Need Help?', color: Navi.muted, size: 10),
        ),
      ),
    ],
  );
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
                  Expanded(
                    child: _small(
                      d.name,
                      color: Navi.ink,
                      bold: true,
                      size: 12,
                    ),
                  ),
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
            _small('From current location', bold: true, color: Navi.ink),
            _small(store.originDescription, size: 9),
            const SizedBox(height: 5),
            _small('Walk → Bus 10 → Walk', bold: true, color: Navi.tealDark),
            _small(
              'Estimated arrival ${store.estimatedArrival} · 1 transfer',
              size: 9,
            ),
          ],
        ),
      ),
      const SizedBox(height: 6),
      const SizedBox(height: 85, child: PlaceholderRouteMap()),
      _button('Start Journey', store.start),
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
  Widget _walk() => Column(
    children: [
      _glass(
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _small(
              'Walk to the bus stop',
              color: Navi.ink,
              bold: true,
              size: 13,
            ),
            _small('Tampines Interchange · 350 m'),
            const SizedBox(height: 5),
            _small(
              'Bus 10 · estimated 8 min',
              color: Navi.tealDark,
              bold: true,
            ),
          ],
        ),
      ),
      _button(
        'I’m at the stop',
        () => store.setPhase(JourneyPhase.waiting, ChildScreen.waiting),
      ),
    ],
  );
  Widget _waiting() => Column(
    children: [
      _glass(
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _small(
              'Bus 10 · Tampines Int',
              color: Navi.ink,
              bold: true,
              size: 13,
            ),
            _small(
              'Next bus: 3 min · then 9 min',
              color: Navi.tealDark,
              bold: true,
            ),
            _small('Seats available · simulated', size: 9),
          ],
        ),
      ),
      _button(
        'I’m on the bus',
        () => store.setPhase(JourneyPhase.onboard, ChildScreen.onboard),
      ),
    ],
  );
  Widget _onboard() => Column(
    children: [
      _glass(
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _small(
              'Bus 10 to ${store.selectedDestination.name}',
              color: Navi.ink,
              bold: true,
              size: 12,
            ),
            _small('18 MIN TO GO', color: Navi.tealDark, bold: true, size: 17),
            _small('ETA ${store.estimatedArrival} · simulated'),
            const LinearProgressIndicator(value: .63, color: Navi.teal),
          ],
        ),
      ),
      _button(
        'Show reaching soon',
        () => store.setPhase(JourneyPhase.reaching, ChildScreen.reaching),
      ),
    ],
  );
  Widget _reaching() => Column(
    children: [
      _glass(
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _small('Reaching soon', color: Navi.ink, bold: true, size: 15),
            _small('Check the bus announcements and stop signs.'),
            _small('Alighting time is approximate.', size: 9),
          ],
        ),
      ),
      _button('I’m off the bus/train', store.offVehicle),
    ],
  );
  Widget _finalWalk() => Column(
    children: [
      _glass(
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _small(
              'Walk to ${store.selectedDestination.name}',
              color: Navi.ink,
              bold: true,
              size: 12,
            ),
            _small('About 5 minutes · simulated'),
            const SizedBox(height: 5),
            _small('Follow the marked route', color: Navi.tealDark, bold: true),
          ],
        ),
      ),
      _button(
        'I’m at the destination',
        () => store.setPhase(
          JourneyPhase.awaitingConfirmation,
          ChildScreen.arrival,
        ),
      ),
    ],
  );
  Widget _arrival() => Column(
    children: [
      _glass(
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _small(
              'Are you at ${store.selectedDestination.name}?',
              color: Navi.ink,
              bold: true,
              size: 13,
            ),
            _small('Only you can confirm your arrival.'),
          ],
        ),
      ),
      _button('Confirm arrival', store.confirmArrival),
    ],
  );
  Widget _confirmed() => Column(
    children: [
      const Icon(Icons.check_circle, color: Color(0xFF16A34A), size: 43),
      _small(
        'You confirmed your arrival.',
        color: Navi.ink,
        bold: true,
        size: 12,
      ),
      _small('Parent view has been updated.', size: 10),
      _button('Home', () => store.childGo(ChildScreen.home)),
    ],
  );
  Widget _help() => Column(
    children: [
      _glass(
        Column(
          children: [
            const Icon(Icons.sos, color: Navi.red, size: 30),
            _small(
              'Help request shown to parent',
              color: Navi.ink,
              bold: true,
              size: 12,
            ),
            _small('Demo only · no real call or push alert', size: 9),
          ],
        ),
      ),
      _button(
        'Back',
        () => store.childGo(store.returnFromHelp),
        secondary: true,
      ),
    ],
  );
  Widget _error(String message, VoidCallback retry) => Column(
    children: [
      _glass(_small(message, color: Navi.red, bold: true)),
      _button('Try again', retry),
    ],
  );
  Widget _alert() => Column(
    children: [
      _glass(
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _small(
              store.leaveEarlier ? 'Leave earlier' : 'Route changed',
              color: Navi.red,
              bold: true,
              size: 15,
            ),
            _small(
              store.leaveEarlier
                  ? 'Leave at ${store.leaveTime} · 10 min earlier'
                  : 'Train disruption affects your route.',
              color: Navi.ink,
              bold: true,
            ),
            _small(
              'Alternative: Bus 10 · ETA ${store.estimatedArrival}',
              size: 10,
            ),
          ],
        ),
      ),
      _button('View route', () => store.childGo(ChildScreen.route)),
    ],
  );
}
