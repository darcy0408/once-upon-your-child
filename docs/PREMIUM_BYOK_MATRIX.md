# Premium vs. BYOK Feature Matrix

**Purpose.** Decide what to lock behind paid Premium ($9.99/mo or $19.99/mo Family), what to allow on BYOK (user brings their own free Gemini key), and what stays on Free. Coordination doc for multiple Claude agents working with Darcy.

**Last updated:** 2026-05-10 by session 3240
**Status:** Draft — initial audit + framing. Awaiting input from parallel agent on monetization strategy.

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

### [open] Should BYOK be its own tier or a modifier on Free?

Two cleanups:
- **Option A**: Add `SubscriptionTier.byok` to `subscription_models.dart`, give it its own `TierLimits.forTier()`. BYOK becomes a real tier with its own feature matrix (e.g. unlimited stories, but capped illustrations).
- **Option B**: Keep BYOK as a SharedPref boolean modifier. Treat free + BYOK as "free with own key." Paid Premium is the only first-class non-free tier.

Trade-off: Option A is cleaner code, easier to message ("BYOK tier vs Premium tier"). Option B is less disruptive — current code mostly works.

### [open] What's the headline value prop for paid Premium?

Darcy's lean: custom character images. Validate by mocking the upgrade screen with that as the lead and checking with parents.

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

### [open] Free tier — does it need any custom-avatar exposure at all?

Today free tier sees the upsell banner ("Create a custom avatar that looks like me!") but can't actually do it. Is that the right balance — show the feature exists to drive curiosity, or hide it entirely to reduce frustration?

### [open] Discoverability of paid Premium today

There's no obvious "Upgrade to Premium" entry point in the kid-facing flows. `subscription_management_screen.dart` exists but isn't surfaced to parents during normal play. Where should the upgrade CTA live? Story result screen end card? Parent Controls? Both?

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

---

## Decision log

(Append decisions here as they're made. Format: `### [decided] YYYY-MM-DD — Title` with rationale + who decided.)

_None yet._

---

## Cross-agent handoff log

(Each agent appends a short summary when handing off. Don't edit prior entries.)

### [3240 2026-05-10] Initial draft

Audited current code, drafted strategic framing per Darcy's "custom character images = paid hook" hypothesis. Did NOT make any decisions or change code. Open questions ready for the parallel agent who's been working with Darcy on premium/BYOK strategy.

**Specifically I'd like the parallel agent to weigh in on:**

1. The "should BYOK be its own tier" question (Option A vs B above). What were you discussing with Darcy on this?
2. Whether you have specific paid-Premium feature recommendations beyond custom avatars.
3. Whether you've already validated any of these hypotheses with parent users.
4. If you've committed any related code changes I should know about, link them here.
