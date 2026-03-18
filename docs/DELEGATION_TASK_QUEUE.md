# Delegation Task Queue — Age Band Expansion

Paste these prompts directly into Codex, Gemini CLI, or a Claude Sonnet/Haiku instance.
Each prompt is fully self-contained. No back-and-forth needed.

## Dependency order

```
[A] Asset copy script  ──┐
[B] Image generation   ──┤── both must finish before ──► [C] Enum expansion ──► [D–K] parallel
```

Tasks D through K have no dependency on each other — run them simultaneously if you have multiple instances.

---

## [A] ASSET COPY — Run first
**Tool:** Codex, Gemini CLI, or any Python-capable assistant
**Time:** ~5 min

```
You are working on the project at C:\dev\story-weaver-app (Windows paths, but you may be running in bash/WSL so use forward slashes).

Write and run a Python script called `copy_age_band_assets.py` at the project root that copies files from `age_band_assets/` into the Flutter `assets/` directory. Run it after writing it.

Rules:
- DO NOT delete anything. Copy only, never move.
- Create destination directories if they don't exist.
- Overwrite destination files if same name exists.
- Skip files that only exist in destination (never delete destination-only files).

Exact copy mapping (source → destination):

age_band_assets/sprouts/UI/           → assets/images/ui/sprout/
age_band_assets/sprouts/archetypes/   → assets/images/archetypes/sprout/
age_band_assets/sprouts/companions/   → assets/images/companions/sprout/
age_band_assets/sprouts/feelings/     → assets/images/feelings/sprout/
age_band_assets/sprouts/orbs/         → assets/images/orbs/sprout/
age_band_assets/sprouts/backgrounds/  → assets/images/backgrounds/sprout/

age_band_assets/early_readers/ui/          → assets/images/ui/explorer/
age_band_assets/early_readers/archetypes/  → assets/images/archetypes/explorer/
age_band_assets/early_readers/companions/  → assets/images/companions/explorer/
age_band_assets/early_readers/feelings/    → assets/images/feelings/explorer/
age_band_assets/early_readers/orbs/        → assets/images/orbs/explorer/
age_band_assets/early_readers/backgrounds/ → assets/images/backgrounds/explorer/
age_band_assets/early_readers/scenes/      → assets/images/scenes/explorer/

age_band_assets/adventurers/ui/          → assets/images/ui/adventurer/
age_band_assets/adventurers/archetypes/  → assets/images/archetypes/adventurer/
age_band_assets/adventurers/companions/  → assets/images/companions/adventurer/
age_band_assets/adventurers/feelings/    → assets/images/feelings/adventurer/
age_band_assets/adventurers/orbs/        → assets/images/orbs/adventurer/
age_band_assets/adventurers/backgrounds/ → assets/images/backgrounds/adventurer/
age_band_assets/adventurers/scenes/      → assets/images/scenes/adventurer/

age_band_assets/creators/ui/          → assets/images/ui/creator/
age_band_assets/creators/archetypes/  → assets/images/archetypes/creator/
age_band_assets/creators/companions/  → assets/images/companions/creator/
age_band_assets/creators/feelings/    → assets/images/feelings/creator/
age_band_assets/creators/orbs/        → assets/images/orbs/creator/
age_band_assets/creators/backgrounds/ → assets/images/backgrounds/creator/
age_band_assets/creators/scenes/      → assets/images/scenes/creator/

age_band_assets/adolescents/ui/          → assets/images/ui/adolescent/
age_band_assets/adolescents/archetypes/  → assets/images/archetypes/adolescent/
age_band_assets/adolescents/companions/  → assets/images/companions/adolescent/
age_band_assets/adolescents/feelings/    → assets/images/feelings/adolescent/
age_band_assets/adolescents/orbs/        → assets/images/orbs/adolescent/
age_band_assets/adolescents/backgrounds/ → assets/images/backgrounds/adolescent/
age_band_assets/adolescents/scenes/      → assets/images/scenes/adolescent/

# For adolescent band: also copy from older_adolescents anything NOT already in adolescents
age_band_assets/older_adolescents/ui/          → assets/images/ui/adolescent/         (only missing files)
age_band_assets/older_adolescents/companions/  → assets/images/companions/adolescent/  (only missing files)
age_band_assets/older_adolescents/feelings/    → assets/images/feelings/adolescent/    (only missing files)

age_band_assets/adults/ui/          → assets/images/ui/adult/
age_band_assets/adults/archetypes/  → assets/images/archetypes/adult/
age_band_assets/adults/companions/  → assets/images/companions/adult/
age_band_assets/adults/feelings/    → assets/images/feelings/adult/
age_band_assets/adults/orbs/        → assets/images/orbs/adult/
age_band_assets/adults/backgrounds/ → assets/images/backgrounds/adult/
age_band_assets/adults/scenes/      → assets/images/scenes/adult/

After copying, print a summary: how many files copied per destination band, and list any destination directories that ended up empty.

Do NOT modify pubspec.yaml — that is handled separately.
```

