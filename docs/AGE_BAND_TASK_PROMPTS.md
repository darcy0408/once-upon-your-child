# Age Band Expansion — Delegation Prompts

Each prompt below is self-contained and can be given to a coding assistant to execute. Tasks 1-3 must be completed in order. Tasks 4-11 can run in parallel after Task 3.

---

## PROMPT 1: Copy & Organize Assets

```
You are working on a Flutter app at C:\dev\story-weaver-app.

There is a directory `age_band_assets/` at the project root containing generated image assets for 7 age bands. These need to be copied into the Flutter `assets/` directory structure.

DO NOT delete the original `age_band_assets/` directory — just copy files.

### Step 1: Fix sprouts casing
The sprouts folder uses `age_band_assets/sprouts/UI/` (uppercase). Copy its contents with lowercase folder name.

### Step 2: Copy assets using this mapping

For each band, copy files as follows:

**Sprout** (source: age_band_assets/sprouts/):
- `UI/*` → `assets/images/ui/sprout/` (overwrite existing files with same names, keep files that only exist in destination)
- `archetypes/*` → `assets/images/archetypes/sprout/`
- `companions/*` → `assets/images/companions/sprout/`
- `orbs/*` → `assets/images/orbs/sprout/`
- `backgrounds/*` → `assets/images/backgrounds/sprout/`
- NOTE: sprouts has no feelings/ or scenes/ folder — skip those

**Explorer** (source: age_band_assets/early_readers/):
- `ui/*` → `assets/images/ui/explorer/` (overwrite existing)
- `archetypes/*` → `assets/images/archetypes/explorer/`
- `companions/*` → `assets/images/companions/explorer/`
- `feelings/*` → `assets/images/feelings/explorer/`
- `orbs/*` → `assets/images/orbs/explorer/`
- `backgrounds/*` → `assets/images/backgrounds/explorer/`
- `scenes/*` → `assets/images/scenes/explorer/`

**Adventurer** (source: age_band_assets/adventurers/):
- `ui/*` → `assets/images/ui/adventurer/` (overwrite existing)
- `archetypes/*` → `assets/images/archetypes/adventurer/`
- `companions/*` → `assets/images/companions/adventurer/`
- `feelings/*` → `assets/images/feelings/adventurer/`
- `orbs/*` → `assets/images/orbs/adventurer/`
- `backgrounds/*` → `assets/images/backgrounds/adventurer/`
- `scenes/*` → `assets/images/scenes/adventurer/`

**Creator** (source: age_band_assets/creators/):
- `ui/*` → `assets/images/ui/creator/` (overwrite existing)
- `archetypes/*` → `assets/images/archetypes/creator/`
- `companions/*` → `assets/images/companions/creator/`
- `feelings/*` → `assets/images/feelings/creator/`
- `orbs/*` → `assets/images/orbs/creator/`
- `backgrounds/*` → `assets/images/backgrounds/creator/`
- `scenes/*` → `assets/images/scenes/creator/`

**Adolescent** (source: age_band_assets/adolescents/ — fill gaps from age_band_assets/older_adolescents/):
- `ui/*` → `assets/images/ui/adolescent/`
- `archetypes/*` → `assets/images/archetypes/adolescent/`
- `companions/*` → `assets/images/companions/adolescent/`
- `feelings/*` → `assets/images/feelings/adolescent/`
- `orbs/*` → `assets/images/orbs/adolescent/`
- `backgrounds/*` → `assets/images/backgrounds/adolescent/`
- `scenes/*` → `assets/images/scenes/adolescent/`
- For any file that exists in older_adolescents but NOT in adolescents (like clicked button states), copy from older_adolescents

**Adult** (source: age_band_assets/adults/):
- `ui/*` → `assets/images/ui/adult/`
- `archetypes/*` → `assets/images/archetypes/adult/`
- `companions/*` → `assets/images/companions/adult/`
- `feelings/*` → `assets/images/feelings/adult/`
- `orbs/*` → `assets/images/orbs/adult/`
- `backgrounds/*` → `assets/images/backgrounds/adult/`
- `scenes/*` → `assets/images/scenes/adult/`

### Step 3: Update pubspec.yaml

Add all new asset directories to the `assets:` section in `pubspec.yaml`. Keep existing entries. Add:
- `assets/images/ui/adolescent/`
- `assets/images/ui/adult/`
- `assets/images/companions/sprout/`
- `assets/images/companions/explorer/`
- `assets/images/companions/adventurer/`
- `assets/images/companions/creator/`
- `assets/images/companions/adolescent/`
- `assets/images/companions/adult/`
- `assets/images/archetypes/sprout/`
- `assets/images/archetypes/explorer/`
- `assets/images/archetypes/adventurer/`
- `assets/images/archetypes/creator/`
- `assets/images/archetypes/adolescent/`
- `assets/images/archetypes/adult/`
- `assets/images/feelings/sprout/` (will be empty for now)
- `assets/images/feelings/explorer/`
- `assets/images/feelings/adventurer/`
- `assets/images/feelings/creator/`
- `assets/images/feelings/adolescent/`
- `assets/images/feelings/adult/`
- `assets/images/orbs/sprout/`
- `assets/images/orbs/explorer/`
- `assets/images/orbs/adventurer/`
- `assets/images/orbs/creator/`
- `assets/images/orbs/adolescent/`
- `assets/images/orbs/adult/`
- `assets/images/backgrounds/sprout/`
- `assets/images/backgrounds/explorer/`
- `assets/images/backgrounds/adventurer/`
- `assets/images/backgrounds/creator/`
- `assets/images/backgrounds/adolescent/`
- `assets/images/backgrounds/adult/`
- `assets/images/scenes/explorer/`
- `assets/images/scenes/adventurer/`
- `assets/images/scenes/creator/`
- `assets/images/scenes/adolescent/`
- `assets/images/scenes/adult/`

### Step 4: Verify
Run `ls` on each new directory to confirm files were copied. Report any directories that are empty or have fewer files than expected.
```

---

## PROMPT 2: Expand AgeBand Enum to 6 Values

```
You are working on a Flutter/Dart app at C:\dev\story-weaver-app. The app currently has 4 age bands (sprout, explorer, adventurer, creator). You need to expand to 6 by adding `adolescent` (ages 15-17) and `adult` (ages 18+).

IMPORTANT: Dart requires ALL switch statements on an enum to be exhaustive. Every switch on AgeBand MUST have cases for all 6 values or the code won't compile.

### Step 1: Update lib/theme/age_band_theme.dart

1. Add `adolescent` and `adult` to the `AgeBand` enum (after `creator`).

2. Update `ageBandFromAge()`:
   ```dart
   AgeBand ageBandFromAge(int age) {
     if (age <= 5) return AgeBand.sprout;
     if (age <= 8) return AgeBand.explorer;
     if (age <= 11) return AgeBand.adventurer;
     if (age <= 14) return AgeBand.creator;
     if (age <= 17) return AgeBand.adolescent;
     return AgeBand.adult;
   }
   ```

3. Add `adolescentTheme` constant after `creatorTheme`:
   ```dart
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
   ```

4. Add `adultTheme` constant after `adolescentTheme`:
   ```dart
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
   ```

5. Update `themeForBand()`:
   ```dart
   AgeBandThemeData themeForBand(AgeBand band) {
     switch (band) {
       case AgeBand.sprout: return sproutTheme;
       case AgeBand.explorer: return explorerTheme;
       case AgeBand.adventurer: return adventurerTheme;
       case AgeBand.creator: return creatorTheme;
       case AgeBand.adolescent: return adolescentTheme;
       case AgeBand.adult: return adultTheme;
     }
   }
   ```

### Step 2: Find and fix ALL other switch statements on AgeBand

Search ALL `.dart` files in `lib/` for:
- `switch` statements that match on an `AgeBand` value
- `case AgeBand.` patterns
- If-else chains checking `== AgeBand.sprout`, `== AgeBand.creator`, etc.

For EACH one found, add the `adolescent` and `adult` cases. Guidelines:
- `adolescent` should generally behave like `creator` but with its own asset paths (`.../adolescent/...`)
- `adult` should generally behave like `creator` but with its own asset paths (`.../adult/...`)
- For character image paths: adult uses `man_character_*` / `woman_character_*` instead of `boy_character_*` / `girl_character_*`
- For buttons: adolescent/adult use `assets/images/ui/adolescent/` and `assets/images/ui/adult/`

Key files to check (but search for ALL occurrences):
- lib/widgets/image_make_magic_button.dart
- lib/widgets/image_continue_button.dart
- lib/screens/wizard_steps/hero_creator_step.dart
- lib/providers/age_band_provider.dart
- lib/main_story.dart
- lib/theme/app_theme.dart

### Step 3: Add hero character choice lists for new bands

In `lib/screens/wizard_steps/hero_creator_step.dart`, find the existing character choice lists (like `_sproutHeroChoices`, `_explorerHeroChoices`, etc.) and add:

```dart
const _adolescentHeroChoices = [
  _SproutHeroChoice(assetPath: 'assets/images/ui/adolescent/boy_character.png', gender: 'Boy', skinTone: 'white'),
  _SproutHeroChoice(assetPath: 'assets/images/ui/adolescent/boy_character_asian.png', gender: 'Boy', skinTone: 'asian'),
  _SproutHeroChoice(assetPath: 'assets/images/ui/adolescent/boy_character_black.png', gender: 'Boy', skinTone: 'black'),
  _SproutHeroChoice(assetPath: 'assets/images/ui/adolescent/boy_character_hispanic.png', gender: 'Boy', skinTone: 'hispanic'),
  _SproutHeroChoice(assetPath: 'assets/images/ui/adolescent/boy_character_south_asian.png', gender: 'Boy', skinTone: 'south_asian'),
  _SproutHeroChoice(assetPath: 'assets/images/ui/adolescent/girl_character.png', gender: 'Girl', skinTone: 'white'),
  _SproutHeroChoice(assetPath: 'assets/images/ui/adolescent/girl_character_asian.png', gender: 'Girl', skinTone: 'asian'),
  _SproutHeroChoice(assetPath: 'assets/images/ui/adolescent/girl_character_black.png', gender: 'Girl', skinTone: 'black'),
  _SproutHeroChoice(assetPath: 'assets/images/ui/adolescent/girl_character_hispanic.png', gender: 'Girl', skinTone: 'hispanic'),
  _SproutHeroChoice(assetPath: 'assets/images/ui/adolescent/girl_character_south_asian.png', gender: 'Girl', skinTone: 'south_asian'),
];

const _adultHeroChoices = [
  _SproutHeroChoice(assetPath: 'assets/images/ui/adult/man_character_white.png', gender: 'Boy', skinTone: 'white'),
  _SproutHeroChoice(assetPath: 'assets/images/ui/adult/man_character_asian.png', gender: 'Boy', skinTone: 'asian'),
  _SproutHeroChoice(assetPath: 'assets/images/ui/adult/man_character_black.png', gender: 'Boy', skinTone: 'black'),
  _SproutHeroChoice(assetPath: 'assets/images/ui/adult/man_character_hispanic.png', gender: 'Boy', skinTone: 'hispanic'),
  _SproutHeroChoice(assetPath: 'assets/images/ui/adult/man_character_south_asian.png', gender: 'Boy', skinTone: 'south_asian'),
  _SproutHeroChoice(assetPath: 'assets/images/ui/adult/woman_character_white.png', gender: 'Girl', skinTone: 'white'),
  _SproutHeroChoice(assetPath: 'assets/images/ui/adult/woman_character_asian.png', gender: 'Girl', skinTone: 'asian'),
  _SproutHeroChoice(assetPath: 'assets/images/ui/adult/woman_character_black.png', gender: 'Girl', skinTone: 'black'),
  _SproutHeroChoice(assetPath: 'assets/images/ui/adult/woman_character_hispanic.png', gender: 'Girl', skinTone: 'hispanic'),
  _SproutHeroChoice(assetPath: 'assets/images/ui/adult/woman_character_south_asian.png', gender: 'Girl', skinTone: 'south_asian'),
];
```

Update `_buildHeroCharacterCarousel()` to include `AgeBand.adolescent` and `AgeBand.adult` in its switch.

### Step 4: Verify

Run `dart analyze lib/` to confirm there are no missing switch cases or compile errors. Fix any issues found.
```

---

## PROMPT 3: Wire Companions Per Band

```
You are working on a Flutter/Dart app at C:\dev\story-weaver-app. The companion selector currently shows the same 7 magical companions to all age groups. You need to make it age-band-aware.

PREREQUISITE: The AgeBand enum must already have 6 values (sprout, explorer, adventurer, creator, adolescent, adult). If it doesn't, stop and do that first.

### Read first
Read these files before making changes:
- lib/screens/wizard_steps/companion_selector_step.dart (the whole file)
- lib/theme/age_band_theme.dart (for AgeBand enum)
- lib/models.dart (for Companion model)

### Changes

1. In `companion_selector_step.dart`, replace the `_magicalCompanions` getter with a method that returns different companions per band:

```dart
List<Companion> get _magicalCompanions {
  final ageBand = Theme.of(context).extension<AgeBandThemeData>()?.band ?? AgeBand.explorer;
  return _companionsForBand(ageBand);
}

List<Companion> _companionsForBand(AgeBand band) {
  switch (band) {
    case AgeBand.sprout:
      return [
        Companion(id: 'fluffy_dragon', emoji: '🐉', name: 'Fluffy Dragon',
          color: AppColors.dragonOrange,
          greeting: 'Rawr! Tiny roars and warm hugs!',
          description: '✨ A cuddly dragon who breathes sparkly bubbles',
          imagePath: 'assets/images/companions/sprout/fluffy_dragon.png'),
        Companion(id: 'magic_bunny', emoji: '🐰', name: 'Magic Bunny',
          color: AppColors.primaryLight,
          greeting: 'Hop hop! Let\'s play!',
          description: '✨ Hops so high it touches the clouds',
          imagePath: 'assets/images/companions/sprout/magic_bunny.png'),
        Companion(id: 'shining_puppy', emoji: '🐕', name: 'Shining Puppy',
          color: AppColors.gold,
          greeting: 'Woof! I love you!',
          description: '✨ Glows bright when you need a friend',
          imagePath: 'assets/images/companions/sprout/shining_puppy.png'),
        Companion(id: 'tiny_fairy', emoji: '🧚', name: 'Tiny Fairy',
          color: AppColors.catPurple,
          greeting: 'Sprinkle sprinkle!',
          description: '✨ Leaves a trail of wishing dust everywhere',
          imagePath: 'assets/images/companions/sprout/tiny_fairy.png'),
      ];
    case AgeBand.explorer:
      return [
        Companion(id: 'bloom_sprite', emoji: '🌸', name: 'Bloom Sprite',
          color: AppColors.primaryLight,
          greeting: 'Watch this flower grow!',
          description: '✨ Makes flowers bloom that heal and protect',
          imagePath: 'assets/images/companions/explorer/bloom_sprite.png'),
        Companion(id: 'ember_dragon', emoji: '🐉', name: 'Ember Dragon',
          color: AppColors.dragonOrange,
          greeting: 'My fire reveals hidden things!',
          description: '✨ Breathes rainbow fire that reveals hidden paths',
          imagePath: 'assets/images/companions/explorer/ember_dragon.png'),
        Companion(id: 'moon_owl', emoji: '🦉', name: 'Moon Owl',
          color: AppColors.owlBlue,
          greeting: 'I see what others miss!',
          description: '✨ Can see through time to show what will happen',
          imagePath: 'assets/images/companions/explorer/moon_owl.png'),
        Companion(id: 'star_fox', emoji: '🦊', name: 'Star Fox',
          color: AppColors.gold,
          greeting: 'Follow the starlight!',
          description: '✨ Leaves a trail of starlight that solves puzzles',
          imagePath: 'assets/images/companions/explorer/star_fox.png'),
      ];
    case AgeBand.adventurer:
      return _olderCompanions('adventurer', 'An unbreakable guardian forged in starfire', 'Strikes from the shadows with silent precision', 'Commands the winds of the highest peaks', 'Bends space and reality at will');
    case AgeBand.creator:
      return _olderCompanions('creator', 'Forged in the heart of a dying star, loyal to the end', 'Moves through darkness unseen, strikes without warning', 'Rides the storm itself, untouchable in flight', 'A fragment of the void given form and purpose');
    case AgeBand.adolescent:
      return _olderCompanions('adolescent', 'Ancient, formidable, speaks only truth', 'A predator that hunts between dimensions', 'Faster than thought, sees every battlefield from above', 'Born from nothingness, reshapes reality');
    case AgeBand.adult:
      return _olderCompanions('adult', 'A sentinel of forgotten ages', 'Silent guardian of liminal spaces', 'Sovereign of the tempest', 'Consciousness without form');
  }
}

List<Companion> _olderCompanions(String band, String golemDesc, String lynxDesc, String hawkDesc, String spriteDesc) {
  return [
    Companion(id: 'iron_golem', emoji: '🤖', name: 'Iron Golem',
      color: AppColors.dogBrown,
      greeting: 'I stand ready.',
      description: '✨ $golemDesc',
      imagePath: 'assets/images/companions/$band/iron_golem.png'),
    Companion(id: 'shadow_lynx', emoji: '🐱', name: 'Shadow Lynx',
      color: AppColors.catPurple,
      greeting: 'Stay close. Stay quiet.',
      description: '✨ $lynxDesc',
      imagePath: 'assets/images/companions/$band/shadow_lynx.png'),
    Companion(id: 'storm_hawk', emoji: '🦅', name: 'Storm Hawk',
      color: AppColors.owlBlue,
      greeting: 'The sky answers to me.',
      description: '✨ $hawkDesc',
      imagePath: 'assets/images/companions/$band/storm_hawk.png'),
    Companion(id: 'void_sprite', emoji: '✨', name: 'Void Sprite',
      color: AppColors.primaryLight,
      greeting: 'Between the stars, I wait.',
      description: '✨ $spriteDesc',
      imagePath: 'assets/images/companions/$band/void_sprite.png'),
  ];
}
```

2. Make sure custom pet companions and saved character companions still work (they should — they prepend to the list).

3. You need to import `AgeBandThemeData` at the top if not already imported.

4. Run `dart analyze` on the file to verify no errors.
```

---

## PROMPT 4: Wire Feelings Per Band

```
You are working on a Flutter/Dart app at C:\dev\story-weaver-app. The feelings system currently shows the same emotions and art to all age groups. You need to make it age-band-aware with appropriate vocabulary depth and band-specific images.

PREREQUISITE: The AgeBand enum must already have 6 values.

### Read first
- lib/feelings_wheel_data.dart
- lib/widgets/feelings_cloud_picker.dart
- lib/screens/wizard_steps/feeling_selection_step.dart
- lib/theme/age_band_theme.dart

### Design

Each band sees a different number of feelings, appropriate to their developmental stage:

**Sprout (2-5):** 6 simple feelings only — no drill-down
  happy, sad, angry, scared, surprised, calm

**Explorer (6-8):** 6 starter feelings, each with "more like..." sub-feelings
  angry → [grumpy, irritated, furious, hurt-mad]
  worried → [nervous, shaky, jumpy, scared]
  sad → [lonely, disappointed, left-out, gloomy]
  frustrated → [stuck, overwhelmed, impatient]
  embarrassed → [awkward, red-faced, wish-I-could-hide]
  excited → [bouncy, hyper, proud, can't-wait]

**Adventurer (9-11):** All Explorer feelings plus:
  jealous, guilty, confused, bored, lonely, nervous, proud, disappointed, hopeful, content

**Creator (12-14):** All Adventurer feelings plus:
  resentful, insecure, overwhelmed, anxious, numb, vulnerable, conflicted, grateful, inspired, pressured, inadequate, relieved

**Adolescent (15-17):** ~50 feelings (all Creator plus nuanced variants)

**Adult (18+):** Full wheel — all ~140 feelings available

### Changes

1. **In `lib/feelings_wheel_data.dart`**, add a function:
```dart
import '../theme/age_band_theme.dart';

/// Returns the feeling IDs appropriate for the given age band.
/// Younger bands see fewer, simpler emotions.
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
      return []; // empty = show all available feelings (no filter)
  }
}
```

2. **In `lib/widgets/feelings_cloud_picker.dart`**, update the image loading to try band-specific images first:

Find where it loads `assets/feelings_faces/${id}.png` and change it to:
```dart
String _feelingImagePath(String id, AgeBand band) {
  // Band-specific images exist for 8 core feelings
  return 'assets/images/feelings/${band.name}/$id.png';
}

String _fallbackFeelingImagePath(String id) {
  return 'assets/feelings_faces/$id.png';
}
```

Then in the Image widget, use an errorBuilder to fall back:
```dart
Image.asset(
  _feelingImagePath(widget.id, currentBand),
  errorBuilder: (context, error, stackTrace) {
    return Image.asset(
      _fallbackFeelingImagePath(widget.id),
      errorBuilder: (context, error, stackTrace) {
        // Final fallback: show emoji text
        return Text(widget.emoji, style: TextStyle(fontSize: 32));
      },
    );
  },
)
```

3. **In `lib/screens/wizard_steps/feeling_selection_step.dart`**, for Sprout band, simplify the UI:
- If band is sprout, show just 6 big feeling tiles in a 2x3 grid
- No sub-feelings drill-down
- No "more like..." options
- Tapping one feeling = done, auto-advance

4. Run `dart analyze` to verify no errors.
```

---

## PROMPT 5: Wire Archetypes Per Band

```
You are working on a Flutter/Dart app at C:\dev\story-weaver-app. The archetype system currently uses one set of images and names. You need to make it age-band-aware.

PREREQUISITE: The AgeBand enum must already have 6 values.

### Read first
- lib/widgets/archetype_card.dart (the whole file, especially the defaultArchetypes list)
- lib/theme/age_band_theme.dart

### Current state
The `defaultArchetypes` list at the bottom of archetype_card.dart has 6 archetypes with sprout-style names (storm_rider, quiz_whiz, etc.) and images from `assets/images/archetypes/`.

### Changes

1. Make `defaultArchetypes` a function that takes `AgeBand`:

```dart
List<ArchetypeCard> defaultArchetypesForBand(AgeBand band) {
  final bandName = band.name; // 'sprout', 'explorer', etc.

  if (band == AgeBand.sprout) {
    return [
      ArchetypeCard(
        imagePath: 'assets/images/archetypes/sprout/storm_rider.jpg',
        name: 'Storm Rider',
        description: 'Brave and bold, charges into any adventure',
        specialAbility: 'Super speed!',
        traits: ['Brave', 'Fast', 'Bold'],
        onUseTemplate: () {},
      ),
      ArchetypeCard(
        imagePath: 'assets/images/archetypes/sprout/quiz_whiz.jpg',
        name: 'Quiz Whiz',
        description: 'Smart and curious, solves every puzzle',
        specialAbility: 'Super brain!',
        traits: ['Smart', 'Curious', 'Quick'],
        onUseTemplate: () {},
      ),
      ArchetypeCard(
        imagePath: 'assets/images/archetypes/sprout/master_creator.jpg',
        name: 'Master Creator',
        description: 'Builds amazing things from imagination',
        specialAbility: 'Magic building!',
        traits: ['Creative', 'Inventive', 'Imaginative'],
        onUseTemplate: () {},
      ),
      ArchetypeCard(
        imagePath: 'assets/images/archetypes/sprout/heart_healer.jpg',
        name: 'Heart Healer',
        description: 'Makes everyone feel better with kindness',
        specialAbility: 'Healing hugs!',
        traits: ['Kind', 'Gentle', 'Caring'],
        onUseTemplate: () {},
      ),
      ArchetypeCard(
        imagePath: 'assets/images/archetypes/sprout/lightning_runner.jpg',
        name: 'Lightning Runner',
        description: 'The fastest hero in all the land',
        specialAbility: 'Lightning speed!',
        traits: ['Fast', 'Energetic', 'Unstoppable'],
        onUseTemplate: () {},
      ),
      ArchetypeCard(
        imagePath: 'assets/images/archetypes/sprout/animal_whisperer.jpg',
        name: 'Animal Whisperer',
        description: 'Talks to animals and makes forest friends',
        specialAbility: 'Animal chat!',
        traits: ['Gentle', 'Nature-loving', 'Empathetic'],
        onUseTemplate: () {},
      ),
    ];
  }

  // All other bands use universal archetype names with band-specific art
  return [
    ArchetypeCard(
      imagePath: 'assets/images/archetypes/$bandName/brave_hero.jpg',
      name: 'Brave Hero',
      description: band == AgeBand.explorer
          ? 'Charges into adventure with a fearless heart'
          : 'Courage defines them — first into danger, last to retreat',
      specialAbility: 'Fearless courage',
      traits: ['Brave', 'Determined', 'Protective'],
      onUseTemplate: () {},
    ),
    ArchetypeCard(
      imagePath: 'assets/images/archetypes/$bandName/clever_inventor.jpg',
      name: 'Clever Inventor',
      description: band == AgeBand.explorer
          ? 'Builds amazing gadgets to solve any problem'
          : 'Solves the unsolvable with ingenuity and precision',
      specialAbility: 'Brilliant invention',
      traits: ['Smart', 'Inventive', 'Resourceful'],
      onUseTemplate: () {},
    ),
    ArchetypeCard(
      imagePath: 'assets/images/archetypes/$bandName/gentle_dreamer.jpg',
      name: 'Gentle Dreamer',
      description: band == AgeBand.explorer
          ? 'Sees beautiful possibilities others miss'
          : 'Quiet vision that reshapes reality',
      specialAbility: 'Dream vision',
      traits: ['Imaginative', 'Perceptive', 'Calm'],
      onUseTemplate: () {},
    ),
    ArchetypeCard(
      imagePath: 'assets/images/archetypes/$bandName/kind_healer.jpg',
      name: 'Kind Healer',
      description: band == AgeBand.explorer
          ? 'Heals wounds and mends broken hearts'
          : 'Restores what is broken — body, mind, and spirit',
      specialAbility: 'Healing touch',
      traits: ['Kind', 'Empathetic', 'Patient'],
      onUseTemplate: () {},
    ),
    ArchetypeCard(
      imagePath: 'assets/images/archetypes/$bandName/mighty_guardian.jpg',
      name: 'Mighty Guardian',
      description: band == AgeBand.explorer
          ? 'Protects friends with an unbreakable shield'
          : 'An immovable force standing between danger and the innocent',
      specialAbility: 'Unbreakable defence',
      traits: ['Strong', 'Loyal', 'Steadfast'],
      onUseTemplate: () {},
    ),
    ArchetypeCard(
      imagePath: 'assets/images/archetypes/$bandName/speedy_explorer.jpg',
      name: 'Speedy Explorer',
      description: band == AgeBand.explorer
          ? 'Runs faster than the wind and discovers hidden places'
          : 'Speed and precision — always first to act, first to discover',
      specialAbility: 'Lightning speed',
      traits: ['Fast', 'Adventurous', 'Daring'],
      onUseTemplate: () {},
    ),
  ];
}
```

2. Find all places where `defaultArchetypes` is used and pass the current band. You'll need to get the band from context: `Theme.of(context).extension<AgeBandThemeData>()?.band ?? AgeBand.explorer`

3. The `onUseTemplate` callbacks will need to be wired up by the calling code (they can't be set inside this static list). You may need to restructure this as archetype data objects rather than widget instances.

4. Run `dart analyze` to verify.
```

---

## PROMPT 6: Wire Progress Orbs Per Band

```
You are working on a Flutter/Dart app at C:\dev\story-weaver-app. The progress orbs currently use hardcoded "clean" style assets. You need to make them age-band-aware.

PREREQUISITE: The AgeBand enum must already have 6 values.

### Read first
- lib/widgets/image_progress_orb.dart

### Changes

1. Add an optional `AgeBand? band` parameter to `ImageProgressOrb`, or read it from the theme context.

2. Update `_orbAssetPath` to use band-specific orbs:
```dart
String get _orbAssetPath {
  final band = /* read from context or parameter */;
  final bandName = band?.name ?? 'clean';

  final isDoneIcon = widget.icon == Icons.check_rounded ||
      widget.icon == Icons.check ||
      widget.icon == Icons.check_circle;

  if (bandName == 'clean') {
    // Fallback to existing clean orbs
    return isDoneIcon
        ? 'assets/images/ui/clean/progress_done_orb.png'
        : 'assets/images/ui/clean/progress_active_orb.png';
  }

  return isDoneIcon
      ? 'assets/images/orbs/$bandName/progress_done.png'
      : 'assets/images/orbs/$bandName/progress_active.png';
}
```

3. To read band from context in a StatefulWidget, you need to do it in `build()` not in a getter. Restructure if needed.

4. Keep the existing errorBuilder fallback (gradient orb) — it'll catch any missing assets gracefully.

5. Run `dart analyze` to verify.
```

