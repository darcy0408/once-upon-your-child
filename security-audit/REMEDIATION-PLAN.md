# Story Weaver — Security Remediation Plan

Date: 2026-05-16
Source: `SIX-HATS-20260516.md` and per-hat sub-files.
Status legend: ☐ todo · ◐ needs decision · ✅ done

This plan groups the 27 actionable findings (C-2 already resolved) into 5 work packages (WP-A … WP-E). Work packages touch mostly disjoint file sets so they can be executed by parallel agents without merge conflicts. Each agent edits the working tree only — **no commits, no git operations** — so you review everything before it lands. C-1, H-5, and H-8 are gated on the decisions in the "Decisions required" section.

---

## Execution status — 2026-05-16

P0 + P1 batch executed by 5 parallel agents. 8 backend files + 9 Flutter files changed; backend syntax OK, `flutter analyze` clean (1 pre-existing info lint).

| Finding | Status | Notes |
|---|---|---|
| C-1 | ✅ Done (by disclosure) | Per owner decision, the photo→AI avatar feature was KEPT (on-device revert reverted). Resolved by removing the false "never leaves the device" claims and adding accurate disclosure: `PRIVACY_POLICY.md` (new "Character & Avatar Data" collection entry + corrected Third-Party Services line) and `parental_consent_screen.dart` (3 corrected strings). Photo-avatar opt-in toggle remains the consent point. **D6 ✅ resolved:** backend verified NOT to persist the photo — `photo_bytes` is request-scoped memory only, never written to disk/DB. The photo IS sent to the active third-party image provider (Gemini primary; Replicate/OpenRouter fallback) — now disclosed in `PRIVACY_POLICY.md` Third-Party Services. Recommended: confirm those providers' data-retention / no-training terms. |
| C-3 | ✅ Done | `validate_photo_avatar_prompt_safety` now runs on all avatar paths; free-text fields sanitized + 200-char capped. |
| H-1 | ✅ Done | `/setup-test-account` guarded (404 in prod) + random password — not deleted, 9 tests depend on it. |
| H-2 | ✅ Done | Webhook derives tier from the actual paid price ID; fails closed on unknown price. |
| H-3 | ✅ Done | Interactive `custom_text` sanitized + `[USER_INPUT]`-wrapped; LLM classifier added to interactive path. |
| H-4 | ✅ Done | `sanitize_story_request` is now recursive — every string field safe by default (also closes L-4). |
| H-5 | ✅ Done (by disclosure) | Owner chose to keep BYOK routing through the backend (key encrypted at rest, AES-256). Resolved like C-1 — the false "never leaves your device / we never see it" wizard copy was corrected to accurately state the key is sent to our servers and stored encrypted (`byok_setup_wizard.dart:321-323`). |
| H-6 | ✅ Done | Secure storage configured (note: `flutter_secure_storage` v10 encrypts by default; iOS accessibility set). |
| H-7 | ✅ Done | JWT access + refresh tokens moved to secure storage with one-time migration. |
| H-8 | ✅ Code done — needs Railway/Resend setup | Flutter UI + backend complete: `consent/request-verification` & `consent/verify` endpoints, `ConsentRecord.verified` + `ConsentVerificationCode` table, Resend email service, migration. 6-digit code, hashed at rest, 15-min expiry, 5-attempt cap, owner-scoped + rate-limited. **Operational steps remain (D4 closed):** set `RESEND_API_KEY` + `CONSENT_EMAIL_FROM` on Railway and verify the sending domain in Resend — until then `request-verification` returns 503 and under-13 onboarding stays blocked (fails closed). |

### New decisions surfaced during execution
- **D4 (H-8 backend):** The consent email round-trip needs backend endpoints (`POST /api/user/<id>/consent/request-verification`, `.../verify`), a `ConsentRecord.verified` column + code store, and an email-sending provider. **Until built, under-13 signups are blocked** (fails closed — intentional, no false consent recorded). Pick an email provider before this can proceed.
- **D5 (BYOK scope):** BYOK now offloads story *text* to the client, but illustrations/coloring still use the server-managed image key. BYOK no longer reduces server image cost — decide whether BYOK stays a premium unlock or whether a client-direct image path is worth building.

### Not yet started
P2/P3/P4 (Medium/Low) — see work packages below; WP-E (infra) untouched. M-12 partially overlaps the H-1 agent's flagged `debug-gemini`/`debug-openrouter` env-leak siblings.

---

## Decisions required before execution