---

## [B] PUBSPEC UPDATE — Run after [A]
**Tool:** Codex, Gemini CLI, or any code assistant
**Time:** ~3 min

```
You are working on the Flutter project at C:\dev\story-weaver-app.

Open pubspec.yaml and add the following asset directory entries under the existing `assets:` section. Add them after the existing entries — do not remove anything already there.

Add these lines (maintain the same indentation as existing asset entries — 4 spaces):

    - assets/images/ui/adolescent/
    - assets/images/ui/adult/
    - assets/images/companions/
    - assets/images/companions/sprout/
    - assets/images/companions/explorer/
    - assets/images/companions/adventurer/
    - assets/images/companions/creator/
    - assets/images/companions/adolescent/
    - assets/images/companions/adult/
    - assets/images/archetypes/
    - assets/images/archetypes/sprout/
    - assets/images/archetypes/explorer/
    - assets/images/archetypes/adventurer/
    - assets/images/archetypes/creator/
    - assets/images/archetypes/adolescent/
    - assets/images/archetypes/adult/
    - assets/images/feelings/sprout/
    - assets/images/feelings/explorer/
    - assets/images/feelings/adventurer/
    - assets/images/feelings/creator/
    - assets/images/feelings/adolescent/
    - assets/images/feelings/adult/
    - assets/images/orbs/sprout/
    - assets/images/orbs/explorer/
    - assets/images/orbs/adventurer/
    - assets/images/orbs/creator/
    - assets/images/orbs/adolescent/
    - assets/images/orbs/adult/
    - assets/images/backgrounds/sprout/
    - assets/images/backgrounds/explorer/
    - assets/images/backgrounds/adventurer/
    - assets/images/backgrounds/creator/
    - assets/images/backgrounds/adolescent/
    - assets/images/backgrounds/adult/
    - assets/images/scenes/explorer/
    - assets/images/scenes/adventurer/
    - assets/images/scenes/creator/
    - assets/images/scenes/adolescent/
    - assets/images/scenes/adult/

Before adding, check if any of these already exist in the file — skip duplicates.
After editing, verify the YAML is valid (no broken indentation).
```

---

## [C] AGEBAND ENUM EXPANSION — Run after [A] and [B]
**Tool:** Codex (preferred for Dart) or Claude Sonnet
**Time:** ~20 min
**This is the most critical task — everything else depends on it.**

