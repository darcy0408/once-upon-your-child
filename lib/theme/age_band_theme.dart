import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// The 4 visual age bands that drive the entire UI personality.
///
/// Each band adapts colors, typography, spacing, animation intensity,
/// and label language to match the developmental stage of the user.
enum AgeBand {
  /// Ages 3-5: Warm, bubbly, illustration-heavy, minimal text
  sprout,

  /// Ages 6-8: Magical purple, sparkles, readable labels (current default)
  explorer,

  /// Ages 9-12: Deeper cosmic palette, book-like typography, "cool" factor
  adventurer,

  /// Ages 13+: Clean, editorial, dark mode default, novel-app aesthetic
  creator,
}

/// Resolves an age (in years) to the appropriate visual band.
AgeBand ageBandFromAge(int age) {
  if (age <= 5) return AgeBand.sprout;
  if (age <= 8) return AgeBand.explorer;
  if (age <= 12) return AgeBand.adventurer;
  return AgeBand.creator;
}

/// All visual parameters that vary per age band.
///
/// Every screen reads from this instead of hard-coded constants, so
/// the entire app adapts automatically when the user's age band changes.
class AgeBandThemeData {
  final AgeBand band;

  // --- Colors ---
  final Color primary;
  final Color primaryLight;
  final Color primaryDark;
  final Color gradientStart;
  final Color gradientMid;
  final Color gradientEnd;
  final Color accent;
  final Color accentLight;
  final Color surface;
  final Color textOnDark;
  final Color textOnLight;

  // --- Typography ---
  final String uiFontFamily;
  final String storyFontFamily;
  final double headingScale;
  final double bodyScale;

  // --- Layout ---
  final double buttonRadiusBase;
  final double cardRadiusBase;
  final double touchTargetMin;
  final double spacingScale;

  // --- Animation & Decoration ---
  final double sparkleIntensity; // 0.0 = none, 1.0 = maximum
  final bool showParticles;
  final bool preferDarkMode;

  // --- Age-Appropriate Labels ---
  final String createCharacterLabel;
  final String feelingsLabel;
  final String feelingsNavLabel;
  final String newStoryLabel;
  final String quickStoryLabel;
  final String companionLabel;
  final String heroLabel;
  final String feelingsPrompt;

  const AgeBandThemeData({
    required this.band,
    required this.primary,
    required this.primaryLight,
    required this.primaryDark,
    required this.gradientStart,
    required this.gradientMid,
    required this.gradientEnd,
    required this.accent,
    required this.accentLight,
    required this.surface,
    required this.textOnDark,
    required this.textOnLight,
    required this.uiFontFamily,
    required this.storyFontFamily,
    required this.headingScale,
    required this.bodyScale,
    required this.buttonRadiusBase,
    required this.cardRadiusBase,
    required this.touchTargetMin,
    required this.spacingScale,
    required this.sparkleIntensity,
    required this.showParticles,
    required this.preferDarkMode,
    required this.createCharacterLabel,
    required this.feelingsLabel,
    required this.feelingsNavLabel,
    required this.newStoryLabel,
    required this.quickStoryLabel,
    required this.companionLabel,
    required this.heroLabel,
    required this.feelingsPrompt,
  });

