# Story Weaver — Comprehensive Improvement Plan

**Created:** 2026-03-21
**Source:** Six Hats UX analysis + user requirements
**Purpose:** 12-feature implementation plan with delegation prompts

---

## Summary of Features

| # | Feature | Complexity | Phase | Model |
|---|---------|-----------|-------|-------|
| F1 | Quick Story / Audio-Only Mode | HIGH | 3 | Claude |
| F2 | "Same Settings" / Repeat Story Mode | MEDIUM | 2 | Gemini |
| F3 | Chronicles Discovery | MEDIUM | 2 | Gemini |
| F4 | Companion UX Improvements | MEDIUM | 2 | Claude |
| F5 | "Imagine It" Scenario Prominence | LOW | 1 | Codex |
| F6 | Cut Archetypes for Younger Kids (4 instead of 6) | LOW | 1 | Codex |
| F7 | Remove Wisdom Gem | MEDIUM | 1 | Gemini |
| F8 | Fix .jpg Gitignore Issue | LOW | 1 | Codex |
| F9 | Fix Isar Web Support | MEDIUM | 4 | Claude |
| F10 | Input Sanitization / Prompt Injection Protection | HIGH | 3 | Claude |
| F11 | Adventurer Band (9-11) Feelings UI (badge grid) | MEDIUM | 3 | Claude + Codex |
| F12 | Therapist Portal Separation | HIGH | 4 | Claude |

---

## Phase 1 — Quick Wins (immediate)

### F8: Fix .jpg Gitignore

**Problem:** `*.jpg` in `.gitignore` prevents ALL JPG files from being committed. Per-band archetype images are missing on fresh clones.

**Files:** `.gitignore`

**Fix:**
- Remove blanket `*.jpg` rule
- Add targeted rules: `/*.jpg` (root-level only) + `!assets/images/**/*.jpg` (track asset JPGs)
- `git add assets/images/` to stage previously-ignored JPGs

---

### F6: Cut Archetypes for Young Kids

**Problem:** Sprout/Explorer see 6 archetypes — too many for ages 3-7.

**Keep 4:** Storm Rider (brave), Master Creator (creative), Heart Healer (caring), Animal Whisperer (required)
**Cut:** Quiz Whiz (too cerebral), Lightning Runner (too competition-focused)

**Files:**
- `lib/widgets/archetype_card.dart` — add `CharacterArchetypes.forBand(AgeBand band)` method
- `lib/screens/wizard_steps/hero_creator_step.dart` — use `forBand()` instead of `.all`

---

### F5: "Imagine It" Scenario Prominence

**Problem:** The most powerful scenario is buried at the end of "Real-Life Heroes" category.

**Fix:**
- Add `featured: true` to `ScenarioCard` class
- Set `featured: true` on `safe_space` scenario
- In `_buildScenarioSections`, render featured scenarios as a full-width card at the TOP
- Give it distinct visual styling (larger, sparkle animation, unique gradient)

**Files:**
- `lib/data/scenario_data.dart`
- `lib/screens/wizard_steps/feeling_selection_step.dart`

---

### F7: Remove Wisdom Gem

**Problem:** Wisdom gem can sound like a lesson summary, breaking story immersion.

**Backend changes:**
- `backend/services/story_service.py` — remove `wisdom_gem` from all JSON schemas, remove `wisdom_gem_guidance` logic, keep `_strip_lesson_endings()`

**Frontend changes:**
- `lib/models/story_generation_result.dart` — make `wisdomGem` nullable
- `lib/story_result_screen.dart` — remove wisdom gem display
- `lib/screens/wizard_steps/magic_review_step.dart` — remove pass-through
- `lib/services/api_service_manager.dart` — update response parsing

---

## Phase 2 — Core UX Improvements

### F2: "Same Settings" / Repeat Story Mode

**Problem:** Users must complete the full wizard every time.

**Fix:**
- Save `WizardData` snapshot after story generation (SharedPreferences JSON)
- Add "Same Character, New Story" and "Same Settings, New Story" buttons to `StoryResultScreen`
- "Same Settings" → jump to `MagicReviewStep` with everything pre-filled
- Add inline scenario picker on `MagicReviewStep` so users can swap scenario without going back

**Files:**
- `lib/models/wizard_data.dart` — add `clone()` method
- `lib/story_result_screen.dart` — add repeat buttons
- `lib/screens/wizard_steps/magic_review_step.dart` — add inline scenario change

---

### F3: Chronicles Discovery

**Problem:** Multi-chapter stories exist but children don't know about them.

**Fix:**
- Add "Continue Your Story" button to `StoryResultScreen` after story ends
- Add "My Chronicles" button to wizard top bar (alongside Heroes/Feelings)
- In `ChroniclesListScreen`, show "Start Chapter 2!" prompt for single-chapter chronicles

**Files:**
- `lib/story_result_screen.dart`
- `lib/screens/wizard_story_screen.dart`
- `lib/screens/chronicles_list_screen.dart`

