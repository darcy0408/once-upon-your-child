# Age Band Expansion Plan: 4 → 6 Bands

## Overview

Expand the Story Weaver app from 4 age bands to 6, making every screen feel age-appropriate — not too babyish for older kids, not too mature for younger ones.

### New Band Structure

| Band | Enum value | Ages | Art style | Asset source |
|------|-----------|------|-----------|-------------|
| Sprout | `sprout` | 2-5 | Soft Pixar 3D, warm sunset | `age_band_assets/sprouts/` |
| Explorer | `explorer` | 6-8 | Whimsical magical purple | `age_band_assets/early_readers/` |
| Adventurer | `adventurer` | 9-11 | Cosmic Chronicle, cool indigo | `age_band_assets/adventurers/` |
| Creator | `creator` | 12-14 | High-fidelity cinematic 3D | `age_band_assets/creators/` |
| Adolescent | `adolescent` | 15-17 | Upper-YA cinematic, moody chiaroscuro | `age_band_assets/adolescents/` + `older_adolescents/` |
| Adult | `adult` | 18+ | Refined fine-art cinematic | `age_band_assets/adults/` |

### Dependencies Between Tasks

```
TASK 1 (Asset cleanup) ──┐
                         ├── TASK 3 (Enum expansion) ── All other tasks depend on this
TASK 2 (Asset fixes)  ──┘
```

Tasks 4-10 can run in parallel after Task 3 is complete.

---

## TASK 1: Copy & Organize Assets

**Goal:** Move age_band_assets into the Flutter `assets/` directory structure.

### Asset mapping

Source → Destination:
```
age_band_assets/sprouts/UI/           → assets/images/ui/sprout/        (already exists, compare & update)
age_band_assets/sprouts/archetypes/   → assets/images/archetypes/sprout/
age_band_assets/sprouts/companions/   → assets/images/companions/sprout/
age_band_assets/sprouts/orbs/         → assets/images/orbs/sprout/
age_band_assets/sprouts/backgrounds/  → assets/images/backgrounds/sprout/
age_band_assets/sprouts/scenes/       → assets/images/scenes/sprout/

age_band_assets/early_readers/ui/          → assets/images/ui/explorer/       (REPLACE existing explorer assets)
age_band_assets/early_readers/archetypes/  → assets/images/archetypes/explorer/
age_band_assets/early_readers/companions/  → assets/images/companions/explorer/
age_band_assets/early_readers/feelings/    → assets/images/feelings/explorer/
age_band_assets/early_readers/orbs/        → assets/images/orbs/explorer/
age_band_assets/early_readers/backgrounds/ → assets/images/backgrounds/explorer/
age_band_assets/early_readers/scenes/      → assets/images/scenes/explorer/

age_band_assets/adventurers/ui/          → assets/images/ui/adventurer/     (REPLACE existing)
age_band_assets/adventurers/archetypes/  → assets/images/archetypes/adventurer/
age_band_assets/adventurers/companions/  → assets/images/companions/adventurer/
age_band_assets/adventurers/feelings/    → assets/images/feelings/adventurer/
age_band_assets/adventurers/orbs/        → assets/images/orbs/adventurer/
age_band_assets/adventurers/backgrounds/ → assets/images/backgrounds/adventurer/
age_band_assets/adventurers/scenes/      → assets/images/scenes/adventurer/

age_band_assets/creators/ui/          → assets/images/ui/creator/        (REPLACE existing)
age_band_assets/creators/archetypes/  → assets/images/archetypes/creator/
age_band_assets/creators/companions/  → assets/images/companions/creator/
age_band_assets/creators/feelings/    → assets/images/feelings/creator/
age_band_assets/creators/orbs/        → assets/images/orbs/creator/
age_band_assets/creators/backgrounds/ → assets/images/backgrounds/creator/
age_band_assets/creators/scenes/      → assets/images/scenes/creator/

age_band_assets/adolescents/ui/          → assets/images/ui/adolescent/      (NEW)
age_band_assets/adolescents/archetypes/  → assets/images/archetypes/adolescent/
age_band_assets/adolescents/companions/  → assets/images/companions/adolescent/
age_band_assets/adolescents/feelings/    → assets/images/feelings/adolescent/
age_band_assets/adolescents/orbs/        → assets/images/orbs/adolescent/
age_band_assets/adolescents/backgrounds/ → assets/images/backgrounds/adolescent/
age_band_assets/adolescents/scenes/      → assets/images/scenes/adolescent/

age_band_assets/adults/ui/          → assets/images/ui/adult/           (NEW)
age_band_assets/adults/archetypes/  → assets/images/archetypes/adult/
age_band_assets/adults/companions/  → assets/images/companions/adult/
age_band_assets/adults/feelings/    → assets/images/feelings/adult/
age_band_assets/adults/orbs/        → assets/images/orbs/adult/
age_band_assets/adults/backgrounds/ → assets/images/backgrounds/adult/
age_band_assets/adults/scenes/      → assets/images/scenes/adult/
```

