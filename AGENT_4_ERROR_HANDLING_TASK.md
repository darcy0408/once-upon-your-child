# YOU ARE AGENT 4 - Error Handling & Loading UX

**⚠️ IMPORTANT: You are Agent 4. This is YOUR task file. Do NOT read other agent files.**

---

## Your Assignment

**Task:** Build reusable error handling + loading UI and wire it into key screens  
**Your Branch:** `feature/error-handling-improvements`  
**Estimated Time:** 2 days  
**Terminal:** WSL Codex

---

## BEFORE YOU START - Branch Verification

```bash
cd /mnt/c/dev/story-weaver-app
git checkout main
git pull origin main
git checkout -b feature/error-handling-improvements

# VERIFY BRANCH
git branch --show-current
# Must show: feature/error-handling-improvements
```
If it shows anything else, STOP and ask the supervisor.

---

## Your File Scope (ONLY TOUCH THESE)

✅ **You CAN modify / add:**
- `lib/widgets/error_boundary.dart` (CREATE)
- `lib/widgets/loading_overlay.dart` (CREATE)
- Wrap screens with error boundaries & overlay:
  - `lib/interactive_story_screen.dart`
  - `lib/story_result_screen.dart`
  - `lib/character_creation_screen_enhanced.dart`
  - `lib/onboarding_screen.dart`
- Improve error messaging/logging in services (pick highest impact, e.g.):
  - `lib/services/interactive_story_service.dart`
  - `lib/services/story_illustration_service.dart`
  - `lib/services/subscription_service.dart`
- Add tests for new widgets: `test/widgets/error_boundary_test.dart`, `test/widgets/loading_overlay_test.dart` (optional but recommended)
- `pubspec.yaml` (ONLY if a new dependency is required; prefer none)

❌ **DO NOT touch:**
- State management conversions (Agent 2 owns Riverpod work)  
- `lib/saved_stories_screen.dart` or `lib/settings_screen.dart` (avoid conflicts with Agent 2)  
- Backend files (`backend/**`)  
- Product copy or analytics events unless needed for error strings

---

## Step-by-Step Instructions

### Step 1: Create Error Boundary Widget (1-2 hours)

Goal: Catch widget tree errors and show a friendly fallback with retry.

- Implement `ErrorBoundary extends StatefulWidget` with:
  - `child`, optional `onRetry`, optional custom `fallback` builder.
  - `FlutterErrorDetails` capture inside `FlutterError.onError` or `runZonedGuarded` style guard; ensure it restores the previous handler in `dispose`.
  - Local `_hasError` flag; on error, render default fallback UI: icon, "Something went wrong" message, optional Retry button.
  - Log via existing logger (e.g., `LoggerService`) if available; otherwise `debugPrint`.
- Keep the fallback lightweight and accessible (Semantics, no infinite rebuild loops).

### Step 2: Create Loading Overlay Widget (45 minutes)

- Implement `LoadingOverlay` as a `Stack` overlay:
  - Props: `isLoading`, `child`, optional `message`.
  - Use `AnimatedOpacity`/`IgnorePointer` to block taps while loading.
  - Include centered `CircularProgressIndicator` + text; keep colors consistent with theme.
  - Provide a static helper `wrap` or simple usage via composition.

### Step 3: Wire Error Boundaries Into Screens (1-2 hours)

Wrap high-traffic screens without touching Agent 2's files:
- `interactive_story_screen.dart`: wrap main body in `ErrorBoundary(onRetry: _retryLoad or regenerate story)`; show `LoadingOverlay` during story generation/fetch.
- `story_result_screen.dart`: wrap result display; `onRetry` should re-fetch or navigate back safely.
- `character_creation_screen_enhanced.dart`: wrap the build; use `LoadingOverlay` around avatar/network operations.
- `onboarding_screen.dart`: wrap the top-level scaffold to catch onboarding flow crashes.

Guidelines:
- Keep diffs minimal; do not restructure state management.
- Use existing loading booleans/async calls; if absent, add a simple `bool _isLoading` toggle around async ops.
- Ensure fallbacks do not trap users (Retry should clear error state and re-run the last action).

### Step 4: Improve Service Error Messages (1 hour)

Focus on clarity and logging; avoid breaking APIs:
- Add contextual error messages (e.g., which endpoint/params) before rethrowing.
- Convert generic `Exception('Failed')` to more descriptive errors while preserving types.
- Use `LoggerService` (or existing logger) to log caught exceptions with stack traces.
- Do NOT expose secrets or raw API responses in user-facing strings; keep user messages friendly, logs detailed.

Suggested targets: `interactive_story_service.dart`, `story_illustration_service.dart`, `subscription_service.dart` (pick 2-3 key paths).

### Step 5: Tests (45 minutes)

- Add quick widget tests if time allows:
  - `error_boundary_test.dart`: child renders; fallback renders on thrown error; retry clears error.
  - `loading_overlay_test.dart`: overlay blocks taps when `isLoading == true`; hidden when false.
- Run:
```bash
flutter analyze
flutter test test/widgets/error_boundary_test.dart test/widgets/loading_overlay_test.dart
```

### Step 6: Final Verification & Report

- Run `flutter test` (full) after wiring changes.  
- Confirm no regressions on wrapped screens (manual sanity via `flutter run -d chrome` if time allows).  
- Update `TEAM_COORDINATION.md` (Phase 2 Wave 2) with files touched, test results, and status.  
- Push to `feature/error-handling-improvements`, then report:
```
✅ Agent 4 COMPLETE - Error boundaries + loading overlay added. Tests/analysis clean.
```

---

## Success Criteria

- Reusable `error_boundary.dart` and `loading_overlay.dart` committed.  
- Targeted screens wrapped with minimal code churn; no conflicts with Agent 2 files.  
- Clearer error messages + logging in selected services.  
- Tests/analyze pass; no new failing widget tests.  
- TEAM_COORDINATION updated with results and branch.

---

Stay scoped, avoid Riverpod files, and keep diffs focused. Good luck! 🛡️
