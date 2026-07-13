# Decision memo — D1 (Kids Category) & D2 (Firebase Analytics)

**Date:** 2026-07-13
**Status:** RECOMMENDED — awaiting owner sign-off (Darcy)
**Resolves:** Open decisions D1 and D2 in `IOS_APP_STORE_CRITICAL_PATH.md` §4.1–4.2
**Builds on:** `STORE_PRIVACY_FORMS_DRAFT.md` (MT-145), `COPPA_AMENDED_RULE_GAP_ANALYSIS.md`, `APP_OVERVIEW.md`

---

## Decision

**D1: List as a general-audience app (Books or Education category, 4+ age rating). Do NOT check "Made for Kids" / do NOT enter Apple's Kids Category.** This ratifies the positioning the code and store drafts already assume (STORE-3: "Families app, under-13 primary, general-audience listing").

**D2: Keep Firebase Analytics and Sentry, with the hardening steps in §4 below.** Do not strip them, do not build a separate kids build.

---

## Why D1: stay out of the Kids Category

1. **It is a one-way door.** Guideline 1.3's own text: once in the Kids Category, the app "will need to continue to meet these guidelines in subsequent updates, **even if you decide to deselect the category**." Developer-forum precedent confirms Apple holds apps to Kids-Category rules after opt-out (developer.apple.com/forums/thread/682386). Entering is optional; leaving is not really possible. Under uncertainty, don't take irreversible steps for zero launch benefit.

2. **It would force stripping our observability stack.** Kids-Category apps "may not send personally identifiable information or device information to third parties" and "should not include third-party analytics." The narrow analytics carve-out (no IDFA, no identifiable info, no location, no device info) has **not** protected Firebase in practice — App Review has rejected Firebase/Google Analytics in Kids-Category apps even with IDFA removed, treating any non-owned SDK as a disqualifying third party; Crashlytics (and by extension Sentry) is treated the same (developer.apple.com/forums/thread/131840). We would lose Firebase Analytics **and** Sentry at exactly the moment (pre-launch, no users) when funnel and crash signal matter most.

3. **Precedent is uniform.** Every comparable checked live in July 2026 sits outside the Kids Category with a 4+ rating and discloses analytics on its privacy label:
   - My Bedtime Story: AI Stories — Education, 4+, analytics + crash data disclosed
   - Storyville: AI Bedtime Stories — Books, 4+, User ID/Device ID/analytics disclosed
   - AI Bedtime Storyteller – Kids — Books, 4+, analytics + child's name disclosed (despite "Kids" in the name)
   - Moshi Kids — Books, 4+, identifiers/analytics disclosed

4. **The Kids Category buys us nothing we need.** Its benefit is discovery placement in the Kids section of the store. Our acquisition model (per GO_TO_MARKET / launch critical path) is parent-directed, not kids-store browse. The costs (irreversibility, SDK ban, strictest review tier, parental-gate mechanics on every external link and purchase) are all downside.

## Why D2: keep Firebase, hardened

1. **Outside the Kids Category, third-party analytics is permitted and routinely approved** (see all four comparables). Guideline 5.1.4(a)'s analytics restriction attaches to apps "intended primarily for kids"; our defensible position is that the **operator and customer is the parent** — parent-run onboarding, parent account, parent consent flow, subscription purchased by the parent — with the child as the story's subject/beneficiary. §3 below hardens that position.

2. **The existing gating is already stronger than what comparables ship.** Firebase collection initializes OFF and is enabled only after explicit consent AND declared age ≥ 18 (`privacy_service.dart`, `privacy_defaults.dart`) — analytics never runs in a child-attested session. Sentry has `sendDefaultPii=false` behind the same gate. No ad SDKs, no ATT/IDFA anywhere.

3. **First-party-only is not a free replacement.** The backend `analytics_events` table is deliberately funnel-only, no-PII. Rebuilding event-level product analytics + crash reporting first-party before launch is real work with no reviewer requirement forcing it.

## §3 — Conditions that keep D1 defensible (metadata & positioning)

These are cheap and should be treated as launch gates for the store listing:

- **M-1. Metadata addresses the parent, not the child.** Description/screenshot copy in second person to the parent ("stories about *your* child"). The app name "Once Upon YOUR Child" already does this. Never use "For Kids" / "For Children" in the name, subtitle, or keyword field — Guideline 2.3.8 reserves those phrases for Kids-Category apps.
- **M-2. Age-rating questionnaire answered as a general 4+ app**; do not select the Made-for-Kids age bands (5-under / 6–8 / 9–11) in App Store Connect — that selection IS the Kids-Category opt-in.
- **M-3. Keep the neutral age gate** (`welcome_screen.dart` STORE-5/M-10) and the 13–17 parent-awareness dialog exactly as built — they evidence the parent-operated model.
- **M-4. Update `APP_OVERVIEW.md` audience line.** "Target Audience: Children ages 3-16" is fine internally but store-facing copy should read "parents and caregivers of children 3–16." Marketing materials are now an explicit COPPA "directed to children" evidentiary factor under the 2025 amendments — parent-directed copy helps in both forums.