### pubspec.yaml additions

Add these asset directories:
```yaml
assets:
  # Existing
  - assets/images/ui/
  - assets/images/ui/sprout/
  - assets/images/ui/explorer/
  - assets/images/ui/adventurer/
  - assets/images/ui/creator/
  - assets/images/ui/clean/
  - assets/images/ui/glassy/
  # New bands
  - assets/images/ui/adolescent/
  - assets/images/ui/adult/
  # Companions per band
  - assets/images/companions/
  - assets/images/companions/sprout/
  - assets/images/companions/explorer/
  - assets/images/companions/adventurer/
  - assets/images/companions/creator/
  - assets/images/companions/adolescent/
  - assets/images/companions/adult/
  # Archetypes per band
  - assets/images/archetypes/
  - assets/images/archetypes/sprout/
  - assets/images/archetypes/explorer/
  - assets/images/archetypes/adventurer/
  - assets/images/archetypes/creator/
  - assets/images/archetypes/adolescent/
  - assets/images/archetypes/adult/
  # Feelings per band
  - assets/images/feelings/sprout/
  - assets/images/feelings/explorer/
  - assets/images/feelings/adventurer/
  - assets/images/feelings/creator/
  - assets/images/feelings/adolescent/
  - assets/images/feelings/adult/
  # Orbs per band
  - assets/images/orbs/sprout/
  - assets/images/orbs/explorer/
  - assets/images/orbs/adventurer/
  - assets/images/orbs/creator/
  - assets/images/orbs/adolescent/
  - assets/images/orbs/adult/
  # Backgrounds per band
  - assets/images/backgrounds/sprout/
  - assets/images/backgrounds/explorer/
  - assets/images/backgrounds/adventurer/
  - assets/images/backgrounds/creator/
  - assets/images/backgrounds/adolescent/
  - assets/images/backgrounds/adult/
  # Scenes per band
  - assets/images/scenes/sprout/
  - assets/images/scenes/explorer/
  - assets/images/scenes/adventurer/
  - assets/images/scenes/creator/
  - assets/images/scenes/adolescent/
  - assets/images/scenes/adult/
```

---

## TASK 2: Fix Asset Inconsistencies

**Goal:** Clean up naming and fill gaps before wiring.

### Fixes needed

1. **Sprouts casing:** `age_band_assets/sprouts/UI/` uses uppercase. Rename to lowercase `ui/` before copying.

2. **Missing sprouts feelings:** `age_band_assets/sprouts/` has no `feelings/` subfolder. Need to generate 8 images:
   - happy.png, sad.png, angry.png, scared.png, surprised.png, calm.png, confused.png, excited.png
   - Style: Soft Pixar 3D to match sprout aesthetic — big round faces, warm colors, very simple expressions a 3yo can read

