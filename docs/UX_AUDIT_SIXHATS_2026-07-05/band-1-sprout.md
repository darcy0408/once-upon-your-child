# Six Hats UX Audit — Band 1: Sprout (3–5)

**Date:** 2026-07-05 · **Session:** d9a5-followon · **Environment:** prod (onceuponyourchild.app), fresh anon account, age 4, "Milo", Boy, Brave Hero, Pebble (dragon), Under the Sea, Story Quest.
**Method:** Playwright synthetic-pointer walkthrough, 14 screens captured. Audio not directly observable (see TTS findings — verified in code instead).

**Settled decisions NOT re-flagged:** Boy/Girl-only picker (MT-265 wontfix), Pick-a-Path 2nd-person POV, Robin's cross necklace (memorial).

---

## Developmental frame

Pre-readers. Icons, art, audio carry all meaning; on-screen text is for the parent. Tap targets huge, drag-free, forgiving. Emotional safety = predictability, warmth, never stuck. Wait tolerance ~30s with entertainment.

## Screen-by-screen

### 1. Splash — "STORY WEAVER / Your hero. Your story. / Let's start!"
- **White:** 1 CTA, title, parent-shield. 1 tap to proceed.
- **Red:** Calm, premium, slightly empty — more meditation app than child-magic.
- **Black:** **Brand drift — says "Story Weaver" not "Once Upon YOUR Child"** (L-ALIGN-07). Tab title flips brand after Flutter boot.
- **Yellow:** Single unmissable CTA, zero load, fast.
- **Green:** Drifting sparkles; pulsing CTA; 2s wordless chime + shimmer.
- **Blue:** Complexity **Right**. Playground Test **10/10**.

### 2–3. Name screen (mic-first, type fallback, live name-echo chip)
- **White:** Mic circle, text field, "That's me!" (disabled until input).
- **Red:** Mic-first correct for pre-readers; name-echo chip ("Milo" appears in the yellow bubble as you type) is delightful.
- **Black:** Disabled→enabled state change of "That's me!" too subtle (purple→brighter purple). Browser mic-permission dialog is a scary system UI a child may face alone.
- **Yellow:** Three input paths; short copy; echo chip.
- **Green:** Chip bounce+sparkle when name lands; enabled CTA turns gold.
- **Blue:** **Right**. Playground **8/10**.

### 4. Age gate — circles 3–11, pills 12–14/15–17/18+
- **White:** 12 targets + back; 1 tap.
- **Red:** Friendly, honest.
- **Black:** Parent-directed copy above child-friendly targets; child can self-serve any age (accepted COPPA posture, but the layout invites the child to answer).
- **Yellow:** Target sizes; "Older?" divider = good dual-audience.
- **Green:** Speak the tapped number ("Four!") before advancing.
- **Blue:** **Right**. Playground **9/10**.