---

## PROMPT 7: Wire Backgrounds Per Band

```
You are working on a Flutter/Dart app at C:\dev\story-weaver-app. You need to add optional background images per age band.

PREREQUISITE: The AgeBand enum must already have 6 values. Assets must already be in `assets/images/backgrounds/{band}/`.

### Read first
- lib/theme/age_band_theme.dart (AgeBandThemeData class)
- lib/screens/welcome_screen.dart (or whatever screen shows the splash/home)
- lib/story_reader_screen.dart or equivalent story display screen

### Changes

1. Add optional background path properties to `AgeBandThemeData`:
```dart
final String? splashBgPath;
final String? storyBgPath;
```

Add them to the constructor with default null values. Update `copyWith` and `lerp` if needed.

2. Set the paths in each band's theme constant:
```dart
// In sproutTheme:
splashBgPath: 'assets/images/backgrounds/sprout/splash_bg.jpg',
storyBgPath: 'assets/images/backgrounds/sprout/story_page_bg.jpg',

// Same pattern for explorer, adventurer, creator, adolescent, adult
```

3. In the welcome/splash screen, if `splashBgPath` is not null, layer the image behind the existing gradient:
```dart
Stack(
  children: [
    if (ageBand.splashBgPath != null)
      Positioned.fill(
        child: Image.asset(ageBand.splashBgPath!, fit: BoxFit.cover),
      ),
    // Semi-transparent gradient overlay for readability
    Positioned.fill(
      child: Container(
        decoration: BoxDecoration(gradient: ageBand.backgroundGradient.copyWith(
          // Make gradient semi-transparent so bg image shows through
        )),
      ),
    ),
    // ... existing content
  ],
)
```

4. Same pattern for story page background.

5. Run `dart analyze` to verify.
```

