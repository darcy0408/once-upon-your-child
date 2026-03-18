# Team Coordination

## 2026-03-18

- Completed: fixed the unsecured API key routes in `backend/routes/api_key_routes.py` so `/api/user/settings/api-key` and `/api/user/usage` now require JWT auth and use `request.current_user` instead of trusting `X-User-ID`.
- Completed: registered the API key blueprint in `backend/app.py`; before this, the BYOK endpoints existed in code but returned `404` because they were never mounted.
- Completed: added authorization coverage in `backend/tests/security/test_authorization.py` for API key, story, therapist, and achievement routes, and added the missing `therapist_user` fixture in `backend/tests/conftest.py`.
- Verification: `cd backend && python -m pytest tests/security/ -v` passed with `97 passed` on 2026-03-18.
- Verification note: the exact import check command `cd backend && python -c "from app import create_app; app = create_app('testing'); print('OK')"` still fails because this repo's current import layout mixes package-relative imports with top-level execution. A package-safe equivalent succeeded: `python -c "import sys; sys.path.insert(0, r'C:\\dev\\story-weaver-app'); from backend.app import create_app; app = create_app('testing'); print('OK')"`.
- In progress: adding per-phase story generation perf instrumentation in `backend/tasks/story_tasks.py` and extending `backend/tests/story_load_audit.py` with real-provider, fallback switchover, and concurrency-ramp coverage.
- Next: run `python backend/tests/story_load_audit.py` and `python backend/tests/story_load_thresholds.py`, then update this file with results and any artifact baseline changes.
