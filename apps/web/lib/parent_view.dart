import 'package:flutter/material.dart';

import 'demo_store.dart';
import 'ui_kit.dart';

class ParentView extends StatelessWidget {
  const ParentView({super.key, required this.store});
  final DemoStore store;
  @override
  Widget build(BuildContext context) {
    final root = [
      ParentScreen.dashboard,
      ParentScreen.destinations,
      ParentScreen.notifications,
    ].contains(store.parentScreen);
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Padding(
          padding: EdgeInsets.only(bottom: 10),
          child: Text(
            'PARENT VIEW · SIMULATED',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.1,
              color: Navi.muted,
            ),
          ),
        ),
        Container(
          width: 390,
          height: 760,
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
            color: Navi.mint,
            borderRadius: BorderRadius.circular(38),
            border: Border.all(color: const Color(0xFF273442), width: 7),
            boxShadow: const [
              BoxShadow(
                color: Color(0x33000000),
                blurRadius: 18,
                offset: Offset(0, 8),
              ),
            ],
          ),
          child: Column(
            children: [
              Expanded(child: SingleChildScrollView(child: _screen())),
              if (root) _bottomNav(),
            ],
          ),
        ),
      ],
    );
  }

  Widget _header(
    String title, {
    String subtitle = '',
    bool back = false,
    Widget? trailing,
  }) => Container(
    width: double.infinity,
    padding: const EdgeInsets.fromLTRB(20, 29, 20, 22),
    color: Navi.tealDark,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            if (back)
              IconButton(
                onPressed: () => store.parentGo(ParentScreen.destinations),
                icon: const Icon(Icons.chevron_left, color: Colors.white),
                constraints: const BoxConstraints(),
                padding: const EdgeInsets.only(right: 8),
              ),
            const Expanded(
              child: Text(
                'NAVI · PARENT',
                style: TextStyle(
                  color: Color(0xFFB2E9E5),
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.3,
                ),
              ),
            ),
            ?trailing,
          ],
        ),
        const SizedBox(height: 5),
        Text(
          title,
          style: const TextStyle(
            fontSize: 25,
            fontWeight: FontWeight.w900,
            color: Colors.white,
          ),
        ),
        if (subtitle.isNotEmpty)
          Text(
            subtitle,
            style: const TextStyle(fontSize: 13, color: Color(0xFFD2F1EF)),
          ),
      ],
    ),
  );
  Widget _body(List<Widget> children) => Padding(
    padding: const EdgeInsets.all(16),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final w in children) ...[w, const SizedBox(height: 14)],
      ],
    ),
  );
  Widget _screen() => switch (store.parentScreen) {
    ParentScreen.dashboard => _dashboard(),
    ParentScreen.destinations => _destinations(),
    ParentScreen.notifications => _notifications(),
    ParentScreen.destinationDetails => _destinationDetails(),
    ParentScreen.destinationForm => DestinationForm(
      key: ValueKey(store.editingDestinationId ?? 'new'),
      store: store,
    ),
    ParentScreen.journeyDetails => _journeyDetails(),
  };

  Widget _bottomNav() => Container(
    color: Colors.white,
    padding: const EdgeInsets.only(top: 5, bottom: 8),
    child: Row(
      children: [
        _navItem(Icons.home_outlined, 'Home', ParentScreen.dashboard),
        _navItem(Icons.place_outlined, 'Places', ParentScreen.destinations),
        _navItem(
          Icons.notifications_none,
          'Updates',
          ParentScreen.notifications,
          badge: store.unreadCount,
        ),
      ],
    ),
  );
  Widget _navItem(
    IconData icon,
    String label,
    ParentScreen screen, {
    int badge = 0,
  }) => Expanded(
    child: InkWell(
      onTap: () => store.parentGo(screen),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Stack(
            clipBehavior: Clip.none,
            children: [
              Icon(
                icon,
                color: store.parentTab == screen ? Navi.tealDark : Navi.muted,
              ),
              if (badge > 0)
                Positioned(
                  right: -8,
                  top: -5,
                  child: CircleAvatar(
                    radius: 8,
                    backgroundColor: Navi.red,
                    child: Text(
                      '$badge',
                      style: const TextStyle(fontSize: 9, color: Colors.white),
                    ),
                  ),
                ),
            ],
          ),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w800,
              color: store.parentTab == screen ? Navi.tealDark : Navi.muted,
            ),
          ),
        ],
      ),
    ),
  );
  Widget _dashboard() {
    final active = store.active || store.phase == JourneyPhase.arrived;
    return Column(
      children: [
        _header(
          active ? 'Maya’s on the move' : 'Good morning 👋',
          subtitle: active
              ? 'Journey to ${store.selectedDestination.name}'
              : 'Maya has no active journey',
          trailing: IconButton(
            onPressed: () => store.parentGo(ParentScreen.notifications),
            icon: const Icon(Icons.notifications_none, color: Colors.white),
          ),
        ),
        _body([
          if (active)
            NaviCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        store.helpRequested
                            ? Icons.sos
                            : store.phase == JourneyPhase.arrived
                            ? Icons.check_circle
                            : Icons.directions_bus,
                        color: store.helpRequested ? Navi.red : Navi.tealDark,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          store.statusLabel,
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                            color: Navi.ink,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 7),
                  Text(
                    '${store.selectedDestination.emoji} ${store.selectedDestination.name} · ${store.selectedDestination.address}',
                    style: const TextStyle(color: Navi.secondary),
                  ),
                  const SizedBox(height: 12),
                  if (store.routeChanged)
                    _notice(
                      'Route updated automatically',
                      'A simulated EWL disruption affects the route. Bus 10 is shown as the alternative.',
                      Navi.amber,
                    ),
                  if (store.helpRequested)
                    _notice(
                      'Maya requested help',
                      'Check in with her right away. This is a demo event.',
                      Navi.red,
                    ),
                  if (store.phase == JourneyPhase.arrived)
                    _notice(
                      'Arrived safely',
                      'Maya explicitly confirmed her arrival at ${store.nowLabel}.',
                      Navi.tealDark,
                    )
                  else
                    Row(
                      children: [
                        Expanded(
                          child: _timeBox(
                            'EST. ARRIVAL',
                            store.estimatedArrival,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: _timeBox(
                            'REQUIRED BY',
                            store.selectedDestination.schedules.isEmpty
                                ? '—'
                                : store
                                      .selectedDestination
                                      .schedules
                                      .first
                                      .arrivalTime,
                          ),
                        ),
                      ],
                    ),
                  const SizedBox(height: 12),
                  TextButton.icon(
                    onPressed: () =>
                        store.parentGo(ParentScreen.journeyDetails),
                    icon: const Icon(Icons.chevron_right),
                    label: const Text('View full journey details'),
                  ),
                ],
              ),
            ),
          if (!active) ...[
            const SectionLabel('Today’s schedule'),
            NaviCard(
              onTap: () => store.parentGo(
                ParentScreen.destinationDetails,
                destinationId: store.selectedDestination.id,
              ),
              child: Row(
                children: [
                  Text(
                    store.selectedDestination.emoji,
                    style: const TextStyle(fontSize: 30),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          store.selectedDestination.name,
                          style: const TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 17,
                          ),
                        ),
                        Text(
                          store.selectedDestination.address,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        Text(
                          'Depart by ${store.leaveTime} · Due ${store.selectedDestination.schedules.isEmpty ? '—' : store.selectedDestination.schedules.first.arrivalTime}',
                          style: const TextStyle(
                            color: Navi.tealDark,
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Icon(Icons.chevron_right),
                ],
              ),
            ),
            NaviCard(
              color: const Color(0xFFE2F4F1),
              child: Row(
                children: [
                  const Icon(Icons.shield_outlined, color: Navi.tealDark),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'All quiet. NAVI will show when Maya starts a journey.',
                      style: TextStyle(
                        color: Navi.tealDark,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
          const SectionLabel('Saved destinations'),
          ...store.destinations
              .take(3)
              .map(
                (d) => NaviCard(
                  onTap: () => store.parentGo(
                    ParentScreen.destinationDetails,
                    destinationId: d.id,
                  ),
                  child: Row(
                    children: [
                      Text(d.emoji, style: const TextStyle(fontSize: 22)),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          d.name,
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                      ),
                      const Icon(Icons.chevron_right),
                    ],
                  ),
                ),
              ),
        ]),
      ],
    );
  }

  Widget _timeBox(String label, String value) => Container(
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: Navi.mint,
      borderRadius: BorderRadius.circular(15),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 10,
            color: Navi.tealDark,
            fontWeight: FontWeight.w800,
          ),
        ),
        Text(
          value,
          style: const TextStyle(
            fontSize: 22,
            color: Navi.ink,
            fontWeight: FontWeight.w900,
          ),
        ),
      ],
    ),
  );
  Widget _notice(String title, String message, Color color) => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(11),
    margin: const EdgeInsets.only(bottom: 8),
    decoration: BoxDecoration(
      color: color.withAlpha(20),
      borderRadius: BorderRadius.circular(13),
      border: Border.all(color: color.withAlpha(70)),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: TextStyle(color: color, fontWeight: FontWeight.w800),
        ),
        Text(message, style: TextStyle(color: color, fontSize: 12)),
      ],
    ),
  );
  Widget _destinations() => Column(
    children: [
      _header('Saved destinations', subtitle: 'Places Maya can travel to'),
      _body([
        for (final d in store.destinations)
          NaviCard(
            onTap: () => store.parentGo(
              ParentScreen.destinationDetails,
              destinationId: d.id,
            ),
            child: Row(
              children: [
                Text(d.emoji, style: const TextStyle(fontSize: 27)),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        d.name,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          color: Navi.ink,
                        ),
                      ),
                      Text(
                        d.address,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 12),
                      ),
                      Text(
                        d.schedules.isEmpty
                            ? 'No recurring schedule'
                            : '${d.schedules.length} recurring schedule(s)',
                        style: const TextStyle(
                          fontSize: 11,
                          color: Navi.tealDark,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: () => store.editDestination(d.id),
                  icon: const Icon(Icons.edit_outlined, color: Navi.tealDark),
                ),
              ],
            ),
          ),
        FilledButton.icon(
          onPressed: () => store.editDestination(null),
          icon: const Icon(Icons.add),
          label: const Text('Add destination'),
        ),
      ]),
    ],
  );
  Widget _destinationDetails() {
    final d = store.parentSelectedDestination;
    return Column(
      children: [
        _header(
          '${d.emoji} ${d.name}',
          subtitle: 'Saved destination',
          back: true,
          trailing: IconButton(
            onPressed: () => store.editDestination(d.id),
            icon: const Icon(Icons.edit_outlined, color: Colors.white),
          ),
        ),
        _body([
          const SectionLabel('Address'),
          NaviCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  d.address,
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    color: Navi.ink,
                  ),
                ),
                const SizedBox(height: 4),
                const Text(
                  'Arrival point only · NAVI uses the child’s current location as origin.',
                  style: TextStyle(fontSize: 12),
                ),
              ],
            ),
          ),
          const SectionLabel('Recurring arrivals'),
          if (d.schedules.isEmpty)
            const NaviCard(child: Text('No recurring schedule yet')),
          for (final s in d.schedules)
            NaviCard(
              child: Row(
                children: [
                  const Icon(
                    Icons.calendar_today_outlined,
                    color: Navi.tealDark,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      s.days.join(', '),
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                  ),
                  Text(
                    s.arrivalTime,
                    style: const TextStyle(
                      fontSize: 21,
                      fontWeight: FontWeight.w900,
                      color: Navi.tealDark,
                    ),
                  ),
                ],
              ),
            ),
          FilledButton.icon(
            onPressed: () => store.editDestination(d.id),
            icon: const Icon(Icons.edit),
            label: const Text('Edit destination and schedule'),
          ),
        ]),
      ],
    );
  }

  Widget _notifications() => Column(
    children: [
      _header('Notifications', subtitle: '${store.unreadCount} unread'),
      _body([
        if (store.events.isEmpty)
          const NaviCard(
            child: Column(
              children: [
                Icon(Icons.notifications_none, size: 42, color: Navi.teal),
                SizedBox(height: 8),
                Text(
                  'No notifications yet',
                  style: TextStyle(fontWeight: FontWeight.w800),
                ),
                Text('Journey updates will appear here as Maya travels.'),
              ],
            ),
          ),
        for (final e in store.events)
          NaviCard(
            onTap: () => store.markRead(e),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(switch (e.type) {
                  'started' => Icons.place,
                  'arrived' => Icons.check_circle,
                  'help' => Icons.sos,
                  _ => Icons.alt_route,
                }, color: e.type == 'help' ? Navi.red : Navi.tealDark),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        switch (e.type) {
                          'started' => 'Journey started',
                          'arrived' => 'Arrived safely',
                          'help' => 'Help requested',
                          _ => 'Route updated',
                        },
                        style: const TextStyle(
                          fontWeight: FontWeight.w800,
                          color: Navi.ink,
                        ),
                      ),
                      Text(e.message, style: const TextStyle(fontSize: 12)),
                      Text(
                        'Today · ${e.time} · Demo',
                        style: const TextStyle(fontSize: 10, color: Navi.muted),
                      ),
                    ],
                  ),
                ),
                if (!e.read)
                  const CircleAvatar(radius: 4, backgroundColor: Navi.teal),
              ],
            ),
          ),
      ]),
    ],
  );
  Widget _journeyDetails() => Column(
    children: [
      _header(
        'Journey details',
        subtitle: 'Maya → ${store.selectedDestination.name}',
        back: true,
      ),
      _body([
        NaviCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                store.statusLabel,
                style: const TextStyle(
                  fontSize: 19,
                  fontWeight: FontWeight.w900,
                  color: Navi.ink,
                ),
              ),
              const SizedBox(height: 6),
              Text(store.originDescription),
              Text(
                'Estimated arrival ${store.estimatedArrival} · due ${store.selectedDestination.schedules.isEmpty ? '—' : store.selectedDestination.schedules.first.arrivalTime}',
              ),
              if (store.phase == JourneyPhase.arrived)
                Text(
                  'Arrival confirmed ${store.nowLabel}',
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    color: Navi.tealDark,
                  ),
                ),
            ],
          ),
        ),
        if (store.routeChanged)
          _notice(
            'Route changed',
            'Relevant train disruption · alternative shown against original.',
            Navi.amber,
          ),
        if (store.helpRequested)
          _notice(
            'Help requested',
            'Demo event · no real message was sent.',
            Navi.red,
          ),
        PlaceholderRouteMap(alternative: store.routeChanged),
        const SectionLabel('Journey stages'),
        for (final item in [
          'Walk to stop · 5 min',
          'Bus 10 · 22 min',
          'Final walk · 5 min',
        ])
          NaviCard(
            child: Row(
              children: [
                const Icon(
                  Icons.radio_button_checked,
                  color: Navi.tealDark,
                  size: 15,
                ),
                const SizedBox(width: 10),
                Expanded(child: Text(item)),
              ],
            ),
          ),
        const Text(
          'Simulated route and times. The real OSM map will replace this preview.',
          style: TextStyle(fontSize: 11, color: Navi.muted),
        ),
      ]),
    ],
  );
}

