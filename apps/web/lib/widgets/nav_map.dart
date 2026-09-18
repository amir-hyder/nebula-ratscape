import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../engine/demo_network.dart';
import '../engine/geo.dart';
import '../models/conditions.dart';
import '../models/route_models.dart';
import 'ui_kit.dart';

/// Raster basemap on OpenStreetMap data. Providers:
///  - `osmde`  tile.openstreetmap.de (FOSSGIS community server, no key, default)
///  - `osm`    tile.openstreetmap.org (OSMF; light demo use only, see policy)
///  - `carto`  CARTO Voyager (watermarked without an API key)
///  - `onemap` SLA basemap (not OSM-derived)
///  - `custom` any {z}/{x}/{y} template passed with
///    `--dart-define=TILE_URL=... --dart-define=TILE_ATTRIBUTION=...`
/// Tiles are cached in memory for the session so each tile is fetched once.
abstract final class MapTiles {
  static const _customUrl = String.fromEnvironment('TILE_URL');
  static const _customAttribution = String.fromEnvironment('TILE_ATTRIBUTION', defaultValue: '© OpenStreetMap contributors');
  static String provider = _customUrl.isNotEmpty ? 'custom' : 'osmde';

  static String url(int z, int x, int y) => switch (provider) {
    'custom' => _customUrl.replaceAll('{z}', '$z').replaceAll('{x}', '$x').replaceAll('{y}', '$y'),
    'onemap' => 'https://www.onemap.gov.sg/maps/tiles/Default/$z/$x/$y.png',
    'carto' => 'https://basemaps.cartocdn.com/rastertiles/voyager/$z/$x/$y.png',
    'osm' => 'https://tile.openstreetmap.org/$z/$x/$y.png',
    _ => 'https://tile.openstreetmap.de/$z/$x/$y.png',
  };
  static String get attribution => switch (provider) {
    'custom' => _customAttribution,
    'onemap' => '© OneMap · SLA',
    'carto' => '© OpenStreetMap contributors · © CARTO',
    _ => '© OpenStreetMap contributors',
  };
  static const maxZoom = 19;
}

/// Kept for callers that referenced the old name.
abstract final class OneMapTiles {
  static String get attribution => MapTiles.attribution;
  static const maxZoom = MapTiles.maxZoom;
}

abstract final class WebMercator {
  static const tile = 256.0;
  static double worldSize(double zoom) => tile * math.pow(2, zoom);
  static Offset project(LatLng p, double zoom) {
    final s = worldSize(zoom);
    final x = (p.lon + 180) / 360 * s;
    final sinLat = math.sin(p.lat * math.pi / 180).clamp(-0.9999, 0.9999);
    final y = (0.5 - math.log((1 + sinLat) / (1 - sinLat)) / (4 * math.pi)) * s;
    return Offset(x, y);
  }

  /// Metres per pixel at [lat] and [zoom].
  static double metresPerPixel(double lat, double zoom) =>
      156543.03392 * math.cos(lat * math.pi / 180) / math.pow(2, zoom);
}

/// Loads and keeps raster tiles; painters listen to [version] to repaint.
class TileCache {
  TileCache._();
  static final instance = TileCache._();
  final version = ValueNotifier<int>(0);
  final _images = <String, ui.Image>{};
  final _pending = <String>{};
  final _failed = <String>{};
  bool enabled = true;

  ui.Image? get(int z, int x, int y) {
    final n = 1 << z;
    if (y < 0 || y >= n) return null;
    final wx = ((x % n) + n) % n;
    final key = '${MapTiles.provider}/$z/$wx/$y';
    final img = _images[key];
    if (img != null) return img;
    if (!enabled || _pending.contains(key) || _failed.contains(key)) return null;
    _pending.add(key);
    final stream = NetworkImage(MapTiles.url(z, wx, y)).resolve(ImageConfiguration.empty);
    late ImageStreamListener listener;
    listener = ImageStreamListener(
      (info, _) {
        _images[key] = info.image;
        _pending.remove(key);
        stream.removeListener(listener);
        version.value++;
      },
      onError: (_, _) {
        _failed.add(key);
        _pending.remove(key);
        stream.removeListener(listener);
      },
    );
    stream.addListener(listener);
    return null;
  }
}

