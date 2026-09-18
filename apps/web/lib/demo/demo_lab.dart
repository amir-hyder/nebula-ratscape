import 'package:flutter/material.dart';

import '../screens/child_view.dart';
import '../screens/parent_view.dart';
import '../state/demo_store.dart';
import '../widgets/ui_kit.dart';
import 'disruption_dashboard.dart';
import 'flow_trace.dart';

/// Presentation layout: child watch on the left, parent phone on the right,
/// and between them the signal flow plus the disruption dashboard.
class DemoLab extends StatefulWidget {
  const DemoLab({super.key, required this.store, required this.width});
  final DemoStore store;
  final double width;
  @override
  State<DemoLab> createState() => _DemoLabState();
}

class _DemoLabState extends State<DemoLab> {
  int tab = 0;

  @override
  Widget build(BuildContext context) {
    final store = widget.store;
    final w = widget.width;
    if (w >= 1180) {
      return SizedBox(
        height: 820,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(top: 40, right: 18),
              child: Column(
                children: [
                  ChildView(store: store),
                  const SizedBox(height: 14),
                  _childHint(),
                ],
              ),
            ),
            Expanded(
              child: Column(
                children: [
                  Expanded(child: FlowTrace(store: store)),
                  const SizedBox(height: 12),
                  Flexible(
                    flex: 0,
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxHeight: 420),
                      child: SingleChildScrollView(child: DisruptionDashboard(store: store)),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 18),
            ParentView(store: store),
          ],
        ),
      );
    }
    if (w >= 720) {
      return Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.only(top: 110, right: 24),
                child: ChildView(store: store),
              ),
              ParentView(store: store),
            ],
          ),
          const SizedBox(height: 18),
          DisruptionDashboard(store: store),
          const SizedBox(height: 18),
          SizedBox(height: 520, child: FlowTrace(store: store)),
        ],
      );
    }
    return Column(
      children: [
        SegmentedButton<int>(
          segments: const [
            ButtonSegment(value: 0, label: Text('Child')),
            ButtonSegment(value: 1, label: Text('Parent')),
            ButtonSegment(value: 2, label: Text('Inject')),
            ButtonSegment(value: 3, label: Text('Flow')),
          ],
          style: const ButtonStyle(visualDensity: VisualDensity.compact),
          selected: {tab},
          showSelectedIcon: false,
          onSelectionChanged: (v) => setState(() => tab = v.first),
        ),
        const SizedBox(height: 18),
        switch (tab) {
          0 => ChildView(store: store),
          1 => ParentView(store: store),
          2 => DisruptionDashboard(store: store),
          _ => SizedBox(height: 560, child: FlowTrace(store: store)),
        },
      ],
    );
  }

  Widget _childHint() => SizedBox(
    width: 240,
    child: NaviCard(
      padding: const EdgeInsets.all(12),
      color: const Color(0xFFE7F5F3),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: const [
          Text('Try on the watch', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: Navi.tealDark)),
          SizedBox(height: 4),
          Text(
            '1. Start Journey and step through.\n'
            '2. Tap “Need help?” → “Someone is scaring me”.\n'
            '3. Inject “Red line delayed” below while going to Grandma.',
            style: TextStyle(fontSize: 11, color: Navi.secondary, height: 1.35),
          ),
        ],
      ),
    ),
  );
}