```
You are working on a Flutter/Dart app at C:\dev\story-weaver-app.

Expand the AgeBand enum from 4 values to 6 by adding `adolescent` (ages 15-17) and `adult` (ages 18+).

IMPORTANT DART RULES:
- All switch statements on an enum must be exhaustive — missing cases are compile errors.
- Dart uses camelCase for method names — never snake_case.
- Always add `mounted` checks before setState() or ScaffoldMessenger calls after any await.

## Step 1 — lib/theme/age_band_theme.dart

Read the whole file first.

1a. Add to the AgeBand enum after `creator`:
    adolescent,  // Ages 15-17
    adult,       // Ages 18+

1b. Update ageBandFromAge():
    AgeBand ageBandFromAge(int age) {
      if (age <= 5) return AgeBand.sprout;
      if (age <= 8) return AgeBand.explorer;
      if (age <= 11) return AgeBand.adventurer;
      if (age <= 14) return AgeBand.creator;
      if (age <= 17) return AgeBand.adolescent;
      return AgeBand.adult;
    }

1c. Add adolescentTheme constant after creatorTheme:
    const adolescentTheme = AgeBandThemeData(
      band: AgeBand.adolescent,
      primary: Color(0xFF37474F),
      primaryLight: Color(0xFF62727B),
      primaryDark: Color(0xFF263238),
      gradientStart: Color(0xFF0A0E12),
      gradientMid: Color(0xFF1A2530),
      gradientEnd: Color(0xFF0F1922),
      accent: Color(0xFFFFAB40),
      accentLight: Color(0xFFFFCC80),
      surface: Color(0xFF263238),
      textOnDark: Color(0xFFECEFF1),
      textOnLight: Color(0xFF263238),
      uiFontFamily: 'SourceSansPro',
      storyFontFamily: 'Merriweather',
      headingScale: 0.9,
      bodyScale: 0.9,
      buttonRadiusBase: 8.0,
      cardRadiusBase: 10.0,
      touchTargetMin: 52.0,
      spacingScale: 0.88,
      sparkleIntensity: 0.0,
      showParticles: false,
      preferDarkMode: true,
      createCharacterLabel: 'New Character',
      feelingsLabel: 'What\'s going on?',
      feelingsNavLabel: 'Feelings',
      newStoryLabel: 'New Story',
      quickStoryLabel: 'Quick Start',
      companionLabel: 'Companion',
      heroLabel: 'Character',
      feelingsPrompt: 'What\'s on your mind?',
    );

1d. Add adultTheme constant after adolescentTheme:
    const adultTheme = AgeBandThemeData(
      band: AgeBand.adult,
      primary: Color(0xFF5C6BC0),
      primaryLight: Color(0xFF8E99A4),
      primaryDark: Color(0xFF3949AB),
      gradientStart: Color(0xFF0D0D12),
      gradientMid: Color(0xFF1A1A24),
      gradientEnd: Color(0xFF12121C),
      accent: Color(0xFFCFD8DC),
      accentLight: Color(0xFFECEFF1),
      surface: Color(0xFF1E1E28),
      textOnDark: Color(0xFFE0E0E0),
      textOnLight: Color(0xFF212121),
      uiFontFamily: 'SourceSansPro',
      storyFontFamily: 'Merriweather',
      headingScale: 0.88,
      bodyScale: 0.88,
      buttonRadiusBase: 6.0,
      cardRadiusBase: 8.0,
      touchTargetMin: 48.0,
      spacingScale: 0.85,
      sparkleIntensity: 0.0,
      showParticles: false,
      preferDarkMode: true,
      createCharacterLabel: 'New Character',
      feelingsLabel: 'Set the mood',
      feelingsNavLabel: 'Mood',
      newStoryLabel: 'New Story',
      quickStoryLabel: 'Quick Start',
      companionLabel: 'Companion',
      heroLabel: 'Character',
      feelingsPrompt: 'What mood fits your story?',
    );

1e. Update themeForBand() to add:
    case AgeBand.adolescent: return adolescentTheme;
    case AgeBand.adult: return adultTheme;

## Step 2 — Find ALL switch statements on AgeBand

Search every .dart file in lib/ for the pattern `AgeBand` and find every switch or if-else chain that checks AgeBand values. Add adolescent and adult cases to each one.

Run this search:
  grep -rn "AgeBand\." lib/ --include="*.dart"

Key files that definitely need updating:
- lib/widgets/image_make_magic_button.dart
- lib/widgets/image_continue_button.dart
- lib/screens/wizard_steps/hero_creator_step.dart
- lib/theme/app_theme.dart
- lib/providers/age_band_provider.dart

For button widgets: add cases pointing to assets/images/ui/adolescent/ and assets/images/ui/adult/.
For hero_creator_step.dart: see Step 3 below.

## Step 3 — Add hero character choice lists in hero_creator_step.dart

Read the file and find _sproutHeroChoices, _explorerHeroChoices etc. to understand the pattern.

Add after _creatorHeroChoices:

    const List<_SproutHeroChoice> _adolescentHeroChoices = [
      _SproutHeroChoice(gender: 'Boy', assetPath: 'assets/images/ui/adolescent/boy_character.png', label: 'Hero', skinTone: 'Light'),
      _SproutHeroChoice(gender: 'Boy', assetPath: 'assets/images/ui/adolescent/boy_character_asian.png', label: 'Hero', skinTone: 'Asian'),
      _SproutHeroChoice(gender: 'Boy', assetPath: 'assets/images/ui/adolescent/boy_character_black.png', label: 'Hero', skinTone: 'Black'),
      _SproutHeroChoice(gender: 'Boy', assetPath: 'assets/images/ui/adolescent/boy_character_hispanic.png', label: 'Hero', skinTone: 'Hispanic'),
      _SproutHeroChoice(gender: 'Boy', assetPath: 'assets/images/ui/adolescent/boy_character_south_asian.png', label: 'Hero', skinTone: 'South Asian'),
      _SproutHeroChoice(gender: 'Girl', assetPath: 'assets/images/ui/adolescent/girl_character.png', label: 'Hero', skinTone: 'Light'),
      _SproutHeroChoice(gender: 'Girl', assetPath: 'assets/images/ui/adolescent/girl_character_asian.png', label: 'Hero', skinTone: 'Asian'),
      _SproutHeroChoice(gender: 'Girl', assetPath: 'assets/images/ui/adolescent/girl_character_black.png', label: 'Hero', skinTone: 'Black'),
      _SproutHeroChoice(gender: 'Girl', assetPath: 'assets/images/ui/adolescent/girl_character_hispanic.png', label: 'Hero', skinTone: 'Hispanic'),
      _SproutHeroChoice(gender: 'Girl', assetPath: 'assets/images/ui/adolescent/girl_character_south_asian.png', label: 'Hero', skinTone: 'South Asian'),
    ];

    const List<_SproutHeroChoice> _adultHeroChoices = [
      _SproutHeroChoice(gender: 'Boy', assetPath: 'assets/images/ui/adult/man_character_white.png', label: 'Character', skinTone: 'Light'),
      _SproutHeroChoice(gender: 'Boy', assetPath: 'assets/images/ui/adult/man_character_asian.png', label: 'Character', skinTone: 'Asian'),
      _SproutHeroChoice(gender: 'Boy', assetPath: 'assets/images/ui/adult/man_character_black.png', label: 'Character', skinTone: 'Black'),
      _SproutHeroChoice(gender: 'Boy', assetPath: 'assets/images/ui/adult/man_character_hispanic.png', label: 'Character', skinTone: 'Hispanic'),
      _SproutHeroChoice(gender: 'Boy', assetPath: 'assets/images/ui/adult/man_character_south_asian.png', label: 'Character', skinTone: 'South Asian'),
      _SproutHeroChoice(gender: 'Girl', assetPath: 'assets/images/ui/adult/woman_character_white.png', label: 'Character', skinTone: 'Light'),
      _SproutHeroChoice(gender: 'Girl', assetPath: 'assets/images/ui/adult/woman_character_asian.png', label: 'Character', skinTone: 'Asian'),
      _SproutHeroChoice(gender: 'Girl', assetPath: 'assets/images/ui/adult/woman_character_black.png', label: 'Character', skinTone: 'Black'),
      _SproutHeroChoice(gender: 'Girl', assetPath: 'assets/images/ui/adult/woman_character_hispanic.png', label: 'Character', skinTone: 'Hispanic'),
      _SproutHeroChoice(gender: 'Girl', assetPath: 'assets/images/ui/adult/woman_character_south_asian.png', label: 'Character', skinTone: 'South Asian'),
    ];

Find _buildHeroCharacterCarousel() (search for that method name) and add AgeBand.adolescent and AgeBand.adult cases that return _adolescentHeroChoices and _adultHeroChoices respectively.

## Step 4 — Verify

Run: dart analyze lib/
Fix every error. There should be zero errors when done.
Warnings are acceptable, errors are not.
```

