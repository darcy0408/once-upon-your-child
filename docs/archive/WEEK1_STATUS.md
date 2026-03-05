# Week 1 MVP Status - Emotion Processing Loop

## 🎯 Current Status: Ready for Codex Implementation

Both parallel tasks are set up and ready for Codex instances to begin work.

---

## 📋 Task Assignments

### Codex Instance A: Emotion Insights Dashboard
**Branch:** `codex-dev`
**Task File:** `CODEX_WEEK1_TASK.md`
**Status:** ⏳ NOT STARTED

**What to Build:**
- `lib/services/emotion_insights_service.dart` - Service to calculate emotion trends
- `lib/insights_screen.dart` - Dashboard UI showing 7-day emotion patterns
- Modify `lib/main_story.dart` - Add "Insights" navigation tab

**Success Criteria:**
- Shows total check-ins, unique emotions, most common emotion
- Displays emotion frequency list with average intensity
- Empty state when no data exists
- Loading state while fetching data
- Works offline with cached data

**How to Start:**
```bash
cd /mnt/c/dev/story-weaver-app
git checkout codex-dev
git pull origin codex-dev
# Read CODEX_WEEK1_TASK.md and follow instructions
```

---

### Codex Instance B: Post-Story Emotional Check
**Branch:** `codex-post-story-check`
**Task File:** `CODEX_WEEK1_TASK_B.md`
**Status:** ⏳ NOT STARTED

**What to Build:**
- `lib/post_story_feelings_dialog.dart` - Post-story emotion check dialog
- Modify `lib/models.dart` - Add pre/post emotion fields to SavedStory
- Modify `lib/story_result_screen.dart` - Show post-check after story
- Modify `lib/main_story.dart` - Pass pre-feeling to result screen

**Success Criteria:**
- Auto-shows 5 seconds after story completion
- Compares before/after emotion intensity
- Shows improvement: "Worried went from 4 → 2 ⬇️"
- Skippable with "Not now" button
- Saves both pre and post emotions

**How to Start:**
```bash
cd /mnt/c/dev/story-weaver-app
git checkout codex-post-story-check
git pull origin codex-post-story-check
# Read CODEX_WEEK1_TASK_B.md and follow instructions
```

---

## 🔄 Integration Plan

After both tasks are complete:

1. **Review Codex A's Work (Insights Dashboard)**
   - Test dashboard with real emotion data
   - Verify calculations are correct
   - Check UI matches design system
   - Merge `codex-dev` → `main`

2. **Review Codex B's Work (Post-Story Check)**
   - Test pre/post emotion flow
   - Verify data is saved correctly
   - Check comparison UI
   - Merge `codex-post-story-check` → `main`

3. **End-to-End Testing**
   - Test complete flow: pre-check → story → post-check → insights
   - Verify data flows between features
   - Fix any integration bugs
   - Deploy to production

---

## 📊 Dependencies

### What Already Exists (DO NOT MODIFY):
- ✅ `lib/emotions_learning_system.dart` - Emotion data models and service
  - `EmotionCheckIn` class - stores emotion data
  - `EmotionsLearningService.getCheckIns()` - retrieves check-ins
  - `EmotionsLearningService.getEmotionById()` - gets emotion metadata

- ✅ `lib/pre_story_feelings_dialog.dart` - Pre-story emotion check
  - Shows emotion wheel, intensity slider, context field
  - Returns `CurrentFeeling` object
  - Already integrated into story creation flow

- ✅ `lib/services/api_service_manager.dart` - Story generation with feelings
  - Accepts `currentFeeling` parameter
  - Passes emotion data to AI for therapeutic story generation

- ✅ Backend feelings support
  - `/generate-story` endpoint accepts `current_feeling`
  - Emotion-centered story prompts implemented

### What Needs to Be Created:
- ❌ `lib/services/emotion_insights_service.dart` ← Codex A
- ❌ `lib/insights_screen.dart` ← Codex A
- ❌ `lib/post_story_feelings_dialog.dart` ← Codex B
- ❌ Navigation tab for Insights ← Codex A
- ❌ Pre/post emotion fields in SavedStory ← Codex B
- ❌ Post-check integration in StoryResultScreen ← Codex B

---

## 🧪 Testing Checklist

Before marking tasks complete, Codex should test:

### Task A (Insights Dashboard):
- [ ] Works with 0 check-ins (empty state)
- [ ] Works with 1 check-in
- [ ] Works with 10+ check-ins
- [ ] Works with data older than 7 days (filtered out)
- [ ] Calculations are correct (count, averages)
- [ ] Emoji displays correctly
- [ ] Navigation works (can go to insights and back)
- [ ] No console errors or warnings

### Task B (Post-Story Check):
- [ ] Dialog appears 5 seconds after story
- [ ] Can be dismissed with "Not now"
- [ ] Can select emotion and intensity
- [ ] Comparison shows correct before/after
- [ ] Data is saved to SavedStory
- [ ] Pre-feeling is passed from story creation
- [ ] Works when user skips pre-check (handles null)
- [ ] No crashes or errors

---

## 🚨 Common Pitfalls to Avoid

1. **Don't modify emotion check-in logic** - just read existing data
2. **Don't add new SharedPreferences keys** - use existing `EmotionsLearningService`
3. **Handle null/empty gracefully** - users might have no data
4. **Match existing UI patterns** - use `SunsetJungleTheme` colors
5. **Test with real data** - create some stories first to populate check-ins
6. **Don't overcomplicate** - This is MVP, keep it simple

---

## 🎯 Week 1 Goal

Ship the core emotional processing loop:

**Check-in (pre-story)** → **Personalized Story** → **Check-out (post-story)** → **Insights Dashboard**

This is the foundation for all parent connection features in Week 2.

---

## 📞 Questions?

If Codex gets stuck:
1. Check existing emotion service methods in `emotions_learning_system.dart`
2. Look at how other screens handle loading/empty states
3. Test with print statements to debug calculations
4. Report blocker and wait for Claude review

---

**Created:** November 6, 2025
**Last Updated:** November 6, 2025
**Status:** 🟢 Ready for Codex to begin implementation
