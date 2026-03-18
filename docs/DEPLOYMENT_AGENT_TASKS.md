# Story Weaver - Deployment Agent Tasks

**Created:** 2026-02-02
**Purpose:** Break down remaining work into delegatable tasks for Gemini CLI and Codex when Claude session limits are hit.

---

## Current Status Summary

### COMPLETE
- Phase 1: Foundation (Wizard UI, Character System)
- Phase 2: Adventure Architecture (Archetypes, Companions, Mood Physics)
- Phase 3: Free-Form Magic (Custom user story elements)
- SDK Migration (google-genai)
- Flutter Code Quality (11 errors resolved)
- Story Personalization Logic (100% pass rate)
- Backend Deployment (Railway)
- Frontend Deployment (Netlify)

### REMAINING WORK
1. **UX Polish** (from Triple-Lens UX Audit - avatar flow, progress feedback, TTS)
2. **Dead Code Cleanup** (remove legacy feelings wheel - Mood Lanterns are now active)
3. **Avatar Categorization** (60 Midjourney images need metadata)
4. **QA & Testing** (manual flows, automated audit)
5. **Production Verification** (end-to-end sanity check)

### ALREADY MAGICAL (No Work Needed)
- **Mood Lanterns** - 7 chakra-colored lanterns with enchanted shelf design
- **Story Magic** - Sensory-rich adventures with impossible moments
- **Character System** - Heroes with special abilities and companion powers

---

## PHASE A: Critical Fixes (P0 - Safety & Accessibility)

### Task A1: JSON Parsing Robustness
**Agent:** Backend (Codex/Gemini)
**Complexity:** Medium
**Files:** `lib/services/api_service_manager.dart`

**Prompt for Agent:**
```
You are Agent 1 (Backend). Your task is to improve JSON parsing robustness in the Story Weaver app.

**File:** `lib/services/api_service_manager.dart` (around line 1264)

**Current Issue:**
Interactive story JSON extraction uses string splitting which fails if Gemini adds extra backticks or malformed markdown.

**Task:**
1. Find the JSON extraction logic (search for "```json")
2. Replace string splitting with regex-based extraction:
   ```dart
   final jsonPattern = RegExp(r'```(?:json)?\s*(\{[\s\S]*?\})\s*```', dotAll: true);
   final match = jsonPattern.firstMatch(responseText);
   if (match != null) {
     final jsonString = match.group(1);
     // Parse jsonString
   }
   ```
3. Add try-catch with retry logic
4. Add fallback for unformatted JSON (try parsing raw response if no code blocks found)

**Success Criteria:**
- [ ] JSON extracts correctly from ```json blocks
- [ ] JSON extracts correctly from ``` blocks (no language specifier)
- [ ] Graceful fallback if no code blocks found
- [ ] No crashes on malformed responses
```

---

### Task A2: WCAG Compliance Fixes
**Agent:** Frontend Widgets (Codex/Gemini)
**Complexity:** Medium
**Files:** `lib/screens/story_reader_screen.dart`, `lib/theme/app_theme.dart`

**Prompt for Agent:**
```
You are Agent 3 (Frontend Widgets). Your task is to improve WCAG accessibility compliance.

**Files:**
- `lib/screens/story_reader_screen.dart` (lines 336-348)
- `lib/theme/app_theme.dart`

**Tasks:**
1. **Text Contrast:** Ensure all text has minimum 4.5:1 contrast ratio against backgrounds
   - Check primary/secondary text colors against background colors
   - Fix any contrast issues in app_theme.dart

2. **Touch Targets:** Ensure all tappable elements are minimum 48x48 dp
   - Search for IconButton, InkWell, GestureDetector
   - Wrap small icons in SizedBox(width: 48, height: 48)

3. **Semantic Labels:** Add Semantics widgets to interactive elements
   ```dart
   Semantics(
     label: 'Play story audio',
     child: IconButton(...),
   )
   ```

**Files to check:**
- story_reader_screen.dart (TTS controls)
- wizard steps (navigation buttons)
- character cards (edit/delete buttons)

