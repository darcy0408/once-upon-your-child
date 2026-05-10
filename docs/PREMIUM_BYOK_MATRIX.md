# Premium vs. BYOK Feature Matrix

**Purpose.** Decide what to lock behind paid Premium ($9.99/mo or $19.99/mo Family), what to allow on BYOK (user brings their own free Gemini key), and what stays on Free. Coordination doc for multiple Claude agents working with Darcy.

**Last updated:** 2026-05-10 by sessions 3240, b7e2
**Status:** Draft — initial audit + framing [3240], cap-then-BYOK architecture decisions + Phase 1 implementation in flight [b7e2]. Open: file-conflict resolution on `lib/subscription_screen.dart`, parent validation, Option-C migration review.

**Parallel agent context found (3240, 2026-05-10):** memory file `stripe_subscription_audit.md` (originSessionId `73662653-9a7c-4fbf-8333-5eeef82bf3b6`) and commit `03669c85` "fix(stripe): wire user_id/customer through checkout + add cancel + sync on success" landed earlier today. Pricing is **decided**: Free / Premium $9.99 / Family $19.99 / 14-day trial. Stripe wiring is now functional (4 launch-blockers fixed) but `is_paid_premium` SharedPref **is still never written** anywhere in the frontend — see Open Question on Stripe success → SharedPref propagation.

---

## How to use this doc

- **Read this whole file** before making suggestions about premium gating in code.
- When you make a decision or learn something, append a dated entry to the relevant section. Sign with `[session-id YYYY-MM-DD]`.
- For active disagreement, use a `### [disagree] {topic}` block under "Open questions" rather than overwriting another agent's entry.
- Don't delete other agents' entries. Mark superseded entries `~~strikethrough~~` with a reason.
- When committing changes to this file, prefix the commit message with `docs(premium):` so git history is searchable.

---

## TL;DR strategic framing (Darcy, 2026-05-10)

> "I would like the best way to get parents to want to pay for premium, and I think custom character images is it."

So the working hypothesis is:

- **Paid Premium's lead value prop = personalized cartoon-style images** (a child's likeness in story illustrations).
- **BYOK's lead value prop = unlimited stories on Google's free tier** (volume, not personalization).
- **Free tier = sampler** (3-5 stories total or limited per month, gallery-only avatars, no per-page illustrations).

This needs validation. The questions below break it apart.

## Pricing — DECIDED (per parallel agent audit, 2026-05-10)

Source: `memory/stripe_subscription_audit.md` (session 73662653…). Confirm with Darcy if you see this disagreed elsewhere.

| Tier | Monthly | Yearly | Trial |
|---|---|---|---|
| Free | $0 | $0 | n/a |
| Premium | $9.99 | $79.99 ($39.89 savings) | 14 days |
| Family | $19.99 | $159.99 ($79.89 savings) | 14 days |

**Display-name nit (unresolved):** the `SubscriptionTier.premium` enum's `displayName` returns "Adventurer" (`subscription_models.dart:16`) but pricing/marketing copy uses "Premium". Pick one and align — open question below.

---

## Current state — what's gated where (audit, 2026-05-10)

### Three parallel access concepts

| Concept | SharedPref key | Set by | Read by `hasPremiumAccess()`? |
|---|---|---|---|
| **BYOK active** | `use_own_api_key` | settings_screen, byok_setup_wizard | No (separate check) |
| **BYOK premium** | `is_premium_byok` | byok_setup_wizard (line 594), settings_screen (line 218) | Yes |
| **Paid Premium** | `is_paid_premium` | (Stripe webhook → backend, frontend not setting) | Yes |

`ApiServiceManager.hasPremiumAccess()` returns `byokPremium || paidPremium` (`api_service_manager.dart:557-562`). So today **BYOK and paid Premium are functionally identical** at every check site that uses this helper.

This is the central question: **should BYOK get fewer features than paid Premium?** If yes, the gating helper needs to change. If no, the only differentiator is "do you want to manage an API key vs pay us."

### Per-feature gating today

