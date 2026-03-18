# Story Weaver — Antigravity Agent Context

Paste this entire file into Antigravity at the start of a session to give it full project context.

---

## What This App Is

**Story Weaver** is a Flutter/Dart mobile app (iOS + Android) that generates personalized AI stories for children aged 3–18+. It connects to a Python/Flask backend that calls Google Gemini to generate story text and illustrations.

Key flows:
- **Story Wizard** — multi-step wizard where user picks a character, companion, feelings/theme, then generates a story with illustrations
- **Bedtime mode** — audio-only story with age question and BYOK (Bring Your Own Key) setup
- **Big Feelings flow** — therapeutic stories for emotional processing
- **Pick-a-Path** — interactive branching story
- **Coloring book** — generates printable coloring pages from story illustrations

---

## Age Band System (CRITICAL — affects all UI)

The app adapts its entire visual language based on 6 age bands:

| Band | Ages | Personality |
|------|------|-------------|
| `sprout` | 3–4 | Magical, soft, gentle — large touch targets, pastel colors, simple language |
| `explorer` | 5–7 | Bright, playful, adventurous — bold colors, friendly characters |
| `adventurer` | 8–10 | Exciting, dynamic — more detail, moderate complexity |
| `creator` | 11–13 | Creative, expressive — cool tones, modern feel |
| `adolescent` | 14–17 | Sophisticated, cinematic — dark/moody allowed, adult themes lite |
| `adult` | 18+ | Full adult aesthetic, no child-safety restrictions |

**The theme system lives in:** `lib/theme/age_band_theme.dart`
**Used everywhere via:** `AgeBandTheme.of(context)` or `AgeBandThemeData`

---

## Tech Stack

- **Flutter** 3.x, Dart, **Riverpod** state management, **Isar** local DB
- **Backend**: Python 3.11, Flask, SQLAlchemy, Google Gemini (`gemini-2.5-flash`), Celery for async tasks
- **Backend URL**: `Environment.backendUrl` from `lib/config/environment.dart`
- **Assets**: Age-band-specific image assets in `age_band_assets/<band>/ui/`

---

## Key File Map

### Screens
```
lib/screens/wizard_story_screen.dart         — wizard container
lib/screens/wizard_steps/
  companion_selector_step.dart               — step 1: pick companion
  hero_creator_step.dart                     — step 2: create hero
  feeling_selection_step.dart                — step 3: pick feelings
  magic_review_step.dart                     — step 4: launch story
lib/screens/bedtime_wizard_screen.dart       — bedtime flow
lib/screens/big_feelings_flow_screen.dart    — therapeutic flow
lib/story_result_screen.dart                 — story display + illustrations
lib/screens/parent_controls_screen.dart      — parent settings
lib/screens/byok_setup_wizard.dart           — BYOK Gemini key setup
lib/settings_screen.dart                     — user preferences
lib/subscription_screen.dart                 — premium upsell
lib/custom_avatar_screen.dart                — AI avatar generation
```

### Widgets
```
lib/widgets/app_bottom_navigation.dart       — age-band-aware bottom nav
lib/widgets/archetype_card.dart              — character type card
lib/widgets/image_make_magic_button.dart     — primary CTA button (image-based)
lib/widgets/image_continue_button.dart       — continue button (image-based)
lib/widgets/image_progress_orb.dart          — animated progress orb
lib/widgets/make_magic_button.dart           — programmatic CTA button
lib/widgets/magic_orb.dart                   — particle orb animation
lib/widgets/magical_typewriter_text.dart     — typing text animation
lib/widgets/feelings_cloud_picker.dart       — feelings selection UI
lib/widgets/mood_lantern_selector.dart       — mood lantern picker
```

### Theme & Styling
```
lib/theme/age_band_theme.dart                — ALL age-band theming (6 bands)
lib/theme/app_theme.dart                     — base Material theme
```

### Models & Data
```
lib/models/wizard_data.dart                  — story wizard form data
lib/data/scenario_data.dart                  — story scenarios/themes
lib/data/companion_data.dart                 — companion definitions
lib/avatar_models.dart                       — CharacterAvatar, EnhancedCharacter
lib/services/api_service_manager.dart        — backend API calls
```

---

## Current State of the Codebase

### What's working
- Story generation pipeline (wizard → backend → Gemini → result screen)
- Custom AI avatar generation
- Age-band theming for sprout, explorer, adventurer, creator, adolescent, adult
- Bedtime wizard with audio-only mode
- Big Feelings therapeutic flow with parent hidden context
- Backend auth, rate limiting, Sentry monitoring

### Active work (files with uncommitted changes)
- `lib/custom_avatar_screen.dart` — avatar UI updates
- `lib/data/scenario_data.dart` — scenario content updates
- `lib/models/wizard_data.dart` — wizard model changes
- `lib/screens/wizard_steps/companion_selector_step.dart` — companion UI
- `lib/screens/wizard_steps/hero_creator_step.dart` — hero creator UI
- `lib/screens/wizard_steps/magic_review_step.dart` — review step + illustration entitlement fix
- `lib/story_result_screen.dart` — story display changes
- `lib/theme/age_band_theme.dart` — theme updates for 6-band expansion
- `lib/widgets/app_bottom_navigation.dart` — nav updates
- `lib/widgets/archetype_card.dart` — card UI
- `lib/widgets/image_continue_button.dart` — button updates
- `lib/widgets/image_make_magic_button.dart` — button updates
- `lib/widgets/image_progress_orb.dart` — orb updates