| # | Finding | Decision | Options |
|---|---|---|---|
| D1 | C-1 (child photos) | How to reconcile the "photos never leave the device" promise | (a) Correct the copy to disclose the upload + name the processor [M] · (b) Move avatar generation on-device so the promise becomes true [L] · (c) Disable photo avatars entirely [S] |
| D2 | H-5 (BYOK key) | How to reconcile "your key never leaves the device" | (a) Correct the copy to state the key is sent to the backend [M] · (b) Route BYOK requests client-direct to Gemini so the promise becomes true [M] |
| D3 | H-8 (verifiable consent) | Which COPPA sliding-scale method | (a) Email round-trip confirmation [M] · (b) Stripe $0.50 authorize-and-void [L] · (c) Both — email default, card for photo-grade data [L] |

---

## WP-A — Backend auth & API hardening
Agent: backend-auth. Files: `backend/routes/utility_routes.py`, `health_routes.py`, `api_key_routes.py`, `progression_routes.py`, `backend/middleware/auth.py`, `backend/config/__init__.py`, `backend/routes/avatar_routes.py`, `backend/app.py`.

- ☐ H-1 — delete or `is_production()`-guard `/setup-test-account`; remove hardcoded creds.
- ☐ M-1 — shorten access-token TTL to ≤1h; add a `tv` (token-version) claim and check it in `require_auth`; bump `token_version` on logout/data-deletion.
- ☐ M-12 — `/health` returns only `{status,version}`; gate `/health/detailed` + `/health/database` behind auth; remove `env_keys` from `/debug-openrouter`; stop echoing `str(e)`.
- ☐ M-16 — never issue JWTs for the singleton `anonymous` user; ensure each anon session gets a unique `anon_*` id.
- ☐ L-1 — require auth on `/validate-api-key` (or add CAPTCHA + tighten limit).
- ☐ L-2 — only add the `http://` CORS origin variant in dev (`config/__init__.py:156-157`).
- ☐ L-3 — set `app.config['MAX_CONTENT_LENGTH']`; cap `tweak_gallery_avatar` read; validate image magic bytes.
- ☐ L-6 — delete the dead `progression_routes.py` (unregistered mass-assignment sink).
- ☐ L-7 — replace raw `str(e)`/traceback in responses with generic messages; log detail server-side.
- ☐ L-8 — standardize identity on the `sub` claim; drop the `user_id` fallback.

## WP-B — Backend payments & entitlement
Agent: backend-payments. Files: `backend/routes/webhook_handler.py`, `stripe_routes.py`, `subscription_routes.py`, `backend/utils/ai_quota.py`, `backend/models/user.py`.

- ☐ H-2 — derive entitlement tier from the subscription's actual `items.data[0].price.id` via a server-side `{price_id: tier}` map; treat metadata as a hint only.
- ☐ M-3 — persist Stripe `event.id` (unique-constrained table); short-circuit duplicates; guard state transitions with the event timestamp.
- ☐ M-2 — split the quota subsystem: keep availability fail-open, but back the cost circuit breaker with a conservative DB counter so a Redis outage cannot uncap LLM spend; alert + global rate cap on Redis-down.
- ☐ M-17 — unify the two quota systems; drive `/api/user/usage` from the enforced source; remove the dead DB `*_this_month` path.
- ☐ M-12 (shared) — add `@require_owner('user_id')` to `/subscription-status/<user_id>` or drop the path param.
- ☐ M-8 (backend half) — ensure every premium-gated capability (coloring, interactive, multi-character, export) is enforced server-side off `User.subscription_tier`.

## WP-C — Backend LLM & child-safety
Agent: backend-llm. Files: `backend/utils/sanitizer.py`, `content_moderator.py`, `backend/services/interactive_adventure_service.py`, `interactive_adventure_prompt_builder.py`, `avatar_generation_service.py`, `story_service.py`, `prompt_service.py`, `backend/routes/story_routes.py`, image generator modules.

