import 'dart:async';

import 'package:flutter/foundation.dart';

import '../engine/demo_network.dart';
import '../engine/geo.dart';
import '../engine/reroute_engine.dart';
import '../engine/signal_mapper.dart';
import '../models/conditions.dart';
import '../models/disruption.dart';
import '../models/journey_models.dart';
import '../models/route_models.dart';
import '../models/signals.dart';
import '../services/navi_api.dart';

export '../models/journey_models.dart';

/// One in-memory state shared by the child watch, the parent phone, the
/// disruption dashboard and the flow trace. Everything is simulated and
/// resets on refresh.
class DemoStore extends ChangeNotifier {
  /// [live] asks the local backend (OneMap/LTA) for routes and conditions and
  /// falls back to labelled fixtures when it is unreachable. [motion] moves
  /// the simulated child along the route geometry so the watch navigates.
  DemoStore({this.live = false, this.motion = false, NaviApi? api}) : api = api ?? NaviApi() {
    _plan(selectedDestinationId);
  }
  final bool live;
  final bool motion;
  final NaviApi api;

  /// Simulated origin: the child's home in Tampines Central.
  static const homeLatLng = LatLng(1.3530, 103.9450);
  static const motionSpeedup = 20; // simulated seconds per real second

  // ── Static demo data ────────────────────────────────────────────────
  final destinations = <Destination>[
    Destination(
      id: 'school',
      name: 'School',
      address: 'Tampines Street 21, Singapore',
      emoji: '🏫',
      location: const LatLng(1.3516, 103.9491),
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
      location: homeLatLng,
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
      location: const LatLng(1.3258, 103.9339),
      schedules: [
        ArrivalSchedule(
          id: 'tuition-days',
          days: ['Wed', 'Fri'],
          arrivalTime: '16:30',
        ),
      ],
    ),
    Destination(
      id: 'grandma',
      name: 'Grandma',
      address: 'Ang Mo Kio Avenue 3, Singapore',
      emoji: '👵',
      location: const LatLng(1.3691, 103.8454),
      schedules: [
        ArrivalSchedule(
          id: 'grandma-sat',
          days: ['Sat'],
          arrivalTime: '10:00',
          bufferMinutes: 10,
        ),
      ],
    ),
  ];

  // ── Engine ──────────────────────────────────────────────────────────
  ChildLimits limits = const ChildLimits();
  final parser = DisruptionParser(
    lines: DemoNetwork.lines,
    knownStations: DemoNetwork.stations,
  );
  RerouteEngine get engine => RerouteEngine(limits: limits);

  // ── Navigation ──────────────────────────────────────────────────────
  String selectedDestinationId = 'school';
  String parentSelectedDestinationId = 'school';
  String? editingDestinationId;
  ChildScreen childScreen = ChildScreen.home;
  ChildScreen returnFromHelp = ChildScreen.home;
  ParentScreen parentScreen = ParentScreen.dashboard;
  ParentScreen parentTab = ParentScreen.dashboard;
  bool demoPanelOpen = false;

  // ── Journey state ───────────────────────────────────────────────────
  JourneyPhase phase = JourneyPhase.idle;
  late RouteCandidate activeRoute;
  RouteCandidate? originalRoute; // set once a reroute replaces activeRoute
  List<RouteCandidate> candidates = const [];
  String routeSource = 'offline fixtures';
  bool planning = false;
  String? busy; // short status while waiting on the backend
  int currentLegIndex = 0;
  double legProgress = 0; // 0..1 along the current leg's geometry
  bool legEndReached = false;
  List<BusArrival> liveArrivals = const [];
  String? ltaStatus;
  WeatherNow? weather;
  String? weatherStatus;
  List<OsmFeature> walkFeatures = const [];
  List<OsmFeature> safePlaces = const [];
  StationCrowding? crowding;
  Timer? _motion;
  int simNow = 7 * 60; // simulated clock, minutes of day
  bool routeChanged = false;
  bool helpRequested = false;
  bool locationUnavailable = false;
  bool noRoute = false;
  String originDescription = 'Simulated current location · Tampines';

  // ── Conditions, decisions, messages ─────────────────────────────────
  final disruptions = <Disruption>[];
  RerouteDecision? decision;
  final events = <JourneyEvent>[];
  final alerts = <ParentAlert>[];
  final flow = <FlowEvent>[];
  final childMessages = <ParentReply>[];
  String? dashboardError;
  PushNotice? parentPush;
  int _seq = 0;
  Timer? _pushTimer;

  bool _disposed = false;

  @override
  void notifyListeners() {
    if (!_disposed) super.notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _pushTimer?.cancel();
    _motion?.cancel();
    super.dispose();
  }

  // ── Derived values ──────────────────────────────────────────────────
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

  ArrivalSchedule? get schedule => selectedDestination.schedules.isEmpty
      ? null
      : selectedDestination.schedules.first;
  int get requiredArrivalMinutes =>
      schedule == null ? simNow + 60 : parseHhmm(schedule!.arrivalTime);
  int get bufferMinutes => schedule?.bufferMinutes ?? 10;

  bool get active =>
      phase != JourneyPhase.idle && phase != JourneyPhase.arrived;
  bool get leaveEarlier => decision?.action == DecisionAction.leaveEarlier;
  int get unreadCount => events.where((e) => !e.read).length;
  int get openAlertCount => alerts.where((a) => !a.acknowledged).length;

