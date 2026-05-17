# Legal & Compliance Audit — "Once Upon a Time, powered by Story Weaver"

Date: 2026-05-17
Method: Read-only review by three parallel domain agents — COPPA/GDPR-K, privacy-policy-vs-code,
and app-store/platform policy. Builds on the 2026-05-16 security audit (`security-audit/`); does not
re-report items already shipped per `docs/sessions/2026-05-17-0855-3315.md`.
Scope: perspective #7 of `audit/AUDIT_PERSPECTIVES.md`.
Status legend: ☐ todo · ◐ in progress · ✅ done

---

## Tally

29 findings: **8 Critical · 9 High · 9 Medium · 3 Low**. All 8 Criticals are launch-blockers.
ID prefixes: `CMP-` COPPA/GDPR-K · `PP-` privacy-policy accuracy · `STORE-` app-store policy.

Two themes dominate:
1. **The verifiable-consent mechanism is built but not in force.** The COPPA email round-trip
   exists and is well-engineered — but a flag disables it in all builds (CMP-1/STORE-4) *and* the
   backend gate never checks the `verified` column (CMP-2). Net: the app has **no enforced
   verifiable parental consent** today, despite the machinery being done.
2. **The corrected privacy policy is the wrong file.** The 2026-05-16 "honest disclosure" fix
   edited `PRIVACY_POLICY.md` — which **is never shown in the app** (PP-1). The screen users
   actually see, `lib/screens/privacy_policy_screen.dart`, still carries every false claim.

---

## Launch-blockers (must fix before any public release)

| # | Finding | Fix effort |
|---|---------|-----------|
| 1 | **CMP-1 / STORE-4** — `_kSkipEmailConsent = true` disables COPPA verifiable consent in *release* builds | S (flip flag) |
| 2 | **CMP-2** — backend `require_parental_consent` ignores the `verified` column; consent gate bypassable end-to-end | S (one-line filter) |
| 3 | ~~**PP-1** — the corrected `PRIVACY_POLICY.md` is never rendered; in-app policy is a different, weaker doc~~ — ✅ resolved 2026-05-17 | M |
| 4 | ~~**CMP-3 / PP-2** — policy claims "end-to-end encryption" (false) + wrong age range + stale date~~ — ✅ resolved 2026-05-17 | M |
| 5 | **STORE-1** — Stripe used for in-app subscriptions; Apple & Google require their own IAP | L (2–4 wk) |
| 6 | ~~**STORE-2** — Sentry crash reporting initialized with no consent gate (Kids-Category violation)~~ — ✅ resolved 2026-05-17 | M |
| 7 | ~~**STORE-6 / PP-6** — AI-generated stories/images carry no "AI-generated" label or disclosure~~ — ✅ resolved 2026-05-17 | M |
| 8 | **STORE-10** — Android release build signed with debug keys; Play rejects debug-signed uploads | S |

---

## A. COPPA §312 / GDPR-K — children's data protection

### ☐ CMP-1 — Critical — Verifiable parental consent disabled in all shipped builds
`lib/screens/parental_consent_screen.dart:24` (`_kSkipEmailConsent = true`), `:77-79`, `:691-714`.
The H-8 email round-trip was built and shipped, but the flag forces every under-13 user into the
bare scroll-95%/checkbox flow, recorded `method:'self_attested', verified:false`. A checkbox is the
exact mechanism the FTC sliding scale says is **not** sufficient (§312.5(b)). Tracked as MT-135 —
elevated here from "task" to launch-blocker. **Fix:** set `false`, finish Resend setup (verified
domain, `RESEND_API_KEY`, `CONSENT_EMAIL_FROM` on Railway). Effort: S + S–M.

### ✅ CMP-2 — Critical — Backend consent gate accepts unverified records (fixed 2026-05-17)
`backend/middleware/auth.py:148-163`. `require_parental_consent` grants access on *any*
`ConsentRecord` with `withdrawn=False` — it never checks `verified`. A `verified=False` pending
record (written by `request-verification` before the parent sees any email) fully satisfies the
gate. The model docstring (`consent_record.py:25-28`) explicitly says the gate must treat
`verified=False` as not-consented; the gate does not. **Even after CMP-1 is fixed, consent stays
bypassable** end-to-end at the API. **Fix:** `filter_by(..., withdrawn=False, verified=True)` for
under-13; thread a documented, production-off tester exception. Effort: S.

