# Guided Meditation Feature — v2 Implementation Plan

**Status:** Planned for v2 — do not build in current release
**Created:** 2026-03-15

## Context

Story Weaver currently has 12 story scenarios, 4 story modes (Standard, Rhyme Time, Learning to Read, Interactive), and a Big Feelings therapeutic theme. The app already narrates all stories via ElevenLabs TTS and has ambient audio infrastructure.

The meditation feature should feel native to the app, not bolted on. It reuses the wizard architecture, TTS pipeline, age-band system, and ambient audio — no parallel system needed.

---

## Two Entry Points

### 1. Scenario Carousel Path (Full Wizard)
User picks "Guided Meditation" from the scenario cards → goes through character creation → companions → review → generates a personalized meditation featuring their character in a calming environment. Can include illustrations.

### 2. Quick Meditation Path (Standalone)
User taps "Calm Time" / "Meditate" from the home screen → answers 3 quick questions → immediately generates and plays a meditation. No character, no illustrations, audio-first. Follows `BedtimeWizardScreen` pattern.

---

## Phase 1: Backend Foundation

### New file: `backend/services/meditation_prompt_service.py`

`MeditationPromptService` class with `build_meditation_prompt()` method.

**Age-band constraints** (mirroring `AGE_CONSTRAINTS` in `story_service.py`):

| Age Band | Duration | Words | Style | Techniques |
|----------|----------|-------|-------|------------|
| Sprout (2-4) | 2-3 min | 150-250 | "Let's pretend" sensory imagery, repetition | Belly breathing, squeeze-and-release |
| Early Reader (5-7) | 3-5 min | 250-450 | Guided journey with companion, counting | Counting breaths, simple body scan, safe place |
| Adventurer (8-10) | 5-7 min | 450-650 | Body scan + visualization, grounding | Full body scan, progressive relaxation, 5-4-3-2-1 |
| Creator (11-13) | 7-10 min | 600-900 | Mindfulness, breathing exercises | Box breathing, thought observation, self-compassion |
| Adolescent (13-15) | 7-10 min | 600-900 | Stress management, self-awareness | 4-7-8 breathing, cognitive defusion, anchor breathing |
| Older Adolescent (15-18) | 7-10 min | 600-900 | Full mindfulness practice | Open awareness, RAIN technique, values anchoring |

**Prompt requirements:**
- Second-person address ("You feel the warm sand...")
- Include `[PAUSE 3s]` markers for breathing pauses
- Weave in chosen environment as setting, goal's techniques into narrative
- Character name/companions included if provided (scenario path)
- Return JSON: `{ "title": "...", "meditation_text": "...", "duration_estimate_seconds": N }`

**Safety rules** (extend existing `SAFETY_GUARDRAILS`):
- No clinical terminology ("mindfulness exercise", "CBT", "grounding technique")
- Frame as adventure/imagination ("imagine", "pretend", "picture")
- Breathing exercises as fun ("breathe like a dragon", "blow out birthday candles" for young)
- No mention of therapy, treatment, diagnosis

### New file: `backend/routes/meditation_routes.py`

Blueprint registered in `app.py`:
- `POST /meditation/generate` — accepts: `age`, `environment`, `goal`, `feeling`, optional `character_name`, `character_details`, `companions`
- Returns: `{ title, meditation_text, duration_estimate_seconds, environment }`
- Auth required, rate limited (10/hour)

### Modify: `backend/routes/story_routes.py`

When `meditationMode: true` in story request payload, redirect to meditation generation logic (for the scenario carousel path).

### Modify: `backend/app.py`

Register meditation blueprint.

---

## Phase 2: Quick Meditation Path (Frontend)

### New file: `lib/data/meditation_data.dart`

Static data following `scenario_data.dart` pattern:

**Environments** (7):
- Beach, Forest, Clouds, Space, Garden, Mountain, Cozy Room
- Each has: `id`, `emoji`, `label`, `description`, `ambienceAsset`
- Age variants: young label ("Sunny Beach") vs mature ("Ocean Shore")

