# Team Coordination

## 2026-03-18

- Completed: fixed the unsecured API key routes in `backend/routes/api_key_routes.py` so `/api/user/settings/api-key` and `/api/user/usage` now require JWT auth and use `request.current_user` instead of trusting `X-User-ID`.
- Completed: registered the API key blueprint in `backend/app.py`; before this, the BYOK endpoints existed in code but returned `404` because they were never mounted.
- Completed: added authorization coverage in `backend/tests/security/test_authorization.py` for API key, story, therapist, and achievement routes, and added the missing `therapist_user` fixture in `backend/tests/conftest.py`.
- Verification: `cd backend && python -m pytest tests/security/ -v` passed with `97 passed` on 2026-03-18.
- Verification note: the exact import check command `cd backend && python -c "from app import create_app; app = create_app('testing'); print('OK')"` still fails because this repo's current import layout mixes package-relative imports with top-level execution. A package-safe equivalent succeeded: `python -c "import sys; sys.path.insert(0, r'C:\\dev\\story-weaver-app'); from backend.app import create_app; app = create_app('testing'); print('OK')"`.
- In progress: adding per-phase story generation perf instrumentation in `backend/tasks/story_tasks.py` and extending `backend/tests/story_load_audit.py` with real-provider, fallback switchover, and concurrency-ramp coverage.
- Completed: `cd backend && python tests/story_load_audit.py` now passes and writes fresh audit artifacts with the new fallback switchover line (`~4573ms`) and concurrency ramp table.
- Completed: `cd backend && python tests/story_load_thresholds.py` passes with the new `concurrency_ramp_c16` checks.
- Completed: manual Flask test-client verification shows `/generate-story` responses now include `story._perf`, and `backend.tasks.story_tasks` emits `perf phase=` debug lines for prompt build, AI call, validation, and total task.
- Next: real-provider baseline remains gated behind `--real-api` / `RUN_REAL_API_TESTS=true` and was not executed because `GEMINI_API_KEY` is not set in this environment.
