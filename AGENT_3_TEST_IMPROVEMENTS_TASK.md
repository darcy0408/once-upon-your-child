# YOU ARE AGENT 3 - Test Improvements

**⚠️ IMPORTANT: You are Agent 3. This is YOUR task file. Do NOT read other agent files.**

---

## Your Assignment

**Task:** Fix pre-existing test failures and add backend coverage  
**Your Branch:** `fix/test-improvements`  
**Estimated Time:** 2 days  
**Terminal:** WSL Codex

---

## BEFORE YOU START - Branch Verification

Run these commands and verify:

```bash
cd /mnt/c/dev/story-weaver-app
git checkout main
git pull origin main
git checkout -b fix/test-improvements

# VERIFY YOU'RE ON THE RIGHT BRANCH
git branch --show-current
# Must show: fix/test-improvements

# If it shows anything else, STOP and ask supervisor
```

---

## Your File Scope (ONLY TOUCH THESE)

✅ **You CAN modify:**
- `test/widgets/feelings_wheel_test.dart` (FIX existing failure)
- `test/widgets/character_creation_test.dart` (FIX avatar loading test)
- `backend/tests/**` (ADD coverage; create new files if needed)
- `backend/**` (ONLY if required to unblock tests or fix a bug revealed by tests)
- `lib/widgets/feelings_wheel.dart` (IF needed to fix widget test)
- `lib/avatar_models.dart` (IF needed to fix avatar URL/test)
- `pubspec.yaml` (ONLY to add a dev dependency for test stability, e.g., network_image_mock)

❌ **DO NOT touch:**
- State management code (Agent 2 owns Riverpod work)
- Error handling widgets (Agent 4 owns that)
- Other screens/features outside the tests listed

---

## Current Test Status

From TEAM_COORDINATION.md (Phase 2, Wave 2):

1) `test/widgets/feelings_wheel_test.dart` → `StateError: No element`  
2) `test/widgets/character_creation_test.dart` → Avatar loading error (HTTP 400 to DiceBear)

Backend tests currently pass (33/33) but need more coverage.

---

## Step-by-Step Instructions

### Step 1: Establish Baseline (20 minutes)

```bash
cd /mnt/c/dev/story-weaver-app

# Frontend failing files (confirm the exact errors)
flutter test test/widgets/feelings_wheel_test.dart
flutter test test/widgets/character_creation_test.dart

# Backend baseline (after `pip install -r requirements.txt` in backend/)
cd backend
python -m pytest tests/ -q
cd ..
```

Capture the exact stack traces before changing anything.

---

### Step 2: Fix Feelings Wheel Test (1-2 hours)

Goal: eliminate `StateError: Bad state: No element`.

- Ensure the test pumps the widget fully (`pumpWidget` + `pumpAndSettle` before/after taps).  
- Use `ensureVisible` before taps if the wheel scrolls.  
- Verify you are using the correct finder (text/key) that matches `FeelingsWheel`.  
- If the widget conditionally renders children, adjust the test to wait for them; only change `lib/widgets/feelings_wheel.dart` if the widget truly fails to render expected nodes.

Sanity pattern:
```dart
await tester.pumpWidget(
  MaterialApp(
    home: Scaffold(
      body: FeelingsWheel(onFeelingsSelected: (_) {}),
    ),
  ),
);
await tester.pumpAndSettle();
```

---

### Step 3: Fix Avatar Loading Test (1 hour)

Goal: stop HTTP 400s and stabilize the avatar test.

- Wrap the test body in `mockNetworkImagesFor` (add `network_image_mock` to `dev_dependencies` if missing).  
- Keep avatar assertions focused on rendering (e.g., `CircleAvatar` present) instead of real network fetches.  
- If URL generation is invalid, minimally patch `lib/avatar_models.dart` to produce a valid DiceBear URL (seed + allowed params) without breaking production behavior.

Snippet:
```dart
await mockNetworkImagesFor(() async {
  await tester.pumpWidget(
    const MaterialApp(home: CharacterCreationScreenEnhanced()),
  );
  await tester.pumpAndSettle();
  expect(find.byType(CircleAvatar), findsWidgets);
});
```

---

### Step 4: Add Backend Test Coverage (2-3 hours)

Objective: increase coverage in `backend/tests/` without breaking existing tests.

1) **Identify gaps:** skim `backend/tests/` and note untested routes/services (e.g., story generation queueing, task-status endpoint, webhook failure paths).  
2) **Create focused tests** (examples, adapt to actual code):
   - `backend/tests/test_story_generation_flow.py`: mock Celery task to ensure `/generate-story` returns 202 + `task_id`, and `/task-status/<id>` returns expected JSON for success/failure. Use `monkeypatch` to stub network/async work.  
   - `backend/tests/test_webhook_errors.py`: verify webhook rejects bad signatures/payloads with 400 and logs safely.  
   - `backend/tests/test_story_routes_errors.py`: cover error handling branches (e.g., invalid payloads, missing fields, rate limits if applicable).
3) **Guidelines:**
   - Use existing `client` fixture from `backend/tests/conftest.py`.  
   - Do not hit real network services (mock OpenRouter/DiceBear/Celery).  
   - Keep DB clean per test; rely on fixtures instead of manual cleanup.  
   - Prefer small, deterministic tests over integration with external systems.

---

### Step 5: Re-run All Tests (30 minutes)

```bash
# Frontend
flutter test

# Backend
cd backend
python -m pytest tests/ -v
cd ..
```

Ensure zero failures in both suites.

---

### Step 6: Update Test Notes (15 minutes)

- If helpful, append a short “How to run” section to `test/README.md` or add a `backend/tests/README.md` noting any new mocks/fixtures added for coverage. Keep it concise.

---

### Step 7: Commit and Push

```bash
git add test/ backend/tests/ lib/ pubspec.yaml
git commit -m "Fix: Stabilize widget tests and expand backend coverage"
git push origin fix/test-improvements
```

---

### Step 8: Report Completion

Post results to `TEAM_COORDINATION.md` under Phase 2 Wave 2 with:
- Files changed (front + backend tests, any code touched)  
- Before/after test results (flutter + pytest)  
- Notes on new backend coverage and any follow-ups  
- Status: ✅ COMPLETE

Then send supervisor update:
```
✅ Agent 3 COMPLETE - fix/test-improvements pushed. Widget tests fixed; backend coverage added; all tests passing.
```

---

## Success Criteria

- feelings_wheel_test passes (no StateError)  
- character_creation_test passes without real HTTP calls  
- Backend tests remain 33/33 + new coverage added (no regressions)  
- No new failing tests introduced  
- Network calls in tests are mocked  
- Documentation updated if new commands or mocks were added

---

## Quick Reminders

- Stay on branch `fix/test-improvements`.  
- Only touch files in the allowed scope.  
- Mock external dependencies; do not rely on network.  
- Do not merge to `main`—push to your branch and report.  
- If you hit blockers, stop and ask the supervisor.
