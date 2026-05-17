# Yellow Hat — Strong Controls

Story Weaver security audit, 2026-05-16. Existing defenses worth preserving against regression and replicating where gaps exist. Each entry cites file:line.

## Authentication & secrets
- Fail-fast startup assertions reject a weak/dev JWT secret and a missing production Redis — `backend/app.py:139-176,562-564`.
- No hardcoded production secret fallbacks; `_get_required_secret` raises in prod — `backend/config/__init__.py:30-49`.
- JWT decoding pins `algorithms=['HS256']` — no `alg:none` / algorithm-confusion — `backend/middleware/auth.py:67,242,267`.
- Passwords hashed with Werkzeug `generate_password_hash`/`check_password_hash` (PBKDF2) — `backend/models/user.py:42-46`.
- BYOK Gemini keys encrypted at rest AES-256-CBC + random IV; `ENCRYPTION_KEY` length-validated; `to_dict()` never exposes the encrypted key — `backend/encryption_utils.py:16-73`, `models/user.py:69`.
- Refresh-token rotation with Redis blocklisting of consumed JTIs — `backend/routes/utility_routes.py:23-41,296-324`.

## API hardening
- Explicit CORS allowlist with a documented rejection of `*.netlify.app` wildcards; never `"*"`; localhost regexes gated to dev — `backend/config/__init__.py:130-188`.
- Strong security header set on API responses — HSTS (prod-only), CSP, `X-Frame-Options: DENY`, `X-Content-Type-Options`, `Referrer-Policy`, `Permissions-Policy` — `backend/app.py:307-366`.
- CSRF defense-in-depth — Origin/Referer enforcement on unsafe methods — `backend/app.py:260-281`.
- No raw SQL string-formatting with user input — parameterized SQLAlchemy ORM throughout; admin DDL uses static strings.
- `create_character` forces `data['user_id'] = request.current_user.id` — mass-assignment-safe — `backend/routes/character_routes.py:138`.
- Hand-rolled but fail-closed ownership (IDOR) checks on characters — `character_routes.py:151-201`.
- Sentry `before_send` scrubs Authorization/Cookie/X-API-Key headers, request bodies, and large/sensitive locals — `backend/app.py:90-137`.
- COPPA right-to-erasure / right-to-access endpoints with strict rate limits and audit logging — `backend/routes/user_routes.py:206-351`.
- API-key save/remove endpoints tightly rate-limited (5/hr, 10/hr) — `backend/routes/api_key_routes.py:30,108`.
- Production runs via `gunicorn wsgi:app`, so `run.py`'s `debug=True` never reaches production — `railway.toml:14`.

## Payments
- Webhook signature verified with `stripe.Webhook.construct_event`; distinct `ValueError` (400) vs `SignatureVerificationError` (401) handling — `backend/routes/webhook_handler.py:28-39`.
- Webhook refuses to run if `STRIPE_WEBHOOK_SECRET` is unset — fails closed on config — `webhook_handler.py:24-26`.
- Checkout binds the authenticated user via `client_reference_id`, `metadata.user_id`, and `subscription_data.metadata.user_id`; a client-supplied body `user_id` is ignored — `backend/routes/stripe_routes.py:59-85`. (The prior-audit "checkout omits user_id" finding is **resolved**.)
- Amount/price never accepted from the client — checkout uses server-side `STRIPE_PRICE_ID_*` env vars; placeholder IDs rejected — `stripe_routes.py:26-71`.
- No card data (PAN/CVV/expiry) touches the backend — checkout and billing portal are fully Stripe-hosted redirects; PCI scope stays SAQ-A — `stripe_routes.py:95-120`.
- Existing-customer reuse guarded — avoids duplicate Stripe customers — `stripe_routes.py:87-90`.
- `subscription_routes.py:22-25` correctly stacks `@require_auth` + `@require_owner('user_id')` + rate limit — the pattern `stripe_routes.py:127` should copy.
- Story generation re-checks tier server-side via a Redis quota circuit breaker and emits an `ai_quota_exceeded` audit log — `backend/routes/story_routes.py:432-442`.