**Success Criteria:**
- [ ] All text passes 4.5:1 contrast ratio
- [ ] All buttons are minimum 48x48dp
- [ ] Screen readers can navigate all interactive elements
```

---

### Task A3: Data Encryption for Character Payloads
**Agent:** Frontend Core (Codex/Gemini)
**Complexity:** Low
**Files:** `lib/screens/wizard_steps/magic_review_step.dart`, `lib/services/secure_storage_service.dart`

**Prompt for Agent:**
```
You are Agent 2 (Frontend Core). Your task is to add encryption to character data before transmission.

**Files:**
- `lib/screens/wizard_steps/magic_review_step.dart` (around line 167-217)
- `lib/services/secure_storage_service.dart`

**Current Issue:**
Character save includes full JSON payload that could expose child data if network is compromised.

**Task:**
1. Check if `SecureStorageService` has an encrypt/decrypt method
2. If not, add simple AES encryption using flutter_secure_storage's underlying encryption
3. Before POSTing character data, encrypt sensitive fields (name, age, custom elements)
4. Update backend to decrypt OR use HTTPS-only (verify SSL is enforced)

**Note:** If backend already uses HTTPS and data is only stored locally, this may be lower priority. Document your findings.

**Success Criteria:**
- [ ] Sensitive data is encrypted before transmission OR
- [ ] Document why encryption isn't needed (HTTPS + local storage only)
```

---

## PHASE B: Engagement Improvements (P1)

### Task B1: Avatar Creation Flow Improvement
**Agent:** Frontend Core (Codex/Gemini)
**Complexity:** Medium
**Files:** `lib/screens/wizard_steps/hero_creator_step.dart`

**Prompt for Agent:**
```
You are Agent 2 (Frontend Core). Improve the avatar creation user experience.

**File:** `lib/screens/wizard_steps/hero_creator_step.dart` (around line 179-190)

**Current Issue:**
Avatar creator requires name input before opening, blocking immediate visual feedback. Children lose interest if they can't see their character immediately.

**Task:**
1. Allow avatar creator to open with placeholder name "Hero"
2. Show avatar preview immediately when user opens creator
3. When user enters name, update avatar's name field
4. Keep validation: require name before proceeding to next step (not before avatar preview)

**Implementation:**
```dart
// Before:
if (nameController.text.isEmpty) {
  showError('Please enter a name first');
  return;
}
openAvatarCreator();

// After:
openAvatarCreator(placeholderName: 'Hero');
// Name validation moves to "Next Step" button, not avatar opener
```

**Success Criteria:**
- [ ] User can see avatar preview without entering name
- [ ] Avatar updates when name is entered
- [ ] Cannot proceed to Step 2 without name (validation on Next button)
```

---

### Task B2: Story Generation Progress Feedback
**Agent:** Frontend Core (Codex/Gemini)
**Complexity:** Medium
**Files:** `lib/services/api_service_manager.dart`, `lib/screens/story_result_screen.dart`

**Prompt for Agent:**
```
You are Agent 2 (Frontend Core). Add progress feedback during story generation.

**Files:**
- `lib/services/api_service_manager.dart` (around line 540-580)
- `lib/screens/story_result_screen.dart`

**Current Issue:**
Story generation polls every 2 seconds with 90-second timeout. Children see no progress and may abandon the app.

**Task:**
1. Add a `Stream<int>` or `ValueNotifier<int>` for progress (0-100)
2. In polling loop, estimate progress based on elapsed time:
   ```dart
   final elapsed = DateTime.now().difference(startTime).inSeconds;
   final estimatedProgress = min(95, (elapsed / 30 * 100).round());
   progressNotifier.value = estimatedProgress;
   ```
3. In UI, show animated progress indicator:
   - Sparkle/star animation
   - Text: "Your story is 45% ready!"
   - Fun messages: "Adding magic...", "Polishing the ending...", "Almost there!"

**Success Criteria:**
- [ ] User sees animated progress during generation
- [ ] Progress text updates every 2-3 seconds
- [ ] Fun messages rotate during wait
```

---

### Task B3: TTS Word Highlighting Improvement
**Agent:** Frontend Widgets (Codex/Gemini)
**Complexity:** Medium
**Files:** `lib/screens/story_reader_screen.dart`

**Prompt for Agent:**
```
You are Agent 3 (Frontend Widgets). Fix TTS word highlighting accuracy.