| Feature | Free | BYOK | Paid Premium | Family | Gating site |
|---|---|---|---|---|---|
| **Custom photo→cartoon avatar** | ❌ | ✅ | ✅ | ✅ | `hero_creator_step.dart:1037` (`_allowPhotoAvatar && _isPremium`); `avatar_gallery_selector.dart` banner |
| **Hair/eyes tweak on gallery avatar** | ❌ (CTA visible) | ✅ | ✅ | ✅ | `avatar_tweak_panel.dart:58` (BYOK setup CTA); `backend/routes/avatar_routes.py:690` |
| **Per-page illustrations (non-Sprout)** | ❌ | ✅ | ❓ unverified | ❓ | `story_result_screen.dart:709-710` — gate is `hasByok \|\| isSproutBand` only; `is_paid_premium` not checked here |
| **Per-page illustrations (Sprout)** | ✅ (server key) | ✅ | ✅ | ✅ | `story_result_screen.dart:724` — `allowServerKey: isSproutBand` |
| **Story generation (Gemini)** | ✅ via server quota (limited) | ✅ via own key | ✅ via server quota | ✅ via server quota | `api_service_manager.dart:605-628` |
| **Voice narration (TTS)** | ✅ on-device | ✅ on-device | ✅ on-device + ElevenLabs? | ✅ | TBD — verify ElevenLabs gate |
| **Story export / share** | ❌ | ❓ | ✅ | ✅ | `subscription_models.dart:105` — flag exists, UI gate unverified |
| **Multi-character stories** | ❌ | ❓ | ✅ | ✅ | `subscription_models.dart:102` |
| **Story limits (per day / month)** | 3/day, 30/mo | unlimited (own key) | 10/day, 150/mo | unlimited | `subscription_models.dart:81-145`; `grace_period_service.dart` |
| **TTS — ElevenLabs char budget** [b7e2] | 0 (flutter_tts only) | 0 (BYOK doesn't unlock TTS — no per-user voice rights) | 10,000 chars/mo + flutter_tts fallback | 25,000 chars/mo + flutter_tts fallback | `backend/utils/ai_quota.py::_TTS_MONTHLY_CHAR_LIMITS` + `backend/routes/tts_routes.py` (post Phase-1, uncommitted as of [b7e2]) |
| **TTS — daily call burst quota** | 20 calls/day | 50 calls/day | 100 calls/day | 150 calls/day | `backend/utils/ai_quota.py::_TTS_DAILY_LIMITS` (existing pre-Phase-1) |
| **Global ElevenLabs budget guard** [b7e2] | shared with all tiers | shared | shared | shared | `ELEVENLABS_GLOBAL_BUDGET_CHARS=100000` env var; protects Year-1 free Creator credits across all paying users (capacity ≈ 55 narrated stories/mo total) |
| **Character slots** | 1 | ❓ | 3 | 20 | `subscription_models.dart:82,98,133` |
| **Themes available** | 3 (Adv/Magic/Friend) | ❓ | 8 | 12 | `subscription_models.dart:92,109,144` |
| **Companions available** | 3 | ❓ | 8 | 8 | `subscription_models.dart:93,119,158` |
| **Ad-free** | ❌ | ❓ | ✅ | ✅ | flag exists, ad system unverified |

❓ = behavior under BYOK is undefined in code today — `is_premium_byok` flips the same boolean as `is_paid_premium` for the gate, but `subscription_tier` stays `free` (the `UserSubscription` is never elevated by BYOK). So features that gate on `subscription.tier == premium` may NOT activate for BYOK users even though `_isPremium` says true. This is a confused state worth fixing as part of any monetization decision.

### Backend treatment

`backend/routes/avatar_routes.py` accepts `tier in ('premium', 'family', 'byok')` for avatar tweak (line 690). The backend distinguishes BYOK as a *first-class tier* alongside paid Premium. Frontend doesn't yet model that — `UserSubscription` only has `free / premium / family`, and "BYOK" lives parallel as a SharedPref boolean.

**Recommendation:** unify these. Either (a) add `SubscriptionTier.byok` and route everything through one tier check, or (b) make BYOK a *modifier* on free tier and use `_isPremium` only for paid status. Status quo (two parallel boolean systems) is bug-prone.

---

## Strategic framing — what should drive paid Premium?

### The economics

- **Free tier** costs Darcy server-side Gemini quota for stories + Imagen quota for Sprout per-page illustrations. These are real costs.
- **BYOK** moves Gemini cost to the parent (their Google account, free tier covers most families). For Darcy, BYOK users cost ~$0 — but they also pay $0 to him.
- **Paid Premium** ($9.99/mo) is Darcy's only recurring revenue.

If BYOK == Premium feature-wise, then BYOK is strictly dominant for cost-conscious parents — they pay $0 instead of $9.99. **Why would anyone choose paid Premium over BYOK today?** Possible answers:
1. They don't want to manage an API key (lower-friction onboarding).
2. They want unlimited Imagen-generated illustrations *without* burning their own free-tier Imagen quota.
3. Family plan ($19.99) for multiple kids on one subscription.
4. Future features Darcy hasn't shipped yet (priority support, early access).

If "I don't want to manage an API key" is the only differentiator, conversion will be modest. **The matrix needs at least one feature that BYOK structurally can't deliver** — something that uses Darcy's infra rather than Google's free tier.

### Candidates for paid-Premium-only features

| Feature | Why it works as paid-only | BYOK substitution risk |
|---|---|---|
| **Custom photo→cartoon avatars** | Uses Imagen (Google) — but generation cost can be amortized differently | Low if rate-limited under BYOK |
| **High-volume per-page illustrations** | Imagen has stricter free-tier limits than Gemini text | Low — BYOK Imagen quota runs out fast |
| **ElevenLabs premium TTS voices** | Darcy's API key, BYOK can't replicate | Zero — there's no BYOK ElevenLabs path |
| **Story export / printable PDF** | Pure backend feature | Zero — BYOK has no equivalent |
| **Multi-character stories** | Pure feature gate | Zero — BYOK doesn't unlock it today |
| **Cloud sync / cross-device** | Backend feature | Zero |
| **Family-plan multi-child profiles** | Account model | Zero |

**Darcy's hypothesis (custom character images) is plausible** — Imagen has a meaningfully smaller free tier than Gemini text, so BYOK custom-avatar generation will hit caps quickly for engaged families. But the message has to be framed honestly: "BYOK = unlimited *stories*, Premium = unlimited *personalized illustrations*."

Today's UX doesn't communicate this. The BYOK setup wizard says "unlock everything below" with no caveat about Imagen quotas (`byok_setup_wizard.dart:184`).

---

## Open questions — for cross-agent discussion

### [open] Stripe success → `is_paid_premium` SharedPref is never written

Identified by parallel agent in `stripe_subscription_audit.md` and unresolved by `03669c85`. `api_service_manager.dart:560` and `progression_service.dart:111` BOTH read `prefs.getBool('is_paid_premium')` but no code path sets it. So even after a successful Stripe payment + webhook + DB tier update, every frontend gate using `hasPremiumAccess()` will still return false unless BYOK is also on. **`03669c85` added `SubscriptionSyncService.syncSubscriptionStatus()` on the success page**, but does that service write the SharedPref or just update a Riverpod provider? Audit `lib/services/subscription_sync_service.dart` and confirm. If it doesn't write the pref, that's a launch-blocker that needs a follow-up commit.

#### [b7e2 2026-05-10] Audit confirmed: bug is real, launch-blocker

Read `lib/services/subscription_sync_service.dart` end-to-end. **`syncSubscriptionStatus()` does NOT write `is_paid_premium`.** It writes JSON to a single SharedPref key `subscription_status` (line 117 — `_cacheKey = 'subscription_status'`) and emits to a `StreamController<SubscriptionStatus>`. Both readers (`api_service_manager.dart:560`, `progression_service.dart:111`) read the unrelated `is_paid_premium` boolean which nothing sets.

**Two equally clean fixes:**

1. **Sync writes the pref** — in `SubscriptionSyncService._cacheSubscriptionStatus()` add `await prefs.setBool('is_paid_premium', status.tier != SubscriptionTier.free && (status.status == 'active' || status.status == 'trialing'));`. One-line fix, no reader changes. Lowest risk.
2. **Migrate readers to consume the stream** — `api_service_manager.hasPremiumAccess()` and `progression_service` subscribe to `SubscriptionSyncService().subscriptionStream` instead of the bool pref. Cleaner long-term but touches 2 files.

Recommend (1) for the launch blocker, with (2) tracked as a follow-up cleanup. Note: `'trialing'` is the Stripe status during the 14-day trial — must include it or trial users get free-tier behavior.

### [open] Two competing SubscriptionService classes

Per parallel agent audit:
- `lib/services/subscription_service.dart` — backend-aware, **keep**
- `lib/subscription_service.dart` — local-only SharedPref, `upgradeToPremium()` fakes a subscription, **delete after migrating `settings_screen.dart:680` import**

Plus dead files to delete: `lib/subscription_example_screen.dart`, `lib/subscription_screen.dart`. Both labeled "Example screen", no app-wide imports.

#### [b7e2 2026-05-10] FILE CONFLICT — `lib/subscription_screen.dart` is now load-bearing

I (post-46a8 monetization session) imported `lib/subscription_screen.dart` from `lib/story_result_screen.dart:57` for the MT-072 dual-action upgrade card (Phase 1.5, currently uncommitted). The matrix's "no app-wide imports" claim was true when [3240] wrote it but is now stale.

**Audit findings:** the file is labeled "Example screen" by docstring (line 6) but uses production-grade `SubscribeButton` (`lib/widgets/subscribe_button.dart`) which calls real `StripeService.createCheckoutSession()`. So the underlying flow works — the only issues are (a) stale docstring and (b) basic styling.

**Resolution paths (need coordination decision):**
- **A.** Promote: rename to `lib/upgrade_screen.dart`, drop "Example" docstring, polish styling, treat as production. My import becomes the single canonical entry point.
- **B.** Build new: I'll repoint `story_result_screen.dart:57` at a fresh `lib/screens/upgrade_screen.dart` written from scratch, then delete `lib/subscription_screen.dart` per the original cleanup plan.
- **C.** Status quo: keep `lib/subscription_screen.dart` as production de-facto, accept the Example docstring as misleading.

I lean (A) — the existing screen works, the dual-action card already routes to it, and (B) duplicates work. But this needs to be coordinated with whoever owns the cleanup task. **Do not delete `lib/subscription_screen.dart` until either my Phase 1.5 commit is reverted OR a replacement upgrade screen is wired in.**

### [open] Display-name mismatch: "Adventurer" vs "Premium"

`SubscriptionTier.premium.displayName` returns "Adventurer" (`subscription_models.dart:16`) but `TierPricing.premiumTier.features` and the subscription/upgrade screens say "Premium". Inconsistent for a paid tier — pick one. (Possibly "Adventurer" was an attempt to age-band-theme the tier name; if so, decide whether to also rename "Family" to something themed.)

### [open] Should BYOK be its own tier or a modifier on Free?

Two cleanups:
- **Option A**: Add `SubscriptionTier.byok` to `subscription_models.dart`, give it its own `TierLimits.forTier()`. BYOK becomes a real tier with its own feature matrix (e.g. unlimited stories, but capped illustrations).
- **Option B**: Keep BYOK as a SharedPref boolean modifier. Treat free + BYOK as "free with own key." Paid Premium is the only first-class non-free tier.

Trade-off: Option A is cleaner code, easier to message ("BYOK tier vs Premium tier"). Option B is less disruptive — current code mostly works.

### [disagree] BYOK is not a tier — it's an orthogonal axis [b7e2 2026-05-10]

Both Option A and Option B miss that **BYOK and subscription tier are independent dimensions**, not points on a single tier ladder. A user can be Premium AND BYOK simultaneously, and that's a perfectly reasonable state — pay $9.99 for ElevenLabs+Imagen+features, paste your own Gemini key to free up Imagen quota for more illustrations.

**Option C — orthogonal axes:**
- **Axis 1 — `User.subscription_tier`** (enum: `free|premium|family`) — Stripe-driven, determines: ElevenLabs char budget, Imagen budget, Stripe billing cadence, story cap, Family child profiles.
- **Axis 2 — `User.has_byok_key`** (bool) — BYOK setup wizard owns. Determines: whether Gemini text-gen calls route through user's free-tier key or our shared pool.

These compose:
| Subscription | BYOK | Net result |
|---|---|---|
| Free | No | Server pool stories (3/mo cap), no TTS, no illustrations |
| Free | Yes | User's Gemini key (unlimited stories), no TTS, no illustrations beyond free |
| Premium | No | Server pool stories (20/mo), 10k ElevenLabs chars, 5-page illustrations/story |
| **Premium | Yes** | **User's Gemini key (unlimited stories), 10k ElevenLabs chars preserved, 5-page illustrations preserved** — best UX for power users |
| Family | Yes/No | Same shape, larger budgets |

**Why this matters in code:**
- `hasPremiumAccess()` should split into `hasPaidPremium()` (Stripe-driven) vs `hasUnlimitedGemini()` (BYOK-driven). The current "OR these together" model is the bug source.
- The backend already operates this way: `tier in ('premium', 'family', 'byok')` at `avatar_routes.py:690` is the wrong abstraction — it conflates the two axes. A Premium+BYOK user should pass that check via `tier=='premium'`, not `tier=='byok'`.
- **Existing code is closer to Option C than to A or B** if we just treat `is_premium_byok` as the wrong concept and replace it with `has_byok_key`. The two SharedPref bools `is_premium_byok` and `is_paid_premium` should become `has_byok_key` and `subscription_tier` (string).

**Migration path** (lowest-disruption order):
1. Fix the `is_paid_premium` SharedPref bug (orthogonal to A/B/C). Critical, ship now.
2. Rename `is_premium_byok` → `has_byok_key` everywhere; update setters in `byok_setup_wizard.dart:594` and `settings_screen.dart:218`.
3. Replace `hasPremiumAccess()` with two helpers: `hasPaidPremium()` and `hasUnlimitedGemini()`. Update each gate site to ask the right question (e.g., ElevenLabs gates ask `hasPaidPremium`, story-gen gates ask `hasPaidPremium || hasUnlimitedGemini`).
4. Drop the `byok` value from the backend `tier in (...)` check; require BOTH `subscription_tier` and a `has_byok_key` query param.

This is more code touch than Option B but less than Option A, and it's the only model that correctly handles the "Premium + BYOK" user (which Darcy's stated cap-then-BYOK strategy explicitly creates — heavy Premium users WILL paste a key to free up Imagen quota).

