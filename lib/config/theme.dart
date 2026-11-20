import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppColors {
  // Primary Medical Green Palette (Derived from Figma "Jai Medical History")
  static const primary = Color(0xFF4FA023);
  static const primaryLight = Color(0xFF74C43B);
  static const primaryDark = Color(0xFF388E18);
  static const accent = Color(0xFFB9EB80);

  // Ambient Aurora Glows (From Starting Screen)
  static const glowLime = Color(0xFFC5F2A0);
  static const glowLeaf = Color(0xFF88D84C);
  static const glowMint = Color(0xFFB9EB80);

  // Same greens as the splash screen, used on headers and cards.
  static const heroGradient = LinearGradient(
    colors: [primaryDark, primary, primaryLight],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const heroSubtleGradient = LinearGradient(
    colors: [Color(0xFFEBF7E4), Color(0xFFF6F9F2)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  // Backgrounds — Clean, modern, warm-mint medical palette from Figma
  static const bg = Color(0xFFF6F9F2);
  static const card = Color(0xFFFFFFFF);
  static const surface = Color(0xFFEBF7E4);
  static const chipBg = Color(0xFFD8EEB8);
  static const chipText = Color(0xFF2C6B14);

  // Full-screen gradient from the starting screen.
  static const pageGradient = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [primaryDark, primary, primaryLight],
  );

  // Glass colors & specular borders
  static const glassBorder = Color(0x66FFFFFF);
  static const glassBorderDark = Color(0x22FFFFFF);

  // Text — Exact Figma Typography Tones
  static const textDark = Color(0xFF173722);
  static const textMid = Color(0xFF4A6652);
  static const textLight = Color(0xFF7A8E7B);
  static const textPrimary = Color(0xFF173722);
  static const textSecondary = Color(0xFF7A8E7B);

  // Status
  static const success = Color(0xFF4FA023);
  static const warning = Color(0xFFFFA000);
  static const error = Color(0xFFE53935);
  static const info = Color(0xFF1E88E5);

  // Borders & Shadows
  static const divider = Color(0xFFE5EDE4);
  static const border = Color(0xFFDFEAE0);
  static const shadow = Color(0x0C173722);
}

extension AppThemeContext on BuildContext {
  bool get isDarkMode => Theme.of(this).brightness == Brightness.dark;
  Color get appBackground => Theme.of(this).scaffoldBackgroundColor;
  Color get appSurface => Theme.of(this).colorScheme.surface;
  Color get appSurfaceRaised => Theme.of(this).colorScheme.surfaceContainer;
  Color get appSurfaceSoft => Theme.of(this).colorScheme.surfaceContainerLow;
  Color get appTextPrimary => Theme.of(this).colorScheme.onSurface;
  Color get appTextSecondary => Theme.of(this).colorScheme.onSurfaceVariant;
  Color get appBorder => Theme.of(this).colorScheme.outlineVariant;
}

class AppTheme {
  static ThemeData get light {
    final base = ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      colorSchemeSeed: AppColors.primary,
    );
    return base.copyWith(
      scaffoldBackgroundColor: AppColors.bg,
      textTheme: GoogleFonts.plusJakartaSansTextTheme(
        base.textTheme,
      ).apply(bodyColor: AppColors.textDark, displayColor: AppColors.textDark),
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
            textStyle: base.textTheme.labelLarge,
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
            textStyle: base.textTheme.labelLarge,
            fontSize: 15,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 18,
          vertical: 16,
        ),
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

  static ThemeData get dark {
    const colorScheme = ColorScheme.dark(
      primary: Color(0xFF2EB872),
      onPrimary: Color(0xFF042F1A),
      primaryContainer: Color(0xFF104E31),
      onPrimaryContainer: Color(0xFFB4F3D2),
      secondary: Color(0xFF38B26C),
      onSecondary: Color(0xFF052F1A),
      surface: Color(0xFF17231B),
      onSurface: Color(0xFFE8F3EA),
      surfaceContainerLowest: Color(0xFF0D1510),
      surfaceContainerLow: Color(0xFF131E17),
      surfaceContainer: Color(0xFF1B2A20),
      surfaceContainerHigh: Color(0xFF223429),
      surfaceContainerHighest: Color(0xFF2A4030),
      onSurfaceVariant: Color(0xFFADC0B0),
      outline: Color(0xFF5D7562),
      outlineVariant: Color(0xFF304737),
      error: Color(0xFFFFB4AB),
      onError: Color(0xFF690005),
    );
    final base = ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: colorScheme,
    );
    return base.copyWith(
      scaffoldBackgroundColor: const Color(0xFF101A13),
      canvasColor: const Color(0xFF101A13),
      dividerColor: colorScheme.outlineVariant,
      textTheme: GoogleFonts.plusJakartaSansTextTheme(base.textTheme).apply(
        bodyColor: colorScheme.onSurface,
        displayColor: colorScheme.onSurface,
      ),
      iconTheme: const IconThemeData(color: Color(0xFFCAD9CC)),
      appBarTheme: AppBarTheme(
        elevation: 0,
        backgroundColor: const Color(0xFF101A13),
        foregroundColor: Colors.white,
        titleTextStyle: GoogleFonts.plusJakartaSans(
          fontSize: 20,
          fontWeight: FontWeight.w700,
          color: Colors.white,
        ),
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        color: colorScheme.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(color: colorScheme.outlineVariant, width: 1.2),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: colorScheme.surfaceContainer,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: Color(0xFF17231B),
        modalBackgroundColor: Color(0xFF17231B),
        surfaceTintColor: Colors.transparent,
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: colorScheme.surface,
        indicatorColor: colorScheme.primaryContainer,
        labelTextStyle: WidgetStatePropertyAll(
          GoogleFonts.plusJakartaSans(
            textStyle: base.textTheme.labelMedium,
            color: colorScheme.onSurfaceVariant,
          ),
        ),
      ),
      listTileTheme: ListTileThemeData(
        textColor: colorScheme.onSurface,
        iconColor: colorScheme.onSurfaceVariant,
        tileColor: colorScheme.surface,
      ),
      dividerTheme: DividerThemeData(color: colorScheme.outlineVariant),
      chipTheme: base.chipTheme.copyWith(
        backgroundColor: colorScheme.surfaceContainerHigh,
        selectedColor: colorScheme.primaryContainer,
        side: BorderSide(color: colorScheme.outlineVariant),
        labelStyle: base.textTheme.labelLarge?.copyWith(
          color: colorScheme.onSurface,
        ),
      ),
      tabBarTheme: TabBarThemeData(
        labelColor: colorScheme.primary,
        unselectedLabelColor: colorScheme.onSurfaceVariant,
        dividerColor: Colors.transparent,
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: colorScheme.primary,
          foregroundColor: colorScheme.onPrimary,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          textStyle: GoogleFonts.plusJakartaSans(
            textStyle: base.textTheme.labelLarge,
            fontSize: 15,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: colorScheme.primary,
          foregroundColor: colorScheme.onPrimary,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          textStyle: GoogleFonts.plusJakartaSans(
            textStyle: base.textTheme.labelLarge,
            fontSize: 15,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: colorScheme.primary,
          side: BorderSide(color: colorScheme.primary, width: 1.5),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 15),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          textStyle: GoogleFonts.plusJakartaSans(
            textStyle: base.textTheme.labelLarge,
            fontSize: 15,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: colorScheme.surfaceContainer,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 18,
          vertical: 16,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: colorScheme.outlineVariant),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: colorScheme.outlineVariant),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(
            color: AppColors.primaryLight,
            width: 1.8,
          ),
        ),
        hintStyle: TextStyle(color: colorScheme.onSurfaceVariant),
        labelStyle: TextStyle(color: colorScheme.onSurfaceVariant),
      ),
    );
  }
}
