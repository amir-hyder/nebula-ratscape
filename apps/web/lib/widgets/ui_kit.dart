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