**File:** `lib/screens/story_reader_screen.dart` (around line 70-89)

**Current Issue:**
Word highlighting relies on string matching which fails with punctuation variations. Highlighting appears on wrong words.

**Task:**
1. Find the word highlight matching logic
2. Replace with word boundary regex:
   ```dart
   final wordPattern = RegExp(r'\b' + RegExp.escape(currentWord) + r'\b', caseSensitive: false);
   ```
3. Tokenize story text by sentence boundaries for more accurate sync
4. Handle punctuation: strip trailing punctuation before matching

**Success Criteria:**
- [ ] "Hello!" matches "hello" correctly
- [ ] Contractions like "don't" highlight properly
- [ ] Highlighting stays in sync with audio
```

---

## PHASE C: Dead Code Cleanup (LOW PRIORITY)

**NOTE:** The Mood Lanterns are the ACTIVE emotion selector. The old feelings wheel is legacy dead code.

### Task C1: Remove Legacy Feelings Wheel Code
**Agent:** Frontend Widgets (Codex/Gemini)
**Complexity:** Low (30 min)
**Files:** Multiple legacy files to delete

**Prompt for Agent:**
```
You are Agent 3 (Frontend Widgets). Remove legacy feelings wheel code that is no longer used.

**Context:**
The app now uses Mood Lanterns (`lib/widgets/mood_lantern_selector.dart`) for emotion selection.
The old 3-level feelings wheel is dead code that should be removed.

**Files to DELETE (if not imported elsewhere):**
- `lib/widgets/expanding_feelings_wheel.dart`
- `lib/widgets/therapeutic_feelings_wheel.dart`
- `lib/feelings_wheel_screen.dart`

**Files to KEEP (still used by Mood Lanterns):**
- `lib/feelings_wheel_data.dart` - Contains SelectedFeeling class used by mood_lantern_data.dart
- `lib/widgets/mood_lantern_selector.dart` - The ACTIVE emotion selector

**Steps:**
1. Search for imports of each file to delete:
   ```bash
   grep -r "expanding_feelings_wheel" lib/
   grep -r "therapeutic_feelings_wheel" lib/
   grep -r "feelings_wheel_screen" lib/
   ```
2. If a file is imported, check if the import is actually used or can be removed
3. Delete files that are truly unused
4. Run `flutter analyze` to verify no broken imports

**Success Criteria:**
- [ ] App compiles without errors
- [ ] `flutter analyze` passes
- [ ] Mood Lantern selector still works
- [ ] Dead wheel code is removed
```

### Task C2: Clean Up feelings_wheel_data.dart (OPTIONAL)
**Agent:** Frontend Widgets (Codex/Gemini)
**Complexity:** Low (15 min)
**Files:** `lib/feelings_wheel_data.dart`

**Prompt for Agent:**
```
You are Agent 3 (Frontend Widgets). Clean up feelings_wheel_data.dart to remove unused data.

**Context:**
This file contains the SelectedFeeling class (USED by Mood Lanterns) but also contains
CoreEmotion, SecondaryFeeling, and the full 3-level emotion hierarchy (UNUSED).

**Task:**
1. Keep the `SelectedFeeling` class - it's used by Mood Lanterns
2. Check if `CoreEmotion`, `SecondaryFeeling`, and `FeelingsWheelData` are used anywhere
3. If unused, delete them (the inappropriate emotions like "Aroused" are in these unused classes)
4. If used elsewhere, leave them but document they're legacy

**Note:** The inappropriate emotions (Aroused, Intimate, Violated) are ONLY in the unused
hierarchical data. Mood Lanterns use clean emotions (Happy, Sad, Angry, etc.).

**Success Criteria:**
- [ ] App compiles without errors
- [ ] Mood Lanterns still work
- [ ] Unused emotion hierarchy removed OR documented as legacy
```

---

## PHASE D: Avatar Categorization (Manual + Script)

### Task D1: Avatar Metadata Script
**Agent:** Backend (Codex/Gemini)
**Complexity:** Low
**Files:** `tools/check_avatar_metadata.py`, `assets/avatars/midjourney/`

**Prompt for Agent:**
```
You are Agent 1 (Backend). Create a script to help categorize Midjourney avatars.

