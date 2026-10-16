import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppColors {
  // Primary Green Palette (Refined from Design Screenshots)
  static const primary = Color(0xFF3FA722);
  static const primaryLight = Color(0xFF6EC632);
  static const primaryDark = Color(0xFF246D16);
  static const accent = Color(0xFF88D84C);

  // Hero Card Gradient
  static const heroGradient = LinearGradient(
    colors: [Color(0xFF3DA31C), Color(0xFF6EC632)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const heroSubtleGradient = LinearGradient(
    colors: [Color(0xFFEBF6E7), Color(0xFFF4FAF1)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  // Backgrounds
  static const bg = Color(0xFFF7FAF6);
  static const card = Color(0xFFFFFFFF);
  static const surface = Color(0xFFEAF5E7);
  static const chipBg = Color(0xFFE2F2D9);
  static const chipText = Color(0xFF235E1E);

  // Text
  static const textDark = Color(0xFF0F3521);
  static const textMid = Color(0xFF4C6656);
  static const textLight = Color(0xFF8B9E92);

  // Status
  static const success = Color(0xFF388E3C);
  static const warning = Color(0xFFFFA000);
  static const error = Color(0xFFE53935);
  static const info = Color(0xFF1E88E5);

  // Borders & Shadows
  static const divider = Color(0xFFE5EDE3);
  static const border = Color(0xFFE8EFE6);
  static const shadow = Color(0x0C0E2818);
}

class AppTheme {
  static ThemeData get light {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      colorSchemeSeed: AppColors.primary,
      scaffoldBackgroundColor: AppColors.bg,
      textTheme: GoogleFonts.plusJakartaSansTextTheme(),
      appBarTheme: AppBarTheme(
        elevation: 0,
        centerTitle: false,
        backgroundColor: AppColors.bg,
        foregroundColor: AppColors.textDark,
        titleTextStyle: GoogleFonts.plusJakartaSans(
          fontSize: 20,
          fontWeight: FontWeight.w700,
          color: AppColors.textDark,
        ),
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        color: AppColors.card,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: const BorderSide(color: AppColors.border, width: 1.2),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 15),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          textStyle: GoogleFonts.plusJakartaSans(
            fontSize: 15,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.primary,
          side: const BorderSide(color: AppColors.primary, width: 1.5),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 15),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          textStyle: GoogleFonts.plusJakartaSans(
            fontSize: 15,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white,
        contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: AppColors.border, width: 1.2),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: AppColors.border, width: 1.2),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: AppColors.primary, width: 1.8),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: AppColors.error),
        ),
        hintStyle: GoogleFonts.plusJakartaSans(
          color: AppColors.textLight,
          fontSize: 14,
        ),
        labelStyle: GoogleFonts.plusJakartaSans(
          color: AppColors.textMid,
          fontSize: 14,
        ),
      ),
    );
  }
}