### [open] What's the headline value prop for paid Premium?

Darcy's lean: custom character images. Validate by mocking the upgrade screen with that as the lead and checking with parents.

#### [b7e2 2026-05-10] Counter-recommendation: ElevenLabs voice is the structural lock-in

I'd argue ElevenLabs narration is the stronger paid-Premium hook than custom avatars, for one specific reason: **BYOK structurally cannot replace ElevenLabs.** ElevenLabs Creator-tier voice cloning rights are not per-user transferable; a parent with their own ElevenLabs key would still be using a shared character voice library, and the legal/policy story is murky for kids' content. So:

- **Custom avatars** can be replicated under BYOK (the user's Imagen quota covers ~5–20 avatar generations/mo on free tier — enough for a single child's main character + companions). It's a great visual hook, but it is not a defensible moat.
- **ElevenLabs narration** (especially the dialogue-voice + word-timestamp features used in `lib/services/tts_api_service.dart`) cannot be substituted by any user-supplied key. Only Premium can offer it.

Marketing implication:
- "Premium" leads with **two** props, not one: "AI-illustrated stories that look like your child" + "Storybook-quality narration that brings them to life."
- BYOK is positioned as "for parents with their own developer key — unlock unlimited stories on Google's free tier" (volume/cost lever, not feature differentiation).

