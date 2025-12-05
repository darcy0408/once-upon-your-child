# Phase 2 Wave 2 - Deployment Instructions

**Status:** ✅ READY TO DEPLOY
**Agents:** 3 agents working in parallel
**Strategy:** Non-overlapping file scopes to prevent conflicts
**Estimated Completion:** 2-3 days with all agents running concurrently

---

## Agent Overview

| Agent | Task | Branch | Files | Conflicts |
|-------|------|--------|-------|-----------|
| **Agent 2** | Riverpod State Management | `feature/riverpod-state-management` | `lib/providers/*`, `lib/main.dart`, `lib/saved_stories_screen.dart`, `lib/settings_screen.dart` | ❌ None |
| **Agent 3** | Test Improvements | `fix/test-improvements` | `test/**`, `backend/tests/**`, minimal widget fixes | ❌ None |
| **Agent 4** | Error Handling & Loading UX | `feature/error-handling-improvements` | `lib/widgets/error_boundary.dart`, `lib/widgets/loading_overlay.dart`, `lib/*_screen.dart` (except saved_stories, settings) | ❌ None |

---

## Deployment Commands

### Agent 2 (Riverpod State Management)

**Terminal:** WSL Codex #1

```bash
Read and follow the instructions in AGENT_2_RIVERPOD_TASK.md

This file contains everything you need for your Riverpod state management task.
Start with the branch verification section, then proceed step-by-step.
```

**What Agent 2 will do:**
- Add flutter_riverpod dependencies
- Create `lib/providers/story_provider.dart` and `lib/providers/theme_provider.dart`
- Convert `SavedStoriesScreen` to `ConsumerWidget`
- Convert `SettingsScreen` to use `ThemeModeProvider`
- Wrap app with `ProviderScope` in `main.dart`
- Remove all `setState` calls from converted screens
- Run `build_runner` to generate `.g.dart` files
- Test dark mode persistence and state management

**Expected outcome:** Centralized state management, better performance, no props drilling

---

### Agent 3 (Test Improvements)

**Terminal:** WSL Codex #2

```bash
Read and follow the instructions in AGENT_3_TEST_IMPROVEMENTS_TASK.md

This file contains everything you need for fixing test failures and improving coverage.
Start with the branch verification section, then proceed step-by-step.
```

**What Agent 3 will do:**
- Fix `feelings_wheel_test.dart` (StateError: No element)
- Fix `character_creation_test.dart` (avatar loading HTTP 400)
- Add network mocking with `network_image_mock` package
- Add backend test coverage for untested routes
- Mock Celery/OpenRouter/external services in tests
- Ensure all tests pass (target: 38+/38 frontend, 33+/33 backend)

**Expected outcome:** All tests passing, better test coverage, no real HTTP calls in tests

---

### Agent 4 (Error Handling & Loading UX)

**Terminal:** Gemini CLI (or WSL Codex #3)

```bash
Read and follow the instructions in AGENT_4_ERROR_HANDLING_TASK.md

This file contains everything you need for error handling and loading UX improvements.
Start with the branch verification section, then proceed step-by-step.
```

**What Agent 4 will do:**
- Create `lib/widgets/error_boundary.dart` (catches widget errors gracefully)
- Create `lib/widgets/loading_overlay.dart` (consistent loading indicators)
- Wrap `interactive_story_screen.dart` with error boundary + loading
- Wrap `story_result_screen.dart` with error boundary
- Add loading overlay to `character_creation_screen_enhanced.dart`
- Improve error messages in services (user-friendly, not technical)
- Add better logging for debugging

**Expected outcome:** Professional error handling, consistent loading states, user-friendly messages

---

## Coordination Strategy

### No File Conflicts

The tasks have been carefully scoped to avoid conflicts:

**Agent 2 owns:**
- `lib/saved_stories_screen.dart`
- `lib/settings_screen.dart`
- `lib/main.dart`
- `lib/providers/*` (new directory)

**Agent 3 owns:**
- `test/**` files
- `backend/tests/**` files
- Minimal widget/service fixes only as needed for tests

**Agent 4 owns:**
- `lib/widgets/error_boundary.dart` (new file)
- `lib/widgets/loading_overlay.dart` (new file)
- `lib/interactive_story_screen.dart`
- `lib/story_result_screen.dart`
- `lib/character_creation_screen_enhanced.dart`
- Service layer error messages

**Note:** Agents 3 and 4 will NOT touch `saved_stories_screen.dart` or `settings_screen.dart` to avoid conflicts with Agent 2.

---

## Success Criteria

Before merging each branch, verify:

### Agent 2 (Riverpod)
- [ ] Riverpod dependencies installed
- [ ] Providers created with code generation
- [ ] SavedStoriesScreen is ConsumerWidget (no setState)
- [ ] SettingsScreen uses theme provider
- [ ] App wrapped with ProviderScope
- [ ] Dark mode persists across app restarts
- [ ] All tests pass
- [ ] `.g.dart` files committed

### Agent 3 (Tests)
- [ ] feelings_wheel_test passes
- [ ] character_creation_test passes
- [ ] Network calls mocked in tests
- [ ] Backend coverage increased
- [ ] All tests passing (38+/38 frontend, 33+/33 backend)
- [ ] No new test failures

### Agent 4 (Error Handling)
- [ ] ErrorBoundary widget created
- [ ] LoadingOverlay widget created
- [ ] 3+ screens wrapped with error boundaries
- [ ] User-friendly error messages in services
- [ ] No technical errors shown to users
- [ ] All tests still pass
- [ ] Manual testing completed

---

## Merge Order

Once all agents report complete:

1. **Agent 3** (Tests) - Merge first
   - Ensures test infrastructure is solid
   - Branch: `fix/test-improvements` → `main`

2. **Agent 4** (Error Handling) - Merge second
   - Adds error boundaries and loading UX
   - Branch: `feature/error-handling-improvements` → `main`

3. **Agent 2** (Riverpod) - Merge last
   - State management changes build on stable tests and error handling
   - Branch: `feature/riverpod-state-management` → `main`

**Rationale:** Tests first ensure quality, error handling provides safety, Riverpod refactor happens on stable foundation.

---

## Monitoring During Development

Agents will report status in `TEAM_COORDINATION.md` under **Phase 2 Wave 2** section.

Watch for:
- Branch confusion (like Wave 1)
- Agents working on wrong files
- Test failures blocking progress
- Git conflicts (unlikely with current scoping)

---

## Ready to Deploy?

When ready, open 3 terminal windows and give each agent their instruction:

**Terminal 1 (WSL Codex):**
```
Read and follow the instructions in AGENT_2_RIVERPOD_TASK.md
```

**Terminal 2 (WSL Codex):**
```
Read and follow the instructions in AGENT_3_TEST_IMPROVEMENTS_TASK.md
```

**Terminal 3 (Gemini CLI or WSL Codex):**
```
Read and follow the instructions in AGENT_4_ERROR_HANDLING_TASK.md
```

All agents will work in parallel without conflicts! 🚀

---

## Need Help?

If issues arise:
- Check `TEAM_COORDINATION.md` for agent status
- Verify agents are on correct branches
- Check for unexpected file modifications
- Ask supervisor (Claude) for coordination help

Good luck! This wave will add significant quality improvements to the app.
