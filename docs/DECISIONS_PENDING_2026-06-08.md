# Pending Decisions — prepped 2026-06-08

> **✅ DECISIONS MADE 2026-06-08 (all per recommendation):**
> - **MT-079** → Launch **Premium-only $9.99/mo** v1; defer Family. Unblocks MT-078 (Stripe product setup — owner-only).
> - **MT-234** → Horror→**Spooky**, delete **Dystopia** chip. *(PR in flight)*
> - **MT-051** → Build the rotating **"✨ Try this!" spotlight** badge (Explorer only). *(PR in flight)*
> - **MT-184** → Fix the eval **rubric** (mode-aware LTR), keep the product. *(PR in flight)*
> - **MT-215** → Keep photo-avatar **1-free**; server-side funnel instrumentation = separate follow-up PR (not blocking).
> - **MT-210** → Keep superhero portrait **premium-only**; close as decided.
> - **MT-142** → Coarse **flat-16-for-EU** consent age; **post-launch**, gate before EU marketing.
> - **MT-137** → **Launch-gate**; research the Vertex AI / enterprise-terms fix. *(research in flight)*
> - **MT-172** → Keep **"Once Upon YOUR Child"** customer-facing; retire "Story Weaver" from user-visible (splash+title done, #259); IP counsel before store listing.
>
> Detail/rationale for each is preserved below.



One-tap recommendations so you can clear the DECISION-gated backlog fast. Each has a recommended answer; reply **yes** to take it, or override. I'll implement/close on your word.

## TL;DR checklist

- [ ] **MT-234** — Rename "👻 Horror" → "👻 Spooky", delete "🏚️ Dystopia" chip (Creator 13–14 brief)
- [ ] **MT-051** — Add a rotating "✨ Try this!" spotlight badge on Pick-a-Path / Rhyme Time orbs for Explorer (no unlock infra)
- [ ] **MT-215** — Keep photo-avatar at 1-free (no code change); the server-side funnel instrumentation is genuinely unbuilt → schedule as its own PR
- [ ] **MT-210** — Keep superhero portrait **premium-only** (no change); close as decided
- [ ] **MT-079** — Launch **Premium-only $9.99/mo** for v1; defer Family tier → unblocks MT-078 (Stripe setup)
- [ ] **MT-184** — Fix the eval rubric, not the product: make `age_band_fit` mode-aware for 13+ LTR (Hi-Lo)
- [ ] **MT-142** — Coarse flat-16-for-EU consent age via `CF-IPCountry`; post-launch, not a blocker
- [ ] 🚨 **MT-137** — **Gemini API terms forbid under-18-directed apps** (contractual launch blocker, not a setting). Keep OpenRouter logging OFF; Cloudflare/ElevenLabs clean; Replicate watch
- [ ] **MT-172** — Keep "Once Upon YOUR Child" customer-facing; retire "Story Weaver" from anything user-visible; counsel runs the real USPTO pull before store listing

---

## Product / Content

### MT-234 — Horror + Dystopia chips on the Creator (13–14) creative brief
**Recommendation:** Rename "👻 Horror" → "👻 Spooky"; remove "🏚️ Dystopia" entirely.
**Why:** Chips only show for the Creator band (age 13+, not 12+ as the title implied). Genre is passed to the backend as a free-text hint with **no horror-specific safety tuning**, so "Horror" is pure store-rating/screenshot liability for a Families-positioned app with zero creative cost — the sibling story-type picker already uses "👻 Spooky". Dystopia adds little for a 13–14yo and skews tone bleak.
**Exact change if approved:** `lib/screens/wizard_steps/hero_creator_creative_brief.dart` — line ~744 label `'👻 Horror'`→`'👻 Spooky'` + value `'horror'`→`'spooky'` (and the two value comparisons ~748–749); delete the `GenreChip('🏚️ Dystopia', value:'dystopia')` block ~772–782 (no other refs).
**Confidence:** High.

### MT-051 — Story-type discovery for Explorer (6–8), Page 6
**Recommendation:** Add a rotating "✨ Try this!" spotlight badge highlighting ONE high-value mode per session (alternating Pick-a-Path ↔ Rhyme Time). Do **not** build progressive-unlock.
**Why:** Explorer already shows all modes as equal-weight orbs — they're undifferentiated, not missing, so the fix is salience, not unlocking. Unlock/celebration needs per-child persistence the codebase doesn't have; a spotlight reuses the orb's existing top-right badge slot, costs no persistence, and never blocks a kid. Sprout stays untouched.
**Exact change if approved:** `lib/widgets/image_mode_orb.dart` — add optional `bool spotlight`, render a pill in the existing `Positioned(top:6,right:6)` slot when `spotlight && !isActive`. `lib/screens/wizard_steps/hero_creator_story_type_page.dart` — compute a rotation flag, pass `spotlight:` to the Rhyme Time (~:527) and Pick-a-Path (~:549) orbs, gated to `AgeBand.explorer`.
**Confidence:** Medium-High (build is mechanical; product lift worth observing after).

### MT-184 — "Learning to Read" approach for ages 13+
**Recommendation:** Fix the **eval rubric**, keep the product. The `d7a434c7` decodable-prose routing for 13+ LTR is already the correct Hi-Lo (struggling-reader/ESL) behavior; the only "failure" is the judge rubric penalizing intentionally-simpler-than-age text.
**Why:** Options (B) Hi-Lo refinement gold-plates a branch that already reads competently; (C) UI-restriction throws away the one legitimate teen/adult use case. Cheapest correct move is fixing the measurement.
**Exact change if approved:** `backend/eval/rubrics.py` — make `AGE_BAND_FIT.judge_prompt` mode-aware (when `mode==LTR`, score "appropriate Hi-Lo decodable text for someone this age *learning to read*" vs "pitch-perfect for age"); bump `RUBRIC_VERSION`→1.1; free retest.
**Launch-blocking?** No. **Confidence:** High.

---

## Monetization

### MT-215 — Photo-avatar paywall (1-free vs premium-only)
**Recommendation:** Keep **1-free** (decision already recorded; no code change — gate is live & correct at `backend/routes/avatar_routes.py:356-403`). BUT the remaining action — server-side funnel instrumentation — is **genuinely unbuilt** (no `analytics_events` table, no event sink). Don't quietly skip it; schedule as its own attended PR.
**Exact change if approved:** Separate ~1–2hr PR: add `analytics_events` table + migration, `record_event()` helper, emit `avatar_limit_hit` at the 403 branch (`:362`) + wire Flutter `paywall_viewed` → new `/analytics/event`. The gate itself ships nothing.
**Confidence:** High.

### MT-210 — Superhero portrait paywall
**Recommendation:** No change — keep `/avatar/transform-superhero` **premium-only** (`@require_premium`) for v1. Close as decided.
**Why:** It's a re-render of an avatar the child already has — not the first "see-yourself-as-a-hero" magic moment (that's already delivered free by the photo-avatar). Matches the pet-avatar precedent; a second free metered portrait needs the same analytics infra MT-215 is blocked on, for marginal upside. Revisit only if data shows superhero entry is a top free drop-off.
**Confidence:** Medium-High.

