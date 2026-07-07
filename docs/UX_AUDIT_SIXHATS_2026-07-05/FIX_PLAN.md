# UX Audit 2026-07-05 — Consolidated Fix Plan

Source: Six Hats screen-by-screen audit of prod (onceuponyourchild.app), all 5 bands, fresh accounts, full create-story loop each. Band reports: `band-1-sprout.md` … `band-5-adolescent.md`.

**Sequenced into PR-sized chunks (Darcy-preferred). Effort: S < ~1h, M = one session, L = multi-session.**

---

## Chunk A — Compliance & trust copy (P0, all S, one PR + one owner pass)

| # | Fix | Where | Notes |
|---|-----|-------|-------|
| A1 | **Remove/replace the ElevenLabs "Proud Partner" block in the under-13 consent notice** | `parental_consent_screen.dart` (vendor section) | Narration is Azure (#277/#278); ElevenLabs is 13+-only. Cleanest: de-brand vendors in consent entirely and link the PRIVACY_POLICY vendor table (one list to sync — see [[consent_disclosure_sync]]). |
| A2 | **Kill Gemini-BYOK promo copy on child profiles** | Parent Controls "Unlock Premium Features — Free" panel + child avatar modal "Free with your key / uses your own Google AI key" chip | MT-137: Gemini ToS forbids under-18 apps. Runtime is gated (#319) but the invitation copy survives. Rewrite provider-neutral or hide for under-13 profiles. |
| A3 | **One brand everywhere** | Splash title ("STORY WEAVER"), boot tab-title flip, consent copy ("…would like to use Story Weaver") | L-ALIGN-07. Customer-facing = "Once Upon YOUR Child". |
| A4 | Verify **Share** action gating for minor accounts | Reader bottom bar (Adventurer+) | What does Share do on an under-13 / 15–17 account? Gate or scope it. |

## Chunk B — The story-type mapping bug (P0/P1, one PR)

One root cause, three symptoms observed:
- Explorer: picked "Story Quest" → review says "Picture tale" → reader renders picture-book-style (text buried below inner fold).
- Adventurer: same "Picture tale" label, text renders fine (cosmetic).
- Creator: "Format: Illustrated story" silent default — likely the same underlying default.

**Fix:** trace the story-type selection → `wizard_data_mapper` / review-summary label → backend format param. Ensure the picked tile actually sets the mode + label per band. Add a regression test: each band's 4 story-type picks map to 4 distinct backend modes.

## Chunk C — Illustration identity & fidelity (P0, M, the "wow" fix)

**Status (a493, 2026-07-07):** C1 partial + C3 done via PR #389 (merged `dd9f0645`) — see `backend/services/image_prompt_helpers.py` (`ILLUSTRATION_STYLE_BY_BAND`, `build_companion_visuals`, `TEXTLESS_ART_RULE`). Companion color/description now threaded (Pebble/Ember-never-render root cause), 5-band style map, textless rule, hero age always stated. C1's persistent per-character appearance anchor (seed-lock / stored string) and C2/C4 are still open.

| # | Fix | Notes |
|---|-----|-------|
| C1 | **Anchor illustration prompts on wizard picks** — skin tone/hair/outfit (from chosen avatar), companion species+color, scene | ~~Sprout run: dark-skinned curly-hair boy in blue hoodie → art showed two light-skinned kids; Pebble (purple dragon) → green turtle;~~ companion color/species now threaded (PR #389). Hero still mutates page-to-page — no stored per-character "appearance anchor" or seed-lock yet. Explorer: 3 different heroes in 3 pages — unresolved. |
| C2 | **Verify scene/scenario reaches the story prompt** | Sprout: picked "Under the Sea!", got a crystal-cave story. Same dropped-field family as the old `_mapArchetypeToDetails` bug. (Explorer/Adventurer honored the pick — check the Sprout path specifically.) Not touched by PR #389 (story-prompt bug, not illustration-prompt). |
| C3 | ~~Add the **textless-art rule** to story-illustration prompts~~ **DONE (PR #389)** | Creator cover rendered gibberish signage ("HORTIDIN'S SAIP BAKERY"). `TEXTLESS_ART_RULE` now placed early in every Flux prompt; live-verified blank billboards in a rain-soaked-rooftop test render. |
| C4 | Dedupe onomatopoeia compositing | Sprout p3 rendered "ZING BOING" twice, one clipped. Not touched by PR #389 (text-rendering/compositing bug, not illustration prompt). |

## Chunk D — TTS warmth (P1, S, one PR + merge #384)

| # | Fix | Notes |
|---|-----|-------|
| D1 | **Move welcome-screen greeting block to the TOP of `kWarmUpPhrases`** | `_prewarm` is sequential (`app_tts_service.dart:219-273`); greetings sit ~55 deep → not cached for ~20–40s → fast first tap = robotic. The list already has a HIGH-PRIORITY section. |
| D2 | **Merge PR #384** (name-agnostic Pick-Hero greeting) | Already open; fixes the consent-CTA → Pick Hero robotic voice. |
| D3 | Speak the generation status lines for Sprout | Static strings, prewarmable; the ~60s wait is the only audio-dead moment for pre-readers. |
| D4 | (Later) Sprout page-1 greeting has the same name-interpolation pattern | Noted in MT-325; different content shape. |

## Chunk E — "Shape the stories" onboarding dead end (P1, M)

"Set up now" (post-consent) → lands at TOP of Parent Controls → target section disabled ("Create a character first") for 100% of new consenting parents → bounced into child wizard (Darcy hit this on 2026-07-05).
**Fix:** put 3–5 concern chips (bedtime worry / big feelings / sharing / listening / 'no') directly in the offer dialog; store as pending prefs; auto-apply to the first character created. Fallback smaller fix: deep-link "Set up now" to the section AND replace the disabled state with the same pending-selection UI.

## Chunk F — Wizard navigation & selection polish (P1/P2, one PR)

| # | Fix | Notes |
|---|-----|-------|
| F1 | **Sticky "Next →" pill appears on selection** (team + scene pages, Explorer/Adventurer) | Next currently below the fold; a 7yo doesn't scroll. |
| F2 | **No default gender selection** (all bands) | Girl is pre-selected everywhere; identity should require the tap. `hero_creator_step.dart:215-216` default + card states. |
| F3 | **Deterministic gender weighting in avatar pool** (≥6/8 match pick) | Observed 7♀/1♂ for a Boy pick (worst case), 5♂/3♀ another run — high variance. |
| F4 | Hide "Add from Photo" when parent photo toggle is off | Child taps into a dead end. |
| F5 | Wish tiles (Explorer p4) render as near-empty purple slabs | Missing art; compact to chips or add art. |
| F6 | "PICK YOUR ARCHETYPE!" → "Who is your hero?" (Sprout/Explorer) | Print what the TTS says; vocab fits band. |

## Chunk G — Scene-picker band art (P1, M, partially owner/Imagen-blocked)

- **Adventurer regression:** setting picker serves the kawaii-bunny shared art despite PR #243's `scenarios/adventurer/` set — verify the code path (`hero_creator_scene_page.dart:113` switch vs whatever page the 4-step wizard actually uses) and re-wire. Possibly the subtraction sprint (#367) or an earlier refactor orphaned it. Code-first: the art may already exist!
- **Explorer/Sprout sets** (MT-268): still blocked on Imagen generation (owner). Code is a 2-case switch once art exists.
- "Imagine It" tile: band-neutral art variants (currently pink-pastel young-girl-coded for everyone).

## Chunk H — Mature-band cohesion (P2, one PR)

| # | Fix | Notes |
|---|-----|-------|
| H1 | **Creator gender cards: identical girl image + transparency checkerboard** | Regression vs #312 (MT-304 item 2 fails device-verify). Check `gender_creator_boy.webp` contents + compositing background. |
| H2 | Adolescent gender cards near-indistinguishable at size | Re-crop/brighten. |
| H3 | Band-aware consent tone for 12–14 ("Time to get a grown-up!" → "A parent or guardian needs to approve this account") | Legal path stays identical. |
| H4 | Band-toned generation copy ≥12 ("Drafting…" not "Something magical…"; hide/reskin sparkle-catcher ≥15) | |
| H5 | Archetype display-name drift (Kinetic Specialist→Lightning Runner; Ecological→Animal Whisperer) | Single source for display names. |
| H6 | Reader: inner-scroll affordance (fade/chevron at page-card bottom) — P1-severity at Explorer, P2 elsewhere | Explorer kids won't discover the text at all. |
| H7 | Title-case consistency (Creator title rendered lowercase) | |
| H8 | Romance genre chip at 9–11 → "Friendship" (align with #249) | |
| H9 | Rockin' Robin tonal drift at 9+ (MT-281) — art/name only; NEVER remove Robin's cross necklace ([[robin_companion_memorial]]) | |

## Chunk I — Verify-only items (S, no code until confirmed)

1. **#381 Superhero/Pick-a-Path absent from the Sprout story picker on prod** (age-4 profile, 3 options only) — stale CF Pages deploy or age sub-gate? Check `hero_creator_story_type_page.dart` + deploy hash.
2. Explorer "Sing, Little Crystal": confirm text pages exist below the inner fold (revise band-2 P0 accordingly).
3. Where Superhero Mode surfaces for Explorer (Phase 6 extension) — not visible on the story-style page.
4. MT-304's remaining device-verify items — this audit COVERS #312 (FAILED, see H1) and #314 (PASSED, Ecological Whisperer art distinct).

## Explicitly NOT flagged (settled owner decisions)
- Boy/Girl-only picker (MT-265 wontfix), Pick-a-Path 2nd-person POV (<15), Robin's cross necklace (memorial), antihero band gated off (MT-266c pending).

## Delight & competitive positioning (from the audit, per band)
- **Sprout:** hero-match illustrations (C1) is the single biggest "whoa"; buddy sounds on tap; spoken age-gate echo; curtain-rise book reveal.
- **Explorer:** read-along karaoke highlight as default text mode; collectible buddy badges ("Ember's 5th adventure!").
- **Adventurer:** the character-sheet/mission review is the app's best screen — extend to a persistent hero-card gallery + saga issue numbering; stackable genre twists.
- **Creator:** echo the desire field in the pitch; parent-gated PDF export ("published work" pride loop).
- **Adolescent:** noir issue-credits wait screen (reskin of existing continuity data) once MT-266c clears.
- **vs. StoryBird/Oscar Stories:** the moat is therapy-informed parent steering — which is why Chunk E (the broken Shape-the-stories hand-off) matters beyond UX.

## Suggested execution order
1. **Chunk A** (compliance copy — small, high-stakes) + merge #384 (D2)
2. **Chunk B** (story-type mapping — one root, three bands)
3. **Chunk D** (TTS warmth D1/D3)
4. **Chunk C** (illustration anchoring — the wow)
5. **Chunk F** (wizard polish)
6. **Chunk E** (Shape-the-stories chips)
7. **Chunk G/H** (art + cohesion; G partially owner-blocked)
8. **Chunk I** verifications woven in wherever touching the same files.