**Context:**
60 avatars in `assets/avatars/midjourney/` need metadata fields filled in:
- Age Group (child, teen, adult)
- Skin Tone (light, medium, dark)
- Hair Color
- Gender Presentation (boy, girl, neutral)

**Task:**
1. Read `tools/check_avatar_metadata.py` to understand current state
2. Create/update a JSON file `assets/avatars/midjourney/metadata.json`:
```json
{
  "avatar_001.webp": {
    "age_group": null,
    "skin_tone": null,
    "hair_color": null,
    "gender": null,
    "needs_review": true
  },
  ...
}
```
3. Create a helper script that opens each image for visual review and prompts for metadata input

**Note:** This task creates the tooling. Actual categorization requires human visual review.

**Success Criteria:**
- [ ] metadata.json exists with all 60 avatar filenames
- [ ] Script can be run to fill in metadata interactively
```

---

## PHASE E: QA & Testing

### Task E1: Automated Content Audit Script
**Agent:** Backend (Codex/Gemini)
**Complexity:** Medium
**Files:** `tools/run_content_audit.py`, `backend/services/story_service.py`

**Prompt for Agent:**
```
You are Agent 1 (Backend). Create an automated content audit script.

**File:** Create `tools/run_content_audit.py`

**Purpose:** Verify backend generates correct prompts for all age/mode combinations WITHOUT consuming API quota.

**What to check:**
1. Age 4 prompt contains: "Vocabulary: CVC words", "Simple sentences"
2. Age 15 prompt avoids: "tummy", "potty", condescending language
3. Rhyme mode prompt contains: "Scheme: AABB"
4. Learn-to-Read mode has repetitive structure instructions
5. All modes include companion if one was selected