/// One polyline to draw on a map.
class MapLine {
  const MapLine(this.points, {required this.colour, this.width = 5, this.dashed = false, this.outline = true, this.chevrons = false});
  final List<LatLng> points;
  final Color colour;
  final double width;
  final bool dashed;
  final bool outline;
  /// Direction-of-travel chevrons along the line (navigation lane look).
  final bool chevrons;
}

/// An arrow lying on the ground at a turn, drawn in perspective.
class GroundArrow {
  const GroundArrow({required this.at, required this.headingIn, required this.turnDeg});
  final LatLng at;
  final double headingIn;
  final double turnDeg;
}

class MapMarker {
  const MapMarker(this.at, {required this.colour, this.radius = 5, this.label});
  final LatLng at;
  final Color colour;
  final double radius;
  final String? label;
}

/// Draws tiles, lines and markers around [center]. With [headingDeg] the map
/// is rotated so that heading points up; [focal] is where [center] lands on
/// the canvas (defaults to the middle).
class MapPainter extends CustomPainter {
  MapPainter({
    required this.center,
    required this.zoom,
    this.headingDeg = 0,
    this.focal,
    this.lines = const [],
    this.markers = const [],
    this.tiles = true,
    this.perspective,
    this.features = const [],
    this.groundArrow,
  }) : super(repaint: TileCache.instance.version);
  final List<OsmFeature> features;
  final GroundArrow? groundArrow;
  final LatLng center;
  final double zoom;
  final double headingDeg;
  final Offset? focal;
  final List<MapLine> lines;
  final List<MapMarker> markers;
  final bool tiles;

  /// Optional 4x4 applied on the canvas around [focal] (3D tilt). Applied
  /// here rather than with a Transform widget because Flutter web drops
  /// layers whose transform has a perspective term.
  final Matrix4? perspective;

  @override
  void paint(Canvas canvas, Size size) {
    final f = focal ?? Offset(size.width / 2, size.height / 2);
    final c = WebMercator.project(center, zoom);
    canvas.save();
    canvas.clipRect(Offset.zero & size);
    canvas.drawRect(Offset.zero & size, Paint()..color = const Color(0xFFE9EFEA));
    canvas.translate(f.dx, f.dy);
    if (perspective != null) canvas.transform(perspective!.storage);
    canvas.rotate(-headingDeg * math.pi / 180);
    canvas.translate(-c.dx, -c.dy);

    if (tiles) _drawTiles(canvas, size, c, f);
    for (final line in lines) {
      _drawLine(canvas, line);
    }
    for (final f in features) {
      _drawFeature(canvas, f);
    }
    if (groundArrow != null) _drawGroundArrow(canvas, groundArrow!);
    for (final m in markers) {
      final p = WebMercator.project(m.at, zoom);
      canvas.drawCircle(p, m.radius + 2, Paint()..color = Colors.white);
      canvas.drawCircle(p, m.radius, Paint()..color = m.colour);
    }
    canvas.restore();
  }

  void _drawTiles(Canvas canvas, Size size, Offset c, Offset f) {
    final z = zoom.round().clamp(1, OneMapTiles.maxZoom);
    final scale = math.pow(2, zoom - z).toDouble();
    final r = math.sqrt(size.width * size.width + size.height * size.height) / 2 + math.max(f.dy, size.height - f.dy);
    final ts = WebMercator.tile * scale;
    final x0 = ((c.dx - r) / ts).floor();
    final x1 = ((c.dx + r) / ts).ceil();
    final y0 = ((c.dy - r) / ts).floor();
    final y1 = ((c.dy + r) / ts).ceil();
    final paint = Paint()..filterQuality = FilterQuality.medium;
    for (var x = x0; x <= x1; x++) {
      for (var y = y0; y <= y1; y++) {
        final dst = Rect.fromLTWH(x * ts, y * ts, ts + .5, ts + .5);
        final img = TileCache.instance.get(z, x, y);
        if (img == null) {
          canvas.drawRect(dst, Paint()..color = const Color(0xFFE3EAE4));
          canvas.drawRect(dst, Paint()..color = const Color(0xFFD5DED7)..style = PaintingStyle.stroke..strokeWidth = .5);
        } else {
          canvas.drawImageRect(img, Rect.fromLTWH(0, 0, img.width.toDouble(), img.height.toDouble()), dst, paint);
        }
      }
    }
  }

