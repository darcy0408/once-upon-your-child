# Age-Band Review — "Choose Your Story Type" (Hero Creator, Step 4 "Start Adventure!")

**Band evaluated:** Adventurer (9–11), with the **parent lens weighted first** per request ("go through the 9–11 age band also from a parent's perspective").
**Screen:** Story-type / mode selector — the wizard's final build step. Widget: `HeroStoryTypePage` in `lib/screens/wizard_steps/hero_creator_story_type_page.dart` (Adventurer = the non-Sprout `else` branch, lines 467–552 + genre block 555–640 + `_buildWishTextInput` 303–364).
**Date:** 2026-05-30
**Grounding:** Widget located and read. Genre flow fully traced through `lib/models/wizard_data.dart` → `lib/screens/wizard_steps/wizard_data_mapper.dart` → `ApiServiceManager.generateStory` → `backend/services/story_service.py`. Free-text handling traced to `backend/utils/sanitizer.py`. **Correction (2026-05-30):** an earlier draft of this report claimed the genre chips were a no-op (finding C-01). That was wrong — the genre is wired via `customElements` (`wizard_data_mapper.dart:298–301`) and woven age-safely by the backend (`story_service.py:922`). C-01 is retracted below; the original error came from a code search truncated by the tool's result limit before it reached the mapper. No grounding gap.

---

## Age-Band Check

A 9-year-old sits at the **bottom edge** of Adventurer (9–11). The screen is correctly gated by band: Explorer (6–8) never sees genre chips and gets tappable wish-prompt buttons instead; Sprout gets auto-advancing picture cards. Only Adventurer and Creator see the genre row (`hero_creator_story_type_page.dart:555`) and the free-text wish field. So the *structure* is age-appropriate by design — the questions for a 9-year-old are about **two specific elements**: the maturity of one genre option, and whether the choices on this screen actually do anything.

---

## Three-Lens Walkthrough

### Parent lens (primary)
A parent watching a 9-year-old on this screen sees a clean, well-staged "build your story" step. What they notice:

- **Builds trust immediately:** the genre row is labelled **"(optional)"** — no pressure, nothing pre-selected. The bottom control says **"Next: Review & Launch!"** (`age_band_theme.dart:412`), so the story is *not* generated from this tap — there's a review gate first. The "Story Quest" subtitle even degrades honestly to "An epic adventure" instead of promising "illustrated" when the account can't make pictures (`:480`). No upsell, no urgency, no pre-checked consent, no accidental-purchase trap. This is a dark-pattern-free surface.
- **First thing that gives a parent pause:** their 9-year-old is offered a **"💕 Romance"** genre chip, sitting beside **"👻 Spooky"** (`:626`, `:615`). For a parent of a 9-year-old, "Romance" reads as aimed older than their child and as *not curated by age*. They don't know what it will do — they just see it on offer.
- **Second point (corrected):** an earlier draft flagged the genre chip as doing nothing. That was wrong — the genre *does* reach the story (woven age-safely by the backend), so a child's "Sci-Fi" pick is honoured. This is a net positive for the parent lens: the child's choice is respected *and* age-bounded.
- **Third concern:** the **free-text box + microphone** ("Anything special you want?"). A child can type or *speak* anything. The parent's instinct is "where does what my kid says go, and what stops something bad from coming back?" The reassuring answer exists in code (server-side sanitization, injection screening) but is invisible on the screen.

### Child lens (9-year-old)
- **Notices first:** the two glowing orb cards up top — "Story Quest" / "Rhyme Time" — the brightest, most game-like things.
- **Notices second:** the "Pick a Path — You choose what happens!" card (agency is a strong pull at this age), then the colorful genre chips.
- **Notices third:** the "Anything special you want?" box and the mic.
- **What they tap:** likely "Story Quest" or "Pick a Path", then a genre chip or two, then maybe type a wish. The flow is intuitive for a 9-year-old.
- **Payoff:** they pick "Sci-Fi" and the story leans sci-fi (age-appropriately) — the choice is honoured. Good closure of the action→effect loop this band cares about.

