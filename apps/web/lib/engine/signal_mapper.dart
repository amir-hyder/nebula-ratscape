import '../models/signals.dart';

/// Turns a child's tap into what the parent sees and what the child reads.
/// Wording is deliberately plain: the child reader is 7 to 12 years old and
/// the parent may be reading in a hurry.
abstract final class SignalMapper {
  static const childName = 'Maya';

  static ParentAlert map(ChildSignal s, {required String id}) {
    switch (s.kind) {
      case ChildSignalKind.scared:
        return ParentAlert(
          id: id,
          kind: s.kind,
          urgency: Urgency.critical,
          title: '$childName feels unsafe',
          detail:
              '$childName pressed "Someone is scaring me" while ${s.stageLabel} near ${s.locationLabel}. '
              'NAVI told her to stay near other people and go to staff or a shop.',
          suggestedActions: const [
            'Call $childName now',
            'Call the school office',
            'Share location with Dad',
          ],
          childReassurance:
              'Stay near other people.\nGo to a shop or a staff member.\nMum has been told. 💚',
          atMinutes: s.atMinutes,
        );
      case ChildSignalKind.lost:
        return ParentAlert(
          id: id,
          kind: s.kind,
          urgency: Urgency.high,
          title: '$childName thinks she is lost',
          detail:
              'Pressed "I am lost" while ${s.stageLabel}. Last known place: ${s.locationLabel}. '
              'NAVI asked her to stay put and look for a bus stop sign.',
          suggestedActions: const [
            'Call $childName',
            'Open last known location',
          ],
          childReassurance:
              'Stay where you are.\nLook for a bus stop sign.\nMum knows where you are. 💚',
          atMinutes: s.atMinutes,
        );
      case ChildSignalKind.missedStop:
        return ParentAlert(
          id: id,
          kind: s.kind,
          urgency: Urgency.high,
          title: '$childName missed her stop',
          detail:
              'Pressed "I missed my stop" while ${s.stageLabel}. NAVI told her to get off at the next stop and wait; a new route will follow.',
          suggestedActions: const [
            'Call $childName',
            'Watch for the new route',
          ],
          childReassurance:
              'Get off at the next stop.\nWait there.\nNAVI is finding a new way. 💚',
          atMinutes: s.atMinutes,
        );
      case ChildSignalKind.unwell:
        return ParentAlert(
          id: id,
          kind: s.kind,
          urgency: Urgency.high,
          title: '$childName feels unwell',
          detail:
              'Pressed "I feel sick" while ${s.stageLabel} near ${s.locationLabel}. NAVI told her to sit down and drink water.',
          suggestedActions: const [
            'Call $childName',
            'Call the school office',
          ],
          childReassurance:
              'Sit down somewhere safe.\nDrink some water.\nMum has been told. 💚',
          atMinutes: s.atMinutes,
        );
      case ChildSignalKind.checkIn:
        return ParentAlert(
          id: id,
          kind: s.kind,
          urgency: Urgency.normal,
          title: '$childName says hi 👋',
          detail: 'Check-in while ${s.stageLabel} near ${s.locationLabel}. All good.',
          suggestedActions: const ['Wave back'],
          childReassurance: 'Mum saw your wave. 👋',
          atMinutes: s.atMinutes,
        );
    }
  }

  /// Quick replies a parent can send from the alert card.
  static const parentQuickReplies = <String>[
    'I am calling you now 📞',
    'Stay there, I am coming 🚗',
    'You are doing great, keep going 👍',
    'Ask someone in uniform 🧑‍✈️',
  ];
}