3. **Missing early_readers white variants:** `early_readers/ui/` has boy/girl in asian, black, hispanic, south_asian but no white/default variant. Either:
   - Generate `boy_character_white.png` and `girl_character_white.png` in the early_readers style
   - OR rename the existing un-suffixed variants if they exist

4. **Adolescents missing clicked buttons:** `adolescents/ui/` has `continue_button.png` but no `continue_button_clicked.png`. Need to generate or copy from older_adolescents.

5. **Adult character naming:** Adults use `man_character_*`/`woman_character_*` while all other bands use `boy_character_*`/`girl_character_*` or `hero_*`/`creator_*`. This is actually correct — keep as-is but the Dart code needs to handle the different naming.

6. **Adolescent band merge:** Copy any assets from `older_adolescents/` that `adolescents/` lacks, preferring adolescents style where both exist.

---

## TASK 3: Expand AgeBand Enum to 6 Values

**Goal:** Add `adolescent` and `adult` to the AgeBand enum and update all code that switches on it.

### File: `lib/theme/age_band_theme.dart`

#### 3a. Update enum
```dart
enum AgeBand {
  sprout,      // Ages 2-5
  explorer,    // Ages 6-8
  adventurer,  // Ages 9-11
  creator,     // Ages 12-14
  adolescent,  // Ages 15-17
  adult,       // Ages 18+
}
```

#### 3b. Update `ageBandFromAge()`
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

