# Phase 2 Wave 3 - Deployment Instructions

**Status:** ✅ READY TO DEPLOY
**Agents:** 3 agents working in parallel
**Strategy:** Non-overlapping file scopes to prevent conflicts
**Estimated Completion:** 2-3 days with all agents running concurrently

---

## Agent Overview

| Agent | Task | Branch | Files | Conflicts |
|-------|------|--------|-------|-----------|
| **Agent 2** | Riverpod Expansion | `feature/riverpod-expansion` | `lib/providers/*`, `lib/quick_story_screen.dart`, `lib/character_creation_screen_enhanced.dart`, `lib/main_story.dart` | ❌ None |
| **Agent 3** | E2E Testing & Monitoring | `feature/e2e-testing-monitoring` | `test_driver/**`, `test/integration/**`, `backend/logging_config.py`, `backend/monitoring.py` | ❌ None |
| **Agent 4** | UI Polish & Animations | `feature/ui-polish-animations` | `lib/widgets/**`, `lib/theme/animations.dart`, `lib/story_result_screen.dart`, `lib/interactive_story_screen.dart`, `lib/onboarding_screen.dart` | ❌ None |

---

## Prerequisites

Before deploying Wave 3, ensure Wave 2 is merged:

```bash
# Check that these are merged to main:
git log --oneline | grep -E "(Riverpod|test-improvements|error-handling)"

# Should see commits like:
# - Feature: Implement Riverpod state management
# - Fix: Stabilize widget tests and expand backend coverage
# - Feature: Add error boundaries and loading UX improvements
```

---

## Deployment Commands

### Agent 2 (Riverpod Expansion)

**Terminal:** WSL Codex #1

```
Read and follow the instructions in AGENT_2_RIVERPOD_EXPANSION_TASK.md

This file contains everything you need to expand Riverpod to all major screens.
Start with the branch verification section, then proceed step-by-step.
```

**What Agent 2 will do:**
- Create `character_provider.dart` for character CRUD
- Create `quick_story_provider.dart` for story generation state
- Create `subscription_provider.dart` for paywall/tier management
- Convert `QuickStoryScreen`, `CharacterCreationScreen`, `MainStoryScreen` to Riverpod
- Add paywall UI when daily limit reached
- Test state persistence and Riverpod integration

**Expected outcome:** Complete Riverpod coverage across app, no setState in major screens

---

### Agent 3 (E2E Testing & Monitoring)

**Terminal:** WSL Codex #2

```
Read and follow the instructions in AGENT_3_E2E_TESTING_TASK.md

This file contains everything you need for E2E testing and backend monitoring.
Start with the branch verification section, then proceed step-by-step.
```

**What Agent 3 will do:**
- Create E2E tests with Flutter Driver
- Add integration tests for providers
- Set up backend logging with structured logging
- Add backend monitoring with metrics
- Create `/admin/metrics` and `/health/detailed` endpoints
- Test complete user flows end-to-end

**Expected outcome:** Comprehensive E2E test coverage, production-ready monitoring

---

### Agent 4 (UI Polish & Animations)

**Terminal:** WSL Codex #3

```
Read and follow the instructions in AGENT_4_UI_POLISH_TASK.md

This file contains everything you need for UI polish and animations.
Start with the branch verification section, then proceed step-by-step.
```

**What Agent 4 will do:**
- Create animation constants and utilities
- Build `AnimatedStoryCard` with staggered entrance
- Build `CustomPageRoute` with multiple transition types
- Build `ShimmerPlaceholder` for loading states
- Build `BounceButton` for tactile feedback
- Add animations to `StoryResultScreen`, `InteractiveStoryScreen`, `OnboardingScreen`

**Expected outcome:** Polished, professional UI with smooth animations

---

## Coordination Strategy

### No File Conflicts

The tasks are scoped to avoid conflicts:

**Agent 2 owns:**
- `lib/providers/*` (new files)
- `lib/quick_story_screen.dart`
- `lib/character_creation_screen_enhanced.dart`
- `lib/main_story.dart`
- `lib/onboarding_screen.dart`

