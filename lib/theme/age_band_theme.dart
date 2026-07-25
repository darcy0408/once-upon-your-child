import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// The 6 visual age bands that drive the entire UI personality.
///
/// Each band adapts colors, typography, spacing, animation intensity,
/// and label language to match the developmental stage of the user.
enum AgeBand {
  /// Ages 2-5: Warm, bubbly, illustration-heavy, minimal text
  sprout,

  /// Ages 6-8: Magical purple, sparkles, readable labels (current default)
  explorer,

  /// Ages 9-12: Deeper cosmic palette, book-like typography, "cool" factor
  adventurer,

  /// Ages 13-14: Clean, editorial, dark mode default, novel-app aesthetic
  creator,

  /// Ages 15-17: Cinematic dark, teal accent, direct language
  adolescent,

  /// Ages 18+: Refined minimal dark, warm amber accent, adult-appropriate
  adult,
}

/// Resolves an age (in years) to the appropriate visual band.
AgeBand ageBandFromAge(int age) {
  if (age <= 5) return AgeBand.sprout;
  if (age <= 8) return AgeBand.explorer;
  if (age <= 12) return AgeBand.adventurer;
  if (age <= 14) return AgeBand.creator;
  if (age <= 17) return AgeBand.adolescent;
  return AgeBand.adult;
}

/// Color flavor within an age band, derived from the hero's gender pick.
///
/// Each band keeps its personality (Sprout = warm sunset, Explorer = magical
/// purple, ...) — a flavor only shifts the hues toward what that group tends
/// to love. [neutral] is the base palette, shown until a gender is chosen.
enum PaletteFlavor { neutral, boy, girl }

/// Maps the wizard's gender strings ('Boy' / 'Girl', any case) to a flavor.
PaletteFlavor paletteFlavorFromGender(String? gender) {
  switch (gender?.toLowerCase()) {
    case 'boy':
      return PaletteFlavor.boy;
    case 'girl':
      return PaletteFlavor.girl;
    default:
      return PaletteFlavor.neutral;
  }
}

/// The flavor currently in effect, kept here (not only in the Riverpod
/// notifier) because many widgets resolve palettes through the static
/// [themeForBand]/[themeForAge] helpers without provider access. The
/// AgeBandNotifier is the single writer; everyone else only reads.
PaletteFlavor currentPaletteFlavor = PaletteFlavor.neutral;

/// All visual parameters that vary per age band.
///
/// Every screen reads from this instead of hard-coded constants, so
/// the entire app adapts automatically when the user's age band changes.
///
/// Accessible from any widget via:
/// ```dart
/// final ageBand = Theme.of(context).extension<AgeBandThemeData>()!;
/// ```
class AgeBandThemeData extends ThemeExtension<AgeBandThemeData> {
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

  /// Background for content cards (AppCard, story text panels). Never plain
  /// white/cream — young bands get warm tinted lights, mature bands rich
  /// darks, so cards feel like part of the world instead of a form.
  final Color cardColor;

  /// Text/icon color guaranteed to contrast with [cardColor] (>= 4.5:1).
  /// Always use this pair together; never white text on an unknown card.
  final Color onCard;

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
  final String launchStoryLabel;
  final String companionCTALabel;

  // --- Scenario / Wizard Labels ---
  /// Page title for scenario selection step.
  final String scenarioPageTitle;

  /// Page subtitle for scenario selection step.
  final String scenarioPageSubtitle;

  /// Category header for fantasy/magical scenarios.
  final String scenarioCategoryFantasyLabel;

  /// Category header for real-life/contemporary scenarios.
  final String scenarioCategoryRealLabel;

  /// Hint text shown at the bottom of the hero creator step.
  final String wizardNextHint;

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
    required this.cardColor,
    required this.onCard,
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
    required this.launchStoryLabel,
    required this.companionCTALabel,
    required this.scenarioPageTitle,
    required this.scenarioPageSubtitle,
    required this.scenarioCategoryFantasyLabel,
    required this.scenarioCategoryRealLabel,
    required this.wizardNextHint,
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