> **Resolved 2026-05-17:** `require_parental_consent` now also requires
> `consent.verified` when `COPPA_REQUIRE_VERIFIED_CONSENT` is enabled
> (`backend/middleware/auth.py`). The flag defaults OFF so the tester phase is
> not blocked; **set `COPPA_REQUIRE_VERIFIED_CONSENT=true` on Railway at launch,
> together with the `_kSkipEmailConsent` flip (CMP-1).**

### ✅ CMP-8 — Medium — `allow_photo_avatar` defaults TRUE server-side (fixed 2026-05-17)
`backend/models/consent_record.py:22`, `backend/routes/user_routes.py:216`,
`lib/screens/parent_controls_screen.dart:124`. The UI defaults the photo-avatar opt-in OFF
(correct), but the `ConsentRecord` column and the `data.get('allow_photo_avatar', True)` fallback
default ON — so a consent POST omitting the field records the child as opted-in to biometric photo
processing. The consent record is the COPPA audit artifact; it must fail safe. **Fix:** default the
column and the `.get()` fallback to `False`; audit existing rows. Effort: S + migration.

> **Resolved 2026-05-17:** column default and the `data.get(...)` fallback now
> `False` (`consent_record.py`, `user_routes.py`); `_allowPhotoAvatar` UI init
> also `false` (`parent_controls_screen.dart`). The SQLAlchemy-level default
> needs no DDL migration. Optional: audit pre-existing `consent_record` rows
> created under the old default.

### ☐ CMP-6 — Medium — Consent screen is child-directed; no assurance an adult is present
`parental_consent_screen.dart:98-99,151,194-232,976-1077`. Child-directed TTS ("Ask a grown-up to
unlock your magical adventure!"), gamified intro, single checkbox — no parent-gate (the math gate
used at `parent_controls_screen.dart:1102` is not applied here). §312.5 requires reasonable efforts
to ensure consent is from a *parent*. **Fix:** drop child-directed TTS/gamification on the consent
*action*; add a "hand to a parent" interstitial/parent-gate before the checkbox. Effort: S–M.

### ☐ CMP-7 — Medium — Emotional-state data lacks GDPR Art. 9 treatment
`parental_consent_service.dart:279-315`, `parent_controls_screen.dart:286-308`,
`backend/services/story_service.py:217-255`. "Big feelings" input and parent-configured "hidden
context" (child's struggles, triggers, coping tools) are collected, stored, and sent to the LLM.
The policy frames the product as "therapeutic." Emotional/mental-health data is GDPR Art. 9
special-category — needs explicit consent + documented Art. 9(2) basis + a DPIA (Art. 35 trigger).
The consent screen treats it as ordinary personalization. **Fix:** decide whether the product is
therapeutic; if not, strip that framing and treat feelings input as transient; if yes, add explicit
Art. 9 consent + DPIA. Disclose that emotional text is sent to the AI provider. Effort: M (+L if DPIA).

### ☐ CMP-9 — Medium — Consent-age threshold hardcoded to 13; no GDPR-K jurisdiction handling
`parental_consent_screen.dart:74`, `backend/routes/user_routes.py:180,230`,
`backend/middleware/auth.py:144`. GDPR Art. 8 lets member states set the digital-consent age 13–16
(DE/NL/IE 16, ES 14). A 14–15-year-old in a 16-threshold country is treated as a self-attesting
teen. **Fix:** jurisdiction-aware threshold (coarse geo or country selector), defaulting to 16 for
unknown EU traffic. Effort: M.

### ☐ CMP-10 — Low — Re-consent on policy change is client-side only, under-13 only
`lib/main_story.dart:108,124-127`, `parental_consent_service.dart:68-77`. A hardcoded `2026-03-21`
cutoff in the Flutter client clears local consent; the backend `ConsentRecord` is never invalidated
against a policy version. Clearing app storage / reinstalling keeps a stale backend consent.
**Fix:** add `policy_version` to `ConsentRecord`; reject stale versions in the gate; drive the
client cutoff from the server. Effort: S–M.

### ☐ CMP-11 — Low — Direct notice missing operator identity/contact (§312.4(d))
`PRIVACY_POLICY.md:146-152`, `parental_consent_screen.dart:251-331`. §312.4(d) requires operator
name, physical address, and phone. The policy gives only an email; the in-app Notice to Parents
names no entity. Already flagged in `docs/COPPA_AUDIT.md:23`, still open. **Fix:** add legal entity
name, postal address, phone to the policy and the consent-screen notice. Effort: S.