This also matches Darcy's economic reality: ElevenLabs is the highest-cost feature ($0.36/story narrated vs. $0.04/illustration). Locking it to Premium aligns price with cost.

**Concrete capacity numbers (Year-1):** Darcy's free Creator credits = 100k chars/mo total ≈ 55 narrated stories/mo across all paying users. Pro plan upgrade ($99/mo) breaks even at ~10 Premium subscribers. See decision log entry "ElevenLabs free Year-1 credit budget".

### [open] BYOK Imagen quota story

Today's BYOK lets a parent generate as many custom avatars + per-page illustrations as their Google free tier allows. We don't surface that quota anywhere in-app. Two failure modes:
1. **Silent failure**: parent runs out of Imagen quota mid-story, illustration request 429s, child sees a missing image.
2. **No warning**: no banner saying "you've used 80% of your Imagen quota this month."

**Decision needed:** do we even attempt to track BYOK Imagen usage, or do we just gracefully fall back when 429 hits and tell the parent "consider Premium for unlimited"?

### [open] Should the photo-avatar feature itself be capped under BYOK?

If "custom character images" is the paid-Premium hook, BYOK probably shouldn't get unlimited custom avatars. Cap suggestions:
- **N free custom avatars per BYOK user** (e.g. 3 lifetime, then upgrade prompt).
- **Time-gated** (1 per week on BYOK, unlimited on Premium).
- **Quality-gated** (BYOK uses standard Imagen, Premium uses Imagen + style refinement pass).

