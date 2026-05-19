# 03 Security Audit — Yellow Hat (Controls Working Well)

Existing strong controls and defense-in-depth wins worth preserving and
replicating. The two prior remediation batches (2026-05-16/17) landed real,
verifiable security work — this hat documents what should NOT be touched.

## Authentication & session

- Identity standardized on the JWT `sub` claim only; the legacy `user_id`
  claim fallback was removed (`auth.py:72`). No ambiguous identity surface.
- Token-version revocation: every access token carries a `tv` claim minted at
  issue time and re-checked against `User.token_version` on every request
  (`auth.py:82-94`). Bumping the column (on data deletion) invalidates every
  outstanding token — true server-side revocation without a per-request
  blocklist read.
- Short access TTL (1h) + long refresh TTL (30d) with refresh-token rotation:
  the spent refresh JTI is blocklisted in Redis on each refresh
  (`utility_routes.py:352-390`), so a stolen refresh token cannot be reused.
- `JWT_SECRET_KEY` hard-fails the app boot in production if unset or left at
  `dev-secret-key` (`app.py:642-647`, `auth.py:36-44`).
- Graceful degradation: the Redis blocklist check fails *open* so a Redis
  outage never locks users out — a deliberate, documented availability choice.

## Authorization

- IDOR protection is systematic: `require_owner('user_id')` on every user-
  scoped route, plus explicit ownership checks in the interactive story path.
- `require_admin` consistently applied to every diagnostic / privileged route
  (`/health/detailed`, `/health/database`, `/debug-*`, `/usage/*`, `/admin/*`).
- The COPPA consent gate (`require_parental_consent`) is a real decorator with
  two forward-looking flags (`COPPA_REQUIRE_VERIFIED_CONSENT`,
  `COPPA_REQUIRE_CURRENT_POLICY_VERSION`) so a policy change or launch can
  tighten the gate with an env-var flip, no code change.

## API & web hardening

- CSRF origin enforcement on every unsafe HTTP method, validating both
  `Origin` and `Referer` against the allowlist (`app.py:268-289`).
- CORS allowlist is explicit, no wildcard; the insecure `http://` origin
  downgrade is added only in development.
- `/health` is minimal `{status,version}` — no env, no integration map, no
  raw errors leaked to unauthenticated callers.
- `/setup-test-account` returns 404 in production (does not even confirm its
  own existence) and uses a per-call random password — zero hardcoded creds.
- `/auth/anonymous` always generates the anonymous id server-side and refuses
  to reclaim the singleton `anonymous` account — no auth-bypass-to-arbitrary-id.

## Payments — notably strong

- Stripe webhook tier resolution reads the *actual charged price ID* through a
  server-side `{price_id: tier}` map and fails closed to `free` on an unknown
  price (`webhook_handler.py:74-125`). Client-supplied metadata is a last-
  resort hint only.
- Webhook idempotency: a unique-constrained `StripeWebhookEvent.event_id`
  table dedups replays, and the INSERT race is caught as the authoritative
  guard. A per-user `StripeSubscriptionCursor` high-water mark drops stale /
  out-of-order events so a replayed `payment_succeeded` cannot un-do a real
  `payment_failed`.
- IAP receipt verification takes identity from the JWT, never the request
  body, and fails closed (HTTP 503) while store credentials are unprovisioned
  — an unverified receipt never grants a tier.
- PCI SAQ-A scope is cleanly preserved: all card handling is hosted-redirect.

## Secrets & crypto

- `.env` is gitignored at multiple patterns; no `.env` is tracked. Config code
  logs only presence booleans, never key values, even masked.
- BYOK API keys are encrypted at rest (AES-256) with the key sourced from a
  required `ENCRYPTION_KEY` env var validated to 32 bytes. (Algorithm mode is
  a Medium finding — see Black Hat S-03 — but encryption-at-rest itself is
  correct and the key is not hardcoded.)
- Prior leaked Gemini key (C-2) was live-tested and confirmed expired —
  exposure genuinely closed, not just assumed.

## Mobile client

- `flutter_secure_storage` v10 keeps the JWT access token, refresh token, and
  BYOK key in the platform keystore/keychain; `SecureStorageService` pins
  `IOSOptions(first_unlock_this_device)` so credentials never reach iCloud
  backups, and documents the Android default-encryption behaviour.
- Firebase Analytics defaults OFF and is enabled only after verified consent
  AND declared age >= 13 — COPPA-aware telemetry.
- The consent test-bypass is a compile-time `--dart-define` defaulting off and
  records an HONEST `consent_method='debug_bypass'` — it never mislabels a
  bypass as real verified consent.

## Infrastructure & supply chain

- All three Docker images run as a non-root user; backend + worker are multi-
  stage builds with no compiler in the runtime image; frontend uses
  `nginx-unprivileged`.
- nginx serves the SPA with `server_tokens off`, a Flutter-tuned CSP, HSTS,
  Referrer-Policy and X-Frame-Options.
- Backend dependencies are hash-pinned (`requirements.txt` carries
  `--hash=sha256:` for every wheel) — supply-chain tamper resistance.
- All backend and Flutter dependencies are on current 2026 releases; no
  known-vulnerable version was identified.

## LLM integration (security dimension)

- `sanitize_story_request` is recursive — every string field in a generation
  request is HTML-stripped, injection-pattern-scrubbed, delimiter-token-
  stripped, and length-capped *by default*; new fields are safe without an
  allowlist edit.
- High-authority free-text directive fields (`worldBible`, `conflictHook`,
  `sensoryPalette`, hero costume fields) are `[USER_INPUT]`-wrapped so the
  model treats them as data.
- The child's real name is pseudonymized to `HERO_1` before any provider call
  and restored locally — strong data minimization toward third-party LLMs.
- Content age band is clamped to the verified account/character age; a client
  may only move the band down.