  RouteLeg get currentLeg =>
      activeRoute.legs[currentLegIndex.clamp(0, activeRoute.legs.length - 1)];
  bool get aboard =>
      phase == JourneyPhase.onboard || phase == JourneyPhase.reaching;
  JourneyPosition get position => JourneyPosition(
    legIndex: currentLegIndex,
    aboard: aboard,
    started: active,
  );

  /// Minutes of travel left from the child's current point on the route.
  int get remainingMinutes {
    if (!active) return activeRoute.totalMinutes;
    var total = activeRoute.remainingMinutes(currentLegIndex + 1);
    final leg = currentLeg;
    total += switch (phase) {
      JourneyPhase.walking || JourneyPhase.finalWalk => leg.minutes,
      JourneyPhase.waiting => leg.totalMinutes,
      JourneyPhase.onboard => leg.minutes,
      JourneyPhase.reaching => 1,
      _ => 0,
    };
    return total;
  }

  int get _pendingDelay => switch (decision?.action) {
    DecisionAction.delay || DecisionAction.holdAboard => decision!.addedMinutes,
    _ => 0,
  };

  int get leaveTimeMinutes =>
      requiredArrivalMinutes - bufferMinutes - activeRoute.totalMinutes -
      (leaveEarlier ? decision!.addedMinutes : 0);
  int get etaMinutes => active
      ? simNow + remainingMinutes + _pendingDelay
      : leaveTimeMinutes + activeRoute.totalMinutes + _pendingDelay;
  String get estimatedArrival => hhmm(etaMinutes);
  String get leaveTime => hhmm(leaveTimeMinutes);
  int get leaveInMinutes => leaveTimeMinutes - simNow;
  String get nowLabel => hhmm(simNow);

  String get statusLabel {
    if (phase == JourneyPhase.arrived) return 'Arrived safely';
    if (helpRequested) return 'Needs help';
    if (routeChanged) return 'Route updated';
    if (active) return 'On the way';
    return 'Not travelling';
  }

  String get stageLabel => switch (phase) {
    JourneyPhase.idle => 'before leaving',
    JourneyPhase.walking => 'walking to ${currentLeg.to}',
    JourneyPhase.waiting => 'waiting at ${currentLeg.from}',
    JourneyPhase.onboard => 'on ${currentLeg.label}',
    JourneyPhase.reaching => 'about to alight at ${currentLeg.to}',
    JourneyPhase.finalWalk => 'walking to ${selectedDestination.name}',
    JourneyPhase.awaitingConfirmation => 'at the destination',
    JourneyPhase.arrived => 'arrived',
  };
  String get locationLabel => switch (phase) {
    JourneyPhase.idle => 'Home',
    JourneyPhase.walking || JourneyPhase.finalWalk => 'between ${currentLeg.from} and ${currentLeg.to}',
    JourneyPhase.waiting => '${currentLeg.from} ${currentLeg.stopWord}',
    JourneyPhase.onboard || JourneyPhase.reaching => '${currentLeg.label}, before ${currentLeg.to}',
    _ => selectedDestination.name,
  };

  // ── Simulated position along the route geometry ─────────────────────
  List<LatLng> get legGeometry => currentLeg.points;
  List<double> get legCumulative => Geo.cumulative(legGeometry);
  double get legLengthM => legGeometry.length < 2 ? 0 : legCumulative.last;
  double get distanceAlongM => legLengthM * legProgress;
  double get metresLeft => (legLengthM - distanceAlongM).clamp(0, double.infinity);

  LatLng get childPosition {
    if (!active) return homeLatLng;
    final pts = legGeometry;
    if (pts.length < 2) return currentLeg.fromLatLng ?? homeLatLng;
    return Geo.pointAt(pts, legCumulative, distanceAlongM);
  }

  double get headingDeg {
    final pts = legGeometry;
    if (pts.length < 2) return 0;
    return Geo.headingAt(pts, legCumulative, distanceAlongM + 2);
  }

  /// Next turn for the watch, using OneMap street names when present.
  TurnGuidance get guidance {
    final pts = legGeometry;
    if (pts.length < 2) return const TurnGuidance(kind: TurnKind.arrive, distanceM: 0);
    final cum = legCumulative;
    final steps = currentLeg.steps.where((s) => s.at != null).toList();
    final stepVertex = <int, String>{};
    for (final st in steps) {
      var best = 0;
      var bestD = double.infinity;
      for (var i = 0; i < pts.length; i++) {
        final d = Geo.distanceM(pts[i], st.at!);
        if (d < bestD) {
          bestD = d;
          best = i;
        }
      }
      if (st.street.isNotEmpty) stepVertex[best] = st.street;
    }
    String streetAt(int v) {
      var name = '';
      for (final e in stepVertex.entries) {
        if (e.key <= v) name = e.value;
      }
      return name;
    }
    return Guidance.next(pts, cum, distanceAlongM, streetAt: stepVertex.isEmpty ? null : streetAt);
  }

  /// Crowd level at the boarding station of the current rail leg.
  CrowdLevel get boardingCrowd {
    final leg = currentLeg;
    if (leg.mode != LegMode.rail || crowding == null || crowding!.lineId != leg.lineId) return CrowdLevel.unknown;
    return crowding!.at(leg.boardingStopCode);
  }

  /// Stops already passed on the current transit leg (for the ride view).
  int get stopsPassed {
    final n = currentLeg.stops.length;
    if (n < 2 || !aboard) return 0;
    return (legProgress * (n - 1)).floor().clamp(0, n - 1);
  }

  /// Legs still to do, for the child's "next steps" list.
  List<RouteLeg> get remainingLegs =>
      active ? activeRoute.legs.skip(currentLegIndex).toList() : activeRoute.legs;