### ☐ CMP-5 / PP-13 — High — Stated retention period has no enforcing code
`PRIVACY_POLICY.md:90-96`. The policy promises deletion after 2 years of inactivity; no cron/Celery
job exists anywhere in `backend/` to enforce it — child PII is retained indefinitely in practice.
A stated-but-unenforced retention period is a §312.10 / GDPR Art. 5(1)(e) gap. **Fix:** implement a
Celery-beat inactivity-purge job, or change the policy to the actual practice (retained until parent
deletes). Define or remove the vague "therapeutic records" retention carve-out. Effort: M.

### Photo onward-transfer (overlaps CMP-5) — High
`photo_bytes` is request-scoped and never persisted server-side (good), but is forwarded to the
active third-party image provider whose retention/training terms are unconfirmed (§312.8 third-party
assurance; tracked as MT-137). **Fix:** obtain written no-training/retention assurances from each
image provider on the photo path; close MT-137 before launch.

## B. Privacy-policy & disclosure accuracy

### ✅ PP-1 — Critical — Two divergent policies; the corrected one is never shown (Resolved 2026-05-17)
The in-app policy is `lib/screens/privacy_policy_screen.dart` (reached from `settings_screen.dart:813`
and `parental_consent_screen.dart:417`). `PRIVACY_POLICY.md` — the file the 2026-05-16 audit
corrected — is never loaded by any Dart code. A third orphaned copy exists at
`lib/privacy_policy_screen.dart` (dead). The C-1 "honest disclosure" remediation edited a file with
zero user-facing effect; parents consent against the still-inaccurate in-app screen. **Fix:** pick
one source of truth — render `PRIVACY_POLICY.md` as a bundled asset and delete both Dart screens,
*or* bring `lib/screens/privacy_policy_screen.dart` fully in line and delete the orphan. Effort: M.

> **Resolved 2026-05-17:** `lib/screens/privacy_policy_screen.dart` is now the
> single in-app policy and was rewritten to be substantively identical to the
> corrected `PRIVACY_POLICY.md`. The orphan `lib/privacy_policy_screen.dart` was
> deleted after confirming via Grep that nothing imports it (both surviving
> imports resolve to `screens/privacy_policy_screen.dart`). `PRIVACY_POLICY.md`
> remains the canonical repo/web copy.

### ✅ PP-2 / CMP-3 — Critical — "End-to-end encryption" claim is false + policy materially stale (Resolved 2026-05-17)
`lib/screens/privacy_policy_screen.dart:79-83`, `PRIVACY_POLICY.md:55`. No E2EE exists — data
transits TLS and is processed/stored in plaintext; only the BYOK key is encrypted at rest. Textbook
FTC deceptive-security claim. Same documents also: wrong age range ("4-12" vs actual 3-17,
`PRIVACY_POLICY.md:72`), stale effective date ("Nov 15 2024" vs a re-consent cutoff of 2026-03-21,
`:3`), Gemini disclosure stronger than the M-7 fix delivers (`:130`), and a "therapeutic records"
framing that overstates collection. **Fix:** delete the E2EE claim (replace with accurate
TLS/at-rest language); correct age range to 3-17; bump and align the effective date; correct the
Gemini line. Effort: M.

