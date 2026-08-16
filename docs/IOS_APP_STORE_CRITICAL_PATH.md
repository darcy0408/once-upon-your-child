# iOS App Store — Critical Path

**Created:** 2026-07-09 (session ios-path)
**Owner:** Darcy Van Pelt / Once Upon YOUR Child LLC
**Status:** Account live; execution not yet started. This is the missing iOS equivalent of
`ANDROID_KEYSTORE_RUNBOOK.md` — a single sequenced tracker instead of state scattered across
MT-317 / MT-350 / MT-143 / MT-145 / `audit/STORE-1-IAP-BRIEF.md` / `IOS_TESTFLIGHT_SETUP.md`.

> **Strategic note.** `docs/DISTRIBUTION_STRATEGY.md` deliberately *deprioritizes* the open app
> store as a growth channel (reach parents through trusted professionals, not store search). The
> App Store is therefore a **presence/credibility** play, not the acquisition engine. It is also
> a **separate track** from the currently-active L1/L2 web-launch plan in
> `docs/LAUNCH_CRITICAL_PATH_2026-07-08.md` (that plan is web + Stripe + Cloudflare Pages and does
> not touch iOS). Sequence this only when the web launch is under control.

---

## TL;DR — where we actually are

The hardest, least-controllable step (Apple Developer Program enrollment, identity-gated, can take
weeks) is **DONE as of 2026-07-09**. The build-without-a-Mac problem is **already solved** in CI.
The iOS client and Apple IAP client code are **already built**. The real remaining distance is:

1. **Owner console setup** in App Store Connect (app record, IAP products, agreements, signing) — days of clicking + Apple wait time.
2. ~~**One large code item** — MT-350 backend receipt verification is a `NotImplementedError` stub.~~
   **STALE — corrected 2026-08-16.** MT-350 is code-complete; see Phase 3. What remains there is
   sandbox proof and a flag flip, both gated on store products existing (Phase 1.5).
3. ~~**Compliance forms + a Kids-Category / Firebase-Analytics decision** — none of it drafted yet.~~
   **STALE — corrected 2026-08-16.** The forms draft exists (`docs/STORE_PRIVACY_FORMS_DRAFT.md`) and
   D1/D2 were decided 2026-07-13 (general-audience listing, not Kids Category; Firebase hardened).
   Owner still transcribes the forms into the consoles.
4. The **platform-agnostic COPPA launch gates** (shared with web launch) must also be cleared.

**Rough distance if prioritized:** ~1 week to a TestFlight beta; ~2–4 weeks of focused work to a
*submittable* paid build, then App Store review calendar time on top (kids apps get extra scrutiny
and often bounce once or twice).

---

## Done ✅ (don't redo)

- [x] **Apple Developer Program** — enrolled as Organization under the LLC. Team ID `JPU8WX66BX`,
      Account Holder Darcy Van Pelt, License Agreement accepted 2026-07-09, $99/yr paid, renews 2027-07-09.
      *(This closes the Apple half of MT-317, which the docs still show as unstarted.)*
- [x] **iOS build pipeline (no Mac needed)** — `.github/workflows/ios-build.yml` (unsigned compile
      check on `macos-latest`) + `ios-testflight.yml` (signed IPA → TestFlight via App Store Connect
      API key). Setup doc: `docs/IOS_TESTFLIGHT_SETUP.md`. **Never proven to run green end-to-end** — see Phase 2.
- [x] **iOS project is real, not scaffold** — bundle `com.storyweaver.storyWeaverApp`, deployment
      target iOS 15.0, real `GoogleService-Info.plist`, custom app icon/launch assets.
- [x] **Privacy usage strings** written in `ios/Runner/Info.plist` — camera, photo library,
      microphone, speech recognition (all four with kid-appropriate copy).
