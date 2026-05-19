# 03 Security Audit — Black Hat (Vulnerabilities)

Concrete vulnerabilities, ranked by severity and child-safety blast radius.
Schema: ID | Severity | CWE | OWASP | File:Line | Description | Exploit Path |
Remediation | Effort. Critical/High include proof-of-exploit reasoning.
Severity: Critical / High / Medium / Low / Informational.

This audit (03) does NOT re-report content-moderation findings — those are in
`02-content-safety-20260519.md` (F-01..F-20, remediated in commit 3db0756e).
It also does NOT re-report prior-audit findings confirmed fixed — see the
"Prior-audit regression check" section at the end. New finding IDs are `S-NN`.

---

## CRITICAL

None. No new Critical security finding. All prior Critical findings (C-1, C-2,
C-3) are resolved or accepted-by-disclosure (see regression check). No
CSAM-adjacent, grooming, or minor-manipulation vector was found in the security
surfaces audited here; the content-generation surfaces are covered by audit 02.

---

## HIGH

### S-01 | Rate-limit key derived from a client-controlled `X-User-ID` header
- Severity: High | CWE-639 / CWE-807 | OWASP API4 (Unrestricted Resource
  Consumption) / API1
- File: `backend/utils/app_helpers.py:41-61` (`get_user_identifier`);
  used as `key_func` at `backend/app.py:302-307`; `X-User-ID` also honoured at
  `backend/middleware/auth.py:305,317` (`get_current_user_id`).
- Description: `get_user_identifier` is the flask-limiter `key_func` for the
  whole app. When no authenticated user is attached it falls back to
  `request.headers.get('X-User-ID')` and returns `user:{that header}`. The
  header is fully attacker-controlled and is consulted *before* the IP
  fallback. Any endpoint reachable without `@require_auth` — `/auth/login`
  (10/min), `/auth/anonymous` (20/min), `/auth/refresh` — is therefore rate-
  limited per *attacker-chosen string*, not per real principal.
- Exploit Path: An attacker brute-forcing `/auth/login` sends a fresh random
  `X-User-ID` value on every request. Each request lands in a brand-new
  limiter bucket, so the `10 per minute` limit and the global
  `200 per day / 50 per hour` default are never reached. The credential-
  stuffing / brute-force rate limit is fully bypassed. The same trick caps
  out a victim's bucket: send 50 requests with `X-User-ID: <victim_id>` and
  the victim is locked out of the global hourly limit (limit exhaustion DoS).
- Remediation: Stop trusting `X-User-ID` for the limiter key. For
  unauthenticated requests key strictly on `get_remote_address()`. The
  `X-User-ID` legacy fallback in `get_current_user_id` should likewise be
  removed (it is a non-cryptographic identity claim — any caller can assert
  any user id for optional-auth code paths). If a legacy client genuinely
  needs it, gate it behind a signed value.
- Effort: S | Needs decision: No (pure code fix; confirm no live client still
  sends `X-User-ID` — grep of `lib/` shows the Flutter client uses
  `Authorization: Bearer`, not `X-User-ID`).
- Verification: re-read `get_user_identifier` and the limiter construction;
  `X-User-ID` appears only here and in `get_current_user_id`, both as an
  unauthenticated fallback.

---

## MEDIUM

### S-02 | `security/` directory is dead code masquerading as live controls
- Severity: Medium | CWE-1164 (Irrelevant Code) / CWE-710
- File: `security/ai_threat_detector.py`, `security/gdpr_compliance.py`,
  `security/iam.py`, `security/data_protection.py`,
  `security/auth_middleware.py` (1,746 LOC total).
- Description: None of these modules is imported by the backend, the Celery
  worker, `wsgi.py`, `app.py`, or the Flutter app — a repo-wide grep for
  `ai_threat_detector`, `GDPRCompliance`, `DataProtection`,
  `security.iam`, `security.auth_middleware` returns zero non-test hits.
  The real auth middleware is `backend/middleware/auth.py`; the real GDPR
  surface is `backend/services/data_retention.py` + user routes. The
  `security/` tree is an earlier, abandoned implementation.
- Exploit Path: Not directly exploitable. The risk is governance: a future
  developer or a compliance reviewer reading the repo sees a "GDPR compliance"
  and "AI threat detector" module and reasonably assumes those controls are
  enforced. A control believed-present but absent is a latent gap — and if
  any of these files is later wired in carelessly (e.g. its `iam.py` role
  model conflicts with `User.is_admin`) it can silently weaken the real path.
- Remediation: Delete the `security/` directory, or move it under a clearly
  labelled `archive/` / `experimental/` path with a README stating it is not
  wired in. Confirm nothing in `monitoring/` or `scripts/` imports it first.
- Effort: S | Needs decision: No.