### 5–8. Consent chain (hand-off → math gate → COPPA notice → Shape-the-stories offer)
- **Red:** "Time to get a grown-up!" warm, non-punitive; math-gate copy charming; scroll-to-arm checkbox honest.
- **Black:**
  1. **P0 — ElevenLabs "Proud Partner" block in the under-13 consent notice.** Narration is Azure (#277/#278); ElevenLabs is 13+-only by owner decision. The legal disclosure names the wrong vendor to the gated audience. Same drift class as the avatar-vendor drift (consent_disclosure_sync).
  2. **P2 — consent copy says "…would like to use Story Weaver"** (brand drift in a legal doc).
  3. P3 — owner's personal phone as COPPA contact; consider VoIP before scale.
- **Yellow:** Age-stamped notice; "What this means for me" kid accordion; photo-avatar off-by-default; better than most big-name kids' apps.
- **Green:** Vendor block → Azure or de-brand vendors and link the policy vendor table (one list to sync). One brand everywhere.
- **Blue:** **Right** for parents. 10th-Use N/A.

### 9. "Shape the stories" interstitial → Parent Controls
- **White:** Promise "Pick what's been tough and stories will quietly work on it" → Set up now / Maybe later.
- **Black:**
  1. **P1 flow bug (matches owner's 7/05 report):** "Set up now" lands at TOP of generic Parent Controls; the "My child could use some help with…" section is **disabled ("Create a character first") for every brand-new account** — exactly the audience that sees the CTA. Dead end → bounced into child wizard. Parent playground ~2/10.
  2. **P0 — "Unlock Premium Features — Free: Connect a free Google Gemini API key" panel on a child profile** (MT-137: Gemini ToS forbids under-18 apps; runtime gated by #319 but the invitation copy survives). Also appears as "Free with your key / uses your own Google AI key" chip inside the child avatar modal.
- **Green:** Defer-don't-dead-end: put 3 concern chips in the dialog itself; store pending; auto-apply to first character. Kills a nav chain; converts the #1 differentiator at highest intent.
- **Blue:** **Over** (promise → settings → disabled card → different wizard = 4 hops).

### 10–11. Wizard p1: name+gender / avatar modals
- **Red:** Sprout gender art adorable; auto-advance feels alive.
- **Black:**
  1. **P2 — Girl pre-selected by default** (`characterGender` default 'Girl'); no-choice recorded as choice.
  2. **P1 — avatar grid ignored Boy pick: 7 of 8 girl avatars offered** (Boy confirmed selected behind modal).
  3. BYOK chip in child modal (see P0 above).
  4. P3 — name re-asked right after onboarding (pre-filled, mitigated).
- **Yellow:** "Love it already → Use this look" one-tap; Shuffle "150 characters to discover".
- **Green:** Filter/weight avatar pool by gender; drop the default selection; "That's you!" TTS on avatar select.
- **Blue:** **Right** modulo pool bug. Playground **7/10**.

### 12. Archetype — "PICK YOUR ARCHETYPE!"
- **Black:** "Archetype" far above band reading level (printed word serves nobody present; TTS already says a friendlier line).
- **Yellow:** Best-looking screen in the flow (Brave Hero/Art Maker boy variants); 4 big targets.
- **Green:** Print what TTS says: "Who is your hero?"; wiggle on tap-down.
- **Blue:** **Right**. Playground **9/10**.

### 13–14. Buddy + Scene
- **Black:** P3 — abstract empty "+" slot confuses 3–5; scene art is the shared young set (MT-268 tracks Explorer variants).
- **Yellow:** Named buddies with one-line personalities ("Brave hugs and sparkly sneezes"); 2 taps 2 steps; the auto-advance chain is best-in-category pacing.
- **Green:** Buddy tap plays its sound (squeak/chirp) — instant personality, retention loop.
- **Blue:** **Right**. Playground **10/10** both.

### 15. Story type + "Ready to go?" review
- **Black:** **P1 — Superhero + Pick-a-Path (PR #381, merged 7/03) not visible for the age-4 profile** — 3 options, no scroll. Stale deploy or age sub-gate; check `hero_creator_story_type_page.dart`.
- **Yellow:** Review = portraits not words; giant orange GO!; "Pick something new" no-stakes redo.
- **Green:** Spoken summary with icons lighting in sequence.
- **Blue:** **Right**. Playground **10/10**.

### 16. Generation (~60s) + Reader
- **Black:**
  1. **P0 — illustrated hero does not match the chosen avatar** (skin tone, hair, clothes) and **changes appearance between pages** (p1 brown-haired kid → p3 orange-haired kid).
  2. **P0 — buddy in art is a green turtle-creature, not Pebble the purple dragon.**
  3. **P1 — scene mismatch:** picked "Under the Sea!", got crystal-cave story ("The Crystals' New Song") — review screen promised otherwise. Smells like a dropped field (cf. old wizard_data_mapper bug).
  4. P2 — ~60s wait at outer limit for age 4; status lines are unreadable text for pre-readers (only audio-dead moment in the flow).
  5. P3 — p3 onomatopoeia "ZING BOING" double-rendered, one clipped.
- **Yellow:** Sparkle-catcher saves the wait; auto-save ≤5 works ("Loved ✓"); Read to me; onomatopoeia delight rule firing; "New Story with Milo" loop-closer.
- **Green:** (a) TTS status lines (static, prewarmable); (b) anchor illustration prompts on wizard picks (appearance + buddy + scene descriptors in every page prompt — $0 on Flux); (c) verify scene keyword reaches story prompt; (d) curtain-rise reveal when book is ready.
- **Blue:** Reader **Right**; wait **Over** without audio.

## Action Plan (Sprout)

| Priority | Screen | Issue | Change | Effort |
|---|---|---|---|---|
| P0 | Reader | Hero/buddy don't match picks; hero mutates page-to-page | Inject appearance/buddy/scene anchors into illustration prompts | M |
| P0 | Consent | ElevenLabs partner block in under-13 consent | Azure or de-brand vendors, link policy | S |
| P0 | Parent Controls + child avatar modal | Gemini BYOK promo on child profile | Provider-neutral copy or hide under-13 | S |
| P1 | Shape-the-stories | CTA dead-ends (disabled until character exists) | Concern chips in dialog; pending → auto-apply | M |
| P1 | Welcome/PickHero | Robotic first voice (prewarm order + #384 unmerged) | Greetings to top of kWarmUpPhrases; merge #384 | S |
| P1 | Story type | #381 Superhero/Pick-a-Path absent at age 4 | Verify deploy/age-gate | S |
| P1 | Avatar modal | Grid ignores gender pick (7♀/1♂ for Boy) | Filter/weight by characterGender | S |
| P1 | Story gen | Scene pick didn't reach story ("Under the Sea"→crystal cave) | Trace scenario field through mapper | S |
| P2 | Wizard p1 | Girl pre-selected | No default; require tap | S |
| P2 | Generation | Status lines unreadable | Speak them | S |
| P2 | Splash/consent | Brand drift ("Story Weaver") | One brand everywhere | S |
| P2 | Archetype | "ARCHETYPE" vocab | "Who is your hero?" | S |
| P3 | Reader | Onomatopoeia double-render | Dedupe compositing | S |
| P3 | Buddy | Abstract "+" slot | Bouncing "?" star fills with pick | S |

**Simplify:** consent vendor branding → canonical list; duplicate name ask → statement not question; buddy "+" placeholder.
**Combine:** Shape-setup into offer dialog; status text + TTS into one spoken beat.
**Elevate:** buddy sounds; spoken age echo; hero-match illustrations (the wow); curtain-rise book reveal.

## Robotic-voice root causes (verified in code)

1. **Automation artifact:** synthetic pointer events set Flutter's interaction flag but don't grant Chrome user activation → warm blob-MP3 blocked → robotic speechSynthesis (not similarly gated) plays. Real taps don't hit this.
2. **Real latent bug:** `_prewarm` is sequential in list order (`app_tts_service.dart:219-273`); welcome greetings sit ~55 phrases deep → not cached until ~20–40s post-load. Fast first tap beats the cache → cold synth → robotic. **Fix: move greeting block to top of kWarmUpPhrases.** Also merge PR #384 (Pick-Hero greeting).
