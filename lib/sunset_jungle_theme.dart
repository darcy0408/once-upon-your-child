// lib/sunset_jungle_theme.dart
// Sunset Jungle Color Theme for Therapeutic Story App
// Matching the React web app color palette

import 'package:flutter/material.dart';

class SunsetJungleTheme {
  // ===== Primary Greens =====
  static const Color jungleDeepGreen = Color(0xFF2D5016);
  static const Color jungleMoss = Color(0xFF4A7C2C);
  static const Color jungleLeaf = Color(0xFF6B9F4A);
  static const Color jungleSage = Color(0xFF87B668);
  static const Color jungleMint = Color(0xFFA8D5A3);
  static const Color jungleForest = Color(0xFF1B3D0F);
  static const Color jungleOlive = Color(0xFF556B2F);

  // ===== Sunset Accent Colors =====
  static const Color sunsetCoral = Color(0xFFFF7B54);
  static const Color sunsetPeach = Color(0xFFFFB26B);
  static const Color sunsetAmber = Color(0xFFFFA94D);

  // ===== Neutral Colors =====
  static const Color creamLight = Color(0xFFFFF8F0);
  static const Color sandWarm = Color(0xFFF5E6D3);

  // ===== Gradients =====
  static const LinearGradient headerGradient = LinearGradient(
    colors: [jungleMoss, jungleDeepGreen],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient buttonGradient = LinearGradient(
    colors: [sunsetCoral, sunsetAmber],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient mintCreamGradient = LinearGradient(
    colors: [jungleMint, creamLight],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient avatarBackgroundGradient = LinearGradient(
    colors: [creamLight, jungleMint],
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
  );

  // ===== Text Styles =====
  static const TextStyle headerTextStyle = TextStyle(
    fontFamily: 'Quicksand',
    fontSize: 24,
    fontWeight: FontWeight.w600,
    color: creamLight,
  );

  static const TextStyle sectionTitleStyle = TextStyle(
    fontFamily: 'Quicksand',
    fontSize: 18,
    fontWeight: FontWeight.w600,
    color: jungleForest,
  );

  static const TextStyle bodyTextStyle = TextStyle(
    fontFamily: 'Quicksand',
    fontSize: 16,
    fontWeight: FontWeight.w500,
    color: jungleDeepGreen,
  );

  static const TextStyle buttonTextStyle = TextStyle(
    fontFamily: 'Quicksand',
    fontSize: 16,
    fontWeight: FontWeight.w700,
    color: creamLight,
  );

  // ===== Box Decorations =====
  static BoxDecoration cardDecoration = BoxDecoration(
    color: Colors.white,
    borderRadius: BorderRadius.circular(16),
    border: Border.all(color: jungleMint, width: 2),
    boxShadow: [
      BoxShadow(
        color: jungleDeepGreen.withOpacity(0.1),
        blurRadius: 12,
        offset: const Offset(0, 4),
      ),
    ],
  );

  static BoxDecoration avatarCanvasDecoration = BoxDecoration(
    shape: BoxShape.circle,
    border: Border.all(color: jungleSage, width: 4),
    gradient: avatarBackgroundGradient,
    boxShadow: [
      BoxShadow(
        color: jungleDeepGreen.withOpacity(0.15),
        blurRadius: 24,
        offset: const Offset(0, 8),
      ),
    ],
  );

  static BoxDecoration saveSectionDecoration = BoxDecoration(
    borderRadius: BorderRadius.circular(16),
    border: Border.all(color: jungleSage, width: 2),
    gradient: mintCreamGradient,
  );

  // ===== Button Styles =====
  static ButtonStyle primaryButtonStyle = ElevatedButton.styleFrom(
    backgroundColor: sunsetCoral,
    foregroundColor: creamLight,
    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(12),
    ),
    elevation: 4,
    shadowColor: sunsetCoral.withOpacity(0.3),
    textStyle: buttonTextStyle,
  );

  static ButtonStyle outlinedButtonStyle = OutlinedButton.styleFrom(
    foregroundColor: jungleForest,
    side: const BorderSide(color: jungleSage, width: 2),
    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(20),
    ),
    textStyle: const TextStyle(
      fontFamily: 'Quicksand',
      fontSize: 14,
      fontWeight: FontWeight.w600,
    ),
  );

  // ===== Input Decoration =====
  static InputDecoration inputDecoration({
    String? labelText,
    String? hintText,
  }) {
    return InputDecoration(
      labelText: labelText,
      hintText: hintText,
      labelStyle: const TextStyle(
        color: jungleForest,
        fontFamily: 'Quicksand',
        fontWeight: FontWeight.w500,
      ),
      hintStyle: TextStyle(
        color: jungleOlive.withOpacity(0.6),
        fontFamily: 'Quicksand',
      ),
      filled: true,
      fillColor: creamLight,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: jungleSage, width: 2),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: jungleSage, width: 2),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: jungleLeaf, width: 2),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
    );
  }

  // ===== Theme Data =====
  static ThemeData get lightTheme {
    return ThemeData(
      primaryColor: jungleDeepGreen,
      scaffoldBackgroundColor: creamLight,
      colorScheme: const ColorScheme.light(
        primary: jungleDeepGreen,
        secondary: sunsetCoral,
        tertiary: jungleSage,
        surface: Colors.white,
        background: creamLight,
        error: Colors.red,
        onPrimary: creamLight,
        onSecondary: creamLight,
        onSurface: jungleForest,
        onBackground: jungleDeepGreen,
      ),
      fontFamily: 'Quicksand',
      appBarTheme: const AppBarTheme(
        backgroundColor: jungleDeepGreen,
        foregroundColor: creamLight,
        elevation: 4,
        centerTitle: true,
        titleTextStyle: TextStyle(
          fontFamily: 'Quicksand',
          fontSize: 20,
          fontWeight: FontWeight.w700,
          color: creamLight,
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(style: primaryButtonStyle),
      outlinedButtonTheme: OutlinedButtonThemeData(style: outlinedButtonStyle),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: creamLight,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: jungleSage, width: 2),
        ),
      ),
    );
  }
}
