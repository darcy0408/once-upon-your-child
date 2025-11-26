import 'package:flutter/material.dart';

class AppColors {
  static const primary = Color(0xFF1B5E20); // darker for contrast
  static const secondary = Color(0xFF2E7D32);
  static const accent = Color(0xFF0D47A1); // high-contrast accent
  static const surface = Color(0xFFF5F9F5);
  static const error = Color(0xFFD32F2F);
  static const warning = Color(0xFFFFA000);
}

class AppSpacing {
  static const xs = 8.0;
  static const sm = 12.0;
  static const md = 16.0;
  static const lg = 24.0;
  static const xl = 32.0;
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
        onPrimary: Colors.white,
        onSecondary: Colors.white,
        surface: surface,
        error: error,
        brightness: Brightness.light,
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
          overlayColor: effectiveAccent.withOpacity(0.14),
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
          overlayColor: AppColors.accent.withOpacity(0.14),
          textStyle: const TextStyle(fontWeight: FontWeight.w600),
        ),
      ),
      focusColor: AppColors.accent.withOpacity(0.22),
      hoverColor: AppColors.accent.withOpacity(0.08),
      highlightColor: AppColors.accent.withOpacity(0.12),
      chipTheme: base.chipTheme.copyWith(
        backgroundColor: Colors.grey.shade100,
        selectedColor: effectiveAccent.withOpacity(0.16),
        labelStyle: const TextStyle(
          color: Colors.black87,
          fontWeight: FontWeight.w600,
        ),
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.sm,
          vertical: AppSpacing.xs,
        ),
        side: BorderSide(color: effectivePrimary.withOpacity(0.2)),
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
    return base.copyWith(
      headlineLarge: const TextStyle(
        fontSize: 32,
        fontWeight: FontWeight.bold,
        color: Colors.black87,
      ),
      headlineMedium: const TextStyle(
        fontSize: 28,
        fontWeight: FontWeight.w600,
        color: Colors.black87,
      ),
      titleLarge: const TextStyle(
        fontSize: 22,
        fontWeight: FontWeight.w600,
        color: Colors.black87,
      ),
      titleMedium: const TextStyle(
        fontSize: 18,
        fontWeight: FontWeight.w600,
        color: Colors.black87,
      ),
      bodyLarge: const TextStyle(
        fontSize: 16,
        height: 1.5,
        color: Colors.black87,
      ),
      bodyMedium: const TextStyle(
        fontSize: 14,
        color: Colors.black87,
      ),
      labelLarge: const TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w600,
      ),
    );
  }
}
