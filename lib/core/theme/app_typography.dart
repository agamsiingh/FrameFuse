import 'package:flutter/material.dart';

/// FrameFuse typography: bundled Work Sans (see pubspec `fonts:`).
class AppTypography {
  AppTypography._();

  static const String fontFamily = 'WorkSans';

  static const TextTheme textTheme = TextTheme(
    displayLarge: TextStyle(fontSize: 40, fontWeight: FontWeight.w800, height: 1.15),
    displayMedium: TextStyle(fontSize: 32, fontWeight: FontWeight.w800, height: 1.15),
    displaySmall: TextStyle(fontSize: 28, fontWeight: FontWeight.w700, height: 1.2),
    headlineLarge: TextStyle(fontSize: 26, fontWeight: FontWeight.w800, height: 1.2),
    headlineMedium: TextStyle(fontSize: 22, fontWeight: FontWeight.w700, height: 1.25),
    headlineSmall: TextStyle(fontSize: 19, fontWeight: FontWeight.w700),
    titleLarge: TextStyle(fontSize: 17, fontWeight: FontWeight.w600),
    titleMedium: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
    titleSmall: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
    bodyLarge: TextStyle(fontSize: 16, fontWeight: FontWeight.w400),
    bodyMedium: TextStyle(fontSize: 14, fontWeight: FontWeight.w400, letterSpacing: 0.2),
    bodySmall: TextStyle(fontSize: 12, fontWeight: FontWeight.w400, letterSpacing: 0.3),
    labelLarge: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, letterSpacing: 0.3),
    labelMedium: TextStyle(fontSize: 13, fontWeight: FontWeight.w500, letterSpacing: 0.3),
    labelSmall: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, letterSpacing: 0.6),
  );
}
