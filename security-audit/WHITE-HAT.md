# White Hat — Factual Inventory

Story Weaver security audit, 2026-05-16. Facts only — no judgment.

## Repository
Root `C:\dev\story-weaver-app`, branch `main`, commit `0de9f590`. Git repo, 2101+ commits, never history-rewritten. Solo developer.

## Top-level directories
`backend/` (Flask API + Celery), `lib/` (Flutter app), `android/` `ios/` `web/` `windows/` `linux/` `macos/` (Flutter platform targets), `assets/` (images), `docs/`, `security/`, `monitoring/`, `scripts/`, `tests/`/`test/`/`integration_test/`/`test_driver/`. Sibling/legacy projects not in the deployed build: `story_weaver_core/`, `story_weaver_mvp/`, `therapy_companion/`, `third_party/`, `age_band_assets_OLD/`.

## Deployment topology (Railway, project radiant-tranquility)
| Service | Build | Start | Public |
|---|---|---|---|
| `backend` | `Dockerfile` | `gunicorn -w 1 wsgi:app --timeout 120` | Yes, `/health` |
| `lovely-perfection` (worker) | `Dockerfile.worker` | `celery ... worker --pool=solo` | No |
| `frontend` | `Dockerfile.frontend` | nginx-served Flutter web bundle | Yes, `/` |
| Postgres, Redis | Railway plugins | — | Private |

## Stack
- Backend: Python 3.11, Flask 3.x, Gunicorn, Celery, SQLAlchemy ORM, PostgreSQL (since 2026-05-14), Redis.
- Frontend: Flutter (Dart SDK >=3.5.0), Riverpod, Isar, `flutter_secure_storage`, `shared_preferences`.
- Dependencies: `backend/requirements.txt` is a `pip-compile --generate-hashes` lockfile (fully hash-pinned). `pubspec.lock` pins Flutter deps.

## Authentication flows
- JWT `HS256`, pinned algorithm. Access token TTL 24h, refresh 30 days.
- Secret: `JWT_SECRET_KEY` from env; startup raises if weak/missing in prod.
- Passwords: Werkzeug PBKDF2 (`generate_password_hash`).
- Two coexisting auth implementations: raw `PyJWT` in `backend/middleware/auth.py` (`require_auth`, used by most routes) and `flask_jwt_extended` in `utility_routes.py`/`achievement_routes.py`.
- Anonymous-user bootstrap (`/auth/anonymous`); refresh-token rotation with Redis JTI blocklist.
- COPPA: `require_parental_consent` decorator and server-side `g.minor_age_cap` for declared under-13 accounts.

## API surface — 17 route blueprints
`user`, `admin`, `api_key`, `story`, `avatar`, `avatar_gallery`, `character`, `chronicle`, `progression` (file present, **not registered**), `achievement`, `stripe`, `subscription`, `tts`, `health`, `utility`, `webhook_handler`, `analytics`.

## Secrets handling
- Required: `JWT_SECRET_KEY`, `GEMINI_API_KEY`, `DATABASE_URL` (Railway-set). `_get_required_secret` raises in production if absent — no hardcoded prod fallback.
- Recommended: `STRIPE_SECRET_KEY`, `STRIPE_WEBHOOK_SECRET`, price IDs, `REDIS_URL`, `SENTRY_DSN`, `OPENROUTER_API_KEY`.
- Optional: `ELEVENLABS_API_KEY`, `REPLICATE_API_TOKEN`, `CLOUDFLARE_ACCOUNT_ID`/`_API_TOKEN`.
- BYOK Gemini keys: encrypted AES-256-CBC + random IV at rest (`backend/encryption_utils.py`); excluded from `to_dict()`.
- `backend/.env` not currently tracked (removed in commit `f383b422`); `.env.example` is the tracked template.

## Third-party data flows
| Service | Purpose | Data sent |
|---|---|---|
| Google Gemini | Story text (primary), images | Prompt incl. child name, age, feelings text |
| OpenRouter | Story/image fallback | Same |
| Cloudflare Workers AI (Flux) | Image gen (primary for ages 6+) | Scene description prompt |
| Replicate (Flux Schnell) | Image-gen fallback | Scene description prompt |
| ElevenLabs | TTS narration | Story text |
| Stripe | Payments | Hosted checkout/portal — no card data on server |
| Firebase Analytics | Usage analytics | `user_id`, screen views, `*_length` metrics |
| Sentry | Crash reporting | Scrubbed errors |

## COPPA-regulated data collected
Child first name, declared age, selfie/photo (camera + gallery), emotional-state ("big feelings") text, caregiver names, persistent anonymous `user_id`, optional parent email. Storage: mostly plaintext `SharedPreferences` on-device; profiles/stories also in Isar. See the touchpoint table in `SIX-HATS-20260516.md`.

## Entry points
- Backend: `wsgi.py` → `backend/app.py:create_app()`. (`backend/run.py` has `debug=True` but is not the production entry.)
- Frontend: `lib/main.dart` → `_AppEntryPoint` → consent gate → story creator.