  // ── Planning ────────────────────────────────────────────────────────
  /// Live itineraries already fetched this session, per destination, so
  /// resets and scripted replays reuse them instead of re-querying OneMap.
  final _liveCache = <String, List<RouteCandidate>>{};

  void _plan(String destinationId) {
    final cached = _liveCache[destinationId];
    if (cached != null && cached.isNotEmpty) {
      candidates = cached;
      activeRoute = _pickPrimary(cached);
      routeSource = 'OneMap live';
    } else {
      candidates = [for (final c in DemoNetwork.candidatesFor(destinationId)) DemoNetwork.hydrate(c)];
      activeRoute = candidates.first;
      routeSource = 'offline fixtures';
    }
    originalRoute = null;
    currentLegIndex = 0;
    legProgress = 0;
    legEndReached = false;
    decision = null;
    routeChanged = false;
    simNow = leaveTimeMinutes - 10;
    if (live && cached == null) unawaited(_planLive(destinationId));
  }

  /// Asks OneMap (through the local backend) for real itineraries from the
  /// child's home to the destination around the scheduled time.
  final _inflight = <String, Future<List<RouteCandidate>>>{};

  Future<void> _planLive(String destinationId) async {
    final dest = destinations.firstWhere((d) => d.id == destinationId, orElse: () => destinations.first);
    if (dest.location == null) return;
    planning = true;
    busy = 'Asking OneMap for routes…';
    notifyListeners();
    try {
      final fetched = await (_inflight[destinationId] ??= api
          .routes(
            origin: homeLatLng,
            destination: dest.location!,
            destinationId: destinationId,
            departMinutes: requiredArrivalMinutes - 60,
            numItineraries: 3,
          )
          .whenComplete(() {
            // Block body on purpose: returning the removed future here would
            // make whenComplete wait on itself.
            _inflight.remove(destinationId);
          }));
      if (fetched.isNotEmpty) _liveCache[destinationId] = fetched;
      if (weather == null) await refreshWeather();
      if (selectedDestinationId != destinationId || active || fetched.isEmpty) return;
      candidates = fetched;
      activeRoute = _pickPrimary(fetched);
      routeSource = 'OneMap live';
      simNow = leaveTimeMinutes - 10;
      _flow(FlowActor.engine, FlowActor.child, FlowKind.info, 'OneMap route planned',
          '${activeRoute.summary} · ${activeRoute.totalMinutes} min · ${fetched.length} itineraries · real geometry');
    } catch (e, st) {
      debugPrint('[navi] planLive failed: $e\n$st');
      routeSource = 'offline fixtures (backend unreachable)';
      _flow(FlowActor.engine, FlowActor.engine, FlowKind.info, 'OneMap unavailable, using fixtures',
          e.toString().split('\n').first);
    } finally {
      debugPrint('[navi] planLive done $destinationId source=$routeSource');
      planning = false;
      busy = null;
      notifyListeners();
    }
  }

  /// Child-suitable ranking: shortest after transfer and walking penalties,
  /// skipping anything over the walking limit when something else exists.
  RouteCandidate _pickPrimary(List<RouteCandidate> list) {
    final ok = list.where((c) => c.longestWalk <= limits.maxWalkMinutesPerLeg && c.transfers <= limits.maxTransfers).toList();
    final pool = ok.isEmpty ? List.of(list) : ok;
    // In rain every walking minute costs double, so sheltered/shorter-walk
    // itineraries win even if a little slower.
    final walkWeight = weather?.raining == true ? 2.0 : 0.5;
    int score(RouteCandidate c) => c.totalMinutes + c.transfers * limits.transferPenaltyMinutes + (c.walkMinutes * walkWeight).round();
    pool.sort((a, b) => score(a).compareTo(score(b)));
    return pool.first;
  }