### MT-079 — v1 launch tier set → unblocks Stripe setup (MT-078)
**Recommendation:** Launch **Premium-only $9.99/mo** for v1; defer the Family tier.
**Why:** All three matrix agents + the Decision Log converge here. Single tier = simpler UX, smaller risk, real conversion data before betting on a second tier. Family economics are shaky (above the kids'-content comp ceiling; a likely Gemini image-price bump flips Family to a per-user loss at the cap). Free/BYOK remain the on-ramp.
**Exact change if approved:** Log `[decided] Premium-only v1` in `docs/PREMIUM_BYOK_MATRIX.md`, then unblock MT-078: create only the Premium $9.99 product in Stripe Test, set `STRIPE_PRICE_ID_PREMIUM` + `STRIPE_WEBHOOK_SECRET` on Railway (skip Family), land the `is_paid_premium` SharedPref fix before smoke test.
**Confidence:** High. **This single yes unblocks the whole Stripe lane.**

---

## Compliance

### MT-142 — Jurisdiction-aware consent age
**Recommendation:** Coarse **flat-16-for-EU** behind `CF-IPCountry` (NOT precise geo-IP, NOT a country selector kids can lie through). Post-launch; gate before any EU marketing push.
**Why:** Threshold is hardcoded `<13` in 3 places; a 14–15yo in a 16-threshold EU state currently wrongly self-attests. Risk is near-zero today (no EU marketing), which is why it was already deferred. A coarse EU→16 rule is the smallest defensible fix.
**Exact change if approved:** Replace the magic `13` with a `consent_age_threshold(request)` helper (CF-IPCountry → 16 for EU members, else 13) in `backend/routes/user_routes.py` + `backend/middleware/auth.py`; mirror in `parental_consent_screen.dart`.
**Launch-blocking?** No. **Confidence:** High.

---

## External Research (decision-prep — not legal advice)

### 🚨 MT-137 — Third-party AI provider child-data terms
**Headline finding (NEW, high-priority):** Google's **Gemini API Additional Terms** state you "will not use the Services as part of a website, application, or other service that is directed towards or is likely to be accessed by individuals under the age of 18." A therapeutic kids' app is squarely that. **This is a *contractual* block independent of retention/training — even paid no-train + Zero-Data-Retention doesn't cure it.** Gemini is the primary story + image provider today. This belongs on the MT-135/launch checklist as a blocker; the fix is either a Vertex AI / enterprise path with child-permissible terms, or routing child-data calls to a provider whose terms allow it.

| Provider | Trains on input (default)? | Zero-retention option | Terms vs. child-directed use | Verdict |
|---|---|---|---|---|
| **Google Gemini API** | No (paid) / Yes (free tier) | Yes (ZDR mode) | ❌ **Prohibits under-18-directed apps** | 🚨 **Contractual blocker** |
| **OpenRouter** | No (default ZDR) | Yes (account ZDR) | No child clause | ⚠️ Keep logging **OFF** + ZDR **ON** (tracked in MT-173, re-verify pre-launch) |
| **Cloudflare Workers AI** | **No** (blanket default) | Contractual | No child clause | ✅ Cleanest |
| **ElevenLabs** | No | Yes (Zero-Retention Mode, `enable_logging=false`) + DPA | No child clause | ✅ Clean w/ ZRM |
| **Replicate** | No (its own models); §5.2 licenses customer-requested fine-tunes only | 1-hour default deletion | 18+/under-16 disclaimer → **you carry COPPA** | ⚠️ Watch; no formal DPA for child photos |

**Action:** (1) Surface the Gemini under-18 clause as a launch blocker now; decide Vertex/enterprise vs. provider reroute. (2) Re-verify OpenRouter logging OFF + ZDR ON. (3) Confirm child-data sub-processors are all disclosed in PRIVACY_POLICY.md. **Confidence:** High on the Gemini clause (quoted from the live terms); other rows sourced from each provider's current policy.

### MT-172 — Trademark collision ("Story Weaver" / "Once Upon YOUR Child")
**Recommendation:** Proceed with **"Once Upon YOUR Child"** as the sole customer-facing brand; **retire "Story Weaver" from everything user-visible** (UI, store listings, marketing, LinkedIn) — confine it to internal/technical use only (aligns with the L-ALIGN-07 string-drift cleanup). Engage IP counsel before any store listing.
**Why:** "Story Weaver" is severely crowded in the *exact* vertical — Pratham Books' StoryWeaver (est. 2015, UN Digital Public Good, children's reading, used in the US) plus ≥4 other active software products including an AI interactive-fiction generator (storyweaver.art). Customer-facing risk = **HIGH**; internal-only = Low–Medium. "Once Upon YOUR Child" is distinctive (the possessive "YOUR" differentiates it from the crowded "Once Upon…" field) → Low–Medium, likely clearable.
**Caveat:** The agent could **not** pull live USPTO/IP-India registration records (their search apps block crawlers) — treat as decision-prep, not clearance. Counsel must run the real TSDR/TESS + IP-India pull on "Once Upon YOUR Child" in Classes 9/41/42 and confirm Pratham's registration scope.
**Launch-blocking?** Counsel clearance is the standing MT-172 launch gate. **Confidence:** High on the crowding/risk direction; registration specifics unverified by design.

