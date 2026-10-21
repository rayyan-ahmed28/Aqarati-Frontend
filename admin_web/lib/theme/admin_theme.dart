import 'package:flutter/material.dart';

/// AQARATI brand tokens for the staff console. Values mirror the customer app's AQ tokens
/// (`lib/core/aq/aq_tokens.dart` in the customer app): mocha #825C3F, ivory, ink #2D2823, warm dark.
/// Kept as a copy so admin code never ships inside the customer binary.
@immutable
class AdminColors {
  final Brightness brightness;
  final Color background, surface, surfaceRaised, surfaceSelected, sidebar;
  final Color ink, inkSoft, inkFaint, hairline;
  final Color accent, accentDeep, onAccent;
  final Color danger, success, warning;
  const AdminColors._({
    required this.brightness,
    required this.background,
    required this.surface,
    required this.surfaceRaised,
    required this.surfaceSelected,
    required this.sidebar,
    required this.ink,
    required this.inkSoft,
    required this.inkFaint,
    required this.hairline,
    required this.accent,
    required this.accentDeep,
    required this.onAccent,
    required this.danger,
    required this.success,
    required this.warning,
  });

  static const light = AdminColors._(
    brightness: Brightness.light,
    background: Color(0xFFF3EBE1),
    surface: Color(0xFFFBF7F1),
    surfaceRaised: Color(0xFFFFFCF8),
    surfaceSelected: Color(0xFFF6EADB),
    sidebar: Color(0xFF2D2823),
    ink: Color(0xFF2D2823),
    inkSoft: Color(0xFF655C52),
    inkFaint: Color(0xFF766B60),
    hairline: Color(0x33655C52),
    accent: Color(0xFF825C3F),
    accentDeep: Color(0xFF674830),
    onAccent: Color(0xFFFFFFFF),
    danger: Color(0xFFA2402E),
    success: Color(0xFF4C6B38),
    warning: Color(0xFF8A5A1F),
  );

  static const dark = AdminColors._(
    brightness: Brightness.dark,
    background: Color(0xFF1A1613),
    surface: Color(0xFF221C17),
    surfaceRaised: Color(0xFF2A231D),
    surfaceSelected: Color(0xFF3A2E24),
    sidebar: Color(0xFF14110E),
    ink: Color(0xFFF1E8DB),
    inkSoft: Color(0xFFC3B6A5),
    inkFaint: Color(0xFF93877A),
    hairline: Color(0x33F1E8DB),
    accent: Color(0xFFB98A64),
    accentDeep: Color(0xFFD1A47F),
    onAccent: Color(0xFF1A1613),
    danger: Color(0xFFE08A78),
    success: Color(0xFF9DB98A),
    warning: Color(0xFFD9A86A),
  );

  static AdminColors of(BuildContext c) => Theme.of(c).brightness == Brightness.dark ? dark : light;
}

class AdminSpace {
  AdminSpace._();
  static const double x1 = 4, x2 = 8, x3 = 12, x4 = 16, x5 = 20, x6 = 24, x8 = 32;
  static const double radius = 14;
  static const double radiusSmall = 8;
}

/// Motion tokens shared in spirit with the customer app (short, calm, reduced-motion aware).
class AdminMotion {
  AdminMotion._();
  static const fast = Duration(milliseconds: 160);
  static const standard = Duration(milliseconds: 240);
  static bool reduced(BuildContext c) => MediaQuery.maybeDisableAnimationsOf(c) ?? false;
  static Duration of(BuildContext c, Duration d) => reduced(c) ? Duration.zero : d;
}

TextStyle adminDisplay(BuildContext c, {double size = 28, Color? color}) => TextStyle(fontFamily: 'Fraunces', fontFamilyFallback: const ['IBMPlexSansArabic'], fontSize: size, height: 1.2, fontWeight: FontWeight.w500, letterSpacing: -0.3, color: color ?? AdminColors.of(c).ink);

TextStyle adminText(BuildContext c, {double size = 14, FontWeight weight = FontWeight.w400, Color? color, bool soft = false}) => TextStyle(
      fontFamily: 'PlusJakartaSans',
      fontFamilyFallback: const ['IBMPlexSansArabic'],
      fontSize: size,
      height: 1.45,
      fontWeight: weight,
      color: color ?? (soft ? AdminColors.of(c).inkSoft : AdminColors.of(c).ink),
    );

ThemeData adminTheme(Brightness b) {
  final c = b == Brightness.dark ? AdminColors.dark : AdminColors.light;
  return ThemeData(
    useMaterial3: true,
    brightness: b,
    scaffoldBackgroundColor: c.background,
    fontFamily: 'PlusJakartaSans',
    colorScheme: ColorScheme.fromSeed(seedColor: c.accent, brightness: b, primary: c.accent, surface: c.surface, error: c.danger),
    pageTransitionsTheme: const PageTransitionsTheme(builders: {TargetPlatform.windows: FadeForwardsPageTransitionsBuilder(), TargetPlatform.macOS: FadeForwardsPageTransitionsBuilder(), TargetPlatform.linux: FadeForwardsPageTransitionsBuilder()}),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: c.surfaceRaised,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(AdminSpace.radiusSmall), borderSide: BorderSide(color: c.hairline)),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(AdminSpace.radiusSmall), borderSide: BorderSide(color: c.hairline)),
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(AdminSpace.radiusSmall), borderSide: BorderSide(color: c.accent, width: 1.5)),
    ),
    filledButtonTheme: FilledButtonThemeData(style: FilledButton.styleFrom(backgroundColor: c.accent, foregroundColor: c.onAccent, minimumSize: const Size(48, 44), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AdminSpace.radiusSmall)))),
    outlinedButtonTheme: OutlinedButtonThemeData(style: OutlinedButton.styleFrom(foregroundColor: c.ink, minimumSize: const Size(48, 44), side: BorderSide(color: c.hairline), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AdminSpace.radiusSmall)))),
    dividerTheme: DividerThemeData(color: c.hairline, space: 1),
    snackBarTheme: SnackBarThemeData(behavior: SnackBarBehavior.floating, backgroundColor: c.ink, contentTextStyle: TextStyle(color: c.background)),
  );
}