## §4 — Firebase/Sentry hardening (D2 conditions)

Mechanical items, suitable for an implementing agent as one MT ticket:

- **H-1. Disable ad signals at the plist level:** `GOOGLE_ANALYTICS_DEFAULT_ALLOW_AD_PERSONALIZATION_SIGNALS = NO` in `Info.plist`; confirm no `AdSupport`/IDFA linkage in the built app. (Google's documented child-directed configuration; also cleans the privacy label.)
- **H-2. Drop `setUserId` from `firebase_analytics_service.dart` (`setUserProperties`).** It is what makes analytics "Linked to you" on the nutrition label (flagged in STORE_PRIVACY_FORMS_DRAFT.md). Funnel-by-user analysis already lives in the first-party `analytics_events` table; Firebase can be anonymous/aggregate. If a stable ID is truly needed, use a per-install random ID, never the account ID.
- **H-3. Re-route the therapeutic events to first-party only.** `therapeutic_analytics.dart` events (`feelings_check_in` emotion/intensity/coping, `story_emotion_moment`) describe the **child's emotional state**. Even consent-gated, sending them to Google is the worst-optics data flow we have, and under the amended COPPA rule (effective 2025-06-23, compliance required since 2026-04-22) third-party disclosure that isn't integral to the service needs **separate** verifiable parental consent. Analytics is not "integral." Cheapest fix: log these events to the backend `analytics_events` table (already no-PII by design) and remove them from Firebase. Generic UX/funnel events (`hero_creator_*`, paywall, grace-period) stay in Firebase.
- **H-4. Verify the consent UI presents analytics as its own optional toggle**, not bundled into core consent — amended §312.5 requires consent-to-collect and consent-to-disclose-to-third-parties to be separable choices.
- **H-5. Sentry client sweep:** confirm no child name / story text / therapeutic context reaches breadcrumbs or event payloads (backend already has the C2 Celery PII-redaction gate; this is the client-side twin).
- **H-6. Finalize the privacy nutrition label** from STORE_PRIVACY_FORMS_DRAFT.md with D1/D2 now decided: after H-2, analytics data should be declarable as Not Linked; Sentry crash data likewise. Close the draft's Gap 4 as resolved-by-decision.

## What this decision does NOT change

- **COPPA obligations are category-independent.** We process a named child's personal information (name, age, feelings, optional photo) regardless of where the app is listed. The `COPPA_AMENDED_RULE_GAP_ANALYSIS.md` register (G-1…G-12), the OpenAI DPA/ZDR track (PR #363 / MT-318), retention-policy work, and the external COPPA/legal review gate all proceed unchanged. The 2025 amendments' retention cap ("as long as reasonably necessary," written policy required, no indefinite retention) applies to `parent_hidden_context` — that table's retention contradiction with PRIVACY_POLICY.md (Gap 2) still needs closing.
- **kidSAFE / clinician trust positioning (O8/MT-320)** is unaffected — those are marketing trust signals, not category mechanics.

## Reversal triggers

Revisit D1 only if: (a) App Review rejects the general-audience listing and explicitly directs Kids-Category placement (then negotiate metadata first — category change is the last resort, given irreversibility); or (b) discovery data post-launch shows kids-store browse is a material acquisition channel AND we are willing to fund first-party analytics + crash reporting to replace the stripped SDKs.

## Sources

- Apple App Review Guidelines 1.3, 2.3.8, 5.1.4 — developer.apple.com/app-store/review/guidelines/
- Kids Category opt-in mechanics — developer.apple.com/kids/; developer.apple.com/help/app-store-connect/manage-app-information/set-an-app-age-rating/
- Kids-Category stickiness after deselect — developer.apple.com/forums/thread/682386
- Firebase rejections in Kids Category despite IDFA removal — developer.apple.com/forums/thread/131840
- Firebase child-directed configuration — firebase.google.com/docs/analytics/android/configure-data-collection; developers.google.com/tag-platform/security/guides/app-consent
- Amended COPPA rule (effective 2025-06-23; compliance 2026-04-22): separate consent for third-party disclosure, retention limits, expanded "directed to children" evidence — federalregister.gov/documents/2025/04/22/2025-05904; ftc.gov/business-guidance/resources/complying-coppa-frequently-asked-questions
- Comparable listings (checked 2026-07-13): My Bedtime Story (id6449901963), Storyville (id6476870883), AI Bedtime Storyteller – Kids (id6737245753), Moshi Kids (id1306719339) — apps.apple.com