  void _drawLine(Canvas canvas, MapLine line) {
    if (line.points.length < 2) return;
    final path = Path();
    final first = WebMercator.project(line.points.first, zoom);
    path.moveTo(first.dx, first.dy);
    for (final p in line.points.skip(1)) {
      final o = WebMercator.project(p, zoom);
      path.lineTo(o.dx, o.dy);
    }
    if (line.outline) {
      canvas.drawPath(
        path,
        Paint()
          ..color = Colors.white
          ..style = PaintingStyle.stroke
          ..strokeWidth = line.width + 3
          ..strokeCap = StrokeCap.round
          ..strokeJoin = StrokeJoin.round,
      );
    }
    final paint = Paint()
      ..color = line.colour
      ..style = PaintingStyle.stroke
      ..strokeWidth = line.width
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    if (!line.dashed) {
      canvas.drawPath(path, paint);
      if (line.chevrons) _drawChevrons(canvas, path, line);
      return;
    }
    for (final metric in path.computeMetrics()) {
      var d = 0.0;
      while (d < metric.length) {
        canvas.drawPath(metric.extractPath(d, math.min(d + 8, metric.length)), paint);
        d += 14;
      }
    }
  }

  /// White ">" glyphs every few metres, pointing along the path.
  void _drawChevrons(Canvas canvas, Path path, MapLine line) {
    final paint = Paint()
      ..color = Colors.white.withAlpha(235)
      ..style = PaintingStyle.stroke
      ..strokeWidth = line.width * .32
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    final size = line.width * .42;
    for (final metric in path.computeMetrics()) {
      var d = 14.0;
      while (d < metric.length - 6) {
        final t = metric.getTangentForOffset(d);
        if (t != null) {
          canvas.save();
          canvas.translate(t.position.dx, t.position.dy);
          canvas.rotate(-t.angle);
          canvas.drawPath(
            Path()
              ..moveTo(-size, -size)
              ..lineTo(0, 0)
              ..lineTo(-size, size),
            paint,
          );
          canvas.restore();
        }
        d += 26;
      }
    }
  }

  void _drawFeature(Canvas canvas, OsmFeature f) {
    final p = WebMercator.project(f.at, zoom);
    switch (f.kind) {
      case 'crossing':
        // Zebra stripes: black/white bars, readable without colour.
        canvas.save();
        canvas.translate(p.dx, p.dy);
        canvas.rotate(-headingDeg * math.pi / 180);
        canvas.drawRRect(RRect.fromRectAndRadius(const Rect.fromLTWH(-9, -6, 18, 12), const Radius.circular(2)), Paint()..color = const Color(0xFF111827));
        for (var x = -7.0; x < 8; x += 4) {
          canvas.drawRect(Rect.fromLTWH(x, -5, 2, 10), Paint()..color = Colors.white);
        }
        canvas.restore();
      case 'steps':
        canvas.drawCircle(p, 6, Paint()..color = Colors.white);
        canvas.drawCircle(p, 4.5, Paint()..color = Navi.amber);
      case 'covered' || 'shelter':
        canvas.drawCircle(p, 6, Paint()..color = Colors.white);
        canvas.drawCircle(p, 4.5, Paint()..color = const Color(0xFF0EA5E9));
      default:
        canvas.drawCircle(p, 8, Paint()..color = Colors.white);
        canvas.drawCircle(p, 6, Paint()..color = const Color(0xFF7C3AED));
    }
  }

  /// A fat 3D-style arrow on the road surface, bent in the turn direction.
  void _drawGroundArrow(Canvas canvas, GroundArrow a) {
    final p = WebMercator.project(a.at, zoom);
    canvas.save();
    canvas.translate(p.dx, p.dy);
    canvas.rotate((a.headingIn - headingDeg) * math.pi / 180);
    final bend = a.turnDeg.abs() < 25 ? 0.0 : (a.turnDeg < 0 ? -1.0 : 1.0);
    final path = Path()..moveTo(-5, 28)..lineTo(5, 28)..lineTo(5, 2);
    if (bend == 0) {
      path
        ..lineTo(14, 2)
        ..lineTo(0, -20)
        ..lineTo(-14, 2)
        ..lineTo(-5, 2);
    } else {
      path
        ..lineTo(5 + bend * 14, 2)
        ..lineTo(5 + bend * 14, 12)
        ..lineTo(5 + bend * 34, -4)
        ..lineTo(5 + bend * 14, -20)
        ..lineTo(5 + bend * 14, -8)
        ..lineTo(-5, -8);
    }
    path.close();
    canvas.drawPath(path.shift(const Offset(2, 3)), Paint()..color = Colors.black.withAlpha(70));
    canvas.drawPath(path, Paint()..color = const Color(0xFF1D4ED8));
    canvas.drawPath(path, Paint()..color = Colors.white..style = PaintingStyle.stroke..strokeWidth = 2.5..strokeJoin = StrokeJoin.round);
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant MapPainter old) => true;
}

