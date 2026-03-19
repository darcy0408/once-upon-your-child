library;

import "package:flutter/material.dart";

class GoogleFontsConfig {
  bool allowRuntimeFetching = true;
}

class GoogleFonts {
  static final GoogleFontsConfig config = GoogleFontsConfig();

  static TextStyle merriweather({
    TextStyle? textStyle,
    Color? color,
    Color? backgroundColor,
    double? fontSize,
    FontWeight? fontWeight,
    FontStyle? fontStyle,
    double? letterSpacing,
    double? wordSpacing,
    TextBaseline? textBaseline,
    double? height,
    Locale? locale,
    Paint? foreground,
    Paint? background,
    List<Shadow>? shadows,
    List<FontFeature>? fontFeatures,
    List<FontVariation>? fontVariations,
    TextDecoration? decoration,
    Color? decorationColor,
    TextDecorationStyle? decorationStyle,
    double? decorationThickness,
    String? debugLabel,
    List<String>? fontFamilyFallback,
    String? package,
    TextOverflow? overflow,
  }) {
    return (textStyle ?? const TextStyle()).copyWith(
      fontFamily: "Merriweather",
      color: color,
      backgroundColor: backgroundColor,
      fontSize: fontSize,
      fontWeight: fontWeight,
      fontStyle: fontStyle,
      letterSpacing: letterSpacing,
      wordSpacing: wordSpacing,
      textBaseline: textBaseline,
      height: height,
      locale: locale,
      foreground: foreground,
      background: background,
      shadows: shadows,
      fontFeatures: fontFeatures,
      fontVariations: fontVariations,
      decoration: decoration,
      decorationColor: decorationColor,
      decorationStyle: decorationStyle,
      decorationThickness: decorationThickness,
      debugLabel: debugLabel,
      fontFamilyFallback: fontFamilyFallback,
      package: package,
      overflow: overflow,
    );
  }

  static TextStyle quicksand({
    TextStyle? textStyle,
    Color? color,
    Color? backgroundColor,
    double? fontSize,
    FontWeight? fontWeight,
    FontStyle? fontStyle,
    double? letterSpacing,
    double? wordSpacing,
    TextBaseline? textBaseline,
    double? height,
    Locale? locale,
    Paint? foreground,
    Paint? background,
    List<Shadow>? shadows,
    List<FontFeature>? fontFeatures,
    List<FontVariation>? fontVariations,
    TextDecoration? decoration,
    Color? decorationColor,
    TextDecorationStyle? decorationStyle,
    double? decorationThickness,
    String? debugLabel,
    List<String>? fontFamilyFallback,
    String? package,
    TextOverflow? overflow,
  }) {
    return (textStyle ?? const TextStyle()).copyWith(
      fontFamily: "Quicksand",
      color: color,
      backgroundColor: backgroundColor,
      fontSize: fontSize,
      fontWeight: fontWeight,
      fontStyle: fontStyle,
      letterSpacing: letterSpacing,
      wordSpacing: wordSpacing,
      textBaseline: textBaseline,
      height: height,
      locale: locale,
      foreground: foreground,
      background: background,
      shadows: shadows,
      fontFeatures: fontFeatures,
      fontVariations: fontVariations,
      decoration: decoration,
      decorationColor: decorationColor,
      decorationStyle: decorationStyle,
      decorationThickness: decorationThickness,
      debugLabel: debugLabel,
      fontFamilyFallback: fontFamilyFallback,
      package: package,
      overflow: overflow,
    );
  }

  static TextTheme quicksandTextTheme([TextTheme? textTheme]) {
    final base = textTheme ?? Typography.blackMountainView;
    return base.copyWith(
      headlineLarge: quicksand(textStyle: base.headlineLarge),
      headlineMedium: quicksand(textStyle: base.headlineMedium),
      headlineSmall: quicksand(textStyle: base.headlineSmall),
      titleLarge: quicksand(textStyle: base.titleLarge),
      titleMedium: quicksand(textStyle: base.titleMedium),
      titleSmall: quicksand(textStyle: base.titleSmall),
      bodyLarge: quicksand(textStyle: base.bodyLarge),
      bodyMedium: quicksand(textStyle: base.bodyMedium),
      bodySmall: quicksand(textStyle: base.bodySmall),
      labelLarge: quicksand(textStyle: base.labelLarge),
      labelMedium: quicksand(textStyle: base.labelMedium),
      labelSmall: quicksand(textStyle: base.labelSmall),
      displayLarge: quicksand(textStyle: base.displayLarge),
      displayMedium: quicksand(textStyle: base.displayMedium),
      displaySmall: quicksand(textStyle: base.displaySmall),
    );
  }
}