## AI / child safety
- 14-pattern prompt-injection filter + delimiter stripping — `backend/utils/sanitizer.py:19-69`.
- `[USER_INPUT]` delimiter framing on parent Big-Feelings context and `custom_elements` — `backend/services/story_service.py:284-308,714`.
- Server-side age clamp [2,120] with out-of-range rejection, and under-13 `minor_age_cap` enforcement preventing age-uplift via the request body — `backend/routes/story_routes.py:31-49,491-500`, `middleware/auth.py:84-153`.
- Two-layer output moderation on the main story path — keyword filter + LLM contextual classifier — with safe-fallback substitution — `backend/tasks/story_tasks.py:1065-1118`.
- Age-band-aware Gemini `SafetySetting` thresholds, `BLOCK_LOW_AND_ABOVE` for sexual/hate/harassment — `backend/services/story_generation_service.py:19-36`.
- Avatar `AVATAR_BLOCKLIST` + `validate_prompt_safety` on the standard avatar path — `backend/services/avatar_prompt_service.py:40-48,202-241` (gap: not on the photo/pet paths — see Black Hat C-3).
- IDOR ownership checks on characters, tasks, interactive stories — `story_routes.py:450,728,934,999,1037`.
- Image ingestion hardened — 5 MB stream cap, dimension validation, thumbnail re-encode — `story_routes.py:1302-1341`.
- Mock story endpoint gated out of production — `story_routes.py:686`.

## Infrastructure & supply chain
- Hash-pinned `pip-compile --generate-hashes` lockfile — 1300+ sha256 entries — `backend/requirements.txt:1-5` (supply-chain integrity, A08).
- `pip-audit` CVE scan on every backend PR — `.github/workflows/backend-tests.yml:47-50`.
- Gitleaks pre-commit hook with `--staged --redact` — `.pre-commit-config.yaml:1-8`.
- `.gitleaksignore` suppresses only Firebase web API keys (public by design) — legitimate suppression — `.gitleaksignore:1-6`.
- Thorough `.gitignore` for `.env` / `*.env` / `**/.env` / DBs / venvs; no `.env` currently tracked.
- Multi-stage build for the frontend image — `Dockerfile.frontend:2,32-35`.
- Celery hardened against pickle — `task_serializer='json'`, `accept_content=['json']`, task time limit — `backend/celery_config.py:41-51`.
- Dependabot configured for pub/pip/actions; no `pull_request_target` in any workflow; least-privilege `permissions: contents: read` on the audit workflow; encrypted off-Railway Postgres backup to R2.

## Client
- Child name persistence correctly deferred until after parental consent — `lib/screens/welcome_screen.dart:851-854` (comment cites COPPA).
- Analytics events transmit `character_name_length`, not the actual child name — `lib/story_analytics.dart:26`, `character_analytics.dart:48`.
- COPPA right-to-erasure — deleting a child profile calls backend `DELETE /api/user/<id>/data` — `child_profile_service.dart:96-105`.
- Re-consent enforced after a privacy-policy update — `lib/main_story.dart:108,124-128`.
- JWT expiry validated client-side before reuse; refresh-token rotation persisted — `api_service_manager.dart:110-123,183-224`.
- Cleartext HTTP restricted to `127.0.0.1`/`localhost`; production backends are HTTPS — `android/app/src/main/res/xml/network_security_config.xml:3-6`.
- iOS `Info.plist` provides clear, child-appropriate usage strings for camera/photos/mic/speech — `ios/Runner/Info.plist:48-55`.
- `LoggerService` gates non-warning logs to debug builds and forwards only errors to Sentry — `lib/services/logger_service.dart:53-74`.
- Debug consent bypass is `kDebugMode`-gated so it cannot fire in release — `parental_consent_screen.dart:57`.

## Patterns worth replicating
- The `@require_auth` + `@require_owner('user_id')` + rate-limit stack from `subscription_routes.py:22-25` should become the standard for every user-scoped endpoint.
- The frontend's multi-stage Docker build should be mirrored by the backend and worker images.
- The main story path's sanitize + `[USER_INPUT]`-wrap + two-layer-moderate pattern should be applied uniformly to the interactive and avatar paths.