  /// Background gradient built from the band's three gradient colors.
  LinearGradient get backgroundGradient => LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [gradientStart, gradientMid, gradientEnd],
        stops: const [0.0, 0.5, 1.0],
      );

  /// Gold shimmer gradient (shared across bands, uses accent colors).
  LinearGradient get accentShimmer => LinearGradient(
        colors: [accent, accentLight, accent],
        stops: const [0.0, 0.5, 1.0],
      );

  /// CTA glow gradient.
  LinearGradient get ctaGlow => LinearGradient(
        colors: [primaryLight, primary, primaryDark],
        stops: const [0.0, 0.5, 1.0],
      );

  // --- Scaled accessors for convenience ---

  double get touchTargetComfortable => touchTargetMin + 8;
  double get touchTargetLarge => touchTargetMin + 24;

  double get radiusSm => buttonRadiusBase * 0.5;
  double get radiusMd => buttonRadiusBase;
  double get radiusLg => buttonRadiusBase * 1.5;
  double get radiusXl => buttonRadiusBase * 2.0;

  /// Build a UI TextTheme using this band's font family.
  TextTheme buildUITextTheme(TextTheme base) {
    final fontCreator = _googleFontCreator(uiFontFamily);
    final textThemeCreator = _googleFontTextThemeCreator(uiFontFamily);

    return textThemeCreator(base).copyWith(
      headlineLarge: fontCreator(
        fontSize: 32 * headingScale,
        fontWeight: FontWeight.bold,
        height: 1.2,
      ),
      headlineMedium: fontCreator(
        fontSize: 28 * headingScale,
        fontWeight: FontWeight.w600,
        height: 1.2,
      ),
      titleLarge: fontCreator(
        fontSize: 24 * headingScale,
        fontWeight: FontWeight.w600,
        height: 1.3,
      ),
      titleMedium: fontCreator(
        fontSize: 20 * bodyScale,
        fontWeight: FontWeight.w600,
        height: 1.3,
      ),
      bodyLarge: fontCreator(
        fontSize: 18 * bodyScale,
        fontWeight: FontWeight.w500,
        height: 1.5,
      ),
      bodyMedium: fontCreator(
        fontSize: 16 * bodyScale,
        fontWeight: FontWeight.w500,
        height: 1.5,
      ),
      labelLarge: fontCreator(
        fontSize: 18 * bodyScale,
        fontWeight: FontWeight.w600,
      ),
      labelMedium: fontCreator(
        fontSize: 16 * bodyScale,
        fontWeight: FontWeight.w600,
      ),
    );
  }

  /// Build a storybook TextStyle for body text.
  TextStyle get storyBodyStyle {
    final fontCreator = _googleFontCreator(storyFontFamily);
    return fontCreator(
      fontSize: 20 * bodyScale,
      fontWeight: FontWeight.normal,
      height: 1.8,
      letterSpacing: 0.3,
    );
  }

  /// Build a storybook TextStyle for titles.
  TextStyle get storyTitleStyle {
    final fontCreator = _googleFontCreator(storyFontFamily);
    return fontCreator(
      fontSize: 28 * headingScale,
      fontWeight: FontWeight.bold,
      height: 1.3,
    );
  }
}

// ---------------------------------------------------------------------------
// Band definitions
// ---------------------------------------------------------------------------

/// Sprout (ages 3-5): Warm sunset palette, bubbly rounded shapes,
/// illustration-heavy, huge touch targets, minimal text.
const sproutTheme = AgeBandThemeData(
  band: AgeBand.sprout,
  // Warm sunset palette
  primary: Color(0xFFE65100), // Deep orange
  primaryLight: Color(0xFFFF8A50), // Light orange
  primaryDark: Color(0xFFBF360C), // Burnt orange
  gradientStart: Color(0xFF1A0533), // Deep plum (keeps magic feel)
  gradientMid: Color(0xFF3D1260), // Warm purple
  gradientEnd: Color(0xFF2E1B4E), // Purple-pink
  accent: Color(0xFFFFD54F), // Gold (shared)
  accentLight: Color(0xFFFFE082),
  surface: Color(0xFFFFF3E0), // Warm cream
  textOnDark: Color(0xFFFFFFFF),
  textOnLight: Color(0xFF3E2723), // Dark brown for readability
  // Rounded, bubbly font
  uiFontFamily: 'Nunito',
  storyFontFamily: 'Merriweather',
  headingScale: 1.15, // Slightly larger headings
  bodyScale: 1.1, // Slightly larger body
  // Extra round, extra large
  buttonRadiusBase: 24.0,
  cardRadiusBase: 28.0,
  touchTargetMin: 88.0, // Extra large for small fingers
  spacingScale: 1.2,
  // Fun sparkles but not overwhelming
  sparkleIntensity: 0.7,
  showParticles: true,
  preferDarkMode: false,
  // Simple, action-oriented labels
  createCharacterLabel: 'Make Your Hero!',
  feelingsLabel: 'How do you feel?',
  feelingsNavLabel: 'Feelings',
  newStoryLabel: 'New Story!',
  quickStoryLabel: 'Tell Me a Story!',
  companionLabel: 'Pick a Buddy!',
  heroLabel: 'Your Hero',
  feelingsPrompt: 'Tap a face!',
);

