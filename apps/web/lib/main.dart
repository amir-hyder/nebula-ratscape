import 'dart:async';

import 'package:flutter/material.dart';

import 'demo/demo_lab.dart';
import 'screens/child_view.dart';
import 'screens/parent_view.dart';
import 'state/demo_store.dart';
import 'widgets/nav_map.dart';
import 'widgets/ui_kit.dart';

void main() => runApp(const NaviApp());

enum ViewingMode { landing, child, parent, combined, lab }

class NaviApp extends StatefulWidget {
  const NaviApp({super.key, this.live = true, this.motion = true});
  /// Use the local backend (OneMap/LTA) when reachable.
  final bool live;
  /// Move the simulated child along the route so the watch navigates.
  final bool motion;
  @override
  State<NaviApp> createState() => _NaviAppState();
}

class _NaviAppState extends State<NaviApp> {
  late final store = DemoStore(live: widget.live, motion: widget.motion);
  // Deep links for presentations: #lab, #child, #parent, #combined, or
  // #lab/<scenario> to replay a scripted scenario (see DemoStore.scenarios).
  ViewingMode mode = switch (Uri.base.fragment.split('/').first) {
    'lab' => ViewingMode.lab,
    'child' => ViewingMode.child,
    'parent' => ViewingMode.parent,
    'combined' => ViewingMode.combined,
    _ => ViewingMode.landing,
  };
  bool combinedChild = true;

  @override
  void initState() {
    super.initState();
    final parts = Uri.base.fragment.split('?').first.split('/');
    final nav = RegExp(r'nav=(\w+)').firstMatch(Uri.base.fragment);
    if (nav != null) NavMap3D.mode = nav.group(1)!;
    final tiles = RegExp(r'tiles=(\w+)').firstMatch(Uri.base.fragment);
    if (tiles != null) MapTiles.provider = tiles.group(1)!;
    if (parts.length > 1 && parts[1].isNotEmpty) unawaited(store.runScenario(parts[1]));
  }

