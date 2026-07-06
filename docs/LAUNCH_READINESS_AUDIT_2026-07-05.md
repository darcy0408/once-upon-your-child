# Launch-Readiness Audit — 2026-07-05 (COMPLETE)

**Method:** ultracode multi-agent audit. 7 parallel dimension auditors (secrets/config, COPPA-in-code, vendor-terms, authz/data-security, data-lifecycle, content-safety, client-trust) → adversarial refuter panel (3 independent refuters per launch_blocker, 1 per lesser finding, each told to *refute* and to read the code themselves) → coverage critic.

**Run status: COMPLETE.** Ran across three sessions (two hit the token limit mid-flight; the third finished 49/49 agents, 0 errors, via cache-resume). Every finder ran, every finding was adversarially verified, the critic ran. Raw output: `tasks/wmdvqnt1l.output`; journal: `subagents/workflows/wf_a337cf1a-bdd/journal.jsonl`.

**Verdict:** Not launch-ready. **~5 distinct launch blockers**, all in two clusters: (A) children's data still reaches Google Gemini despite PR #319, and (B) the server-side COPPA consent gates are defeatable (default-off + two forgery paths). Both clusters are code fixes plus one ops flip, not redesigns.

---

## 🔴 LAUNCH BLOCKERS

### Cluster A — child data still reaches Gemini (Gemini API ToS forbids under-18 apps; this is your MT-137 blocker, still live)

1. **Chronicle → Gemini** · `backend/routes/chronicle_routes.py:61,115`
   `/chronicle/summarize-chapter` and `/compress-arc` send a child's full story chapter (≤50k chars) to Gemini under the **server key** — `require_auth` only, no age/consent gate. Client-wired (Pick-a-Path chapter completion), undisclosed in the privacy policy. Verified 3/3 refuters.
   **Fix:** port `ChroniclePromptService` to OpenAI (mirror `backend/utils/content_moderator.py`), or disable the blueprint until ported.

2. **Avatar tweak → Gemini** · `backend/routes/avatar_routes.py:1291-1295` *(independently found by 3 dimensions — vendor-terms, data-lifecycle, content-safety)*
   `/avatar/tweak-gallery-avatar` builds a direct `GeminiImageGenerator()` on the server key for premium/family child accounts and **bypasses the prod `DISABLE_GEMINI_IMAGE=1` kill switch** (route never checks it). Verified 3/3.
   **Fix:** route through `AvatarGenerationService`/`OpenAIImageGenerator` like the other avatar endpoints, or gate behind `ALLOW_DIRECT_GEMINI_IMAGE` + a BYOK-key requirement. Confirm `GEMINI_API_KEY` is unset on the Railway web service as defense-in-depth.

### Cluster B — server-side COPPA consent is defeatable

3. **All three consent gates default OFF** · `backend/middleware/auth.py:184,232,257` *(corroborated by the authz dimension: `coppa-consent-fails-open-unaged`, `coppa-verified-consent-flag-off-by-default`)*
   `ENFORCE_RESOLVED_AGE`, `COPPA_REQUIRE_VERIFIED_CONSENT`, `COPPA_REQUIRE_CURRENT_POLICY_VERSION` all default `false` and are set nowhere in repo config; `POST /auth/anonymous` mints a JWT with no age → `is_under_13=False` → `/generate-story`, `/generate-custom-avatar` (photo upload), `/tts/synthesize`, `/create-character` all callable **pre-consent**. Verified 3/3.
   **Fix (ops, MT-310):** flip all three to `true` (clean values) on the Railway backend — **but** close #4 and #5 first or the flip is hollow.

4. **Verified consent is client-forgeable** · `backend/routes/user_routes.py:248` — *not previously in the gap register*
   `POST /api/user/<id>/consent` accepts a client-asserted `verified=true` for non-email methods (`parent`, `self_attested`, `debug_bypass`) → one API call forges verified parental consent, defeating gate #3 even after the flip. Verified.
   **Fix:** force `verified=False` for all records created via `record_consent` (only `/consent/verify` may set true); reject/env-gate `debug_bypass` outside dev; add a regression test.

