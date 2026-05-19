# 03 Security Audit — White Hat (Factual Inventory)

Audit ID: 03-security | Date: 2026-05-19 | Method: Six Thinking Hats, static review
Scope: auth, API, infra, payments, secrets, dependencies, mobile, LLM-security.
Out of scope (covered by 02-content-safety-20260519): story/illustration content
moderation, content prompt-injection, age-band content bypass.

## Repository inventory

Repo root `C:\dev\story-weaver-app`. Top-level dirs analysed:

| Dir | Role | Covered by hat |
|---|---|---|
| `backend/` | Flask API, Celery tasks, services, models, migrations | White/Black/Yellow |
| `lib/` | Flutter client | White/Black/Yellow |
| `security/` | Custom security modules (ai_threat_detector, gdpr_compliance, iam, data_protection, auth_middleware) | Black (S-13: dead code) |
| `audit/` | Compliance docs (LEGAL-COMPLIANCE.md, AUDIT_PERSPECTIVES.md) | White (reference) |
| `android/` `ios/` `macos/` `windows/` `linux/` `web/` | Platform shells | Black (mobile surface) |
| `Dockerfile*`, `railway.toml`, `nginx.conf` | Infra | White/Yellow |
| `.github/` | CI workflows | Black (supply chain) |
| `monitoring/` `scripts/` `qa/` `tests/` `test/` | Tooling/tests | Excluded — non-shipping |
| `node_modules/` `build/` `.dart_tool/` `__pycache__/` `age_band_assets_OLD/` `*.png` | Build/artifacts | Excluded per scope |
| `story_weaver_core/` `story_weaver_mvp/` `therapy_companion/` `third_party/` | Legacy/vendored subtrees | Not exercised by the live app; spot-checked only |

## Authentication & session

- Primary decorator `require_auth` (`backend/middleware/auth.py:47-121`): raw PyJWT
  HS256 decode, identity on the `sub` claim only (legacy `user_id` fallback
  removed — prior L-8 fixed), `tv` token-version revocation check (prior M-1
  fixed), under-13 `g.minor_age_cap` set from `declared_age`.
- Tokens minted by `flask_jwt_extended` with `additional_claims={'tv': ...}`
  in `utility_routes.py` (`/auth/login`, `/auth/anonymous`, `/auth/refresh`).
- Access TTL 1h, refresh TTL 30d (`app.py:639-640`) — prior M-1 fixed.
- Refresh-token rotation: spent refresh JTI blocklisted in Redis
  (`utility_routes.py:23-41, 352-390`); blocklist check `app.py:652-666` —
  fails open on Redis outage (documented, intentional).
- `JWT_SECRET_KEY` required in production; raises on `dev-secret-key` in prod
  (`auth.py:36-44`, `app.py:642-647`).
- `optional_auth` / `get_current_user_id`: accept `X-User-ID` header as a
  legacy identity fallback when no JWT present (`auth.py:296-317`).

## API surface & authorization

- IDOR protection: `require_owner('user_id')` on user-scoped routes; ownership
  checks in interactive story routes.
- `require_admin` on `/health/detailed`, `/health/database`, `/debug-gemini`,
  `/debug-openrouter`, `/usage/*`, `/admin/*`.
- `require_parental_consent` COPPA gate (`auth.py:124-223`) — feature-flagged
  verified-consent + policy-version enforcement, both default OFF for tester
  phase.
- Public `/health` returns only `{status,version}` (prior M-12 fixed).
- CSRF origin enforcement on all unsafe methods (`app.py:268-289`).
- CORS allowlist explicit; no wildcard; `http://` downgrade only in dev
  (`config/__init__.py:135-203`) — prior L-2 fixed.
- Rate limiting: flask-limiter, Redis-backed in prod, key = `get_user_identifier`
  (`app_helpers.py:41-61`).
- `/setup-test-account` returns 404 in production, random password
  (`utility_routes.py:198-232`) — prior H-1 fixed.

## Payments

- Stripe checkout + portal fully hosted-redirect (PCI SAQ-A preserved).
- Webhook (`webhook_handler.py`): signature-verified; fails closed if
  `STRIPE_WEBHOOK_SECRET` unset; tier resolved from the actual charged price
  ID via server-side map, fails closed to `free` on unknown price (prior H-2
  fixed); `StripeWebhookEvent` unique-`event_id` dedup + `StripeSubscriptionCursor`
  high-water-mark ordering guard (prior M-3 fixed).
- IAP (`iap_routes.py`): Apple/Google receipt verify endpoints `@require_auth`;
  identity taken from JWT not body; fails closed (503) while
  `IAP_VERIFICATION_ENABLED` off; S2S notification endpoints are phase-1 stubs
  that ACK 200 without mutating entitlement.

## Secrets handling

- `.env` gitignored (`.gitignore:55-59`); no `.env` tracked (only `.env.example`).
- Config never logs key values, only presence booleans (`config/__init__.py:18-23`).
- BYOK Gemini keys stored AES-256-CBC encrypted at rest (`encryption_utils.py`),
  key from `ENCRYPTION_KEY` env (32-byte hex, required).
- Prior C-2 (Gemini key in git history) confirmed resolved — key expired/rejected
  by Google; dead string in history carries no risk.

## Data flows / third-party calls

- LLM text: Gemini primary, OpenRouter (Llama-3.2-3B free) fallback.
- Images: Gemini image model, Replicate, OpenRouter, Cloudflare.
- Hero name pseudonymized to `HERO_1` before provider calls (prior M-7 fixed).
- Crash reporting: Sentry (backend + Flutter web SDK).
- Analytics: Firebase Analytics — default OFF, enabled only after verified
  consent + age >= 13 (prior M-9 fixed).
- Child reference photos sent to Gemini/Replicate for avatars — see
  02-content-safety F-07/F-17 (not re-reported here).

## Dependencies

- Backend `requirements.txt`: hash-pinned, all current 2026 releases —
  flask 3.1.3, werkzeug 3.1.8, cryptography 46.0.7, stripe 15.1.0,
  pyjwt 2.12.1, gunicorn 25.3.0, pillow 12.2.0, requests 2.33.1,
  urllib3 2.7.0, sqlalchemy 2.0.49. No known-vulnerable versions identified.
- Flutter `pubspec.yaml`: flutter_secure_storage ^10.0.0 (encrypts by default),
  firebase_core ^4.6.0, sentry_flutter ^9.16.0, http ^1.2.1, isar ^3.1.0.
  No known-vulnerable versions identified.

## Infrastructure

- Dockerfile + Dockerfile.worker: multi-stage builds, non-root `app` user
  (prior M-13/M-14 fixed). Dockerfile.frontend: nginx-unprivileged.
- nginx.conf: `server_tokens off`, CSP, HSTS, Referrer-Policy, X-Frame-Options
  (prior L-10 fixed). CSP `connect-src` is `https: wss:` (broad — documented).
- railway.toml: single gunicorn start command, `--workers 2`, info log level
  (prior L-9 fixed); `nixpacks.toml` removed.