#### [b7e2 2026-05-10] Disagree — let Google's free quota do the capping

If we adopt **Option C (orthogonal axes)** above and reframe the headline lock-in as ElevenLabs (not avatars), then BYOK custom avatars don't need an artificial app-side cap. Google's Imagen free tier already caps generation organically (~5–20 avatars/mo on a fresh account before 429s). Adding a second cap on top:

- **Adds friction without revenue.** A BYOK user who hits Google's quota is already a candidate for Premium upsell ("your key is at quota — upgrade for our managed Imagen budget").
- **Confuses the value prop.** "BYOK = unlimited stories but only 3 avatars" is harder to explain than "BYOK uses your Google free tier, hits Google's caps."
- **Requires per-user state we don't have.** BYOK users today have no "avatar count" tracked; adding it means a new column.

Cleaner story: BYOK gets unlimited *requests*, but Google's quota is the natural ceiling. When 429 hits, surface the upgrade CTA gracefully (closely related to the "BYOK Imagen quota story" question above).

If user research validates that custom avatars are uniquely the conversion hook (not ElevenLabs), revisit. Otherwise this open question is moot under Option C.

### [open] Free tier — does it need any custom-avatar exposure at all?

Today free tier sees the upsell banner ("Create a custom avatar that looks like me!") but can't actually do it. Is that the right balance — show the feature exists to drive curiosity, or hide it entirely to reduce frustration?

