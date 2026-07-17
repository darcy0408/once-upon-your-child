# Copilot Instructions — Story Weaver App

## Architecture Overview

Full-stack app: **Flutter frontend** + **Python Flask backend** + **Google Gemini API** for AI story generation.

```
Flutter (lib/)  ──REST──►  Flask (backend/)  ──►  Gemini API
                                              ──►  OpenRouter (images)
```

All AI calls run server-side: Flutter calls the Flask backend, which calls the
AI providers (story text = OpenAI; images = Cloudflare Flux/OpenRouter;
narration = Azure Speech) with server-managed keys. There is no client-side
AI-provider path (the old BYOK direct-Gemini mode was removed 2026-07-15,
MT-358).

All Flutter→backend routing goes through `lib/services/api_service_manager.dart`.

## Build & Run

### Flutter Frontend
```bash
flutter pub get
flutter run -d chrome                                          # dev web
flutter run --dart-define=FLAVOR=development                  # explicit flavor
flutter build web --release --dart-define=FLAVOR=production   # production build
```

Build flavors: `development`, `staging`, `production` — configured in `lib/config/flavor_config.dart`.

### Python Backend
```bash
cd backend
pip install -r requirements.txt
python app.py          # dev server on :5000
# or
python run.py
```

Required env vars (in `backend/.env`): `GEMINI_API_KEY`, `SECRET_KEY`, `JWT_SECRET_KEY`.  
Optional: `STRIPE_API_KEY`, `SENTRY_DSN`, `REDIS_URL`.

Gemini model is set in `backend/config/__init__.py` line 23. Use `gemini-2.5-flash` (stable, good quotas) — **not** `gemini-2.0-flash-exp` (experimental, has free-tier quota limits even on Tier 1).

## Testing

### ⚠️ Always Enable Mock Mode Before Testing

The app calls Google Gemini, which costs real money. **Always set mock mode before running any tests:**

```powershell
# PowerShell
$env:MOCK_TESTING_MODE = "true"

# Or add to backend/.env for persistence:
# MOCK_TESTING_MODE=true
```

Verify mock is active: `curl http://localhost:5000/usage/mock-mode`  
Check cost after work: `curl http://localhost:5000/usage/summary`

Only disable mock mode for 2-3 final validation tests before a production deploy.

### Backend
```bash
# From repo root
pytest tests/                          # full suite
pytest tests/test_story_service.py     # single file
pytest tests/ -k "test_age_band"       # single test by name
pytest tests/ -v                       # verbose

# From inside backend/ directory
pytest
```

Config: `pytest.ini` at repo root (also one inside `backend/`). Uses `--import-mode=importlib`.  
Tests use a separate SQLite in-memory DB (see `backend/config/__init__.py` Testing class).

### Flutter
```bash
flutter test                           # full suite
flutter test test/widget_test.dart     # single file
flutter analyze                        # lint (rules in analysis_options.yaml)
```

## Key Conventions

### Backend: Import Dual-Path Pattern
`backend/app.py` and most modules use a try/except import pattern to support both:
- Running as a package from repo root: `from backend.services.story_service import ...`
- Running as a script from inside `backend/`: `from services.story_service import ...`

Always maintain both import paths when adding new modules.

### Backend: Story Generation Constraints
The `AdvancedStoryEngine` in `backend/services/story_service.py` enforces hard-coded age/length constraints. **Do not change these without explicit approval** — they encode therapeutic and developmental requirements:

| Age Band | Regular (words) | Pick-a-Path (nodes) |
|----------|-----------------|---------------------|
| 3–4      | 200–650         | 7–13                |
| 5–7      | 450–1200        | 9–18                |
| 8–10     | 900–2400        | 12–24               |
| 11–13    | 1300–3400       | 14–26               |
| 13–15    | 1600–4500       | 16–32               |
| 15–18    | 2000–6000       | 18–38               |
| Adult    | 2000–7800       | 18–44               |

Interactive (Pick-a-Path) per-segment word counts are calculated by dividing total words by path depth — see `interactive_adventure_prompt_builder.py`.

### Backend: Route & Middleware Structure
- Routes are Flask **blueprints** in `backend/routes/`, each registered in `app.py`.
- Cross-cutting concerns (logging, rate limits, auth) use factory helpers from `backend/utils/app_helpers.py`: `make_log_error()`, `make_handle_error()`, `make_add_request_id()`.
- Rate limiting: default 200/day, 50/hour; higher tiers get more. Tier is resolved via `get_user_tier()`.
- Auth is JWT (`flask_jwt_extended`), but anonymous fallback is supported for dev/testing.

### Backend: Error Response Shape
```json
{ "error": "short_code", "message": "Human-readable message", "details": {} }
```

### Flutter: State Management
Uses **Riverpod** (`flutter_riverpod`) for all dependency injection and state. Providers live in `lib/providers/`.

### Flutter: Local Storage
- **Isar** (NoSQL) for offline story/character caching — `lib/services/isar_service.dart` has platform stubs (`_io.dart`, `_stub.dart`) for web/native splits.
- **flutter_secure_storage** for BYOK API keys.

### Flutter: Platform Service Stubs
Several services have three files: `foo_service.dart` (interface/exports), `foo_service_io.dart` (native), `foo_service_stub.dart` (web). Follow this pattern when adding platform-conditional services.

### Flutter: Code Generation
After changing Riverpod providers or Isar models, run:
```bash
dart run build_runner build --delete-conflicting-outputs
```

## Key Files

| File | Purpose |
|------|---------|
| `backend/services/story_service.py` | Core age-aware prompt engine (`AdvancedStoryEngine`) |
| `backend/services/interactive_adventure_prompt_builder.py` | Pick-a-Path prompt & segment sizing |
| `backend/utils/app_helpers.py` | Auth, tier, rate-limit, logging helpers |
| `backend/config/__init__.py` | All environment/tier configuration classes |
| `lib/services/api_service_manager.dart` | Single source of all Flutter→backend HTTP calls |
| `lib/config/flavor_config.dart` | Dev/staging/prod URL switching |
| `lib/providers/` | All Riverpod providers |

## MCP Servers (configured in `.vscode/mcp.json`)

| Server | Purpose |
|--------|---------|
| **playwright** | Browser automation — test the Flutter web UI at `http://localhost:8080` and verify Flask API responses |
| **sqlite** | Query the local dev database at `instance/app.db` — inspect users, characters, stories, achievements |

## Deployment

- **Backend**: Railway (`railway.toml`, `Dockerfile`). Gunicorn in prod: `gunicorn -w 4 -b 0.0.0.0:$PORT wsgi:app`
- **Frontend**: Netlify (`netlify.toml`) for web builds.
- **CI/CD**: GitHub Actions workflows in `.github/workflows/` — `cicd.yml` is the main pipeline, `backend-tests.yml` and `backend-lint.yml` run on PRs.

## Session Log Convention

After each working session, prepend a new entry to `TEAM_COORDINATION.md` (newest at top) using this format:

```markdown
## Session Update - YYYY-MM-DD (Short description)

### Scope Completed
- Bullet list of what changed and why.

### Status
- **Feature X:** ✅ / 🟡 / ❌ with brief note.
- **Launch Readiness:** N%
```

Then commit with a `docs:` prefix: `docs: log <session description> in TEAM_COORDINATION.md`