### S-03 | BYOK API keys encrypted with unauthenticated AES-256-CBC
- Severity: Medium | CWE-326 (Inadequate Encryption Strength) / CWE-327
- File: `backend/encryption_utils.py:38-115`
- Description: `encrypt_api_key` / `decrypt_api_key` use AES-256-CBC with a
  random IV and PKCS7 padding but no message-authentication (no HMAC, not
  GCM). Ciphertext stored in `User.gemini_api_key_encrypted` is malleable and
  the decrypt path is a padding-unpadding oracle: `decrypt_api_key` raises
  `ValueError(f"Decryption failed: {e}")` distinguishing a padding error from
  other failures.
- Exploit Path: Requires DB write access (a deeper compromise) to be a true
  padding-oracle attack, so this is not high-severity in isolation — but for a
  credential store, integrity-less encryption is below standard. An attacker
  with DB access could also swap a victim's encrypted key for one they control
  without detection.
- Remediation: Use authenticated encryption — `cryptography`'s `AESGCM`, or
  Fernet (already a `cryptography` primitive, used elsewhere in the ecosystem).
  Provide a one-time migration that re-wraps existing CBC blobs. Make
  `decrypt_api_key` raise a single generic error regardless of failure mode.
- Effort: M | Needs decision: No.

### S-04 | Debug endpoints (`/usage/*`) still echo raw exception strings
- Severity: Medium | CWE-209 (Information Exposure Through an Error Message)
- File: `backend/routes/utility_routes.py:504, 531, 557`
- Description: Prior audit L-7 removed raw `str(e)` from `api_key_routes.py`,
  but three admin-only handlers were missed: `/usage/summary` returns
  `{'error': ..., 'detail': str(e)}`, `/usage/daily` the same, and
  `/usage/mock-mode` returns `{'error': str(e)}`. These can surface DB driver
  text, connection strings, or internal paths.
- Exploit Path: Lower than the prior L-7 because all three are
  `@require_auth @require_admin`. An attacker would already need an admin JWT.
  Still an unnecessary internal-detail leak and an inconsistency with the
  rest of the codebase's now-generic error handling.
- Remediation: Replace the `detail`/`str(e)` payloads with a generic message;
  `logger.exception` already captures the detail server-side.
- Effort: S | Needs decision: No.

### S-05 | Per-user avatar rate limit is per-process and unbounded in memory
- Severity: Medium | CWE-770 (Allocation Without Limits) / CWE-837
- File: `backend/routes/avatar_routes.py:54-75` (`_check_avatar_rate_limit`,
  `current_app._avatar_generate_counts`)
- Description: The avatar generation rate limit is enforced through a plain
  `dict` stored on `current_app`. (a) The Dockerfile / railway.toml run
  gunicorn with `--workers 2`; each worker process holds its own dict, so the
  effective limit is 2x the intended one and a client load-balanced across
  workers gets double the avatar generations (each generation is metered
  Gemini/Replicate spend). (b) The dict keys are `f"{user_key}:{hour_bucket}"`
  and are never evicted — every distinct user and every hour adds a permanent
  entry, an unbounded memory growth over the process lifetime.
- Exploit Path: A high-cost-control (paid image generation) is under-enforced
  by a factor of the worker count, weakening the cost circuit breaker; and a
  long-lived process slowly leaks memory proportional to unique-users x hours.
- Remediation: Move the counter into the existing Redis-backed flask-limiter
  (a dynamic per-tier `limiter.limit`), which is shared across workers and
  self-expiring. If the in-process path must stay, evict buckets older than
  the current hour on each call.
- Effort: M | Needs decision: No.

### S-06 | IAP server-to-server notification endpoints are unauthenticated stubs
- Severity: Medium | CWE-306 (Missing Authentication for Critical Function) —
  latent | OWASP API2 / API8
- File: `backend/routes/iap_routes.py:223-277`
  (`/iap/apple/notifications`, `/iap/google/notifications`,
  `_handle_notification_stub`)
- Description: Both store S2S notification endpoints are registered, public
  (no `@require_auth`, no signature check), and respond `200` with
  `{"handled": false}`. Today they mutate no state, so there is no current
  exploit. The risk is the phase-2 TODO: the in-code plan correctly notes that
  the JWS / Pub/Sub OIDC token must be verified, but the route already exists
  and a future "wire up the handler" change could land the entitlement-
  granting logic without the signature verification, since the endpoint is
  already returning 200.
- Exploit Path (post-phase-2, if signature check is skipped): an attacker
  POSTs a forged Apple `signedPayload` / Google Pub/Sub envelope claiming a
  renewal and is granted a paid tier for free.
