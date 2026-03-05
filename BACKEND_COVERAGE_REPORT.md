# Backend Test Coverage Report
**Date:** 2026-02-13
**Overall Coverage:** 57%

## Coverage Summary by Module

| Module | Statements | Missed | Coverage |
|--------|------------|--------|----------|
| `app.py` | 275 | 75 | 73% |
| `middleware/auth.py` | 116 | 32 | 72% |
| `models/` | 183 | 7 | 96% |
| `repositories/` | 23 | 4 | 83% |
| `routes/character_routes.py` | 65 | 2 | 97% |
| `routes/story_routes.py` | 592 | 327 | 45% |
| `routes/stripe_routes.py` | 47 | 7 | 85% |
| `routes/subscription_routes.py` | 25 | 2 | 92% |
| `services/character_service.py` | 195 | 28 | 86% |
| `services/story_service.py` | 280 | 149 | 47% |
| `tasks/story_tasks.py` | 301 | 124 | 59% |
| **TOTAL** | **8661** | **3695** | **57%** |

## Analysis of Gaps

1. **Story Generation & Services (45-49%):** 
   - `story_routes.py` and `story_service.py` have significant uncovered logic related to real AI calls and complex branching which are currently mocked or bypassed in tests.
   - `interactive_adventure_service.py` (11%) needs much more coverage.

2. **Image Generation (10-14%):**
   - `gemini_image_generator.py`, `openrouter_image_generator.py`, and `replicate_image_generator.py` have low coverage as real external API calls are skipped.

3. **Utilities & Scripts (0-30%):**
   - Several maintenance scripts and migration tools have 0% coverage, which is acceptable as they are not part of the runtime API.

## Recommendations

1. **High Priority:**
   - Increase coverage for `InteractiveAdventureService`.
   - Add integration tests for `StoryTasks` with more varied payloads.
   - Add tests for `analytics_routes.py` (currently 47%).

2. **Maintenance:**
   - Continue to use mock-based testing for image generators but verify the logic that *prepares* the requests.
   - Address the 745 warnings (mostly deprecation warnings) to clean up test output.

## Test Statistics
- **Total Passed:** 297
- **Total Failed:** 0
- **Total Duration:** ~4 minutes
