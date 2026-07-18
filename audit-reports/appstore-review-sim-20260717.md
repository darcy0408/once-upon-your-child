# App Store Review Simulation — "Once Upon YOUR Child" (Story Weaver)

**Date:** 2026-07-17 · **Reviewer stance:** strict Apple App Review, looking for reasons to reject
**Listing posture reviewed:** general-audience (Books/Education, 4+), NOT Kids Category (D1 decision 2026-07-13) — both stores, COPPA handled in-product
**Sources:** `docs/IOS_APP_STORE_CRITICAL_PATH.md`, `docs/STORE_PRIVACY_FORMS_DRAFT.md` (MT-145), `docs/PROJECT_STATUS.md`, `docs/COPPA_AMENDED_RULE_GAP_ANALYSIS.md`, `backend/routes/iap_routes.py`, `lib/services/payment/*`, `lib/screens/subscription_management_screen.dart`, `lib/premium_upgrade_screen.dart`, `lib/story_result_screen.dart` (MT-353 report flow), `pubspec.yaml`

---

## THE 3.1.1 VERDICT (read this first)

**Architecturally: PASS. The app does NOT sell digital subscriptions through Stripe on iOS.**
The feared automatic 3.1.1 rejection ("Stripe checkout on an iOS build") is **not present**:

