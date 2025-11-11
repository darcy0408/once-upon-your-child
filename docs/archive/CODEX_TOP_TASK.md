# CODEX TOP: Post-Story Emotional Check (Week 1 Task B)

## 🚫 RESET YOUR CONTEXT

**IGNORE everything about:**
- ❌ Achievements
- ❌ Achievement dialogs
- ❌ Achievement service
- ❌ Badges
- ❌ Previous work on other branches

**If you see files missing (like achievement_celebration_dialog.dart), this is CORRECT and EXPECTED.**

---

## 📍 Your Working Location

```bash
cd /mnt/c/dev/story-weaver-app
git checkout codex-post-story-check
git pull origin codex-post-story-check
```

**Branch:** `codex-post-story-check`
**Status:** Fresh start, no code written yet

---

## 🎯 Your Single Goal

Build a post-story emotional check dialog that shows children how their emotions improved after reading a story.

**Example:**
- Before story: Child felt "Worried 😟" with intensity 4/5
- After story: Dialog appears asking "How do you feel now?"
- Child selects "Worried 😟" with intensity 2/5
- App shows: "Worried went from 4 → 2 ⬇️ Great job!"

---

## 📖 READ THESE FILES FIRST

### 1. Read the full task specification:
```bash
cat CODEX_WEEK1_TASK_B.md
```
This has ALL the details you need.

### 2. Read the reset instructions:
```bash
cat CODEX_INSTRUCTIONS.md
```
This explains why achievement files don't exist.

### 3. Understand what already exists:
```bash
# Pre-story feelings dialog (USE AS REFERENCE)
cat lib/pre_story_feelings_dialog.dart

# Emotion data service (READ DATA FROM HERE)
cat lib/emotions_learning_system.dart

# Story result screen (MODIFY THIS)
cat lib/story_result_screen.dart

# Models (MODIFY SavedStory HERE)
cat lib/models.dart
```

---

## 📦 Files You Will Create/Modify

### CREATE:
1. **lib/post_story_feelings_dialog.dart**
   - Clone structure from `pre_story_feelings_dialog.dart`
   - Add comparison display (before vs after)
   - Add celebration for improvement
   - Make it skippable ("Not now" button)

### MODIFY:
2. **lib/models.dart**
   - Add to `SavedStory` class:
     ```dart
     class SavedStory {
       // ... existing fields ...

       // NEW FIELDS (add these)
       final Map<String, dynamic>? preStoryFeeling;
       final Map<String, dynamic>? postStoryFeeling;
       final int? emotionIntensityDelta; // pre - post (positive = improvement)
     ```

3. **lib/story_result_screen.dart**
   - Auto-show `PostStoryFeelingsDialog` 5 seconds after story loads
   - Pass pre-story feeling from constructor
   - Show emotion comparison if both exist
   - Save post-feeling to storage

4. **lib/main_story.dart**
   - Pass `preStoryFeeling` to `StoryResultScreen` constructor
   - This data already exists from `PreStoryFeelingsDialog`

---

## ✅ Acceptance Criteria

Before committing, verify:

- [ ] `PostStoryFeelingsDialog` exists and compiles
- [ ] Dialog appears 5 seconds after story ends
- [ ] Can select emotion and intensity (1-5)
- [ ] Shows comparison: "Worried went from 4 → 2 ⬇️"
- [ ] Has "Not now" button to skip
- [ ] SavedStory model has pre/post emotion fields
- [ ] Data saves to SharedPreferences
- [ ] No compile errors: `flutter analyze`
- [ ] No runtime crashes when opening story result

---

## 🧪 How to Test

### 1. Create test data:
```bash
# Run the app
flutter run
```

### 2. Test the flow:
1. Create a story (triggers pre-story feelings check)
2. Select emotion: "Worried 😟" intensity 4
3. Add context: "I'm worried about school"
4. Read the generated story
5. **Wait 5 seconds** on result screen
6. Post-story dialog should appear
7. Select "Worried 😟" intensity 2
8. See comparison: "Worried went from 4 → 2 ⬇️"

### 3. Test edge cases:
- Skip pre-check, see if post-check still works (should skip comparison)
- Skip post-check with "Not now"
- Select same intensity (no change)
- Select worse intensity (should show empathy, not celebration)

---

## 🚨 Common Mistakes to Avoid

1. **DON'T look for achievement files** - They're on a different branch
2. **DON'T create new SharedPreferences keys** - Use existing `SavedStory` model
3. **DON'T modify EmotionsLearningService** - Just read from it
4. **DO handle null pre-feelings** - User might skip pre-check
5. **DO use SunsetJungleTheme colors** - Match existing UI

---

## 🎨 UI Guidelines

Copy design from `pre_story_feelings_dialog.dart`:
- Use emotion wheel layout
- Use intensity slider (1-5)
- Use SunsetJungleTheme.creamLight background
- Use SunsetJungleTheme.jungleDeepGreen for text
- Use SunsetJungleTheme.sunsetCoral for accent

**Add comparison section:**
```dart
if (hasPreFeeling) {
  Card(
    child: Column(
      children: [
        Text('How you felt before:', style: bold),
        Text('${preEmotion} ${preEmoji} - Intensity ${preIntensity}'),
        SizedBox(height: 8),
        Text('How you feel now:', style: bold),
        Text('${postEmotion} ${postEmoji} - Intensity ${postIntensity}'),
        SizedBox(height: 8),
        _buildDeltaIndicator(delta), // ⬇️ or ⬆️ with color
      ],
    ),
  )
}
```

---

## 📝 Commit Message When Done

```bash
git add .
git commit -m "Add post-story emotional check dialog

- Create PostStoryFeelingsDialog with emotion/intensity selection
- Add preStoryFeeling, postStoryFeeling, emotionIntensityDelta to SavedStory
- Auto-show post-check 5 seconds after story in StoryResultScreen
- Display before/after comparison with improvement indicator
- Make skippable with 'Not now' button
- Handle edge cases (no pre-feeling, same intensity, worse intensity)

Completes Week 1 Task B: Post-story emotional check
Ref: CODEX_WEEK1_TASK_B.md"
```

---

## ❓ Questions?

1. **"I don't see achievement files"** → CORRECT. You're on a different branch.
2. **"Should I work on insights?"** → NO. That's a different Codex instance.
3. **"Where is EmotionCheckIn stored?"** → In `EmotionsLearningService`, you just read it.
4. **"Should I create new storage?"** → NO. Add fields to existing `SavedStory` model.

---

## 🚀 Start Command

```bash
# 1. Get on right branch
git checkout codex-post-story-check
git pull origin codex-post-story-check

# 2. Read the full spec
cat CODEX_WEEK1_TASK_B.md

# 3. Start coding
# Create lib/post_story_feelings_dialog.dart
```

**Focus only on this task. Ignore everything else.**

---

**Estimated Time:** 2-3 hours
**Priority:** P0 (blocking Week 1 completion)
**Success Metric:** Parents see emotion improvement after stories
