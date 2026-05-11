# Brief: Add Debug-Build Bypass for COPPA Parental Consent Gate

You are an implementation agent. Your job is to add a development-only way to skip the parental consent screen so Playwright-driven smoke tests can run end-to-end.

## Why this matters
The Playwright smoke test (`docs/agent-briefs/PLAYWRIGHT_SMOKE_TEST.md`) gets stuck at the COPPA consent gate because Flutter web canvas mode rejects programmatic scrolling — the "scroll-through-the-notice" requirement can't be satisfied from automation. Without a bypass, we can't smoke-test anything past onboarding.

## Required tools
- File read/write access to a git worktree at `C:\dev\story-weaver-app-coppa` (set up below)
- Flutter SDK for `flutter analyze` / `flutter build web` to verify

## Worktree setup (do this FIRST)

The main repo has another agent active. Work in an isolated worktree:

```powershell
cd C:\dev\story-weaver-app
git worktree add C:\dev\story-weaver-app-coppa -b agent/coppa-debug-bypass
cd C:\dev\story-weaver-app-coppa
```

**Use the absolute path** — `..\name` will mis-resolve on Windows PowerShell (verified gotcha). All file paths below apply to your worktree.

## Project context

- Flutter app at `C:\dev\story-weaver-app` (you work in `C:\dev\story-weaver-app-coppa`).
- The parental consent screen is at `lib/screens/parental_consent_screen.dart` — read it first.
- It requires the user to (1) scroll a notice to the bottom, (2) tick a checkbox, (3) tap "Give Permission".
- Result is persisted (likely via SharedPreferences or Isar). Find where, you'll need it.
- The smoke-test runbook at `docs/agent-briefs/PLAYWRIGHT_SMOKE_TEST.md` describes what we're enabling.

## Requirements

1. **Debug-only**. Bypass must NOT affect release builds. Use `kDebugMode` from `flutter/foundation.dart` to gate it.

2. **Two acceptable forms** (pick whichever fits cleanest — your call):
   - **Form A — URL param:** when `?bypass_consent=1` is on the URL AND `kDebugMode`, auto-grant consent and skip the screen. Read query params via `Uri.base.queryParameters`.
   - **Form B — env-style flag:** an `--dart-define=BYPASS_CONSENT=true` compile-time const that, when true AND `kDebugMode`, auto-grants consent.
   
   Form A is easier for Playwright (just change URL). Prefer Form A unless there's a strong reason against it.

3. **Auto-grant must look like a real grant.** Persist the consent record the same way a real grant does — same field names, same storage location. Otherwise downstream code that reads the consent state breaks.

4. **Add ONE log line** when bypass triggers: `debugPrint('🔓 COPPA consent bypassed (debug build, bypass_consent flag)');` so it's obvious in console.

5. **Verify**:
   - `flutter analyze` clean
   - `flutter build web --no-tree-shake-icons` succeeds
   - Manual sanity check: read your diff and confirm the bypass path is unreachable in release mode (no `kDebugMode &&` removed accidentally)

6. **Do NOT**:
   - Modify production logic
   - Change the consent UI (don't add a "Skip" button)
   - Touch Sentry, Stripe, TTS, or anything unrelated
   - Commit or push — leave the change for review

## Output / done when

- File(s) modified in your worktree, change minimal (likely <30 lines).
- `flutter analyze` passes.
- `flutter build web` succeeds.
- Hand-off message in chat:
  ```
  Worktree: C:\dev\story-weaver-app-coppa (branch: agent/coppa-debug-bypass)
  Bypass mechanism: <Form A url param | Form B dart-define>
  How to trigger: <exact URL or build flag>
  Files changed: <list>
  Analyze + build: passing
  To review: cd C:\dev\story-weaver-app-coppa && git status && git diff
  To merge: from main repo, git merge agent/coppa-debug-bypass
  To clean up: git worktree remove C:\dev\story-weaver-app-coppa
  ```
