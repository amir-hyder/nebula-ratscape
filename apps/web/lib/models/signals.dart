// Child → parent communication models for the demo lab.
// A [ChildSignal] is a single tap on the watch; the engine turns it into a
// [ParentAlert] and a reassurance line for the child.

import 'conditions.dart';

enum ChildSignalKind { scared, lost, missedStop, unwell, checkIn }

extension ChildSignalKindX on ChildSignalKind {
  /// Button text on the watch. Short words a 7-year-old can read.
  String get childButton => switch (this) {
    ChildSignalKind.scared => 'Someone is scaring me',
    ChildSignalKind.lost => 'I am lost',
    ChildSignalKind.missedStop => 'I missed my stop',
    ChildSignalKind.unwell => 'I feel sick',
    ChildSignalKind.checkIn => 'Just saying hi',
  };
  String get emoji => switch (this) {
    ChildSignalKind.scared => '😨',
    ChildSignalKind.lost => '🧭',
    ChildSignalKind.missedStop => '🚌',
    ChildSignalKind.unwell => '🤒',
    ChildSignalKind.checkIn => '👋',
  };
}

enum Urgency { critical, high, normal }

class ChildSignal {
  const ChildSignal({
    required this.kind,
    required this.atMinutes,
    required this.stageLabel,
    required this.locationLabel,
  });
  final ChildSignalKind kind;
  final int atMinutes;
  final String stageLabel;
  final String locationLabel;
}

class ParentAlert {
  ParentAlert({
    required this.id,
    required this.kind,
    required this.urgency,
    required this.title,
    required this.detail,
    required this.suggestedActions,
    required this.childReassurance,
    required this.atMinutes,
  });
  final String id;
  final ChildSignalKind kind;
  final Urgency urgency;
  final String title;
  final String detail;
  final List<String> suggestedActions;
  /// What the watch shows the child right after they tap.
  final String childReassurance;
  final int atMinutes;
  bool acknowledged = false;

  /// Nearest staffed place from OpenStreetMap, filled in asynchronously.
  OsmFeature? safePlace;

  String get childReassuranceLive => safePlace == null
      ? childReassurance
      : '$childReassurance\nGo to ${safePlace!.name} (${safePlace!.distanceM} m).';
}

/// A short message a parent sends back; shown big on the watch.
class ParentReply {
  const ParentReply({required this.text, required this.atMinutes});
  final String text;
  final int atMinutes;
}

/// Who produced or received a message in the demo pipeline.
enum FlowActor { child, engine, parent, dashboard }

enum FlowKind { signal, decision, notification, disruption, reply, info }

/// One hop in the visualised pipeline (left → right in the demo lab).
class FlowEvent {
  const FlowEvent({
    required this.seq,
    required this.from,
    required this.to,
    required this.kind,
    required this.title,
    required this.detail,
    required this.atMinutes,
  });
  final int seq;
  final FlowActor from;
  final FlowActor to;
  final FlowKind kind;
  final String title;
  final String detail;
  final int atMinutes;
}
