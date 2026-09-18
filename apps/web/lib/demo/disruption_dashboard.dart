import 'package:flutter/material.dart';

import '../engine/reroute_engine.dart';
import '../models/conditions.dart';
import '../models/disruption.dart';
import '../models/route_models.dart';
import '../state/demo_store.dart';
import '../widgets/ui_kit.dart';

/// Operator panel for the demo: type a disruption in plain words, or tap a
/// preset, and watch the reroute land on the watch and the parent phone.
/// Nothing here calls LTA or OneMap.
class DisruptionDashboard extends StatefulWidget {
  const DisruptionDashboard({super.key, required this.store});
  final DemoStore store;
  @override
  State<DisruptionDashboard> createState() => _DisruptionDashboardState();
}

class _DisruptionDashboardState extends State<DisruptionDashboard> {
  final controller = TextEditingController();

  static const presets = <String>[
    'Red line delayed',
    'Red line closed',
    'Green line delayed 10 min',
    'Green line closed between Tampines and Bedok',
    'Bus 10 not running',
    'Bus 10 delayed 3 min',
    'Circle line crowded',
    'Heavy rain',
    'Purple line closed',
  ];

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  void _apply([String? text]) {
    final t = text ?? controller.text;
    if (widget.store.applyDisruptionText(t)) controller.clear();
  }