---

## PROMPT 8: Big Feelings Theme Naming Per Band

```
You are working on a Flutter/Dart app at C:\dev\story-weaver-app. You need to update the "Big Feelings Quest" story theme to have age-appropriate names per band.

PREREQUISITE: The AgeBand enum must already have 6 values.

### Read first
- lib/data/scenario_data.dart (find the big_feelings_quest entry)
- lib/screens/wizard_steps/hero_creator_step.dart (search for big_feelings_quest)

### Current state
The ScenarioCard for big_feelings_quest has:
- title: 'Big Feelings Quest'
- youngTitle: 'Big Feelings' (used for age <=6)
- matureTitle: 'Riding the Storm' (used for age >=10)

The `titleForAge()` method uses simple age thresholds.

### Changes

1. Add more age-variant fields to `ScenarioCard` or change `titleForAge` to be more granular. Simplest approach — update the existing thresholds and add intermediate variants:

Option A (add fields): Add `tweenTitle` and `teenTitle` fields:
```dart
// In ScenarioCard class:
final String? tweenTitle;      // ages 9-11
final String? teenTitle;       // ages 12-14
final String? olderTeenTitle;  // ages 15-17
final String? adultTitle;      // ages 18+

String titleForAge(int age) {
  if (age <= 5 && youngTitle != null) return youngTitle!;
  if (age <= 8) return title; // "Big Feelings Quest"
  if (age <= 11 && tweenTitle != null) return tweenTitle!;
  if (age <= 14 && teenTitle != null) return teenTitle!;
  if (age <= 17 && olderTeenTitle != null) return olderTeenTitle!;
  if (adultTitle != null) return adultTitle!;
  if (age >= 10 && matureTitle != null) return matureTitle!;
  return title;
}
```

2. Set the Big Feelings naming:
```dart
ScenarioCard(
  id: 'big_feelings_quest',
  title: 'Big Feelings Quest',         // Explorer (6-8) default
  youngTitle: 'Big Feelings',           // Sprout (2-5)
  tweenTitle: 'Feeling Quest',          // Adventurer (9-11)
  teenTitle: 'The Inner Map',           // Creator (12-14)
  olderTeenTitle: 'Under the Surface',  // Adolescent (15-17)
  adultTitle: 'Emotional Landscape',    // Adult (18+)
  matureTitle: 'Riding the Storm',      // fallback for >=10
  // ... keep other fields
)
```

3. Do the same for `descriptionForAge`, `conflictHookForAge`, and `worldBibleForAge` if those methods exist — add more age-granular variants.

For descriptions:
- Sprout: "Feelings come and go like the wind. You can be the boss of your clouds!"
- Explorer: "Riding the waves of being worried or mad without getting swept away."
- Adventurer: "When the pressure builds, how do you hold your ground?"
- Creator: "Mapping the terrain of what you feel — and choosing what to do next."
- Adolescent: "The stuff no one talks about. The pressure, the noise, the real you underneath."
- Adult: "Navigating emotional complexity with clarity and self-awareness."

4. Also update hero_creator_step.dart if it has hardcoded "Big Feelings!" text (search for 'big_feelings_quest' in that file).

5. Run `dart analyze` to verify.
```

---

## Summary

| Prompt | Task | Depends on |
|--------|------|-----------|
| 1 | Copy & organize assets | Nothing |
| 2 | Expand AgeBand enum to 6 | Prompt 1 (assets must exist) |
| 3 | Wire companions per band | Prompt 2 |
| 4 | Wire feelings per band | Prompt 2 |
| 5 | Wire archetypes per band | Prompt 2 |
| 6 | Wire progress orbs per band | Prompt 2 |
| 7 | Wire backgrounds per band | Prompt 2 |
| 8 | Big Feelings naming per band | Prompt 2 |

Prompts 3-8 can run in parallel after Prompt 2 is complete.