  // ── Navigation actions ──────────────────────────────────────────────
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
    if (active) return;
    selectedDestinationId = id;
    _plan(id);
    childScreen = ChildScreen.route;
    _flow(FlowActor.child, FlowActor.engine, FlowKind.info, 'Route planned ($routeSource)',
        '${activeRoute.summary} · ${activeRoute.totalMinutes} min · ${candidates.length} candidates');
    _reevaluateAll();
    notifyListeners();
  }

  void toggleDemo() {
    demoPanelOpen = !demoPanelOpen;
    notifyListeners();
  }

  // ── Journey actions (child) ─────────────────────────────────────────
  void start() {
    if (active) return;
    if (phase == JourneyPhase.arrived) _plan(selectedDestinationId);
    simNow = leaveTimeMinutes;
    currentLegIndex = 0;
    helpRequested = false;
    _enterLeg();
    _event('started', 'Journey to ${selectedDestination.name} started',
        title: 'Journey started');
    _flow(FlowActor.child, FlowActor.parent, FlowKind.notification,
        'Journey started', '${activeRoute.summary} · ETA $estimatedArrival');
    _push('Maya started her journey', 'To ${selectedDestination.name} · ETA $estimatedArrival');
  }

  void _enterLeg() {
    final leg = currentLeg;
    legProgress = 0;
    legEndReached = false;
    liveArrivals = const [];
    walkFeatures = const [];
    if (leg.mode == LegMode.walk) {
      final last = currentLegIndex == activeRoute.legs.length - 1;
      phase = last ? JourneyPhase.finalWalk : JourneyPhase.walking;
      childScreen = last ? ChildScreen.finalWalk : ChildScreen.walk;
      _startMotion();
      if (live && leg.hasGeometry) unawaited(refreshWalkFeatures());
    } else {
      phase = JourneyPhase.waiting;
      childScreen = ChildScreen.waiting;
      _stopMotion();
      if (live && leg.mode == LegMode.bus && leg.boardingStopCode != null) unawaited(refreshArrivals());
      if (live && leg.mode == LegMode.rail && leg.lineId != null) unawaited(refreshCrowding(leg.lineId!));
    }
  }

  /// OpenStreetMap crossings, steps and sheltered walkways along this walk.
  Future<void> refreshWalkFeatures() async {
    final leg = currentLeg;
    if (!live || !leg.hasGeometry) return;
    final index = currentLegIndex;
    try {
      final feats = await api.walkFeatures(leg.points);
      if (currentLegIndex != index) return;
      walkFeatures = feats;
      final crossings = feats.where((f) => f.kind == 'crossing').length;
      final covered = feats.where((f) => f.kind == 'covered').length;
      _flow(FlowActor.engine, FlowActor.child, FlowKind.info, 'OpenStreetMap features on this walk',
          '$crossings crossing(s), ${feats.where((f) => f.kind == 'steps').length} steps, $covered sheltered section(s) · © OpenStreetMap contributors');
    } catch (_) {
      walkFeatures = const [];
    }
    notifyListeners();
  }

  /// LTA station crowd density for the line the child is about to ride.
  Future<void> refreshCrowding(String lineId) async {
    if (!live) return;
    try {
      crowding = await api.crowding(lineId);
      final level = boardingCrowd;
      _flow(FlowActor.engine, FlowActor.child, FlowKind.info, 'LTA crowding · $lineId',
          '${currentLeg.from} platform: ${level.word} ${level.emoji} · ${crowding!.levels.length} stations reported');
      if (level == CrowdLevel.high) {
        _event('info', '${currentLeg.from} platform is very crowded (LTA live). NAVI told Maya to stand near the door and wait for the next train if needed.',
            title: 'Crowded platform');
      }
    } catch (_) {
      crowding = null;
    }
    notifyListeners();
  }

  /// data.gov.sg nowcast + rainfall near the child; rain becomes a live
  /// weather condition that the engine turns into umbrella advice.
  Future<void> refreshWeather() async {
    if (!live) {
      weatherStatus = 'Live mode is off (no backend).';
      notifyListeners();
      return;
    }
    try {
      final w = await api.weather(childPosition);
      weather = w;
      weatherStatus = '${w.emoji} ${w.forecast} in ${w.area} · rain gauge ${w.rainfallMm.toStringAsFixed(1)} mm · ${w.validPeriod}';
      _flow(FlowActor.dashboard, FlowActor.engine, FlowKind.info, 'Weather (data.gov.sg)', '${w.forecast} in ${w.area} · ${w.advice}');
      if (w.raining && !disruptions.any((d) => d.kind == DisruptionKind.weather && !d.simulated)) {
        await addDisruption(Disruption(
          id: 'weather-${++_seq}',
          kind: DisruptionKind.weather,
          rawInput: 'data.gov.sg: ${w.forecast} in ${w.area}',
          issuedAtMinutes: simNow,
          simulated: false,
        ));
      }
    } catch (e) {
      weatherStatus = 'Weather unavailable: ${e.toString().split('\n').first}';
    }
    notifyListeners();
  }

  /// OSM staffed places near the child, attached to the latest alert so
  /// the watch can say where to go and the parent can see it on the map.
  Future<void> refreshSafePlaces(ParentAlert alert) async {
    if (!live) return;
    try {
      final places = await api.safePlaces(childPosition, radius: 600);
      safePlaces = places;
      if (places.isNotEmpty) {
        final p = places.first;
        alert.safePlace = p;
        _flow(FlowActor.engine, FlowActor.child, FlowKind.info, 'Nearest safe place (OpenStreetMap)',
            '${p.emoji} ${p.name} · ${p.label} · ${p.distanceM} m');
      }
    } catch (_) {
      safePlaces = const [];
    }
    notifyListeners();
  }

  void _startMotion() {
    _stopMotion();
    if (!motion) return;
    final leg = currentLeg;
    final seconds = leg.minutes * 60;
    _motion = Timer.periodic(const Duration(milliseconds: 200), (_) {
      if (!active) return _stopMotion();
      legProgress = (legProgress + 0.2 * motionSpeedup / seconds).clamp(0, 1);
      if (legProgress >= 1) {
        legEndReached = true;
        _stopMotion();
      }
      notifyListeners();
    });
  }

  void _stopMotion() {
    _motion?.cancel();
    _motion = null;
  }

  /// Live bus ETAs at the boarding stop (LTA), shown on the waiting screen.
  Future<void> refreshArrivals() async {
    final leg = currentLeg;
    final code = leg.boardingStopCode;
    if (!live || code == null) return;
    try {
      liveArrivals = await api.busArrivals(code, service: leg.serviceNo);
      if (liveArrivals.isNotEmpty) {
        final a = liveArrivals.first;
        _flow(FlowActor.engine, FlowActor.child, FlowKind.info, 'Live bus arrivals (LTA)',
            'Bus ${a.serviceNo} at stop $code: ${a.minutes.isEmpty ? 'no data' : a.minutes.map((m) => '$m min').join(' · ')}');
      }
    } catch (_) {
      liveArrivals = const [];
    }
    notifyListeners();
  }

  /// Advances the child one step through the current leg.
  void nextStep() {
    if (!active) return;
    final leg = currentLeg;
    switch (phase) {
      case JourneyPhase.walking:
        simNow += leg.minutes;
        currentLegIndex++;
        _enterLeg();
      case JourneyPhase.waiting:
        simNow += leg.waitMinutes + _consumeDelay();
        phase = JourneyPhase.onboard;
        childScreen = ChildScreen.onboard;
        legProgress = 0;
        legEndReached = false;
        _startMotion();
      case JourneyPhase.onboard:
        simNow += leg.minutes - 1;
        phase = JourneyPhase.reaching;
        childScreen = ChildScreen.reaching;
        legProgress = 1;
        _stopMotion();
      case JourneyPhase.reaching:
        offVehicle();
        return;
      case JourneyPhase.finalWalk:
        simNow += leg.minutes;
        phase = JourneyPhase.awaitingConfirmation;
        childScreen = ChildScreen.arrival;
      default:
        return;
    }
    notifyListeners();
  }

  int _consumeDelay() {
    final d = _pendingDelay;
    if (d > 0) decision = null;
    return d;
  }

  /// Kept for existing callers and tests.
  void setPhase(JourneyPhase p, ChildScreen s) {
    phase = p;
    childScreen = s;
    notifyListeners();
  }

  void offVehicle() {
    if (!active) return;
    simNow += 1;
    if (currentLegIndex >= activeRoute.legs.length - 1) {
      phase = JourneyPhase.awaitingConfirmation;
      childScreen = ChildScreen.arrival;
    } else {
      currentLegIndex++;
      _enterLeg();
    }
    notifyListeners();
  }

  void confirmArrival() {
    if (!active) return;
    phase = JourneyPhase.arrived;
    childScreen = ChildScreen.confirmed;
    helpRequested = false;
    _stopMotion();
    _event('arrived', 'Arrival at ${selectedDestination.name} confirmed by Maya',
        title: 'Arrived safely');
    _flow(FlowActor.child, FlowActor.parent, FlowKind.notification,
        'Arrival confirmed', 'Explicit tap by the child at $nowLabel');
    _push('Maya arrived safely', 'She confirmed arrival at ${selectedDestination.name}');
  }

  // ── Child signals → parent alerts ───────────────────────────────────
  void requestHelp() {
    if (childScreen != ChildScreen.help) returnFromHelp = childScreen;
    childScreen = ChildScreen.help;
    notifyListeners();
  }

  void sendSignal(ChildSignalKind kind) {
    final signal = ChildSignal(
      kind: kind,
      atMinutes: simNow,
      stageLabel: stageLabel,
      locationLabel: locationLabel,
    );
    final alert = SignalMapper.map(signal, id: 'a-${++_seq}');
    alerts.insert(0, alert);
    if (kind == ChildSignalKind.scared || kind == ChildSignalKind.lost || kind == ChildSignalKind.unwell) {
      unawaited(refreshSafePlaces(alert));
    }
    helpRequested = kind != ChildSignalKind.checkIn;
    childScreen = ChildScreen.helpSent;
    _flow(FlowActor.child, FlowActor.engine, FlowKind.signal,
        '${kind.emoji} "${kind.childButton}"', 'Tapped while $stageLabel · $locationLabel');
    _flow(FlowActor.engine, FlowActor.parent, FlowKind.notification,
        alert.title, '${alert.urgency.name.toUpperCase()} · ${alert.suggestedActions.join(' / ')}');
    _flow(FlowActor.engine, FlowActor.child, FlowKind.info,
        'Reassurance shown', alert.childReassurance.replaceAll('\n', ' '));
    _event(kind == ChildSignalKind.checkIn ? 'info' : 'help', alert.detail,
        title: alert.title);
    _push(alert.title, alert.detail, critical: alert.urgency == Urgency.critical);
  }

  ParentAlert? get latestAlert => alerts.isEmpty ? null : alerts.first;

  void acknowledgeAlert(ParentAlert a) {
    a.acknowledged = true;
    if (alerts.every((x) => x.acknowledged)) helpRequested = false;
    notifyListeners();
  }

  void replyToChild(String text) {
    childMessages.insert(0, ParentReply(text: text, atMinutes: simNow));
    childScreen = ChildScreen.message;
    _flow(FlowActor.parent, FlowActor.child, FlowKind.reply, 'Parent reply', text);
    _event('reply', 'You replied: "$text"', title: 'Reply sent to Maya').read = true;
    notifyListeners();
  }

  void dismissMessage() {
    childScreen = active ? _screenForPhase() : ChildScreen.home;
    notifyListeners();
  }

  ChildScreen _screenForPhase() => switch (phase) {
    JourneyPhase.walking => ChildScreen.walk,
    JourneyPhase.waiting => ChildScreen.waiting,
    JourneyPhase.onboard => ChildScreen.onboard,
    JourneyPhase.reaching => ChildScreen.reaching,
    JourneyPhase.finalWalk => ChildScreen.finalWalk,
    JourneyPhase.awaitingConfirmation => ChildScreen.arrival,
    JourneyPhase.arrived => ChildScreen.confirmed,
    JourneyPhase.idle => ChildScreen.home,
  };

  // ── Disruption dashboard → engine → both phones ─────────────────────
  /// Parses free text such as "red line delayed 10 min" and applies it.
  bool applyDisruptionText(String text) {
    final d = parser.parse(text, nowMinutes: simNow);
    if (d == null) {
      dashboardError =
          'Not understood. Name a line colour (red, green, blue, orange, purple, brown), a line, a bus number, or rain.';
      notifyListeners();
      return false;
    }
    dashboardError = null;
    addDisruption(d);
    return true;
  }

  /// Offline: evaluated synchronously. Live and relevant: asks OneMap for
  /// alternatives first, then evaluates.
  Future<void> addDisruption(Disruption d) {
    disruptions.add(d);
    _flow(FlowActor.dashboard, FlowActor.engine, FlowKind.disruption,
        'Disruption: ${d.summary}', 'Typed: "${d.rawInput}" · ${d.simulated ? 'simulated' : 'live LTA'}');
    notifyListeners();
    final relevant = d.kind != DisruptionKind.weather &&
        d.kind != DisruptionKind.crowding &&
        remainingLegs.any(d.affects);
    if (live && relevant) return _evaluateLive(d);
    _evaluate(d, candidates);
    notifyListeners();
    return Future.value();
  }

  Future<void> _evaluateLive(Disruption d) async {
    final pool = await _liveAlternatives();
    if (_disposed || !disruptions.contains(d)) return;
    _evaluate(d, pool);
    notifyListeners();
  }

  /// Fresh itineraries from the child's *actionable* position: where they are
  /// now, or the next stop if they are aboard. Legs already ridden are kept
  /// as the prefix so the engine can compare like with like. If every
  /// itinerary still touches an active disruption, ask again for bus-only.
  Future<List<RouteCandidate>> _liveAlternatives() async {
    final dest = selectedDestination.location;
    if (dest == null) return candidates;
    final locked = position.lockedLegs;
    final origin = !active
        ? homeLatLng
        : aboard
        ? (currentLeg.toLatLng ?? childPosition)
        : childPosition;
    final depart = !active ? leaveTimeMinutes : simNow + (aboard ? (currentLeg.minutes * (1 - legProgress)).round() : 0);
    busy = 'Asking OneMap for alternatives from ${aboard ? currentLeg.to : 'current position'}…';
    _flow(FlowActor.engine, FlowActor.engine, FlowKind.info, 'Re-planning with OneMap',
        'Origin: ${aboard ? 'next stop ${currentLeg.to}' : 'current position $origin'} · depart ${hhmm(depart)}');
    notifyListeners();
    List<RouteCandidate> fetched;
    try {
      fetched = await api.routes(origin: origin, destination: dest, destinationId: selectedDestinationId,
          departMinutes: depart, numItineraries: 3);
      bool blocked(RouteCandidate c) => disruptions.any((x) =>
          x.kind != DisruptionKind.weather && x.kind != DisruptionKind.crowding && c.legs.any(x.affects));
      if (fetched.isEmpty || fetched.every(blocked)) {
        _flow(FlowActor.engine, FlowActor.engine, FlowKind.info, 'All OneMap itineraries affected',
            'Asking again for bus-only routes');
        fetched = [...fetched, ...await api.routes(origin: origin, destination: dest,
            destinationId: selectedDestinationId, departMinutes: depart, mode: 'BUS', numItineraries: 3)];
      }
      _flow(FlowActor.engine, FlowActor.engine, FlowKind.info, 'OneMap returned ${fetched.length} itineraries',
          fetched.map((c) => '${c.summary} (${c.totalMinutes} min)').join(' | '));
    } catch (e) {
      _flow(FlowActor.engine, FlowActor.engine, FlowKind.info, 'OneMap unavailable for re-planning',
          'Falling back to known candidates · ${e.toString().split('\n').first}');
      return candidates;
    } finally {
      busy = null;
    }
    final prefix = activeRoute.legs.take(locked).toList();
    return [
      activeRoute,
      for (final c in fetched) c.copyWith(id: '${c.id}-from-$locked', legs: [...prefix, ...c.legs]),
    ];
  }

  void removeDisruption(Disruption d) {
    disruptions.remove(d);
    if (decision?.disruption.id == d.id) {
      decision = null;
      if (childScreen == ChildScreen.alert) childScreen = _screenForPhase();
    }
    _flow(FlowActor.dashboard, FlowActor.engine, FlowKind.info,
        'Cleared: ${d.summary}', 'Condition removed');
    notifyListeners();
  }

  void clearDisruptions() {
    for (final d in List.of(disruptions)) {
      removeDisruption(d);
    }
  }

  void setLimits(ChildLimits l) {
    limits = l;
    notifyListeners();
  }

  void _reevaluateAll() {
    for (final d in disruptions) {
      _evaluate(d, candidates);
    }
  }

  void _evaluate(Disruption d, List<RouteCandidate> pool) {
    final result = engine.evaluate(
      route: activeRoute,
      candidates: pool,
      disruption: d,
      active: disruptions,
      position: position,
      nowMinutes: simNow,
      requiredArrivalMinutes: requiredArrivalMinutes,
      bufferMinutes: bufferMinutes,
      remainingMinutesNow: active ? remainingMinutes : null,
    );
    _flow(FlowActor.engine, FlowActor.engine, FlowKind.decision,
        'Decision: ${result.action.name}', result.reason);
    _applyDecision(result);
  }

  void _applyDecision(RerouteDecision r) {
    switch (r.action) {
      case DecisionAction.keep:
        _flow(FlowActor.engine, FlowActor.parent, FlowKind.info,
            r.parentTitle, r.parentMessage);
        return;
      case DecisionAction.info:
        decision = r;
        if (r.childTitle.isNotEmpty) {
          _flow(FlowActor.engine, FlowActor.child, FlowKind.info,
              r.childTitle, r.childMessage);
        }
        _event('info', r.parentMessage, title: r.parentTitle).read = true;
        _flow(FlowActor.engine, FlowActor.parent, FlowKind.info,
            r.parentTitle, r.parentMessage);
        return;
      case DecisionAction.reroute:
        originalRoute ??= activeRoute;
        activeRoute = r.alternative!;
        candidates = [for (final c in candidates) if (c.id != activeRoute.id) c, activeRoute];
        routeChanged = true;
        decision = r;
        if (active && !aboard) {
          // Same leg index, new geometry: keep walking from where we are.
          legProgress = 0;
          legEndReached = false;
          if (phase == JourneyPhase.walking || phase == JourneyPhase.finalWalk) _startMotion();
        }
        if (active && childScreen != ChildScreen.help) {
          childScreen = ChildScreen.alert;
        } else if (!active) {
          childScreen = ChildScreen.alert;
        }
        _event('route', r.parentMessage, title: r.parentTitle);
        _flow(FlowActor.engine, FlowActor.child, FlowKind.notification,
            r.childTitle, r.childMessage);
        _flow(FlowActor.engine, FlowActor.parent, FlowKind.notification,
            r.parentTitle, r.parentMessage);
        _push(r.parentTitle, r.parentMessage);
        return;
      case DecisionAction.delay:
      case DecisionAction.leaveEarlier:
      case DecisionAction.holdAboard:
      case DecisionAction.noRoute:
        decision = r;
        childScreen = ChildScreen.alert;
        if (r.action == DecisionAction.noRoute) noRoute = true;
        _event(r.action == DecisionAction.noRoute ? 'noRoute' : 'delay',
            r.parentMessage, title: r.parentTitle);
        _flow(FlowActor.engine, FlowActor.child, FlowKind.notification,
            r.childTitle, r.childMessage);
        _flow(FlowActor.engine, FlowActor.parent, FlowKind.notification,
            r.parentTitle, r.parentMessage);
        _push(r.parentTitle, r.parentMessage,
            critical: r.action == DecisionAction.noRoute ||
                r.action == DecisionAction.holdAboard);
        return;
    }
  }

  /// Child taps "OK" on an alert: return to the step they are on.
  void dismissAlert() {
    childScreen = active ? _screenForPhase() : ChildScreen.route;
    notifyListeners();
  }

  // ── Legacy demo controls (now routed through the engine) ────────────
  /// Injects a closure on the first transit leg the child still has to ride.
  void showReroute() {
    if (!active) start();
    final leg = activeRoute.legs.skip(currentLegIndex).firstWhere(
      (l) => l.isTransit,
      orElse: () => activeRoute.legs.last,
    );
    addDisruption(Disruption(
      id: 'd-${++_seq}',
      kind: DisruptionKind.closure,
      rawInput: 'demo: ${leg.label} not running',
      lineId: leg.lineId,
      serviceNo: leg.serviceNo,
      issuedAtMinutes: simNow,
    ));
  }

  /// Injects a delay big enough to eat the arrival buffer before leaving.
  void showLeaveEarlier() {
    if (active) return;
    final leg = activeRoute.legs.firstWhere((l) => l.isTransit);
    addDisruption(Disruption(
      id: 'd-${++_seq}',
      kind: DisruptionKind.delay,
      rawInput: 'demo: ${leg.label} delayed',
      lineId: leg.lineId,
      serviceNo: leg.serviceNo,
      delayMinutes: bufferMinutes + 5,
      issuedAtMinutes: simNow,
    ));
  }

  void setFailure({bool? location, bool? route}) {
    if (location != null) locationUnavailable = location;
    if (route != null) noRoute = route;
    childScreen = locationUnavailable
        ? ChildScreen.unavailable
        : noRoute
        ? ChildScreen.noRoute
        : active
        ? _screenForPhase()
        : ChildScreen.home;
    if (locationUnavailable) {
      _flow(FlowActor.child, FlowActor.engine, FlowKind.info,
          'Location unavailable', 'Origin marked stale; parent sees a warning');
    }
    notifyListeners();
  }

  /// Pulls LTA TrainServiceAlerts and turns affected segments into live
  /// (non-simulated) conditions.
  Future<void> pullLtaAlerts() async {
    if (!live) {
      ltaStatus = 'Live mode is off (no backend).';
      notifyListeners();
      return;
    }
    busy = 'Fetching LTA train service alerts…';
    notifyListeners();
    try {
      final a = await api.trainAlerts();
      ltaStatus = a.status == 'normal'
          ? 'LTA: all train lines normal at ${a.fetchedAt.substring(11, 16)} · ${a.messages.length} notice(s)'
          : 'LTA: DISRUPTION · ${a.segments.map((s) => s.lineId).join(', ')}';
      _flow(FlowActor.dashboard, FlowActor.engine, FlowKind.disruption, 'LTA train alerts pulled',
          a.messages.isEmpty ? ltaStatus! : a.messages.first);
      for (final seg in a.segments) {
        if (seg.lineId.isEmpty) continue;
        await addDisruption(Disruption(
          id: 'lta-${seg.lineId}-${++_seq}',
          kind: DisruptionKind.closure,
          rawInput: 'LTA: ${seg.lineId} ${seg.stationCodes.join(',')}',
          lineId: seg.lineId,
          issuedAtMinutes: simNow,
          simulated: false,
        ));
      }
    } catch (e) {
      ltaStatus = 'LTA unavailable: ${e.toString().split('\n').first}';
    } finally {
      busy = null;
      notifyListeners();
    }
  }

  void resetDemo() {
    _stopMotion();
    phase = JourneyPhase.idle;
    ltaStatus = null;
    liveArrivals = const [];
    walkFeatures = const [];
    safePlaces = const [];
    crowding = null;
    helpRequested = false;
    locationUnavailable = false;
    noRoute = false;
    disruptions.clear();
    events.clear();
    alerts.clear();
    flow.clear();
    childMessages.clear();
    parentPush = null;
    dashboardError = null;
    childScreen = ChildScreen.home;
    parentScreen = ParentScreen.dashboard;
    parentTab = ParentScreen.dashboard;
    _plan(selectedDestinationId);
    notifyListeners();
  }

  // ── Scripted scenarios for presentations ────────────────────────────
  static const scenarios = <String, String>{
    'walk': 'Child walking to the stop (3D navigation)',
    'scared': 'Child: "Someone is scaring me" at the bus stop',
    'redline': 'Train line delayed while riding to Grandma',
    'bus10': 'Bus not running before school',
    'lost': 'Child lost after a transfer, parent replies',
  };

  /// Phrase that disrupts the next transit leg the child still has to ride,
  /// so the scripted scenarios bite whichever route OneMap actually chose.
  String _phraseForNextTransit({required DisruptionKind kind}) {
    final leg = activeRoute.legs.skip(currentLegIndex).firstWhere(
      (l) => l.isTransit,
      orElse: () => activeRoute.legs.firstWhere((l) => l.isTransit, orElse: () => activeRoute.legs.first),
    );
    if (leg.mode == LegMode.rail) {
      final colour = DemoNetwork.line(leg.lineId)?.colourName ?? 'green';
      return kind == DisruptionKind.closure ? '$colour line closed' : '$colour line delayed 15 min';
    }
    if (leg.mode == LegMode.bus) {
      return kind == DisruptionKind.closure ? 'bus ${leg.serviceNo} not running' : 'bus ${leg.serviceNo} delayed 15 min';
    }
    return 'red line delayed';
  }

  /// Replays a fixed sequence of taps and injections so a presenter can jump
  /// straight to an interesting state. Deep link: `#lab/<id>`. In live mode
  /// it first waits for OneMap so the replay runs on real itineraries.
  Future<void> runScenario(String id) async {
    final dest = id == 'scared' || id == 'bus10' || id == 'walk' ? 'school' : 'grandma';
    if (live && !_liveCache.containsKey(dest)) {
      await _planLive(dest);
    }
    resetDemo();
    _runScenario(id);
  }

  void _runScenario(String id) {
    switch (id) {
      case 'walk':
        selectDestination('school');
        start();
        _stopMotion();
        legProgress = .35;
      case 'scared':
        selectDestination('school');
        start();
        nextStep(); // at the bus stop
        requestHelp();
        sendSignal(ChildSignalKind.scared);
      case 'redline':
        selectDestination('grandma');
        start();
        // Ride the first transit leg and step off, so the child is between
        // legs; then delay whatever they are about to board next.
        while (phase == JourneyPhase.walking) {
          nextStep();
        }
        if (phase == JourneyPhase.waiting) {
          nextStep(); // aboard
          nextStep(); // reaching
          offVehicle(); // next leg
        }
        while (phase == JourneyPhase.walking) {
          nextStep();
        }
        applyDisruptionText(_phraseForNextTransit(kind: DisruptionKind.delay));
      case 'bus10':
        selectDestination('school');
        applyDisruptionText(_phraseForNextTransit(kind: DisruptionKind.closure));
      case 'lost':
        selectDestination('grandma');
        start();
        while (phase == JourneyPhase.walking) {
          nextStep();
        }
        if (phase == JourneyPhase.waiting) {
          nextStep();
          nextStep();
          offVehicle();
        }
        requestHelp();
        sendSignal(ChildSignalKind.lost);
        replyToChild('Stay there, I am coming 🚗');
      default:
        return;
    }
    parentGo(ParentScreen.dashboard);
  }

  // ── Parent notifications ────────────────────────────────────────────
  void markRead(JourneyEvent event) {
    event.read = true;
    parentScreen = ParentScreen.journeyDetails;
    notifyListeners();
  }

  void dismissPush() {
    parentPush = null;
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
      if (live) unawaited(_geocode(d));
    } else {
      existing.name = name;
      existing.address = address;
      existing.emoji = emoji;
      existing.schedules = schedules;
      parentSelectedDestinationId = existing.id;
      if (existing.id == selectedDestinationId && !active) _plan(existing.id);
    }
    parentScreen = ParentScreen.destinationDetails;
    notifyListeners();
  }

  Future<void> _geocode(Destination d) async {
    try {
      final at = await api.geocode(d.address);
      if (at == null) return;
      d.location = at;
      _flow(FlowActor.parent, FlowActor.engine, FlowKind.info, 'Destination geocoded (OneMap)', '${d.name} → $at');
      if (selectedDestinationId == d.id && !active) _plan(d.id);
      notifyListeners();
    } catch (_) {}
  }

  // ── Internals ───────────────────────────────────────────────────────
  JourneyEvent _event(String type, String message, {String? title}) {
    final e = JourneyEvent(type, message, nowLabel, title: title);
    events.insert(0, e);
    notifyListeners();
    return e;
  }

  void _flow(FlowActor from, FlowActor to, FlowKind kind, String title,
      String detail) {
    flow.insert(
      0,
      FlowEvent(
        seq: ++_seq,
        from: from,
        to: to,
        kind: kind,
        title: title,
        detail: detail,
        atMinutes: simNow,
      ),
    );
  }

  void _push(String title, String body, {bool critical = false}) {
    parentPush = PushNotice(
      title: title,
      body: body,
      critical: critical,
      time: nowLabel,
    );
    _pushTimer?.cancel();
    _pushTimer = Timer(const Duration(seconds: 7), () {
      parentPush = null;
      notifyListeners();
    });
    notifyListeners();
  }
}