### Psychologist lens
- **Reading level:** "genre" and "twist" are ~grade-4–5 vocabulary; "optional" is fine; "Anything special you want?" is grade-2. Comprehension load is low. Acceptable for the band, slightly leaning on "genre twist" as a known concept.
- **Attention / working memory:** 3 mode orbs + 6 genre chips + 1 text field = ~10 elements, but they're cleanly chunked into three labelled zones ("story style" / "genre twist" / "anything special"), so load stays within Adventurer comfort.
- **Motor precision:** mode orbs are large; **genre chips are not** (see U-01) — ~36–40 px tall, under this band's own 64 px standard.
- **Emotional safety:** neutral and safe. The only content-maturity flag is the Romance option (G-01).

---

## Age-Appropriateness Scorecard

*Frustration risk scored so that **10 = lowest risk**.*

| Category | Score (1–10) | Evidence |
|---|---|---|
| Reading level | 8 | "genre twist (optional)" ~grade 4–5; rest grade 2–3 (`:559`, `:310`). Clear for the band. |
| Visual maturity fit | 7 | Orb cards + dark palette suit upper Adventurer well; the **Romance** chip skews older than a 9-year-old (`:626`). |
| Clarity | 8 | Three zones cleanly labelled; "Next: Review & Launch!" sets correct expectation; genre + free-text choices both reach the story. *(Was 7 — revised up after retracting the false no-op finding.)* |
| Delight | 8 | "Pick a Path" agency + genre play are great hooks for 9–11, and the genre actually shapes the story (woven age-safely). *(Was 6 — the "hollow hook" premise was wrong.)* |
| Frustration risk | 8 | Sub-floor chip tap targets — now fixed (U-01, `minHeight: 44`). *(Was 6 — the "genre ignored" premise was wrong.)* |
| Parent trust | 8 | Strong fundamentals (optional, review gate, sanitized input, no dark patterns); the one maturity flag (Romance) addressed via the Friendship reframe. *(Was 7.)* |
| **Overall age fit** | **8** | Structurally right for the band; genre/free-text honoured and age-clamped; tap target and Romance both addressed. *(Was 7.)* |

---

## Band-Shift Check

- **One younger — Explorer (6–8):** the code already *prevents* this version from showing — Explorer gets wish-prompt buttons and **no genre chips** (`:641`). Good gating. If chips *were* shown, "genre/Romance/Sci-Fi" would be too abstract/mature → ~4/10. The screen correctly serves Explorer a gentler variant.
- **One older — Creator (12–14):** the genre chips fit cleanly; "Rhyme Time" becomes "Poetry" at age ≥ 11 (`:497`). Overall ~8–9/10.

**Conclusion:** this screen is aimed correctly at Adventurer. The former mis-aim (a Romance chip whose comfortable home is Creator+) has been addressed by reframing it to Friendship on this screen.

---

## Too Advanced or Too Babyish

**Too advanced for a 9-year-old**
- ~~"💕 Romance" genre chip~~ — **resolved.** The chip is now "💛 Friendship"; the other five (Mystery, Comedy, Sci-Fi, Action, Spooky) are squarely in-band. No remaining too-advanced element on this screen.

**Too babyish:** nothing. The orb/chip treatment reads age-appropriate, not childish.

---

## Confusion & Frustration

| ID | Title | Lens | Severity | Element | Issue | Recommendation | Autonomous? | Effort |
|---|---|---|---|---|---|---|---|---|
| ~~C-01~~ | ~~Genre chips are a no-op~~ — **RETRACTED, false** | — | — | — | **Correction (2026-05-30):** the original finding was wrong. The genre IS wired: `WizardDataMapper.mapToStoryRequest` folds `'Genre: <value>'` into `customElements` (`wizard_data_mapper.dart:298–301`), and the backend weaves it age-safely (`story_service.py:922` — "Incorporate the spirit… age-appropriate and safe"). The original "no-op" call came from a `selectedGenre` search truncated by the tool's result limit *before* it reached the mapper. No action needed; the feature works. | — | — | — |
| G-01 | "Romance" offered to a 9-year-old | Parent | Medium | `GenreChip '💕 Romance'` (`:626`) | Reads as aimed older than the band's 9-year-old edge; parent sees it as un-curated. Now that genre actually flows to the model, the chip also nudges romance themes (age-clamped, but still surfaced). | **DONE (2026-05-30):** reframed the chip to **"💛 Friendship"** (`value: 'friendship'`) on this Adventurer/Creator-shared screen. Romance remains on the Creator-only creative-brief screen. | **Y** (actioned) | S |
| U-01 | Genre chips below tap-target floor | Child, Psych | Medium | `GenreChip` padding (`genre_chip.dart:24`) | `padding: 16h/10v` with no `minHeight` → ~36–40 px tall, under the 44–48 px norm and well under this band's own `touchTargetMin: 64` (`age_band_theme.dart:391`). | **DONE (2026-05-30):** added `constraints: BoxConstraints(minHeight: 44)` + `alignment: center` to `GenreChip`. | **Y** (actioned) | S |
| C-02 | Mic/free-text has no visible safety/privacy cue | Parent | Low | `_buildWishTextInput` mic + field | Real protection exists server-side (sanitizer: caps, `[USER_INPUT]` wrap, injection screening) but the parent couldn't see it. **STT path confirmed:** `speech_to_text` with no `onDevice` flag → on web/Chrome the browser streams audio to Google's cloud, *not* on-device. | **DONE (2026-05-30):** added a persistent reassurance line — *"We don't keep your voice — only the words, and we check those to keep things safe."* Phrased to be truthful on every platform (no on-device claim). **Follow-up (doc, not code):** privacy policy should disclose third-party (browser/OS) speech processing. | **Y** (actioned) | S |

