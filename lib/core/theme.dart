import 'package:flutter/material.dart';

/// Dark theme with amber as the single accent colour.
class AppColors {
  static const amber = Color(0xFFFFC107);
  static const amberSoft = Color(0xFFFFD54F);
  static const background = Color(0xFF0B0B0D);
  static const surface = Color(0xFF16161A);
  static const surfaceHigh = Color(0xFF202026);
  static const textMuted = Color(0xFF9A9AA3);
  static const success = Color(0xFF7BD88F);
  static const danger = Color(0xFFFF6B6B);
}

ThemeData buildDarkAmberTheme() {
  final scheme = ColorScheme.fromSeed(
    seedColor: AppColors.amber,
    brightness: Brightness.dark,
  ).copyWith(
    primary: AppColors.amber,
    onPrimary: Colors.black,
    secondary: AppColors.amberSoft,
    onSecondary: Colors.black,
    surface: AppColors.surface,
    onSurface: Colors.white,
    error: AppColors.danger,
  );

  return ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    colorScheme: scheme,
    scaffoldBackgroundColor: AppColors.background,
    appBarTheme: const AppBarTheme(
      backgroundColor: AppColors.background,
      foregroundColor: Colors.white,
      elevation: 0,
      centerTitle: false,
      titleTextStyle: TextStyle(
        fontSize: 20,
        fontWeight: FontWeight.w700,
        color: Colors.white,
        letterSpacing: 0.2,
      ),
    ),
    cardTheme: CardThemeData(
      color: AppColors.surface,
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: BorderSide(color: AppColors.amber.withValues(alpha: 0.14)),
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: AppColors.amber,
        foregroundColor: Colors.black,
        minimumSize: const Size.fromHeight(52),
        textStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: AppColors.amber,
        side: const BorderSide(color: AppColors.amber),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    ),
    switchTheme: SwitchThemeData(
      thumbColor: WidgetStateProperty.resolveWith(
        (s) => s.contains(WidgetState.selected) ? Colors.black : null,
      ),
      trackColor: WidgetStateProperty.resolveWith(
        (s) => s.contains(WidgetState.selected) ? AppColors.amber : null,
      ),
    ),
    sliderTheme: SliderThemeData(
      activeTrackColor: AppColors.amber,
      thumbColor: AppColors.amber,
      inactiveTrackColor: AppColors.amber.withValues(alpha: 0.2),
    ),
    progressIndicatorTheme:
        const ProgressIndicatorThemeData(color: AppColors.amber),
    dividerColor: Colors.white10,
    textTheme: const TextTheme(
      bodyMedium: TextStyle(color: Colors.white),
      bodySmall: TextStyle(color: AppColors.textMuted),
    ),
  );
}
