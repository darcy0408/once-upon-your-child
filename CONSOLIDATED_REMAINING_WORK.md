# Consolidated Remaining Work

## Outstanding Validation, Testing, and Hardening

1. Run manual visual QA on crystal/orb animations and tune timing if needed (`TEAM_COORDINATION.md:2615`, `TEAM_COORDINATION.md:2616`).
2. Do a performance/latency audit under load for story generation (429/reset behavior and async fallback paths were noted) (`TEAM_COORDINATION.md:797`, `TEAM_COORDINATION.md:798`, `TEAM_COORDINATION.md:803`).
3. Add frontend screen/widget coverage still called out in backlog docs (wizard step screens, settings, character library, story reader, coloring) (`REMAINING_TASKS_2026-02-16.md:104`, `REMAINING_TASKS_2026-02-16.md:105`, `REMAINING_TASKS_2026-02-16.md:106`).
4. Add additional service test coverage for avatar/achievement/analytics areas (`REMAINING_TASKS_2026-02-16.md:5`, `COMPREHENSIVE_TEST_REPORT_2026-02-16.md:174`).
5. Complete manual content quality passes across age bands and modes (the docs still track this as partial) (`REMAINING_TASKS_2026-02-16.md:8`).
6. Complete cross-browser verification matrix (desktop + mobile browsers) (`REMAINING_TASKS_2026-02-16.md:6`).
7. Close security hardening gaps still listed: token refresh flow, advanced rate-limit/auth scenarios, CSRF/CSP validation (`COMPREHENSIVE_TEST_REPORT_2026-02-16.md:198`, `PARALLEL_WORK_PLAN_2026-02-16.md:82`).

## Open Code TODOs (Recently Touched Code)

~~8. Implement tier-based avatar route rate limiting (`backend/routes/avatar_routes.py:38`).~~ ✅ **COMPLETE** (2026-02-20)
~~9. Implement avatar vision-based verification (`backend/services/avatar_generation_service.py:493`).~~ ✅ **COMPLETE** (2026-02-20)
~~10. Implement selected-character proceed logic (`lib/character_selection_screen.dart:67`).~~ ✅ **COMPLETE** (2026-02-20)
~~11. Add `TherapeuticAnalytics` tracking (`lib/emotions_learning_system.dart:429`).~~ ✅ **COMPLETE** (2026-02-20)
~~12. Add earlier feelings check before generation (`lib/main_story.dart:512`).~~ ✅ **COMPLETE** (2026-02-20) - Already implemented
~~13. Hydrate `characterAppearance` into story result request (`lib/story_result_screen.dart:610`).~~ ✅ **COMPLETE** (2026-02-20) - Verified working in coloring page generation
