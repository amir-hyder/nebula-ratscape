import '../models/disruption.dart';
import '../models/route_models.dart';

/// What the coordinator decided after checking conditions against a journey.
/// Mirrors `JourneyDecision.action` in the backend contract with two extra
/// demo-only actions (`info`, `holdAboard`).
enum DecisionAction {
  /// Nothing on the remaining journey is affected.
  keep,

  /// Affected, but too small to act on. Shown quietly, never as an alert.
  info,

  /// A validated alternative replaces the remaining legs.
  reroute,

  /// Stay on the same route; it now takes longer.
  delay,

  /// Not started yet and the delay eats the buffer: leave earlier.
  leaveEarlier,

  /// Child is aboard the affected vehicle. Give a calm holding instruction.
  holdAboard,

  /// No usable alternative. Escalate to the parent.
  noRoute,
}

class RerouteDecision {
  const RerouteDecision({
    required this.action,
    required this.original,
    required this.disruption,
    required this.reason,
    required this.childTitle,
    required this.childMessage,
    required this.parentTitle,
    required this.parentMessage,
    this.alternative,
    this.affectedLegIndex = -1,
    this.addedMinutes = 0,
    this.rejected = const [],
  });
  final DecisionAction action;
  final RouteCandidate original;
  final RouteCandidate? alternative;
  final Disruption disruption;
  final int affectedLegIndex;
  final int addedMinutes;

  /// Engineering explanation for the demo trace.
  final String reason;
  final String childTitle;
  final String childMessage;
  final String parentTitle;
  final String parentMessage;

  /// Candidates considered and why they lost; shown in the dashboard.
  final List<RejectedCandidate> rejected;

  bool get isAlert =>
      action == DecisionAction.reroute ||
      action == DecisionAction.leaveEarlier ||
      action == DecisionAction.holdAboard ||
      action == DecisionAction.noRoute ||
      action == DecisionAction.delay;
  bool get changesRoute => action == DecisionAction.reroute;
}

class RejectedCandidate {
  const RejectedCandidate(this.candidate, this.why);
  final RouteCandidate candidate;
  final String why;
}

/// Where the child is on the route right now.
class JourneyPosition {
  const JourneyPosition({
    required this.legIndex,
    required this.aboard,
    required this.started,
  });
  final int legIndex;
  /// True while riding the transit leg at [legIndex].
  final bool aboard;
  final bool started;

  /// Number of legs that can no longer be changed.
  int get lockedLegs => !started ? 0 : (aboard ? legIndex + 1 : legIndex);
}

/// Pure decision logic. No Flutter, no I/O, so it is unit-testable and can be
/// ported to the TypeScript coordinator later.
class RerouteEngine {
  const RerouteEngine({this.limits = const ChildLimits()});
  final ChildLimits limits;