Color legColour(RouteLeg leg) => switch (leg.mode) {
  LegMode.walk => const Color(0xFF3B82F6),
  LegMode.bus => Navi.teal,
  LegMode.rail => Color(DemoNetwork.line(leg.lineId)?.colour ?? 0xFF333333),
};

/// Watch navigation: the map is tilted into perspective and rotated so the
/// child's direction of travel is up. A fixed arrow marks the child; the
/// banner says the next turn in words a young child can follow.
class NavMap3D extends StatelessWidget {
  /// Debug switch: 'canvas' (default, perspective applied in the painter),
  /// 'filter' (rasterised Transform), 'widget' (plain Transform), 'flat'.
  static String mode = 'canvas';

  const NavMap3D({
    super.key,
    required this.path,
    required this.position,
    required this.headingDeg,
    required this.guidance,
    required this.metresLeft,
    required this.destinationLabel,
    this.features = const [],
    this.height = 175,
    this.zoom = 18.4,
  });
  final List<LatLng> path;
  final LatLng position;
  final double headingDeg;
  final TurnGuidance guidance;
  final double metresLeft;
  final String destinationLabel;
  final List<OsmFeature> features;
  final double height;
  final double zoom;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, c) {
      final w = c.maxWidth;
      final h = height;
      final focal = Offset(w / 2, h * .82);
      return ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: SizedBox(
          width: w,
          height: h,
          child: Stack(
            children: [
              // Perspective ground plane.
              Positioned.fill(
                child: switch (mode) {
                  'widget' || 'filter' => Transform(
                    alignment: Alignment.topLeft,
                    origin: focal,
                    filterQuality: mode == 'filter' ? FilterQuality.low : null,
                    transform: Matrix4.identity()
                      ..setEntry(3, 2, 0.0022)
                      ..rotateX(-0.95),
                    child: _bigCanvas(w, h, focal, null),
                  ),
                  'flat' => _bigCanvas(w, h, focal, null),
                  _ => _bigCanvas(
                    w,
                    h,
                    focal,
                    Matrix4.identity()
                      ..setEntry(3, 2, 0.0022)
                      ..rotateX(-0.95),
                  ),
                },
              ),
              // Sky haze at the horizon.
              Positioned(
                left: 0,
                right: 0,
                top: 0,
                height: h * .45,
                child: IgnorePointer(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [const Color(0xFFDDEBF7).withAlpha(235), const Color(0xFFDDEBF7).withAlpha(0)],
                      ),
                    ),
                  ),
                ),
              ),
              // Child arrow (3D chevron with ground shadow).
              Positioned(
                left: focal.dx - 22,
                top: focal.dy - 24,
                child: const _ChildArrow(),
              ),
              // Turn banner.
              Positioned(
                left: 6,
                right: 6,
                top: 6,
                child: _TurnBanner(guidance: guidance),
              ),
              Positioned(
                left: 8,
                bottom: 5,
                child: Text(
                  '${metresLeft.round()} m to $destinationLabel',
                  style: const TextStyle(fontSize: 9.5, fontWeight: FontWeight.w800, color: Navi.ink),
                ),
              ),
              Positioned(
                right: 6,
                bottom: 4,
                child: Text(MapTiles.attribution, style: const TextStyle(fontSize: 7, color: Navi.muted)),
              ),
            ],
          ),
        ),
      );
    },
  );
}

