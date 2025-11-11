# Task Plans for Multi-AI Development Session
## 2025-11-10 Continuation - Story Generation + Age-Appropriate Content

---

## 🎯 CLAUDE (You) - Story Generation Fix + Age-Appropriate System
**Branch:** `main`
**Priority:** CRITICAL

### Task 1: Fix Story Generation (IMMEDIATE)
**Problem:** Regular story generation broken (interactive works). Backend has fix but may not be deployed.

**Steps:**
1. Check if Railway auto-deployed from latest push (commit 68e8990)
2. If not deployed, trigger manual Railway deployment
3. Verify backend returns `"story"` field in response
4. Test story generation endpoint with curl
5. If backend issue persists, check backend logs on Railway

**Files to check:**
- `backend/app.py:680-686` - Has the fix (both "story" and "story_text" fields)
- Railway dashboard for deployment status

### Task 2: Age-Appropriate Story System
**Goal:** Stories adapt to child's age with appropriate length, vocabulary, and complexity

**Implementation:**
1. Create `lib/services/story_complexity_service.dart`
2. Define age brackets:
   - Ages 3-5: Very simple, 100-150 words, basic vocabulary
   - Ages 6-8: Simple, 150-250 words, sight words + phonics
   - Ages 9-12: Moderate, 250-400 words, grade-level vocabulary
   - Ages 13-15: Complex, 400-600 words, advanced concepts
   - Ages 16+: Adult, 600-800 words, mature themes

3. Update `lib/services/api_service_manager.dart`:
   - Add age-based length guidelines to prompts
   - Add vocabulary level instructions
   - Add complexity guidance (plot layers, character depth)

4. Modify prompt builders to include:
```dart
String _getAgeAppropriateGuidelines(int age) {
  if (age <= 5) {
    return '''
LENGTH: Keep story 100-150 words max
VOCABULARY: Use only simple, everyday words (cat, dog, happy, sad, run, jump)
SENTENCES: Very short (3-6 words). Simple subject-verb-object.
CONCEPTS: Concrete, tangible things. No abstract ideas.
REPETITION: Repeat key phrases for learning.
''';
  }
  // ... more age brackets
}
```

**Files to create/modify:**
- `lib/services/story_complexity_service.dart` (NEW)
- `lib/services/api_service_manager.dart:_buildTherapeuticPrompt`
- `lib/services/api_service_manager.dart:_buildAdventurePrompt`

---

## 📚 CODEX - Easy Rhyming Stories for Early Readers
**Branch:** Create new branch `codex/rhyming-reader-mode`
**Priority:** HIGH

### Task: Rhyming Story Mode for Learning to Read

**Goal:** Create simple, predictable rhyming stories that help kids learn to read

**Requirements:**
1. New story mode toggle: "Learning to Read Mode"
2. Stories with:
   - Simple rhyme scheme (AABB or ABAB)
   - Repetitive patterns kids can predict
   - Sight words and phonics-friendly words
   - 50-100 words total for ages 4-7
   - Clear rhythm and meter

**Implementation Steps:**

1. **Add UI Toggle** in `lib/main_story.dart`:
```dart
bool _learningToReadMode = false;

// Add switch in story options
SwitchListTile(
  title: Text('Learning to Read Mode'),
  subtitle: Text('Simple rhyming story for early readers (ages 4-7)'),
  value: _learningToReadMode,
  onChanged: (value) => setState(() => _learningToReadMode = value),
)
```

2. **Create Rhyming Prompt Builder** in `lib/services/api_service_manager.dart`:
```dart
static String _buildLearningToReadPrompt({
  required String characterName,
  required String theme,
  required int age,
  Map<String, dynamic>? characterDetails,
}) {
  return '''
You are creating a LEARNING TO READ story for a ${age}-year-old.

STRICT REQUIREMENTS:
✓ 50-100 words total (this is critical!)
✓ Simple AABB rhyme scheme (every 2 lines rhyme)
✓ Each line: 4-6 words maximum
✓ Use only CVC words (cat, dog, run, sit) and common sight words (the, and, can)
✓ Repetitive structure: "Can [character] [verb]? Yes! [Character] can [verb]!"
✓ No complex words, no exceptions to phonics rules

EXAMPLE FORMAT:
"$characterName likes to play.
$characterName runs every day.
Can $characterName jump? Yes, so high!
$characterName touches the sky!"

Create a ${theme} rhyming story about $characterName now:
''';
}
```

3. **Update Story Generation Call**:
   - Pass `learningToReadMode` flag to backend
   - Backend uses different prompt template
   - Validate response has rhymes and correct length