5. **Age-redeclaration bypass** · `backend/routes/user_routes.py:181` — *not previously in the gap register*
   `PATCH /api/user/<id>/age` lets an actual-knowledge under-13 account re-declare 13+ anytime → `is_under_13=False` → consent gate passes unconditionally. Verified.
   **Fix:** in `set_declared_age`, refuse (or require fresh parental verification for) an upward change when the account has any `ConsentRecord` with `child_age < 13` or a prior `declared_age < 13`; audit-log the attempt.

---

## 🟠 HIGH

- **`photo-avatar-optin-not-enforced`** · `backend/routes/avatar_routes.py:246` — the `allow_photo_avatar` parental opt-in is stored but **never read**; `/generate-custom-avatar` accepts a child photo (biometric-class PI) with only the generic consent gate, contradicting the consent-screen promise. **Fix:** load latest non-withdrawn `ConsentRecord`, 403 when `allow_photo_avatar` is False for under-13.
- **`gemini-tts-13-17`** · `backend/routes/tts_routes.py:477` *(found by 4 dimensions)* — TTS fallback gates on `is_under_13` only, so 13-17 minors get Gemini Flash TTS (under-18-barred) when Azure is down/unset. **Fix:** change gate to under-18.
- **`invalid-story-provider-coerces-to-gemini`** · `backend/app.py:474` — an unrecognized `STORY_GEN_PROVIDER` typo coerces to `"gemini"`, routing all story text Gemini-first. **Fix:** one line → `"openai"`.
- **`gemini-byok-promo-copy-on-child-profiles`** · `lib/screens/parent_controls_screen.dart:388` — FIX_PLAN A2 unfixed; "Unlock Premium Features — Free / connect a Google Gemini key" still solicits parents. **Fix:** execute A2 (provider-neutral or hide for under-13).
- **`child-pii-in-server-logs`** · `backend/tasks/story_tasks.py:1547` — child names/ages/full personalized prompts logged at INFO on Railway, no retention control. **Fix:** demote to DEBUG (off in prod) or redact child identifiers before logging.
- **`retention-policy-not-published`** · `PRIVACY_POLICY.md:106` (gap G-4) — no retention schedule meeting the Amended Rule's 3-part test; R2 backup tail, 365-day illustration cache, 30-day unconsented-contact window all undisclosed; policy still v2. **Fix:** add the schedule table, bump to v3, mirror in the consent direct notice.
- **`crisis-detection-only-one-freetext-path`** · `backend/routes/story_routes.py:1847` — **NEW, found by the coverage critic.** Server-side self-harm/crisis detection guards only the interactive "Something Else" box; the **linear-story free-text fields (`custom_elements`, antihero `hero_secret`, `therapeutic_prompt`) reach the LLM with no crisis routing.** **Fix:** call `detect_crisis()` on all raw child/parent free-text before generation in every endpoint, returning `crisis_response()` as the continue-endpoint already does.

---

## 🟡 MEDIUM