- Remediation: Before any entitlement logic is added, implement Apple JWS x5c
  chain verification and Google Pub/Sub OIDC token verification (or re-query
  the store API for authoritative state and never trust the body). Add a code
  comment / test that fails if `_handle_notification_stub` is replaced without
  a verification call. Track explicitly so phase 2 cannot regress it.
- Effort: M (phase-2 work) | Needs decision: No (the requirement is fixed; it
  is engineering, not a product call).

---

## LOW / INFORMATIONAL

- **S-07** CWE-1188 — `JWT_ACCESS_TOKEN_EXPIRES` / `JWT_REFRESH_TOKEN_EXPIRES`
  are set with `app.config.setdefault(...)` at `app.py:639-640`, *after*
  `JWTManager(app)` is constructed at `app.py:636`. flask-jwt-extended reads
  these lazily at token-mint time so the 1h/30d values do apply today, but the
  ordering is fragile and `setdefault` means an env/config override silently
  wins. Fix: set both on the config class (`config/__init__.py`) before
  `JWTManager` is created, and use `=` not `setdefault`. Effort S.

- **S-08** CWE-200 — nginx CSP `connect-src 'self' https: wss:` is a wildcard
  for all HTTPS/WSS hosts (`nginx.conf:50`). Acknowledged in the prior audit's
  caveats; still open. Once the Railway backend domain is stable, tighten to
  the concrete origin. Effort S.

- **S-09** CWE-489 — `/setup-test-account` and the `CONSENT_TEST_BYPASS`
  dart-define are correctly production-guarded, but `/debug-gemini` and
  `/debug-openrouter` remain registered in production (admin-gated). They
  perform live metered API calls. Low risk given the admin gate; consider an
  `is_production()` guard so a leaked admin token cannot run up spend. Effort S.

- **S-10** CWE-532 — `app.py:684` logs the first 200 chars of slow SQL
  statements. SQL text, not bound parameters, so no PII — informational only.

- **S-11** CWE-307 — `/auth/login` is rate-limited `10 per minute` but the
  limit is bypassable via S-01. There is no account-lockout / failed-attempt
  backoff independent of the rate limiter. Once S-01 is fixed the 10/min cap
  is meaningful; consider an additional per-account failed-login counter for
  defense in depth. Effort S.

- **S-12** CWE-1104 — `.github/` workflow actions: prior L-11 pinned
  `setup-python@v5`, `codecov-action@v5`, `slack-github-action@v2`. Spot-check
  confirms current majors; no new outdated action observed. Informational —
  re-verify on the next dependency review.

- **S-13** Informational — `optional_auth` swallows all `jwt.InvalidTokenError`
  silently (`auth.py:347-349`). Correct for optional auth, but a sudden spike
  of invalid tokens (a key-rotation mistake, an attack) is invisible. Consider
  a debug-level counter/log. Effort S.

---

## Chain-of-verification (Critical/High re-read)

S-01 re-read against `app_helpers.py:41-61` and `app.py:302-307`: confirmed
`get_user_identifier` is the limiter `key_func` and returns `user:{X-User-ID}`
when no auth context is present, before the IP fallback. Confirmed
`X-User-ID` is attacker-supplied (a plain request header). Confirmed
unauthenticated rate-limited endpoints exist (`/auth/login`, `/auth/anonymous`).
Not a false positive. No other Critical/High in this audit.

## STRIDE matrix (security surfaces)

| Flow | Spoofing | Tampering | Repudiation | Info Disclosure | DoS | Elev. of Priv |
|---|---|---|---|---|---|---|
| Auth / session | JWT HS256, `sub`-only, `tv` revocation — OK | Token tamper rejected by signature — OK | `audit_log` on login/refresh — OK | tokens in secure storage — OK | **S-01** rate-limit bypass | `require_admin` gate — OK |
| Payment (Stripe) | webhook signature — OK | price-ID tier resolution — OK | `event_id` dedup table — OK | no PAN handled — OK | webhook retry-safe — OK | fail-closed unknown price — OK |
| Payment (IAP) | receipt verify (when enabled) — OK | identity from JWT — OK | `IapPurchase` row — OK | n/a | **S-06** unauth stub | fail-closed default — OK |
| LLM integration | n/a | `sanitize_story_request` recursive + `[USER_INPUT]` wrap — OK | n/a | `STRICT_OUTPUT_CONSTRAINTS` anti-leak — OK | quota / cost breaker — OK | M-6 age clamp — OK |
| Child data | consent gate — OK | — | consent record — OK | **S-03** CBC integrity; photos→3P (audit 02 F-07) | — | minor age cap — OK |

## Compliance sub-sections

### COPPA §312
- §312.5(b) verifiable consent — INFRASTRUCTURE PRESENT, FLAG-GATED OFF.
  `COPPA_REQUIRE_VERIFIED_CONSENT` defaults false for the tester phase;
  must be set true before public launch (`auth.py:185-187`). Not a code bug —
  a launch-gate decision. (audit/LEGAL-COMPLIANCE.md CMP-2.)