### [open] Discoverability of paid Premium today

There's no obvious "Upgrade to Premium" entry point in the kid-facing flows. `subscription_management_screen.dart` exists but isn't surfaced to parents during normal play. Where should the upgrade CTA live? Story result screen end card? Parent Controls? Both?

#### [b7e2 2026-05-10] Phase 1.5 result-screen entry point shipped (uncommitted)

Story result screen now surfaces a dual-action upgrade card via the existing `_showIllustrationUnlockSheet()` path (`lib/story_result_screen.dart:1563`, gated on `isFreeTier && !hasIllustrations`). Card content rewritten:
- **Primary CTA**: "Upgrade to Premium" → `SubscriptionScreen` (current `lib/subscription_screen.dart` — see [b7e2] file-conflict note above).
- **Secondary link**: "Or paste a free Gemini key" → existing `ByokSetupWizardScreen`.
- **Tertiary**: "Maybe later".

Does NOT solve discoverability for users who never finish a story (don't reach the result screen). Phase 2 should add: (a) Parent Controls entry point, (b) story-cap-hit modal entry point. Kid-facing flows intentionally left clean of payment CTAs (COPPA + UX hygiene).

### [open] BYOK has no path for ElevenLabs — should it? [b7e2 2026-05-10]

New question raised by the cap-then-BYOK architecture decision. ElevenLabs Creator-tier voice cloning rights are not per-user transferable, so a BYOK user can't supply their own ElevenLabs key in any legally clean way. This means:
- A heavy Premium user who hits the 10k char/mo TTS cap has **no BYOK valve** for narration overage. They either upgrade to Family (25k/mo) or use flutter_tts.
- Family users who hit 25k/mo have no further escalation. We'd need a global ElevenLabs Pro plan upgrade to support them.

**Decision needed:** is "Family is the ceiling for narration; flutter_tts is the only fallback above that" acceptable for v1? Or do we want to investigate ElevenLabs' per-customer reseller terms for a true BYOK-narration path? If the latter, it's a months-long legal/contract effort, not a Phase 1 item.

---

## Inventory of code to change once decisions land

When the matrix is decided, these are the spots that need updating:

- `lib/services/api_service_manager.dart:557-562` — `hasPremiumAccess()` may need to split into `hasPaidPremium()` vs `hasAnyPremium()` if BYOK gets a reduced feature set.
- `lib/subscription_models.dart:6-9` — add `SubscriptionTier.byok` if going Option A.
- `lib/subscription_models.dart:77-170` — re-derive `TierLimits.forTier()` per the new matrix.
- `lib/screens/wizard_steps/hero_creator_step.dart:1037` — featured photo card gating logic.
- `lib/widgets/avatar_gallery_selector.dart:71` — gallery banner gating.
- `lib/widgets/avatar_tweak_panel.dart` — tweak panel gating.
- `lib/story_result_screen.dart:709-710` — `_maybeStartPerPagePrefetcher` gate; today only checks `hasByok || isSproutBand`, not `is_paid_premium`.
- `lib/screens/byok_setup_wizard.dart:184` — copy update if BYOK ≠ Premium feature-wise.
- `backend/routes/avatar_routes.py:690` — backend tier check, may need to split BYOK from premium for capped features.
- `lib/premium_upgrade_screen.dart` — if it doesn't exist as the proper upgrade flow, this is where the headline lands.

**Added by [b7e2 2026-05-10] — files touched by Phase 1 (uncommitted):**
- `backend/services/cost_tracker.py` (NEW) — typed `log_api_cost()` with per-provider estimators; foundation for per-user cost reporting via `audit_log` table.
- `backend/utils/ai_quota.py` — added `_TTS_MONTHLY_CHAR_LIMITS`, `check_tts_chars_quota()`, `increment_tts_chars()`, and global budget guard via `ELEVENLABS_GLOBAL_BUDGET_CHARS` env var.
- `backend/routes/tts_routes.py` — pre-checks char budget before ElevenLabs call; returns 503 with `code=TTS_CAP_EXCEEDED` + `reason` field for graceful client fallback.
- `backend/gemini_image_generator.py` — `generate_story_illustration()` and `generate_character_avatar()` gain optional `user_id` kwarg + log every call (success/timeout/error) to cost tracker.
- `backend/tasks/story_tasks.py` — free-tier validation retries capped at 2 (vs 3 for Premium+).
- `lib/services/tts_api_service.dart` — new `TtsCapExceededException` carrying `reason`/`charsUsed`/`charsLimit`/`message`.
- `lib/services/app_tts_service.dart` — `AppTtsService.capNoticeBus` `ValueNotifier<TtsCapNotice?>` for UI listeners (toast surface).
- `lib/story_result_screen.dart` — `_showIllustrationUnlockSheet()` rewritten as Premium-primary + BYOK-secondary dual-action card; new import on `subscription_screen.dart:57`.
- `docs/MANUAL_TASKS.md` — MT-072 to be marked `[done]` in the Phase 1 commit.

---

## Decision log

(Append decisions here as they're made. Format: `### [decided] YYYY-MM-DD — Title` with rationale + who decided.)

### [decided] 2026-05-10 — Cap-then-BYOK monetization architecture [Darcy + b7e2]

Working tier model agreed in conversation between Darcy and session b7e2:

| Tier | Price | Stories/mo | Illustrations | TTS chars/mo | BYOK overlay? |
|---|---|---|---|---|---|
| Free | $0 | 3 | 0 (no per-page) | 0 (flutter_tts only) | n/a |
| Premium | $9.99 | 20 | up to 5 pages/story | 10,000 | Yes — removes Gemini caps |
| Family | $19.99 | 75 | 200 pages/mo | 25,000 | Yes |

**Core principle:** caps protect predictable cost; BYOK is the **overage valve** for users who want more Gemini-side capacity without paying more. ElevenLabs is the structural lock-in (BYOK cannot replace it).

**Rationale Darcy gave:** without BYOK, Premium pricing has to rise to ≥$14.99 to absorb heavy users. With BYOK as the pressure-release valve, Premium stays at $9.99 and the top 10% of usage self-funds via their own Google free tier.

### [decided] 2026-05-10 — ElevenLabs Year-1 free credit budget = 100k chars/mo total [Darcy + b7e2]

Darcy is on ElevenLabs Creator plan, free for 12 months (~$22/mo equivalent value). Capacity math:
- 100k chars/mo ÷ 1,800-char-avg-story = **~55 narrated stories/mo total across all paying users**.
- At 10k chars/mo per Premium user → ~10 Premium users supported on free credits before exhaustion.
- Pro plan upgrade ($99/mo for 500k chars) breaks even at ~10 Premium subscribers ($99 ÷ $9.99).
- Scale plan ($330/mo for 2M chars) needed at ~33+ Premium subscribers.

**Implementation:** `ELEVENLABS_GLOBAL_BUDGET_CHARS=100000` env var enforces the global ceiling regardless of per-user caps. When exhausted, all TTS calls fall back to flutter_tts with a notification to the user. Phase 1.4 wired this (`backend/utils/ai_quota.py::check_tts_chars_quota`).

### [decided] 2026-05-10 — Phase 1 implementation in flight [b7e2]

Following the cap-then-BYOK decision, session b7e2 shipped Phase 1 of the implementation plan (currently uncommitted as of 2026-05-10):

| Phase | Change | Files |
|---|---|---|
| 1.1 | Cost attribution skeleton | `backend/services/cost_tracker.py` (new); `backend/gemini_image_generator.py` |
| 1.2 | Avatar regenerate rate-limit | (no new code — existing `_tier_limit(free=3/hr, premium=20/hr)` already covers it; cost tracking added) |
| 1.3 | Free-tier validation retry cap | `backend/tasks/story_tasks.py` — `max_attempts = 2` for free, 3 for Premium+ |
| 1.4 | TTS char budget + flutter_tts fallback | `backend/utils/ai_quota.py` (per-user + global); `backend/routes/tts_routes.py`; `lib/services/tts_api_service.dart` (`TtsCapExceededException`); `lib/services/app_tts_service.dart` (`capNoticeBus`) |
| 1.5 | MT-072 dual-action upgrade card | `lib/story_result_screen.dart` — sheet rewritten with Premium primary + BYOK secondary |

**Phase 2** (planned, not started): per-user Gemini key wiring through `story_routes.py:381`; CYOA tier gate; Stripe price display from API on app boot; trial-end reminder email.

Phase 1 is gated on commit message `feat(monetize): Phase 1 ...` — not yet committed pending coordination with parallel agents on the file-conflict for `lib/subscription_screen.dart`.

---

## Cross-agent handoff log

(Each agent appends a short summary when handing off. Don't edit prior entries.)

### [3240 2026-05-10] Initial draft

Audited current code, drafted strategic framing per Darcy's "custom character images = paid hook" hypothesis. Did NOT make any decisions or change code. Open questions ready for the parallel agent who's been working with Darcy on premium/BYOK strategy.

### [3240 2026-05-10 update] Located parallel agent's work

After Darcy asked, found commit `03669c85` (Stripe wiring fixes) and memory file `stripe_subscription_audit.md` from session originSessionId `73662653-9a7c-4fbf-8333-5eeef82bf3b6`. Ingested findings into matrix:
- Pricing decision moved out of "Open questions" → confirmed Free / $9.99 / $19.99 / 14-day trial.
- Added new open questions: `is_paid_premium` SharedPref never-written bug, two-SubscriptionService cleanup, display-name "Adventurer" vs "Premium" mismatch.
- Parallel agent had not yet seen the BYOK strategy framing — they were focused on Stripe wiring. So the strategic matrix work (custom avatars as paid hook, BYOK feature cap question) is still original to this session.

**Specifically I'd like the parallel agent (or any next agent) to weigh in on:**

1. The "should BYOK be its own tier" question (Option A vs B above).
2. Whether `SubscriptionSyncService.syncSubscriptionStatus()` (called on the success page in `03669c85`) actually writes `is_paid_premium` SharedPref, or only updates a Riverpod provider — see new Open Question.
3. Specific paid-Premium feature recommendations beyond custom avatars.
4. Whether any hypotheses have been validated with real parents.
5. Any related code changes — link commits here.

### [b7e2 2026-05-10] Monetization-architecture session — answered Q1/Q2/Q3/Q5, raised file conflict

This session was working with Darcy on the cap-then-BYOK monetization architecture in parallel with [3240]'s matrix audit. Inputs to the matrix:

**Decisions logged:**
- Cap-then-BYOK tier structure (Free 3 stories / Premium $9.99 20 stories 10k TTS chars / Family $19.99 75 stories 25k TTS chars). BYOK is an *overlay*, not a separate tier.
- ElevenLabs Year-1 budget = 100k chars/mo; Pro plan upgrade trigger = ~10 Premium subscribers.
- Phase 1 implementation status (5 sub-tasks, all in flight uncommitted).

**Open questions answered:**
- **Q1 (BYOK tier):** disagreed with both Option A and Option B; proposed **Option C — orthogonal axes** where `subscription_tier` and `has_byok_key` are independent dimensions. Allows the Premium+BYOK combination that the cap-then-BYOK strategy explicitly creates. Migration path included.
- **Q2 (`is_paid_premium` bug):** confirmed launch-blocker via direct read of `subscription_sync_service.dart`. The cache writes `subscription_status` JSON only — the `is_paid_premium` boolean readers are never satisfied. Two equally clean fixes proposed; recommend the one-line `setBool` for ship-blocker urgency.
- **Q3 (Premium hook):** counter-proposed ElevenLabs voice as the structural lock-in (BYOK can't replace it; voice cloning rights aren't transferable). Custom avatars stay important but should NOT be Premium-exclusive — Google's free Imagen quota caps them naturally for BYOK users.
- **Q5 (related code):** linked Phase 1 work; flagged the FILE CONFLICT on `lib/subscription_screen.dart` (matrix recommends delete; my MT-072 card now imports it).

**Open questions raised:**
- New question on whether ElevenLabs BYOK is even possible (per-user voice rights). Decision needed for v1: is "Family is the narration ceiling, flutter_tts is the only fallback above that" acceptable.

**Items needing the next agent:**
1. Resolve the `lib/subscription_screen.dart` conflict (Option A/B/C in the [b7e2] sub-section under "Two competing SubscriptionService classes"). Cannot delete that file until either my Phase 1.5 commit reverts or a replacement upgrade screen lands.
2. Validate the cap-then-BYOK numbers with parents (Q4 still unanswered — no validation has been done in this thread).
3. If Option C (orthogonal axes) is adopted, the migration path I sketched needs technical review before implementation.

**Items I am NOT a good source for:** parent research / user interviews (Q4); CYOA gating implementation (Phase 2 item not yet scoped).

Cross-coordination flag: my Phase 1 commit is gated on resolving the `lib/subscription_screen.dart` conflict. The other agent who's been working on subscription cleanup may want to coordinate before I commit.