---

### F4: Companion UX Improvements (without lengthening wizard)

**Problem:** Companions feel like accessories. Naming is not obvious.

**Fix:**
- Redesign `_CompanionCard` to show signature power and sensory tell
- "Meet Your Companion" animation: expand card, show speech bubble with greeting
- Add companion naming text field when selected (default to original name)
- Pass companion personality more explicitly in `WizardDataMapper` so companions SPEAK and ACT in stories

**Files:**
- `lib/screens/wizard_steps/companion_selector_step.dart`
- `lib/models/wizard_data.dart` — add `companionCustomNames`
- `lib/screens/wizard_steps/wizard_data_mapper.dart` — enhance companion data in prompt

---

## Phase 3 — New Capabilities

### F1: Quick Story / Audio-Only Mode

**Problem:** 4-step wizard is too long. No way to jump straight into a story.

**Fix:**
- Create `QuickStoryScreen` — loads last character, randomizes scenario, shows single review screen
- "Jump Into a Story" button on welcome/main screen (only if saved character exists)
- Refactor `BedtimeWizardScreen` with `isAnytime: true` for audio-only mode available any time
- "Audio Story" button prominent from the beginning

**New files:**
- `lib/screens/quick_story_screen.dart`
- `lib/services/last_session_service.dart`

**Modified files:**
- `lib/screens/welcome_screen.dart`
- `lib/screens/bedtime_wizard_screen.dart` — add `isAnytime` parameter
- `lib/screens/wizard_story_screen.dart` — add Quick/Audio buttons to top bar

---

### F10: Input Sanitization / Prompt Injection Protection (SAFETY-CRITICAL)

**Problem:** User text reaches Gemini prompt unsanitized. Prompt injection and inappropriate content possible.

**Fix — Frontend:**
- Create `InputSanitizer` with:
  - `sanitizeText()` — strip HTML, cap length, remove null bytes
  - `sanitizeForPrompt()` — strip injection patterns ("ignore previous instructions", "system:", etc.)
  - `containsInappropriateContent()` — blocklist check
- Apply in `WizardDataMapper.mapToStoryRequest()` to all user-entered fields
- Length caps: customElements 500 chars, parentalNote 300 chars, characterName 50 chars
- Gentle warning UI: "Let's keep our stories magical and kind!"

**Fix — Backend defense-in-depth:**
- Wrap user strings with `[USER_INPUT]...[/USER_INPUT]` delimiters
- Add system instruction telling Gemini to treat those as story descriptions only, never instructions
- Server-side sanitization in `backend/utils/sanitizer.py`

**New files:**
- `lib/utils/input_sanitizer.dart`
- `backend/utils/sanitizer.py`

**Modified files:**
- `lib/screens/wizard_steps/wizard_data_mapper.dart`
- `backend/services/story_service.py`

---

### F11: Adventurer Band (9-11) Feelings UI

**Problem:** Ages 9-11 get neither cloud cards (too young) nor flat cards (too mature).

**Fix:**
- Create badge/icon grid: 2x4 grid of illustrated emotion badges (scout badge / RPG skill style)
- Not babyish, not corporate — illustrated icons with labels
- 8 emotions: Happy, Sad, Angry, Worried, Frustrated, Embarrassed, Excited, Calm
- Assets needed: 8 illustrated badge PNGs (~128x128, transparent background)

**New files:**
- `lib/widgets/feelings_badge_grid.dart`

**Modified files:**
- `lib/screens/wizard_steps/feeling_selection_step.dart` — route ages 9-11 to badge grid

**Asset needs:** 8 emotion badge illustrations in `assets/images/feelings/adventurer/`

---

## Phase 4 — Architectural

### F9: Fix Isar Web Support

**Problem:** Avatar caching disabled on web. `dart:io` File not available in browsers.

**Fix:**
- Add `kIsWeb` checks in avatar service
- Cache avatar base64 strings in SharedPreferences on web
- Use `image_picker_for_web` for photo selection
- Create conditional imports for File operations

**Files:**
- `lib/services/avatar_service.dart`
- `lib/custom_avatar_screen.dart`
- `lib/services/isar_service_stub.dart`

---

### F12: Therapist Portal Separation

**Problem:** Children can accidentally navigate to therapist dashboard through settings.

**Fix (Option B + A hybrid):**
- Remove therapist portal from child-accessible settings
- Add therapist login behind parent controls with credential gate
- Create `TherapistAuthService` for role verification
- Backend: add `/therapist/auth/login` endpoint with role middleware
- Future: deep link `storyweaver://therapist` for direct access

**Files:**
- `lib/settings_screen.dart` — remove therapist nav
- `lib/screens/parent_controls_screen.dart` — add gated therapist section
- New: `lib/services/therapist_auth_service.dart`
- `backend/routes/therapist_routes.py` — add auth middleware
