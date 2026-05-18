# Legal & Compliance Audit — Phase 4 Plan (DRAFT)

Date: 2026-05-17
Source: `audit/LEGAL-COMPLIANCE.md`. Phases 1–3 are complete (17 of 29 findings).
Phase 4 covers everything that remains.
Status legend: ☐ todo · ◐ in progress · ✅ done · 🔑 decision required

---

## Why Phase 4 is different

Phases 1–3 were mostly self-contained code fixes that parallel agents could knock out in
hours. Phase 4 is **not** one sprint — it's a mix of:

- one **large migration** (STORE-1, 2–4 weeks) that should not be rushed by an agent;
- two **product/legal decisions** only the owner can make (CMP-7, and STORE-1 scope);
- a set of **console actions** outside the codebase (store forms, age rating);
- and a handful of **small code items** that *can* be delegated.

So Phase 4 is organised as **work packages** with different shapes, not a single batch.

## Remaining findings

| ID | Sev | Title | Work package |
|----|-----|-------|--------------|
| STORE-1 | Critical | Stripe used for in-app subscriptions | WP-1 |
| CMP-1 | Critical | Verifiable consent disabled (`_kSkipEmailConsent`) | Launch gate |
| CMP-5 / PP-13 | High | Stated retention period has no enforcing code | WP-2 |
| Photo onward-transfer (MT-137) | High | Provider DPA review for child photos | WP-2 |
| CMP-6 | Medium | Consent screen child-directed; no parent gate | WP-3 |
| CMP-7 | Medium | Emotional-state data lacks GDPR Art. 9 treatment | WP-5 (D-1 resolved) |
| CMP-9 | Medium | Consent-age threshold hardcoded; no GDPR-K jurisdiction | WP-3 |
| PP-8 | Medium | Policy promises a data-export feature that doesn't exist | WP-4 |
| PP-9 | Medium | Policy promises an analytics opt-out; no toggle exists | WP-4 |
| STORE-8 | Medium | Mic/camera capture needs Kids-Category justification | WP-6 |
| STORE-9 | Medium | Data-safety form / privacy label must list every SDK | WP-6 |
| CMP-10 | Low | Re-consent on policy change is client-side only | WP-3 |
| CMP-11 | Low | Direct notice missing operator identity/contact | WP-3 |
| PP-11 | Low | Deletion described as "removes all profiles"; code anonymizes | WP-7 |
| PP-12 | Low | Stale/inconsistent effective dates | WP-7 (verify — likely fixed in Phase 2) |

Plus four **code follow-ups** logged during Phase 3: consent-screen ElevenLabs link still
ungated · three near-duplicate math-gate implementations · BYOK-prefetch illustrations lack
the AI badge · Sentry breadcrumb scrubbing + DPA. → WP-7.

---

## Decisions required first (these gate the work)

### ✅ D-1 — RESOLVED 2026-05-17: NOT a therapeutic product
The app collects a child's emotional state ("big feelings") and parent-configured behavioural
context, and the policy historically framed this as "therapeutic." Under GDPR Art. 9 that
would be special-category (health) data needing explicit consent + a documented lawful basis
+ a DPIA. **Owner decision: this is a storytelling app with an emotional-wellbeing angle —
NOT a therapeutic/clinical product.** Consequence: WP-5 shrinks to a small copy/data-handling
pass — no Art. 9 consent flow, no DPIA, no legal counsel needed.

### 🔑 D-2 — STORE-1 scope & timing
Apple and Google require their own IAP for in-app digital subscriptions; Stripe-web-checkout
will be rejected. Options:
- **(a) Full IAP migration before any store launch** — StoreKit + Play Billing, ~2–4 weeks.
- **(b) Launch web first** (Stripe is fine on the web build), defer the iOS/Android store
  submission until IAP is built. Lets the product ship sooner; IAP becomes a fast-follow.
- **(c)** Mobile builds ship with subscriptions disabled (free tier only) initially.
Recommendation: decide (a) vs (b) based on how soon you need a mobile-store presence.

---

## Work packages

### WP-1 — STORE-1: payment-platform compliance  ·  Critical · ~2–4 weeks
The big one. **Gets its own brief — do not hand this to a single quick agent.**
- Add the `in_app_purchase` plugin; define the Premium/Family products in App Store Connect
  and Play Console.
- Implement StoreKit (iOS) + Play Billing (Android) purchase flows.
- Server-side: validate store receipts and reconcile entitlement with the existing
  Stripe-derived tier logic (one entitlement source of truth, two purchase channels).
- Keep Stripe **only** for the Flutter web build; gate the Stripe path unreachable on
  iOS/Android.
- Regression-test upgrade/downgrade/restore/refund on all three platforms.
→ Action: draft a dedicated `audit/STORE-1-IAP-BRIEF.md` before starting.

