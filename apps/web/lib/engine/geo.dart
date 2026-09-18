import 'dart:math' as math;

/// Small geodesy helpers used by the watch navigation and the maps.
class LatLng {
  const LatLng(this.lat, this.lon);
  final double lat;
  final double lon;

  factory LatLng.fromJson(List<dynamic> j) =>
      LatLng((j[0] as num).toDouble(), (j[1] as num).toDouble());
  List<double> toJson() => [lat, lon];

  @override
  String toString() => '${lat.toStringAsFixed(5)},${lon.toStringAsFixed(5)}';
  @override
  bool operator ==(Object other) => other is LatLng && other.lat == lat && other.lon == lon;
  @override
  int get hashCode => Object.hash(lat, lon);
}

abstract final class Geo {
  static const earthRadiusM = 6371000.0;

  static double _rad(double d) => d * math.pi / 180;
  static double _deg(double r) => r * 180 / math.pi;

  static double distanceM(LatLng a, LatLng b) {
    final dLat = _rad(b.lat - a.lat);
    final dLon = _rad(b.lon - a.lon);
    final h = math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(_rad(a.lat)) * math.cos(_rad(b.lat)) * math.sin(dLon / 2) * math.sin(dLon / 2);
    return 2 * earthRadiusM * math.asin(math.sqrt(h));
  }

  /// Compass bearing from [a] to [b] in degrees, 0 = north, clockwise.
  static double bearingDeg(LatLng a, LatLng b) {
    final y = math.sin(_rad(b.lon - a.lon)) * math.cos(_rad(b.lat));
    final x = math.cos(_rad(a.lat)) * math.sin(_rad(b.lat)) -
        math.sin(_rad(a.lat)) * math.cos(_rad(b.lat)) * math.cos(_rad(b.lon - a.lon));
    return (_deg(math.atan2(y, x)) + 360) % 360;
  }

  /// Signed smallest difference between two bearings, in (-180, 180].
  static double turnDeg(double from, double to) {
    var d = (to - from) % 360;
    if (d > 180) d -= 360;
    if (d <= -180) d += 360;
    return d;
  }

  static LatLng lerp(LatLng a, LatLng b, double t) =>
      LatLng(a.lat + (b.lat - a.lat) * t, a.lon + (b.lon - a.lon) * t);

  /// Cumulative distance at each vertex; `cum.last` is the total length.
  static List<double> cumulative(List<LatLng> pts) {
    final cum = <double>[0];
    for (var i = 1; i < pts.length; i++) {
      cum.add(cum[i - 1] + distanceM(pts[i - 1], pts[i]));
    }
    return cum;
  }

  static LatLng pointAt(List<LatLng> pts, List<double> cum, double dist) {
    if (pts.isEmpty) return const LatLng(0, 0);
    if (pts.length == 1 || dist <= 0) return pts.first;
    if (dist >= cum.last) return pts.last;
    var i = 1;
    while (i < cum.length && cum[i] < dist) {
      i++;
    }
    final seg = cum[i] - cum[i - 1];
    final t = seg == 0 ? 0.0 : (dist - cum[i - 1]) / seg;
    return lerp(pts[i - 1], pts[i], t);
  }

  static double headingAt(List<LatLng> pts, List<double> cum, double dist) {
    if (pts.length < 2) return 0;
    var i = 1;
    while (i < cum.length - 1 && cum[i] <= dist) {
      i++;
    }
    return bearingDeg(pts[i - 1], pts[i]);
  }
}

enum TurnKind { start, straight, slightLeft, left, sharpLeft, slightRight, right, sharpRight, uturn, arrive }

/// What the watch shows next: one turn, one distance, one street.
class TurnGuidance {
  const TurnGuidance({required this.kind, required this.distanceM, this.street = '', this.at, this.headingIn = 0, this.turnDeg = 0});
  final TurnKind kind;
  final double distanceM;
  final String street;
  /// Where the turn happens, the heading arriving at it and the signed turn.
  final LatLng? at;
  final double headingIn;
  final double turnDeg;

  String get words => switch (kind) {
    TurnKind.start => 'Start walking',
    TurnKind.straight => 'Keep going straight',
    TurnKind.slightLeft => 'Keep left',
    TurnKind.left => 'Turn left',
    TurnKind.sharpLeft => 'Turn sharp left',
    TurnKind.slightRight => 'Keep right',
    TurnKind.right => 'Turn right',
    TurnKind.sharpRight => 'Turn sharp right',
    TurnKind.uturn => 'Turn around',
    TurnKind.arrive => 'You are almost there',
  };

  String get distanceWords => distanceM < 12
      ? 'now'
      : distanceM < 1000
      ? 'in ${(distanceM / 5).round() * 5} m'
      : 'in ${(distanceM / 1000).toStringAsFixed(1)} km';
}

abstract final class Guidance {
  /// Finds the next bend of at least [minTurnDeg] ahead of [distAlong].
  static TurnGuidance next(
    List<LatLng> pts,
    List<double> cum,
    double distAlong, {
    double minTurnDeg = 28,
    double minLegM = 4,
    String Function(int vertex)? streetAt,
  }) {
    if (pts.length < 2) return const TurnGuidance(kind: TurnKind.arrive, distanceM: 0);
    if (distAlong <= 1) return TurnGuidance(kind: TurnKind.start, distanceM: 0, street: streetAt?.call(0) ?? '');
    final total = cum.last;
    var prevHeading = Geo.headingAt(pts, cum, distAlong);
    var lastVertexDist = distAlong;
    for (var i = 1; i < pts.length - 1; i++) {
      if (cum[i] <= distAlong) continue;
      if (cum[i] - lastVertexDist < minLegM) continue;
      // Heading of the segment leaving vertex i (skip micro segments).
      var j = i + 1;
      while (j < pts.length - 1 && cum[j] - cum[i] < minLegM) {
        j++;
      }
      final nextHeading = Geo.bearingDeg(pts[i], pts[j]);
      final turn = Geo.turnDeg(prevHeading, nextHeading);
      if (turn.abs() >= minTurnDeg) {
        return TurnGuidance(
          kind: _kind(turn),
          distanceM: cum[i] - distAlong,
          street: streetAt?.call(i) ?? '',
          at: pts[i],
          headingIn: prevHeading,
          turnDeg: turn,
        );
      }
      prevHeading = nextHeading;
      lastVertexDist = cum[i];
    }
    return TurnGuidance(kind: TurnKind.arrive, distanceM: total - distAlong, at: pts.last);
  }

  static TurnKind _kind(double turn) {
    final a = turn.abs();
    if (a >= 160) return TurnKind.uturn;
    if (a >= 110) return turn < 0 ? TurnKind.sharpLeft : TurnKind.sharpRight;
    if (a >= 55) return turn < 0 ? TurnKind.left : TurnKind.right;
    return turn < 0 ? TurnKind.slightLeft : TurnKind.slightRight;
  }
}