- `lib/services/payment/payment_channel.dart` conditional-imports `payment_channel_io.dart` on any `dart.library.io` build → iOS/Android use StoreKit/Play Billing via `in_app_purchase ^3.2.0`. The web build compiles `payment_channel_web.dart` (Stripe) instead; **no Stripe SDK or checkout is linked into the iOS binary** (MT-143 item 1, PR #362).
- `lib/screens/subscription_management_screen.dart:498-526` explicitly replaces the Stripe "Manage Billing"/"Cancel" buttons on store builds with an informational panel pointing at device Settings → Subscriptions — the comment even cites Guideline 3.1.1. Stripe billing-portal and Stripe cancel are web-only (line 622).
- "Restore Purchases" flow exists (`payment_channel_io.dart:59`, 3.1.1/3.1.2 requirement).

**BUT: the IAP purchase flow cannot succeed today, which converts the #1 risk from a 3.1.1 rejection into a near-certain 2.1 rejection** — see Finding 1. And there is a genuine sold-vs-delivered mismatch on the annual plan — see Finding 2.

Residual 3.1.1 cosmetic: `lib/premium_upgrade_screen.dart:165` shows a "Redirecting to checkout for …" snackbar even on the IAP path. A reviewer primed to hunt for external checkout will screenshot that wording. One-line copy fix ("Opening App Store purchase…").

---

## LIKELY REJECT

### Finding 1 — Guideline 2.1 (App Completeness): the purchase flow is dead on arrival
**What triggers it:** The reviewer taps the paywall, selects Premium, and nothing sellable happens:
- **No IAP products exist in App Store Connect** — Phase 1.5 of `docs/IOS_APP_STORE_CRITICAL_PATH.md` is unchecked; `premium_monthly`/`premium_annual` are hard-coded client- and server-side (`payment_models.dart:120-121`, `iap_routes.py:84-88`) but never created in the console. `loadProducts()` returns empty → broken/blank paywall.
- **Paid Applications Agreement + banking/tax not completed** (Phase 1.1) — Apple will not even let IAP products be approved.
- **Backend verification is dark:** `iap_routes.py:96-107` — `IAP_VERIFICATION_ENABLED` defaults `false` → `/api/iap/apple/verify` returns 503 `iap_not_configured` → even a sandbox-successful StoreKit purchase never grants entitlement. (The Apple verifyReceipt implementation at `iap_routes.py:961-978` is now real code, not the old `NotImplementedError` stub — MT-350 code-complete — but it is **sandbox-unproven** and off by default.)
- App Store Server Notifications V2 URL not configured (Phase 3.3), so renewals/refunds would silently not sync even if verification were on.

**Reviewer outcome:** "We found that your app exhibited one or more bugs… when we tapped Subscribe, the purchase did not complete." Automatic 2.1 rejection; if they suspect the subscription was never meant to work on iOS, they escalate to 3.1.1 questioning.

**Fix before submission:** Complete Phase 1 (agreement, banking, product creation with exactly matching IDs), set `IAP_VERIFICATION_ENABLED=true` on Railway only after provisioning `APP_STORE_SHARED_SECRET`, run the full sandbox purchase → verify → entitlement loop on TestFlight (Phase 3.5), and wire the ASSN V2 URL.

### Finding 2 — Guideline 3.1.2 / 2.3.1 (Subscriptions / Accurate Metadata): "Yearly (Save 50%)" is sold but monthly is charged
**What triggers it:** `lib/premium_upgrade_screen.dart:117-121` offers a "Yearly (Save 50%)" billing toggle. `lib/services/payment/payment_channel_io.dart:48-51` — explicit TODO: *"annual store products (`premium_annual`) don't exist… billingPeriod is accepted but ignored here — every IAP purchase is monthly for now."* A user (or reviewer) who selects Yearly at $59.99 is put through a $9.99/mo monthly purchase. Charging something other than what the UI advertised is a textbook misleading-subscription rejection (3.1.2 clarity of price/duration; 2.3.1 accurate metadata), and in Apple's eyes worse than a bug.
**Fix:** Either create `premium_annual` in App Store Connect and honor `billingPeriod`, or hide the Yearly toggle on store builds until it exists. Do not ship the toggle wired to the wrong product.

### Finding 3 — Guideline 5.1.1 (Data Collection and Storage): no App Privacy label, no published privacy policy URL — submission literally cannot complete honestly
**What triggers it:**
- The **Privacy Nutrition Label is not drafted/filed** (critical path 4.3 open; `docs/STORE_PRIVACY_FORMS_DRAFT.md` is a draft with OWNER-VERIFY rows, not filed answers). App Store Connect blocks submission without it.
- **Privacy Policy v3 is not published** (MT-330, cross-cutting launch gate) — the listing's required privacy-policy URL has nowhere accurate to point.
- If filed from today's policy text, the label would be **inaccurate**, which Apple treats as grounds for rejection/removal and is a false attestation:
  - **Gap 2 (HIGH, per the MT-145 draft):** `parent_hidden_context` is a *retained, structured* emotional/behavioral record per child (`feeling`, `trigger`, `body_signal`, `coping_tool`, `repair_goal`), while `PRIVACY_POLICY.md:23,192-194` calls Big Feelings data "transient… not a retained emotional profile." This belongs in Apple's **Health & Fitness / Sensitive Info** bucket, Linked to You. Under-disclosing it is the single biggest attestation risk.
  - **Gap 5:** IP addresses are collected and retained linked to user_id (`consent_record.ip_address`, `audit_log.ip_address`) and are not named in the policy's "Information We Collect."
  - **Gap 7 (STORE draft):** speech-to-text audio destination (Apple/Google speech servers) unverified — affects the "collects audio" answer.
**Fix:** Publish Privacy Policy v3 with the retention schedule (COPPA gap G-4 does double duty here), file the label from the MT-145 draft **after** resolving its OWNER-VERIFY rows, and declare the Big Feelings record as Health & Fitness (or Sensitive Info), Linked, App-Functionality-only. "Data Used to Track You = None" is well-evidenced (no ad SDK, no IDFA, no `NSUserTrackingUsageDescription`) — keep that claim.

---

## POSSIBLE REJECT

### Finding 4 — Guideline 1.3 / 5.1.4 (Kids Category / Kids' data): the reviewer WILL clock this as a kids app
General-audience listing or not, the first screenshot is a storybook app with age bands starting at 2-5. Apple applies 5.1.4 ("apps that collect data from minors must comply with applicable children's privacy statutes") regardless of category. Posture is mostly strong: neutral age gate (STORE-5), parental math-gate on external links (STORE-7), no ads/tracking SDKs, Firebase Analytics + Sentry consent-gated to self-attested 18+ and default-OFF (D2 hardening H-1…H-6, `setUserId` removed). Two exposures:
- **Server-side COPPA enforcement flags are currently OFF in prod.** `docs/PROJECT_STATUS.md` says the three flags (`ENFORCE_RESOLVED_AGE`, `COPPA_REQUIRE_VERIFIED_CONSENT`, `COPPA_REQUIRE_CURRENT_POLICY_VERSION`) were flipped ON 2026-07-14, but they were turned back OFF 2026-07-15 at owner request (launch blocker #449). With them off, an anonymous session can reach every child-data endpoint with no consent record (COPPA gap G-2). Apple can't see Railway env vars, but "COPPA handled in-product" is only true when these are ON. **Verify and flip before submission** — a 5.1.4 claim in review notes that contradicts server behavior is the bad scenario.
- **4+ age rating with AI-generated content:** the age-rating questionnaire now probes AI content and mature-theme potential. Answer honestly (fantasy violence mild; antihero band **must stay server-gated OFF** — `ANTIHERO_CRUX_ENABLED`, MT-266c — or the substance set-dressing residual ~1/7 changes the rating answers). A reviewer pushing the story generator with edgy prompts and getting anything off-tone at 4+ is a 1.3 rejection.
**Fix:** flags ON + smoke-verified; keep antihero OFF; answer the AI-content questionnaire conservatively; put the moderation architecture in the review notes.

### Finding 5 — Guideline 2.1 (Completeness): the age gate / consent flow can brick the reviewer's session
With COPPA flags ON (as they must be, per Finding 4), an under-13 profile requires a **real parent-email verification round trip via Resend** (hashed codes, 15-min expiry, fail-closed 503 if `RESEND_API_KEY` is missing). A reviewer exploring the child path with a throwaway email hits a wall; a Resend misconfiguration turns it into a hard 503. Reviewers reject what they cannot get past.
**Fix:** App Review notes with (a) a demo parent account with consent already granted, (b) explicit instructions that the adult path self-attests 18+ and works immediately, (c) an explanation that the email round trip is COPPA verifiable parental consent. Smoke-test Resend on prod the day of submission (the 503-code diagnosis recipe exists). Do not build a review-bypass backdoor — Apple treats that worse than friction.

### Finding 6 — Guideline 1.2 / 1.1 (UGC & AI-generated content safety): posture is good, but it must be demonstrable
Apple applies the 1.2 triad (filter / report / block + contact info) to AI-generated content shown to minors. Current state largely clears the bar:
- **Filtering:** two-layer output moderation — deterministic keyword filter + LLM classifier on OpenAI (`backend/utils/content_moderator.py`), explicitly **fail-closed for minors** (`fail_closed=True`).
- **Reporting:** "Report this content" flow with reason capture on the story screen (MT-353, `lib/story_result_screen.dart:1868,5413`), plus a contact email surfaced in the privacy screen.
- **Blocking users:** N/A — verified no chat/social/multiplayer/public-gallery anywhere (`share_plus` is OS share-sheet only), so the "block abusive users" prong has no object.
- **AI labeling:** "Created with AI" labels shipped (STORE-6).
Residual risks: the classifier is fail-open for adults (defensible; say so in notes only if asked), and the ElevenLabs 13-17 gate gap (`tts_routes.py:358` checks `is_under_13`, not the `is_under_18` computed for Gemini TTS) is a vendor-ToS problem, not an Apple one — but fix it anyway before attesting vendor lists (MT-145 Gap 1).
**Fix:** none blocking; describe filter+report in review notes preemptively.

### Finding 7 — Guideline 1.4.1 / 2.3.1 (Medical claims / misleading marketing): "therapeutic" is doing risky work
The paywall sells "**Therapeutic Superhero Missions**" and "expanded **therapeutic** prompts and coping tools" (`lib/premium_upgrade_screen.dart:385-391`), while `PRIVACY_POLICY.md:192-194` disclaims being "a therapeutic, clinical, or medical product." An aggressive reviewer reads that as either (a) a health claim without substantiation (1.4.1 territory: apps providing health/treatment services get extra scrutiny, especially aimed at children) or (b) marketing that contradicts the developer's own legal docs (2.3.1). The SEL credentialing gap (no named advisory clinician, no CASEL mapping yet) means there is nothing to point at if challenged.
**Fix:** Purge "therapeutic/therapy" from in-app purchase copy and store metadata; use "emotional-skills," "SEL-informed," "coping tools" framing consistent with the disclaimer. Keep the medical/treatment age-rating question answered per the MT-145 Section 3 guidance (honest, qualified). Do not claim clinical outcomes anywhere in the listing.

### Finding 8 — Guideline 5.2.1 (Intellectual Property): "StoryWeaver" name collision
Bundle ID is `com.storyweaver.storyWeaverApp` and the platform name "Story Weaver" collides with Pratham Books' well-known "StoryWeaver" children's-literacy platform (MT-172, flagged "do BEFORE any store listing"). Listing under "Once Upon YOUR Child" materially de-risks the visible surface, but the bundle ID and any "powered by Story Weaver" tagline in metadata leave a hook for an IP complaint or a 5.2.1 reviewer question. Formal trademark clearance is still open.
**Fix:** complete MT-172 clearance before listing; keep "Story Weaver" out of the app name, subtitle, and keywords; the bundle ID itself is not user-visible and needn't change, but don't feature the platform name in marketing.

---

## MINOR / HOUSEKEEPING

| # | Guideline | Item | Fix |
|---|-----------|------|-----|
| 9 | 4.8 | Sign in with Apple — **confirmed N/A**: no `google_sign_in`/Facebook/social login in `pubspec.yaml`; auth is anonymous/email. Closes critical-path item 4.5. | None; note in review prep that 4.5 is verified. |
| 10 | 3.1.1 (cosmetic) | "Redirecting to checkout for …" snackbar on the IAP purchase path (`premium_upgrade_screen.dart:165`) reads like external checkout. | Reword to "Opening App Store purchase…". |
| 11 | 2.1 (pre-review) | Build pipeline never proven: `ios/Podfile` missing, `DEVELOPMENT_TEAM` not wired in `project.pbxproj`, `ios-testflight.yml` never run green. You cannot get a build in front of a reviewer at all today. | Critical-path Phase 2.2-2.4 before anything else. |
| 12 | 3.1.2(a) | In-app ToS + Privacy Policy screens exist (`terms_of_service_screen.dart`, `privacy_policy_screen.dart`); functional Terms/EULA + privacy links must ALSO appear in App Store metadata. | Add both URLs to the listing; requires the published Policy v3 (Finding 3). |
| 13 | 5.1.1(v) | Account deletion — **present and compliant**: in-app Delete All My Data + `DELETE /api/user/<id>/data` full cascade. | None; a strength — mention in review notes. |
| 14 | 5.1.2 | Third-party AI processor consent architecture depends on OpenAI DPA + Zero Data Retention being executed (MT-318, open) — without processor status, sending child data to OpenAI is a "disclosure" the consent screen doesn't separately cover (COPPA G-3). Azure/Cloudflare DPAs also uncollected (G-6). | Execute MT-318 + collect DPAs before submission; keep consent-screen vendor list synced to the policy. |
| 15 | 2.3.1 | Operator identity mismatch: policy names "Darcy VanPelt" (individual) but the Apple account is the LLC (Gap 9). | Align policy Operator section with the LLC before filing. |

---

## GO / NO-GO

**If submitted today: NO-GO — the submission cannot even be completed, and if forced through it is rejected.**

Concretely, in order of encounter:
1. **You cannot produce a reviewable build** (no Podfile, unproven signing pipeline — item 11).
2. **You cannot complete the App Store Connect submission form** (no privacy label, no published privacy-policy URL — Finding 3; no IAP products/Paid Apps Agreement — Finding 1).
3. **If a build somehow reached a reviewer: rejection under Guideline 2.1** (subscribe button that cannot complete a purchase — Finding 1), with 3.1.2 (Finding 2) cited alongside if the Yearly toggle survives, and follow-up questions on kids' data handling (Finding 4) and "therapeutic" claims (Finding 7) in the same rejection letter — Apple batches findings.

**Most probable reviewer outcome:** *Rejected — 2.1 App Completeness (IAP purchase non-functional) + 3.1.2 (subscription price/duration mismatch), with a metadata request on privacy label accuracy.* The 3.1.1 Stripe catastrophe everyone fears is already engineered out; what remains is finishing the IAP console + backend-enable + sandbox proof, publishing accurate privacy artifacts, flipping the COPPA flags back ON, and softening the therapeutic language. Clear Findings 1-5 and 7, and this becomes a plausible first-or-second-pass approval; the critical path's own estimate of "1-2 review bounces" is realistic, not pessimistic.