**Goals** (7):
- Relax, Sleep, Focus, Feel Brave, Calm Down, Feel Safe, Let Go of Worries
- Each has: `id`, `emoji`, `label`, `description`

### New file: `lib/screens/quick_meditation_screen.dart`

**Pattern**: `lib/screens/bedtime_wizard_screen.dart` (minimal wizard, audio-first)

3-step flow:
1. **How are you feeling?** — Emotion cards (reuse feelings data from `feelings_wheel_data.dart`)
2. **Where do you want to go?** — Environment cards with calming imagery
3. **What would help?** — Goal cards

Dark calming gradient background. Large touch-friendly cards. Breathing animation during generation wait. Auto-plays TTS when meditation arrives.

**Entry point**: Card/button on main story screen (`lib/main_story.dart`). Age-adaptive label: "Calm Time" for Sprouts, "Meditate" for older bands.

### New file: `lib/screens/meditation_result_screen.dart`

Audio-first design (NOT like `StoryResultScreen`):
- Full-screen calming gradient mapped to chosen environment
- Central animated breathing visual (expanding/contracting orb — reuse `MagicOrb` from `lib/widgets/magic_orb.dart`)
- Text hidden by default, "Show Text" toggle
- Auto-play TTS narration on load
- Background ambience layered under narration
- Play/pause/restart controls + elapsed timer
- "Save to My Meditations" button (Isar storage)

### Modify: `lib/models/wizard_data.dart`

Add fields:
```dart
bool meditationMode = false;
String? meditationEnvironment;  // 'beach', 'forest', etc.
String? meditationGoal;         // 'relax', 'sleep', etc.
String? meditationFeeling;      // current emotion
```

---

## Phase 3: Scenario Carousel Path (Frontend)

### Modify: `lib/data/scenario_data.dart`

Add new `ScenarioCard`:
```dart
ScenarioCard(
  id: 'guided_meditation',
  emoji: '🧘',
  title: 'Guided Meditation',
  illustration: 'images/scenarios/meditation.png',
  description: 'Close your eyes and take a calming journey with your hero.',
  conflictHook: 'Take a deep breath. A peaceful adventure awaits.',
  sensoryPalette: 'Gentle waves, soft breezes, warm sunlight, deep slow breaths.',
  category: 'Real-Life Heroes',
  youngTitle: 'Calm Time',
  youngDescription: 'Breathe in... breathe out... let\'s go somewhere peaceful!',
  matureTitle: 'Guided Meditation',
  matureDescription: 'A personalized mindfulness journey with your character.',
)
```

### New widget: `lib/widgets/meditation_setup_modal.dart`

**Pattern**: `lib/widgets/feelings_quest_modal.dart`

Shown in `feeling_selection_step.dart` when `selectedScenario == 'guided_meditation'`. Three-panel modal: feeling → environment → goal. Results stored in `wizardData.meditationEnvironment`, `.meditationGoal`, `.meditationFeeling`.

### Modify: `lib/screens/wizard_steps/feeling_selection_step.dart`

When meditation scenario selected, show `MeditationSetupModal` instead of standard emotion chips.

### Modify: `lib/screens/wizard_steps/wizard_data_mapper.dart`

When `selectedScenario == 'guided_meditation'`, add `meditationMode: true`, `meditationEnvironment`, `meditationGoal` to API payload.

### Modify: `lib/screens/wizard_steps/magic_review_step.dart`

When meditation mode, navigate to `MeditationResultScreen` instead of `StoryResultScreen`.

---

## Phase 4: Audio Polish

### Modify: `backend/elevenlabs_tts_service.py`

- Add `clean_meditation_text_for_tts()` — converts `[PAUSE Xs]` markers to SSML `<break time="Xs"/>` tags
- Add meditation voice settings: higher stability (0.85), lower style (0.2), no speaker boost — calmer delivery

### Modify: `backend/routes/tts_routes.py`

Accept optional `meditation_mode` flag that applies meditation voice settings.

### Modify: `lib/services/app_tts_service.dart`