---

## [D] WIRE COMPANIONS PER BAND — Run after [C]
**Tool:** Codex or Claude Sonnet
**Time:** ~15 min

```
You are working on a Flutter/Dart app at C:\dev\story-weaver-app.
The AgeBand enum already has 6 values: sprout, explorer, adventurer, creator, adolescent, adult.

Read lib/screens/wizard_steps/companion_selector_step.dart in full.
Read lib/theme/age_band_theme.dart for AgeBandThemeData.

The _magicalCompanions getter (around line 76) returns a single hardcoded list of companions for all ages. Replace it so it returns different companions per band.

New companion data per band:

SPROUT: fluffy_dragon, magic_bunny, shining_puppy, tiny_fairy
  - image paths: assets/images/companions/sprout/{id}.png
  - descriptions: cute, cuddly, simple ("Loves warm hugs and tiny roars!")

EXPLORER: bloom_sprite, ember_dragon, moon_owl, star_fox
  - image paths: assets/images/companions/explorer/{id}.png
  - descriptions: whimsical, magical ("Breathes rainbow fire that reveals hidden paths")

ADVENTURER/CREATOR/ADOLESCENT/ADULT: iron_golem, shadow_lynx, storm_hawk, void_sprite
  - image paths: assets/images/companions/{band}/{id}.png
  - descriptions scale in maturity per band:
    adventurer: "An unbreakable guardian forged in starfire"
    creator: "Forged in the heart of a dying star, loyal to the end"
    adolescent: "Ancient, formidable. Speaks only truth."
    adult: "A sentinel of forgotten ages"

Implementation:
1. Replace the _magicalCompanions getter with a method that reads the current AgeBand from Theme.of(context).extension<AgeBandThemeData>()?.band
2. Switch on band and return the appropriate List<Companion>
3. Keep the custom pet companions and saved character companions logic unchanged — they prepend to whatever list is returned
4. You will need to import AgeBandThemeData at the top if not already imported

Run dart analyze lib/screens/wizard_steps/companion_selector_step.dart to verify. Fix all errors.
```