- [x] **Apple IAP client** — `in_app_purchase: ^3.2.0` in `lib/services/payment/`; StoreKit path,
      conditional-import split (web = Stripe, iOS/Android = store billing), "Restore Purchases" flow,
      server-side-verify call. MT-143 item 1 shipped (#362): killed Stripe steering on store builds.
- [x] **Most Kids-Category compliance** (from `audit/LEGAL-COMPLIANCE.md`, May 2026): neutral age gate
      (STORE-5), parental math-gate on external links (STORE-7), "Created with AI" labels (STORE-6),
      Sentry consent-gated + `sendDefaultPii=false` (STORE-2). Age-rating *positioning* decided:
      Families app, under-13 primary (STORE-3, code side).

---

## Phase 1 — App Store Connect setup (OWNER / console, no code)

Everything downstream depends on this. Do it first.

- [x] **1.1a Accept the Paid Applications Agreement** — **DONE.** Accepted 2026-07-13; the agreement
      term runs Jul 13, 2026 – Jul 8, 2027. (The Free Apps Agreement is separately Active since Jul 9.)
- [ ] **1.1b Clear `Pending User Info` on the Paid Apps Agreement** — verified in the console
      2026-08-16. The agreement is accepted but not Active, because two items are outstanding:
      - **Bank account** — none added. Must be in the LLC's name. **Longest lead time; owner only.**
      - **U.S. Form W-9** — status `Missing Tax Info`. Requires an EIN, which does not exist yet
        (Secretary of State registration only). EIN is free at IRS.gov, ~15 min.

      Required before any IAP subscription can be created *or* approved, so this gates Phase 1.5.
      **Owner has a disability hearing pending — the decision to open a business bank account or take
      revenue is on hold until a benefits counselor (WIPA) advises. Do not treat this as a simple
      to-do; do not push on it.** Code-side work routes around it fine.
- [ ] **1.1c EU trader status (DSA)** — separate from the agreement, gates EU distribution only. Apple
      publicly displays trader contact details (name, address, phone, email) on the EU product page,
      and the registered address is the owner's home. **Recommended: ship US-only at launch** — set
      territories to exclude the EU, cost $0, reversible at any time — rather than paying for a
      virtual business address that isn't affordable right now.
- [ ] **1.2 Enroll in the App Store Small Business Program** — drops Apple's commission from **30% → 15%**
      for developers under $1M/yr. You qualify. Materially changes the $9.99/mo economics. One-time application.
- [ ] **1.3 Register the App ID** in Certificates, IDs & Profiles → Identifiers, bundle
      `com.storyweaver.storyWeaverApp` (must match `IOS_TESTFLIGHT_SETUP.md` and `GoogleService-Info.plist`).
- [ ] **1.4 Create the app record** in App Store Connect (name = **"Once Upon YOUR Child"**, primary
      language, category — likely Education / Kids). Using the customer-facing brand for the listing name
      also de-risks the "StoryWeaver" trademark collision (see MT-172 below).
- [ ] **1.5 Create the IAP subscription products** — `premium_monthly` ($9.99) + `premium_annual`
      ($59.99) in one subscription group. Leave `family_monthly` unconfigured (Family hidden at launch).
      Product IDs are already hard-coded (`payment_models.dart:120-121`, `iap_routes.py:78-81`) — the
      console IDs must match exactly. Unblocks MT-317 / MT-340's annual-IAP note.

---

## Phase 2 — Signing → first TestFlight build (OWNER creds + small code fix)

Goal: prove the `ios-testflight.yml` pipeline actually produces a signed build Apple accepts.

- [ ] **2.1 Generate signing assets** — iOS Distribution certificate (`.p12`) + App Store provisioning
      profile for the bundle ID + App Store Connect API key (`.p8`). Populate the **8 GitHub secrets**
      listed in `docs/IOS_TESTFLIGHT_SETUP.md` (`IOS_CERTIFICATE_P12_BASE64`, `IOS_CERTIFICATE_PASSWORD`,
      `IOS_PROVISIONING_PROFILE_BASE64`, `IOS_DEVELOPMENT_TEAM=JPU8WX66BX`, `APP_STORE_CONNECT_API_KEY_ID`,
      `APP_STORE_CONNECT_ISSUER_ID`, `APP_STORE_CONNECT_API_KEY_BASE64`, …). **Credential boundary — owner only.**
- [x] **2.2 Commit an `ios/Podfile`** — **DONE 2026-08-16.** Committed rather than left to
      flutter_tools regeneration, which had never been proven green. `platform :ios, '15.0'` matches
      `IPHONEOS_DEPLOYMENT_TARGET` in the project. `Podfile.lock`/`Pods/` remain uncommitted (generated
      on the runner). **Not build-verified — see the note at the end of this phase.**
- [x] **2.3 Wire `DEVELOPMENT_TEAM` into Xcode signing** — **DONE 2026-08-16.**
      `DEVELOPMENT_TEAM = JPU8WX66BX` is now set on all three Runner build configurations (Debug,
      Release, Profile) in `project.pbxproj`. The diagnosis in the old text was correct and the bug was
      real: `ios-testflight.yml` passed the team as `--dart-define=IOS_DEVELOPMENT_TEAM`, which only
      defines a Dart compile-time constant and never reaches the Xcode build setting — so signing was
      never configured at all. That flag has been removed from the workflow, and the
      `IOS_DEVELOPMENT_TEAM` repo secret is now unused (drop it from the 2.1 list when convenient).
      `ios/ExportOptions.plist` added for manual `xcodebuild -exportArchive`; CI still uses
      `flutter build ipa --export-method=app-store` and does not read it.
      **Not build-verified — see the note below.**

> **None of Phase 2's code prep has been compiled.** It was written on Windows with no Mac available,
> and `ios-build.yml` was deliberately not dispatched: it runs on `macos-latest`, which meters at 10×
> on this public repo and once consumed $75 of an ~$80 monthly allowance. Treat 2.2/2.3 as "correctly
> configured on inspection," not "green." The first real macOS run should be a deliberate, budgeted
> `workflow_dispatch`. Note also that `ios-build.yml` triggers on `pull_request` touching `ios/**`, so
> **any PR that edits iOS files spends macOS minutes** — land iOS-only changes directly on `main`.
- [ ] **2.4 Run `ios-testflight.yml`** (manual dispatch) → first build lands in App Store Connect →
      TestFlight. This is the proof-of-life for the whole pipeline. Bump `pubspec.yaml` off `1.0.0+1`.
- [ ] **2.5 Install via TestFlight on a real device** and smoke-test the core flows.

---

## Phase 3 — Backend IAP receipt verification (MT-350, CODE)

> **This entire phase was rewritten 2026-08-16. The old text — "the one genuinely large engineering
> item, ~45h, the backend doesn't implement them" — was stale by about a month** and was still being
> quoted in planning as the largest remaining blocker. It is not. The code shipped mid-July in PRs
> #428, #429, #432, and #436. Re-verified against `main` on 2026-08-16: there is **no
> `NotImplementedError` anywhere in `backend/routes/iap_routes.py`**.

- [x] **3.1** `_verify_with_apple()` — **DONE**, real implementation at `iap_routes.py:961`.
- [x] **3.2** `_verify_with_google()` — **DONE**, real implementation at `iap_routes.py:1119`.
- [x] **3.3** Server-to-server notifications — **DONE in code.** Apple ASSN V2 and Google RTDN handlers
      exist (`iap_routes.py:310` and `:354`), and `IapNotificationEvent` now has a writer
      (`_record_notification_event`, `:425`). **Console step still outstanding:** set the ASSN V2 URL in
      App Store Connect to `/api/iap/apple/notifications` and provision the Apple S2S credentials
      (`.p8` + `APPLE_KEY_ID`/`APPLE_ISSUER_ID`/`APPLE_BUNDLE_ID`). Gated on the app record existing.
- [x] **3.4** Cross-channel entitlement reconciliation — **DONE**, single-writer `apply_entitlement()`
      at `backend/services/entitlement_service.py:64`, shared by Stripe + Apple + Google.

**Remaining Phase-3 scope is only 3.5 below** — sandbox proof and the `IAP_VERIFICATION_ENABLED` flag
flip, both gated on store products existing (Phase 1.5), which is gated on the Paid Apps agreement
(1.1b). Do not flip the flag before a sandbox purchase succeeds.
- [ ] **3.5** Sandbox-test end-to-end: TestFlight purchase → verify → entitlement, fail-closed on bad receipt.

---

## Phase 4 — Kids-Category / review compliance (OWNER + light CODE)

- [x] **4.1 DECISION: formal Kids Category vs general-audience Families listing. DECIDED 2026-07-13** —
      see `docs/DECISION_D1_D2_KIDS_CATEGORY_ANALYTICS_2026-07-13.md`. **D1 = general-audience listing
      (Books or Education category, 4+ age rating). Do NOT enter Apple's Kids Category** — it is a
      one-way door (Guideline 1.3, forum precedent) for zero launch benefit given the app's
      parent-directed acquisition model.
- [x] **4.2 Firebase Analytics decision. DECIDED 2026-07-13** — same memo. **D2 = keep Firebase
      Analytics and Sentry**, hardened per the memo's §4 (H-1…H-6, implemented): ad-personalization
      signals disabled at the plist level, `setUserId` removed (analytics data is Not Linked), the two
      most sensitive Firebase events rerouted to first-party only, a separate default-OFF analytics
      consent toggle, and a Sentry event tag/extra scrubber. No stripping required — the general-Families
      listing (4.1) does not trigger Guideline 5.1.4's Kids-Category analytics ban.
      Note: no `NSUserTrackingUsageDescription` is present — no tracking / no IDFA / no ATT prompt
      anywhere in the project (verified 2026-07-13), so "Data Not Used to Track You" is accurate.
- [ ] **4.3 Apple Privacy Nutrition Label** — enumerate every SDK/data flow (OpenAI, Replicate,
      Cloudflare, Azure, Stripe, Firebase, Sentry, Resend). ~~**Not drafted** — the MT-145 attempt hit a
      usage limit before writing `docs/STORE_PRIVACY_FORMS_DRAFT.md` (file absent).~~
      **STALE — corrected 2026-08-16: the draft EXISTS**, `docs/STORE_PRIVACY_FORMS_DRAFT.md`, ~32 KB,
      with `path:line` citations. Remaining work is owner transcription into the console, not drafting.
      (Historical note: Glob returned a false negative on this file twice during the 2026-08-14 audit —
      `ls` and `git ls-tree` both find it. Trust the shell.)
- [ ] **4.4 Age-rating questionnaire** in App Store Connect. ~~(Families, under-13 primary.)~~
      **CORRECTED 2026-08-16** — this contradicted decision D1 (2026-07-13): the listing is
      **general-audience, NOT the Kids Category**, on both stores, with COPPA handled in-product.
      Answer the questionnaire to match that, and do not re-litigate the positioning here.
- [x] **4.5 Confirm Sign in with Apple is N/A** — **DONE, verified 2026-08-16.** Guideline 4.8 applies
      only if third-party social login is offered. `pubspec.yaml` has no `google_sign_in`,
      `sign_in_with_apple`, `flutter_facebook_*`, or `firebase_auth` — no social login exists, so
      Sign in with Apple is not required. Re-check if any social login is ever added.
- [ ] **4.6 Mic/camera Kids-Category justification** (STORE-8) — declare optional; confirm speech-to-text
      on-device vs cloud status for the privacy form.

---

## Phase 5 — Store listing + submit (OWNER)

- [ ] **5.1 Trademark clearance (MT-172)** — flagged "do BEFORE any store listing" (Pratham Books
      "StoryWeaver" collision). Listing under **"Once Upon YOUR Child"** materially de-risks it, but the
      formal USPTO/counsel clearance is still open. Gate check before submit.
- [ ] **5.2 Listing assets** — screenshots (6.7"/6.5" iPhone + iPad if universal), description, keywords,
      support URL, **privacy policy URL** (needs Privacy Policy v3 published — see cross-cutting gates),
      promo text. App icon already present.
- [ ] **5.3 Submit for review.** Expect kids-app scrutiny; budget for 1–2 review bounces.

---

## Cross-cutting launch gates (block ANY launch — web too; not iOS-specific)

These live in `docs/LAUNCH_CRITICAL_PATH_2026-07-08.md` and must be cleared regardless of platform:

- [ ] COPPA config flips on Railway — `COPPA_REQUIRE_VERIFIED_CONSENT`, `ENFORCE_RESOLVED_AGE`,
      `COPPA_REQUIRE_CURRENT_POLICY_VERSION` (MT-310).
- [ ] Privacy Policy v3 **published** (MT-330) — also the 5.2 listing privacy URL.
- [ ] OpenAI DPA + Zero Data Retention confirmed (MT-318).
- [ ] Clinical sign-off — Adolescent antihero band stays gated OFF pending review (MT-266c).
- [ ] External legal review — COPPA consent mechanics + retention (LAUNCH-CRITICAL O7).
- [ ] **MT-363** photo-avatar opt-in enforcement + **MT-364** Celery PII-log redaction — *currently in the
      open PR queue* (PRs #421 / #420). Merge those and these clear.

---

## Open decisions for the owner

| # | Decision | Why it matters |
|---|----------|----------------|
| D1 | ✅ **DECIDED 2026-07-13** — Kids Category vs general-Families listing (4.1) | General-Families listing chosen; see `docs/DECISION_D1_D2_KIDS_CATEGORY_ANALYTICS_2026-07-13.md` |
| D2 | ✅ **DECIDED 2026-07-13** — Firebase Analytics on kids build — keep/strip/gate (4.2) | Kept + hardened (§4 of the same memo), not stripped |
| D3 | IAP migration timing (MT-143 D-2) — before store launch, or web-first + IAP fast-follow | Sets whether Phase 3 blocks first submission |
| D4 | Small Business Program enrollment (1.2) | 30%→15% commission on all IAP revenue |

## Key files & references

- Signing/CI: `.github/workflows/ios-build.yml`, `ios-testflight.yml`, `docs/IOS_TESTFLIGHT_SETUP.md`
- IAP code: `lib/services/payment/` (client), `backend/routes/iap_routes.py` (server, stubbed)
- IAP brief / gap table: `audit/STORE-1-IAP-BRIEF.md`, MT-143 / MT-350 in `docs/MANUAL_TASKS.md`
- Console forms: MT-145, MT-317 in `docs/MANUAL_TASKS.md`
- Compliance origin: `audit/LEGAL-COMPLIANCE.md` (STORE-1…10)
- Android sibling (for parity/pattern): `docs/ANDROID_KEYSTORE_RUNBOOK.md`, MT-144