  // --- ThemeExtension overrides ---

  @override
  AgeBandThemeData copyWith({AgeBand? band}) {
    // Age band themes are immutable presets; copyWith returns self.
    return this;
  }

  @override
  AgeBandThemeData lerp(AgeBandThemeData? other, double t) {
    // Discrete switch — no interpolation between age bands.
    if (t < 0.5) return this;
    return other ?? this;
  }

  /// A copy of this band with only color fields swapped — used to build the
  /// boy/girl flavor variants without duplicating typography, layout, and
  /// label fields (which never vary by flavor).
  AgeBandThemeData recolored({
    Color? primary,
    Color? primaryLight,
    Color? primaryDark,
    Color? gradientStart,
    Color? gradientMid,
    Color? gradientEnd,
    Color? accent,
    Color? accentLight,
    Color? surface,
    Color? textOnDark,
    Color? textOnLight,
    Color? cardColor,
    Color? onCard,
  }) {
    return AgeBandThemeData(
      band: band,
      primary: primary ?? this.primary,
      primaryLight: primaryLight ?? this.primaryLight,
      primaryDark: primaryDark ?? this.primaryDark,
      gradientStart: gradientStart ?? this.gradientStart,
      gradientMid: gradientMid ?? this.gradientMid,
      gradientEnd: gradientEnd ?? this.gradientEnd,
      accent: accent ?? this.accent,
      accentLight: accentLight ?? this.accentLight,
      surface: surface ?? this.surface,
      textOnDark: textOnDark ?? this.textOnDark,
      textOnLight: textOnLight ?? this.textOnLight,
      cardColor: cardColor ?? this.cardColor,
      onCard: onCard ?? this.onCard,
      uiFontFamily: uiFontFamily,
      storyFontFamily: storyFontFamily,
      headingScale: headingScale,
      bodyScale: bodyScale,
      buttonRadiusBase: buttonRadiusBase,
      cardRadiusBase: cardRadiusBase,
      touchTargetMin: touchTargetMin,
      spacingScale: spacingScale,
      sparkleIntensity: sparkleIntensity,
      showParticles: showParticles,
      preferDarkMode: preferDarkMode,
      createCharacterLabel: createCharacterLabel,
      feelingsLabel: feelingsLabel,
      feelingsNavLabel: feelingsNavLabel,
      newStoryLabel: newStoryLabel,
      quickStoryLabel: quickStoryLabel,
      companionLabel: companionLabel,
      heroLabel: heroLabel,
      feelingsPrompt: feelingsPrompt,
      launchStoryLabel: launchStoryLabel,
      companionCTALabel: companionCTALabel,
      scenarioPageTitle: scenarioPageTitle,
      scenarioPageSubtitle: scenarioPageSubtitle,
      scenarioCategoryFantasyLabel: scenarioCategoryFantasyLabel,
      scenarioCategoryRealLabel: scenarioCategoryRealLabel,
      wizardNextHint: wizardNextHint,
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
  gradientStart: Color(0xFF2D1B42), // Warm plum — cozy, not cold
  gradientMid: Color(0xFF5F2776), // Rose-purple — bedtime story feel
  gradientEnd: Color(0xFF8B3A6B), // Dusty rose — sunset warmth
  accent: Color(0xFFFFD54F), // Gold (shared)
  accentLight: Color(0xFFFFE082),
  surface: Color(0xFFFFE3C2), // Warm apricot — tinted, never white
  textOnDark: Color(0xFFFFFFFF),
  textOnLight: Color(0xFF3E2723), // Dark brown for readability
  cardColor: Color(0xFFFFE3C2), // Warm apricot card
  onCard: Color(0xFF4E342E), // Cocoa ink (11:1 on apricot)
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
  feelingsNavLabel: 'Life Quests',
  newStoryLabel: 'New Story!',
  quickStoryLabel: 'Tell Me a Story!',
  companionLabel: 'Pick a Buddy!',
  heroLabel: 'Your Hero',
  feelingsPrompt: 'Tap a face!',
  launchStoryLabel: 'Make Magic!',
  companionCTALabel: 'Pick My Friends!',
  scenarioPageTitle: 'Pick a Place!',
  scenarioPageSubtitle: 'Where should the story happen?',
  scenarioCategoryFantasyLabel: 'Magical Worlds',
  scenarioCategoryRealLabel: 'Real-Life Heroes',
  wizardNextHint: 'Next: Review & Make Magic!',
);

/// Explorer (ages 6-8): Magical purple — the baseline aesthetic.
/// Sparkles, readable labels, sense of wonder. Visibly more vivid/purple
/// than Sprout's warm plum (MT-121 — previous gradient read as dark navy).
const explorerTheme = AgeBandThemeData(
  band: AgeBand.explorer,
  // Vivid magical purple palette — brighter than the prior near-black mix
  // so Explorer reads as clearly "purple magic" and not Sprout-dark-navy.
  primary: Color(0xFF7B1FA2),
  primaryLight: Color(0xFFBA68C8),
  primaryDark: Color(0xFF4A148C),
  gradientStart: Color(0xFF2E0854), // Deep royal violet
  gradientMid: Color(0xFF5B21B6), // Vivid magical purple
  gradientEnd: Color(0xFF3B1078), // Rich indigo-purple base
  accent: Color(0xFFFFD54F),
  accentLight: Color(0xFFFFE082),
  surface: Color(0xFFEBD9F7), // Soft lilac (replaces the stray teal)
  textOnDark: Color(0xFFFFFFFF),
  textOnLight: Color(0xFF38115C),
  cardColor: Color(0xFFEBD9F7), // Lilac card
  onCard: Color(0xFF38115C), // Deep violet ink (10:1 on lilac)
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
  feelingsNavLabel: 'Life Quests',
  newStoryLabel: 'New Story',
  quickStoryLabel: 'Quick Story',
  companionLabel: 'Choose a Companion',
  heroLabel: 'Your Hero',
  feelingsPrompt: 'Tap to explore feelings',
  launchStoryLabel: 'Make Magic!',
  companionCTALabel: 'Gather Party!',
  scenarioPageTitle: 'Choose Your Adventure!',
  scenarioPageSubtitle: 'Where shall we go today?',
  scenarioCategoryFantasyLabel: 'Magical Worlds',
  scenarioCategoryRealLabel: 'Real-Life Heroes',
  wizardNextHint: 'Next: Review & Make Magic!',
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
  cardColor: Color(0xFF1B2450), // Deep cosmic card — "cool", not a form
  onCard: Color(0xFFE8EAF6), // Soft white-blue ink (12:1)
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
  feelingsNavLabel: 'Life Quests',
  newStoryLabel: 'New Story',
  quickStoryLabel: 'Quick Story',
  companionLabel: 'Choose Companion',
  heroLabel: 'Character',
  feelingsPrompt: 'Set the mood for your story',
  launchStoryLabel: 'Start Adventure!',
  companionCTALabel: 'Assemble Party',
  scenarioPageTitle: 'Choose Your Adventure!',
  scenarioPageSubtitle: 'Where shall we go today?',
  scenarioCategoryFantasyLabel: 'Magical Worlds',
  scenarioCategoryRealLabel: 'Real-Life Heroes',
  wizardNextHint: 'Next: Review & Launch!',
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
  cardColor: Color(0xFF1E1E2E), // Editorial dark card
  onCard: Color(0xFFE2E2EE), // Soft lavender-gray ink
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
  launchStoryLabel: 'Start Writing',
  companionCTALabel: 'Set the Cast',
  scenarioPageTitle: 'Choose Your Adventure!',
  scenarioPageSubtitle: 'Where shall we go today?',
  scenarioCategoryFantasyLabel: 'Magical Worlds',
  scenarioCategoryRealLabel: 'Real-Life Heroes',
  wizardNextHint: 'Next: Review',
);

/// Adolescent (ages 15-17): Cinematic charcoal-black, electric teal accent,
/// direct no-nonsense language. Matches the moody adolescent character art.
const adolescentTheme = AgeBandThemeData(
  band: AgeBand.adolescent,
  // Cinematic dark with electric teal
  primary: Color(0xFF00838F), // Deep teal
  primaryLight: Color(0xFF26C6DA), // Bright cyan
  primaryDark: Color(0xFF005662), // Very deep teal
  gradientStart: Color(0xFF070B14), // Near-black blue
  gradientMid: Color(0xFF0D1520), // Very dark blue
  gradientEnd: Color(0xFF0A1018), // Near-black
  accent: Color(0xFF00BCD4), // Cyan
  accentLight: Color(0xFF80DEEA),
  surface: Color(0xFF121E2B), // Dark blue-gray
  textOnDark: Color(0xFFE0F7FA), // Light cyan-white
  textOnLight: Color(0xFF1A2332),
  cardColor: Color(0xFF121E2B), // Cinematic dark card
  onCard: Color(0xFFE0F7FA), // Light cyan-white ink
  uiFontFamily: 'SourceSansPro',
  storyFontFamily: 'Merriweather',
  headingScale: 0.88,
  bodyScale: 0.88,
  buttonRadiusBase: 6.0,
  cardRadiusBase: 10.0,
  touchTargetMin: 52.0,
  spacingScale: 0.88,
  sparkleIntensity: 0.0,
  showParticles: false,
  preferDarkMode: true,
  createCharacterLabel: 'Your Character',
  feelingsLabel: 'Under the surface',
  feelingsNavLabel: 'Inner Map',
  newStoryLabel: 'New Story',
  quickStoryLabel: 'Quick Start',
  companionLabel: 'Companion',
  heroLabel: 'Character',
  feelingsPrompt: "What's going on under the surface?",
  launchStoryLabel: 'Start Writing',
  companionCTALabel: 'Continue',
  scenarioPageTitle: 'Pick your ground',
  scenarioPageSubtitle: 'Every one of these puts you in a corner. Choose where.',
  scenarioCategoryFantasyLabel: 'Speculative Fiction',
  scenarioCategoryRealLabel: 'Contemporary Themes',
  wizardNextHint: 'Next: Review',
);

/// Adult (ages 18+): Refined minimal dark, warm amber-gold accent,
/// adult-appropriate vocabulary. The most editorial and understated band.
const adultTheme = AgeBandThemeData(
  band: AgeBand.adult,
  // Refined midnight sapphire with a warm copper highlight.
  // `primary` (CTA background) holds WCAG AA against white button text (5.4:1);
  // copper lives in `accent` for glints and links, echoing the navy+copper
  // pairing without warming the whole palette.
  primary: Color(0xFF2C5D8F), // Sapphire steel — AA-contrast CTA background
  primaryLight: Color(0xFF5B8CBD), // Lit steel blue (hover / glow)
  primaryDark: Color(0xFF1B3E60), // Deep navy
  gradientStart: Color(0xFF060A12), // Near-black navy
  gradientMid: Color(0xFF0C1524), // Deep midnight navy
  gradientEnd: Color(0xFF080D17), // Near-black navy
  accent: Color(0xFFC77B47), // Copper highlight
  accentLight: Color(0xFFE0A277), // Lit copper
  surface: Color(0xFF142130), // Dark navy surface
  textOnDark: Color(0xFFE6EDF5), // Cool off-white
  textOnLight: Color(0xFF142130),
  cardColor: Color(0xFF142130), // Midnight navy card
  onCard: Color(0xFFE6EDF5), // Cool off-white ink
  uiFontFamily: 'SourceSansPro',
  storyFontFamily: 'Merriweather',
  headingScale: 0.85,
  bodyScale: 0.85,
  buttonRadiusBase: 4.0,
  cardRadiusBase: 8.0,
  touchTargetMin: 48.0,
  spacingScale: 0.85,
  sparkleIntensity: 0.0,
  showParticles: false,
  preferDarkMode: true,
  createCharacterLabel: 'Your Character',
  feelingsLabel: 'Emotional landscape',
  feelingsNavLabel: 'Landscape',
  newStoryLabel: 'New Story',
  quickStoryLabel: 'Quick Start',
  companionLabel: 'Companion',
  heroLabel: 'Character',
  feelingsPrompt: 'Explore the emotional landscape',
  launchStoryLabel: 'Create',
  companionCTALabel: 'Continue',
  scenarioPageTitle: 'Choose a Premise',
  scenarioPageSubtitle: 'What narrative interests you?',
  scenarioCategoryFantasyLabel: 'Speculative Fiction',
  scenarioCategoryRealLabel: 'Contemporary Themes',
  wizardNextHint: 'Next: Review',
);

// ---------------------------------------------------------------------------
// Flavor variants — hue shifts of each band's base mood, per gender pick.
// Every `primary` keeps >= 4.5:1 contrast with white button text; every
// cardColor/onCard pair keeps >= 7:1. Adult has no variants (adults pick for
// themselves); Adolescent boy deliberately IS the base cinematic teal.
// ---------------------------------------------------------------------------

/// Sprout girl — "Rosy Sunset": raspberry + gold on a rose-plum dusk.
final _sproutGirl = sproutTheme.recolored(
  primary: const Color(0xFFC2185B), // Raspberry (5.9:1 w/ white)
  primaryLight: const Color(0xFFF06292),
  primaryDark: const Color(0xFF880E4F),
  gradientStart: const Color(0xFF3A1545),
  gradientMid: const Color(0xFF7A2B68),
  gradientEnd: const Color(0xFFA34877),
  surface: const Color(0xFFFFDCE8),
  textOnLight: const Color(0xFF4A2233),
  cardColor: const Color(0xFFFFDCE8), // Blush card
  onCard: const Color(0xFF4A2233), // Plum-brown ink
);

/// Sprout boy — "Campfire Glow": the ember orange leans warmer, sunset
/// gradient ends in glowing sienna instead of dusty rose.
final _sproutBoy = sproutTheme.recolored(
  gradientStart: const Color(0xFF2B1B3D),
  gradientMid: const Color(0xFF6B2D4F),
  gradientEnd: const Color(0xFFA34A2A),
  surface: const Color(0xFFFFE2B8),
  cardColor: const Color(0xFFFFE2B8), // Butter card
  onCard: const Color(0xFF3E2723),
);

/// Explorer girl — "Orchid Magic": brighter orchid purple, same gold magic.
final _explorerGirl = explorerTheme.recolored(
  primary: const Color(0xFF9C27B0), // Orchid (6.3:1 w/ white)
  primaryLight: const Color(0xFFCE93D8),
  primaryDark: const Color(0xFF6A1B9A),
  gradientStart: const Color(0xFF3D0A5E),
  gradientMid: const Color(0xFF7B2CBF),
  gradientEnd: const Color(0xFF53107E),
  surface: const Color(0xFFF6D9F0),
  textOnLight: const Color(0xFF511254),
  cardColor: const Color(0xFFF6D9F0), // Pink-lilac card
  onCard: const Color(0xFF511254),
);

/// Explorer boy — "Royal Wizard": deeper violet-indigo, same gold magic.
final _explorerBoy = explorerTheme.recolored(
  primary: const Color(0xFF5E35B1), // Deep violet (8.0:1 w/ white)
  primaryLight: const Color(0xFF9575CD),
  primaryDark: const Color(0xFF4527A0),
  gradientStart: const Color(0xFF1D0B54),
  gradientMid: const Color(0xFF4A27A8),
  gradientEnd: const Color(0xFF2B1370),
  surface: const Color(0xFFDEDAF8),
  textOnLight: const Color(0xFF201461),
  cardColor: const Color(0xFFDEDAF8), // Periwinkle card
  onCard: const Color(0xFF201461),
);

/// Adventurer boy — "Midnight Voyager": dark navy + copper. Treasure-map
/// cards in warm parchment ink.
final _adventurerBoy = adventurerTheme.recolored(
  primary: const Color(0xFF1565C0), // Voyager blue (5.7:1 w/ white)
  primaryLight: const Color(0xFF5E92F3),
  primaryDark: const Color(0xFF0D47A1),
  gradientStart: const Color(0xFF070D24),
  gradientMid: const Color(0xFF12224E),
  gradientEnd: const Color(0xFF0A1638),
  accent: const Color(0xFFE5975A), // Copper
  accentLight: const Color(0xFFF2BE93),
  surface: const Color(0xFFE3ECFA),
  textOnLight: const Color(0xFF12315E),
  cardColor: const Color(0xFF142347), // Midnight navy card
  onCard: const Color(0xFFF2E7D8), // Warm parchment ink
);

/// Adventurer girl — "Aurora Quest": cosmic violet + aurora mint.
final _adventurerGirl = adventurerTheme.recolored(
  primary: const Color(0xFF6A2FBF), // Cosmic violet (7.6:1 w/ white)
  primaryLight: const Color(0xFF9E6FE8),
  primaryDark: const Color(0xFF4A1F8F),
  gradientStart: const Color(0xFF120B2E),
  gradientMid: const Color(0xFF2E1560),
  gradientEnd: const Color(0xFF1A0F42),
  accent: const Color(0xFF5CD6C0), // Aurora mint
  accentLight: const Color(0xFFA8F0E0),
  surface: const Color(0xFFEDE7FB),
  textOnLight: const Color(0xFF2C1157),
  cardColor: const Color(0xFF251349), // Deep violet card
  onCard: const Color(0xFFEFE9FB),
);

/// Creator boy — "Neon Circuit": near-black + electric blue/cyan.
final _creatorBoy = creatorTheme.recolored(
  primary: const Color(0xFF3D5AFE), // Electric blue (5.1:1 w/ white)
  primaryLight: const Color(0xFF8187FF),
  primaryDark: const Color(0xFF304FFE),
  gradientStart: const Color(0xFF06080F),
  gradientMid: const Color(0xFF0C1224),
  gradientEnd: const Color(0xFF080C18),
  accent: const Color(0xFF00E5FF),
  accentLight: const Color(0xFF84FFFF),
  surface: const Color(0xFF141B33),
  cardColor: const Color(0xFF141B33),
  onCard: const Color(0xFFDDE6FA),
);

/// Creator girl — "Midnight Bloom": near-black + orchid and rose neon.
final _creatorGirl = creatorTheme.recolored(
  primary: const Color(0xFF8E24AA), // Deep orchid (7.1:1 w/ white)
  primaryLight: const Color(0xFFCE93D8),
  primaryDark: const Color(0xFF6A1B9A),
  gradientStart: const Color(0xFF0F0714),
  gradientMid: const Color(0xFF1E0F28),
  gradientEnd: const Color(0xFF140A1C),
  accent: const Color(0xFFFF80AB),
  accentLight: const Color(0xFFFFB2DD),
  surface: const Color(0xFF251427),
  cardColor: const Color(0xFF251427),
  onCard: const Color(0xFFF4DFEF),
);

/// Adolescent girl — "Dusk Rose": the same cinematic dark, lit rose instead
/// of teal. (Adolescent boy stays on the base electric-teal palette.)
final _adolescentGirl = adolescentTheme.recolored(
  primary: const Color(0xFFAD1457), // Deep rose (7.0:1 w/ white)
  primaryLight: const Color(0xFFEC6A9C),
  primaryDark: const Color(0xFF780E3F),
  gradientStart: const Color(0xFF10060C),
  gradientMid: const Color(0xFF1E0C18),
  gradientEnd: const Color(0xFF150812),
  accent: const Color(0xFFFF6090),
  accentLight: const Color(0xFFFFA8C4),
  surface: const Color(0xFF201018),
  cardColor: const Color(0xFF201018),
  onCard: const Color(0xFFFAE3EC),
);

final Map<AgeBand, Map<PaletteFlavor, AgeBandThemeData>> _flavorVariants = {
  AgeBand.sprout: {
    PaletteFlavor.boy: _sproutBoy,
    PaletteFlavor.girl: _sproutGirl,
  },
  AgeBand.explorer: {
    PaletteFlavor.boy: _explorerBoy,
    PaletteFlavor.girl: _explorerGirl,
  },
  AgeBand.adventurer: {
    PaletteFlavor.boy: _adventurerBoy,
    PaletteFlavor.girl: _adventurerGirl,
  },
  AgeBand.creator: {
    PaletteFlavor.boy: _creatorBoy,
    PaletteFlavor.girl: _creatorGirl,
  },
  AgeBand.adolescent: {
    // boy: falls through to the base cinematic teal on purpose.
    PaletteFlavor.girl: _adolescentGirl,
  },
  // AgeBand.adult: no flavor variants.
};

/// Look up the theme data for a given band.
///
/// [flavor] defaults to the app-wide [currentPaletteFlavor] so the dozens of
/// existing static call sites pick up the gender flavor automatically.
AgeBandThemeData themeForBand(AgeBand band, {PaletteFlavor? flavor}) {
  final resolved = flavor ?? currentPaletteFlavor;
  if (resolved != PaletteFlavor.neutral) {
    final variant = _flavorVariants[band]?[resolved];
    if (variant != null) return variant;
  }
  switch (band) {
    case AgeBand.sprout:
      return sproutTheme;
    case AgeBand.explorer:
      return explorerTheme;
    case AgeBand.adventurer:
      return adventurerTheme;
    case AgeBand.creator:
      return creatorTheme;
    case AgeBand.adolescent:
      return adolescentTheme;
    case AgeBand.adult:
      return adultTheme;
  }
}

/// Look up the theme data for a given age.
AgeBandThemeData themeForAge(int age, {PaletteFlavor? flavor}) =>
    themeForBand(ageBandFromAge(age), flavor: flavor);

/// Convenience helpers for common band groupings used across the app.
extension AgeBandGroups on AgeBand {
  /// True for creator, adolescent, and adult — the three "mature" bands
  /// that share dark-mode editorial UI and direct label language.
  bool get isMature =>
      this == AgeBand.creator ||
      this == AgeBand.adolescent ||
      this == AgeBand.adult;

  /// True for sprout and explorer — the "young child" bands that use
  /// large touch targets, bright colors, and simplified language.
  bool get isYoung =>
      this == AgeBand.sprout || this == AgeBand.explorer;

  /// True for the five bands that participate in the returnable Hero Saga
  /// (MT-235 Phase 2): Explorer (6-8), Adventurer (9-12), Creator (13-14),
  /// Adolescent (15-17), and Adult (18+ — rides the Creator visuals/roster
  /// client-side, mirroring the backend's 18+ → Creator prompt-tier routing).
  /// Sprout (3-5) is the only band with no saga.
  ///
  /// Single source of truth for the saga band set so the magic-review WRITE
  /// path (`recordIssue`) and the welcome-back READ path (the "Previously…" /
  /// "Issue #N" recap card) gate on the SAME predicate and can never drift to
  /// a Creator-only subset — the exact regression MT-286 guards against.
  bool get usesHeroSaga =>
      this == AgeBand.explorer ||
      this == AgeBand.adventurer ||
      this == AgeBand.creator ||
      this == AgeBand.adolescent ||
      this == AgeBand.adult;
}

extension AgeBandSizing on AgeBandThemeData {
  double heading(double base) => base * headingScale;
  double body(double base) => base * bodyScale;
  double space(double base) => base * spacingScale;
  double touchTarget(double base) => math.max(base, touchTargetMin);
}

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