---

## 🚨🚨 MT-137 — DEEP RESEARCH UPDATE (2026-06-08) — provider path

**This corrects the earlier "use Vertex / Cloudflare+ElevenLabs" guidance. Two big changes:**

1. **Vertex AI does NOT clear the blocker.** The same "directed towards or likely accessed by individuals under the age of 18" prohibition is in Google Cloud's **Service Specific Terms** (Generative AI Services → Age Restrictions), materially identical to the Developer-API clause. Migrating Gemini → Vertex is **dead on arrival**. No public Google consumer path permits child-directed Gemini use — only **Workspace for Education** (managed school accounts), which doesn't transfer to a B2C app. An enterprise/DPA waiver of the *audience* restriction is **unverified and unlikely** (data settings ≠ audience restriction). *Caveat: the live GCP terms page wouldn't fully render to the research tool — clause confirmed via 3 search indices + a Google dev-forum answer; **eyeball the live "Generative AI Services → Age Restrictions" subsection yourself before final sign-off.***

2. **ElevenLabs is a SECOND blocker.** Its Prohibited Use Policy bars "bundled solutions that **target anyone under the age of 13**" — i.e. your 3–12 core demographic. The earlier "ElevenLabs clean" read was wrong. Must **replace ElevenLabs for under-13 TTS**, or restrict it to verified-consent 13–18 only.

**Who's clean:** ✅ **Cloudflare Workers AI** (your default illustration provider) has no under-18 end-user restriction — keep it.

**The fix — providers that *permit minors with safeguards*** (vs. Gemini/ElevenLabs' hard audience ban):
| Provider | Stance | Source |
|---|---|---|
| **Anthropic Claude API** | **Permitted** — terms expressly contemplate "products for minors" with safeguards (age verification, content moderation, child-safety system prompt, COPPA, AI-disclosure). *(API, not claude.ai consumer which is 18+.)* | support.claude.com "Organizations Serving Minors" |
| **OpenAI API** | Permitted **with Zero Data Retention** mandatory before processing under-13 data | OpenAI Under-18 API Guidance |

**Recommended path:**
1. **Route story-TEXT off Gemini → Anthropic Claude API** (cleanest fit; terms explicitly sanction serving minors with safeguards you largely already have for COPPA).
2. **Keep Cloudflare Workers AI for illustrations** (already compliant + default).
3. **Replace or consent-gate ElevenLabs TTS** (independent second launch-gate for under-13).
4. **Fallback for text:** OpenAI with ZDR enabled.
5. **Drop the Vertex migration idea** entirely.

**Effort:** swap the text-gen client + wire the safeguards checklist (Medium); TTS replacement needs a child-permissible vendor vetted separately (not yet cleared). **These spawn new launch-gate work items.**