/// Explorer (ages 6-8): Current magical purple — the baseline aesthetic.
/// Sparkles, readable labels, sense of wonder.
const explorerTheme = AgeBandThemeData(
  band: AgeBand.explorer,
  // Current magical purple palette (preserved as-is)
  primary: Color(0xFF6A1B9A),
  primaryLight: Color(0xFF9C4DCC),
  primaryDark: Color(0xFF4A148C),
  gradientStart: Color(0xFF120226),
  gradientMid: Color(0xFF2A0A4E),
  gradientEnd: Color(0xFF1A1040),
  accent: Color(0xFFFFD54F),
  accentLight: Color(0xFFFFE082),
  surface: Color(0xFFB2DFDB),
  textOnDark: Color(0xFFFFFFFF),
  textOnLight: Color(0xFF333333),
  // Current Quicksand font
  uiFontFamily: 'Quicksand',
  storyFontFamily: 'Merriweather',
  headingScale: 1.0,
  bodyScale: 1.0,
  // Current radii and targets
  buttonRadiusBase: 16.0,
  cardRadiusBase: 20.0,
  touchTargetMin: 64.0,
  spacingScale: 1.0,
  // Maximum sparkle
  sparkleIntensity: 1.0,
  showParticles: true,
  preferDarkMode: false,
  // Magical labels
  createCharacterLabel: 'Create Your Hero!',
  feelingsLabel: 'How does your hero feel?',
  feelingsNavLabel: 'Feelings',
  newStoryLabel: 'New Story',
  quickStoryLabel: 'Quick Story',
  companionLabel: 'Choose a Companion',
  heroLabel: 'Your Hero',
  feelingsPrompt: 'Tap to explore feelings',
);

/// Adventurer (ages 9-12): Deeper cosmic palette, book-like typography,
/// sophisticated but still engaging. "Cool" factor.
const adventurerTheme = AgeBandThemeData(
  band: AgeBand.adventurer,
  // Deep cosmic palette
  primary: Color(0xFF283593), // Deep indigo
  primaryLight: Color(0xFF5C6BC0), // Medium indigo
  primaryDark: Color(0xFF1A237E), // Navy indigo
  gradientStart: Color(0xFF0D0D2B), // Near-black navy
  gradientMid: Color(0xFF1A1A4E), // Dark indigo
  gradientEnd: Color(0xFF0F1838), // Deep navy
  accent: Color(0xFF80CBC4), // Teal accent (cooler, more sophisticated)
  accentLight: Color(0xFFB2DFDB),
  surface: Color(0xFFE8EAF6), // Cool light indigo
  textOnDark: Color(0xFFE8EAF6), // Soft white-blue
  textOnLight: Color(0xFF1A237E), // Dark indigo
  // Slab serif for a "book" feel
  uiFontFamily: 'Bitter',
  storyFontFamily: 'Merriweather',
  headingScale: 0.95,
  bodyScale: 0.95,
  // Slightly sharper corners
  buttonRadiusBase: 12.0,
  cardRadiusBase: 16.0,
  touchTargetMin: 64.0,
  spacingScale: 0.95,
  // Subtle glints, not sparkles
  sparkleIntensity: 0.3,
  showParticles: true,
  preferDarkMode: false,
  // More mature labels
  createCharacterLabel: 'Create Character',
  feelingsLabel: 'Set the mood',
  feelingsNavLabel: 'Mood',
  newStoryLabel: 'New Story',
  quickStoryLabel: 'Quick Story',
  companionLabel: 'Choose Companion',
  heroLabel: 'Character',
  feelingsPrompt: 'Set the mood for your story',
);

