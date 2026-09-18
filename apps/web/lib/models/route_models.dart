// Route domain models. Mirrors `backend/src/contracts/index.ts`
// (`RouteLeg`, `RouteCandidate`) and the JSON served by backend/mock.

import '../engine/geo.dart';

export '../engine/geo.dart' show LatLng;

enum LegMode { walk, bus, rail }

/// A Singapore MRT line. Colour names let the disruption dashboard accept
/// plain phrases such as "red line delayed".
class TransitLine {
  const TransitLine({
    required this.id,
    required this.name,
    required this.colourName,
    required this.colour,
    required this.aliases,
  });
  final String id; // NSL, EWL, DTL, CCL, NEL, TEL
  final String name;
  final String colourName;
  final int colour; // ARGB
  final List<String> aliases;
}

/// One OneMap/OTP walking step (street change).
class WalkStep {
  const WalkStep({required this.direction, required this.street, required this.distanceM, this.at});
  final String direction;
  final String street;
  final int distanceM;
  final LatLng? at;

  factory WalkStep.fromJson(Map<String, dynamic> j) => WalkStep(
    direction: (j['direction'] ?? '') as String,
    street: (j['street'] ?? '') as String,
    distanceM: ((j['distanceM'] ?? 0) as num).round(),
    at: j['lat'] == null || j['lon'] == null
        ? null
        : LatLng((j['lat'] as num).toDouble(), (j['lon'] as num).toDouble()),
  );
}

class RouteLeg {
  const RouteLeg({
    required this.mode,
    required this.from,
    required this.to,
    required this.minutes,
    this.lineId,
    this.serviceNo,
    this.stops = const [],
    this.stopCodes = const [],
    this.waitMinutes = 0,
    this.points = const [],
    this.steps = const [],
    this.distanceM = 0,
    this.fromLatLng,
    this.toLatLng,
  });
  final LegMode mode;
  final String from;
  final String to;
  final int minutes;
  final int waitMinutes;
  final String? lineId; // rail line id
  final String? serviceNo; // bus service number
  /// Ordered stops/stations from `from` to `to` inclusive (transit legs).
  final List<String> stops;
  final List<String?> stopCodes;
  /// Decoded geometry, lat/lon. Empty for fixtures until hydrated.
  final List<LatLng> points;
  final List<WalkStep> steps;
  final int distanceM;
  final LatLng? fromLatLng;
  final LatLng? toLatLng;

  bool get isTransit => mode != LegMode.walk;
  int get totalMinutes => minutes + waitMinutes;
  bool get hasGeometry => points.length >= 2;
  String? get boardingStopCode => stopCodes.isEmpty ? null : stopCodes.first;

  String get label => switch (mode) {
    LegMode.walk => 'Walk',
    LegMode.bus => 'Bus $serviceNo',
    LegMode.rail => '$lineId train',
  };

  /// Child-facing wording: short, concrete, no jargon.
  String get childLabel => switch (mode) {
    LegMode.walk => 'Walk to $to',
    LegMode.bus => 'Bus $serviceNo to $to',
    LegMode.rail => 'Train to $to',
  };

  String get vehicleWord => mode == LegMode.rail ? 'train' : 'bus';
  String get stopWord => mode == LegMode.rail ? 'station' : 'bus stop';

  bool samePlaceAs(RouteLeg other) =>
      mode == other.mode &&
      from == other.from &&
      to == other.to &&
      lineId == other.lineId &&
      serviceNo == other.serviceNo;

  RouteLeg copyWith({List<LatLng>? points, LatLng? fromLatLng, LatLng? toLatLng, int? distanceM}) => RouteLeg(
    mode: mode,
    from: from,
    to: to,
    minutes: minutes,
    lineId: lineId,
    serviceNo: serviceNo,
    stops: stops,
    stopCodes: stopCodes,
    waitMinutes: waitMinutes,
    points: points ?? this.points,
    steps: steps,
    distanceM: distanceM ?? this.distanceM,
    fromLatLng: fromLatLng ?? this.fromLatLng,
    toLatLng: toLatLng ?? this.toLatLng,
  );

