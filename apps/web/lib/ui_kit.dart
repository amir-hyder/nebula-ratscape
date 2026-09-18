import 'package:flutter/material.dart';

abstract final class Navi {
  static const teal = Color(0xFF10A3A0);
  static const tealDark = Color(0xFF0F766E);
  static const ink = Color(0xFF0C111D);
  static const secondary = Color(0xFF475467);
  static const muted = Color(0xFF667085);
  static const mint = Color(0xFFF0FDFA);
  static const red = Color(0xFFC83F43);
  static const amber = Color(0xFFB66711);
  static ThemeData theme() => ThemeData(
    useMaterial3: true,
    scaffoldBackgroundColor: mint,
    colorScheme: ColorScheme.fromSeed(
      seedColor: teal,
      primary: tealDark,
      surface: Colors.white,
    ),
    textTheme: const TextTheme(
      headlineLarge: TextStyle(
        fontSize: 28,
        fontWeight: FontWeight.w800,
        color: ink,
      ),
      headlineMedium: TextStyle(
        fontSize: 23,
        fontWeight: FontWeight.w800,
        color: ink,
      ),
      titleLarge: TextStyle(
        fontSize: 18,
        fontWeight: FontWeight.w800,
        color: ink,
      ),
      titleMedium: TextStyle(
        fontSize: 15,
        fontWeight: FontWeight.w700,
        color: ink,
      ),
      bodyMedium: TextStyle(fontSize: 14, color: secondary),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: tealDark,
        foregroundColor: Colors.white,
        minimumSize: const Size.fromHeight(48),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        textStyle: const TextStyle(fontWeight: FontWeight.w800),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: Colors.white,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: Color(0xFFCCFBF1)),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
    ),
  );
}

class NaviCard extends StatelessWidget {
  const NaviCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.color = Colors.white,
    this.onTap,
  });
  final Widget child;
  final EdgeInsets padding;
  final Color color;
  final VoidCallback? onTap;
  @override
  Widget build(BuildContext context) => Material(
    color: color,
    borderRadius: BorderRadius.circular(20),
    child: InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        width: double.infinity,
        padding: padding,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: const Color(0xFFCCFBF1)),
        ),
        child: child,
      ),
    ),
  );
}

class SectionLabel extends StatelessWidget {
  const SectionLabel(this.label, {super.key});
  final String label;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(left: 3, bottom: 8),
    child: Text(
      label.toUpperCase(),
      style: const TextStyle(
        fontSize: 11,
        letterSpacing: 1.2,
        fontWeight: FontWeight.w800,
        color: Navi.muted,
      ),
    ),
  );
}

class DemoTag extends StatelessWidget {
  const DemoTag({super.key});
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
    decoration: BoxDecoration(
      color: const Color(0xFFE7F5F3),
      borderRadius: BorderRadius.circular(99),
    ),
    child: const Text(
      'SIMULATED',
      style: TextStyle(
        fontSize: 9,
        letterSpacing: 0.5,
        fontWeight: FontWeight.w800,
        color: Navi.tealDark,
      ),
    ),
  );
}

class PlaceholderRouteMap extends StatelessWidget {
  const PlaceholderRouteMap({super.key, this.alternative = false});
  final bool alternative;
  @override
  Widget build(BuildContext context) => Container(
    height: 130,
    width: double.infinity,
    decoration: BoxDecoration(
      borderRadius: BorderRadius.circular(18),
      color: const Color(0xFFE8F4F0),
      border: Border.all(color: const Color(0xFFB8DDD4)),
    ),
    child: Stack(
      children: [
        Positioned.fill(
          child: CustomPaint(painter: _RoutePainter(alternative)),
        ),
        Positioned(
          left: 12,
          top: 10,
          child: Row(
            children: [
              const Icon(Icons.map_outlined, size: 16, color: Navi.tealDark),
              const SizedBox(width: 4),
              Text(
                alternative ? 'Original + alternative' : 'Journey route',
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: Navi.tealDark,
                ),
              ),
            ],
          ),
        ),
        const Positioned(
          right: 10,
          bottom: 8,
          child: Text(
            'Map preview · simulated',
            style: TextStyle(fontSize: 9, color: Navi.muted),
          ),
        ),
      ],
    ),
  );
}

class _RoutePainter extends CustomPainter {
  _RoutePainter(this.alternative);
  final bool alternative;
  @override
  void paint(Canvas c, Size s) {
    final grid = Paint()
      ..color = const Color(0xFFD2E5E0)
      ..strokeWidth = 1;
    for (var x = 22.0; x < s.width; x += 38) {
      c.drawLine(Offset(x, 0), Offset(x + 45, s.height), grid);
    }
    for (var y = 20.0; y < s.height; y += 35) {
      c.drawLine(Offset(0, y), Offset(s.width, y - 14), grid);
    }
    final path = Path()
      ..moveTo(s.width * .14, s.height * .78)
      ..cubicTo(
        s.width * .28,
        s.height * .78,
        s.width * .26,
        s.height * .3,
        s.width * .48,
        s.height * .54,
      )
      ..cubicTo(
        s.width * .62,
        s.height * .72,
        s.width * .67,
        s.height * .25,
        s.width * .84,
        s.height * .24,
      );
    c.drawPath(
      path,
      Paint()
        ..color = Navi.teal
        ..strokeWidth = 5
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round,
    );
    if (alternative) {
      final alt = Path()
        ..moveTo(s.width * .14, s.height * .78)
        ..cubicTo(
          s.width * .34,
          s.height * .5,
          s.width * .53,
          s.height * .85,
          s.width * .84,
          s.height * .24,
        );
      c.drawPath(
        alt,
        Paint()
          ..color = Navi.amber
          ..strokeWidth = 4
          ..style = PaintingStyle.stroke
          ..strokeCap = StrokeCap.round,
      );
    }
    for (final p in [
      Offset(s.width * .14, s.height * .78),
      Offset(s.width * .84, s.height * .24),
    ]) {
      c.drawCircle(p, 7, Paint()..color = Colors.white);
      c.drawCircle(p, 5, Paint()..color = Navi.tealDark);
    }
  }

  @override
  bool shouldRepaint(covariant _RoutePainter old) =>
      old.alternative != alternative;
}