**Agent 3 owns:**
- `test_driver/**` (new directory)
- `test/integration/**`
- `backend/logging_config.py` (new file)
- `backend/monitoring.py` (new file)
- `backend/app.py` (add logging only)

**Agent 4 owns:**
- `lib/widgets/**` (new animated widgets)
- `lib/theme/animations.dart` (new file)
- `lib/story_result_screen.dart` (add animations only)
- `lib/interactive_story_screen.dart` (add page transitions only)

**Potential overlap:**
- `lib/onboarding_screen.dart` - Both Agent 2 and Agent 4 may touch this
  - **Resolution:** Agent 2 converts state to Riverpod, Agent 4 adds animations
  - Agent 2 should finish first, then Agent 4 adds animations on top

---

## Success Criteria

### Agent 2 (Riverpod Expansion)
- [ ] 3 new providers created with code generation
- [ ] 3 screens converted to ConsumerWidget/ConsumerStatefulWidget
- [ ] Paywall UI shows when limit reached
- [ ] All tests pass
- [ ] State persists across navigation

### Agent 3 (E2E Testing & Monitoring)
- [ ] E2E tests run successfully via `flutter drive`
- [ ] Integration tests pass
- [ ] Backend logging configured
- [ ] Metrics endpoint returns data
- [ ] Health endpoint shows system stats

### Agent 4 (UI Polish & Animations)
- [ ] 5 new animated widgets created
- [ ] Animations smooth on web
- [ ] Loading states use shimmer
- [ ] Buttons have tactile feedback
- [ ] Page transitions feel professional

---

## Merge Order

Once all agents report complete:

1. **Agent 3** (E2E Testing & Monitoring) - Merge first
   - Provides test infrastructure for other features
   - Branch: `feature/e2e-testing-monitoring` → `main`

2. **Agent 2** (Riverpod Expansion) - Merge second
   - Completes state management migration
   - Branch: `feature/riverpod-expansion` → `main`

3. **Agent 4** (UI Polish & Animations) - Merge last
   - Adds polish on top of stable functionality
   - Branch: `feature/ui-polish-animations` → `main`

**Rationale:** Tests first ensure quality, Riverpod provides functionality, animations add polish.

---

## Monitoring During Development

Agents will report status in `TEAM_COORDINATION.md` under **Phase 2 Wave 3** section.

Watch for:
- Onboarding screen conflicts (Agent 2 vs Agent 4)
- E2E tests taking too long (optimize if needed)
- Animation performance issues on web
- Riverpod provider circular dependencies

---

## Ready to Deploy?

When ready, open 3 terminal windows and give each agent their instruction:

**Terminal 1 (WSL Codex #1):**
```
Read and follow the instructions in AGENT_2_RIVERPOD_EXPANSION_TASK.md
```

**Terminal 2 (WSL Codex #2):**
```
Read and follow the instructions in AGENT_3_E2E_TESTING_TASK.md
```

**Terminal 3 (WSL Codex #3):**
```
Read and follow the instructions in AGENT_4_UI_POLISH_TASK.md
```

All agents will work in parallel without conflicts! 🚀

---

## After Wave 3 Completion

With Wave 3 complete, the app will have:

✅ **Complete Riverpod State Management** - All major screens using providers
✅ **Comprehensive Testing** - Unit, integration, E2E, and backend tests
✅ **Production Monitoring** - Logging, metrics, health checks
✅ **Professional UI/UX** - Animations, transitions, loading states
✅ **Error Handling** - Graceful fallbacks, user-friendly messages
✅ **Offline Support** - Isar database for local storage
✅ **Async Processing** - Celery for background tasks
✅ **Accessibility** - Semantic labels, tooltips
✅ **Security** - Sentry crash reporting, secure storage

**The app will be production-ready!** 🎉

---

## Future Waves (Optional)

If desired, future waves could add:
- Wave 4: Internationalization (i18n) + Localization
- Wave 5: Advanced analytics dashboard
- Wave 6: Push notifications
- Wave 7: Social sharing features
- Wave 8: In-app purchases (if not using Stripe subscriptions)

But with Wave 3 complete, you'll have a solid, polished, production-quality app!