  @override
  Widget build(BuildContext context) {
    final store = widget.store;
    return NaviCard(
      color: const Color(0xFFFFF8EC),
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.tune, color: Navi.amber, size: 18),
              const SizedBox(width: 6),
              const Expanded(
                child: Text(
                  'Disruption dashboard',
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: Navi.ink),
                ),
              ),
              const SizedBox(width: 8),
              const DemoTag(),
              const SizedBox(width: 4),
              TextButton.icon(
                onPressed: store.resetDemo,
                icon: const Icon(Icons.restart_alt, size: 16),
                label: const Text('Reset demo'),
              ),
            ],
          ),
          const Text(
            'Type what an operator would say. NAVI checks it against the child’s remaining journey and, when it matters, asks OneMap for new itineraries from where the child actually is.',
            style: TextStyle(fontSize: 11.5, color: Navi.secondary),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 4,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: store.activeRoute.live ? Navi.tealDark.withAlpha(24) : Navi.muted.withAlpha(24),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  'Routes: ${store.routeSource}',
                  style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w800, color: store.activeRoute.live ? Navi.tealDark : Navi.muted),
                ),
              ),
              OutlinedButton.icon(
                onPressed: store.pullLtaAlerts,
                icon: const Icon(Icons.train, size: 14),
                label: const Text('Pull live LTA train alerts', style: TextStyle(fontSize: 11)),
                style: OutlinedButton.styleFrom(visualDensity: VisualDensity.compact),
              ),
              OutlinedButton.icon(
                onPressed: store.refreshWeather,
                icon: const Icon(Icons.cloud_outlined, size: 14),
                label: const Text('Pull live weather (data.gov.sg)', style: TextStyle(fontSize: 11)),
                style: OutlinedButton.styleFrom(visualDensity: VisualDensity.compact),
              ),
              OutlinedButton.icon(
                onPressed: () {
                  final line = store.activeRoute.legs.firstWhere((l) => l.mode == LegMode.rail, orElse: () => store.activeRoute.legs.first).lineId;
                  if (line != null) store.refreshCrowding(line);
                },
                icon: const Icon(Icons.groups_outlined, size: 14),
                label: const Text('Pull live LTA crowding', style: TextStyle(fontSize: 11)),
                style: OutlinedButton.styleFrom(visualDensity: VisualDensity.compact),
              ),
              if (store.busy != null)
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const SizedBox(width: 12, height: 12, child: CircularProgressIndicator(strokeWidth: 2)),
                    const SizedBox(width: 6),
                    Text(store.busy!, style: const TextStyle(fontSize: 11, color: Navi.tealDark)),
                  ],
                ),
            ],
          ),
          if (store.ltaStatus != null)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(store.ltaStatus!, style: const TextStyle(fontSize: 11, color: Navi.secondary)),
            ),
          if (store.weatherStatus != null)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(store.weatherStatus!, style: const TextStyle(fontSize: 11, color: Navi.secondary)),
            ),
          if (store.crowding != null)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                'LTA crowding ${store.crowding!.lineId}: ${store.crowding!.levels.entries.where((e) => e.value == CrowdLevel.high).length} high, ${store.crowding!.levels.entries.where((e) => e.value == CrowdLevel.moderate).length} moderate, ${store.crowding!.levels.entries.where((e) => e.value == CrowdLevel.low).length} low',
                style: const TextStyle(fontSize: 11, color: Navi.secondary),
              ),
            ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: controller,
                  onSubmitted: (_) => _apply(),
                  decoration: InputDecoration(
                    hintText: 'e.g. "red line delayed 10 min"',
                    isDense: true,
                    errorText: store.dashboardError,
                    prefixIcon: const Icon(Icons.campaign_outlined, size: 18),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              FilledButton(
                onPressed: _apply,
                style: FilledButton.styleFrom(minimumSize: const Size(90, 44), backgroundColor: Navi.amber),
                child: const Text('Inject'),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 6,
            runSpacing: 4,
            children: [
              for (final p in presets)
                ActionChip(
                  label: Text(p, style: const TextStyle(fontSize: 11)),
                  visualDensity: VisualDensity.compact,
                  onPressed: () => _apply(p),
                ),
            ],
          ),
          const SizedBox(height: 12),
          const SectionLabel('Scripted scenarios'),
          Wrap(
            spacing: 6,
            runSpacing: 4,
            children: [
              for (final entry in DemoStore.scenarios.entries)
                ActionChip(
                  avatar: const Icon(Icons.play_arrow, size: 14, color: Navi.tealDark),
                  label: Text(entry.value, style: const TextStyle(fontSize: 11)),
                  visualDensity: VisualDensity.compact,
                  onPressed: () => store.runScenario(entry.key),
                ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              const SectionLabel('Active conditions'),
              const Spacer(),
              if (store.disruptions.isNotEmpty)
                TextButton(onPressed: store.clearDisruptions, child: const Text('Clear all', style: TextStyle(fontSize: 11))),
            ],
          ),
          if (store.disruptions.isEmpty)
            const Text('None. The network is running normally.', style: TextStyle(fontSize: 12, color: Navi.muted)),
          for (final d in store.disruptions) _condition(d),
          const SizedBox(height: 10),
          const SectionLabel('Child limits used by the engine'),
          Wrap(
            spacing: 10,
            runSpacing: 6,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              _limit('Max walk / leg', [10, 12, 15, 20], store.limits.maxWalkMinutesPerLeg,
                  (v) => store.setLimits(store.limits.copyWith(maxWalkMinutesPerLeg: v)), suffix: 'min'),
              _limit('Max transfers', [0, 1, 2, 3], store.limits.maxTransfers,
                  (v) => store.setLimits(store.limits.copyWith(maxTransfers: v))),
              _limit('Alert threshold', [3, 5, 8, 10], store.limits.alertThresholdMinutes,
                  (v) => store.setLimits(store.limits.copyWith(alertThresholdMinutes: v)), suffix: 'min'),
            ],
          ),
          if (store.decision != null) ...[
            const SizedBox(height: 12),
            const SectionLabel('Latest decision'),
            _decision(store.decision!),
          ],
        ],
      ),
    );
  }

  Widget _condition(Disruption d) {
    final store = widget.store;
    final decision = store.decision;
    final drove = decision != null && decision.disruption.id == d.id;
    final badge = drove
        ? switch (decision.action) {
            DecisionAction.reroute => 'REROUTED AROUND',
            DecisionAction.info => 'INFO ONLY',
            DecisionAction.keep => 'NOT RELEVANT',
            _ => decision.action.name.toUpperCase(),
          }
        : store.remainingLegs.any(d.affects)
        ? 'RELEVANT'
        : 'NOT RELEVANT';
    final relevant = badge != 'NOT RELEVANT';
    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: relevant ? Navi.amber.withAlpha(140) : const Color(0xFFE4EFEC)),
      ),
      child: Row(
        children: [
          Icon(
            switch (d.kind) {
              DisruptionKind.delay => Icons.schedule,
              DisruptionKind.closure => Icons.block,
              DisruptionKind.crowding => Icons.groups,
              DisruptionKind.weather => Icons.umbrella,
            },
            size: 18,
            color: relevant ? Navi.amber : Navi.muted,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(d.summary, style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w800, color: Navi.ink)),
                Text('“${d.rawInput}” · ${hhmm(d.issuedAtMinutes)}${d.simulated ? '' : ' · LIVE'}', style: const TextStyle(fontSize: 10.5, color: Navi.muted)),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
            decoration: BoxDecoration(
              color: (relevant ? Navi.amber : Navi.muted).withAlpha(24),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              badge,
              style: TextStyle(fontSize: 9, fontWeight: FontWeight.w800, color: relevant ? Navi.amber : Navi.muted),
            ),
          ),
          IconButton(
            onPressed: () => store.removeDisruption(d),
            icon: const Icon(Icons.close, size: 16),
            visualDensity: VisualDensity.compact,
            tooltip: 'Resolve',
          ),
        ],
      ),
    );
  }

  Widget _limit(String label, List<int> options, int value, ValueChanged<int> onChanged, {String suffix = ''}) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Text('$label ', style: const TextStyle(fontSize: 11, color: Navi.secondary)),
      DropdownButton<int>(
        value: value,
        isDense: true,
        style: const TextStyle(fontSize: 12, color: Navi.ink, fontWeight: FontWeight.w700),
        items: [for (final o in options) DropdownMenuItem(value: o, child: Text('$o $suffix'.trim()))],
        onChanged: (v) => v == null ? null : onChanged(v),
      ),
    ],
  );

  Widget _decision(RerouteDecision d) {
    final colour = switch (d.action) {
      DecisionAction.keep => Navi.muted,
      DecisionAction.info => Navi.tealDark,
      DecisionAction.reroute => Navi.amber,
      DecisionAction.delay || DecisionAction.leaveEarlier => Navi.amber,
      DecisionAction.holdAboard || DecisionAction.noRoute => Navi.red,
    };
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: colour.withAlpha(120)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(color: colour, borderRadius: BorderRadius.circular(8)),
                child: Text(d.action.name.toUpperCase(), style: const TextStyle(fontSize: 10, color: Colors.white, fontWeight: FontWeight.w900)),
              ),
              const SizedBox(width: 8),
              Expanded(child: Text(d.disruption.summary, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700))),
            ],
          ),
          const SizedBox(height: 6),
          Text(d.reason, style: const TextStyle(fontSize: 11.5, color: Navi.secondary)),
          if (d.alternative != null) ...[
            const SizedBox(height: 4),
            Text('Chosen: ${d.alternative!.summary} · ${d.alternative!.totalMinutes} min · ${d.alternative!.transfers} transfer(s)',
                style: const TextStyle(fontSize: 11.5, color: Navi.ink, fontWeight: FontWeight.w700)),
          ],
          for (final r in d.rejected)
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Text('✗ ${r.candidate.summary}: ${r.why}', style: const TextStyle(fontSize: 11, color: Navi.muted)),
            ),
          const SizedBox(height: 6),
          Row(
            children: [
              const Icon(Icons.watch_outlined, size: 13, color: Navi.tealDark),
              const SizedBox(width: 4),
              Expanded(child: Text(d.childTitle.isEmpty ? 'Watch: nothing shown (suppressed)' : 'Watch: ${d.childTitle} — ${d.childMessage}', style: const TextStyle(fontSize: 11))),
            ],
          ),
          Row(
            children: [
              const Icon(Icons.phone_iphone, size: 13, color: Navi.tealDark),
              const SizedBox(width: 4),
              Expanded(child: Text('Phone: ${d.parentTitle} — ${d.parentMessage}', style: const TextStyle(fontSize: 11))),
            ],
          ),
        ],
      ),
    );
  }
}
