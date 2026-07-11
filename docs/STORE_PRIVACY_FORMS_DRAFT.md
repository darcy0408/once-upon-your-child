# Store Privacy & Age-Rating Forms — Draft (MT-145)

> **STATUS: DRAFT, enumerated from the actual codebase at `C:\dev\sw-ios-path` as of
> 2026-07-09 (worktree branch `session/ios-path`, tip `6fb9f725`).** This is a
> transcription aid, not a filed form. The owner must (1) re-verify every row against
> current Railway env vars / live behavior before submitting — code shows what *can*
> happen, not what's flipped on in production right now — and (2) actually paste the
> answers into App Store Connect / Play Console / IARC. **Read Section 4 (⚠️ Gap
> Analysis) first** — it lists every place the app's real data behavior diverges from
> what `PRIVACY_POLICY.md` or the in-app consent screens promise a parent. Submitting
> a privacy label that doesn't match the code is a false attestation to Apple/Google,
> which is a worse outcome than an honestly-disclosed data flow.
>
> Positioning used throughout: **Families app, under-13 primary**, general-audience
> listing (not Apple's dedicated Kids Category) — per the task brief. Note this is
> still an **open owner decision (D1)** in `docs/IOS_APP_STORE_CRITICAL_PATH.md`
> §4.1; if Kids Category is chosen instead, Section 4 item G4 below changes the
> Firebase Analytics answer materially.

---

## 0. Vendor / data-flow inventory (source of truth for all three forms)

Confirmed by reading code, not the policy doc. "Live default" = what runs today with
no special env var; "Reachable" = code path exists but requires explicit opt-in or a
non-default config.

| Vendor | Data sent | Purpose | Status | Key evidence |
|---|---|---|---|---|
| **OpenAI** (GPT-5 mini) | Pseudonymized hero token, story theme/details, "big feelings" text, image/avatar prompts; photo bytes on avatar path | Story text (default) + character avatars (gpt-image, primary) | **Live default** | `backend/config/__init__.py:146-147` (`STORY_GEN_PROVIDER` defaults `"openai"`); `backend/tasks/story_tasks.py:203-234` (hard-coded openai fallback + prod warning if anything else); `backend/services/avatar_generation_service.py:58-80` (OpenAI primary avatar generator) |
| **Cloudflare Workers AI** (Flux Schnell) | Image/illustration prompts | Story-page illustrations, primary | **Live default** | `backend/routes/story_routes.py:690-715` (`_generate_flux_illustration`, tried first) |
| **Replicate** | Image prompts; photo bytes on avatar fallback path | Illustration fallback (Flux Schnell) + avatar fallback | **Live fallback** (fires when Cloudflare fails/quota-exhausted, or when `REPLICATE_API_TOKEN` set and used as avatar fallback) | `backend/routes/story_routes.py:716-728`; `backend/services/avatar_generation_service.py:118-145` |
| **OpenRouter** | Image prompts; photo bytes on avatar fallback path (if no Replicate token) | Story-text dev/local provider (non-default) + shared image-generator fallback + avatar fallback-of-fallback | **Reachable** — image fallback wired via `app.py:550-577` when `OPENROUTER_API_KEY` set; story-text path only when `STORY_GEN_PROVIDER=openrouter` (used in local dev, not prod default) | `backend/app.py:541-609`; `backend/tasks/story_tasks.py:344-372` |
| **Google Gemini** (`google-genai`) | Image prompts (illustration/avatar dev path); story prompts (residual); TTS text | Illustration/avatar **direct-Gemini path is OFF by default** (`ALLOW_DIRECT_GEMINI_IMAGE` must be set, local/dev only per comments); story-text path only if `STORY_GEN_PROVIDER=gemini` is explicitly set (self-flags loudly in prod logs if it ever is); Gemini Flash TTS is a narration fallback tier | **Residual / gated-off by default** — Gemini's API ToS forbid child-directed apps (MT-137), so every direct-Gemini construction site has an explicit off-by-default guard | `backend/app.py:543-609`; `backend/services/avatar_generation_service.py:44-104`; `backend/tasks/story_tasks.py:212-235,293-341`; `backend/routes/tts_routes.py:81-130` |
| **Anthropic (Claude)** | Story prompts | Alternate story-text provider for a possible future paid tier | **Present in code, not reachable in prod today** — `STORY_GEN_PROVIDER=claude` required, and `ANTHROPIC_API_KEY` is not currently set on Railway (per project ops notes) | `backend/tasks/story_tasks.py:375-402`; `backend/requirements.in:17-24` |
| **Microsoft Azure AI Speech** | Generated story text | Voice narration, **licensed primary** when `AZURE_SPEECH_KEY`/`AZURE_SPEECH_REGION` are set | **Live when configured** (real-time synthesis, no server-side audio retention per provider) | `backend/routes/tts_routes.py:16-20`; `backend/requirements.in:83-91` |
| **Google (Gemini Flash TTS)** | Generated story text | Narration fallback tier (between ElevenLabs and Edge, or primary tier if Azure unconfigured) | **Live fallback**; barred for ALL minors (under-18), not just under-13 (MT-327) | `backend/routes/tts_routes.py:81-130,312-325,483-490` |
| **Microsoft Edge TTS** (free, no key) | Generated story text | Final online narration fallback before on-device `flutter_tts` | **Live fallback** | `backend/routes/tts_routes.py:132-150` |
| **ElevenLabs** | Generated story text | Opt-in premium/dialogue-differentiated narration voice | **Live, opt-in, gated only to under-13** — see ⚠️ Gap #1 below | `backend/routes/tts_routes.py:304-367`; `backend/.env.example:92` |
| **Stripe** | Parent payment info (web checkout only; tokenized, no card data touches this app's servers) | Subscription billing on the **web** channel | **Live (web only)** | `backend/requirements.in:52`; `in_app_purchase` is the store-build channel instead (see below) |
| **Apple / Google IAP** (`in_app_purchase` 3.2.0) | Store transaction ID, product ID, purchase receipt | Subscription billing on **iOS/Android store builds** (Stripe web checkout is compiled out of store builds — App Store/Play Store forbid it for digital subscriptions) | **Live (store builds)** | `pubspec.yaml:62-67`; `lib/services/payment/`; `backend/routes/iap_routes.py`; `backend/models/iap_event.py` |
| **Railway (Postgres)** | All first-party app data: accounts, characters, stories, consent records, subscription state | Cloud hosting / database of record | **Live** | `backend_db_architecture` — Postgres on Railway since 2026-05-14 |
| **Firebase Analytics** | Anonymized usage events, user ID (when enabled) | App analytics | **Wired but collection defaults OFF; enabled only for self-attested age ≥ 18 AND explicit consent** | `lib/services/firebase_analytics_service.dart:23-48`; `lib/services/privacy_service.dart:58-81`; `lib/services/privacy_defaults.dart` (CAADCA `adultAge = 18`) |
| **Sentry** | Crash/error diagnostics, `sendDefaultPii=false`, breadcrumbs stripped of message/data | Crash reporting / stability | **Wired but reporting defaults OFF; enabled only under the same consent+18 gate as Firebase Analytics** (same `applyConsentDecision` call) | `lib/main.dart:20-76`; `lib/services/sentry_consent_gate.dart` |
| **Resend** | Parent/guardian email address, consent verification code | COPPA parental-consent verification emails | **Live when `RESEND_API_KEY` configured** | `backend/utils/email_service.py`; `backend/.env.example:32` |

**No ad SDK / no tracking SDK found**: no `google_mobile_ads`, no Facebook Audience
Network, no `AD_ID` Android permission, no `NSUserTrackingUsageDescription` in
`ios/Runner/Info.plist`, no IDFA/AdSupport usage anywhere in `lib/`. This supports
answering **"Data Used to Track You" = None** on the Apple label and **"Does your app
use an advertising ID?" = No** on Play.

---

## 1. Apple App Privacy ("Privacy Nutrition Label")

Apple's three buckets, then data types within each. Only types with a real code-backed
flow are listed; omit the rest on the console (Apple's default is "not collected").

### Bucket: Data Used to Track You
**None.** No ad SDK, no cross-app/cross-site identifier sharing, no IDFA. Answer "No"
to "Do you or your third-party partners collect data from this app to track users."

### Bucket: Data Linked to You
Data tied to the account (`user.id`) or a named child profile.

| Apple category | Collected? | Purpose(s) | Notes |
|---|---|---|---|
| **Contact Info** — Email Address | Yes | App Functionality, Account creation | `user.email` (`backend/models/user.py:12`); parent email also captured transiently in `consent_record.parent_email` for COPPA verification |
| **Contact Info** — Name | Yes | App Functionality | Child/character `name` (`backend/models/character.py:9`) — a chosen character name, not necessarily the child's legal name, but treat as Contact-adjacent/User Content; `username` on the account |
| **Health & Fitness** | **OWNER VERIFY — recommend Yes** | App Functionality | See ⚠️ Gap #2: `parent_hidden_context` stores structured emotional/behavioral fields (`feeling`, `trigger`, `body_signal`, `coping_tool`, `repair_goal`) per child, retained until erasure. This is the closest fit to Apple's Health & Fitness (or Sensitive Info) bucket even though the app is marketed as "not a health product." Under-disclosing this is the single biggest false-attestation risk in this draft. |
| **Financial Info** | Yes (indirectly) | App Functionality (payment) | `stripe_customer_id` linked to account (web); IAP `product_id`/`store_transaction_id`/`tier` linked to account (store builds) — no raw card data ever reaches this app's server (Stripe/Apple/Google tokenize) |
| **User Content** — Photos or Videos | Yes, optional | App Functionality | Photo-to-avatar path: photo bytes transit the request to OpenAI/Replicate/OpenRouter, are **not persisted** server-side (no DB column, no disk/S3 write found for raw photo bytes — only the generated cartoon `avatar_data` is stored). Off by default; requires explicit parental opt-in (`ConsentRecord.allow_photo_avatar`) |
| **User Content** — Other User Content | Yes | App Functionality | Generated stories/story text (`story.content` JSON), character customization (personality, likes/dislikes/fears/goals — `backend/models/character.py`) |
| **Identifiers** — User ID | Yes | App Functionality | `user.id` (UUID), `child_profile_id` |
| **Identifiers** — Device ID | **OWNER VERIFY** | — | No explicit device-ID collection found server-side; `package_info_plus`/`flutter_secure_storage` are local-only. Verify no IAP/Sentry payload includes a device identifier before answering "No." |
| **Purchases** — Purchase History | Yes | App Functionality | Subscription tier, IAP product/transaction IDs, Stripe customer ID |
| **Usage Data** — Product Interaction | Yes (first-party) | Analytics, App Functionality | In-house `analytics_events` / `audit_log` Postgres tables, linked to `user_id` (`backend/models/analytics_event.py`, `backend/models/audit_log.py`) — **not** shared with a third party; separate from the optional third-party Firebase Analytics below |
| **Diagnostics** — Crash Data | Yes, consent-gated | App Functionality (stability) | Sentry, off by default, on only after consent + self-attested age ≥ 18 (see vendor table). If answering strictly for what a *child's* session can ever send: **No** (gate never opens for a declared-minor session) |

### Bucket: Data Not Linked to You
| Apple category | Collected? | Purpose(s) | Notes |
|---|---|---|---|
| **Usage Data** — Product Interaction (Firebase Analytics) | Optional, consent-gated | Analytics | Only fires for a session that both (a) got explicit consent and (b) self-attested age ≥ 18 (`PrivacyDefaults.adultAge`). Firebase's own SDK can technically link a user ID if `setUserId` is called (`firebase_analytics_service.dart:74`) — **that actually makes this Linked, not Not-Linked; OWNER VERIFY which bucket to use.** Recommend listing under Data Linked to You instead, given `setUserId` is called in `setUserProperties`. |
| **Identifiers** — Image cache key | No (not personal data) | — | `illustration_cache` rows are keyed by a one-way SHA-256 of inputs, no `user_id` column (`backend/services/data_retention.py:361-369`) |

### Not collected (explicitly ruled out by code)
Location, Contacts, Search History, Browsing History, Sensitive Info's protected-class
categories (race, religion, sexual orientation, etc.) — none found in any model or
client-side collection point.

---

## 2. Google Play Data Safety

| Data type | Collected | Shared | Purpose | Optional/Required | Encrypted in transit | Ephemeral? |
|---|---|---|---|---|---|---|
| Email address | Yes | No (sub-processors get pseudonymized data, not raw email, except Resend which gets parent email solely to deliver the consent code) | Account management, App functionality | Required | Yes (TLS) | No |
| Name | Yes (character/username, not necessarily legal name) | Yes — sent to OpenAI/Cloudflare/Replicate/OpenRouter as part of story/image prompts (pseudonymized "hero token" for OpenAI per `PRIVACY_POLICY.md:148`) | App functionality (personalization) | Required for story generation | Yes | No |
| Photos | Yes, optional | Yes — sent to the active avatar image provider (OpenAI primary, Replicate/OpenRouter fallback) for one-time processing; not stored | App functionality (avatar generation) | Optional (parent opt-in required, off by default) | Yes | Yes — not persisted server-side |
| Health info / "Big Feelings" (emotional/behavioral) | Yes | No (used only to shape AI prompts sent to the story-text provider — see caveat below) | App functionality (story personalization) | Optional | Yes | **No — see ⚠️ Gap #2.** `parent_hidden_context` is retained, not ephemeral, contradicting the "transient" framing in `PRIVACY_POLICY.md`. Answer this row as **retained**, not ephemeral. |
| Financial info (subscription tier/status) | Yes | Yes — Stripe (web) or Apple/Google (store builds) process payment; this app never receives full card data | Account management, App functionality | Required to subscribe | Yes | No |
| App activity / usage data | Yes (first-party `analytics_events`/`audit_log`) + optional third-party (Firebase Analytics) | Firebase data leaves the device only when the 18+-and-consented gate is open | Analytics, App functionality | First-party: required (can't be disabled, it's operational telemetry with no PII/story content per `analytics_event.py:10`); Firebase: optional, default off | Yes | No (retained per the 2-year inactivity window) |
| App info and performance (crash logs) | Yes, consent-gated | Sentry | Analytics (stability) | Optional, default off, gated to 18+ self-attested + consent | Yes | No (Sentry's own retention) |
| Device or other IDs | **OWNER VERIFY** | — | — | — | — | No explicit collection found; verify no IAP/Sentry SDK payload includes one before answering "No" |

**"Is all of the user data collected by your app encrypted in transit?"** → **Yes.**
All backend traffic terminates TLS at Railway's edge / Cloudflare (no code path found
constructing plain-HTTP client requests to first-party infra). `PRIVACY_POLICY.md:68`
also claims this. OWNER VERIFY: no explicit `Strict-Transport-Security` / forced-HTTPS
middleware was found in `backend/app.py` — Railway's edge is presumed to enforce it;
confirm this hasn't regressed since audit-reports were last reviewed.

**"Do you provide a way for users to request that their data is deleted?"** → **Yes.**
- In-app: Parent Controls → Data & Privacy → Delete All My Data (`PRIVACY_POLICY.md:102`)
- API: `DELETE /api/user/<user_id>/data` (`backend/routes/user_routes.py:312-353`),
  which calls `backend.services.data_retention.purge_user_data` — deletes characters,
  stories (linear + interactive), achievements, consent records, **and
  `parent_hidden_context`** (backend/services/data_retention.py:164-237), anonymizes
  the user row, revokes outstanding tokens, and best-effort deletes the Stripe customer.
- Also automatic: `purge_inactive_accounts` (730-day default inactivity window) and
  `purge_unconsented_parent_contact` (30-day window for abandoned consent flows).
- Export: `GET /api/user/<user_id>/export` also exists (`user_routes.py:355+`) —
  supports the Play/Apple "data portability" question too.

---

## 3. Age-rating questionnaires (Apple age rating + Google Play IARC)

Positioning: **Families / general audience, under-13 primary** (per task brief; see
the D1 open-decision caveat in the header). Answers below assume that positioning.

| Question area | Answer | Basis |
|---|---|---|
| Fantasy violence | **Mild / Infrequent** | Superhero/"antihero" archetype content exists for the Adventurer/Adolescent bands (capes, powers, "missions" — `backend/models/character.py:17-19`), but this is storybook-level, not combat-realistic |
| Mature/suggestive themes, profanity, alcohol/drugs/substances | **None intended; OWNER VERIFY residual risk** | The Adolescent "antihero" feature (`ANTIHERO_CRUX_ENABLED`) is **hard-gated OFF by default server-side** (`backend/routes/story_routes.py:426-439`) pending clinical review (MT-266c) — do not describe this content in the rating until/unless that flag is ever flipped on. A prior safety audit found a residual ~1-in-7 risk of substances appearing as incidental "set dressing" even with the feature off in earlier testing; re-verify against the current gate before submitting if the flag status changes. |
| User-generated content shared with other users / chat / multiplayer | **No** | No social, chat, multiplayer, or public-gallery feature found anywhere in `lib/` (searched for community/multiplayer/chat/friend-request patterns — none present). `share_plus` is a local OS share-sheet only, not a publish-to-other-users feature. |
| Unrestricted web access / web browser | No | `url_launcher` opens external links via the OS browser, not an in-app browser |
| Gambling / simulated gambling | No | Not present |
| Horror/fear themes | Mild — the app markets an emotional-wellbeing angle ("big feelings," bedtime mode with a "dim/stay-dark" ending option) but is explicitly not a horror product |
| Medical/treatment information | **OWNER VERIFY — lean Yes, qualified** | The app surfaces "coping tool"/"repair goal" language tied to a child's emotional state (`parent_hidden_context`), and `PRIVACY_POLICY.md:192-194` explicitly disclaims being "a therapeutic, clinical, or medical product." Apple/IARC questionnaires sometimes trigger a "Medical/Treatment Information" prompt for SEL/emotional-regulation content even when self-disclaimed — answer honestly per the actual feature set, not just the disclaimer text. |
| In-app purchases | Yes | Subscription tiers via IAP (store builds) / Stripe (web) — `pricing_decision_2026_07`: $9.99/mo or $59.99/yr Premium, free tier = 5 stories/mo + 1 illustrated story |
| Data collection from children without parental consent | No — COPPA verifiable-parental-consent gate exists for declared age below the jurisdiction's consent age (13 in the US per COPPA, 16 in the EEA per GDPR Art. 8) | `lib/screens/parental_consent_screen.dart`; `backend/models/consent_record.py`; `lib/services/consent_age.dart` |
| Third-party analytics/ads targeting children | No ads. Analytics (Firebase) is wired but **collection is off by default and only turns on for a self-attested adult (18+) who explicitly consents** — never for a declared minor | See vendor table above; this is the strongest evidence for a "no behavioral advertising / no under-13 analytics" answer |

**Apple Kids Category note (cross-reference only, not this task's decision):**
`docs/IOS_APP_STORE_CRITICAL_PATH.md` §4.1/§4.2 flags that if the owner later decides
to list under Apple's formal **Kids Category** instead of general Families, Apple's
Guideline 5.1.4 requires **no third-party analytics SDK at all**, which would mean
`firebase_analytics` must be stripped from that build entirely — not just consent-gated.
The current code's consent-gate-to-18 approach is compliant with a **general Families**
listing but may not satisfy strict Kids Category review. Confirm the listing category
before finalizing this answer.

---

## 4. ⚠️ Policy-vs-code gap analysis (READ THIS FIRST)

Ordered by how much attestation risk each one carries if submitted as-is.

### Gap 1 — ElevenLabs may be reachable by 13–17-year-olds despite an internally-documented "under-18 ToS bar" (HIGH)

- **What the code itself says the risk is:** `backend/.env.example:92` — *"ELEVENLABS_API_KEY = TTS narration (LEGACY/opt-in — under-18 ToS bar; see MT-248)."*
- **What the code actually enforces:** `backend/routes/tts_routes.py:311-325` computes an `is_under_18` flag specifically *because* MT-327 found that the parallel Gemini Flash TTS tier is "barred for ALL minors, not just under-13s" — and that flag is used to gate Gemini TTS at lines 483/490. **The ElevenLabs opt-in gate two hundred lines earlier, at line 358 (`if (premium_voice or wants_dialogue) and is_under_13:`), still checks only `is_under_13`**, not the `is_under_18` variable that was introduced specifically to close this class of gap for the sibling provider.
- **What the policy discloses:** `PRIVACY_POLICY.md:156` — *"ElevenLabs — Generated story text — Premium/character voice narration (ages 13+ only; never for under-13)."* The policy and the code agree with each other (both say 13+), but neither may agree with **ElevenLabs' own terms**, per the codebase's own admission.
- **Why this matters:** this is structurally the same issue as MT-137 (Gemini's ToS forbidding under-18 apps), which was treated as a **contractual launch blocker** requiring story text to move off Gemini entirely. If ElevenLabs' ToS really does bar under-18 processing, a 13-17-year-old who opts into "premium_voice" today can still reach ElevenLabs.
- **Recommended fix:** (a) OWNER VERIFY ElevenLabs' current terms of service for the exact age bar; (b) if confirmed under-18, change `tts_routes.py:358` to gate on `is_under_18` (already computed two lines above the ElevenLabs docstring, reused at 483/490 for Gemini) instead of `is_under_13`; (c) update `PRIVACY_POLICY.md:156` and this draft's vendor table accordingly. Do not attest "ages 13+" to either console until (a) is resolved.

### Gap 2 — "Big Feelings" parent-authored guidance is retained, not transient, contradicting the privacy policy's framing (HIGH)

- **What the policy says:** `PRIVACY_POLICY.md:23` — *"'Big feelings' a child chooses to share... We treat it as transient story-personalization input, not as a health record or a retained emotional profile of your child."* Reinforced at `PRIVACY_POLICY.md:192-194` ("not a therapeutic, clinical, or medical product... not retained as a health profile").
- **What the code does:** `backend/models/parent_hidden_context.py` defines a `parent_hidden_context` table — **"Private parent-authored Big Feelings guidance stored per child profile"** — with structured, persistent fields: `feeling`, `trigger` (required), `body_signal`, `coping_tool` (required), `repair_goal` (required), `created_at`, `updated_at`, unique per `(user_id, child_profile_id)`. This is a genuinely retained, structured emotional/behavioral record, not a one-off transient prompt input. It IS included in the erasure cascade (`data_retention.py:211`) and the 2-year inactivity purge, so retention-*limit* policy is honored — but the "transient... not retained" characterization in the policy text does not match this table's existence and shape.
- **Why this matters:** this is the kind of thing a COPPA regulator or an Apple/Play reviewer, or a parent, would consider materially different from what's promised. It's also the strongest candidate for Apple's Health & Fitness / Sensitive Info bucket (see Section 1) — mischaracterizing it as ordinary "User Content" in the label would be inaccurate.
- **Recommended fix:** update `PRIVACY_POLICY.md`'s "Story & Feelings Data" section to explicitly disclose the parent-authored, retained guidance record (distinct from the child-typed one-off text), and mark it Yes/Linked on both store forms.

### Gap 3 — `STORY_GEN_PROVIDER` on Railway must be independently re-verified, not assumed from this doc (MEDIUM)

The code defaults to `openai` and self-flags loudly (`story_tasks.py:220-234`) if a
production request is ever served by a non-`openai` provider ("routed to a processor
that is NOT disclosed in the privacy policy"). That's a good guard rail, but it's a
**runtime env var**, not a compile-time guarantee — this draft cannot see Railway's
actual configured value. OWNER VERIFY the live `STORY_GEN_PROVIDER` value on Railway
before attesting "story text goes to OpenAI" to either console.

### Gap 4 — Kids Category vs. Families listing decision (D1) changes the Firebase Analytics answer (MEDIUM)

Already tracked as an open owner decision in `docs/IOS_APP_STORE_CRITICAL_PATH.md`
§4.1/§4.2/D1. This draft answers the forms for a **general Families listing**
(analytics consent-gated to 18+ is compliant). If Apple's formal Kids Category is
chosen instead, Guideline 5.1.4 likely requires stripping `firebase_analytics` from
that build entirely — the consent gate alone would not be sufficient. Resolve D1
before finalizing Section 1/3.

### Gap 5 — IP address collection isn't named in the "Information We Collect" section (LOW-MEDIUM)

`ConsentRecord.ip_address` (`backend/models/consent_record.py:38`) and
`AuditLog.ip_address` (`backend/models/audit_log.py:32`) both capture and retain IP
addresses linked to `user_id`. `PRIVACY_POLICY.md`'s "Information We Collect" section
never mentions IP address as a collected field (it's implicitly covered by "Data
Security" / TLS language, but that's about transit encryption, not collection).
Recommend adding one line to the policy; mark IP/Device-ID as collected on both forms
rather than "not collected."

### Gap 6 — Internal docstring says Sentry gates at 13+; actual enforced gate is 18+ (LOW, informational — code is stricter than documented, not a violation)

`lib/services/sentry_consent_gate.dart:11` — *"only when consent was granted AND the
declared age is >= 13."* The actual call site, `lib/services/privacy_service.dart:58-68`,
gates both Sentry and Firebase Analytics on `PrivacyDefaults.analyticsAllowedByDefault`,
which is **18+** (CAADCA `adultAge`), not 13+. This is safe (more protective than
documented) but the stale comment should be fixed so a future reader doesn't
mis-describe the gate. Also: `PRIVACY_POLICY.md:159` says analytics is "not enabled
for children under 13," which a parent of a 13-17-year-old could misread as "might be
on for my teen" — it never is, per current code. Consider tightening the policy
wording to "under 18" for precision (not required for compliance, just accuracy).

### Gap 7 — Speech-to-text audio destination not verified (LOW, OWNER VERIFY)

`speech_to_text: ^7.3.0` is used for voice input (`ios/Runner/Info.plist:52-55`
declares `NSMicrophoneUsageDescription` / `NSSpeechRecognitionUsageDescription`). No
explicit on-device-only flag (e.g., `requiresOnDeviceRecognition`) was found in the
call sites searched (`lib/widgets/voice_mic_button.dart`,
`lib/screens/wizard_steps/hero_creator_step.dart`, etc.). Depending on OS/device
settings, iOS's `SFSpeechRecognizer` and Android's `SpeechRecognizer` may send raw
audio to Apple's/Google's own speech servers — outside this app's declared vendor
list, but potentially relevant to "does this app collect audio data." OWNER VERIFY
before answering the microphone/audio question on either form.

### Gap 8 — Illustration-fallback wording is approximately, not exactly, right (LOW)

`PRIVACY_POLICY.md:163` says story-page illustrations use "Cloudflare Workers AI (with
Replicate, then Gemini, as fallbacks)." The actual chain is Cloudflare → Replicate →
the shared `image_generator` global, which is **OpenRouter** by default (not raw
Gemini) — direct Gemini image generation is off unless `ALLOW_DIRECT_GEMINI_IMAGE` is
explicitly set for local dev (`backend/app.py:541-609`). Minor wording cleanup
recommended; not a compliance-critical gap since OpenRouter itself is already
disclosed as a fallback provider one row above it in the same table.

### Gap 9 — Operator identity is an individual name, not the LLC (LOW, non-data, attestation-relevant)

`PRIVACY_POLICY.md:181` lists the operator as "Darcy VanPelt" (individual), but per
project history the business was formed as an LLC on 2026-06-21. Not a data-flow
issue, but both App Store Connect and Play Console ask for the legal entity behind the
developer account — confirm the console account's registered entity name matches
whatever `PRIVACY_POLICY.md` and the age-rating/developer-identity questionnaires say,
and update the policy's Operator Identity section if the LLC should be the named party
going forward.

### Gap 10 — Anthropic listed in dependencies but not in the privacy policy vendor table (LOW, self-guarded)

`anthropic>=0.115.0` ships in `backend/requirements.in:17-24` and
`ClaudeDirectStoryGenerator` is wired in `backend/tasks/story_tasks.py:375-402`, but
it requires both `STORY_GEN_PROVIDER=claude` and an `ANTHROPIC_API_KEY` that (per
project notes) is not currently set on Railway — so it cannot fire in production today,
and it isn't listed in `PRIVACY_POLICY.md`'s Third-Party Services table. No action
needed unless/until a Claude-backed tier ships; flagging so it isn't forgotten if that
happens (the code's own prod-warning at `story_tasks.py:220-234` will also catch it).

---

## Appendix — files read to build this draft

`pubspec.yaml` · `backend/requirements.in` · `backend/requirements.txt` (spot-checked)
· `backend/config/__init__.py` · `backend/app.py` · `backend/tasks/story_tasks.py` ·
`backend/routes/tts_routes.py` · `backend/routes/story_routes.py` ·
`backend/routes/avatar_routes.py` · `backend/routes/user_routes.py` ·
`backend/services/avatar_generation_service.py` · `backend/services/data_retention.py`
· `backend/models/user.py` · `backend/models/character.py` · `backend/models/story.py`
· `backend/models/consent_record.py` · `backend/models/parent_hidden_context.py` ·
`backend/models/analytics_event.py` · `backend/models/audit_log.py` ·
`backend/models/iap_event.py` · `backend/.env.example` · `PRIVACY_POLICY.md` ·
`lib/main.dart` · `lib/services/firebase_analytics_service.dart` ·
`lib/services/privacy_service.dart` · `lib/services/privacy_defaults.dart` ·
`lib/services/sentry_consent_gate.dart` · `lib/services/consent_age.dart` ·
`lib/screens/parental_consent_screen.dart` · `lib/services/api_service_manager.dart` ·
`ios/Runner/Info.plist` · `docs/IOS_APP_STORE_CRITICAL_PATH.md`.