**Implementation:**
1. Import story generation functions from backend
2. Mock the LLM call (just capture the prompt, don't send it)
3. Run through test matrix:
   - Ages: 4, 7, 9, 12, 15
   - Modes: Regular, Rhyme, Learn-to-Read, Pick-a-Path
4. Assert prompt contains expected keywords for each combination

**Success Criteria:**
- [ ] Script runs without errors
- [ ] Outputs pass/fail for each combination
- [ ] Documents any prompt gaps found
```

---

### Task E2: Manual Test Case Execution
**Agent:** Human (with Agent assistance)
**Complexity:** Medium
**Files:** `COMPREHENSIVE_QA_PLAN.md`

**Prompt for Agent:**
```
This task requires human testing with optional AI assistance.

**Test Cases (from COMPREHENSIVE_QA_PLAN.md):**

A. First Time User Flow
   1. Fresh install -> Create "Leo" (Age 7, Boy, Explorer)
   2. Select "Excited" -> "To Explore"
   3. Add "Sparky the Dragon" companion
   4. Enable Illustrations, generate Regular Story
   5. Verify: ~700 words, illustration present, Sparky in story, Leo is hero
   6. Restart -> Verify Leo saved

B. Little Reader Flow (Age 4)
   1. Create "Mia" (Age 4), Learn to Read mode
   2. Verify: CVC words, short sentences, no scary content

C. Pick-a-Path Adventure (Age 10)
   1. Create "Sam" (Age 10), Pick-a-Path mode
   2. Verify: 2 choices per segment, choices are action-oriented, state persists

D. Custom Wish Flow
   1. Enter "I want to meet a talking toaster"
   2. Verify: Story literally contains a talking toaster

**Document results in:** `reports/QA_RESULTS_[DATE].md`
```

---

## PHASE F: Production Verification

### Task F1: Production Sanity Check
**Agent:** Human + Backend (Codex/Gemini)
**Complexity:** Low
**Files:** N/A (live testing)

**Prompt for Agent:**
```
Verify production deployment is working correctly.

**Backend (Railway):**
1. Check `/health` endpoint returns 200
2. Verify database connection
3. Verify Gemini API key is set
4. Check Stripe configuration (if applicable)

**Frontend (Netlify):**
1. Load production URL
2. Complete one full wizard flow
3. Generate one story
4. Verify story saves to library

**Commands to check backend:**
```bash
curl https://[railway-url]/health
curl https://[railway-url]/api/status
```

**Document any issues in:** `reports/PRODUCTION_CHECK_[DATE].md`
```

---

## PHASE G: Post-Launch Enhancements (Optional)

### Task G1: Parent Dashboard
**Agent:** Frontend Core (Codex/Gemini)
**Complexity:** High
**Files:** New file: `lib/screens/parent_dashboard_screen.dart`

### Task G2: BYOK Onboarding Tooltip
**Agent:** Frontend Core (Codex/Gemini)
**Complexity:** Low
**Files:** `lib/settings_screen.dart`, `lib/onboarding_screen.dart`

### Task G3: Simple Mode for Wizard
**Agent:** Frontend Core (Codex/Gemini)
**Complexity:** Medium
**Files:** `lib/screens/wizard_story_screen.dart`

### Task G4: TTS Speed Control
**Agent:** Frontend Widgets (Codex/Gemini)
**Complexity:** Low
**Files:** `lib/screens/story_reader_screen.dart`

---

## PHASE X: Remove Onboarding Screen (USER REQUESTED)

### Task X1: Skip Onboarding - Go Straight to Wizard
**Agent:** Frontend Core (Codex/Gemini)
**Complexity:** Low (20 min)
**Files:** `lib/main.dart`, `lib/onboarding_screen.dart`

**Prompt for Agent:**
```
You are Agent 2 (Frontend Core). Remove the onboarding screen so users go directly to the wizard.

**Files:**
- `lib/main.dart` (main app routing logic)
- `lib/onboarding_screen.dart` (to be removed or bypassed)
- `lib/services/onboarding_service.dart` (may need cleanup)

**Current Behavior:**
1. App checks `_hasCompletedOnboarding` in main.dart
2. If false, shows OnboardingScreen (collects child name, age, theme)
3. After onboarding, shows MainStoryScreen (the wizard)

**New Behavior:**
1. App always goes directly to MainStoryScreen (the wizard)
2. The wizard's Hero Creator step already collects name, age, etc.

**Implementation Options:**

Option A (Quick - Force skip onboarding):
In `lib/main.dart`, change the build logic to always show MainStoryScreen:
```dart
// Before:
if (_hasCompletedOnboarding == false) {
  return OnboardingScreen(...);
}
return MainStoryScreen();

// After:
return MainStoryScreen();
```

Option B (Clean - Remove onboarding entirely):
1. In `lib/main.dart`, remove OnboardingScreen import and all onboarding checks
2. Remove `_hasCompletedOnboarding`, `_onboardingService` references
3. Delete or archive `lib/onboarding_screen.dart`
4. Delete or archive `lib/services/onboarding_service.dart`
5. Delete or archive `lib/services/onboarding_analytics.dart`

**Recommendation:** Start with Option A to verify it works, then do Option B cleanup later.

**Success Criteria:**
- [ ] App launches directly to the wizard (MainStoryScreen)
- [ ] No onboarding screen appears on first launch
- [ ] Hero Creator step still collects name/age properly
- [ ] App compiles without errors
```

---

## PHASE Y: Age-Appropriate Content for Tweens/Teens (USER REQUESTED)

### Task Y1: Add Mature Content Variants for Ages 10+
**Agent:** Frontend Core + Backend (Codex/Gemini)
**Complexity:** Medium-High (2-3 hours)
**Files:** Multiple data files

**Prompt for Agent:**
```
You are working on Story Weaver. The content feels too babyish for 12-year-olds.
Current content has "rainbow lava", "magic paintbrush", "Giggle lantern" - very young.

**Problem:**
- Scenarios have `youngTitle`/`youngDescription` for ages 3-6
- But NO mature variants for ages 10+ (tweens/teens)
- Archetypes like "Heart Healer" and "Quiz Whiz" feel childish to a 12-year-old
- Mood Lanterns (Sunshine, Giggle, Heartglow) feel babyish

**Task:** Add mature content variants for older users (ages 10+)

**Files to modify:**

1. `lib/data/scenario_data.dart` - Add mature scenario variants:
```dart
class ScenarioCard {
  // ... existing fields ...
  final String? matureTitle;        // For ages 10+
  final String? matureDescription;
  final String? matureConflictHook;

  String titleForAge(int age) {
    if (age <= 6 && youngTitle != null) return youngTitle!;
    if (age >= 10 && matureTitle != null) return matureTitle!;
    return title;
  }
}
```

Example transformations for MAGICAL WORLDS:
| Young (3-6) | Default (7-9) | Mature (10+) |
|-------------|---------------|--------------|
| Dragon Friends | The Volcano of Sleeping Dragons | The Volcanic Lair |
| Pretty colors! | Rainbow lava | Molten crystal eruption |
| Gentle lullaby | Wake the kindest dragon | Negotiate with an ancient wyrm |

**CRITICAL: Real-Life Heroes scenarios are especially babyish for 12-year-olds:**

| Current (Babyish) | Mature Version (10+) |
|-------------------|----------------------|
| "The Brave Friend" - "saying hello is a big adventure!" | "Breaking the Ice" - "Navigating social dynamics and finding your crew" |
| "Standing Tall" - "playground shadow", "heart is your shield" | "Standing Your Ground" - "Dealing with someone who's giving you a hard time" |
| "Big Feelings Quest" - "rumbly tummy feelings", "boss of your clouds" | "Riding the Storm" - "Managing anxiety and anger without losing control" |
| "Change is Coming!" - "cocoon turning into butterfly" | "Unknown Territory" - "Starting over when everything familiar is gone" |
| "Magic Story Whisperer" - "whisper to your magical friend!" | "Safe Space" - "Getting something off your chest" |

The current descriptions like "Let's find our happy sunshine after the rainy clouds pass by" are mortifying for a 12-year-old. They need real, relatable language.

2. `lib/widgets/archetype_card.dart` - Add mature archetype names:
```dart
class ArchetypeData {
  final String matureName;        // For ages 10+
  final String matureDescription;
}
```

Example transformations:
| Current Name | Mature Name (10+) |
|--------------|-------------------|
| The Quiz Whiz | The Strategist |
| The Heart Healer | The Empath |
| The Master Creator | The Architect |
| The Lightning Runner | The Speedster |
| The Storm Rider | The Tempest |
| The Animal Whisperer | The Beast Speaker |

3. `lib/data/mood_lantern_data.dart` - Add mature mood names:
```dart
class MoodLantern {
  final String matureName;  // For ages 10+
}
```

Example transformations:
| Current | Mature (10+) |
|---------|--------------|
| Sunshine | Triumph |
| Giggle | Mischief |
| Raindrop | Melancholy |
| Moonbeam | Dread |
| Ember | Fury |
| Dewdrop | Serenity |
| Heartglow | Thrill |

4. `lib/screens/wizard_steps/feeling_selection_step.dart` - Use age to select variant
5. `lib/screens/wizard_steps/hero_creator_step.dart` - Use age to select variant

**Implementation Pattern:**
- Add `matureName`, `matureDescription` fields to data classes
- Add helper methods like `nameForAge(int age)`
- In UI, get current character age from WizardData and call `nameForAge(age)`
- Age thresholds: young ≤ 6, default 7-9, mature ≥ 10

**Success Criteria:**
- [ ] 12-year-old sees "The Strategist" not "The Quiz Whiz"
- [ ] 12-year-old sees "Fury" not "Ember" for angry mood
- [ ] 12-year-old sees mature scenario descriptions
- [ ] 6-year-old still sees young/cute content
- [ ] 8-year-old sees default content
- [ ] App compiles without errors
```

---

### Task Y2: Update Backend Story Prompts for Mature Tone
**Agent:** Backend (Codex/Gemini)
**Complexity:** Medium (1 hour)
**Files:** `backend/services/story_service.py`

**Prompt for Agent:**
```
You are Agent 1 (Backend). Update story generation prompts to use age-appropriate tone.

**File:** `backend/services/story_service.py`

**Problem:**
Stories for 12-year-olds might still use phrases like "magical adventure" or "special friend"
which feel condescending to tweens/teens.

**Task:**
1. Find the AGE_CONSTRAINTS or age-based prompt logic
2. For ages 10+, adjust the tone instructions:

```python
if age >= 10:
    tone_instructions = """
    TONE FOR TWEENS/TEENS (10+):
    - Use "epic" not "magical"
    - Use "ally" or "companion" not "special friend"
    - Use "challenge" not "problem to solve"
    - Use "determined" not "brave little"
    - Avoid: tummy, potty, uh-oh, oopsie, yummy
    - Avoid: condescending phrases like "good job" or "you did it!"
    - Include: moral complexity, real stakes, character growth
    - Vocabulary: age-appropriate sophistication
    """
else:
    tone_instructions = "..." # existing young/default tone
```

3. Verify the prompt includes these tone adjustments

**Success Criteria:**
- [ ] Story for 12-year-old uses mature vocabulary
- [ ] No condescending phrases in tween/teen stories
- [ ] Story for 5-year-old still uses gentle, simple language
```

---

## Task Priority Order

**BEFORE LAUNCH (Required):**
1. Task X1: Remove Onboarding Screen (20 min) - USER REQUESTED
2. Task Y1: Mature Content for Ages 10+ (2-3 hours) - USER REQUESTED
3. Task Y2: Backend Mature Tone (1 hour) - USER REQUESTED
4. Task A1: JSON Parsing Robustness (30 min)
5. Task E1: Automated Content Audit (1 hour)
6. Task E2: Manual Test Cases (1-2 hours)
7. Task F1: Production Sanity Check (30 min)

**SOON AFTER LAUNCH (High Priority):**
5. Task B1: Avatar Creation Flow (1 hour)
6. Task B2: Story Generation Progress (1 hour)
7. Task B3: TTS Word Highlighting (1 hour)

**LATER (Nice to Have - Cleanup):**
8. Task C1: Remove Legacy Feelings Wheel Code (30 min)
9. Task C2: Clean Up feelings_wheel_data.dart (15 min)
10. Task A2: WCAG Compliance (2 hours)
11. Task A3: Data Encryption (varies)
12. Task D1: Avatar Metadata Script (1 hour)
13. Phase G tasks (post-launch)

---

## How to Use This Document

### For Gemini CLI:
```bash
gemini -p "$(cat << 'EOF'
[Paste task prompt here]
EOF
)"
```

### For Codex:
1. Open Codex in the project directory
2. Paste the task prompt
3. Monitor output and iterate

### For Claude (when available):
1. Reference this document: "Continue from DEPLOYMENT_AGENT_TASKS.md Task [X]"
2. Claude will read the task and execute

---

## Agent Assignment Summary

| Phase | Task | Best Agent | Time Est. |
|-------|------|------------|-----------|
| X1 | Remove Onboarding | Gemini/Codex | 20 min |
| Y1 | Mature Content (UI) | Claude/Gemini | 2-3 hours |
| Y2 | Mature Tone (Backend) | Codex | 1 hour |
| A1 | JSON Parsing | Codex (precise) | 30 min |
| A2 | WCAG Compliance | Gemini (broad) | 2 hours |
| A3 | Data Encryption | Codex (secure) | varies |
| B1 | Avatar Flow | Gemini (UX) | 1 hour |
| B2 | Progress Feedback | Gemini (UX) | 1 hour |
| B3 | TTS Highlighting | Codex (precise) | 1 hour |
| C1 | Delete Dead Code | Either | 30 min |
| C2 | Clean Data File | Either | 15 min |
| D1 | Avatar Metadata | Codex (script) | 1 hour |
| E1 | Content Audit | Codex (test) | 1 hour |
| E2 | Manual Tests | Human | 1-2 hours |
| F1 | Prod Check | Human | 30 min |

## What's Already Magical (No Work Needed)

The "magical GUI" is ALREADY IMPLEMENTED via **Mood Lanterns**:
- 7 glowing lanterns on an enchanted shelf
- Chakra-inspired colors (Amber, Rose, Purple, etc.)
- Magical names: Sunshine, Ember, Raindrop, Moonbeam, Giggle, Dewdrop, Heartglow
- Animated glow effects on selection
- "Picking a magic ingredient" not "checking an emotion box"

The story generation already includes:
- Sensory-rich adventures (sight, sound, smell, taste, touch)
- Physics-defying "impossible moments"
- Companions with special abilities (Rainbow Fire, Walk Through Walls, etc.)
- Mood Physics (emotions affect world rules)

---

**Last Updated:** 2026-02-02
**Author:** Claude (Opus 4.5)
