import 'package:flutter/foundation.dart';

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
  help,
  unavailable,
  noRoute,
  alert,
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
  });
  final String id;
  String name;
  String address;
  String emoji;
  List<ArrivalSchedule> schedules;
}

class JourneyEvent {
  JourneyEvent(this.type, this.message, this.time);
  final String type;
  final String message;
  final String time;
  bool read = false;
}

class DemoStore extends ChangeNotifier {
  final destinations = <Destination>[
    Destination(
      id: 'school',
      name: 'School',
      address: 'Tampines Street 21, Singapore',
      emoji: '🏫',
      schedules: [
        ArrivalSchedule(
          id: 'school-weekday',
          days: ['Mon', 'Tue', 'Wed', 'Thu', 'Fri'],
          arrivalTime: '07:45',
        ),
      ],
    ),
    Destination(
      id: 'home',
      name: 'Home',
      address: 'Tampines Central, Singapore',
      emoji: '🏠',
      schedules: [
        ArrivalSchedule(
          id: 'home-weekday',
          days: ['Mon', 'Tue', 'Wed', 'Thu', 'Fri'],
          arrivalTime: '15:30',
        ),
      ],
    ),
    Destination(
      id: 'tuition',
      name: 'Tuition',
      address: 'Bedok Central, Singapore',
      emoji: '📚',
      schedules: [
        ArrivalSchedule(
          id: 'tuition-days',
          days: ['Wed', 'Fri'],
          arrivalTime: '16:30',
        ),
      ],
    ),
  ];
  final events = <JourneyEvent>[];
  String selectedDestinationId = 'school';
  String parentSelectedDestinationId = 'school';
  String? editingDestinationId;
  ChildScreen childScreen = ChildScreen.home;
  ChildScreen returnFromHelp = ChildScreen.home;
  ParentScreen parentScreen = ParentScreen.dashboard;
  ParentScreen parentTab = ParentScreen.dashboard;
  JourneyPhase phase = JourneyPhase.idle;
  bool routeChanged = false;
  bool leaveEarlier = false;
  bool helpRequested = false;
  bool demoPanelOpen = false;
  bool locationUnavailable = false;
  bool noRoute = false;
  String estimatedArrival = '07:39';
  String leaveTime = '07:05';
  String originDescription = 'Simulated current location · Tampines';

  Destination get selectedDestination => destinations.firstWhere(
    (d) => d.id == selectedDestinationId,
    orElse: () => destinations.first,
  );
  Destination get parentSelectedDestination => destinations.firstWhere(
    (d) => d.id == parentSelectedDestinationId,
    orElse: () => destinations.first,
  );
  Destination? get editingDestination {
    for (final d in destinations) {
      if (d.id == editingDestinationId) return d;
    }
    return null;
  }

  int get unreadCount => events.where((e) => !e.read).length;
  bool get active =>
      phase != JourneyPhase.idle && phase != JourneyPhase.arrived;
  String get statusLabel {
    if (phase == JourneyPhase.arrived) return 'Arrived safely';
    if (helpRequested) return 'Needs help';
    if (routeChanged) return 'Route updated';
    if (active) return 'On the way';
    return 'Not travelling';
  }

  String get nowLabel {
    final now = DateTime.now();
    return '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';
  }

  void childGo(ChildScreen s) {
    childScreen = s;
    notifyListeners();
  }

  void parentGo(ParentScreen s, {String? destinationId}) {
    parentScreen = s;
    if (destinationId != null) parentSelectedDestinationId = destinationId;
    if (s == ParentScreen.dashboard ||
        s == ParentScreen.destinations ||
        s == ParentScreen.notifications) {
      parentTab = s;
    }
    notifyListeners();
  }

  void selectDestination(String id) {
    selectedDestinationId = id;
    childScreen = ChildScreen.route;
    notifyListeners();
  }

  void _event(String type, String message) {
    events.insert(0, JourneyEvent(type, message, nowLabel));
    notifyListeners();
  }

  void start() {
    if (phase != JourneyPhase.idle && phase != JourneyPhase.arrived) return;
    phase = JourneyPhase.walking;
    routeChanged = false;
    helpRequested = false;
    childScreen = ChildScreen.walk;
    _event('started', 'Journey to ${selectedDestination.name} started');
  }

  void setPhase(JourneyPhase p, ChildScreen s) {
    phase = p;
    childScreen = s;
    notifyListeners();
  }

  void offVehicle() {
    setPhase(JourneyPhase.finalWalk, ChildScreen.finalWalk);
  }

  void confirmArrival() {
    if (phase == JourneyPhase.idle || phase == JourneyPhase.arrived) return;
    phase = JourneyPhase.arrived;
    childScreen = ChildScreen.confirmed;
    helpRequested = false;
    _event(
      'arrived',
      'Arrival at ${selectedDestination.name} confirmed by child',
    );
  }

  void requestHelp() {
    returnFromHelp = childScreen;
    helpRequested = true;
    childScreen = ChildScreen.help;
    _event('help', 'Help requested on the way to ${selectedDestination.name}');
  }

  void showReroute() {
    if (!active) return;
    routeChanged = true;
    estimatedArrival = '07:44';
    childScreen = ChildScreen.alert;
    _event('route', 'Relevant train disruption · route updated automatically');
  }

  void showLeaveEarlier() {
    leaveEarlier = true;
    leaveTime = '06:55';
    childScreen = ChildScreen.alert;
    notifyListeners();
  }

  void setFailure({bool? location, bool? route}) {
    if (location != null) locationUnavailable = location;
    if (route != null) noRoute = route;
    childScreen = locationUnavailable
        ? ChildScreen.unavailable
        : noRoute
        ? ChildScreen.noRoute
        : ChildScreen.home;
    notifyListeners();
  }

  void markRead(JourneyEvent event) {
    event.read = true;
    parentScreen = ParentScreen.journeyDetails;
    notifyListeners();
  }

  void editDestination(String? id) {
    editingDestinationId = id;
    parentScreen = ParentScreen.destinationForm;
    notifyListeners();
  }

  void saveDestination({
    required String name,
    required String address,
    required String emoji,
    required List<ArrivalSchedule> schedules,
  }) {
    final existing = editingDestination;
    if (existing == null) {
      final d = Destination(
        id: 'dest-${DateTime.now().microsecondsSinceEpoch}',
        name: name,
        address: address,
        emoji: emoji,
        schedules: schedules,
      );
      destinations.add(d);
      parentSelectedDestinationId = d.id;
    } else {
      existing.name = name;
      existing.address = address;
      existing.emoji = emoji;
      existing.schedules = schedules;
      parentSelectedDestinationId = existing.id;
    }
    parentScreen = ParentScreen.destinationDetails;
    notifyListeners();
  }

  void toggleDemo() {
    demoPanelOpen = !demoPanelOpen;
    notifyListeners();
  }
}
