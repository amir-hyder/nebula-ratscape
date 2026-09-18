import 'package:flutter/material.dart';

import '../models/signals.dart';
import '../models/route_models.dart';
import '../state/demo_store.dart';
import '../widgets/ui_kit.dart';

/// The middle column of the demo lab: every hop between the child watch,
/// the NAVI engine, the disruption dashboard and the parent phone, newest
/// first. This is what makes "child taps → parent sees" visible on stage.
class FlowTrace extends StatelessWidget {
  const FlowTrace({super.key, required this.store});
  final DemoStore store;

  static const _actorLabel = {
    FlowActor.child: 'Child watch',
    FlowActor.engine: 'NAVI engine',
    FlowActor.parent: 'Parent phone',
    FlowActor.dashboard: 'Dashboard',
  };
  static const _actorIcon = {
    FlowActor.child: Icons.watch_outlined,
    FlowActor.engine: Icons.psychology_outlined,
    FlowActor.parent: Icons.phone_iphone,
    FlowActor.dashboard: Icons.tune,
  };

  static Color kindColour(FlowKind k) => switch (k) {
    FlowKind.signal => Navi.red,
    FlowKind.disruption => Navi.amber,
    FlowKind.decision => const Color(0xFF6D28D9),
    FlowKind.notification => Navi.tealDark,
    FlowKind.reply => const Color(0xFF1D4ED8),
    FlowKind.info => Navi.muted,
  };

  @override
  Widget build(BuildContext context) => NaviCard(
    padding: const EdgeInsets.all(14),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Text('Signal flow', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: Navi.ink)),
            const SizedBox(width: 8),
            const DemoTag(),
            const Spacer(),
            Text('${store.flow.length} hops', style: const TextStyle(fontSize: 11, color: Navi.muted)),
          ],
        ),
        const SizedBox(height: 10),
        _pipeline(),
        const SizedBox(height: 10),
        Expanded(
          child: store.flow.isEmpty
              ? const Center(
                  child: Text(
                    'Nothing yet. Tap something on the watch, or inject a disruption below.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Navi.muted, fontSize: 12),
                  ),
                )
              : ListView.builder(
                  itemCount: store.flow.length,
                  itemBuilder: (context, i) => _hop(store.flow[i], highlight: i == 0),
                ),
        ),
      ],
    ),
  );

  /// Static picture of who talks to whom, with the node of the latest hop lit.
  Widget _pipeline() {
    final latest = store.flow.isEmpty ? null : store.flow.first;
    Widget node(FlowActor a) {
      final lit = latest != null && (latest.from == a || latest.to == a);
      return AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
        decoration: BoxDecoration(
          color: lit ? Navi.tealDark : const Color(0xFFE7F5F3),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(_actorIcon[a], size: 14, color: lit ? Colors.white : Navi.tealDark),
            const SizedBox(width: 4),
            Text(
              _actorLabel[a]!,
              style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w800, color: lit ? Colors.white : Navi.tealDark),
            ),
          ],
        ),
      );
    }

    const arrow = Padding(
      padding: EdgeInsets.symmetric(horizontal: 4),
      child: Icon(Icons.sync_alt, size: 14, color: Navi.muted),
    );
    return Wrap(
      crossAxisAlignment: WrapCrossAlignment.center,
      runSpacing: 6,
      children: [
        node(FlowActor.child),
        arrow,
        node(FlowActor.engine),
        arrow,
        node(FlowActor.parent),
        const SizedBox(width: 10),
        const Icon(Icons.subdirectory_arrow_left, size: 14, color: Navi.muted),
        node(FlowActor.dashboard),
      ],
    );
  }

  Widget _hop(FlowEvent e, {required bool highlight}) {
    final colour = kindColour(e.kind);
    return TweenAnimationBuilder<double>(
      key: ValueKey(e.seq),
      tween: Tween(begin: highlight ? 0 : 1, end: 1),
      duration: const Duration(milliseconds: 500),
      builder: (context, t, child) => Opacity(
        opacity: .4 + .6 * t,
        child: Transform.translate(offset: Offset(0, (1 - t) * -8), child: child),
      ),
      child: Container(
        margin: const EdgeInsets.only(bottom: 6),
        padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
        decoration: BoxDecoration(
          color: highlight ? colour.withAlpha(16) : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: highlight ? colour.withAlpha(120) : const Color(0xFFE4EFEC)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(_actorIcon[e.from], size: 13, color: colour),
                const SizedBox(width: 3),
                Text(_actorLabel[e.from]!, style: TextStyle(fontSize: 10, color: colour, fontWeight: FontWeight.w800)),
                if (e.from != e.to) ...[
                  Icon(Icons.arrow_forward, size: 12, color: colour),
                  Icon(_actorIcon[e.to], size: 13, color: colour),
                  const SizedBox(width: 3),
                  Text(_actorLabel[e.to]!, style: TextStyle(fontSize: 10, color: colour, fontWeight: FontWeight.w800)),
                ],
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(color: colour.withAlpha(22), borderRadius: BorderRadius.circular(8)),
                  child: Text(e.kind.name, style: TextStyle(fontSize: 9, color: colour, fontWeight: FontWeight.w800)),
                ),
                const SizedBox(width: 6),
                Text(hhmm(e.atMinutes), style: const TextStyle(fontSize: 10, color: Navi.muted)),
              ],
            ),
            const SizedBox(height: 3),
            Text(e.title, style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w800, color: Navi.ink)),
            Text(e.detail, style: const TextStyle(fontSize: 11, color: Navi.secondary, height: 1.3)),
          ],
        ),
      ),
    );
  }
}