- ☐ C-3 — run `validate_prompt_safety` (or a stronger blocklist) on the fully assembled prompt for ALL avatar paths (`generate_custom_avatar`, `generate_pet_avatar`, `generate_human_companion_avatar`); sanitize + length-cap `refinement_note`/`breed_description`.
- ☐ H-3 — route interactive `custom_text` through `sanitize_for_prompt` + `wrap_user_input(...,'player_choice')`; add `moderate_story_content` to the interactive filter path.
- ☐ H-4 — replace the `sanitize_story_request` field allowlist with a recursive pass that sanitizes + `[USER_INPUT]`-wraps every string field (closes `worldBible`/`conflictHook`/`sensoryPalette` and L-4 permanently).
- ☐ M-4 — wire the LLM contextual classifier into the interactive path; fail-closed (serve a safe fallback) for the Sprout band when the classifier errors.
- ☐ M-5 — add an image-output safety check before display, or restrict Flux providers to a vetted prompt template.
- ☐ M-6 — derive the content age band from the authenticated account's verified age / owned `Character` record; allow downward override only.
- ☐ M-7 — pseudonymize the hero name (`HERO_1`) before any provider call; substitute back locally.
- ☐ L-4 — covered by the H-4 recursive-sanitizer refactor.

## WP-D — Flutter client & COPPA
Agent: flutter-client. Files: `lib/services/secure_storage_service.dart`, `api_service_manager.dart`, `firebase_analytics_service.dart`, `lib/screens/parental_consent_screen.dart`, `welcome_screen.dart`, `lib/custom_avatar_screen.dart`, `lib/services/privacy_service.dart`, plus copy in `PRIVACY_POLICY.md` / `byok_setup_wizard.dart` (per D1/D2).

- ☐ H-6 — `AndroidOptions(encryptedSharedPreferences: true)` + `IOSOptions(accessibility: first_unlock_this_device)`.
- ☐ H-7 — move JWT access + refresh tokens from `SharedPreferences` to `flutter_secure_storage`.
- ☐ H-8 — implement the chosen verifiable-consent method (D3); never record `consent_method='email_verified'` unless an email was actually verified.
- ☐ C-1 — per D1: correct policy/consent/kid-summary copy, or move avatar gen on-device, or disable photo avatars.
- ☐ H-5 — per D2: correct BYOK wizard/consent copy, or route BYOK calls client-direct to Gemini.
- ☐ M-9 — default Firebase Analytics collection OFF; enable only after verified consent AND declared age ≥ 13; wire `PrivacyService.setAnalyticsConsent` to the consent result.
- ☐ M-10 — defer all age persistence until after consent; make the age screen neutral (no celebration/TTS gamification).
- ☐ M-11 — enforce `getAllowPhotoAvatar()` inside `CustomAvatarScreen.initState` / before camera invocation.
- ☐ M-15 — drive the consent test-bypass from a compile-time `--dart-define` defaulting off.
- ☐ M-8 (client half) — treat client premium/grace/unlock flags as cosmetic; do not let local counters override the backend downward.
- ☐ L-5 — route logging through `LoggerService`; remove raw `debugPrint` of `user_id`/auth lifecycle.

## WP-E — Infrastructure & supply chain
Agent: infra. Files: `Dockerfile`, `Dockerfile.worker`, `Dockerfile.frontend`, `nginx.conf`, `nixpacks.toml`, `.github/workflows/*.yml`.

- ☐ M-13 — add a non-root `USER` to all three Dockerfiles; use `nginxinc/nginx-unprivileged` for the frontend.
- ☐ M-14 — convert the backend + worker images to multi-stage builds (compile wheels in a builder stage, copy site-packages into a clean runtime).
- ☐ L-9 — standardize on one gunicorn start command; remove `nixpacks.toml` (or the dead Dockerfile `CMD`); drop `--log-level debug`.
- ☐ L-10 — `server_tokens off;` in `nginx.conf` + a frontend CSP / `Referrer-Policy` / HSTS header block.
- ☐ L-11 — pass the Railway token via `env:` not a CLI arg; pin `actions/setup-python`, `codecov-action`, `slack-github-action` to current majors.

---

## Execution model
- 5 agents run in parallel, one per work package. File sets are disjoint except `app.py` (WP-A only) and `story_routes.py` (WP-C only) — no cross-WP conflicts.
- Agents edit the working tree only. **No git commits, no `git` mutations** — avoids the known parallel-session index race; you review and commit.
- C-1 / H-5 / H-8 work proceeds only after D1 / D2 / D3 are answered.
- After agents finish: run `flutter analyze` + backend test suite, review diffs, then commit per work package.

## Out-of-scope follow-ups (separate effort)
- Backend-side child-photo retention / onward-transfer to Cloudflare (needed to fully close C-1).
- `chronicle_prompt_service.py` and `openrouter_story_generator.py` safety-parity review.
- Isar local-DB encryption-at-rest for child stories/profiles.
- Optional: git history scrub of the (now-dead) C-2 key string.