---

## Layout & Usability

- **Tap targets:** mode orbs ✅ large. Genre chips ❌ under floor (U-01). Mic button is `band.touchTarget(48)` → clamped to 64 ✅ (`:349`). Wish field ✅.
- **Placement / hierarchy:** story-style → genre twist → "anything special" → Next is a clean, logical top-to-bottom read. Good.
- **Crowding / fold:** at 400×811 the orbs + genre row fill the first view; the wish field and arrow sit just below the fold — a 9-year-old must scroll once. Acceptable.
- **Redundancy:** none.
- **Next action obvious?** Yes — single purple arrow labelled "Next: Review & Launch!". The progress stepper (My Character ✓ / Companions ✓ / Setting ✓ / Start Adventure! 4) gives clear "almost done" framing — good for sustaining a 9-year-old through a multi-step wizard.

---

## Delight Levers (band-specific, with developmental rationale)

1. **The genre twist already twists — make it *visible*.** 9–11s are in Erikson's industry stage and want choices to visibly matter. The genre already shapes the story (woven age-safely), but the child gets no on-screen confirmation that it "took." See lever 3.
2. **"Pick a Path" agency.** "You choose what happens!" is perfectly pitched — concrete-operational kids love branching control. Keep it prominent.
3. **A tiny preview chip when a genre is chosen.** e.g. selecting "Mystery" briefly shows "🔍 a clue to solve". Rationale: confirms the choice registered (the effect is real but currently invisible until the story arrives) and rewards exploration.
4. **Let them stack two genres (e.g. Comedy + Spooky).** 9–11s delight in combinatorial play ("a *funny* scary story"). Current model holds a single `selectedGenre`; a 2-pick cap would feel grown-up without overwhelming. Rationale: mastery through combination.
5. **Voice-wish as a "talk to your story" moment.** The mic can feel magical at this age *if* it's framed as the story listening. A subtle "I'm listening…" animation makes the tool feel capable, not babyish.

---

## Parent Trust (Love / Distrust)

**Love**
- Genre row is **"(optional)"** and nothing is pre-selected — no nudging, no dark pattern.
- **"Next: Review & Launch!"** — the story isn't generated from this screen; there's a review gate. Parents trust a confirm step.
- Free-text wish is **genuinely protected server-side**: per-field length cap (`MAX_CUSTOM_ELEMENTS`), `[USER_INPUT]` delimiter wrapping, and prompt-injection pattern screening (`backend/utils/sanitizer.py:59–109`). Strong, real signal.
- Honest labelling: "Story Quest" subtitle drops the "illustrated" promise when the account can't make images (`:476–482`).
- No upsell, urgency, or pre-checked consent on this surface.

**Distrust / concern**
- **Romance for a 9-year-old (G-01)** — the clearest "is this curated for my kid?" flag on the screen. **Addressed:** reframed to "💛 Friendship" on this screen.
- **Opaque mic/free-text (C-02)** — **addressed:** a persistent reassurance line now states we keep only the safety-checked words, not the voice. (Open follow-up: privacy-policy disclosure of third-party speech processing — a doc task.)
- *(Retracted: an earlier draft listed a "genre no-op" here. The genre is in fact wired and age-clamped — not a concern.)*