---

## [E] WIRE FEELINGS PER BAND — Run after [C]
**Tool:** Codex or Claude Sonnet
**Time:** ~20 min

```
You are working on a Flutter/Dart app at C:\dev\story-weaver-app.
The AgeBand enum has 6 values: sprout, explorer, adventurer, creator, adolescent, adult.

Read these files in full before making any changes:
- lib/feelings_wheel_data.dart
- lib/widgets/feelings_cloud_picker.dart
- lib/screens/wizard_steps/feeling_selection_step.dart

## Change 1 — lib/feelings_wheel_data.dart

Add this function at the bottom of the file:

/// Returns feeling IDs shown to this band. Empty list = show all.
List<String> coreFeelingIdsForBand(AgeBand band) {
  switch (band) {
    case AgeBand.sprout:
      return ['happy', 'sad', 'angry', 'scared', 'surprised', 'calm'];
    case AgeBand.explorer:
      return ['angry', 'worried', 'sad', 'frustrated', 'embarrassed', 'excited'];
    case AgeBand.adventurer:
      return ['angry', 'worried', 'sad', 'frustrated', 'embarrassed', 'excited',
              'jealous', 'guilty', 'confused', 'bored', 'lonely', 'nervous',
              'proud', 'disappointed', 'hopeful', 'content'];
    case AgeBand.creator:
      return ['angry', 'worried', 'sad', 'frustrated', 'embarrassed', 'excited',
              'jealous', 'guilty', 'confused', 'bored', 'lonely', 'nervous',
              'proud', 'disappointed', 'hopeful', 'content', 'resentful',
              'insecure', 'overwhelmed', 'anxious', 'numb', 'vulnerable',
              'conflicted', 'grateful', 'inspired', 'pressured', 'inadequate', 'relieved'];
    case AgeBand.adolescent:
    case AgeBand.adult:
      return []; // show all available feelings
  }
}

Add the import for AgeBandThemeData at the top: import 'theme/age_band_theme.dart';

## Change 2 — lib/widgets/feelings_cloud_picker.dart

Find where it loads the feeling image (currently loads assets/feelings_faces/{id}.png).

Update to try band-specific image first:
  String _bandImagePath(String id, String bandName) =>
      'assets/images/feelings/$bandName/$id.png';
  String _fallbackImagePath(String id) =>
      'assets/feelings_faces/$id.png';

In the Image.asset widget, use an errorBuilder chain:
  Image.asset(
    _bandImagePath(id, ageBand.band.name),
    errorBuilder: (_, __, ___) => Image.asset(
      _fallbackImagePath(id),
      errorBuilder: (_, __, ___) => Text(emoji, style: TextStyle(fontSize: 32)),
    ),
  )

## Change 3 — lib/screens/wizard_steps/feeling_selection_step.dart

Read the file. Find where it builds the feeling tiles/cards.
For AgeBand.sprout only: limit the displayed feelings to just 6 tiles in a 2×3 grid.
No sub-feelings drill-down for sprout. Tapping one = done, calls onNext immediately.
All other bands: unchanged behaviour.

Run dart analyze on all three files. Fix all errors.
```