/// Creator (ages 13+): Clean, editorial, dark mode default.
/// Novel-app aesthetic. Minimal decoration.
const creatorTheme = AgeBandThemeData(
  band: AgeBand.creator,
  // Near-black with subtle purple undertone
  primary: Color(0xFF7C4DFF), // Bright purple accent
  primaryLight: Color(0xFFB388FF), // Light purple
  primaryDark: Color(0xFF651FFF), // Deep purple
  gradientStart: Color(0xFF0A0A14), // Near-black
  gradientMid: Color(0xFF121228), // Very dark purple
  gradientEnd: Color(0xFF0E0E1E), // Near-black blue
  accent: Color(0xFF7C4DFF), // Purple accent (not gold — more modern)
  accentLight: Color(0xFFB388FF),
  surface: Color(0xFF1E1E2E), // Dark surface
  textOnDark: Color(0xFFE0E0E0), // Light gray
  textOnLight: Color(0xFF212121), // Near-black
  // Clean sans-serif
  uiFontFamily: 'SourceSansPro',
  storyFontFamily: 'Merriweather',
  headingScale: 0.9,
  bodyScale: 0.9,
  // Sharp corners, standard targets
  buttonRadiusBase: 8.0,
  cardRadiusBase: 12.0,
  touchTargetMin: 56.0,
  spacingScale: 0.9,
  // Minimal decoration
  sparkleIntensity: 0.0,
  showParticles: false,
  preferDarkMode: true,
  // Direct, no-frills labels
  createCharacterLabel: 'New Character',
  feelingsLabel: 'Set the mood',
  feelingsNavLabel: 'Mood',
  newStoryLabel: 'New Story',
  quickStoryLabel: 'Quick Start',
  companionLabel: 'Companion',
  heroLabel: 'Character',
  feelingsPrompt: 'What mood fits your story?',
);

/// Look up the theme data for a given band.
AgeBandThemeData themeForBand(AgeBand band) {
  switch (band) {
    case AgeBand.sprout:
      return sproutTheme;
    case AgeBand.explorer:
      return explorerTheme;
    case AgeBand.adventurer:
      return adventurerTheme;
    case AgeBand.creator:
      return creatorTheme;
  }
}

/// Look up the theme data for a given age.
AgeBandThemeData themeForAge(int age) => themeForBand(ageBandFromAge(age));

// ---------------------------------------------------------------------------
// Helpers — map font family strings to Google Fonts constructors
// ---------------------------------------------------------------------------

typedef _FontCreator = TextStyle Function({
  double? fontSize,
  FontWeight? fontWeight,
  double? height,
  double? letterSpacing,
  Color? color,
});

TextTheme Function([TextTheme?]) _googleFontTextThemeCreator(String family) {
  switch (family) {
    case 'Nunito':
      return GoogleFonts.nunitoTextTheme;
    case 'Quicksand':
      return GoogleFonts.quicksandTextTheme;
    case 'Bitter':
      return GoogleFonts.bitterTextTheme;
    case 'SourceSansPro':
      return GoogleFonts.sourceSans3TextTheme;
    case 'Merriweather':
      return GoogleFonts.merriweatherTextTheme;
    default:
      return GoogleFonts.quicksandTextTheme;
  }
}

_FontCreator _googleFontCreator(String family) {
  switch (family) {
    case 'Nunito':
      return ({fontSize, fontWeight, height, letterSpacing, color}) =>
          GoogleFonts.nunito(
            fontSize: fontSize,
            fontWeight: fontWeight,
            height: height,
            letterSpacing: letterSpacing,
            color: color,
          );
    case 'Quicksand':
      return ({fontSize, fontWeight, height, letterSpacing, color}) =>
          GoogleFonts.quicksand(
            fontSize: fontSize,
            fontWeight: fontWeight,
            height: height,
            letterSpacing: letterSpacing,
            color: color,
          );
    case 'Bitter':
      return ({fontSize, fontWeight, height, letterSpacing, color}) =>
          GoogleFonts.bitter(
            fontSize: fontSize,
            fontWeight: fontWeight,
            height: height,
            letterSpacing: letterSpacing,
            color: color,
          );
    case 'SourceSansPro':
      return ({fontSize, fontWeight, height, letterSpacing, color}) =>
          GoogleFonts.sourceSans3(
            fontSize: fontSize,
            fontWeight: fontWeight,
            height: height,
            letterSpacing: letterSpacing,
            color: color,
          );
    case 'Merriweather':
      return ({fontSize, fontWeight, height, letterSpacing, color}) =>
          GoogleFonts.merriweather(
            fontSize: fontSize,
            fontWeight: fontWeight,
            height: height,
            letterSpacing: letterSpacing,
            color: color,
          );
    default:
      return ({fontSize, fontWeight, height, letterSpacing, color}) =>
          GoogleFonts.quicksand(
            fontSize: fontSize,
            fontWeight: fontWeight,
            height: height,
            letterSpacing: letterSpacing,
            color: color,
          );
  }
}