Add `speakMeditation()` method with slower speech rate (0.35 vs normal 0.42).

### Modify: `lib/services/audio_ambience_service.dart`

Add meditation ambience map:
- `beach` → ocean_gentle.mp3
- `forest` → forest_birds.mp3
- `clouds` → wind_soft.mp3
- `space` → space_ambient.mp3
- `garden` → garden_morning.mp3
- `mountain` → mountain_stream.mp3
- `cozy_room` → rain_window.mp3

Add `startMeditationAmbience(String environment)` — low volume (0.10-0.15), looping.

---

## Phase 5: Save & History

- Extend Isar storage (or add `MeditationLocal` model) to save meditations
- "My Meditations" section in saved stories / library
- Offline replay of saved meditations
- Analytics tracking for meditation usage

---

## Asset Requirements

**Images** (generate with existing Gemini pipeline):
- `assets/images/scenarios/meditation.png` — scenario card
- `assets/images/meditation/{beach,forest,clouds,space,garden,mountain,cozy_room}.png` — environment cards
- Age-band UI variants in `age_band_assets/*/` if needed

**Audio** (source from royalty-free libraries):
- 7 ambient loops (~30s each, loopable): ocean, forest, wind, space, garden, stream, rain

**Animation**:
- Breathing orb animation (Lottie JSON or custom Flutter `AnimatedBuilder`)

---

## Testing Strategy

**Backend unit tests:**
- `test_meditation_prompt_service.py` — verify each age band produces correct word count, techniques, safety compliance
- `test_meditation_routes.py` — API contract, auth, rate limits, error handling
- Verify `[PAUSE Xs]` markers appear and convert to SSML correctly

**Frontend widget tests:**
- `test/widgets/quick_meditation_screen_test.dart` — 3-step flow advances, stores data
- `test/widgets/meditation_result_screen_test.dart` — play/pause, text toggle, save
- `WizardDataMapper` produces `meditationMode: true` for meditation scenario

**Integration tests:**
- Quick path end-to-end: selections → API → meditation text → TTS playback
- Scenario path end-to-end: wizard → meditation scenario → API → result screen

---

## Rollout Timeline

| Phase | Scope | Est. Effort |
|-------|-------|-------------|
| 1 | Backend prompt service + endpoint | 1-2 weeks |
| 2 | Quick meditation path (standalone screen) | 1-2 weeks |
| 3 | Scenario carousel integration | 1 week |
| 4 | Audio polish (SSML pauses, ambience, voice tuning) | 1 week |
| 5 | Save/history, analytics | 1 week |

Phases 1 and 2 are independent. Phase 3 depends on Phase 1. Phase 4 can run in parallel with Phase 3.

---

## Files Summary

### New files
- `backend/services/meditation_prompt_service.py`
- `backend/routes/meditation_routes.py`
- `lib/data/meditation_data.dart`
- `lib/screens/quick_meditation_screen.dart`
- `lib/screens/meditation_result_screen.dart`
- `lib/widgets/meditation_setup_modal.dart`
- `backend/tests/unit/test_meditation_prompt_service.py`
- `backend/tests/unit/test_meditation_routes.py`

### Modified files
- `backend/app.py` — register meditation blueprint
- `backend/routes/story_routes.py` — redirect meditationMode requests
- `backend/elevenlabs_tts_service.py` — SSML pause conversion, meditation voice settings
- `backend/routes/tts_routes.py` — meditation_mode flag
- `lib/models/wizard_data.dart` — add meditation fields
- `lib/data/scenario_data.dart` — add meditation scenario card
- `lib/screens/wizard_steps/feeling_selection_step.dart` — show meditation modal
- `lib/screens/wizard_steps/wizard_data_mapper.dart` — map meditation fields
- `lib/screens/wizard_steps/magic_review_step.dart` — route to meditation result
- `lib/services/app_tts_service.dart` — speakMeditation method
- `lib/services/audio_ambience_service.dart` — meditation ambience map
- `lib/main_story.dart` — add meditation entry point
