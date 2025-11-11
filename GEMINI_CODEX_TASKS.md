# Detailed Task Plans for Gemini & Codex
## Save Claude Time - Parallel Development

**Context:** User wants to conserve Claude usage by delegating appropriate tasks to Gemini (Ubuntu) and Codex (Ubuntu).

---

## 🎨 GEMINI TASK 1: Simplify Character Creation Form
**Branch:** `gemini/simplify-form`
**Location:** Ubuntu (`/mnt/c/dev/story-weaver-app-codex-dev` or similar)
**Priority:** HIGH
**Estimated Time:** 30-45 minutes

### Goal
Combine the "Goals" and "Current Challenge" sections in character creation/edit forms to make the form shorter and less overwhelming.

### What to Change

**Files to modify:**
1. `lib/character_creation_screen_enhanced.dart`
2. `lib/character_edit_screen.dart`
3. `lib/interest_options.dart`

### Step-by-Step Instructions

**Step 1: Update interest_options.dart**
```dart
// FIND this section (lines 44-60):
const List<InterestOption> commonGoalOptions = [
  InterestOption('Make New Friends', Icons.group_add),
  InterestOption('Be Brave', Icons.shield_outlined),
  InterestOption('Try New Foods', Icons.restaurant),
  InterestOption('Sleep Alone', Icons.bedtime),
  InterestOption('Learn to Swim', Icons.pool),
  InterestOption('Share More', Icons.share),
];

const List<InterestOption> commonChallengeOptions = [
  InterestOption('Taking Turns', Icons.loop),
  InterestOption('New Routines', Icons.schedule),
  InterestOption('Being Patient', Icons.hourglass_bottom),
  InterestOption('Losing Games', Icons.videogame_asset),
  InterestOption('Going to School', Icons.school),
  InterestOption('Trying Again After Failing', Icons.restart_alt),
];

// REPLACE with this single combined list:
// Combined goals and challenges - what the child is working on
const List<InterestOption> commonGoalOptions = [
  InterestOption('Make New Friends', Icons.group_add),
  InterestOption('Be Brave', Icons.shield_outlined),
  InterestOption('Try New Foods', Icons.restaurant),
  InterestOption('Sleep Alone', Icons.bedtime),
  InterestOption('Learn to Share', Icons.share),
  InterestOption('Taking Turns', Icons.loop),
  InterestOption('Be Patient', Icons.hourglass_bottom),
  InterestOption('Handle Losing Well', Icons.videogame_asset),
  InterestOption('New School/Routines', Icons.school),
  InterestOption('Keep Trying', Icons.restart_alt),
];

// DELETE commonChallengeOptions entirely
```

**Step 2: Update character_creation_screen_enhanced.dart**

2a. Find the controller declarations (around line 69-72):
```dart
// CHANGE FROM:
final _goalsController = TextEditingController();
final _challengesController = TextEditingController();

// TO:
final _goalsChallengesController = TextEditingController(); // Combined
```

2b. Find the state variables (around line 58-62):
```dart
// CHANGE FROM:
final Set<String> _selectedGoalOptions = <String>{};
String? _selectedChallengeOption;

// TO:
final Set<String> _selectedGoalChallengeOptions = <String>{}; // Combined
```

2c. Find the `_resolveChallengeValue()` method and DELETE it entirely (around line 151-157)

2d. Find where goals/challenges are sent to backend (around line 295-297):
```dart
// CHANGE FROM:
'goals': _combinedGrowthSelections(_selectedGoalOptions, _goalsController),
if (challengeValue != null) 'challenge': challengeValue,

// TO:
'goals': _combinedGrowthSelections(_selectedGoalChallengeOptions, _goalsChallengesController),
```

2e. Find the dispose method (around line 360):
```dart
// CHANGE FROM:
_goalsController.dispose();
_challengesController.dispose();

// TO:
_goalsChallengesController.dispose();
```