### WP-2 — Backend data lifecycle  ·  High · ~2–3 days · delegatable
- **CMP-5/PP-13** — implement the retention/inactivity purge the policy already promises
  (a Celery-beat task that anonymises or deletes accounts after the stated inactivity window),
  or correct the policy to the real practice. Define or remove the "therapeutic records"
  retention carve-out (ties to D-1).
- **Photo onward-transfer (MT-137)** — obtain and document written no-training/retention
  assurances from each image provider that can receive a child's photo; ideally restrict the
  photo-avatar path to a provider with a contractual no-retention term.
Files: `backend/` (new Celery task), provider DPA docs. Backend-only — disjoint from WP-3/4.

### WP-3 — Consent & jurisdiction hardening  ·  Medium/Low · ~3–4 days · delegatable
- **CMP-9** — jurisdiction-aware consent age (GDPR-K 13–16). Decide: coarse geo-IP vs a
  country selector at onboarding; default to 16 for unknown EU traffic.
- **CMP-6** — make the consent *action* parent-facing: drop child-directed TTS/gamification on
  the consent screen, add a "hand to a parent" step or parent-gate before the checkbox.
- **CMP-10** — add `policy_version` to `ConsentRecord`; reject stale-version consent in the
  gate; drive the client re-consent cutoff from the server instead of a hardcoded date.
- **CMP-11** — add operator legal name, postal address, and phone to the privacy policy and
  the in-app Notice to Parents.
Files: `welcome_screen.dart`, `parental_consent_screen.dart`, `parental_consent_service.dart`,
backend `ConsentRecord` + the consent gate, policy docs.

### WP-4 — Privacy-control UI  ·  Medium · ~2 days · delegatable
- **PP-8** — surface the existing backend `export_user_data` endpoint as a "Download my
  child's data" action in Parent Controls (the backend already supports it; only UI is missing).
- **PP-9** — add an analytics on/off toggle in Parent Controls wired to
  `PrivacyService.setAnalyticsConsent`, so withdrawal is as easy as giving (GDPR Art. 7(3)).
Files: `parent_controls_screen.dart`, `privacy_service.dart`. Disjoint from WP-3.

### WP-5 — De-therapeutic copy pass (CMP-7)  ·  Small · unblocked (D-1 = not therapeutic)
Per D-1: remove any lingering "therapeutic records" framing from the policy and UI, treat
"feelings" input as transient story-personalisation (not a retained health profile), and
ensure the consent copy discloses that emotional text is sent to the AI provider. No Art. 9
consent flow or DPIA. Small enough to fold into WP-3.

### WP-6 — Store-submission compliance  ·  Medium · console + small code · owner-driven
- **STORE-8** — confirm `speech_to_text` runs on-device (no audio leaves the device) and
  document it; if cloud-based, consent-gate it. Verify mic/camera are declared as optional.
- **STORE-9** — build a complete data-flow/SDK inventory; fill the Play Data Safety form and
  the Apple Privacy Nutrition Label to match exactly; confirm each SDK is Families-eligible.
- **STORE-3 console tail** — set the age-rating questionnaire and store-listing copy to the
  under-13 Families positioning.
Mostly console actions for the owner; the speech-recognition check is a small code task.

### WP-7 — Cleanup batch  ·  Low · ~1 day · delegatable
- **PP-11** — soften the deletion wording to match the code (anonymises the user row).
- **PP-12** — verify (Phase 2 already replaced the Terms' live `DateTime.now()` with a static
  date — likely already resolved; confirm and close).
- Phase 3 follow-ups: gate the consent-screen `elevenlabs.io` link; consolidate the three
  duplicate math-gate widgets into one shared `ParentalGateDialog`; add the AI badge to the
  BYOK-prefetch illustration widget (`per_page_illustration.dart`); add Sentry breadcrumb
  scrubbing.

### Launch gate — CMP-1  ·  Critical · do last
At the end of the tester phase: set `_kSkipEmailConsent = false`, set
`COPPA_REQUIRE_VERIFIED_CONSENT=true` on Railway, and complete the Resend sending-domain
setup (MT-135). Do NOT do this while still testing.

---

## Recommended sequencing

1. **Make decisions D-1 and D-2** — they gate WP-5 and WP-1.
2. **Start the WP-1 brief immediately** — it's the long pole; everything else finishes inside
   its window.
3. **Delegate WP-2, WP-3, WP-4, WP-7 as parallel agents** — disjoint file sets, same model as
   Phases 2–3.
4. **WP-6** — owner works the console forms around submission time; one small code check.
5. **WP-5** — once D-1 is answered.
6. **CMP-1 launch gate** — the very last step before public release.

## Effort summary
- WP-1: 2–4 weeks (own brief) · WP-2: 2–3 days · WP-3: 3–4 days · WP-4: 2 days ·
  WP-7: 1 day · WP-5: small or large per D-1 · WP-6: mostly console.
- Delegatable now (after decisions): WP-2, WP-3, WP-4, WP-7.
- Owner-only: D-1, D-2, WP-6 console actions, CMP-1, keystore, mailbox confirmation.