  /// Evaluates [disruption] (plus any other [active] ones for validating the
  /// alternative) against the child's current route.
  RerouteDecision evaluate({
    required RouteCandidate route,
    required List<RouteCandidate> candidates,
    required Disruption disruption,
    required List<Disruption> active,
    required JourneyPosition position,
    required int nowMinutes,
    required int requiredArrivalMinutes,
    required int bufferMinutes,
    int? remainingMinutesNow,
  }) {
    final start = position.started ? position.legIndex : 0;
    final etaNow = nowMinutes + (remainingMinutesNow ?? route.remainingMinutes(start));
    var affected = -1;
    for (var i = start; i < route.legs.length; i++) {
      if (disruption.affects(route.legs[i])) {
        affected = i;
        break;
      }
    }

    if (affected == -1) {
      return RerouteDecision(
        action: DecisionAction.keep,
        original: route,
        disruption: disruption,
        reason:
            'Checked ${route.legs.length - start} remaining leg(s); none use ${disruption.targetLabel}.',
        childTitle: '',
        childMessage: '',
        parentTitle: 'Checked: not relevant',
        parentMessage:
            '${disruption.summary} does not touch the remaining journey. No change.',
      );
    }

    final leg = route.legs[affected];

    if (disruption.kind == DisruptionKind.weather) {
      return RerouteDecision(
        action: DecisionAction.info,
        original: route,
        disruption: disruption,
        affectedLegIndex: affected,
        reason: 'Weather touches walking legs; route stays, advice only.',
        childTitle: 'Rain today ☔',
        childMessage: 'Bring your umbrella. Walk carefully.',
        parentTitle: 'Heavy rain on the walk',
        parentMessage:
            'Walking legs are affected. Route unchanged; NAVI reminded the child about an umbrella.',
      );
    }

    if (disruption.kind == DisruptionKind.crowding) {
      return RerouteDecision(
        action: DecisionAction.info,
        original: route,
        disruption: disruption,
        affectedLegIndex: affected,
        reason: 'Crowding does not change timing enough to reroute.',
        childTitle: 'Very crowded 🚉',
        childMessage: 'Stand near the door. Hold the pole.',
        parentTitle: 'Crowded ${leg.label}',
        parentMessage:
            '${disruption.summary}. Route unchanged; the child was told to stand near the door.',
      );
    }

    final delay = disruption.kind == DisruptionKind.closure
        ? null
        : disruption.delayMinutes;

    if (delay != null && delay < limits.alertThresholdMinutes) {
      return RerouteDecision(
        action: DecisionAction.info,
        original: route,
        disruption: disruption,
        affectedLegIndex: affected,
        addedMinutes: delay,
        reason:
            'Delay of $delay min is below the ${limits.alertThresholdMinutes} min alert threshold. Suppressed.',
        childTitle: '',
        childMessage: '',
        parentTitle: 'Small delay, no alert',
        parentMessage:
            '${leg.label} is $delay min late. Below the alert threshold, so the child was not disturbed.',
      );
    }

    // Child is aboard the very vehicle that is affected.
    if (position.started && position.aboard && position.legIndex == affected) {
      if (delay == null) {
        return RerouteDecision(
          action: DecisionAction.holdAboard,
          original: route,
          disruption: disruption,
          affectedLegIndex: affected,
          reason: 'Child is aboard the affected ${leg.vehicleWord}; cannot reroute from origin.',
          childTitle: '${leg.vehicleWord == 'train' ? '🚆' : '🚌'} Stop coming',
          childMessage:
              'Get off at the next ${leg.stopWord}. Wait there. Find a staff member. Mum has been told.',
          parentTitle: '${leg.label} stopped while the child is aboard',
          parentMessage:
              '${disruption.summary}. The child was told to alight at the next ${leg.stopWord} and wait for staff. Please call.',
        );
      }
      return RerouteDecision(
        action: DecisionAction.delay,
        original: route,
        disruption: disruption,
        affectedLegIndex: affected,
        addedMinutes: delay,
        reason: 'Aboard the delayed vehicle; staying on is the only actionable option.',
        childTitle: '⏱️ ${leg.vehicleWord[0].toUpperCase()}${leg.vehicleWord.substring(1)} is late',
        childMessage: 'Stay on the ${leg.vehicleWord}. It is $delay minutes late. That is okay.',
        parentTitle: '${leg.label} running $delay min late',
        parentMessage:
            'The child is aboard. New estimated arrival is ${hhmm(etaNow + delay)}.',
      );
    }

    // Look for an alternative the child can actually act on from here.
    final locked = position.lockedLegs;
    final rejected = <RejectedCandidate>[];
    RouteCandidate? best;
    var bestScore = 1 << 30;
    for (final c in candidates) {
      if (c.id == route.id) continue;
      if (!c.sharesPrefixWith(route, locked)) {
        rejected.add(RejectedCandidate(c, 'starts from a place the child has already passed'));
        continue;
      }
      final hit = active.any((d) =>
          d.kind != DisruptionKind.weather &&
          d.kind != DisruptionKind.crowding &&
          c.legs.skip(locked).any(d.affects));
      if (hit) {
        rejected.add(RejectedCandidate(c, 'also affected by an active disruption'));
        continue;
      }
      if (c.longestWalk > limits.maxWalkMinutesPerLeg) {
        rejected.add(RejectedCandidate(c, 'walk of ${c.longestWalk} min exceeds the ${limits.maxWalkMinutesPerLeg} min child limit'));
        continue;
      }
      if (c.transfers > limits.maxTransfers) {
        rejected.add(RejectedCandidate(c, '${c.transfers} transfers exceed the limit of ${limits.maxTransfers}'));
        continue;
      }
      final score = c.remainingMinutes(locked) +
          c.transfers * limits.transferPenaltyMinutes +
          (c.walkMinutes ~/ 2);
      if (score < bestScore) {
        bestScore = score;
        best = c;
      }
    }

    final remainingOriginal = route.remainingMinutes(locked);
    final originalScore = delay == null
        ? 1 << 29
        : remainingOriginal + delay + route.transfers * limits.transferPenaltyMinutes + (route.walkMinutes ~/ 2);
    final deadline = requiredArrivalMinutes - bufferMinutes;

    if (best != null && bestScore < originalScore) {
      final altEta = etaNow - remainingOriginal + best.remainingMinutes(locked);
      // First leg that differs from the original: that is the child's new step.
      var diff = locked;
      while (diff < best.legs.length &&
          diff < route.legs.length &&
          best.legs[diff].samePlaceAs(route.legs[diff])) {
        diff++;
      }
      if (diff >= best.legs.length) diff = best.legs.length - 1;
      final firstNew = best.legs[diff];
      final childStep = diff > locked
          ? 'Same way until ${firstNew.from}. Then ${firstNew.childLabel}.'
          : locked > 0
          ? 'Get off at ${route.legs[locked - 1].to} like before. Then ${firstNew.childLabel}.'
          : '${firstNew.childLabel}.';
      final rest = best.legs.skip(locked).map((l) => l.label).join(' → ');
      return RerouteDecision(
        action: DecisionAction.reroute,
        original: route,
        alternative: best,
        disruption: disruption,
        affectedLegIndex: affected,
        addedMinutes: altEta - etaNow,
        rejected: rejected,
        reason:
            'Alternative ${best.id} scores $bestScore vs ${delay == null ? 'no service' : '$originalScore'} for staying. Prefix of $locked leg(s) kept.',
        childTitle: '🔀 New way to go',
        childMessage: '${_childWhy(disruption, leg)} $childStep',
        parentTitle: 'Route changed automatically',
        parentMessage:
            '${disruption.summary}. New route: $rest. Estimated arrival ${hhmm(altEta)} (was ${hhmm(etaNow)}). No approval needed; the child already sees the new step.',
      );
    }

    if (delay != null) {
      final newEta = etaNow + delay;
      if (!position.started && newEta > deadline) {
        return RerouteDecision(
          action: DecisionAction.leaveEarlier,
          original: route,
          disruption: disruption,
          affectedLegIndex: affected,
          addedMinutes: delay,
          rejected: rejected,
          reason:
              'No better alternative. Delay pushes arrival to ${hhmm(newEta)}, past the ${hhmm(deadline)} deadline (buffer $bufferMinutes min). Leave $delay min earlier.',
          childTitle: '⏰ Leave earlier',
          childMessage: 'The ${leg.vehicleWord} is late today. Leave $delay minutes earlier.',
          parentTitle: 'Leave $delay min earlier',
          parentMessage:
              '${disruption.summary}. Same route, but leaving at ${hhmm(nowMinutes - delay)} keeps the ${hhmm(requiredArrivalMinutes)} arrival.',
        );
      }
      return RerouteDecision(
        action: DecisionAction.delay,
        original: route,
        disruption: disruption,
        affectedLegIndex: affected,
        addedMinutes: delay,
        rejected: rejected,
        reason:
            'No alternative beats waiting $delay min. Arrival ${hhmm(newEta)} still within the ${hhmm(deadline)} deadline.',
        childTitle: '⏱️ ${leg.label} is late',
        childMessage: 'Your ${leg.vehicleWord} is $delay minutes late. Wait at the ${leg.stopWord}. That is okay.',
        parentTitle: '${leg.label} running $delay min late',
        parentMessage:
            '${disruption.summary}. Staying on the same route; new estimated arrival ${hhmm(newEta)}.',
      );
    }

    return RerouteDecision(
      action: DecisionAction.noRoute,
      original: route,
      disruption: disruption,
      affectedLegIndex: affected,
      rejected: rejected,
      reason: 'Closure with no child-suitable alternative from the current position.',
      childTitle: '🛑 Wait for help',
      childMessage: 'The ${leg.vehicleWord} is not running. Stay at the ${leg.stopWord}. Mum has been told.',
      parentTitle: 'No suitable route',
      parentMessage:
          '${disruption.summary}. No child-suitable alternative from ${leg.from}. Please call the child.',
    );
  }

  static String _childWhy(Disruption d, RouteLeg leg) =>
      d.kind == DisruptionKind.closure
      ? 'The ${leg.vehicleWord} is not running.'
      : 'The ${leg.vehicleWord} is very late.';
}
