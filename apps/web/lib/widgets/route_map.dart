import 'package:flutter/material.dart';

import '../engine/demo_network.dart';
import '../models/route_models.dart';
import 'ui_kit.dart';

/// Schematic strip map: one row per route, legs sized by minutes, MRT legs
/// in their line colour, the affected leg hatched red, and the child's
/// current position marked. When [original] is given it is drawn above the
/// new route so a parent can compare them at a glance. Simulated geometry;
/// the OSM map replaces this later.
class RouteStripMap extends StatelessWidget {
  const RouteStripMap({
    super.key,
    required this.route,
    this.original,
    this.affectedLegIndex = -1,
    this.currentLegIndex = -1,
    this.compact = false,
  });
  final RouteCandidate route;
  final RouteCandidate? original;
  final int affectedLegIndex;
  final int currentLegIndex;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final rows = <_Row>[
      if (original != null)
        _Row(original!, 'Original', affected: affectedLegIndex, faded: true),
      _Row(
        route,
        original == null ? 'Route' : 'New route',
        affected: original == null ? affectedLegIndex : -1,
        current: currentLegIndex,
      ),
    ];
    final rowHeight = compact ? 34.0 : 58.0;
    return Container(
      width: double.infinity,
      padding: EdgeInsets.fromLTRB(compact ? 6 : 12, compact ? 6 : 10, compact ? 6 : 12, compact ? 4 : 8),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(compact ? 12 : 18),
        color: const Color(0xFFE8F4F0),
        border: Border.all(color: const Color(0xFFB8DDD4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final r in rows)
            SizedBox(
              height: rowHeight,
              width: double.infinity,
              child: CustomPaint(painter: _StripPainter(r, compact)),
            ),
          if (!compact)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Wrap(
                crossAxisAlignment: WrapCrossAlignment.center,
                runSpacing: 2,
                children: [
                  _legend(const Color(0xFF9AA5B1), 'Walk', dotted: true),
                  _legend(Navi.teal, 'Bus'),
                  _legend(const Color(0xFFD42E12), 'Affected', hatched: true),
                  const Text(
                    'Schematic · simulated',
                    style: TextStyle(fontSize: 9, color: Navi.muted),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _legend(Color c, String label, {bool dotted = false, bool hatched = false}) =>
      Padding(
        padding: const EdgeInsets.only(right: 10),
        child: Row(
          children: [
            Container(
              width: 14,
              height: 4,
              decoration: BoxDecoration(
                color: dotted ? null : c,
                border: dotted ? Border.all(color: c) : null,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(width: 4),
            Text(label, style: const TextStyle(fontSize: 9, color: Navi.muted)),
          ],
        ),
      );
}

class _Row {
  const _Row(this.route, this.label, {this.affected = -1, this.current = -1, this.faded = false});
  final RouteCandidate route;
  final String label;
  final int affected;
  final int current;
  final bool faded;
}

class _StripPainter extends CustomPainter {
  _StripPainter(this.row, this.compact);
  final _Row row;
  final bool compact;

  @override
  void paint(Canvas canvas, Size size) {
    final legs = row.route.legs;
    final y = compact ? size.height * .5 : size.height * .42;
    final left = 8.0;
    final right = size.width - 8.0;
    final total = row.route.totalMinutes.toDouble();
    final minW = compact ? 14.0 : 26.0;
    // Proportional widths with a floor so short walks stay visible.
    var widths = legs.map((l) => (right - left) * l.totalMinutes / total).toList();
    final deficit = widths.fold(0.0, (s, w) => s + (w < minW ? minW - w : 0));
    final flexible = widths.fold(0.0, (s, w) => s + (w >= minW ? w - minW : 0));
    widths = [
      for (final w in widths)
        w < minW ? minW : minW + (w - minW) * (1 - (flexible == 0 ? 0 : deficit / flexible)),
    ];

    if (!compact) {
      _text(canvas, row.label.toUpperCase(), Offset(left, 0),
          size: 8, color: Navi.muted, bold: true);
    }

    var x = left;
    final alpha = row.faded ? 110 : 255;
    for (var i = 0; i < legs.length; i++) {
      final leg = legs[i];
      final w = widths[i];
      final affected = i == row.affected;
      final colour = affected
          ? const Color(0xFFD42E12)
          : switch (leg.mode) {
              LegMode.walk => const Color(0xFF9AA5B1),
              LegMode.bus => Navi.teal,
              LegMode.rail => Color(DemoNetwork.line(leg.lineId)?.colour ?? 0xFF333333),
            };
      final paint = Paint()
        ..color = colour.withAlpha(alpha)
        ..strokeWidth = compact ? 4 : 6
        ..strokeCap = StrokeCap.round
        ..style = PaintingStyle.stroke;
      if (leg.mode == LegMode.walk && !affected) {
        var dx = x + 3;
        final dot = Paint()..color = colour.withAlpha(alpha);
        while (dx < x + w - 2) {
          canvas.drawCircle(Offset(dx, y), compact ? 1.4 : 2, dot);
          dx += compact ? 5 : 7;
        }
      } else {
        canvas.drawLine(Offset(x + 2, y), Offset(x + w - 2, y), paint);
        if (affected) {
          final hatch = Paint()
            ..color = Colors.white.withAlpha(200)
            ..strokeWidth = 2;
          var hx = x + 6;
          while (hx < x + w - 4) {
            canvas.drawLine(Offset(hx, y - 4), Offset(hx + 4, y + 4), hatch);
            hx += 8;
          }
        }
      }
      if (!compact && leg.isTransit) {
        _text(canvas, leg.label, Offset(x + w / 2, y - 17),
            size: 8.5, color: colour.withAlpha(alpha), bold: true, center: true);
      }
      if (!compact) {
        _text(canvas, '${leg.totalMinutes}m', Offset(x + w / 2, y + 6),
            size: 8, color: Navi.muted.withAlpha(alpha), center: true);
      }
      x += w;
    }

    // Station dots at leg boundaries.
    x = left;
    for (var i = 0; i <= legs.length; i++) {
      final isEnd = i == 0 || i == legs.length;
      canvas.drawCircle(Offset(x, y), compact ? 3 : 4.5, Paint()..color = Colors.white);
      canvas.drawCircle(
        Offset(x, y),
        compact ? 2 : 3,
        Paint()..color = (isEnd ? Navi.tealDark : Navi.secondary).withAlpha(alpha),
      );
      if (i < legs.length) x += widths[i];
    }
    if (!compact) {
      _text(canvas, legs.first.from, Offset(left, y + 16), size: 8, color: Navi.ink, bold: true);
      _text(canvas, legs.last.to, Offset(right, y + 16), size: 8, color: Navi.ink, bold: true, alignRight: true);
    }

    // Child position: at the start of the current leg.
    if (row.current >= 0 && row.current < legs.length) {
      var px = left;
      for (var i = 0; i < row.current; i++) {
        px += widths[i];
      }
      px += widths[row.current] * .35;
      canvas.drawCircle(Offset(px, y), compact ? 6 : 8, Paint()..color = Navi.tealDark.withAlpha(60));
      canvas.drawCircle(Offset(px, y), compact ? 3.5 : 5, Paint()..color = Navi.tealDark);
      canvas.drawCircle(Offset(px, y), compact ? 1.5 : 2, Paint()..color = Colors.white);
    }
  }

  void _text(Canvas c, String s, Offset at,
      {double size = 9, Color color = Navi.ink, bool bold = false, bool center = false, bool alignRight = false}) {
    final tp = TextPainter(
      text: TextSpan(
        text: s,
        style: TextStyle(fontSize: size, color: color, fontWeight: bold ? FontWeight.w800 : FontWeight.w500),
      ),
      textDirection: TextDirection.ltr,
      maxLines: 1,
      ellipsis: '…',
    )..layout(maxWidth: 90);
    final dx = center ? at.dx - tp.width / 2 : alignRight ? at.dx - tp.width : at.dx;
    tp.paint(c, Offset(dx, at.dy));
  }

  @override
  bool shouldRepaint(covariant _StripPainter old) =>
      old.row.route.id != row.route.id ||
      old.row.affected != row.affected ||
      old.row.current != row.current ||
      old.row.faded != row.faded;
}
