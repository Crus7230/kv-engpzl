import 'package:flutter/material.dart';

abstract final class AppColors {
  static const Color ink = Color(0xFF17233D);
  static const Color mutedInk = Color(0xFF5D6981);
  static const Color canvasTop = Color(0xFFF5F1FF);
  static const Color canvasBottom = Color(0xFFEAF7FF);
  static const Color surface = Color(0xFFFFFFFF);
  static const Color primary = Color(0xFF6547D9);
  static const Color primaryDark = Color(0xFF4931A9);
  static const Color accent = Color(0xFFFFB54A);
  static const Color number = Color(0xFF2F73D9);
  static const Color operator = Color(0xFFE56A42);
  static const Color parenthesis = Color(0xFF3D9B82);
  static const Color success = Color(0xFF21845E);
  static const Color error = Color(0xFFC94343);
  static const Color outline = Color(0xFFD9DDEC);
}

abstract final class AppTheme {
  static ThemeData light() {
    final colorScheme =
        ColorScheme.fromSeed(
          seedColor: AppColors.primary,
          brightness: Brightness.light,
          surface: AppColors.surface,
        ).copyWith(
          primary: AppColors.primary,
          onPrimary: Colors.white,
          secondary: AppColors.accent,
          onSurface: AppColors.ink,
          error: AppColors.error,
          outline: AppColors.outline,
        );

    return ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: AppColors.canvasBottom,
      fontFamilyFallback: const ['Noto Sans KR', 'Malgun Gothic', 'sans-serif'],
      textTheme: const TextTheme(
        headlineSmall: TextStyle(
          color: AppColors.ink,
          fontSize: 24,
          fontWeight: FontWeight.w700,
        ),
        titleLarge: TextStyle(
          color: AppColors.ink,
          fontSize: 21,
          fontWeight: FontWeight.w700,
        ),
        titleMedium: TextStyle(
          color: AppColors.ink,
          fontSize: 17,
          fontWeight: FontWeight.w700,
        ),
        bodyLarge: TextStyle(color: AppColors.ink, fontSize: 17, height: 1.55),
        bodyMedium: TextStyle(
          color: AppColors.mutedInk,
          fontSize: 15,
          height: 1.45,
        ),
        labelLarge: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
      ),
      cardTheme: const CardThemeData(
        color: AppColors.surface,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(24)),
          side: BorderSide(color: AppColors.outline),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size(56, 52),
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(52, 48),
          foregroundColor: AppColors.ink,
          side: const BorderSide(color: AppColors.outline),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
      ),
      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(
          minimumSize: const Size(48, 48),
          foregroundColor: AppColors.ink,
        ),
      ),
    );
  }
}