**Conflicting-lens tension (design decision, not a defect):** the child lens wants *more* expressive freedom (free text, voice, genre stacking); the parent-of-a-9-year-old lens wants *curated, visible-safety* choices. Resolution for the 9-end: keep the expressive tools, but (a) reframe Romance → Friendship *(done)* and (b) surface the safety that already exists. Neither reduces a child's agency.

---

## Simplification

- **The genre set is now fully in-band** (Romance → Friendship). Six wholesome genres, all of which reach the story age-safely.
- **One reassurance line** under the wish field does more for parent trust than any layout change.

---

## Fix Plan

### Done (2026-05-30)
- **G-01** Reframed "💕 Romance" → "💛 Friendship" on this screen. *(Romance kept on the Creator-only creative-brief screen.)*
- **U-01** Genre chips now have `minHeight: 44` + centered alignment, meeting the tap-target floor.
- **C-01** Retracted (false) — genre is already wired and age-clamped; no work needed.

### Done (2026-05-30, cont.)
- **C-02** Persistent parent-facing safety line added under the wish field + mic. STT path confirmed (browser/cloud on web). *Open follow-up: privacy-policy disclosure (doc).*

### P3 — Delight Polish
- **D-03** Selection-confirmation micro-preview when a genre is picked (the effect is real but invisible until the story arrives).
- **D-04** Allow stacking up to two genres.
- **D-05** "I'm listening…" mic affordance.

---

## Autonomous vs Founder-Decision

| Fix | Autonomous? | Files Touched | Status | Risk | Reversible? |
|---|---|---|---|---|---|
| U-01 chip tap target | **Y** | `lib/widgets/hero_creator/genre_chip.dart` | **Done** | Low | Yes |
| G-01 Romance → Friendship | **Y** | `lib/screens/wizard_steps/hero_creator_story_type_page.dart` | **Done** | Low | Yes |
| C-01 wire genre | — | — | **Retracted (already wired)** | — | — |
| C-02 safety line | **Y** | `hero_creator_story_type_page.dart` (`_buildWishTextInput`) | **Done** | Low | Yes |
| C-02 privacy-policy disclosure | **N** | privacy policy doc | Open — disclose third-party speech processing | Low | Yes |
| D-03/D-04/D-05 polish | Partly | wizard page + `wizard_data.dart` | Open (P3) | Low | Yes |

> **Protected-constraint note:** no change here touches story word counts or age routing in `backend/services/story_service.py`. The genre already flows *within* the existing age-bounded prompt (`story_service.py:922` weaves it "age-appropriate and safe"); the Friendship reframe and tap-target fix are pure frontend.

**Remaining open item (doc, not code)**
1. **C-02 privacy-policy disclosure:** add language to the privacy policy noting that voice input is converted to text by a third-party browser/OS speech service (e.g. Google for Chrome users) and that Story Weaver stores only the resulting text, not audio. This matches the in-app reassurance line now shipped.

---

## Imagen Prompts

**No new imagery is needed.** The genre chips are emoji + text (not custom art), so the Romance → Friendship reframe used the "💛" emoji to match the existing chips — no Imagen asset required. The earlier "Animals paw-print orb" prompt is moot and has been removed.

---

## Final Checklist

1. ☑ **Done** — Reframed "💕 Romance" → "💛 Friendship" on this screen (G-01).
2. ☑ **Done** — Genre chips floored at `minHeight: 44` (U-01).
3. ☑ **Done** — "Pick a Path" goes full-width for Adventurer+ instead of leaving a blank half-row (L-01, addendum).
4. ☒ **Retracted** — "wire the genre chips" (C-01): already wired and age-clamped; no work needed.
5. ☑ **Done** — Persistent parent-facing safety line under the wish field + mic; STT path confirmed (C-02).
6. ☐ **Open (doc, not code):** privacy-policy disclosure of third-party speech processing (C-02 follow-up).
7. ☐ **Optional polish:** Adventurer body font (Bitter, M-01), band-palette Next arrow (P-01), and the P3 delight pass (genre confirmation preview, two-genre stacking, "listening" mic).

---

### Verdict (≤300 words)

*Revised after correcting the C-01 error and shipping the G-01/U-01/L-01 fixes.*

**Per-lens delight score (post-fix):** Parent **8/10** · Child **8/10** · Psychologist **8/10**.

