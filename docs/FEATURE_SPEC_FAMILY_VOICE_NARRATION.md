# Feature Spec — Family Voice Narration ("read by someone who loves you")

**Status:** PARKED — owner decision 2026-07-15. Do not build, scope, or re-pitch; see the decision note below.
**Date:** 2026-07-14 · **Origin:** owner request following `docs/COMPETITIVE_PRODUCT_AUDIT_2026-07-14.md` (StoryBee's parent voice-cloning flagged as the strongest "they have, we lack" feature).
**Explicit non-goal:** this does NOT gate the current launch. It is a post-launch differentiator.

---

> ## PARKED — owner decision, 2026-07-15
>
> The **entire plan is on the backburner indefinitely**, including the P0.5
> "Voice Dedications" stepping stone. The deciding concern, in the owner's
> words: **"I don't like the idea of parents feeling like we are putting words
> into their mouth."**
>
> The concern is sharpest exactly where this product is most differentiated:
> the stories are app-generated and often *therapeutic-adjacent* (Big
> Feelings, boundary-setting, guidance registers). A cloned family voice makes
> app-authored words sound personally spoken — for a young child, "the app
> said it" and "Mom said it" must never blur, and this feature blurs it by
> design. No consent screen fixes that; it is a product-identity objection,
> not a compliance gap.
>
> **For future sessions:** the research below (vendor landscape, BIPA/COPPA
> analysis, pricing, phasing) is preserved so it never needs redoing, but
> treat this feature as declined unless the owner re-raises it themselves.
> Note for any future revisit: P0.5 dedications use the family member's OWN
> recorded words (no cloning, no authored-words problem), so it would be the
> only defensible re-entry point — but as of this decision it is parked with
> everything else.

---

## 1. What it is

An adult family member records ~2–3 minutes of guided reading; the backend creates a private cloned narration voice; the child's stories can then be read aloud in that voice.

Target moments (owner's framing):
- **Faraway grandparents** — "Grandma reads you a bedtime story from three states away."
- **Deployed military parents** — a parent's voice at bedtime through a long deployment.
- **Memorial voices** — a recording that outlives someone (Phase 3 only; see §3.5 and §6).
- Plus the mundane majority case: a parent who works nights.

Why it wins: no competitor pairs voice-family narration with feelings-personalized stories. StoryBee has cloning but no SEL layer; Moshi/Slumberkins have human narration but zero personalization. Emotionally, this converts narration from a feature into the reason a family subscribes — and the **grandparent is a buyer, not just a user** (gift-subscription loop, §7).

## 2. Hard rules (non-negotiable, set before any code)

1. **A child's voice is NEVER cloned.** Enrollment is adult-only: 18+ attestation + consent statement recorded in the enrollee's own voice. (Consistent with our deleted child-voice STT posture.)
2. **The voice owner consents personally.** Enrollment captures a recorded verbal consent statement spoken by the voice owner, plus email verification sent to the voice owner themselves. An account holder cannot enroll someone else's voice from saved audio — that door stays closed (it is also the abuse/impersonation vector).
3. **Family voices are private to the account.** Never surfaced in the public voice picker, never shareable across accounts.
4. **Deletion cascade extends to voice profiles.** Account deletion purges the vendor-side voice model (verified via vendor deletion API), the consent recording, and cached narration audio. Voice data gets its own row in the published retention policy (sequence with v3 policy publication — COPPA memo F-5).
5. **Memorial voices are Phase 3 and owner-gated.** The clean path is enrollment-while-alive ("legacy recording"). An upload-from-old-recordings path for someone already deceased requires estate/next-of-kin authorization and its own legal review — parked until then.

## 3. UX flows

**3.1 In-app enrollment (P1).** Parent settings → "Family Voices" → guided script (a short Sprout-style story, so the sample matches the product's actual register) → consent statement read aloud → processing → preview on a sample paragraph → name it ("Grandma Jo") → appears in the picker.

**3.2 Remote invite (P2, the growth loop).** Account owner sends a magic link → grandparent records in their phone browser (no install, no account) → owner previews and approves → voice goes live for the child. The grandparent has now touched the product at its emotional peak; the thank-you screen carries the gift-subscription CTA (§7).

**3.3 Child side.** Voice picker gains a "Family" section (heart icon) above the curated voices; bedtime mode can default to a family voice. No other child-facing change.

## 4. Architecture sketch

Slots into the existing narration stack with no new concepts:

- `POST /tts/synthesize` already accepts `voice_id`; `GET /tts/voices` already feeds the picker a curated list. Family voices become per-account entries appended to that list.
- New table `voice_profiles`: `user_id`, `vendor_profile_id`, `display_name`, `consent_record_id` (FK to the existing ConsentRecord pattern — timestamp/IP/method/policy-version, same provability standard as parental consent), `status`, `created_at`.
- Synthesis path: family `voice_id` resolves to the vendor personal-voice id; provider chain otherwise unchanged (Azure is the licensed primary, MT-248). Cache narrated audio per (story, voice) as with stock voices.
- Enrollment service: upload sample + consent clip → vendor profile creation → async status (Celery task, mirrors illustration jobs).
- Kill switch: `FAMILY_VOICE_ENABLED` env flag, default **off**, plus per-account entitlement check (Premium/Family only).

**Vendor (per 2026-07-14 research pass):** see §5. Working recommendation: **Azure Personal Voice first, Resemble AI as the verified fallback** — Azure fits the existing licensed-primary integration and its mandated consent statement matches rule #2 exactly, but its Limited Access page says only "customers managed by Microsoft" account teams are eligible, which may exclude a solo-dev account entirely. Confirming that eligibility is P0 work (§8) before anything else is scoped.

## 5. Vendor comparison (research pass 2026-07-14; source links in PR body)

| | Azure Personal Voice | ElevenLabs | Resemble AI (fallback) |
|---|---|---|---|
| Sample needed | 1 min (training <5 s, 91 languages) | IVC 1–5 min; PVC 30+ min | short sample |
| Access gating | **Limited Access intake + Microsoft approval; page says only Microsoft-account-team customers are eligible — solo-dev eligibility UNVERIFIED, the #1 risk** | IVC: self-serve consent checkbox (weak); PVC: Voice Captcha liveness check but **enterprise-only** | Self-serve; consent-confirmation step built into clone creation |
| Consent mechanism | Mandatory scripted recorded statement ("I [name] am aware… synthetic version of my voice") + speaker-recognition match of consent vs training audio | IVC checkbox only — no identity verification | Consent step + built-in audio **watermarking** (marketed for ELVIS Act / EU AI Act) |
| Existing integration | **Yes — current primary TTS** | Yes (13+ premium voice only) | New vendor |
| Deletion | API deletion of voice + training audio, but Microsoft "may independently retain" model copies for security — must be disclosed in policy | Deletion supported | Deletion supported |
| Pricing (verify before build) | ~$24/1M chars + ~$600/1,000 profiles/mo (secondary source, UNVERIFIED) | Creator $22/mo (100K chars — only ~9 Adventurer stories), Pro $99/mo (500K) | PAYG ~$0.0005/sec audio + $2–5/mo per clone |

Also noted: **Readmio and Novel Effect avoid cloning entirely** (live parent read-aloud + on-device effects, no voice data leaves the device) — the privacy-by-design contrast point, and the inspiration for the P0.5 stepping stone in §8. StoryBee's "Clone My Voice Free" flow shows no visible consent scaffolding, no vendor disclosure, no guardrails — our compliance-first version is both defensible and marketable against it.

## 6. Legal / compliance checklist

- **COPPA (amended 2025):** the rule text explicitly adds voiceprints to "personal information" (biometric identifiers list, Federal Register 2025-05904). Its trigger is data collected **from or about a child under 13**; the enrolled voiceprint is the **adult's**, collected from the adult with the adult's direct consent, and the child's voice is never captured (rule #1) — so this *likely* sits outside COPPA's core trigger, but the research pass flags it as a judgment call the rule text doesn't settle. Treat as a one-page legal memo item, not settled fact. Still required regardless: privacy-policy disclosure of the voice vendor + a voice-data retention row (fold into v3 **before** publication — do not publish v3 twice).
- **Illinois BIPA (740 ILCS 14):** voiceprint is a statutory biometric identifier; private right of action at $1,000/negligent and $5,000/intentional violation with **no injury requirement**. A compliant flow needs (a) a **standalone consent screen** — not a buried ToS checkbox — stating purpose and the retention/destruction schedule *before* collection, and (b) an affirmative e-signed written release (electronic signature suffices since the 2024 SB2979 amendment). Build this as the baseline enrollment UX for **all** states — strictest floor, costs nothing extra.
- **TN ELVIS Act + 2024–26 state voice laws** (AR, WA, CA AB 1836/2602, NY): all restrict **unauthorized** simulation; none block consensual self-enrollment — rule #2's owner-verified consent is the compliance mechanism.
- **Post-mortem publicity rights** exist in 24–38 states (10 years TN → 70 CA → 100 IN/OK), vesting in heirs/estates; a *paid* service narrating in a deceased person's voice is a novel, untested fact pattern. The memorial-upload path (§3.5) stays parked behind legal review with a required heir/estate attestation; enrollment-while-alive avoids the question entirely.
- **Azure retention nuance:** even after customer-initiated deletion, Microsoft states it may independently retain model copies for security/integrity — the privacy policy must say "deleted on request; vendor may retain limited copies for security" rather than promising absolute erasure.
- **Vendor paper:** DPA + deletion SLA + no-training commitment for voice data, same standard as the OpenAI DPA/ZDR work (COPPA memo F-3).
- **Reputational (the Amazon lesson):** Amazon's 2022 demo of Alexa reading in a deceased grandmother's voice drew broad backlash — the framing was the product cloning the dead. Ours inverts it: the *family* records on purpose, while they can. Market the living use cases (grandparents, deployment); let memorial value stay a private discovery, never ad copy.

## 7. Pricing placement & the gifting loop

- **Premium-only**, N=2 family voices included (owner call, §9). The dormant **Family tier** finally gets its anchor feature: more voices + multi-child.
- **Gift loop:** the remote-invite thank-you screen offers "Gift a year of stories" — the `gift` entitlement channel already exists in `apply_entitlement()` (STORE-1), so gifting needs checkout UI, not backend architecture.
- **Unit cost (order-of-magnitude, pricing UNVERIFIED per §5):** at Azure's reported ~$24/1M chars, an Adventurer story (~11K chars) narrates for ~$0.26 and a Sprout story for ~$0.04, cached once per (story, voice); profile storage ~$0.60/profile/mo. Resemble's per-second model prices a 10-minute narration at ~$0.30. Either way: not a margin problem at Premium pricing. ElevenLabs Creator's 100K-char cap (~9 long stories/mo) is too tight to be the primary.
- **Distribution side-effect:** military-family and long-distance-grandparent framing is organic-PR-friendly (military family orgs, deployment support communities) — consistent with the VALIDATION.md finding that distribution, not product, is the bottleneck.

## 8. Phasing

- **P0 (now):** this spec → owner decisions (§9) → **confirm Azure Personal Voice Limited Access eligibility for a non-account-team customer** (the #1 open risk; apply via the intake form and ask the question directly) → verify vendor pricing → privacy-policy v3 additions drafted (so v3 publishes once).
- **P0.5 (optional cheap demand test, zero cloning risk):** "Voice Dedications" — a grandparent records a plain 15-second intro that plays before the story ("This one's for you, Mia — love, Grandma"). No cloning, no biometrics, no vendor gate; ships the emotional core of the remote-invite flow (§3.2) and measures whether families actually use family-voice features before the compliance investment. (Pattern inspired by Readmio/Novel Effect's no-cloning designs.)
- **P1 (MVP):** in-app enrollment, 1 voice, web only, `FAMILY_VOICE_ENABLED=false` default, Premium-gated, BIPA-grade consent screen from day one. Verify: enroll → narrate → delete account → confirm vendor-side purge.
- **P2:** remote grandparent invite + gift CTA.
- **P3:** memorial/legacy program (heir attestation + legal review first, then code; never marketed — the Amazon Alexa 2022 lesson is that positioning, not technology, was the backlash).

## 9. Owner decisions needed

1. Included voice count for Premium (proposal: 2) and whether Family tier revives around this.
2. Gift-subscription pricing (flat year at $59.99?).
3. Memorial path stance: enrollment-while-alive only (proposal), or eventually estate-authorized uploads.
4. Timing: P1 before or after iOS launch (proposal: after — MT-350 store setup stays the critical path).
5. Run the P0.5 "Voice Dedications" demand test first? (proposal: yes — it's small, riskless, and ships the emotional moment while the vendor/legal track runs.)