---

## [F] WIRE PROGRESS ORBS PER BAND — Run after [C]
**Tool:** Codex or any code assistant
**Time:** ~10 min

```
You are working on a Flutter/Dart app at C:\dev\story-weaver-app.
The AgeBand enum has 6 values: sprout, explorer, adventurer, creator, adolescent, adult.

Read lib/widgets/image_progress_orb.dart in full.

Currently _orbAssetPath is hardcoded to assets/images/ui/clean/progress_done_orb.png and progress_active_orb.png.

Update it to use band-specific orbs. The orb asset paths follow this pattern:
  assets/images/orbs/{bandName}/progress_done.png
  assets/images/orbs/{bandName}/progress_active.png
  assets/images/orbs/{bandName}/progress_idle.png

Since _orbAssetPath is a getter in a StatefulWidget and needs context, move the logic into the build() method:
1. In build(), get the band: final band = Theme.of(context).extension<AgeBandThemeData>()?.band;
2. Build the path: final bandName = band?.name ?? 'clean';
3. For 'clean' band (null case), keep existing fallback paths.
4. For all real bands, use the assets/images/orbs/{bandName}/ paths.
5. Pass the resolved path down to the Image.asset widget.
6. Keep the existing errorBuilder gradient fallback — it catches any missing asset gracefully.

Run dart analyze lib/widgets/image_progress_orb.dart. Fix all errors.
```

---

## [G] WIRE ARCHETYPES PER BAND — Run after [C]
**Tool:** Codex or Claude Sonnet
**Time:** ~20 min

```
You are working on a Flutter/Dart app at C:\dev\story-weaver-app.
The AgeBand enum has 6 values: sprout, explorer, adventurer, creator, adolescent, adult.

Read lib/widgets/archetype_card.dart in full.

Find the defaultArchetypes list (or wherever archetype data is defined). It currently has 6 archetypes with sprout-style names pointing to assets/images/archetypes/.

Make it band-aware:

1. Create a function defaultArchetypesForBand(AgeBand band) that returns a List of archetype data.

2. SPROUT keeps existing names and assets:
   storm_rider, quiz_whiz, master_creator, heart_healer, lightning_runner, animal_whisperer
   → assets/images/archetypes/sprout/{name}.jpg
   → Kid-friendly descriptions ("Loves to run super fast!")

3. ALL OTHER BANDS use these names:
   brave_hero, clever_inventor, gentle_dreamer, kind_healer, mighty_guardian, speedy_explorer
   → assets/images/archetypes/{bandName}/{name}.jpg
   → Descriptions scale in sophistication:
     explorer: simple and fun ("Charges in with a fearless heart")
     adventurer: more dramatic ("Courage defines them — first into danger")
     creator/adolescent/adult: concise and real ("Courage. First in, last out.")

4. Where defaultArchetypes is currently used, pass the current band from:
   Theme.of(context).extension<AgeBandThemeData>()?.band ?? AgeBand.explorer

5. The onUseTemplate callbacks are set by the calling widget, not inside this function.
   Return plain data objects (or a model class) rather than fully-constructed widgets if needed.

Run dart analyze. Fix all errors.
```

---

## [H] WIRE BACKGROUNDS PER BAND — Run after [C]
**Tool:** Codex or Claude Sonnet
**Time:** ~15 min

