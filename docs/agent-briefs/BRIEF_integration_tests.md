# Brief: Build Out Flutter Integration Test Suite for Story Weaver

You are an implementation agent. Your job is to add `integration_test/` coverage for the critical user flows in Story Weaver so the solo developer stops finding regressions by manual clicking.

## Required tools
- File read/write access to a git worktree of `C:\dev\story-weaver-app` (see setup below)
- Bash/PowerShell to run `flutter test integration_test/...`
- Flutter SDK installed and on PATH

## Worktree setup (do this FIRST, before any other work)

The main repo has another Claude instance running in it. To avoid git index contamination from parallel `claude.exe` processes, you MUST work in an isolated worktree.

1. From your terminal (before launching/continuing this agent session), run:
   ```powershell
   cd C:\dev\story-weaver-app
   git worktree add C:\dev\story-weaver-app-tests -b agent/integration-tests
   cd C:\dev\story-weaver-app-tests
   ```
   This creates `C:\dev\story-weaver-app-tests` on a new branch `agent/integration-tests` based on `main`. **Use the absolute path `C:\dev\story-weaver-app-tests` — do NOT use `..\story-weaver-app-tests`, PowerShell will mis-interpret it and create a literal `..story-weaver-app-tests` folder inside the main repo.**

2. If launching Claude Code fresh, `cd` into the worktree first so the working directory is `C:\dev\story-weaver-app-tests`.

3. **All file paths in this brief that say `C:\dev\story-weaver-app\...` apply to your worktree at `C:\dev\story-weaver-app-tests\...`.** Read and write only inside the worktree.

4. When you finish, **do not merge or delete the worktree** — just leave the branch with the test files added. The developer will review, merge, and clean up via `git worktree remove C:\dev\story-weaver-app-tests` from the main repo.

If the worktree command fails because the path already exists, stop and tell the user — do not improvise.

## Project context
- Flutter app, repo at `C:\dev\story-weaver-app`. Windows host.
- Pubspec already declares `integration_test:` and `flutter_test:` under `dev_dependencies`. **Do not add new deps unless absolutely required.**
- Existing tests in `integration_test/`:
  - `story_creation_e2e_test.dart` — sample pattern using `MockClient` from `package:http/testing.dart` and `ApiServiceManager.setTestClient(...)`
  - `pick_a_path_*_test.dart` — adventure flow
- Existing unit tests in `test/unit/`, widget tests in `test/widget_test.dart` and `test/widgets/`.
- Helper code in `test/helpers/` — **read this first**, it has shared mocks/fixtures.
- The app's main entry is `lib/main.dart` exporting `app.main()`. Tests bootstrap via `import 'package:story_weaver_app/main.dart' as app;` then `app.main();` + `await tester.pumpAndSettle();`.

## Target flows (priority order)

### P0 — Hero Creator → Story Generation → Result Screen
Files involved (read these to know widget structure / keys):
- `lib/screens/wizard_steps/hero_creator_step.dart`
- `lib/screens/wizard_steps/hero_creator_story_type_page.dart`
- `lib/screens/wizard_steps/hero_creator_scene_page.dart`
- `lib/screens/wizard_steps/hero_creator_creative_brief.dart`
- `lib/screens/wizard_steps/companion_selector_step.dart`
- `lib/screens/wizard_steps/feeling_selection_step.dart`
- `lib/screens/wizard_steps/magic_review_step.dart`
- `lib/screens/wizard_steps/imagine_it_screen.dart`
- `lib/story_result_screen.dart`
- `lib/services/per_page_illustration_prefetcher.dart`
- `lib/widgets/per_page_illustration.dart`

Test should: launch app → navigate to wizard → fill each step with valid inputs → submit → assert result screen renders with mocked story + illustrations. Mock the backend via `MockClient` (see `integration_test/story_creation_e2e_test.dart` for the pattern).

### P1 — Avatar creation with reference photo
Recent commit `01859be6` is about hair preservation + MIME detection. Cover:
- Pick image from gallery (mock `image_picker`)
- Send to backend, assert correct MIME header and request shape
- Assert resulting avatar URL renders in the picker

Files: `lib/screens/avatar_picker_screen.dart`, `lib/screens/custom_pet_avatar_screen.dart`, `lib/screens/character_editor_screen.dart`.

### P2 — Subscription / paywall gating
Cover the free-tier monthly cap on image gen (commit `8c516e02`). Mock the subscription status, attempt to generate beyond cap, assert the upsell screen appears.

Files: `lib/screens/subscription_management_screen.dart`, `lib/screens/subscription_success_screen.dart`, plus whatever service gates image gen.

**Skip P2 if P0+P1 take more than 90 minutes.** Quality over coverage.

## Rules
1. **Reuse patterns from `integration_test/story_creation_e2e_test.dart`.** Do not invent a new approach.
2. **Read `test/helpers/` first** and reuse anything there before writing new fixtures.
3. **Mock external IO** — backend HTTP, image_picker, camera, shared_preferences if needed. Never hit real network.
4. **Add `Key`s only when necessary** — prefer `find.text()`, `find.byType()`, `find.byTooltip()`. If you must add a Key to lib code, name it `Key('test_<purpose>')` and add a one-line comment explaining why.
5. **Each test must pass before you commit.** Run with: `flutter test integration_test/<file>.dart -d windows` (or `-d chrome` if windows desktop isn't configured — try windows first, fall back).
6. **If a test reveals a real bug, do not fix it.** Mark the test `skip: 'BUG: <description> — see file:line'` and add the bug to a new file `docs/agent-briefs/reports/integration_test_findings.md`. The dev will triage.
7. **Do not touch `lib/` files** except to add necessary `Key`s. No refactoring, no "while I'm here" cleanup.

## Output / done when
- New files (inside the worktree): `integration_test/hero_to_result_e2e_test.dart`, `integration_test/avatar_reference_photo_test.dart` (and `integration_test/free_tier_cap_test.dart` if P2 reached).
- All new tests pass locally with `flutter test integration_test/<file>.dart`.
- One findings doc at `docs/agent-briefs/reports/integration_test_findings.md` listing any bugs surfaced (empty file is fine if none).
- Worktree left in place on branch `agent/integration-tests` with all new files unstaged or staged (do not commit, do not push).
- Hand-off message in chat:
  ```
  Worktree: C:\dev\story-weaver-app-tests (branch: agent/integration-tests)
  Integration tests added: <list of files>
  All passing: <yes/no — if no, which and why>
  Bugs surfaced: <count, see findings doc>
  Run all with: flutter test integration_test/
  To review: cd C:\dev\story-weaver-app-tests && git status
  To merge: from main repo, git merge agent/integration-tests
  To clean up: git worktree remove C:\dev\story-weaver-app-tests
  Next: wire into CI (separate task).
  ```

## Hard constraints — do NOT
- Do not add `flutter_driver` — `integration_test` package is sufficient.
- Do not add new pubspec dependencies.
- Do not modify existing tests.
- Do not commit, push, or merge. Leave the worktree branch with changes for review.
- Do not run the app (`flutter run`) — only `flutter test`.
- Do not work outside the worktree at `C:\dev\story-weaver-app-tests`. The main `C:\dev\story-weaver-app` checkout has another agent active.
- Do not remove the worktree when finished — the developer will do that after merging.
