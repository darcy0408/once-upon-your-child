# Safety & Compliance Audit — Remediation Tracker

Source: pre-launch Safety & Compliance Audit (Pass 1–2), 2026-06-28/29. Severities
calibrated against **prod Railway env flags**, not code alone (some code-level
findings are neutralized by prod config — noted inline).

Status legend: ☐ todo · ◐ in progress · ☑ done (PR #) · ↪ delegated to another
session · ⊘ accept / won't-fix

> **App is pre-launch (no live users).** Nothing here is a live incident; items
> are gated on *launch*, not on production traffic.

## Status as of 2026-07-01
This audit was worked by several parallel sessions. Ownership split — **all
tracked PRs are now merged to main:**

| Area | Owner | State |
|---|---|---|
| Purchase gating (P0 cluster) | this audit | ☑ **#321** |
| Generation-output egress + teen fail-closed (PR 2+3 combined) | this audit | ☑ **#332** |
| Authz/generator hardening (PR 6-lite) | this audit | ☑ **#335** |
| COPPA consent/collection + posture (PR 4+5) | `session/legal-fixes` | ☑ **#320** |
| Analytics off-by-default (under-18, CAADCA) | `session/privacy-defaults` | ☑ **#333** |
| Crisis-resources panel (PR 7 allowlist) | `session/crisis-input-scan` | ☑ **#334** |
| BYOK image-gen hardening + PP disclosure | `fix/gemini-byok-consent-guard` | ☑ **#319** |
| LLM moderator decouple Gemini→OpenAI (launch-gate) | overnight sweep | ☑ **#341** |

**Remaining code work: none.** P2#17 (Isar at-rest encryption) was resolved
⊘ not-implementable-in-Isar-3.1.0 on 2026-07-03 (OS file-based encryption covers
it; see PR 7 below). P2#14 was reclassified won't-fix (see PR 6-lite). Everything
else is owner-ops config flips or external legal/clinical sign-off.

## Sequenced PRs

### PR 1 — Purchase gating (the P0 cluster) — ☑ #321
- ☑ **P0** Gate the illustration-upsell → `SubscriptionScreen` push behind `showPaywallGated` — `story_result_screen.dart`.
- ☑ **P1#3** Paywall gate: addition → multiplication — `utils/paywall_gate.dart`.
- ☑ **P1#4** Gate **all** minor bands + null/indeterminate; only explicit Adult bypasses — `utils/paywall_gate.dart`.
- ☑ **P2#21** Gate the three dead `PaywallDialog` methods' ungated pushes — `paywall_dialog.dart`.
- ☑ Tests: `test/paywall_gate_test.dart` (8).
- **Out of scope (documented):** `settings_screen.dart` "Real Stripe Checkout (test card 4242…)" is dev-tools-only (`Environment.isDevelopment`), not a production child path.

### PR 2 + 3 — Generation-output egress + fail-closed for minors — ☑ #332 (combined)
- ☑ **P1#2** Deterministic `scrub_external_links()` on final title + pages + body — `utils/sanitizer.py`, wired in `tasks/story_tasks.py`. URL clause added to moderator UNSAFE list — `content_moderator.py`. *(Scrub-only; share-out left ungated to preserve the parent share flow.)*
- ☑ **P1#8** Fail closed for every minor (`age <= 17`), not just `<= 12` — `story_tasks.py`.
- ☑ **P2#25** Antihero crux (15–17) fails closed — `story_tasks.py`.
- ☑ Tests: `test_external_link_scrub.py` (15) + antihero mocks updated.

### PR 6-lite — Authz & generator hardening — ☑ #335
- ☑ **P2#13** Symmetric owner guard on `/task-status` (SUCCESS no longer leaks on null owner) — `story_routes.py`.
- ☑ **P2#15** Regex-validate `avatar_id` → 400 — `avatar_gallery_routes.py`.
- ☑ **P2#16** IAP `user_id` ownership check before reassignment — `iap_routes.py`.
- ☑ **P2#23** OpenRouter generator child-safety system prompt — `openrouter_story_generator.py`.
- ☑ Tests: `test_authz_hardening.py` (3).
- ⊘ **P2#14** refresh-blocklist fail-closed on Redis outage — **won't-fix (reclassified 2026-07-01).** Verified in code: the Redis blocklist (`app.py` `_check_token_revoked`) only tracks *spent refresh tokens* and fails **open** on a Redis outage *by design* — making it fail-closed would lock every user out during any Redis blip. The authoritative revocation control is the DB `token_version` claim (`middleware/auth.py`), which **fails closed** on mismatch and invalidates all tokens on logout/data-deletion. Same decision already recorded under "Accept / won't-fix" below (JWT refresh fail-open). No code change.

### PR 4 — COPPA collection + PII logging + Sentry — ↪ #320 (`session/legal-fixes`)
Covers `@require_parental_consent` on character creation, PII/prompt log redaction, Sentry breadcrumb scrub, `allow_photo_avatar` enforcement. *Do not duplicate — coordinate with that branch.*

### PR 5 — COPPA posture & config — ↪ #320 + ops
- ↪ `debug_bypass` removal / verified-consent default — `session/legal-fixes`.
- **Ops (owner, Railway):**
  - ☑ `GEMINI_API_KEY` rotated 2026-06-29 (old key revoked at Google, new key in Railway).
  - ☐ Set `COPPA_REQUIRE_CURRENT_POLICY_VERSION=true` — **pre-flight first:** `CURRENT_POLICY_VERSION = 2`; enabling re-prompts every under-13 whose consent record is `NULL`/`< 2`. Count by version in prod Postgres before flipping; backfill or accept a re-prompt wave.

### PR 7 — Data-at-rest & external surfaces
- ↪ **P2#22** Crisis-resource host allowlist — `session/crisis-input-scan` already edits `crisis_resources_panel.dart`.
- ⊘ **P2#17** Isar `encryptionKey` for offline child PII — **not implementable as written (resolved 2026-07-03).** Isar **3.1.0 (our pinned version) has no `encryptionKey` / at-rest-encryption API** — the feature does not exist in this release line, so the remediation as specified cannot be built. Mitigation that *does* cover the risk today: OS-level file-based encryption (Android FBE on all supported devices; iOS Data Protection), which encrypts the Isar file at rest whenever the device is locked. Web builds use the `SharedPreferences` stub (browser storage, no Isar file). **Post-launch follow-up:** re-evaluate when moving off Isar 3.x (Isar 4 / drift+sqlcipher / encrypted alternative) — track as a v1.1 item, not a launch gate. PP-disclosure half was superseded by #319's privacy-policy work.

## Launch-gate follow-ups (not fires; close before going live)
- ☑ **Decouple the LLM moderator from Gemini** — **PR #341 (merged 2026-07-01).** The layer-2 LLM moderator in `backend/utils/content_moderator.py` now runs on the same OpenAI client/model as story text (`OPENAI_API_KEY`, `gpt-5-mini`; mirrors `openai_story_generator`), with new optional `OPENAI_MODERATION_*` env overrides. Public interface + safety posture (fail-open default, fail-**closed** for minors) preserved, so callers are unchanged. `GEMINI_API_KEY` no longer needed by the moderation path — drop it after prod-verify (still an image last-resort; see [[MT-295]] / MT-313). Original note below:
- ☐ **(original) Decouple the LLM moderator from Gemini.** `content_moderator.py` runs `gemini-2.5-flash-lite`, so layer-2 moderation depends on `GEMINI_API_KEY`. Two reasons to move it to the OpenAI model already used for story text (`OPENAI_API_KEY`): (1) **MT-137 ToS** — Gemini forbids child-directed apps, so sending kids' story text there *for moderation* trips the same ToS that drove the text/image migration; (2) **resilience** — a single Gemini key being unavailable silently turns every minor's story into the generic safe-fallback (now fail-closed for all ≤17 after #332). **Build stacked on #332** (same file). After it lands, `GEMINI_API_KEY` can be dropped entirely.

## Verification tasks (Pass-1 "could not verify")
- ☑ Trace live onboarding endpoint order (is `/create-character` reachable pre-consent?) — **verified 2026-07-03: YES, reachable.** `POST /auth/anonymous` mints `declared_age=NULL` / `is_under_13=False`, and `@require_parental_consent` early-returns for "not under 13", so every gated endpoint is callable with zero consent record while `ENFORCE_RESOLVED_AGE` stays off. Client-side flow is well-behaved; the server gate is the missing half. Full trace + remediation sequencing: `docs/COPPA_AMENDED_RULE_GAP_ANALYSIS.md` (Part 2 + G-2). Prerequisite for flipping the flag (MT-311 durable age-sync) is merged.
- ☐ Inspect a real prod Sentry event's breadcrumb payload for PII.
- ☐ Check prod `LOG_LEVEL`.
- ☐ Device-test URL→share on the prod `openai` path with classifier down.

## External review (route out)
- COPPA verifiable-consent mechanics + env-gated enforcement posture — **legal**.
- Data retention/deletion completeness (COPPA/GDPR-K) — **legal**.
- Crisis/self-harm flow incl. US-only hardcoding — **clinical**.

## Accept / won't-fix (decisions, not gaps)
- ⊘ Gemini `DANGEROUS_CONTENT = BLOCK_MEDIUM` — by design, legacy modes only.
- ⊘ Crisis links + content-report `mailto:` ungated — intentional (child-in-distress reaches help).
- ⊘ JWT refresh fail-open on Redis — deliberate availability tradeoff (`token_version` is the real revocation control).
- ⊘ Isar at-rest encryption (P2#17) — no such API in Isar 3.1.0; OS file-based encryption (Android FBE / iOS Data Protection) covers the at-rest risk; revisit at the Isar-4/storage migration (v1.1).

## Probe evidence (reusable)
Adversarial generation probe scripts (session scratchpad, re-runnable): build the
real prod prompt per band → prod-path generator → real two-layer moderation.
Key results: prompt-injection defense held across 6 bands on the weakest model;
URL emission reproduced in 6/6 bands (only the LLM classifier caught it);
teen (13–17) fail-open on the prod `openai` path proven during a real Gemini 503.
