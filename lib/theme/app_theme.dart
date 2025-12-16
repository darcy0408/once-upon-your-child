import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppColors {
  // 🎨 Magical Purple Theme - Emotion First Design
  // Primary purple for CTAs and magical elements
  static const primary = Color(0xFF6A1B9A); // High-saturation purple
  static const primaryLight = Color(0xFF9C4DCC); // Lighter purple for hover
  static const primaryDark = Color(0xFF4A148C); // Darker purple for depth

  // Gradient background colors (lavender to teal)
  static const gradientStart = Color(0xFFE1BEE7); // Soft lavender
  static const gradientMid = Color(0xFFCE93D8); // Medium lavender
  static const gradientEnd = Color(0xFF80CBC4); // Soft teal

  // Accent colors
  static const gold = Color(0xFFFFD54F); // Gold for selections/highlights
  static const goldLight = Color(0xFFFFE082); // Light gold for glows
  static const cream = Color(0xFFFFF8E1); // Cream for pill buttons

  // Semantic colors
  static const surface = Color(0xFFFAFAFA); // Clean white surface
  static const error = Color(0xFFD32F2F);
  static const warning = Color(0xFFFFA000);
  static const success = Color(0xFF388E3C);

  // Text colors (ensuring 4.5:1 contrast)
  static const textDark = Color(0xFF333333); // Dark gray for light backgrounds
  static const textLight = Color(0xFFFFFFFF); // White for dark backgrounds
  static const textDisabled = Color(0xFFCCCCCC); // Light gray for disabled

  // Companion/Character colors
  static const dragonOrange = Color(0xFFFF6F00); // Fire dragon
  static const owlBlue = Color(0xFF1A237E); // Night owl
  static const catPurple = Color(0xFF6A1B9A); // Purple cat
  static const dogBrown = Color(0xFF5D4037); // Brown dog

  // Legacy colors (for gradual migration)
  static const secondary = primary;
  static const secondaryLight = primaryLight; // Alias for backward compatibility
  static const purple = primary; // Alias for explicit usage
  static const accent = gold;
}

class AppSpacing {
  static const xs = 8.0; // Minimum spacing between elements
  static const sm = 12.0;
  static const md = 16.0;
  static const lg = 24.0;
  static const xl = 32.0;
  static const xxl = 48.0;
}

// Accessibility touch target sizes
class AppTouchTargets {
  static const minSize = 64.0; // WCAG AAA minimum (64x64px)
  static const comfortable = 72.0; // More comfortable for kids
  static const large = 88.0; // Extra large for primary actions
}

// Border radius for consistent rounding
class AppRadius {
  static const sm = 8.0;
  static const md = 16.0;
  static const lg = 24.0;
  static const xl = 32.0; // Added missing xl radius
  static const pill = 1000.0; // Full pill shape
}

// Gradients
class AppGradients {
  // Main magical background gradient (vertical)
  static const magicalBackground = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [
      AppColors.gradientStart, // Lavender
      AppColors.gradientMid, // Medium lavender
      AppColors.gradientEnd, // Teal
    ],
    stops: [0.0, 0.5, 1.0],
  );

  // Gold shimmer for selected items
  static const goldShimmer = LinearGradient(
    colors: [
      AppColors.gold,
      AppColors.goldLight,
      AppColors.gold,
    ],
    stops: [0.0, 0.5, 1.0],
  );

  // Purple glow for CTAs
  static const purpleGlow = LinearGradient(
    colors: [
      AppColors.primaryLight,
      AppColors.primary,
      AppColors.primaryDark,
    ],
    stops: [0.0, 0.5, 1.0],
  );
}

class AppTheme {
  static ThemeData light({Color? primaryColor, Color? accentColor}) {
    final effectivePrimary = primaryColor ?? AppColors.primary;
    final effectiveAccent = accentColor ?? AppColors.accent;
    final surface = AppColors.surface;
    final error = AppColors.error;

    final base = ThemeData.light();
    return base.copyWith(
      scaffoldBackgroundColor: Colors.white,
      colorScheme: ColorScheme.fromSeed(
        seedColor: effectiveAccent,
        primary: effectivePrimary,
        secondary: effectiveAccent,
        surface: surface,
        error: error,
      ),
      textTheme: _textTheme(base.textTheme),
      cardTheme: const CardThemeData(
        color: Colors.white,
        elevation: 4,
        margin: EdgeInsets.all(16),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(20)),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: effectivePrimary,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.lg,
            vertical: AppSpacing.sm,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          textStyle: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: AppColors.primary,
          textStyle: const TextStyle(fontWeight: FontWeight.w600),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.sm,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: Colors.grey.shade300),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: effectivePrimary, width: 2),
        ),
      ),
      appBarTheme: AppBarTheme(
        elevation: 0,
        backgroundColor: Colors.white,
        foregroundColor: effectivePrimary,
        titleTextStyle: TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.bold,
          color: effectivePrimary,
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: effectivePrimary,
        contentTextStyle: const TextStyle(color: Colors.white),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: effectivePrimary,
      ),
    );
  }

  static TextTheme _textTheme(TextTheme base) {
    // Using Quicksand font for rounded, soft, kid-friendly typography
    // All fonts use weight 500+ for clarity
    // Google Fonts package handles font loading automatically
    return GoogleFonts.quicksandTextTheme(base).copyWith(
      // Headings - 24pt+ for important titles
      headlineLarge: GoogleFonts.quicksand(
        fontSize: 32,
        fontWeight: FontWeight.bold, // 700
        color: AppColors.textDark,
        height: 1.2,
      ),
      headlineMedium: GoogleFonts.quicksand(
        fontSize: 28,
        fontWeight: FontWeight.w600,
        color: AppColors.textDark,
        height: 1.2,
      ),
      // Titles - 18-24pt for section headers
      titleLarge: GoogleFonts.quicksand(
        fontSize: 24,
        fontWeight: FontWeight.w600,
        color: AppColors.textDark,
        height: 1.3,
      ),
      titleMedium: GoogleFonts.quicksand(
        fontSize: 20,
        fontWeight: FontWeight.w600,
        color: AppColors.textDark,
        height: 1.3,
      ),
      // Body text - 18pt for readability (if text is needed)
      bodyLarge: GoogleFonts.quicksand(
        fontSize: 18,
        fontWeight: FontWeight.w500,
        height: 1.5,
        color: AppColors.textDark,
      ),
      bodyMedium: GoogleFonts.quicksand(
        fontSize: 16,
        fontWeight: FontWeight.w500,
        color: AppColors.textDark,
        height: 1.5,
      ),
      // Labels for buttons
      labelLarge: GoogleFonts.quicksand(
        fontSize: 18,
        fontWeight: FontWeight.w600,
        color: AppColors.textDark,
      ),
      labelMedium: GoogleFonts.quicksand(
        fontSize: 16,
        fontWeight: FontWeight.w600,
        color: AppColors.textDark,
      ),
    );
  }
}