---

## UI Tasks for This Session

Below are the specific tasks to work through. Each is self-contained.

---

### TASK 1 — Age Band Visual Audit (Sprout & Explorer)

**Goal:** Verify the `sprout` (3–4) and `explorer` (5–7) age bands render correctly with age-appropriate styling.

**Files to check:**
- `lib/theme/age_band_theme.dart` — confirm colors, font sizes, touch targets for these bands
- `lib/widgets/app_bottom_navigation.dart` — verify nav icons and labels adapt per band
- `lib/screens/wizard_steps/hero_creator_step.dart` — confirm sprout/explorer get simplified UI
- `lib/screens/wizard_steps/companion_selector_step.dart` — confirm companion cards scale for young users

**What correct looks like:**
- Sprout: large rounded buttons (min 60px), soft pastel palette, 2–3 word labels max, no small text
- Explorer: bright primary colors, friendly rounded shapes, up to 5-word labels

**Ask:** Read each file, describe what you see, flag anything that doesn't match the spec above, and suggest fixes.

---

### TASK 2 — Bottom Navigation Consistency

**Goal:** Ensure `app_bottom_navigation.dart` correctly applies different icons/labels/styles for each of the 6 age bands.

**File:** `lib/widgets/app_bottom_navigation.dart`

**Ask:** Read the file. Map out what each age band gets (icons, labels, colors, tab count). Flag any band that falls through to a default or shares styling with another band when it shouldn't.

---

### TASK 3 — Magic Review Step Polish

**Goal:** The final wizard step (`magic_review_step.dart`) is where the user launches story generation. It should feel exciting and age-appropriate.

**File:** `lib/screens/wizard_steps/magic_review_step.dart`

**Ask:**
1. Read the file.
2. Identify where age band theming is (or isn't) applied.
3. Flag any hardcoded colors, font sizes, or spacing that should be driven by `AgeBandTheme`.
4. Check that the "Make Magic" button uses `ImageMakeMagicButton` or `MakeMagicButton` and not a plain `ElevatedButton`.
5. Confirm illustration count logic: `free`/`premium` = 1 image, `family` = 2 images.

---

### TASK 4 — Story Result Screen Age Adaptation

**Goal:** `story_result_screen.dart` shows the finished story. Verify it adapts layout/typography to age band.

**File:** `lib/story_result_screen.dart`

**Ask:**
1. Read the file.
2. Find where typography is set — is font size driven by `AgeBandTheme` or hardcoded?
3. Check if the coloring book export button is hidden for sprout/explorer (they don't do coloring books) or shown for all.
4. Check the share/save button visibility — should be present for all bands.
5. Flag anything hardcoded that should adapt.

---

### TASK 5 — Archetype Card Styling

**Goal:** `archetype_card.dart` is used in the hero creator step. Cards should be visually distinct per age band.

**File:** `lib/widgets/archetype_card.dart`

**Ask:**
1. Read the file.
2. Check if card size, font, corner radius, and color adapt to the current age band.
3. For sprout/explorer, cards should be large with an icon-first layout. For adolescent/adult, more compact text-forward layout is appropriate.
4. Suggest any changes needed.

---

### TASK 6 — Companion Selector Step

**Goal:** The companion selector shows companion characters the child can add to their story.

**File:** `lib/screens/wizard_steps/companion_selector_step.dart`

**Ask:**
1. Read the file.
2. Check if companion data is loaded from `lib/data/companion_data.dart` and filtered by age band.
3. Verify the grid layout uses age-appropriate card sizes.
4. Flag any missing age-band filtering (e.g., adult-only companions appearing in sprout band).

---

### TASK 7 — Image Button Asset Audit

**Goal:** The image-based buttons (`image_make_magic_button.dart`, `image_continue_button.dart`, `image_progress_orb.dart`) load PNG assets from `age_band_assets/`. Verify all 6 bands have valid asset paths.

**Files:**
- `lib/widgets/image_make_magic_button.dart`
- `lib/widgets/image_continue_button.dart`
- `lib/widgets/image_progress_orb.dart`

**Asset directories to cross-reference:**
```
age_band_assets/sprouts/ui/
age_band_assets/early_readers/ui/     ← maps to explorer band
age_band_assets/adventurers/ui/       ← maps to adventurer band
age_band_assets/creators/ui/          ← maps to creator band
age_band_assets/adolescents/ui/
age_band_assets/adults/ui/
```

**Ask:** Read all three widget files. For each widget, list which asset paths it tries to load per band. Then check if those files actually exist in the asset directories. Report any missing assets.

---

## Rules for This Session

- Always read a file before suggesting changes to it.
- Dart uses camelCase for method names — never snake_case.
- Always add `mounted` checks before `setState()` or `ScaffoldMessenger` calls after any `await`.
- Do not add comments or docstrings to code you didn't change.
- The age band system is the source of truth for all visual decisions — prefer `AgeBandTheme.of(context)` over hardcoded values.
- Keep changes minimal — fix what's broken, don't refactor what isn't.

---

## How to Run the App

```bash
# Terminal 1 — backend
cd C:\dev\story-weaver-app\backend
python app.py

# Terminal 2 — Flutter (Android emulator)
cd C:\dev\story-weaver-app
flutter run -d emulator-5554

# Or Flutter (Chrome for quick UI checks)
flutter run -d chrome --web-port 8080
```

Health check: `curl http://127.0.0.1:5000/health`