2f. Find the _buildGrowthSection UI (around lines 1085-1126):
```dart
// FIND this entire block (about 40 lines):
        const SizedBox(height: 20),
        _buildInterestChipGroup(
          title: 'Goals or things they're working on',
          subtitle: 'Helps the story cheer them on',
          options: commonGoalOptions,
          selections: _selectedGoalOptions,
        ),
        const SizedBox(height: 12),
        TextFormField(
          controller: _goalsController,
          decoration: InputDecoration(
            labelText: 'Other goals',
            hintText: 'e.g., be braver at night',
            helperText: 'Separate with commas',
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
            filled: true,
            fillColor: Colors.amber[50],
            prefixIcon: const Icon(Icons.flag_outlined),
          ),
          maxLines: 2,
        ),
        const SizedBox(height: 20),
        _buildSingleChoiceChipGroup(
          title: 'Current challenge',
          subtitle: 'Pick the one that fits best',
          options: commonChallengeOptions,
          selectedValue: _selectedChallengeOption,
          onSelected: (value) {
            setState(() => _selectedChallengeOption = value);
          },
        ),
        const SizedBox(height: 12),
        TextFormField(
          controller: _challengesController,
          decoration: InputDecoration(
            labelText: 'Describe their current challenge',
            hintText: 'e.g., getting ready on time',
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
            filled: true,
            fillColor: Colors.pink[50],
            prefixIcon: const Icon(Icons.trending_up),
          ),
        ),

// REPLACE with this simpler version (about 20 lines):
        const SizedBox(height: 20),
        _buildInterestChipGroup(
          title: 'What they\'re working on (goals or challenges)',
          subtitle: 'Stories can help them grow and cheer them on',
          options: commonGoalOptions,
          selections: _selectedGoalChallengeOptions,
        ),
        const SizedBox(height: 12),
        TextFormField(
          controller: _goalsChallengesController,
          decoration: InputDecoration(
            labelText: 'Other goals or challenges',
            hintText: 'e.g., being braver, making new friends, learning to share',
            helperText: 'Separate with commas',
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
            filled: true,
            fillColor: Colors.amber[50],
            prefixIcon: const Icon(Icons.emoji_events),
          ),
          maxLines: 2,
        ),
```

**Step 3: Apply SAME changes to character_edit_screen.dart**
- It has the same structure as character_creation_screen_enhanced.dart
- Make identical changes in the same sections
- Search for the same patterns and replace them

### Testing
```bash
flutter pub get
flutter build web --release
# Should compile without errors
```

### Git Workflow
```bash
git checkout main
git pull origin main
git checkout -b gemini/simplify-form
# Make changes
flutter build web --release  # Verify it builds
git add lib/character_creation_screen_enhanced.dart lib/character_edit_screen.dart lib/interest_options.dart
git commit -m "[Simplify] Merge goals and challenges into single section

- Combined goals and challenges into one field
- Reduced form complexity by ~20 lines per form
- Updated both creation and edit screens
- Merged commonGoalOptions and commonChallengeOptions"
git push origin gemini/simplify-form
```

---

## 📚 CODEX TASK 1: Add Age-Appropriate Story Length & Vocabulary System
**Branch:** `codex/age-appropriate-stories`
**Location:** Ubuntu
**Priority:** HIGH
**Estimated Time:** 1-2 hours

### Goal
Make stories adapt to the child's age with appropriate length, vocabulary complexity, and concepts.

### Requirements

**Age Brackets:**
- Ages 3-5: 100-150 words, very simple vocabulary (cat, dog, run, happy)
- Ages 6-8: 150-250 words, sight words + basic phonics
- Ages 9-12: 250-400 words, grade-level vocabulary
- Ages 13-15: 400-600 words, complex concepts
- Ages 16+: 600-800 words, mature themes

### Implementation

**Step 1: Create new service file**

Create `lib/services/story_complexity_service.dart`:

```dart
class StoryComplexityService {
  /// Get age-appropriate story guidelines
  static Map<String, dynamic> getAgeGuidelines(int age) {
    if (age <= 5) {
      return {
        'length_guideline': '100-150 words',
        'word_count_min': 100,
        'word_count_max': 150,
        'vocabulary_level': 'very simple',
        'sentence_structure': 'very short (3-6 words)',
        'vocabulary_examples': 'cat, dog, happy, sad, run, jump, play',
        'concepts': 'concrete and tangible only',
        'special_instructions': 'Use repetition for learning. No abstract ideas.',
      };
    } else if (age <= 8) {
      return {
        'length_guideline': '150-250 words',
        'word_count_min': 150,
        'word_count_max': 250,
        'vocabulary_level': 'simple',
        'sentence_structure': 'short and clear',
        'vocabulary_examples': 'sight words + CVC words (cat, bat, sit)',
        'concepts': 'simple cause and effect',
        'special_instructions': 'Include dialogue. Phonics-friendly words.',
      };
    } else if (age <= 12) {
      return {
        'length_guideline': '250-400 words',
        'word_count_min': 250,
        'word_count_max': 400,
        'vocabulary_level': 'grade-level',
        'sentence_structure': 'varied, some complex',
        'vocabulary_examples': 'adventurous, curious, determined, nervous',
        'concepts': 'multiple plot layers, character growth',
        'special_instructions': 'Show emotional depth. Problem-solving.',
      };
    } else if (age <= 15) {
      return {
        'length_guideline': '400-600 words',
        'word_count_min': 400,
        'word_count_max': 600,
        'vocabulary_level': 'advanced',
        'sentence_structure': 'sophisticated',
        'vocabulary_examples': 'contemplated, ambivalent, resilient',
        'concepts': 'complex themes, moral dilemmas, identity',
        'special_instructions': 'Nuanced emotions. Real-world parallels.',
      };
    } else {
      return {
        'length_guideline': '600-800 words',
        'word_count_min': 600,
        'word_count_max': 800,
        'vocabulary_level': 'adult',
        'sentence_structure': 'complex and literary',
        'vocabulary_examples': 'introspective, existential, paradoxical',
        'concepts': 'mature themes, philosophical questions',
        'special_instructions': 'Literary devices. Deep character psychology.',
      };
    }
  }

  /// Build age-appropriate instruction block for AI prompts
  static String buildAgeInstructions(int age) {
    final guidelines = getAgeGuidelines(age);

    return '''
AGE-APPROPRIATE GUIDELINES FOR ${age}-YEAR-OLD:
✓ LENGTH: ${guidelines['length_guideline']} (strict requirement!)
✓ VOCABULARY: ${guidelines['vocabulary_level']} - Examples: ${guidelines['vocabulary_examples']}
✓ SENTENCES: ${guidelines['sentence_structure']}
✓ CONCEPTS: ${guidelines['concepts']}
✓ SPECIAL NOTES: ${guidelines['special_instructions']}
''';
  }
}
```

**Step 2: Update api_service_manager.dart**

In `lib/services/api_service_manager.dart`:

2a. Add import at top:
```dart
import 'story_complexity_service.dart';
```

2b. Find `_buildTherapeuticPrompt` method (around line 161):

Add this AFTER the method signature but BEFORE the feelings section:
```dart
// Get age-appropriate guidelines
final ageInstructions = StoryComplexityService.buildAgeInstructions(age);
```

Then in the prompt string, add this section BEFORE the "STORY STRUCTURE:" part:
```dart
$ageInstructions

```

2c. Do the SAME for `_buildAdventurePrompt` method (around line 295)