class DestinationForm extends StatefulWidget {
  const DestinationForm({super.key, required this.store});
  final DemoStore store;
  @override
  State<DestinationForm> createState() => _DestinationFormState();
}

class _DestinationFormState extends State<DestinationForm> {
  final key = GlobalKey<FormState>();
  late final TextEditingController name;
  late final TextEditingController address;
  late String emoji;
  late List<ArrivalSchedule> schedules;
  final days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
  @override
  void initState() {
    super.initState();
    final d = widget.store.editingDestination;
    name = TextEditingController(text: d?.name ?? '');
    address = TextEditingController(text: d?.address ?? '');
    emoji = d?.emoji ?? '📍';
    schedules = [
      for (final s in d?.schedules ?? <ArrivalSchedule>[])
        ArrivalSchedule(
          id: s.id,
          days: [...s.days],
          arrivalTime: s.arrivalTime,
          bufferMinutes: s.bufferMinutes,
        ),
    ];
  }

  @override
  void dispose() {
    name.dispose();
    address.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final edit = widget.store.editingDestination != null;
    return Column(
      children: [
        Container(
          width: double.infinity,
          color: Navi.tealDark,
          padding: const EdgeInsets.fromLTRB(14, 30, 18, 20),
          child: Row(
            children: [
              IconButton(
                onPressed: () => widget.store.parentGo(
                  edit
                      ? ParentScreen.destinationDetails
                      : ParentScreen.destinations,
                ),
                icon: const Icon(Icons.chevron_left, color: Colors.white),
              ),
              Expanded(
                child: Text(
                  edit ? 'Edit destination' : 'New destination',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(16),
          child: Form(
            key: key,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SectionLabel('Name & icon'),
                Row(
                  children: [
                    DropdownButton<String>(
                      value: emoji,
                      items: ['📍', '🏫', '🏠', '📚', '⚽', '🏊', '🎨']
                          .map(
                            (e) => DropdownMenuItem(value: e, child: Text(e)),
                          )
                          .toList(),
                      onChanged: (e) => setState(() => emoji = e ?? emoji),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: TextFormField(
                        controller: name,
                        decoration: const InputDecoration(
                          hintText: 'e.g. School',
                        ),
                        validator: (v) => v == null || v.trim().isEmpty
                            ? 'Enter a name'
                            : null,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                const SectionLabel('Address'),
                TextFormField(
                  controller: address,
                  decoration: const InputDecoration(
                    hintText: 'Public Singapore location',
                  ),
                  validator: (v) =>
                      v == null || v.trim().isEmpty ? 'Enter an address' : null,
                ),
                const SizedBox(height: 5),
                const Text(
                  'Arrival point only. The child’s current location is the origin.',
                  style: TextStyle(fontSize: 11, color: Navi.muted),
                ),
                const SizedBox(height: 20),
                const SectionLabel('Recurring arrivals'),
                if (schedules.isEmpty)
                  const NaviCard(child: Text('No recurring schedule set.')),
                for (final s in schedules)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: NaviCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Expanded(
                                child: Text(
                                  'Schedule',
                                  style: TextStyle(fontWeight: FontWeight.w800),
                                ),
                              ),
                              TextButton(
                                onPressed: () =>
                                    setState(() => schedules.remove(s)),
                                child: const Text('Remove'),
                              ),
                            ],
                          ),
                          Wrap(
                            spacing: 3,
                            runSpacing: 2,
                            children: [
                              for (final d in days)
                                FilterChip(
                                  label: Text(
                                    d,
                                    style: const TextStyle(fontSize: 11),
                                  ),
                                  selected: s.days.contains(d),
                                  onSelected: (selected) => setState(() {
                                    selected ? s.days.add(d) : s.days.remove(d);
                                  }),
                                ),
                            ],
                          ),
                          Row(
                            children: [
                              Text(
                                'Arrive by ${s.arrivalTime}',
                                style: const TextStyle(
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              const Spacer(),
                              TextButton(
                                onPressed: () async {
                                  final parts = s.arrivalTime.split(':');
                                  final t = await showTimePicker(
                                    context: context,
                                    initialTime: TimeOfDay(
                                      hour: int.parse(parts[0]),
                                      minute: int.parse(parts[1]),
                                    ),
                                  );
                                  if (t != null) {
                                    setState(
                                      () => s.arrivalTime =
                                          '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}',
                                    );
                                  }
                                },
                                child: const Text('Change'),
                              ),
                            ],
                          ),
                          Row(
                            children: [
                              const Text('Buffer'),
                              const Spacer(),
                              DropdownButton<int>(
                                value: s.bufferMinutes,
                                items: [5, 10, 15, 20, 30]
                                    .map(
                                      (n) => DropdownMenuItem(
                                        value: n,
                                        child: Text('$n min'),
                                      ),
                                    )
                                    .toList(),
                                onChanged: (n) =>
                                    setState(() => s.bufferMinutes = n ?? 10),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                OutlinedButton.icon(
                  onPressed: () => setState(
                    () => schedules.add(
                      ArrivalSchedule(
                        id: 's-${DateTime.now().microsecondsSinceEpoch}',
                        days: ['Mon', 'Tue', 'Wed', 'Thu', 'Fri'],
                        arrivalTime: '07:45',
                      ),
                    ),
                  ),
                  icon: const Icon(Icons.add),
                  label: const Text('Add recurring schedule'),
                ),
                const SizedBox(height: 20),
                FilledButton(
                  onPressed: () {
                    if (!key.currentState!.validate()) return;
                    if (schedules.any((s) => s.days.isEmpty)) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text(
                            'Choose at least one day for each schedule',
                          ),
                        ),
                      );
                      return;
                    }
                    widget.store.saveDestination(
                      name: name.text.trim(),
                      address: address.text.trim(),
                      emoji: emoji,
                      schedules: schedules,
                    );
                  },
                  child: Text(edit ? 'Save changes' : 'Save destination'),
                ),
                const SizedBox(height: 8),
                Center(
                  child: TextButton(
                    onPressed: () =>
                        widget.store.parentGo(ParentScreen.destinations),
                    child: const Text('Cancel'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
