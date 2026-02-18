import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppColors {
  static const Color primary = Color(0xFF2455D6);
  static const Color secondary = Color(0xFFF4B400);
  static const Color accent = Color(0xFF26A69A);
  static const Color background = Color(0xFFF4F7FB);
  static const Color surface = Colors.white;
  static const Color textPrimary = Color(0xFF1E2430);
  static const Color textSecondary = Color(0xFF6A7280);
  static const Color success = Color(0xFF37B24D);
  static const Color error = Color(0xFFE03131);
}

class AppTheme {
  static ThemeData get lightTheme {
    final textTheme = GoogleFonts.notoSansKrTextTheme().apply(
      bodyColor: AppColors.textPrimary,
      displayColor: AppColors.textPrimary,
    );
    return ThemeData(
      useMaterial3: true,
      scaffoldBackgroundColor: AppColors.background,
      colorScheme: ColorScheme.fromSeed(
        seedColor: AppColors.primary,
        primary: AppColors.primary,
        secondary: AppColors.secondary,
      ),
      fontFamily: GoogleFonts.notoSansKr().fontFamily,
      textTheme: textTheme,
      primaryTextTheme: textTheme,
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
      ),
      cardTheme: CardThemeData(
        color: AppColors.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
    );
  }
}