```
You are working on a Flutter/Dart app at C:\dev\story-weaver-app.
The AgeBand enum has 6 values: sprout, explorer, adventurer, creator, adolescent, adult.

Read lib/theme/age_band_theme.dart in full.

## Change 1 — Add background path fields to AgeBandThemeData

Add two nullable String fields:
  final String? splashBgPath;
  final String? storyBgPath;

Add them to the constructor with required: false (just make them optional named params defaulting to null).
Update copyWith() and lerp() — for lerp return this if t < 0.5 as usual.

## Change 2 — Set paths on each band theme constant

For each band, set:
  splashBgPath: 'assets/images/backgrounds/{band}/splash_bg.jpg',
  storyBgPath:  'assets/images/backgrounds/{band}/story_page_bg.jpg',

Bands: sprout, explorer, adventurer, creator, adolescent, adult.

## Change 3 — Use in welcome/splash screen

Search lib/ for the welcome or splash screen (try: grep -rn "WelcomeScreen\|SplashScreen\|HomeScreen" lib/ --include="*.dart" -l).

In that screen's background widget, if ageBand.splashBgPath is not null, render it as an image behind the existing gradient:

  Stack(
    children: [
      if (ageBand.splashBgPath != null)
        Positioned.fill(
          child: Image.asset(
            ageBand.splashBgPath!,
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) => const SizedBox.shrink(),
          ),
        ),
      Positioned.fill(
        child: DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                ageBand.gradientStart.withValues(alpha: 0.85),
                ageBand.gradientMid.withValues(alpha: 0.75),
                ageBand.gradientEnd.withValues(alpha: 0.85),
              ],
            ),
          ),
        ),
      ),
      // ... existing content
    ],
  )

The gradient overlay keeps text readable while the background image shows through.

Run dart analyze on all changed files. Fix all errors.
```

---

## [I] BIG FEELINGS NAMING PER BAND — Run after [C]
**Tool:** Codex or any code assistant
**Time:** ~10 min

```
You are working on a Flutter/Dart app at C:\dev\story-weaver-app.

Read lib/data/scenario_data.dart in full.

Find the ScenarioCard with id: 'big_feelings_quest'.

## Change 1 — Add more age-granular title/description variants

Add these fields to the ScenarioCard class (make them optional/nullable):
  final String? tweenTitle;       // ages 9-11
  final String? teenTitle;        // ages 12-14
  final String? olderTeenTitle;   // ages 15-17
  final String? adultTitle;       // ages 18+

  final String? tweenDescription;
  final String? teenDescription;
  final String? olderTeenDescription;
  final String? adultDescription;

## Change 2 — Update titleForAge() and descriptionForAge()

  String titleForAge(int age) {
    if (age <= 5 && youngTitle != null) return youngTitle!;
    if (age <= 8) return title;
    if (age <= 11 && tweenTitle != null) return tweenTitle!;
    if (age <= 14 && teenTitle != null) return teenTitle!;
    if (age <= 17 && olderTeenTitle != null) return olderTeenTitle!;
    if (age >= 18 && adultTitle != null) return adultTitle!;
    if (age >= 10 && matureTitle != null) return matureTitle!;
    return title;
  }

Same pattern for descriptionForAge().

## Change 3 — Set values on the big_feelings_quest ScenarioCard

  youngTitle: 'Big Feelings',
  title: 'Big Feelings Quest',
  tweenTitle: 'Feeling Quest',
  teenTitle: 'The Inner Map',
  olderTeenTitle: 'Under the Surface',
  adultTitle: 'Emotional Landscape',
  matureTitle: 'Riding the Storm',

  youngDescription: 'Feelings come and go like the wind. You can be the boss of your clouds!',
  // title description stays: 'Riding the waves of being worried or mad without getting swept away.'
  tweenDescription: 'When the pressure builds — how do you hold your ground?',
  teenDescription: 'Mapping the terrain of what you feel, and choosing what to do next.',
  olderTeenDescription: 'The stuff no one talks about. The pressure, the noise, the real you underneath.',
  adultDescription: 'Navigating emotional complexity with clarity and self-awareness.',

Run dart analyze lib/data/scenario_data.dart. Fix all errors.
```

---

## [J] BACKEND BIG FEELINGS — AGES 15+ — Run any time (Python, independent)
**Tool:** Codex, Gemini CLI, or any Python-capable assistant
**Time:** ~20 min