  @override
  void dispose() {
    store.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'NAVI · Demo',
    debugShowCheckedModeBanner: false,
    theme: Navi.theme(),
    home: AnimatedBuilder(
      animation: store,
      builder: (context, _) => Scaffold(
        body: SafeArea(
          child: Column(
            children: [
              Container(
                color: Colors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: 18,
                  vertical: 10,
                ),
                child: Row(
                  children: [
                    const Text(
                      'NAVI',
                      style: TextStyle(
                        color: Navi.tealDark,
                        fontSize: 21,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(width: 9),
                    const DemoTag(),
                    const Spacer(),
                    if (mode != ViewingMode.landing)
                      TextButton(
                        onPressed: () =>
                            setState(() => mode = ViewingMode.landing),
                        child: const Text('Views'),
                      ),
                    if (mode != ViewingMode.landing &&
                        mode != ViewingMode.lab)
                      IconButton(
                        tooltip: 'Demo controls',
                        onPressed: store.toggleDemo,
                        icon: const Icon(Icons.tune, color: Navi.tealDark),
                      ),
                  ],
                ),
              ),
              Expanded(
                child: LayoutBuilder(
                  builder: (context, c) => SingleChildScrollView(
                    child: Center(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(12, 24, 12, 36),
                        child: Column(
                          children: [
                            if (mode == ViewingMode.landing)
                              _landing(c.maxWidth),
                            if (mode == ViewingMode.child)
                              ChildView(store: store),
                            if (mode == ViewingMode.parent)
                              ParentView(store: store),
                            if (mode == ViewingMode.combined)
                              _combined(c.maxWidth),
                            if (mode == ViewingMode.lab)
                              DemoLab(store: store, width: c.maxWidth),
                            if (mode != ViewingMode.landing &&
                                mode != ViewingMode.lab &&
                                store.demoPanelOpen)
                              Padding(
                                padding: const EdgeInsets.only(top: 18),
                                child: _demoPanel(),
                              ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );

  Widget _landing(double width) => ConstrainedBox(
    constraints: const BoxConstraints(maxWidth: 720),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 25),
        const Text(
          'A calmer way to get there.',
          style: TextStyle(
            fontSize: 32,
            height: 1.1,
            fontWeight: FontWeight.w900,
            color: Navi.ink,
          ),
        ),
        const SizedBox(height: 8),
        const Text(
          'An interactive Singapore travel companion for children and parents. Explore a simulated journey.',
          style: TextStyle(fontSize: 16, color: Navi.secondary),
        ),
        const SizedBox(height: 25),
        _modeCard(
          Icons.watch_outlined,
          'Child watch',
          'Short, timely travel instructions',
          ViewingMode.child,
        ),
        const SizedBox(height: 12),
        _modeCard(
          Icons.phone_iphone,
          'Parent phone',
          'Destinations, schedules and updates',
          ViewingMode.parent,
        ),
        const SizedBox(height: 12),
        _modeCard(
          Icons.dashboard_outlined,
          'Combined demo',
          'See how both views stay in sync',
          ViewingMode.combined,
        ),
        const SizedBox(height: 12),
        _modeCard(
          Icons.science_outlined,
          'Demo lab',
          'Child input → NAVI → parent output, plus a disruption dashboard for live rerouting',
          ViewingMode.lab,
        ),
        const SizedBox(height: 20),
        const Text(
          'Demo data only · no live location, routing or notifications',
          style: TextStyle(color: Navi.muted, fontSize: 12),
        ),
      ],
    ),
  );
  Widget _modeCard(
    IconData icon,
    String title,
    String subtitle,
    ViewingMode next,
  ) => NaviCard(
    onTap: () => setState(() => mode = next),
    padding: const EdgeInsets.all(20),
    child: Row(
      children: [
        Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: Navi.mint,
            borderRadius: BorderRadius.circular(14),
          ),
          child: Icon(icon, color: Navi.tealDark),
        ),
        const SizedBox(width: 15),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: Navi.ink,
                ),
              ),
              Text(subtitle, style: const TextStyle(color: Navi.secondary)),
            ],
          ),
        ),
        const Icon(Icons.chevron_right, color: Navi.tealDark),
      ],
    ),
  );
  Widget _combined(double width) {
    if (width < 700) {
      return Column(
        children: [
          SegmentedButton<bool>(
            segments: const [
              ButtonSegment(value: true, label: Text('Child')),
              ButtonSegment(value: false, label: Text('Parent')),
            ],
            selected: {combinedChild},
            onSelectionChanged: (v) => setState(() => combinedChild = v.first),
          ),
          const SizedBox(height: 20),
          if (combinedChild)
            ChildView(store: store)
          else
            ParentView(store: store),
        ],
      );
    }
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 110, right: 30),
          child: ChildView(store: store),
        ),
        ParentView(store: store),
      ],
    );
  }

  Widget _demoPanel() => ConstrainedBox(
    constraints: const BoxConstraints(maxWidth: 520),
    child: NaviCard(
      color: const Color(0xFFE7F5F3),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Demo controls',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: Navi.ink,
            ),
          ),
          const Text(
            'These actions simulate events; they do not call transport services.',
            style: TextStyle(fontSize: 12, color: Navi.secondary),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 4,
            children: [
              ActionChip(
                label: const Text('Start journey'),
                onPressed: store.start,
              ),
              ActionChip(
                label: const Text('Leave earlier'),
                onPressed: store.showLeaveEarlier,
              ),
              ActionChip(
                label: const Text('Relevant disruption'),
                onPressed: store.showReroute,
              ),
              ActionChip(
                label: const Text('Request help'),
                onPressed: store.requestHelp,
              ),
              ActionChip(
                label: const Text('Confirm arrival'),
                onPressed: store.confirmArrival,
              ),
              ActionChip(
                label: const Text('Location unavailable'),
                onPressed: () => store.setFailure(location: true),
              ),
              ActionChip(
                label: const Text('No suitable route'),
                onPressed: () => store.setFailure(route: true),
              ),
              ActionChip(
                label: const Text('Clear failure'),
                onPressed: () =>
                    store.setFailure(location: false, route: false),
              ),
              ActionChip(
                label: const Text('Reset demo'),
                onPressed: store.resetDemo,
              ),
            ],
          ),
        ],
      ),
    ),
  );
}
