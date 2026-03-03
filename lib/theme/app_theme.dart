import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'age_band_theme.dart';

class AppColors {
  // 🎨 Magical Purple Theme - Emotion First Design
  // Primary purple for CTAs and magical elements
  static const primary = Color(0xFF6A1B9A); // High-saturation purple
  static const primaryLight = Color(0xFF9C4DCC); // Lighter purple for hover
  static const primaryDark = Color(0xFF4A148C); // Darker purple for depth

  // Gradient background colors (deep purple — darker, more magical)
  static const gradientStart = Color(0xFF120226); // Deep midnight purple
  static const gradientMid = Color(0xFF2A0A4E); // Dark purple
  static const gradientEnd = Color(0xFF1A1040); // Deep indigo

  // Accent colors
  static const gold = Color(0xFFFFD54F); // Gold for selections/highlights
  static const goldLight = Color(0xFFFFE082); // Light gold for glows
  static const cream = Color(0xFFFFF8E1); // Cream for pill buttons

  // Semantic colors
  static const surface = Color(0xFFB2DFDB); // Light teal surface (contrasts with lavender background)
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

/// Text styles specifically for storybook content
/// Uses Merriweather serif font for enhanced readability and magical aesthetic
class AppTextStyles {
  // Story title style - bold, large serif for chapter/story titles
  static TextStyle storyTitle = GoogleFonts.merriweather(
    fontSize: 28,
    fontWeight: FontWeight.bold,
    color: const Color(0xFF2C3E50),
    height: 1.3,
  );

  // Story body text - comfortable reading size with generous line spacing
  static TextStyle storyBody = GoogleFonts.merriweather(
    fontSize: 20,
    fontWeight: FontWeight.normal,
    color: const Color(0xFF2C3E50),
    height: 1.8, // Generous line spacing for readability
    letterSpacing: 0.3,
  );

  // Large story body - for better readability or user preference
  static TextStyle storyBodyLarge = GoogleFonts.merriweather(
    fontSize: 22,
    fontWeight: FontWeight.normal,
    color: const Color(0xFF2C3E50),
    height: 1.8,
    letterSpacing: 0.3,
  );

  // Drop cap style - decorative first letter (optional)
  static TextStyle dropCap = GoogleFonts.merriweather(
    fontSize: 56,
    fontWeight: FontWeight.bold,
    color: AppColors.primary,
    height: 0.9,
  );

  // Story metadata - author, date, etc.
  static TextStyle storyMeta = GoogleFonts.merriweather(
    fontSize: 16,
    fontWeight: FontWeight.w500,
    color: const Color(0xFF6B7280),
    fontStyle: FontStyle.italic,
  );
}

class AppTheme {
  /// Build the light theme, optionally adapted for an age band.
  ///
  /// When [ageBand] is provided, colors, fonts, spacing, and radii are
  /// derived from the band data. When omitted, the Explorer band (current
  /// default look) is used, preserving full backward compatibility.
  static ThemeData light({
    Color? primaryColor,
    Color? accentColor,
    AgeBandThemeData? ageBand,
  }) {
    final band = ageBand ?? explorerTheme;
    final effectivePrimary = primaryColor ?? band.primary;
    final effectiveAccent = accentColor ?? band.accent;
    final surface = band.surface;
    final error = AppColors.error;

    final base = ThemeData.light();
    return base.copyWith(
      scaffoldBackgroundColor: band.gradientStart,
      colorScheme: ColorScheme.fromSeed(
        seedColor: effectiveAccent,
        primary: effectivePrimary,
        secondary: effectiveAccent,
        surface: surface,
        error: error,
      ),
      textTheme: band.buildUITextTheme(base.textTheme),
      cardTheme: CardThemeData(
        color: surface,
        elevation: 4,
        margin: const EdgeInsets.all(16),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(band.cardRadiusBase)),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: effectivePrimary,
          foregroundColor: Colors.white,
          padding: EdgeInsets.symmetric(
            horizontal: AppSpacing.lg * band.spacingScale,
            vertical: AppSpacing.sm * band.spacingScale,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(band.buttonRadiusBase),
          ),
          minimumSize: Size(0, band.touchTargetMin),
          textStyle: TextStyle(
            fontSize: 16 * band.bodyScale,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: effectivePrimary,
          textStyle: const TextStyle(fontWeight: FontWeight.w600),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: surface,
        contentPadding: EdgeInsets.symmetric(
          horizontal: AppSpacing.md * band.spacingScale,
          vertical: AppSpacing.sm * band.spacingScale,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(band.buttonRadiusBase),
          borderSide: BorderSide(color: effectivePrimary.withAlpha(77)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(band.buttonRadiusBase),
          borderSide: BorderSide(color: effectivePrimary, width: 2),
        ),
      ),
      appBarTheme: AppBarTheme(
        elevation: 0,
        backgroundColor: effectivePrimary,
        foregroundColor: band.textOnDark,
        titleTextStyle: TextStyle(
          fontSize: 20 * band.headingScale,
          fontWeight: FontWeight.bold,
          color: band.textOnDark,
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: effectivePrimary,
        contentTextStyle: TextStyle(color: band.textOnDark),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(band.buttonRadiusBase),
        ),
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: effectivePrimary,
      ),
      extensions: [band],
    );
  }
}