```
You are working on a Python/Flask backend at C:\dev\story-weaver-app\backend.

Read backend/services/interactive_adventure_prompt_builder.py in full.

Find the existing age-differentiated Big Feelings sections:
- "AGES 6-8 BIG FEELINGS RULES"
- "AGES 9-12 BIG FEELINGS RULES"
- "AGES 13-15 BIG FEELINGS RULES"

Understand the pattern. Then add two new sections following exactly the same structure.

## ADD: AGES 15-17 BIG FEELINGS RULES

Tone: Real, direct, YA novel quality. No condescension.
Vocabulary: Nuanced — "hollowed out" not "sad", "quietly furious" not "angry".
Complexity:
- Friend-group fractures, romantic uncertainty, family tension, future pressure
- Social media consequences
- Gap between who they are and who people expect them to be
- Consequences are real — a sent message can't be unsent
Regulation: Frame as "finding clarity" not "calming down"
  - Physical: movement, music, creating, being outdoors
  - Cognitive: naming what's actually happening vs the catastrophe story
  - Social: choosing who to let in, asking for what they need specifically
Repair: May take multiple conversations. "Sorry" is the start, not the end.
Choices: 3 per decision point
  1. Reactive/impulsive (understandable, creates consequences)
  2. Creates space to think (not presented as "the right answer")
  3. Moves toward connection (hardest, highest risk, highest payoff)
NEVER: therapy jargon, moralizing, passive victim protagonist, tidy resolution

## ADD: AGES 18+ BIG FEELINGS RULES

Tone: Literary fiction quality. Emotional intelligence assumed, not taught.
Vocabulary: Full adult spectrum — ambivalence, cognitive dissonance, anticipatory grief, compassion fatigue.
Complexity:
- Adult responsibilities: work, relationships, parenting, finances, health
- Feelings about feelings: guilt about anger, shame about sadness
- Relationship dynamics: partnership strain, family obligation vs personal need
- No villain required — sometimes two reasonable positions conflict
Regulation: Frame as "emotional navigation"
  - The character likely knows techniques — challenge is using them when hardest
  - Self-compassion is the sophisticated skill
  - Sometimes right move is letting the feeling exist without fixing it
Repair: Adult repair means having avoided conversations. Being right and being kind sometimes conflict.
Choices: 3 per decision point
  1. Self-protection (reasonable, may have relational cost)
  2. Sit with discomfort (hardest, most growth, least dramatic)
  3. Prioritise the relationship (generous, may have personal cost)
NEVER: condescend, pop-psychology language, imply a "correct" emotional response, tidy endings

## UPDATE the age-checking logic

Find where the age determines which Big Feelings rules to use. Add:
  if age >= 18:  → use AGES 18+ rules
  elif age >= 15:  → use AGES 15-17 rules
  (keep existing elif age >= 13: for AGES 13-15, etc.)

## ADD tests

In backend/tests/unit/test_story_constraints.py, add:
- Test that age=16 Big Feelings prompt does NOT contain "dragon breaths" or "stomp"
- Test that age=25 Big Feelings prompt does NOT contain "friend-group"
- Test that the correct age path is selected for each age

Run: python -m pytest backend/tests/unit/test_story_constraints.py -q
Fix any failures.
```

---

## [K] DART ANALYZE CLEAN-UP — Run after all D–J are complete
**Tool:** Codex or Claude Sonnet
**Time:** ~10 min

```
You are working on a Flutter/Dart app at C:\dev\story-weaver-app.

Run: dart analyze lib/

Read the full output. Fix every ERROR (not warnings — those are acceptable).

Common issues to expect:
- Missing switch cases on AgeBand (add adolescent and adult cases)
- Undefined names if an import was missed
- Type mismatches if a method signature changed

After fixing, run dart analyze lib/ again and confirm zero errors.

Do not refactor anything beyond what's needed to fix the errors.
Do not add comments or documentation.
Just fix the errors, nothing else.
```

---

## Quick-reference order

| Step | Task | Depends on | Best tool |
|------|------|-----------|-----------|
| A | Copy assets | nothing | Gemini CLI / Codex |
| B | Update pubspec.yaml | A | Gemini CLI / Codex |
| C | Expand AgeBand enum | A + B | Codex (Dart) |
| D | Companions per band | C | Codex |
| E | Feelings per band | C | Codex |
| F | Progress orbs per band | C | Codex |
| G | Archetypes per band | C | Codex |
| H | Backgrounds per band | C | Codex |
| I | Big Feelings naming | C | Codex |
| J | Backend 15+ feelings | nothing | Gemini CLI / Codex |
| K | Final dart analyze fix | D–I | Codex / Sonnet |
