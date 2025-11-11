# Messages for Codex Instances

## 📨 Message for CODEX TOP

```
RESET YOUR CONTEXT. Discard all previous work.

Your task: Build post-story emotional check dialog

Read this file:
git checkout codex-post-story-check
git reset --hard origin/codex-post-story-check
git pull origin codex-post-story-check
cat CODEX_TOP_TASK.md

Follow the instructions exactly. You are building the POST-STORY emotion check that compares before/after feelings.

The achievement files you mentioned earlier DON'T EXIST on your branch. This is CORRECT and EXPECTED.

Start here:
cat CODEX_WEEK1_TASK_B.md
```

---

## 📨 Message for CODEX BOTTOM

```
RESET YOUR CONTEXT. Discard your analyzer cleanup work.

Your task: Build emotion insights dashboard

Read this file:
git checkout codex-dev
git reset --hard origin/codex-dev
git pull origin codex-dev
cat CODEX_BOTTOM_TASK.md

Follow the instructions exactly. You are building the INSIGHTS DASHBOARD that shows 7-day emotion patterns to parents.

The analyzer cleanup you did is NOT needed right now. Focus only on building the insights dashboard.

Start here:
cat CODEX_WEEK1_TASK.md
```

---

## 🎯 Summary

**Codex Top (codex-post-story-check):**
- Build: `lib/post_story_feelings_dialog.dart`
- Modify: `lib/models.dart`, `lib/story_result_screen.dart`, `lib/main_story.dart`
- Goal: Show emotion improvement after story

**Codex Bottom (codex-dev):**
- Build: `lib/services/emotion_insights_service.dart`, `lib/insights_screen.dart`
- Modify: `lib/main_story.dart` (add Insights tab)
- Goal: Dashboard showing 7-day emotion trends

Both tasks are ISOLATED on different branches. No conflicts possible.
