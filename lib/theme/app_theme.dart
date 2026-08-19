import 'package:flutter/material.dart';

class AppTheme {
  static ThemeData _base(Color seed, Brightness b) {
    final cs = ColorScheme.fromSeed(seedColor: seed, brightness: b);
    return ThemeData(
      useMaterial3: true,
      colorScheme: cs,
      visualDensity: VisualDensity.standard,
      inputDecorationTheme: const InputDecorationTheme(
        border: OutlineInputBorder(),
      ),
    );
  }

  static ThemeData lightTheme = _base(const Color(0xFF6750A4), Brightness.light);
  static ThemeData darkTheme  = _base(const Color(0xFF6750A4), Brightness.dark);
}
