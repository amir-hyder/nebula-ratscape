// Journey, destination and notification models shared by all views.

import '../engine/geo.dart';

enum ChildScreen {
  home,
  destinations,
  route,
  loading,
  walk,
  waiting,
  onboard,
  reaching,
  finalWalk,
  arrival,
  confirmed,
  help, // help menu with signal buttons
  helpSent, // reassurance after a signal
  message, // parent reply
  unavailable,
  noRoute,
  alert, // engine decision
}

enum ParentScreen {
  dashboard,
  destinations,
  notifications,
  destinationDetails,
  destinationForm,
  journeyDetails,
}

enum JourneyPhase {
  idle,
  walking,
  waiting,
  onboard,
  reaching,
  finalWalk,
  awaitingConfirmation,
  arrived,
}

class ArrivalSchedule {
  ArrivalSchedule({
    required this.id,
    required this.days,
    required this.arrivalTime,
    this.bufferMinutes = 10,
  });
  final String id;
  final List<String> days;
  String arrivalTime;
  int bufferMinutes;
}

class Destination {
  Destination({
    required this.id,
    required this.name,
    required this.address,
    required this.emoji,
    required this.schedules,
    this.location,
  });
  final String id;
  String name;
  String address;
  String emoji;
  List<ArrivalSchedule> schedules;
  /// Arrival point. Null until geocoded (parent-added destinations).
  LatLng? location;
}

/// One row in the parent's notification list. `type` is one of
/// started, arrived, help, route, delay, info, reply, noRoute.
class JourneyEvent {
  JourneyEvent(this.type, this.message, this.time, {this.title});
  final String type;
  final String message;
  final String time;
  final String? title;
  bool read = false;
}

/// A transient push-style banner shown on top of the parent phone.
class PushNotice {
  const PushNotice({
    required this.title,
    required this.body,
    required this.critical,
    required this.time,
  });
  final String title;
  final String body;
  final bool critical;
  final String time;
}