> **Resolved 2026-05-17:** the E2EE claim is removed from both `PRIVACY_POLICY.md`
> and `lib/screens/privacy_policy_screen.dart`, replaced with accurate language
> ("encrypted in transit via TLS; stored on access-controlled servers; payment
> data and API keys encrypted at rest" plus an explicit "we do not provide
> end-to-end encryption"). Age range corrected to 3-17 in both. A static
> effective date of 2026-05-17 is set on each document; the Terms screen's
> `DateTime.now()` "Last updated" was replaced with a `lastUpdated` static
> constant. The Gemini disclosure now states accurately that a pseudonymized
> hero token, story details/themes, "big feelings" text, and image prompts are
> sent (no longer "story text only").

### ✅ PP-3 — High — BYOK wizard claims photos are "stored only on your phone and never shared" (Resolved 2026-05-17)
`lib/screens/byok_setup_wizard.dart:139`. The exact false claim C-1 was meant to kill — the photo
is uploaded to the backend and forwarded to a third-party image provider
(`avatar_generation_service.py:247-248,285-286`). The fix missed this benefits-list string.
**Fix:** rewrite to match the corrected disclosure. Effort: S.

> **Resolved 2026-05-17:** the benefit text now reads truthfully — the photo is
> sent to our servers and our AI image provider solely to generate the cartoon
> avatar, is not stored on our servers, and is used for nothing else.

### ✅ PP-4 — High — Consent screen tells the child "Your choices stay on this device" (Resolved 2026-05-17)
`parental_consent_screen.dart:1038-1039` (child-facing) and `:305` (parent-facing "saved on this
device"). Story preferences, feelings, and choices all go to the backend and persist server-side in
Postgres. False privacy claim made directly to a child in a COPPA app. **Fix:** reword both bullets
truthfully (e.g. "Your stories are saved safely — a grown-up can delete them any time"). Effort: S.

> **Resolved 2026-05-17:** both bullets reworded truthfully. Child-facing:
> "Your stories are saved safely — a grown-up can see or delete them any time."
> Parent-facing: "Your child's stories and characters are saved on our secure
> servers — you can view or delete them any time from Parent Controls."

### ✅ PP-7 — High — Three different, likely non-functional rights-contact addresses (Resolved 2026-05-17)
`PRIVACY_POLICY.md:85,150` (`privacy@storyweaver.app`), `privacy_policy_screen.dart:74`
(`onceuponyourchild@gmail.com` + a CO address), `terms_of_service_screen.dart:48,85`
(`support@storyweaver.app`). The `storyweaver.app` addresses appear nowhere else and may be
unprovisioned. §312.6 / GDPR Art. 13 require a working, monitored rights channel. **Fix:**
standardize on one verified, monitored address everywhere; confirm it resolves before launch.
Effort: S.

> **Resolved 2026-05-17:** all three documents (`PRIVACY_POLICY.md`,
> `lib/screens/privacy_policy_screen.dart`, `lib/screens/terms_of_service_screen.dart`)
> now use the single address `onceuponyourchild@gmail.com`; the dead
> `storyweaver.app` addresses are removed. **Action required:** the user must
> confirm `onceuponyourchild@gmail.com` is an actively monitored mailbox before
> launch (§312.6 / GDPR Art. 13 require a working rights channel).

### ☐ PP-8 — Medium — Policy promises a data-export feature that does not exist
`PRIVACY_POLICY.md:86,115`, `privacy_policy_screen.dart:102`. `parent_controls_screen.dart` has
delete but no export/download UI. (A backend `export_user_data` endpoint exists but is not surfaced
in the client.) GDPR Art. 20. **Fix:** surface the existing backend export endpoint in Parent
Controls, or change the policy to "export on request" and ensure that request can be fulfilled.
Effort: M.

### ☐ PP-9 — Medium — Policy promises an analytics opt-out; no in-app toggle exists
`privacy_policy_screen.dart:65`. Analytics is correctly consent+age gated (M-9), but once enabled a
parent has no in-app way to turn it back off. GDPR Art. 7(3) — withdrawal must be as easy as
giving. **Fix:** add an analytics toggle in Parent Controls wired to
`PrivacyService.setAnalyticsConsent`, or drop the promise. Effort: S.

### ☐ PP-11 — Low — Deletion described as "permanently removes all profiles"; code anonymizes
`PRIVACY_POLICY.md:85`, `parent_controls_screen.dart:717` vs `backend/routes/user_routes.py:262-329`.
Child content is hard-deleted, but the user row is anonymized, not removed. Defensible erasure
technique; only the wording overstates it. **Fix:** soften to "deletes your child's data and
anonymizes your account." Effort: S.

### ☐ PP-12 — Low — Effective dates stale / inconsistent; Terms date is a live `DateTime.now()`
`PRIVACY_POLICY.md:3`, `privacy_policy_screen.dart:88`, `terms_of_service_screen.dart:86`. The Terms
"Last updated" renders the current device date, so it appears to change daily. **Fix:** one static,
accurate effective date per document; hard-code the Terms date. Effort: S.

## C. App-store & platform policy

### ☐ STORE-1 — Critical — Stripe used for in-app subscriptions
`lib/widgets/subscribe_button.dart:39-84`, `lib/services/stripe_service.dart:23-49`,
`lib/premium_upgrade_screen.dart`, `lib/paywall_dialog.dart`. The paywall opens a Stripe-hosted
web checkout via `launchUrl`. Apple Guideline 3.1.1 and Google Play Payments policy **require**
their own IAP for in-app digital goods — automatic rejection on both stores. **Fix:** implement
StoreKit / Google Play Billing (`in_app_purchase` plugin), define products in App Store Connect /
Play Console, reconcile entitlement server-side. Keep Stripe only for the Flutter **web** build;
gate it unreachable on iOS/Android. Effort: L (2–4 weeks).

### ✅ STORE-2 — Critical — Sentry initialized with no consent gate (Resolved 2026-05-17)
`lib/main.dart:19-37`. `SentryFlutter.init()` runs unconditionally at the top of `main()`,
`sampleRate=1.0` in release, before any consent — unlike Firebase Analytics, which *is* correctly
gated. Apple Kids-Category 1.3/5.1.4 prohibits third-party crash/analytics from a child's session
without verified consent. **Fix:** gate Sentry behind the same `PrivacyService` consent decision
(init only post-consent, age ≥ 13), or confirm a children's-safe config (`sendDefaultPii=false`,
breadcrumb scrub) + DPA. Effort: M.

> **Resolved 2026-05-17 (`99cfde6f`):** Sentry's `beforeSend` hook now drops
> every event while `SentryConsentGate.isReportingEnabled` is false (its
> startup default). `PrivacyService.applyConsentDecision` flips it true only
> when consent is granted AND declared age ≥ 13 — the same gate as analytics.
> Also set `sendDefaultPii=false` and lowered the release `sampleRate` to 0.2.
> Follow-up: breadcrumb scrubbing + a Sentry DPA are still recommended.

### ✅ STORE-6 / PP-6 — Critical — AI-generated content is not labelled or disclosed (Resolved 2026-05-17)
`lib/story_result_screen.dart`, `character_preview.dart`, `avatar_gallery_selector.dart`; no
AI-transparency section in any policy/consent surface. Google Play's Generative-AI policy requires
in-app disclosure + a content-report mechanism; Apple flags unlabelled generative AI, especially in
kids' apps; EU AI Act Art. 50 requires AI-output disclosure. **Fix:** persistent "Created with AI"
label on generated stories/avatars; in-app "report this content" path; AI-disclosure section in the
privacy notice + a line in the consent flow; complete the Play Console gen-AI declaration. Effort: M.

> **Resolved 2026-05-17 (`4f788edc`):** new `AiGeneratedBadge` widget — a
> "Created with AI" chip on the story result screen and corner "AI" badges on
> generated illustrations and character avatars. An "AI-Generated Content"
> section was added to the privacy policy (doc + in-app screen), a one-line AI
> notice to the consent flow, and a "Report this content" (mailto) affordance.
> Follow-ups: the Play Console generative-AI declaration (a console action,
> not code); and the live BYOK prefetch illustration widget
> (`per_page_illustration.dart`) does not yet carry the badge.

### ◐ STORE-10 — Critical — Android release build signed with debug keys (code done 2026-05-17; keystore pending)
`android/app/build.gradle.kts:34-37` (`TODO: Add your own signing config`). Play rejects
debug-signed AABs — blocks the upload step. **Fix:** create a release keystore + signing config.
Also set the user-visible app name to the brand ("Once Upon a Time…") in `android:label` /
`CFBundleDisplayName` — currently the slug "story_weaver_app" (STORE-10 also covers this). Effort: S.

> **Code done 2026-05-17:** `android/app/build.gradle.kts` now loads a release
> signing config from `android/key.properties` (gitignored), falling back to
> debug signing if absent so `flutter run --release` still works locally.
> **Still required (you must do this — it creates a credential you must own
> and back up):** generate the keystore and create `key.properties`:
> ```powershell
> keytool -genkey -v -keystore $env:USERPROFILE\story-weaver-release.jks `
>   -keyalg RSA -keysize 2048 -validity 10000 -alias story-weaver
> ```
> Then create `android/key.properties` (NOT committed):
> ```
> storePassword=<the store password you chose>
> keyPassword=<the key password you chose>
> keyAlias=story-weaver
> storeFile=C:/Users/Darcy/story-weaver-release.jks
> ```
> Keep the `.jks` file outside the repo and **back it up** — losing it means
> you can never publish an update to the Play listing. The app-name rename
> (slug → brand) is deferred. 

### ✅ STORE-3 — High — Age rating / declared range inconsistent across the app (Resolved 2026-05-17)
`lib/onboarding_screen.dart:22` (ages 3-12 only — appears to be dead duplicate),
`lib/screens/welcome_screen.dart:82-83` (offers 15-17, 18+), `:952` (dialog says "for ages 13 and
up"). Effective served range is 3-21. Apple's Kids Category is segmented 5-/6-8/9-11 and does not
accommodate teens/adults. **Fix:** decide store positioning (recommend: Families app targeting
under-13, 13+ as secondary); remove the dead `onboarding_screen.dart`; make the rating
questionnaire, in-app gate, and marketing copy agree. Effort: M.

> **Resolved 2026-05-17 (`30691bab`):** positioning decided — Families app,
> under-13 primary, 13-17 secondary. The dead `lib/onboarding_screen.dart` was
> deleted; the false "Story Weaver is for ages 13 and up" dialog was reworded;
> the age step now states the app serves ages 3-17. **Still required (console,
> not code):** set the App Store Connect / Play Console age-rating questionnaire
> and store-listing copy to the under-13 Families positioning.

### ✅ STORE-5 — High — No neutral age gate; age picker is child-completed and gamified (Resolved 2026-05-17)
`lib/screens/welcome_screen.dart:241-290`. No "ask a parent" screen, no DOB entry; the child taps a
playful age band. Apple 5.1.4 / Google Families expect a neutral, non-incentivized gate (ideally
DOB-derived). **Fix:** add a neutral age/DOB gate as the first screen — plain styling, no steering
TTS, no reward for older ages. Effort: M.

> **Resolved 2026-05-17 (`30691bab`):** the age step is now neutral — a calm
> "How old is the child?" header (plain font), no decorative glyphs, no steering
> TTS, and the Adventurer-band "unlocked new adventures" celebration was removed
> so an older age band is not a reward. Age-band selection is otherwise
> unchanged (no DOB switch). Optional future enhancement: a true DOB-derived gate.

### ✅ STORE-7 — Medium — External links open without a parental gate (Resolved 2026-05-17)
`byok_setup_wizard.dart:38-41` (Google AI Studio), `settings_screen.dart:851` &
`parental_consent_screen.dart:442-447` (elevenlabs.io). Apple Kids 1.3/5.1.4 requires links out and
account-creation flows behind a parental gate. **Fix:** route every external `launchUrl` through the
existing math parental gate; confine the BYOK/API-key flow to a parent-only area. Effort: S–M.

> **Resolved 2026-05-17 (`e6b7f4ff`):** the Google AI Studio link (BYOK wizard)
> and the ElevenLabs partner link (settings) now sit behind a multiplication
> `ParentalGateDialog`. Follow-ups: the consent-screen `elevenlabs.io` link
> (`parental_consent_screen.dart:442-447`) is still ungated; and the math gate
> now has three near-duplicate implementations worth consolidating into one.

### ☐ STORE-8 — Medium — Mic/camera capture from children needs Kids-Category justification
`android/app/src/main/AndroidManifest.xml:5` (`RECORD_AUDIO`), `pubspec.yaml:38,47-48`
(`speech_to_text`, `camera`, `image_picker`). iOS usage strings are all present (good). Photo-avatar
is opt-in/parent-gated (good); `speech_to_text` is not documented as on-device vs cloud. **Fix:**
confirm speech recognition is on-device (no audio leaves the device) and document it, else
consent-gate it; ensure store privacy forms declare mic/photo accurately as optional. Effort: S–M.

### ☐ STORE-9 — Medium — Data-safety form / privacy nutrition label must list every SDK
`pubspec.yaml:51-55` (`firebase_analytics`, `sentry_flutter`, `google_generative_ai`),
`firebase_options.dart`, `ios/Runner/GoogleService-Info.plist`. BYOK also sends story prompts
directly from the device to Google's API. Play Data Safety and Apple Privacy Label must enumerate
every SDK + data flow; omissions trigger enforcement. **Fix:** build a complete data-flow inventory;
match both store forms exactly; confirm each SDK version is on Google's Families self-certified list.
Effort: M.

### ✅ Third-party / sub-processor disclosure (CMP-4 + PP-5 + STORE-9) — High (PP-5/CMP-4 Resolved 2026-05-17)
The consent screen lists only 3 processors (Gemini, ElevenLabs, Stripe); `PRIVACY_POLICY.md` lists
5; **neither** lists Cloudflare Workers AI, Firebase Analytics, Sentry, or Resend — all of which
receive data. Cloudflare may receive a child's photo while undisclosed. §312.4(d) / GDPR Art. 13.
**Fix:** one canonical sub-processor table (name, data received, purpose, location, policy link)
used verbatim in the in-app policy *and* the consent screen, covering every provider in the live
build. Effort: M.

> **Resolved 2026-05-17 (PP-5 / CMP-4):** one canonical sub-processor list now
> appears in both `PRIVACY_POLICY.md` (as a table) and the consent screen's
> "Third-Party Services" section, covering all 10 live providers: Google Gemini,
> OpenRouter, Replicate, Cloudflare Workers AI, ElevenLabs, Stripe, Railway,
> Firebase/Google Analytics, Sentry, Resend — each with data category received
> and purpose. The consent-screen Gemini line was corrected (no longer "story
> text only" — it also receives image prompts, "big feelings" text, and a
> pseudonymized hero token; the photo-avatar path to OpenRouter/Replicate/
> Cloudflare is now disclosed). STORE-9 (store data-safety forms) remains open —
> Phase 4.

---

## What is done well — protect against regression

- Collection-before-consent is genuinely deferred — name/age not persisted until consent succeeds
  (`welcome_screen.dart:839-867`).
- Right-to-erasure / right-to-access endpoints are solid: `delete_user_data` cascades across all
  child content + consent records, anonymizes the user, bumps `token_version`, rate-limited,
  audit-logged; `export_user_data` is a real export (just not surfaced in UI — PP-8).
- The email-verification mechanism itself is well-built (SHA-256-hashed codes, 15-min expiry,
  5-attempt cap, constant-time compare, fails closed when email unconfigured) — it just needs to be
  switched on (CMP-1) and enforced (CMP-2).
- `consent_method` recording is honest post-H-8; the test bypass is compile-time only and records
  an honest `debug_bypass` method.
- Firebase Analytics is correctly consent+age gated and defaults OFF — the model Sentry should copy.
- No third-party ad SDKs bundled; the app is genuinely ad-free.
- iOS permission usage strings are all present and purpose-specific.
- Photo-avatar is opt-in, off by default, parent-controlled; `photo_bytes` never persisted server-side.

---

## Recommended remediation order

**Phase 1 — cheap launch-blockers (hours):** CMP-1, CMP-2, STORE-10, CMP-8. Flip the flag, fix the
gate filter, create the release keystore, fix the photo-avatar default.

**Phase 2 — disclosure truth (1–2 days):** ✅ done 2026-05-17 — PP-1 (consolidate to one real
policy), PP-2/CMP-3 (remove E2EE claim, fix age range/date), PP-3/PP-4 (false "on device" claims),
PP-7 (standardize the rights-contact address — user must still confirm the mailbox is monitored),
the sub-processor table (CMP-4/PP-5). PP-6 (AI disclosure) deferred to Phase 3.

**Phase 3 — store gates (days):** ✅ done 2026-05-17 — STORE-2 (gate Sentry, `99cfde6f`),
STORE-6/PP-6 (AI labelling, `4f788edc`), STORE-7 (parental gate on external links, `e6b7f4ff`),
STORE-3 + STORE-5 (age positioning + neutral gate, `30691bab`). Console follow-up: set the store
age-rating questionnaire and listing copy to the under-13 Families positioning (STORE-3).

**Phase 4 — larger / decision-gated:** STORE-1 (IAP migration — 2–4 weeks, start now), CMP-5/PP-13
(retention job), CMP-7 (therapeutic-data decision + possible DPIA), CMP-9 (jurisdictional consent
age), PP-8/PP-9 (export + analytics-opt-out UI), STORE-9 (data-safety forms).

## Out-of-scope follow-ups
- STORE-1's IAP migration is large enough to warrant its own brief.
- CMP-7's "is this a therapeutic product?" is a product/legal decision, not an engineering fix.
- Provider DPA review for child photos (MT-137) continues from the security audit.
