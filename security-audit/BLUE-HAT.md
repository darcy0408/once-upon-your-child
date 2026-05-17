# Blue Hat — Synthesis & Remediation Backlog

Story Weaver security audit, 2026-05-16. Synthesis of all five hats into a sequenced, prioritized remediation plan.

## Tally
3 Critical (C-2 resolved during the audit — leaked Gemini key confirmed expired/rejected by Google 2026-05-16; 2 active: C-1, C-3), 8 High, 17 Medium, 12 Low/Informational. Two dominant themes:
1. **Promise vs. implementation gap** — privacy claims (photos, BYOK keys never leave the device) contradicted by the code, which under COPPA/GDPR voids the consent collected.
2. **Child-safety surfaces without defense-in-depth** — free-text fields bypass the prompt sanitizer; moderation fails open; the photo+free-text avatar path is unvalidated.

## Conflicts surfaced between hats
- Yellow credits the prompt-injection sanitizer; Black shows three field sets bypass it. **Resolution:** the control is sound; its *coverage* is allowlist-based — the Green Hat single-gateway refactor is the durable fix.
- Yellow credits the Stripe webhook; Black flags entitlement trust. **Resolution:** no conflict — signature verification and tier-from-price derivation are independent layers; both are required.
- "Fail open" is a deliberate availability choice. **Resolution:** defensible for story rendering, indefensible for the cost breaker and Sprout-band moderation — fail-open *by surface*, not globally.

## Remediation backlog

| Priority | ID | Title | Severity | Effort | Depends on |
|---|---|---|---|---|---|
| ✅ Done | C-2 | ~~Rotate the leaked Gemini API key~~ — confirmed expired/rejected by Google 2026-05-16 | Resolved | Done | — |
| P0 | C-1 | Correct photo-privacy claims OR move avatar gen on-device | Critical | M–L | — |
| P0 | C-3 | Run `validate_prompt_safety` on all avatar/pet prompt paths | Critical | M | — |
| P1 | H-1 | Remove/guard `/setup-test-account` | High | S | — |
| P1 | H-4 | Sanitize `worldBible`/`conflictHook`/`sensoryPalette` | High | S | — |
| P1 | H-6 | Enable `encryptedSharedPreferences` + iOS keychain accessibility | High | S | — |
| P1 | H-7 | Move JWT access+refresh tokens to secure storage | High | S | H-6 |
| P1 | H-3 | Sanitize + wrap + moderate interactive `custom_text` | High | M | — |
| P1 | H-2 | Derive webhook tier from the paid Stripe price | High | M | — |
| P1 | H-5 | Fix BYOK "never leaves device" copy OR call Gemini client-side | High | M | — |
| P2 | H-8 | Implement a verifiable parental-consent method | High | L | — |
| P2 | M-2 | Fail-closed cost circuit breaker | Medium | M | — |
| P2 | M-4 | Wire LLM classifier into interactive path; fail-closed for Sprout | Medium | M | — |
| P2 | M-9 | Default analytics off; gate on consent + age ≥ 13 | Medium | M | — |
| P2 | M-3 | Webhook idempotency (persist `event.id`) | Medium | S | — |
| P2 | M-1 | Shorten access-token TTL; revocation check in `require_auth` | Medium | M | — |
| P2 | M-12 | Strip `/health*` detail; gate detailed routes | Medium | S | — |
| P2 | M-6 | Derive content age band from verified account age | Medium | M | — |
| P3 | M-5 | Add image-output moderation for Flux providers | Medium | M | — |
| P3 | M-7 | Pseudonymize hero name before provider calls | Medium | M | — |
| P3 | M-8 / M-17 | Server-side entitlement enforcement; unify quota systems | Medium | L | H-2 |
| P3 | M-10 | Defer age persistence; neutral age screen | Medium | M | — |
| P3 | M-11 | Enforce photo-avatar opt-in inside `CustomAvatarScreen` | Medium | S | — |
| P3 | M-13 / M-14 | Non-root containers; multi-stage backend build | Medium | M | — |
| P3 | M-15 / M-16 | Compile-time test flag; never tokenize the singleton anon user | Medium | S | — |
| P4 | L-1..L-12 | Hardening backlog (see `BLACK-HAT.md`) | Low | S each | — |

## Sequencing

**Hour 0 — P0, do today.**
- C-2 is already resolved — the leaked key was live-tested and confirmed expired/rejected by Google (2026-05-16). No action remaining beyond optional Google Cloud key-restriction hardening and pruning unused keys.
- C-1: decide the path — correct the copy (M, fast, unblocks compliance) vs. on-device generation (L, the durable answer). Ship the copy fix immediately even if on-device work is queued.
- C-3: extend `validate_prompt_safety` to the photo/pet/companion avatar paths — a self-contained backend change.

**Day 1 — P1, the High batch.**
Mostly small, independent edits. Order notes:
- H-6 before H-7 — the token move depends on encrypted storage being enabled.
- H-2 needs a server-side `{price_id: tier}` map; resolve tier from `items.data[0].price.id`.
- H-4: ship the field fix, and if time allows pair it with the Green Hat single-gateway sanitizer refactor so the class is closed permanently.
- H-1: delete or environment-guard the endpoint.

**Day 2–3 — P2.**
- H-8 (verifiable consent) is the largest single item — scope the Stripe authorize-and-void approach from the Green Hat.
- Bundle M-2 + M-4 as one "fail-open audit" change — both are the same root philosophy applied to cost and safety.
- M-9 and M-12 are quick wins.

**Backlog — P3/P4.**
Infrastructure hardening (M-13, M-14) and the Low items can ride normal release cycles. M-8/M-17 (server-side entitlement) is larger and best done after H-2 lands.

## Estimated effort
P0 + P1 is a focused 2–3 day push for one developer. P2 adds roughly 2–3 more days, dominated by H-8. No rewrite is required — the codebase's existing controls are sound; the work is closing coverage gaps and reconciling claims with code.

## Coverage check
Every top-level repo directory appears in at least one hat or is explicitly excluded:
- Covered: `backend/`, `lib/`, `android/`, `ios/`, `web/`, `.github/`, Docker/Railway config.
- Excluded with rationale: `assets/`, `style_samples/`, `age_band_assets_OLD/`, `StoryWeaverImagesToShare/`, root `*.png` verification screenshots (static assets, no executable surface); `story_weaver_core/`, `story_weaver_mvp/`, `therapy_companion/`, `third_party/` (legacy/sibling projects not in the deployed build); `node_modules/`, `build/`, `.dart_tool/` (generated/vendored).

## Residual gaps — recommended follow-up
- `backend/services/quality_service.py` / `backend/quality_service.py` — not deeply read.
- `backend/services/chronicle_prompt_service.py` — `chronicle_context` flows into the interactive opening prompt; sanitization status uncertain.
- `backend/services/openrouter_story_generator.py` — whether it applies the same child-safety `SafetySetting` thresholds as the Gemini path is uncertain.
- Backend-side handling of the uploaded child photo (retention, onward transfer to Cloudflare) — C-1 cannot be fully closed without confirming server-side deletion. **A dedicated backend data-flow follow-up is recommended.**
- Isar local-DB encryption posture — child stories/profiles are likely unencrypted at rest; unconfirmed.

## Bottom line
Ship the P0 items today (key rotation is non-negotiable and immediate). The Critical/High set is a small, well-bounded body of work. The recurring lesson across hats: reconcile every user-facing privacy promise with the code, and apply the main story path's proven sanitize-wrap-moderate discipline uniformly to the interactive and avatar paths.