- §312.4 notice accuracy — prior C-1 resolved by corrected disclosure copy.
- §312.5(a) collection before consent — prior M-9/M-10 fixed (analytics off
  pre-consent, age persisted post-consent).
- §312.8 minimization / third-party disclosure — hero name pseudonymized
  (M-7). Child photos to Gemini/Replicate: see audit 02 F-07 (MT-157), not
  re-reported here.
- §312.6 erasure/access — backend delete endpoints + `data_retention.py`
  purge job; `delete_user_data` bumps `token_version` (M-1).

### PCI DSS SAQ-A
SAQ-A eligibility preserved. Stripe checkout and billing portal are hosted-
redirect; no PAN/CVV/expiry touches backend or client. IAP routes carry no
card data (store-mediated). Webhook signature verified, fails closed if the
secret is unset. S-01/S-06 are availability/authorization issues, not
cardholder-data exposure — PCI scope unchanged.

### OWASP LLM Top 10 (security dimension only)
- LLM01 Prompt Injection — recursive `sanitize_story_request` +
  `[USER_INPUT]` wrapping + `STRICT_OUTPUT_CONSTRAINTS` (prior H-3/H-4/C-3
  fixed). Content-side injection in the generation pipeline: see audit 02.
- LLM02 Sensitive Info Disclosure — hero-name pseudonymization (M-7).
- LLM06 Excessive Agency — M-6 age clamp; model output is never executed.
- LLM07 System Prompt Leakage — `STRICT_OUTPUT_CONSTRAINTS` instructs against
  echoing instructions; low residual risk.
- LLM10 Unbounded Consumption — quota + cost circuit breaker; **S-05** weakens
  the avatar sub-limit; **S-01** weakens unauthenticated rate limiting.
- LLM03/04/05/08/09 — see audit 02 for the content/output-handling dimension.

---

## Prior-audit regression check (2026-05-16/17 findings vs current source)

Confirmed STILL FIXED in current source:

| Prior ID | Status | Evidence |
|---|---|---|
| C-1 photo disclosure | Fixed (by disclosure) | PRIVACY_POLICY.md + consent copy corrected |
| C-2 key in git history | Resolved | key expired/rejected by Google |
| C-3 avatar prompt validation | Fixed | (audit 02 covers avatar content path) |
| H-1 test-account endpoint | Fixed | `utility_routes.py:212-213` 404 in prod, random pw |
| H-2 webhook tier from metadata | Fixed | `webhook_handler.py:74-125` price-ID map, fail-closed |
| H-3 interactive custom_text | Fixed | recursive sanitizer + interactive classifier |
| H-4 worldBible/conflictHook bypass | Fixed | `sanitizer.py:46-53,180-196` recursive + wrap |
| H-5 BYOK key copy | Fixed (by disclosure) | wizard copy corrected; key still sent to backend (accepted) |
| H-6 Android secure storage | Fixed | `flutter_secure_storage ^10.0.0` encrypts by default |
| H-7 JWT in SharedPreferences | Fixed | `SecureStorageService` save/getUserToken+RefreshToken |
| H-8 verifiable consent | Code done, flag-gated | `COPPA_REQUIRE_VERIFIED_CONSENT` — launch gate |
| M-1 token TTL + revocation | Fixed | TTL 1h; `tv` claim checked in `require_auth` |
| M-3 webhook idempotency | Fixed | `StripeWebhookEvent` + `StripeSubscriptionCursor` |
| M-12 health endpoint leak | Fixed | `/health` minimal; detailed admin-gated |
| M-13 containers run as root | Fixed | non-root `app` USER in Dockerfiles |
| M-14 build toolchain in runtime | Fixed | multi-stage Docker builds |
| M-16 singleton anonymous user | Fixed | `utility_routes.py:257-262` rejects `anonymous` id |
| L-2 CORS http downgrade | Fixed | `config/__init__.py:166-170` dev-only |
| L-8 user_id claim fallback | Fixed | `auth.py:72` `sub`-only |
| L-9 gunicorn config drift | Fixed | single command; nixpacks removed |
| L-10 nginx headers | Fixed | `server_tokens off` + CSP/HSTS |

NOT fully fixed — regression / partial:

| Prior ID | Finding | This audit |
|---|---|---|
| L-7 raw `str(e)` in 500 responses | api_key_routes.py was swept, but `utility_routes.py` `/usage/*` was missed | re-filed as **S-04** |

Other prior caveats verified: `backup_database.py:66` syntax error
(`exit(1)</content>`) is FIXED — current source has clean `exit(1)`.
