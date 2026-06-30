# Legal-Liability Audit — Story Weaver / Once Upon YOUR Child

**Date:** 2026-06-28
**Scope:** Children's AI-content app (ages 2–17). Code-design audit for product-liability / negligence exposure.
**Lens:** *Garcia v. Character Technologies* (M.D. Fla., May 2025) — an AI app can be treated as a "product"; **design defects** (no age verification, no reporting mechanism, engagement-maximizing patterns, unsupervised AI-to-child relationship) that foreseeably harm a minor support product-liability / negligence / wrongful-death claims. **Section 230 and First Amendment defenses failed; liability extended down the supply chain to the model provider.** Also assessed against COPPA (verifiable parental consent, third-party disclosure, data minimization) and GDPR Art. 28 (processors).
**Method:** Five parallel read-only code audits (age assurance, vendor/supply-chain data flow, content guardrails, design patterns, consent/disclosure) against the **working tree** (includes uncommitted edits as of this date).

> ⚖️ This is a code-design audit, not legal advice. The liability-theory column maps each finding to the theory above; weigh remediation with counsel.

---

## Findings

| # | Risk area | File:line | What was found | Liability theory | Severity |
|---|-----------|-----------|----------------|------------------|----------|
| 1 | Age never verified or required server-side | `backend/models/user.py:61`; `backend/routes/utility_routes.py:375`; `backend/app.py:733` | `is_under_13` defaults `False`; `/auth/anonymous` + bootstrap users created with **no age**. No server-side age inference — every unknown user treated as 13+. | COPPA; Garcia (no age verification) | **High** |
| 2 | COPPA consent gate structurally bypassable | `backend/middleware/auth.py:171-173` | `require_parental_consent` early-returns for anyone not flagged `is_under_13`; that flag defaults False and is set only by an honest client POST. Anonymous/undeclared sessions pass unconditionally. | COPPA; 230-not-available | **High** |
| 3 | Verified-consent enforcement OFF by default | `backend/middleware/auth.py:200-202, 225-227` | `COPPA_REQUIRE_VERIFIED_CONSENT` + `COPPA_REQUIRE_CURRENT_POLICY_VERSION` default `"false"`. Shipped config accepts an unverified `email_pending` record. | COPPA | **High** |
| 4 | Client age/consent write is fire-and-forget | `lib/services/parental_consent_service.dart:134-150` | Server sync wrapped in `try {} catch (_) {}`; local SharedPreferences is "source of truth." Dropped POST → no server-side verifiable record. | COPPA (verifiable consent/records); GDPR Art. 28 | **High** |
| 5 | No self-harm/suicide detection on child **input** | `lib/utils/input_sanitizer.dart:78` (dead code); `backend/utils/sanitizer.py` (injection-only); `lib/pick_a_path_adventure_screen.dart:1320` | Child's free-text is sanitized for injection only and sent to the model; only model **output** is moderated. The one client-side self-harm check is never called. Crisis panel gated to curated quest IDs (`life_quest_screen.dart:24`), never fires on spontaneous disclosure. | **Garcia product-defect (bullseye)**; 230-not-available | **High** |
| 6 | Image-gen silently falls back to Gemini (ToS bars child apps) | `backend/app.py:558` **as committed on HEAD 4aa69b39** | On HEAD, `elif api_key and not testing_mode:` → cleared `OPENROUTER_API_KEY` constructs direct `GeminiImageGenerator()` when `GEMINI_API_KEY` set. **Uncommitted** edit (`app.py:566-595`) closes it via `ALLOW_DIRECT_GEMINI_IMAGE`, but is not committed/deployed. | GDPR Art. 28 / COPPA third-party; supply-chain | **High** (until shipped) |
| 7 | Same Gemini fallback unguarded in avatar path | `backend/services/avatar_generation_service.py:73-95` | Avatar service falls back to direct Gemini (child photo + prompt) if no OpenAI key and `disable_gemini` unset. Not protected by the new guard. | GDPR Art. 28 / COPPA third-party; supply-chain | **High** |
| 8 | Mature "antihero" generation reachable without resolved age | `backend/routes/story_routes.py:1023, 1083-1084` | `/generate-antihero-crux` / `-resolution` default to age 16, reachable by anonymous age-unknown user, no downward clamp (consent gate no-ops per #2). | Garcia product-defect | **High** |
| 9 | `/create-character` stores child name+age with no consent gate | `backend/routes/character_routes.py:148-150, 161-163, 239-243` | Data-collecting POSTs (name, age, parent hidden-context) carry `@require_auth` only — no `@require_parental_consent`. | COPPA (collection before consent) | **High** |
| 10 | Persistent bonded companions + returnable saga + daily streak | `lib/data/companion_personality_data.dart:7-10`; `lib/screens/wizard_steps/superhero_welcome_back_screen.dart:31-43`; `backend/services/achievement_service.py:258-264`; `lib/services/achievement_service.dart:350-377` | Attachment-forming companions persist via welcome-back; 3/7/30-day streaks manufacture daily return; "Night Owl" rewards post-10pm use. | Garcia product-defect (engagement + persistent AI relationship) | **High** |
| 11 | Reporting mechanism buried, mailto-only, non-routed | `lib/story_result_screen.dart:1750-1808` | "Report this content" two taps deep behind AI-info sheet; opens `mailto:` to one personal inbox — no backend, no logging, no triage, no SLA, no child-facing affordance; absent during interactive/pick-a-path/life-quest flows. | Garcia product-defect (no reporting mechanism) | **Med-High** |
| 12 | Session limits OFF by default + child-bypassable gate | `lib/services/screen_time_service.dart:78-81, 109-115`; `lib/screens/times_up_screen.dart:34-39, 107-196` | Daily limit defaults Unlimited; bedtime off. "Solve to add 15 min" is two-digit addition, trivially solved + repeatable by the 9-12 target age. No in-session adult checkpoint. | Garcia product-defect (no session limits / adult-in-loop) | **Med-High** |
| 13 | 13–17 consent cosmetic backend-side | `lib/screens/parental_consent_screen.dart:823-851`; `backend/middleware/auth.py:171-173` | Teens record `self_attested, verified:false`; backend never checks it. State minor-privacy laws + store policies reach 13-17. | State minor-privacy; store policy; Garcia | **Med-High** |
| 14 | TTS narrates with no independent content screening | `backend/gemini_tts_service.py:166`; `backend/edge_tts_service.py:75`; `backend/elevenlabs_tts_service.py:231` | All three TTS providers strip markup only; rely on upstream text moderation, which fails open for 13+ on classifier outage, then speak verbatim. | Garcia product-defect (unscreened output) | **Med-High** |
| 15 | `/tts/synthesize` + 3 avatar routes lack consent gate | `backend/routes/tts_routes.py:231`; `backend/routes/avatar_routes.py:769, 1013, 1191` | Child narration audio + image gen leave on `@require_auth` alone. | COPPA (data to vendor before consent) | **Med** |
| 16 | Child's real name leaks to image vendors | `backend/services/story_service.py:472-508` (token) vs `backend/routes/story_routes.py:2091, 2303, 2325, 2586`; `interactive_adventure_service.py:811` | `HERO_1` pseudonymization protects only text path; illustration/interactive calls pass real `character_name` to Cloudflare/Replicate/OpenRouter — the exact vendors the module comment says should see only the token. | COPPA §312.8 / GDPR minimization | **Med** |
| 17 | LLM output classifier fails open for 13-17 + key-dependent | `backend/utils/content_moderator.py:189`; `backend/tasks/story_tasks.py:2026` | `fail_closed` only for ≤12 / Sprout / OpenRouter-authored. For 13-17, a classifier outage or unset `GEMINI_API_KEY` lets content through. Output moderation is the sole net (no input content gate). | Garcia product-defect | **Med** |
| 18 | OpenRouter image generator has no prompt vetting | `backend/openrouter_image_generator.py:156, 334, 455, 556` | Non-default provider, prompts reach it with no input vet / no provider safety settings. | Garcia product-defect | **Med** |
| 19 | Substances leak as set-dressing in adolescent antihero (~1/7) | `docs/CLINICAL_REVIEW_ADOLESCENT_ANTIHERO.md` | Known residual: age-aware classifier permits mild peril for SEL; substances occasionally appear as set-dressing in 15-17 band. | Garcia product-defect (age-inappropriate) | **Med** |

### Strengths (defensive posture for the same theory)
- **Confidant pattern is absent** — no open-ended chat, no turn-by-turn AI persona, no cross-session memory of the *child's disclosures*; the free-text surface is a single bounded 200-char story-turn. Strongest distinction from the Garcia fact pattern; companions are static story cast, not confidants.
- **No push/re-engagement notifications** anywhere (verified).
- **Two-layer output moderation** (keyword + LLM classifier) on every story-text path; fail-closed for ≤12 / Sprout; covers titles + choice labels + full-story chunking; antihero path fails closed on flagged content.
- **Verifiable email-consent machinery** is well-built (hashed codes, 15-min expiry, 5-attempt cap, fails closed if Resend unconfigured, `verified` un-spoofable client-side) — just not enforced by default (#3).
- **AI-generated disclosure** present and in-sync across consent screen, in-app privacy policy, and `PRIVACY_POLICY.md`, with a persistent "Created with AI" badge.

---

## Remediation plan (phased)

### Phase 1 — Legal foundation: server-authoritative age + consent  *(fixes #1, #2, #3, #4, #8, #9, #13)*
The whole COPPA posture rests on a client-declared flag that defaults open. Make the server the boundary.
1. Require a resolved age before any generation/data-collection endpoint; treat **unresolved age as under-13** (deny-by-default), not 13+.
2. Change `require_parental_consent` to deny when age is unresolved, not only when `is_under_13 == True`.
3. Set `COPPA_REQUIRE_VERIFIED_CONSENT=true` (and policy-version) for launch config.
4. Make the client→server consent write **blocking** (surface failure; don't swallow).
5. Add `@require_parental_consent` to `/create-character` (+ update/hidden-context routes), `/tts/synthesize`, and the 3 unguarded avatar routes.
6. Clamp mature/antihero endpoints to the resolved age; refuse when age unresolved.

### Phase 2 — Garcia safety affordances  *(fixes #5, #11)*
1. **Self-harm/suicide input detection + crisis off-ramp:** wire the existing `crisis_resources_panel.dart` to fire on detected disclosure in *any* free-text surface, independent of curated quest IDs. Detection terms already exist (dead code in `input_sanitizer.dart:78`) — call them, add a server-side check too.
2. **Real reporting mechanism:** visible "Report" control on every content surface (incl. mid-interactive-session) → logged backend endpoint with triage/acknowledgement; add a child-appropriate "this made me feel bad" affordance.

### Phase 3 — Supply chain / vendor ToS  *(fixes #6, #7, #14, #16, #17, #18)*
1. **Commit + deploy** the `app.py` image-gen guard (HEAD is still vulnerable).
2. Apply the same `ALLOW_DIRECT_GEMINI_IMAGE` guard to `avatar_generation_service.py:73-95`.
3. Tokenize `character_name` before image-vendor calls (extend `HERO_1` pseudonymization to image paths).
4. Add content screening before TTS synthesis (or assert upstream moderation ran).
5. Make the output classifier fail-closed for 13-17, or add an input content gate.
6. Add prompt vetting to the OpenRouter image generator.

### Phase 4 — Engagement / session safety  *(fixes #10, #12, #19)*
1. Reconsider daily streaks + the post-10pm "Night Owl" badge for a kids' app.
2. Default a session limit ON; replace the two-digit-addition parent gate with a non-repeatable real gate.
3. Consider an in-session adult checkpoint.
4. Tighten the antihero substance-set-dressing residual (#19).

### Top 5 by severity
1. Phase 1 cluster (server-authoritative age + consent).
2. Phase 2.1 (self-harm input detection — closest to the Garcia harm).
3. Phase 3.1+3.2 (commit/deploy Gemini guard + avatar guard).
4. Phase 2.2 (real reporting mechanism).
5. Phase 4 (engagement/session safety) + #14/#17 (unscreened/fail-open output to 13-17).

---

## Remediation progress (2026-06-28)

| Finding | Status | Where |
|---|---|---|
| #6, #7 (silent direct-Gemini image fallback) | **Fixed, pending merge** | PR #319 (`app.py` + `avatar_generation_service.py` guards, BYOK consent, disclosure sync) |
| #9, #15 (data/vendor routes bypass consent gate) | **Fixed, pending merge** | PR #320 — `@require_parental_consent` added to `/create-character`, char PATCH/PUT, parent-hidden-context PUT, `/tts/synthesize`, `/generate-avatar`, `/regenerate-avatar`, `/tweak-gallery-avatar` |
| #1, #2 (unresolved age treated as 13+) | **Fixed behind flag, pending merge** | PR #320 — `ENFORCE_RESOLVED_AGE` gate in `require_parental_consent` (default OFF; blocks gated endpoints when `declared_age is None`). Needs companion client change (sync age server-side for all users) before the flag can be flipped on. |
| #8 (antihero reachable / un-clamped) | **Covered** | Resolved-age users already clamped via the existing `_verified_age_anchor` (M-6) at `story_routes.py:1082-1086`; un-aged users blocked by `ENFORCE_RESOLVED_AGE`. No extra code. |
| #3 (verified consent enforced only by an off-by-default flag) | **Launch toggle** (see checklist) | No code-default change — flip at launch. |
| #5 (no self-harm detection on child input) | **Fixed, pending merge** | PR #320 — `backend/utils/crisis_detection.py` (authoritative) wired into `/continue-interactive-story`; client `InputSanitizer.detectCrisis` + `CrisisDisclosureException` + `CrisisResourcesPanel` modal in pick-a-path. Returns crisis resources, never a story. 34 backend + 24 Dart tests. *Covers the interactive free-text surface; story-gen custom_elements + "Make One Up" still to wire (same detector).* |

### Launch-gate configuration checklist
Before public launch (these are env flags, intentionally OFF for the tester phase so legitimate users aren't blocked):
- [ ] **Client age-sync shipped** — every onboarding path (incl. 13+/18+) POSTs `declared_age` server-side. *Prerequisite for the next item.*
- [ ] `ENFORCE_RESOLVED_AGE=true` — deny generation/collection until the server has resolved an age (fixes #1/#2/#8 in production).
- [ ] **Resend verified live in prod** — *prerequisite* for the next item, or under-13 users get locked out.
- [ ] `COPPA_REQUIRE_VERIFIED_CONSENT=true` — require the email round-trip to have completed (fixes #3).
- [ ] `COPPA_REQUIRE_CURRENT_POLICY_VERSION=true` — force re-consent when the privacy policy version bumps.

### Still open (later phases)
- Phase 2: #5 self-harm detection — **done for the interactive surface** (extend the same detector to story-gen `custom_elements` + "Make One Up"); #11 real reporting mechanism.
- Phase 3 (beyond #6/#7): #14 TTS output screening; #16 name tokenization to image vendors; #17 fail-closed classifier for teens; #18 OpenRouter image vetting.
- Phase 4: #10 engagement mechanics; #12 session limits / parent gate; #19 antihero substance set-dressing.
- #4 client consent-sync hardening (make the server write non-best-effort).

## Working-tree note (historical)
Finding #6 originally differed between HEAD and the working tree (uncommitted edit). That work was committed by a parallel session as **PR #319** — see Remediation progress above. Confirm what the live Railway artifact was built from before relying on the guard in production.