extension on NavMap3D {
  /// A canvas three times the viewport, positioned so that the child's
  /// point lands on [focal]; the painter draws heading-up around it.
  Widget _bigCanvas(double w, double h, Offset focal, Matrix4? perspective) => OverflowBox(
    maxWidth: w * 3,
    maxHeight: h * 3,
    alignment: Alignment.topLeft,
    child: Transform.translate(
      offset: Offset(-w, -h * 1.5),
      child: SizedBox(
        width: w * 3,
        height: h * 3,
        child: CustomPaint(
          painter: MapPainter(
            center: position,
            zoom: zoom,
            headingDeg: headingDeg,
            focal: Offset(w + focal.dx, h * 1.5 + focal.dy),
            perspective: perspective,
            lines: [
              MapLine(path, colour: const Color(0xFF2563EB), width: 11, chevrons: true),
            ],
            features: features,
            groundArrow: guidance.at != null && guidance.kind != TurnKind.start && guidance.kind != TurnKind.arrive
                ? GroundArrow(at: guidance.at!, headingIn: guidance.headingIn, turnDeg: guidance.turnDeg)
                : null,
            markers: [
              if (path.isNotEmpty) MapMarker(path.last, colour: const Color(0xFF16A34A), radius: 7),
            ],
          ),
        ),
      ),
    ),
  );
}

class _ChildArrow extends StatelessWidget {
  const _ChildArrow();
  @override
  Widget build(BuildContext context) => SizedBox(
    width: 44,
    height: 48,
    child: CustomPaint(painter: _ArrowPainter()),
  );
}

/// Extruded chevron: a dark base slab, a lit top face and a highlight edge,
/// over a soft ground shadow, so it reads as a solid object on the road.
class _ArrowPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size s) {
    final cx = s.width / 2;
    Path chevron(double dy, double scale) => Path()
      ..moveTo(cx, 4 + dy)
      ..lineTo(cx + 18 * scale, 36 + dy)
      ..lineTo(cx, 27 + dy)
      ..lineTo(cx - 18 * scale, 36 + dy)
      ..close();
    // Ground shadow.
    canvas.drawOval(
      Rect.fromCenter(center: Offset(cx, 41), width: 34, height: 11),
      Paint()
        ..color = Colors.black.withAlpha(60)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3),
    );
    // Extrusion: several darker slabs stacked downwards.
    for (var i = 5.0; i >= 1; i -= 1) {
      canvas.drawPath(chevron(i, 1), Paint()..color = const Color(0xFF0B4F4A));
    }
    // Top face with a light-to-dark gradient.
    final top = chevron(0, 1);
    canvas.drawPath(
      top,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF5EEAD4), Color(0xFF0F766E)],
        ).createShader(top.getBounds()),
    );
    canvas.drawPath(
      top,
      Paint()
        ..color = Colors.white
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..strokeJoin = StrokeJoin.round,
    );
    // Specular highlight along the leading edge.
    canvas.drawLine(Offset(cx, 6), Offset(cx + 12, 26), Paint()..color = Colors.white.withAlpha(150)..strokeWidth = 2);
  }

  @override
  bool shouldRepaint(covariant CustomPainter old) => false;
}

class _TurnBanner extends StatelessWidget {
  const _TurnBanner({required this.guidance});
  final TurnGuidance guidance;