For a 9-year-old, "Choose Your Story Type" is structurally the *right* screen — the app correctly hides this maturity of choice from younger bands, the genre row is honestly marked "(optional)," nothing auto-generates ("Next: Review & Launch!"), and the free-text wish is genuinely protected server-side (length-capped, `[USER_INPUT]`-wrapped, injection-screened). From a parent's chair, the fundamentals are trustworthy and dark-pattern-free.

The biggest claim in the first draft — that the genre chips were a no-op — was **wrong**: the genre is folded into `customElements` (`wizard_data_mapper.dart:298–301`) and woven age-safely by the backend (`story_service.py:922`). A child's "Sci-Fi" pick *is* honoured and *is* age-clamped, which is a strong dual win for both lenses. The one real maturity flag (a "Romance" chip at the 9-year-old edge) has been reframed to "Friendship," and the two layout defects — sub-floor chip tap targets and the blank half-row beside "Pick a Path" — are fixed.

**What's shipped (this session):**
1. **Romance → Friendship (G-01).** Removes the only maturity flag; Romance stays on the Creator-only creative-brief screen.
2. **44 px tap target on genre chips (U-01).** Meets the band's own standard.
3. **Full-width "Pick a Path" for Adventurer+ (L-01).** Kills the "looks broken" gap *and* headlines the highest-agency mode.

**What's left:** all four findings are now actioned in code. The only open item is a **doc task** — disclosing third-party (browser/OS) speech processing in the privacy policy to match the new in-app reassurance line. Optional polish remains: Adventurer body font (M-01) and band-palette Next arrow (P-01).

---

## Addendum — Second-Pass Findings (2026-05-30, independent review)

*A second review pass (parallel session) recorded three **net-new** findings the first pass did not cover. The first is a visible layout defect.*

> **Correction (2026-05-30):** this addendum's intro originally said it "confirmed C-01 (genre no-op)." That is **false** — both passes repeated the same truncated-search error. The genre is wired and age-clamped (`wizard_data_mapper.dart:298–301` → `story_service.py:922`). C-01 is retracted. L-01 below, however, is real and has been **fixed** (Pick a Path now full-width for Adventurer+). U-01 and G-01 are also fixed.

| ID | Title | Lens | Severity | Element | Issue | Recommendation | Autonomous? | Effort |
|---|---|---|---|---|---|---|---|---|
| L-01 | Empty half-row beside "Pick a Path" | Child, Parent | **High** | `hero_creator_story_type_page.dart:531–549` | For `characterAge >= 9` (i.e. all of Adventurer) the reading-mode orb is hidden and replaced by `Expanded(child: SizedBox.shrink())`, so "Pick a Path" sits alone in the **left half of the row with a blank right half** (visible in screenshot 1). A 9-year-old reads it as "something failed to load"; a parent reads it as "unfinished app," which quietly erodes willingness to pay. | When the reading orb is absent, give **Pick a Path a full-width row** — this removes the gap *and* promotes the highest-agency mode (the band's strongest delight lever). | **Y** | S |
| M-01 | Body font reads younger than the band | Psych, Parent | Medium | Fredoka in `genre_chip.dart:45` and `hero_creator_story_type_page.dart:135/:219/:413` | The gold Bitter title hits the "book/cool" Adventurer personality (`age_band_theme.dart:384`), but every body label/chip uses bubbly **Fredoka**, shaving ~2 years off the intended 9–11 sophistication. | Use the band UI font (Bitter) for Adventurer body labels/chips; keep Fredoka for Sprout/Explorer only. | **Y** | M |
| P-01 | Next arrow ignores the band palette | Consistency | Low | `hero_input_widgets.dart:387–393` | The arrow gradient is hard-coded purple/gold for every band, rather than the Adventurer teal/indigo accent — the one element on screen that ignores `adventurerTheme`. | Drive the gradient from `band.primary` / `band.accent`. (Note: this button is shared across all bands — confirm before retheming.) | **Y** | S |

**Updated checklist priority** (merging both passes): the **L-01 full-width "Pick a Path"** fix is a same-change double win — it kills the "looks broken" gap *and* headlines the agency mode — and is fully autonomous, so it belongs alongside U-01 as a do-now item, ahead of the two founder decisions (C-01 wire-vs-remove, G-01 Romance gating).

*Reconciliation note: the first pass scored Delight 6 (hollow genre) and weighted the genre no-op as the headline; this pass concurs C-01 is the most important issue. L-01 is the most important issue the first pass **missed** — it's the only finding here visible in the screenshot without reading code.*