2d. Find where `lengthGuideline` is calculated (it's in the `_buildStoryPrompt` method around line 410):

REPLACE the entire lengthGuideline calculation with:
```dart
final guidelines = StoryComplexityService.getAgeGuidelines(age);
String lengthGuideline = guidelines['length_guideline'];
```

**Step 3: Update Backend (optional but recommended)**

In `backend/app.py`, find the generate_story_endpoint function and add similar age-based guidelines to the backend prompts.

### Testing

Test stories at different ages:
```bash
# Test each age bracket
# Age 4: Should get ~120 words, simple words
# Age 7: Should get ~200 words, sight words
# Age 10: Should get ~300 words, grade-level
# Age 14: Should get ~500 words, complex
# Age 18: Should get ~700 words, mature
```

### Git Workflow
```bash
git checkout main
git pull origin main
git checkout -b codex/age-appropriate-stories
# Make changes
flutter build web --release
git add lib/services/story_complexity_service.dart lib/services/api_service_manager.dart
git commit -m "[Feature] Add age-appropriate story complexity system

- Created StoryComplexityService with 5 age brackets
- Ages 3-5: 100-150 words, simple vocabulary
- Ages 6-8: 150-250 words, phonics-friendly
- Ages 9-12: 250-400 words, grade-level
- Ages 13-15: 400-600 words, complex themes
- Ages 16+: 600-800 words, mature content
- Integrated into therapeutic and adventure prompts"
git push origin codex/age-appropriate-stories
```

---

## 📚 CODEX TASK 2: Learning to Read Mode (Rhyming Stories)
**Branch:** `codex/rhyming-reader-mode`
**Location:** Ubuntu
**Priority:** MEDIUM
**Estimated Time:** 1-2 hours
**Depends on:** CODEX TASK 1 (age-appropriate system)

See TASK_PLANS.md for detailed implementation - it's already documented there!

Quick summary:
- Add toggle for "Learning to Read Mode" in main_story.dart
- Create `_buildLearningToReadPrompt` in api_service_manager.dart
- 50-100 words, AABB rhyme scheme, CVC words only
- For ages 4-7

---

## 🎨 GEMINI TASK 2: Integrate Full Feelings Wheel UI
**Branch:** `gemini/feelings-wheel-ui`
**Location:** Ubuntu
**Priority:** MEDIUM
**Estimated Time:** 2-3 hours

See TASK_PLANS.md for detailed implementation - it's already documented there!

Quick summary:
- Replace 18-emotion grid with hierarchical wheel
- Use existing FeelingsWheelScreen component
- 3 levels: Core → Secondary → Tertiary (72+ emotions)
- Integrate into PreStoryFeelingsDialog

---

## 🔄 What Claude Will Do (Can't Delegate)

1. **Fix story generation error** - Need browser console debugging
2. **Complex architecture decisions** - Requires high-level reasoning
3. **Review & merge pull requests** - Quality control
4. **Handle unexpected build errors** - Advanced troubleshooting
5. **Update session documentation** - Session context understanding

---

## 📊 Task Priority Matrix

**Do Immediately (Claude):**
- Fix story generation error after getting console screenshot

**Do in Parallel (Gemini + Codex):**
- Gemini Task 1: Simplify form ⚡ HIGH - Quick win
- Codex Task 1: Age-appropriate stories ⚡ HIGH - Core feature

**Do Next (After Task 1):**
- Codex Task 2: Rhyming mode
- Gemini Task 2: Feelings wheel

---

## ⚙️ Setup Instructions for Ubuntu

**For Gemini:**
```bash
cd /mnt/c/dev/story-weaver-app  # or wherever the project is
git checkout main
git pull origin main
code .  # or your editor
# Read this file and GEMINI_CODEX_TASKS.md
# Start with GEMINI TASK 1
```

**For Codex:**
```bash
cd /mnt/c/dev/story-weaver-app-codex-dev  # or wherever
git checkout main
git pull origin main
code .
# Read CODEX TASK 1 in this file
# May need: flutter pub get
```

---

**Last Updated:** 2025-11-10
**Session Goal:** Maximize parallel development, minimize Claude usage