  IconData get _icon => switch (guidance.kind) {
    TurnKind.start => Icons.directions_walk,
    TurnKind.straight => Icons.straight,
    TurnKind.slightLeft => Icons.turn_slight_left,
    TurnKind.left => Icons.turn_left,
    TurnKind.sharpLeft => Icons.turn_sharp_left,
    TurnKind.slightRight => Icons.turn_slight_right,
    TurnKind.right => Icons.turn_right,
    TurnKind.sharpRight => Icons.turn_sharp_right,
    TurnKind.uturn => Icons.u_turn_left,
    TurnKind.arrive => Icons.flag,
  };

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
    decoration: BoxDecoration(
      color: Navi.tealDark,
      borderRadius: BorderRadius.circular(12),
      boxShadow: const [BoxShadow(color: Color(0x44000000), blurRadius: 6, offset: Offset(0, 2))],
    ),
    child: Row(
      children: [
        Container(
          width: 34,
          height: 34,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(9),
            boxShadow: const [BoxShadow(color: Color(0x55000000), blurRadius: 4, offset: Offset(0, 2))],
          ),
          child: Icon(_icon, color: Navi.tealDark, size: 28),
        ),
        const SizedBox(width: 7),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                guidance.words,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w900),
              ),
              Text(
                guidance.street.isEmpty ? guidance.distanceWords : '${guidance.distanceWords} · ${guidance.street}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: Color(0xFFCDF3EF), fontSize: 9.5, fontWeight: FontWeight.w700),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}

/// Flat overview for the parent phone: whole route(s) fitted into the box.
class MiniMap extends StatelessWidget {
  const MiniMap({
    super.key,
    required this.route,
    this.original,
    this.affectedLegIndex = -1,
    this.child,
    this.features = const [],
    this.height = 170,
  });
  final RouteCandidate route;
  final RouteCandidate? original;
  final int affectedLegIndex;
  final LatLng? child;
  /// OSM points of interest (e.g. safe places near the child).
  final List<OsmFeature> features;
  final double height;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, c) {
      final all = <LatLng>[
        for (final l in route.legs) ...l.points,
        if (original != null) for (final l in original!.legs) ...l.points,
        ?child,
      ];
      if (all.length < 2) {
        return Container(
          height: height,
          alignment: Alignment.center,
          decoration: BoxDecoration(color: const Color(0xFFE9EFEA), borderRadius: BorderRadius.circular(16)),
          child: const Text('No route geometry yet', style: TextStyle(fontSize: 11, color: Navi.muted)),
        );
      }
      var minLat = all.first.lat, maxLat = all.first.lat, minLon = all.first.lon, maxLon = all.first.lon;
      for (final p in all) {
        minLat = math.min(minLat, p.lat);
        maxLat = math.max(maxLat, p.lat);
        minLon = math.min(minLon, p.lon);
        maxLon = math.max(maxLon, p.lon);
      }
      final center = LatLng((minLat + maxLat) / 2, (minLon + maxLon) / 2);
      var zoom = 17.0;
      while (zoom > 10) {
        final a = WebMercator.project(LatLng(minLat, minLon), zoom);
        final b = WebMercator.project(LatLng(maxLat, maxLon), zoom);
        if ((b.dx - a.dx).abs() < c.maxWidth - 40 && (a.dy - b.dy).abs() < height - 40) break;
        zoom -= 0.25;
      }
      final lines = <MapLine>[
        if (original != null)
          for (final (i, l) in original!.legs.indexed)
            MapLine(
              l.points,
              colour: i == affectedLegIndex ? const Color(0xFFD42E12) : const Color(0xFF9AA5B1),
              width: i == affectedLegIndex ? 6 : 4,
              dashed: i == affectedLegIndex,
              outline: false,
            ),
        for (final (i, l) in route.legs.indexed)
          MapLine(
            l.points,
            colour: original == null && i == affectedLegIndex ? const Color(0xFFD42E12) : legColour(l),
            width: l.mode == LegMode.walk ? 4 : 6,
            dashed: l.mode == LegMode.walk,
          ),
      ];
      return ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: SizedBox(
          height: height,
          width: c.maxWidth,
          child: Stack(
            children: [
              Positioned.fill(
                child: CustomPaint(
                  painter: MapPainter(
                    center: center,
                    zoom: zoom,
                    lines: lines,
                    features: features,
                    markers: [
                      MapMarker(route.legs.first.points.first, colour: Navi.tealDark),
                      MapMarker(route.legs.last.points.last, colour: const Color(0xFF16A34A)),
                      ?child == null ? null : MapMarker(child!, colour: const Color(0xFF2563EB), radius: 7),
                    ],
                  ),
                ),
              ),
              Positioned(
                left: 8,
                top: 6,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                  decoration: BoxDecoration(color: Colors.white.withAlpha(225), borderRadius: BorderRadius.circular(8)),
                  child: Text(
                    original == null ? 'Live map' : 'Grey dashed = original · red = affected',
                    style: const TextStyle(fontSize: 9.5, fontWeight: FontWeight.w800, color: Navi.ink),
                  ),
                ),
              ),
              Positioned(
                right: 6,
                bottom: 4,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                  color: Colors.white.withAlpha(200),
                  child: Text(
                    '${MapTiles.attribution} · ${route.live ? 'route: OneMap' : 'route: simulated'}',
                    style: const TextStyle(fontSize: 8, color: Navi.secondary),
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    },
  );
}