  factory RouteLeg.fromJson(Map<String, dynamic> j) {
    LatLng? ll(dynamic v) =>
        v is List && v.length == 2 && v[0] != null && v[1] != null ? LatLng.fromJson(v) : null;
    return RouteLeg(
      mode: switch (j['mode']) { 'bus' => LegMode.bus, 'rail' => LegMode.rail, _ => LegMode.walk },
      from: j['from'] as String,
      to: j['to'] as String,
      minutes: (j['minutes'] as num).round(),
      waitMinutes: ((j['waitMinutes'] ?? 0) as num).round(),
      lineId: j['lineId'] as String?,
      serviceNo: j['serviceNo'] as String?,
      stops: [for (final s in (j['stops'] ?? []) as List) s as String],
      stopCodes: [for (final s in (j['stopCodes'] ?? []) as List) s as String?],
      points: [for (final p in (j['points'] ?? []) as List) LatLng.fromJson(p as List)],
      steps: [for (final s in (j['steps'] ?? []) as List) WalkStep.fromJson(s as Map<String, dynamic>)],
      distanceM: ((j['distanceM'] ?? 0) as num).round(),
      fromLatLng: ll(j['fromLatLon']),
      toLatLng: ll(j['toLatLon']),
    );
  }
}

class RouteCandidate {
  const RouteCandidate({
    required this.id,
    required this.destinationId,
    required this.legs,
    this.source = 'demo',
  });
  final String id;
  final String destinationId;
  final List<RouteLeg> legs;
  /// 'onemap' for live itineraries, 'demo' for offline fixtures.
  final String source;

  bool get live => source == 'onemap';
  int get totalMinutes => legs.fold(0, (sum, l) => sum + l.totalMinutes);
  int get walkMinutes =>
      legs.where((l) => l.mode == LegMode.walk).fold(0, (s, l) => s + l.minutes);
  int get longestWalk => legs
      .where((l) => l.mode == LegMode.walk)
      .fold(0, (m, l) => l.minutes > m ? l.minutes : m);
  int get transitLegCount => legs.where((l) => l.isTransit).length;
  int get transfers => transitLegCount == 0 ? 0 : transitLegCount - 1;

  /// e.g. "Walk → Bus 10 → Walk"
  String get summary => legs.map((l) => l.label).join(' → ');

  /// Minutes still to travel from leg [fromIndex] onward.
  int remainingMinutes(int fromIndex) => legs
      .skip(fromIndex.clamp(0, legs.length))
      .fold(0, (s, l) => s + l.totalMinutes);

  /// True when the first [count] legs are the same places as [other]'s,
  /// meaning a child who has completed those legs can switch to this route.
  bool sharesPrefixWith(RouteCandidate other, int count) {
    if (count > legs.length || count > other.legs.length) return false;
    for (var i = 0; i < count; i++) {
      if (!legs[i].samePlaceAs(other.legs[i])) return false;
    }
    return true;
  }

  RouteCandidate copyWith({String? id, List<RouteLeg>? legs, String? source}) => RouteCandidate(
    id: id ?? this.id,
    destinationId: destinationId,
    legs: legs ?? this.legs,
    source: source ?? this.source,
  );

  factory RouteCandidate.fromJson(Map<String, dynamic> j, {required String destinationId}) => RouteCandidate(
    id: j['id'] as String,
    destinationId: destinationId,
    source: (j['source'] ?? 'onemap') as String,
    legs: [for (final l in j['legs'] as List) RouteLeg.fromJson(l as Map<String, dynamic>)],
  );
}

/// Limits that keep a route suitable for a primary school child.
class ChildLimits {
  const ChildLimits({
    this.maxWalkMinutesPerLeg = 15,
    this.maxTransfers = 2,
    this.alertThresholdMinutes = 5,
    this.transferPenaltyMinutes = 6,
  });
  final int maxWalkMinutesPerLeg;
  final int maxTransfers;

  /// Delays below this are shown as information only, never as an alert.
  final int alertThresholdMinutes;

  /// Each transfer counts as this many extra minutes when ranking routes,
  /// so a simpler route can outrank a slightly faster one.
  final int transferPenaltyMinutes;

  ChildLimits copyWith({
    int? maxWalkMinutesPerLeg,
    int? maxTransfers,
    int? alertThresholdMinutes,
    int? transferPenaltyMinutes,
  }) => ChildLimits(
    maxWalkMinutesPerLeg: maxWalkMinutesPerLeg ?? this.maxWalkMinutesPerLeg,
    maxTransfers: maxTransfers ?? this.maxTransfers,
    alertThresholdMinutes: alertThresholdMinutes ?? this.alertThresholdMinutes,
    transferPenaltyMinutes:
        transferPenaltyMinutes ?? this.transferPenaltyMinutes,
  );
}

/// Formats minutes-of-day as HH:mm.
String hhmm(int minutesOfDay) {
  final m = ((minutesOfDay % 1440) + 1440) % 1440;
  return '${(m ~/ 60).toString().padLeft(2, '0')}:${(m % 60).toString().padLeft(2, '0')}';
}

int parseHhmm(String text) {
  final parts = text.split(':');
  return int.parse(parts[0]) * 60 + int.parse(parts[1]);
}