- **`byok-consent-gate-client-side-only`** · `story_routes.py:2225` — backend accepts `user_api_key` with no server-side record of the parent acknowledgment. **Fix:** persist ack timestamp; refuse the key without it.
- **`theme-field-prompt-injection`** · `backend/utils/sanitizer.py:26` — `theme`/`tone`/`style`/`gender`/`pronouns` exempt from sanitization as "structural," never allowlist-validated → raw uncapped injection into prompt f-strings (bounded by output moderation). **Fix:** allowlist-validate or remove from `_STRUCTURAL_KEYS` + cap + sanitize.
- **`moderation-fallback-fail-open`** · `backend/tasks/story_tasks.py:2132` — a flagged minor's story is replaced by a fresh LLM generation served with **no re-moderation**; `if fallback_body:` has no `else` (empty extraction persists the flagged text). **Fix:** re-moderate the fallback; if the flag reason was "moderation unavailable," serve the *static* fallback.
- **`share-ungated-adventurer`** · `lib/story_result_screen.dart:5032` — reader Share (native OS sheet of full story text + "Hero: <child name>") is ungated for Adventurer 9-12 (under-13). No public URL created. *(A sloppier "no age gate at all" framing was correctly refuted; the precise under-13-Adventurer exposure stands.)* **Fix:** hide/gate for under-13; drop the name line for minors.
- **`character-routes-rate-limits-disabled`** · `backend/routes/character_routes.py:147-148` — decorator ordering disables `@limiter` on all four character endpoints. **Fix:** make `@route` the outermost decorator; add a 429 regression test.
- **`audit-log-no-retention-survives-erasure`** · `backend/models/audit_log.py:14` — `AuditLog` rows with IPs accumulate indefinitely and survive right-to-erasure; promised 90-day purge doesn't exist. **Fix:** scheduled purge + null the IP for erased users.
- **`illustration-cache-unreachable-by-erasure`** · `backend/services/data_retention.py:361-411` — cached illustrations (can embed a child likeness) have no owner column, so `purge_user_data` can't target them. **Fix:** add owner column, or shorten TTL + disclose the age-out window.
- **`direct-notice-missing-r2-statements`** · `lib/screens/parental_consent_screen.dart:391` (gap G-7) — consent direct notice missing the two Amended-Rule R-2 sentences. **Fix:** add both, batched with the G-4 v3 bump, routed past counsel.
- **`is-production-single-envvar-gate`** · `backend/utils/app_helpers.py:54` — `/setup-test-account` + 500-handler leak key only on `RAILWAY_ENVIRONMENT` (a refuter dropped this to low: live prod returns 404, guard holds; real consistency debt for any future non-Railway host). **Fix:** OR `FLASK_ENV` into `is_production()`.
- **`iap-lifecycle-nonfunctional-stub`** · `backend/routes/iap_routes.py:390` — **critic finding.** Mobile IAP is a Phase-1 scaffold (verification raises `NotImplementedError`; S2S handlers ACK 200 without applying entitlement). Fine for the web-first Stripe launch — **fail-closed with `IAP_VERIFICATION_ENABLED` off** — but blocks any mobile paid launch. **Fix:** keep the flag off for now; implement before mobile IAP.

---

## 🟢 LOW / preventive

- `database-url-prefix-logged` — first ~8 chars of the Postgres password logged on boot (`config/__init__.py:119`) → log hostname only.
- `csp-unsafe-eval-and-inline` — CSP allows `unsafe-eval` (Flutter only needs `wasm-unsafe-eval`) → test removing it.
- `dockerignore-missing-db-exclusion` — add `*.db`, `backend/instance/`, `backend/config/*.db` (dev DBs are gitignored but not dockerignored).
- `accessibility-wcag-ada-unaddressed` — CanvasKit web, only 37/308 Dart files use `Semantics(`; ADA Title III surface. Run an axe/screen-reader pass; publish an accessibility statement + timeline.
- Preventive: add `.env.*` to `.gitignore`.

---

## GENUINELY REFUTED (verifier read the code and cleared it)

- `byok-gemini-invite-under18` — under-18 BYOK data-to-Gemini risk mitigated by the existing acknowledgment doctrine (client claims accurate, core risk not).
- `share-not-age-gated` — the "no age/band condition at all" framing is false; the chip IS inside `if (!isYoungUser)`. (The narrower under-13-Adventurer exposure survives as the medium above.)
- `elevenlabs-no-client-age-gate` — client claims correct but the under-13 voice risk is fully mitigated server-side.

---

## SOLID (verified good)

No live secrets committed (only public Firebase web keys + Sentry DSN). `.env` gitignored + dockerignored. Prod refuses to boot with a default/short JWT secret. CORS is a strict allowlist. Debug/health endpoints double-gated (admin + prod). Cloudflare `_headers` ships HSTS + correct CanvasKit CSP. Interactive/Pick-a-Path crisis detection, moderation on the interactive path, and the antihero moderation path all verified working.

---

## Recommended fix order (cheaper models can execute against this doc — no Fable needed)

1. **One "no Gemini for minors, ever" PR** — closes blockers #1, #2, the two `gemini-tts` highs, and `invalid-story-provider` in a single sweep across chronicle, avatar-tweak, TTS, and the provider default. Highest leverage.
2. **One "harden server-side consent" PR** — closes #4 (`verified` forgery) and #5 (age redeclaration), *then* do the MT-310 ops flip for #3.
3. **Crisis detection on all free-text paths** (`crisis-detection-only-one-freetext-path`) — highest-conscience item on a therapeutic kids' app; small, isolated fix.
4. **Photo opt-in enforcement** + **PII-in-logs redaction** — two small backend PRs.
5. **Policy v3 batch** (retention schedule + R-2 notices) — the owner/counsel doc task, not code.
6. Mediums (rate-limit decorator order, share gating, moderation-fallback, caches/audit retention) as a cleanup PR.