4. **Add Visual Enhancements** (optional):
   - Larger font size for easy reading
   - Highlight rhyming words in different colors
   - Add line breaks between rhyming couplets
   - Option to read line-by-line (show one line at a time)

**Files to modify:**
- `lib/main_story.dart` - Add UI toggle
- `lib/services/api_service_manager.dart` - Add rhyming prompt builder
- `backend/app.py` - Handle learning_to_read_mode parameter

**Testing:**
- Create stories for ages 4, 5, 6, 7
- Verify all rhyme
- Check word count stays 50-100
- Ensure only simple words used

**Branch commands:**
```bash
git checkout main
git pull origin main
git checkout -b codex/rhyming-reader-mode
# Do your work
git add .
git commit -m "[Feature] Add learning to read rhyming story mode for ages 4-7"
git push origin codex/rhyming-reader-mode
```

---

## 🎨 GEMINI - Full Feelings Wheel Integration
**Branch:** Create new branch `gemini/feelings-wheel-ui`
**Priority:** MEDIUM

### Task: Replace Simple Emotion Grid with Hierarchical Feelings Wheel

**Goal:** Integrate the full feelings wheel system that already exists in the codebase

**Current State:**
- `lib/feelings_wheel_screen.dart` EXISTS but is NOT integrated
- `lib/pre_story_feelings_dialog.dart` shows simple grid of 18 emotions
- Want: Full 3-level hierarchical wheel (Core → Secondary → Tertiary)

**Implementation Steps:**

1. **Understand Existing Feelings Wheel:**
   - Read `lib/feelings_wheel_data.dart` - Has full wheel data structure
   - Read `lib/feelings_wheel_screen.dart` - Has UI implementation
   - Current wheel has core emotions with secondary and tertiary levels

2. **Integrate into Pre-Story Dialog:**

Option A: Replace dialog entirely
```dart
// In lib/main_story.dart, replace PreStoryFeelingsDialog with:
final feeling = await Navigator.push(
  context,
  MaterialPageRoute(
    builder: (context) => FeelingsWheelScreen(
      currentFeeling: null,
    ),
  ),
);
```

Option B: Embed wheel into dialog
```dart
// In lib/pre_story_feelings_dialog.dart, replace the Wrap with emotion chips:
import 'feelings_wheel_screen.dart';

// Replace lines 129-183 with:
FeelingsWheelScreen(currentFeeling: _selectedFeeling)
```

3. **Update Feeling Data Structure:**
   - Convert `SelectedFeeling` from feelings_wheel_data to match `CurrentFeeling`
   - Ensure both have: emotion name, intensity, what happened, coping strategies
   - May need adapter/converter function

4. **Preserve Therapeutic Features:**
   - Keep intensity slider
   - Keep "what happened" text field
   - Keep physical signs and coping strategies display
   - Add them AFTER user selects tertiary feeling from wheel

5. **UI Flow:**
   - Show core emotions (Happy, Sad, Angry, Scared, Surprised, Calm)
   - User clicks core → Show secondary emotions
   - User clicks secondary → Show tertiary emotions
   - User clicks tertiary → Show intensity slider + "what happened" field
   - User clicks "Create Story" → Send to story generator

**Files to modify:**
- `lib/pre_story_feelings_dialog.dart` - Integrate wheel
- `lib/main_story.dart` - Update dialog call
- May need to modify `lib/feelings_wheel_screen.dart` to work in dialog mode

**Files to read first:**
- `lib/feelings_wheel_data.dart`
- `lib/feelings_wheel_screen.dart`
- `lib/pre_story_feelings_dialog.dart`

**Testing:**
- Click through all 3 levels of wheel
- Verify 72+ emotions available (not just 18)
- Test story generation with wheel-selected emotions
- Verify therapeutic prompts use tertiary emotion detail

**Branch commands:**
```bash
git checkout main
git pull origin main
git checkout -b gemini/feelings-wheel-ui
# Do your work
git add .
git commit -m "[Feature] Integrate hierarchical feelings wheel into pre-story dialog"
git push origin gemini/feelings-wheel-ui
```

---

## 🔄 Integration Plan

**Order of merging:**
1. Claude fixes story generation (merge to main immediately)
2. Claude adds age-appropriate system (merge to main, needed for other features)
3. Codex's rhyming mode (depends on #2, merge after testing)
4. Gemini's feelings wheel (independent, can merge anytime)

**Final Testing:**
- Create character (age 5) → Skip feelings → Get simple story (100 words)
- Create character (age 5) → Use feelings wheel → Get therapeutic rhyming story
- Create character (age 14) → Use feelings → Get complex story (500+ words)
- Verify all age ranges work (3-100)

---

**Last Updated:** 2025-11-10
**Session Goal:** Fix story generation + Add age-appropriate content + Full feelings wheel