#### 3c. Add adolescentTheme definition
```dart
const adolescentTheme = AgeBandThemeData(
  band: AgeBand.adolescent,
  // Moody cinematic palette — warm darks, amber/teal accents
  primary: Color(0xFF37474F),        // Blue-grey
  primaryLight: Color(0xFF62727B),    // Light blue-grey
  primaryDark: Color(0xFF263238),     // Dark blue-grey
  gradientStart: Color(0xFF0A0E12),   // Near-black
  gradientMid: Color(0xFF1A2530),     // Dark slate
  gradientEnd: Color(0xFF0F1922),     // Dark navy
  accent: Color(0xFFFFAB40),          // Amber accent
  accentLight: Color(0xFFFFCC80),     // Light amber
  surface: Color(0xFF263238),         // Dark surface
  textOnDark: Color(0xFFECEFF1),      // Light grey
  textOnLight: Color(0xFF263238),     // Dark blue-grey
  // Modern sans-serif
  uiFontFamily: 'SourceSansPro',
  storyFontFamily: 'Merriweather',
  headingScale: 0.9,
  bodyScale: 0.9,
  // Sharp, modern
  buttonRadiusBase: 8.0,
  cardRadiusBase: 10.0,
  touchTargetMin: 52.0,
  spacingScale: 0.88,
  // Very subtle
  sparkleIntensity: 0.0,
  showParticles: false,
  preferDarkMode: true,
  // Direct, real-talk labels
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

#### 3d. Add adultTheme definition
```dart
const adultTheme = AgeBandThemeData(
  band: AgeBand.adult,
  // Refined obsidian/platinum palette
  primary: Color(0xFF5C6BC0),        // Soft indigo
  primaryLight: Color(0xFF8E99A4),    // Platinum
  primaryDark: Color(0xFF3949AB),     // Deep indigo
  gradientStart: Color(0xFF0D0D12),   // Obsidian black
  gradientMid: Color(0xFF1A1A24),     // Dark charcoal
  gradientEnd: Color(0xFF12121C),     // Near-black purple
  accent: Color(0xFFCFD8DC),          // Platinum accent
  accentLight: Color(0xFFECEFF1),     // Light grey
  surface: Color(0xFF1E1E28),         // Dark surface
  textOnDark: Color(0xFFE0E0E0),      // Light grey
  textOnLight: Color(0xFF212121),     // Near-black
  // Clean editorial
  uiFontFamily: 'SourceSansPro',
  storyFontFamily: 'Merriweather',
  headingScale: 0.88,
  bodyScale: 0.88,
  // Minimal, editorial
  buttonRadiusBase: 6.0,
  cardRadiusBase: 8.0,
  touchTargetMin: 48.0,
  spacingScale: 0.85,
  // No decoration
  sparkleIntensity: 0.0,
  showParticles: false,
  preferDarkMode: true,
  // Adult labels
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

#### 3e. Update `themeForBand()`
Add cases for `AgeBand.adolescent` and `AgeBand.adult`.

#### 3f. Find and update ALL switch statements on AgeBand

Search the entire `lib/` directory for any `switch` on `AgeBand` or `case AgeBand.` or `== AgeBand.` and add the two new cases. Key files include:
- `lib/widgets/image_make_magic_button.dart`
- `lib/widgets/image_continue_button.dart`
- `lib/screens/wizard_steps/hero_creator_step.dart`
- `lib/providers/age_band_provider.dart`
- `lib/main_story.dart`
- `lib/theme/app_theme.dart`
- Any other file matching `AgeBand`

For buttons and UI, the `adolescent` and `adult` cases should point to their respective asset folders:
- `assets/images/ui/adolescent/...`
- `assets/images/ui/adult/...`

---

## TASK 4: Wire Companions Per Band

**Goal:** Replace the single hardcoded companion list with age-appropriate companions.

### Current state
- `lib/screens/wizard_steps/companion_selector_step.dart` lines 76-141 has a single `_magicalCompanions` list with 7 generic companions (dragon, owl, cat, dog, unicorn, fox, robin)
- All companions use `assets/images/companions/{animal}.jpg`
- Same companions shown to every age

### New companion sets per band

```dart
// Sprout companions — soft, cuddly, simple names
sprout: [
  {id: 'fluffy_dragon', name: 'Fluffy Dragon', image: 'assets/images/companions/sprout/fluffy_dragon.png'},
  {id: 'magic_bunny', name: 'Magic Bunny', image: 'assets/images/companions/sprout/magic_bunny.png'},
  {id: 'shining_puppy', name: 'Shining Puppy', image: 'assets/images/companions/sprout/shining_puppy.png'},
  {id: 'tiny_fairy', name: 'Tiny Fairy', image: 'assets/images/companions/sprout/tiny_fairy.png'},
]

// Explorer companions — whimsical, magical creatures
explorer: [
  {id: 'bloom_sprite', name: 'Bloom Sprite', image: 'assets/images/companions/explorer/bloom_sprite.png'},
  {id: 'ember_dragon', name: 'Ember Dragon', image: 'assets/images/companions/explorer/ember_dragon.png'},
  {id: 'moon_owl', name: 'Moon Owl', image: 'assets/images/companions/explorer/moon_owl.png'},
  {id: 'star_fox', name: 'Star Fox', image: 'assets/images/companions/explorer/star_fox.png'},
]

// Adventurer companions — bolder, more powerful
adventurer: [
  {id: 'iron_golem', name: 'Iron Golem', image: 'assets/images/companions/adventurer/iron_golem.png'},
  {id: 'shadow_lynx', name: 'Shadow Lynx', image: 'assets/images/companions/adventurer/shadow_lynx.png'},
  {id: 'storm_hawk', name: 'Storm Hawk', image: 'assets/images/companions/adventurer/storm_hawk.png'},
  {id: 'void_sprite', name: 'Void Sprite', image: 'assets/images/companions/adventurer/void_sprite.png'},
]

// Creator companions — same 4, cinematic style
creator: same IDs as adventurer, path: 'assets/images/companions/creator/...'

// Adolescent companions — same 4, moody mythic style
adolescent: same IDs as adventurer, path: 'assets/images/companions/adolescent/...'

// Adult companions — same 4, refined fine-art style
adult: same IDs as adventurer, path: 'assets/images/companions/adult/...'
```

### Changes to make

1. In `companion_selector_step.dart`, replace the `_magicalCompanions` getter with a method that reads the current `AgeBand` from the theme context and returns the appropriate list.

2. Update companion descriptions to match age tone:
   - Sprout: "Fluffy Dragon loves warm hugs and tiny roars!"
   - Explorer: "Ember Dragon breathes rainbow fire that reveals hidden paths"
   - Adventurer: "Iron Golem — an unbreakable guardian forged in starfire"
   - Creator: "Iron Golem — forged in the heart of a dying star, loyal to the end"
   - Adolescent: "Iron Golem — ancient, formidable, speaks only in truth"
   - Adult: "Iron Golem — a sentinel of forgotten ages"

3. Keep custom pet companions working (they bypass the default list).

4. Keep saved character companions working (they also bypass the default list).

---

## TASK 5: Wire Feelings Per Band

**Goal:** Make the feelings experience age-appropriate — younger kids see fewer, simpler emotions with band-specific art; older kids/adults see the full wheel.

### Feelings vocabulary tiers

```
Sprout (2-5): 6 core feelings
  happy, sad, angry, scared, surprised, calm
  → Big, simple tiles. Tap one = done. No sub-feelings.
  → Use band-specific images: assets/images/feelings/sprout/{feeling}.png

Explorer (6-8): 6 starter feelings + "more like..." sub-feelings
  angry → [grumpy, irritated, furious, hurt-mad, left-out mad]
  worried → [nervous, shaky, jumpy, scared, what-if-y]
  sad → [lonely, disappointed, left out, gloomy, teary]
  frustrated → [stuck, overwhelmed, impatient, trying-so-hard]
  embarrassed → [awkward, red-faced, wish-I-could-hide]
  excited → [bouncy, hyper, proud, can't-wait]
  → Band-specific images for 6 starters, generic feelings_faces for sub-feelings
  → Already defined in big-feelings-theme-spec-ages-6-8.md

Adventurer (9-11): ~20 feelings
  All Explorer feelings plus: jealous, guilty, confused, bored,
  lonely, nervous, proud, disappointed, hopeful, content
  → Band-specific images for 8 core, generic for expanded

Creator (12-14): ~35 feelings
  All Adventurer feelings plus: resentful, insecure, overwhelmed,
  anxious, numb, vulnerable, conflicted, grateful, inspired,
  pressured, inadequate, empowered, ambivalent, defensive, relieved
  → Band-specific images for 8 core, generic for expanded

Adolescent (15-17): Full wheel (~50+ feelings)
  All Creator feelings plus nuanced variants
  → Band-specific images for 8 core, generic for expanded

Adult (18+): Full wheel (~140 feelings)
  Everything available
  → Band-specific images for 8 core, generic for expanded
```

### Changes to make

1. **`lib/feelings_wheel_data.dart`** — Add a function `feelingsForBand(AgeBand band)` that returns the appropriate vocabulary tier.

2. **`lib/widgets/feelings_cloud_picker.dart`** — Update to:
   - Read current AgeBand from theme context
   - Load band-appropriate feeling list
   - Try band-specific image first: `assets/images/feelings/{band}/{feeling_id}.png`
   - Fall back to generic: `assets/feelings_faces/{feeling_id}.png`

3. **`lib/screens/wizard_steps/feeling_selection_step.dart`** — For Sprout band, simplify the UI to just 6 big tiles (no sub-feelings, no "more like..." drill-down).

4. **Band-specific feeling images** (8 per band) should be loaded from:
   `assets/images/feelings/{band}/{feeling}.png`
   where feeling is: happy, sad, angry, scared, surprised, calm, confused, excited

---

## TASK 6: Wire Archetypes Per Band

**Goal:** Show age-appropriate archetype images and names.

### Current state
- `lib/widgets/archetype_card.dart` lines 225-325 define 6 archetypes with sprout-style names
- Images point to `assets/images/archetypes/{name}_framed.png`

### New archetype mapping

```
Sprout: storm_rider, quiz_whiz, master_creator, heart_healer, lightning_runner, animal_whisperer
  → assets/images/archetypes/sprout/{name}.jpg

All other bands: brave_hero, clever_inventor, gentle_dreamer, kind_healer, mighty_guardian, speedy_explorer
  → assets/images/archetypes/{band}/{name}.jpg
```

### Changes to make

1. Make the `defaultArchetypes` list in `archetype_card.dart` band-aware.
2. Sprout keeps current names/traits (kid-friendly: "Storm Rider", "Quiz Whiz").
3. Explorer+ use the more universal names ("Brave Hero", "Clever Inventor").
4. Update `imagePath` to include band subfolder.
5. Adjust trait descriptions per band:
   - Sprout: "Loves to run super fast!"
   - Explorer: "Runs faster than the wind and never gives up"
   - Adventurer: "Swiftest in the realm, outruns any danger"
   - Creator+: "Speed and precision — always first to act"

---

## TASK 7: Wire Progress Orbs Per Band

**Goal:** Replace hardcoded clean/purple orbs with band-specific orbs.

### Current state
- `lib/widgets/image_progress_orb.dart` hardcodes `assets/images/ui/clean/progress_done_orb.png` and `progress_active_orb.png`

### Changes to make

1. Add `AgeBand` parameter to `ImageProgressOrb` (or read from theme context).
2. Build asset path dynamically: `assets/images/orbs/{band}/progress_{state}.png`
3. States: `active`, `done`, `idle` (idle is new — not currently used but assets exist)
4. Keep the gradient/glow fallback in errorBuilder.

---

## TASK 8: Wire Backgrounds Per Band

**Goal:** Add age-appropriate background images behind gradient overlays.

### Available backgrounds per band
- `splash_bg.jpg` — for the splash/welcome screen
- `story_page_bg.jpg` — for the story reader
- `feelings_bg.jpg` — (sprouts only) for feelings screens

### Changes to make

1. Add optional `splashBgPath` and `storyBgPath` properties to `AgeBandThemeData`.
2. Set paths per band: `assets/images/backgrounds/{band}/splash_bg.jpg` etc.
3. Update splash/welcome screen to layer the image behind the existing gradient.
4. Update story reader to use story_page_bg as a background.
5. Use a semi-transparent gradient overlay on top so text remains readable.

---

## TASK 9: Wire Scenes Per Band

**Goal:** Show age-appropriate scene/setting options in the story wizard.

### Available scenes

Early readers (sprout + explorer): cloud_castle, enchanted_forest, ocean_depths, star_village
Older bands (adventurer through adult): deep_archive, orbital_station, ruined_citadel, tidal_shrine

### Changes to make

1. If scenes are used as settings in the wizard, make them band-aware.
2. This may overlap with existing `ScenarioData` which already has `youngWorldBible` / `matureWorldBible`.
3. Lower priority — the scenario system already adapts text by age; images are secondary.

---

## TASK 10: Big Feelings Theme Naming & UX Per Band

**Goal:** Adapt the Big Feelings story theme name and experience for each age band.

### Name per band

Update `scenario_data.dart` Big Feelings entry with more granular age variants:

```dart
// Current age thresholds use <=6 and >=10
// Expand to band-aware naming:
// Sprout (2-5): "Big Feelings"
// Explorer (6-8): "Big Feelings Quest"  (current default)
// Adventurer (9-11): "Feeling Quest"
// Creator (12-14): "The Inner Map"
// Adolescent (15-17): "Under the Surface"
// Adult (18+): "Emotional Landscape"
```

### UX differences per band for feelings stories

**Sprout:**
- 6 simple feeling tiles (no drill-down)
- Feelings = weather metaphors (volcano, rain, fog)
- 2 choices per decision point
- Very short stories

**Explorer:**
- 6 starter feelings with "more like..." expansion
- Feelings = playful story metaphors (fizzing, stomping, wobbling)
- 3 choices per decision point
- Calming tools: dragon breaths, stomp-and-stop
- Repair framed as brave

**Adventurer:**
- ~20 feelings available
- Social dynamics: friend pressure, performance stress
- 3 choices with believable social consequences
- Calming = "regaining choice"
- Repair = brave and not tidy

**Creator:**
- ~35 feelings, more nuanced
- Identity pressure, self-consciousness
- 3 choices with complex social fallout
- No moralizing, teen has agency
- Repair = credible and self-directed

**Adolescent:**
- 50+ feelings
- Friend-group dynamics, digital life, romance
- 3 choices with real-world nuance
- Non-preachy, respects intelligence
- Adults may help but teen retains agency

**Adult:**
- Full 140 feeling wheel
- Real-world emotional complexity
- Evidence-based coping naturally woven in
- No hand-holding
- Equanimity as goal, not happiness

---

## TASK 11: Wire UI Buttons & Characters for New Bands

**Goal:** Add button and character assets for adolescent and adult bands.

### Changes to make

1. **`lib/widgets/image_make_magic_button.dart`** — Add cases:
   ```dart
   case AgeBand.adolescent:
     return 'assets/images/ui/adolescent/make_magic_normal.png';
   case AgeBand.adult:
     return 'assets/images/ui/adult/make_magic_normal.png';
   ```
   Same for clicked/pressed states.

2. **`lib/widgets/image_continue_button.dart`** — Same pattern.

3. **`lib/screens/wizard_steps/hero_creator_step.dart`** — Add character choice lists:
   ```dart
   // _adolescentHeroChoices — boy/girl + 5 skin tones each
   // Use: assets/images/ui/adolescent/boy_character_{skin_tone}.png
   //      assets/images/ui/adolescent/girl_character_{skin_tone}.png

   // _adultHeroChoices — man/woman + 5 skin tones each
   // Use: assets/images/ui/adult/man_character_{skin_tone}.png
   //      assets/images/ui/adult/woman_character_{skin_tone}.png
   ```

4. Update `_buildHeroCharacterCarousel()` to include the two new bands in its switch.

---

## TASK 12: Generate Missing Assets

**Goal:** Fill gaps identified in Task 2.

### Images to generate

1. **Sprout feelings (8 images)**
   - Style: Soft Pixar 3D, warm colors, big round simple faces, transparent PNG, 512x512
   - Emotions: happy, sad, angry, scared, surprised, calm, confused, excited
   - Think: emoji-like but 3D rendered, a toddler should instantly recognize the emotion

2. **Early reader white character variants (2 images)**
   - Style: Match existing early_readers characters — whimsical magical style
   - `boy_character_white.png` and `girl_character_white.png`
   - Same pose/composition as the other skin tone variants

3. **Adolescent clicked buttons (2 images)**
   - `continue_button_clicked.png` — darker/pressed version of continue_button.png
   - `make_magic_normal_clicked.png` — darker/pressed version of make_magic_normal.png
   - Style: Match adolescent moody cinematic aesthetic

4. **App logo variants (5 images)** — if needed
   - Currently only sprouts has app_logo.png
   - May want band-specific logo treatments

---

## Summary Checklist

- [ ] Task 1: Copy & organize assets into `assets/` structure
- [ ] Task 2: Fix naming inconsistencies (casing, missing files)
- [ ] Task 3: Expand AgeBand enum to 6 values + themes + all switches
- [ ] Task 4: Wire companions per band
- [ ] Task 5: Wire feelings per band (vocabulary tiers + images)
- [ ] Task 6: Wire archetypes per band
- [ ] Task 7: Wire progress orbs per band
- [ ] Task 8: Wire backgrounds per band
- [ ] Task 9: Wire scenes per band
- [ ] Task 10: Big Feelings naming & UX per band
- [ ] Task 11: Wire UI buttons & characters for new bands
- [ ] Task 12: Generate missing assets
