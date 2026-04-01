# Children's App UX Audit — Adolescent Band (Age 16)
**Date:** 2026-03-31
**Method:** Screenshot walkthrough (3 live screenshots) + full code review of adolescent-specific paths
**Persona:** 16-year-old, independent user, uses the app on a phone or laptop alone
**Band tested:** Adolescent (ages 15–17)
**Screenshots folder:** `docs/ux_audit_adolescent_16yo_2026-03-31/` (adolescent_01–03)

---

## Flow Observed

| Step | Screen | Screenshot |
|------|--------|------------|
| 1 | Profile setup — name entry | `adolescent_01_splash.png` |
| 2 | Wizard — creative brief accordion (Character step expanded) | `adolescent_02_wizard.png` |
| 3 | Review — "Ready to begin?" pitch card | `adolescent_03_pitch.png` |

**Note:** Playwright browser lock prevented a full live walkthrough. Screenshots 1–3 are from a prior session; remaining steps are reconstructed from code review of `hero_creator_step.dart`, `magic_review_step.dart`, `wizard_story_screen.dart`, and `age_band_theme.dart`.

---

## 🤍 White Hat — Facts I Observed

**Profile setup (adolescent_01_splash.png):**
- Title: "Set up your profile" in white. Purple account-circle icon above.
- Large mic button: "Tap to say your name."
- Text field below: placeholder "What should we call you?"
- "Continue →" button, full-width, purple.
- Top-right: "Parent" shield-icon button (COPPA).
- No mascots, no sparkles. Clean dark background.

**Wizard — Character step (adolescent_02_wizard.png):**
- 4-step progress bar at top: `1 Character` · `2 Companions` · `3 Setting` · `4 Start Writing`
- Top-right icons: ✕ close, ♥ feelings, 👤 characters, 📖 library, 🌙 dark mode
- Gold heading: "Build Your Story"
- Italic subtitle: "Define the parameters of your experience."
- Gold divider (short)
- "CHARACTER & ROLE" section — expanded (chevron ↑)
  - "PROTAGONIST NAME" text field — value: "Sam"
  - "CHARACTER GENDER" — two 3D Pixar-style portraits, girl selected (gold border)
  - Below (not visible in screenshot): CORE ARCHETYPE chip row
- Other accordion sections collapsed: Personality, Cast & Companions, World & Setting, Story Options
- Background: dark purple gradient (0xFF120226 → 0xFF3D1166)
- CTA at page bottom: large gold "Create Story" button

**Wizard accordion — additional sections (code review):**
- **Personality**: Three labelled sliders (e.g. Energy Level, Introvert ↔ Extrovert)
- **Cast & Companions**: "ADVENTURE TEAM" label + companion showcase + full companion grid (same 7 companions as younger bands)
- **World & Setting**: Setting choice chips (band-specific scenario titles e.g. "The Door You're Afraid to Open") + "CUSTOM PREMISE" chip + free-text field
- **Story Options**: "NARRATIVE MODE" dropdown (Standard View / Interactive / Poetry) + "TARGET DURATION" dropdown (Short / Medium / Long)

**isComplete logic (code):**
- `isComplete = selectedArchetypeId != null && characterName.isNotEmpty`
- Archetype is gated; setting, companions, personality are all optional
- "Create Story" button: `onPressed: _handleContinue` — no visible disabled-state feedback

**Review (adolescent_03_pitch.png):**
- 4-step header: all 4 steps now show gold checkmarks (Character ✓, Companions ✓, Setting ✓, Start Writing active)
- "Ready to begin?" title + speaker TTS icon
- Summary card (dark surface):
  - "Sam" in teal/cyan (protagonist name)
  - "—" below (archetype not selected → hidden; scenario label shows as "—" for unseen/uncompleted)
- "Start Writing" button — full-width teal

**Measured gaps vs Creator band (same accordion, different age):**
- No "What does your character want more than anything?" character-desire prompt (Creator only)
- No `characterAge`-parameterised title for world chips — uses `titleForBand(band.band)` instead
- Companion section uses "ADVENTURE TEAM" heading (age-inappropriate for 16-year-old)
- Background gradient unchanged from the shared purple (not adolescent near-black teal)

---

## 🟡 Yellow Hat — What's Working Well

### 1. Profile Setup Tone Is Pitch-Perfect for 16
"Set up your profile" is exactly the vocabulary a teen expects — it's the same phrasing as every app they use (Spotify, Discord, TikTok). No cutesy language, no cartoon mascots. The mic-first layout is direct; the text-field fallback is unobtrusive. This screen will not embarrass a teenager.

### 2. "Build Your Story" Brief Concept Is the Right UX Pattern
The accordion creative brief — rather than a page-by-page wizard — is conceptually correct for a 16-year-old. Teens resist being walked through things step-by-step like a child. Giving them a single page they can fill out in any order treats them as capable. The pattern respects autonomy.

### 3. Personality Sliders Are Interesting
The personality sliders (energy, introversion, etc.) are the most age-appropriate feature in the flow. A 16-year-old who thinks about their identity and character will enjoy calibrating these. It creates genuine emotional investment in the character before a word of story is written.

### 4. "NARRATIVE MODE" Vocabulary Is Mature
"Standard View / Interactive / Poetry" in a labelled dropdown is considerably more sophisticated than "Story Quest / Rhyme Time / Pick a Path" in the Adventurer band. A 16-year-old reader or writer will understand and appreciate the distinction. "Interactive" is clear; "Poetry" is clear.

### 5. World Chips Use Band-Specific Literary Scenario Titles
The world setting chip labels use `titleForBand(adolescent)` — so a 16-year-old sees settings like "The Door You're Afraid to Open" rather than "Big Feelings!" or "The Crystal Canyon." These are thematically appropriate: atmospheric, slightly provocative, designed to evoke story rather than spectacle.

### 6. CUSTOM PREMISE Chip
The "CUSTOM PREMISE" chip + free-text field gives complete creative control. A 16-year-old who has a specific story concept ("post-apocalyptic school reunion") can describe it directly. This is the right affordance for this age.

---

## 🖤 Black Hat — Problems and Risks

### CRITICAL

**BUG-A1: CORE ARCHETYPE is required but completely unmarked as required**
`isComplete = selectedArchetypeId != null && characterName.isNotEmpty`. The "Create Story" button is disabled if no archetype is selected — but the Character & Role section shows no asterisk, no counter, no highlighted required field. A 16-year-old who enters their name, sets gender, fills in personality sliders, picks a setting, and taps "Create Story" gets... nothing. The button doesn't fire. There is no error message explaining why. The most likely interpretation: "the app is broken." This is a silent gate with no exit sign.

**BUG-A2: Review card shows "—" when no scenario or archetype is selected**
The review card renders `heroName` (always shown) and then conditionally renders `selectedArchetypeId` only if non-null. The `scenarioLabel` falls back to a string — but if the user navigated directly to the review without selecting a setting, the card looks incomplete ("Sam" + "—"). A 16-year-old reading "—" as their story brief summary would reasonably wonder if the app registered their choices, or whether something went wrong. (Code-level: the `scenarioLabel` fallback is "Your own adventure" in current code; the "—" in the screenshot may represent the archetype line specifically when archetype is null and archetype-dependent code shows a dash instead of hiding cleanly.)

### SERIOUS

**UX-A1: Wizard background is wrong colour for the adolescent theme**
The `_buildCreativeBrief()` method is enclosed in a `Container` with a fixed purple gradient (`0xFF120226 → 0xFF3D1166 → 0xFF120226`). This gradient is shared across Creator, Adolescent, and Adult bands — none of them inherit the band's `gradientStart`/`gradientEnd` colours defined in `adolescentTheme` (`0xFF070B14` near-black blue). A 16-year-old entering the adolescent flow sees the same purple background as a 12-year-old Creator. The visual identity that distinguishes the adolescent band (cinematic dark blue-black with electric teal) is completely absent from the core wizard step.

**UX-A2: "ADVENTURE TEAM" label in companions is age-regressive**
The Cast & Companions section header reads "ADVENTURE TEAM" — the same label used when this method was written for younger children. A 16-year-old adding a friend or secondary character to their story does not want to be told they're assembling an "adventure team." The appropriate labels for this age: "Cast", "Supporting Characters", or simply "Who else is in your story?"

**UX-A3: Adolescent band shares the exact same UI as Creator — no differentiation**
Ages 12–14 (Creator) and 15–17 (Adolescent) use the same accordion layout with almost zero band-specific customisation beyond text labels. The 15-year-old and the 12-year-old see the same sections, the same companion grid, the same personality sliders, the same dropdowns. The depth of customisation appropriate for a 16-year-old (nuanced character motivation, tonal control, theme selection, POV choice) is absent. The creative brief does not feel like a 16-year-old's tool.

**UX-A4: No genre or tone selection**
The Adventurer band (10-year-old) has genre twist chips: Mystery / Comedy / Sci-Fi / Action / Spooky. The adolescent band has none — only "NARRATIVE MODE" (Standard View / Interactive / Poetry) and "TARGET DURATION". A 16-year-old with strong genre preferences (horror, romance, dystopia, literary fiction) cannot express them. The most story-genre-literate age band in the app has the fewest genre controls.

**UX-A5: The character-desire prompt is on Creator (12–14) but not Adolescent (15–17)**
`_buildBriefIdentityInputs()` shows the prompt "What does your character want more than anything?" only when `isCreator`. A 15-year-old is considerably more capable of answering this question meaningfully than a 12-year-old, and character desire is a foundational concept in teenage literature (YA, coming-of-age, etc.). The prompt should be on Adolescent, not exclusive to Creator.

### MINOR

**UX-M1: Speaker icon on "Ready to begin?" review header**
The `MagicEarButton` (speaker icon) on the review header triggers TTS of the story summary. This is a valuable feature for early readers (Explorer, Adventurer). For a 16-year-old who reads fluently, it reads as odd — "why does this app want to read my summary to me?" The icon could be hidden for mature bands, or repositioned as a settings option.

**UX-M2: "Standard View" is opaque**
The NARRATIVE MODE dropdown default is "Standard View." This tells a 16-year-old writer nothing. "Standard View" of what? The other options (Interactive, Poetry) are self-explanatory. A small descriptor ("illustrated chapters" / "branching choices" / "verse form") would make the choice meaningful.

**UX-M3: Step nav taps do scroll but this is completely non-obvious**
The 4-step progress bar at the top is interactive — tapping a step scrolls the accordion to and expands the relevant section. But there is no visual affordance suggesting the steps are tappable. A user who has already expanded Character & Role and wants to jump to World & Setting doesn't know they can tap "3 Setting" to get there. The steps look like a read-only indicator.

**UX-M4: 3D Pixar-style gender portraits feel young for 16**
The gender selection shows two animated 3D Pixar-style character portraits. This art direction is appropriate for Explorer/Adventurer. For a 16-year-old, a more editorial treatment (illustrated silhouettes, a simple toggle, or a text choice) would better match the mature tone the rest of the screen sets.

---

## 🔴 Red Hat — How It Feels to Be 16 Years Old Here

**Profile setup:** "Oh, it's asking for my name like an app. That's fine." The mic option is a surprise — "hm, voice input, interesting." Most 16-year-olds will type their name. The "Parent" button in the corner might feel slightly embarrassing — "is this a kids' app?" — but it's small enough not to dominate. ⚠️

**The creative brief landing:** "Build Your Story." The layout looks serious — like a form, not a game. This is the right instinct. A 16-year-old will appreciate being asked to "define the parameters of their experience" rather than "pick your adventure!" The gold headers on dark feel cinematic. ✅

**Filling in the name and gender:** Easy. The name field is clear, the gender portraits work. But — scrolling down past gender to find the CORE ARCHETYPE chips requires scrolling within the already-expanded accordion. If the character portraits are tall enough to push the chips below the fold, a teen might not find them at all. ⚠️

**Trying to scroll to companions, setting, story options:** The other accordion sections are collapsed. The teen taps each one, reads the content, makes selections. This works — but there's no feedback that they've "completed" a section. No checkmark, no colour change on the header. After filling four sections: "I think I got everything?" ⚠️

**Tapping "Create Story":** Nothing happens. The button is visually active (gold, full-width) — but if archetype wasn't selected, `isComplete` is false and `_handleContinue` won't fire. The 16-year-old taps again. Still nothing. They look at the screen. No error. No toast. No shake animation on the required field. The most likely outcome: rage-close or assume the app is broken. ❌❌

**The review card:** If they made it to review, they see "Sam" + their setting + "Start Writing." Minimal and clean — which is correct for the brand. The TTS speaker icon is odd. The "—" if archetype is missing is puzzling. "Wait — did it not save my character?" ⚠️

**Overall emotional arc:** Neutral curiosity → growing engagement with the brief → quiet frustration at uncommunicated requirements → abandonment or confusion → (if lucky) cautious "Start Writing."

---

## 🟢 Green Hat — Ideas and Opportunities

### Fix-adjacent improvements

1. **Mark CORE ARCHETYPE as required, show completion state per section.**
   Each accordion section header should show a subtle status indicator:
   - Not started: dim label
   - In progress / complete: small gold dot or ✓ next to the section title
   - Required + empty: subtle amber dot or border on the section header
   This prevents the silent block at "Create Story."

2. **Add error feedback when "Create Story" is tapped with no archetype.**
   Options: scroll to the Character & Role section + shake animation on the CORE ARCHETYPE row + inline message ("Pick an archetype to continue"). Even a simple `ScaffoldMessenger` snackbar is better than silence.

3. **Move character-desire prompt to Adolescent (and keep it on Creator).**
   "What drives your character?" placed under the archetype chips gives 15–17-year-olds the depth the band deserves. One `TextField`, optional. Cost: trivial.

4. **Rename "ADVENTURE TEAM" → "Cast"** in `_buildBriefCompanionsInputs()`. One string change.

5. **Add a genre/tone row to Adolescent story options.**
   Between NARRATIVE MODE and TARGET DURATION, add: TONE — chip row with `Tense`, `Melancholy`, `Dark humour`, `Romantic`, `Hopeful`. This is meaningfully different from the Adventurer "genre twist" (which is entertainment-genre) — it's a _tonal register_, which is a more sophisticated concept for 15–17.

6. **Use band-specific background gradient in the wizard.**
   In `_buildCreativeBrief()` or its parent container, apply `band.gradientStart` / `band.gradientEnd` instead of the hardcoded purple. One-line change using `band.gradientStart`.

### Enhancement opportunities

7. **Make step nav arrows visually tappable.**
   Give each step in the progress bar a subtle tap ripple or underline to signal interactivity. Tooltip on long-press: "Tap to jump to this section."

8. **Add a brief "You're writing a story" intro on first launch.**
   Before the accordion, a one-line contextual message (dismissible): "Give your story some shape — fill in what matters to you, skip what doesn't." This orients a first-time teen user without being patronising.

9. **Replace Pixar-style gender portraits with editorial silhouettes.**
   A 16-year-old choosing a character's presentation doesn't need a cartoon avatar — they need a clean toggle or two illustrated options that feel like a graphic novel, not a Disney game.

10. **Review card: show "No archetype selected" explicitly rather than hiding the line.**
    If `selectedArchetypeId` is null, show `"— archetype not set"` in a muted colour. This is better feedback than an invisible field — and since the user must fix it before continuing, surfacing the gap here gives them a second chance.

---

## 🔵 Blue Hat — Priorities and Next Steps

### Summary judgment
The Adolescent band has the right structural instincts — a creative brief rather than a childish wizard — but fails on three dimensions: (1) a hidden required-field gate that silently blocks launch, (2) a visual identity that's indistinguishable from the younger Creator band, and (3) a creative depth that is _shallower_ than it should be for the most sophisticated reading/writing age group in the app. Fixes 1–4 below are low-effort and remove the most damaging friction. Fixes 5–6 are medium-effort but meaningfully differentiate the band.

### Action plan

| # | Issue | Severity | Effort | Action |
|---|-------|----------|--------|--------|
| 1 | BUG-A1: CORE ARCHETYPE required but silent | 🔴 Critical | Low | Section completion indicators + error feedback on blocked "Create Story" tap |
| 2 | UX-A2: "ADVENTURE TEAM" → "Cast" | 🟠 High | Trivial | String rename in `_buildBriefCompanionsInputs()` |
| 3 | UX-A6: Wrong wizard background colour | 🟠 High | Low | Apply `band.gradientStart`/`gradientEnd` in wizard container |
| 4 | UX-A5: Character-desire prompt missing | 🟠 High | Low | Move/copy prompt to adolescent band (remove `isCreator` guard) |
| 5 | UX-A4: No genre/tone control | 🟡 Medium | Low | Add TONE chip row (Tense / Melancholy / Dark humour / Romantic / Hopeful) to Story Options |
| 6 | UX-M2: "Standard View" opaque | 🟡 Medium | Trivial | Add one-line descriptor per narrative mode option |
| 7 | UX-M3: Step nav not obviously tappable | 🟡 Medium | Low | Visual affordance (ripple / underline) on step nav items |
| 8 | BUG-A2: Review "—" for missing fields | 🟡 Medium | Low | Show "— not set" placeholder text instead of conditional hide |
| 9 | UX-M1: TTS speaker icon feels young | 🟢 Low | Low | Hide `MagicEarButton` for mature bands on review screen |
| 10 | UX-M4: Pixar gender portraits feel young | 🟢 Low | High | Redesign gender selector for mature bands (editorial style) |

### Top 3 if only three fixes are possible
1. **BUG-A1 — Required archetype gate** — currently causes silent failure at the most critical moment. A one-word fix ("Required") next to the section header, plus a snackbar on blocked tap, would eliminate the most damaging user path.
2. **UX-A2 — "ADVENTURE TEAM" label** — one string, one line of code, immediate register improvement.
3. **UX-A5 — Character-desire prompt** — one TextField, removes the `isCreator` guard, gives 15-17 year olds the creative depth they deserve.

### Cross-band note
- **UX-A3 (shared accordion, no band differentiation)** and **UX-A4 (no genre/tone)** are related: the adolescent band needs its own section or field additions to feel distinct from Creator. Fixing UX-A4 (adding a tone row) partially addresses UX-A3 with low effort.
- **BUG-A1** affects Creator band too — the same `isComplete` logic silently blocks Creator users as well. Any required-field feedback fix should be applied to both bands simultaneously.

---

*Audit conducted via 3 live screenshots from prior Playwright session (`docs/usability_2026-03-29/adolescent_01–03.png`) supplemented by code review of `hero_creator_step.dart` (accordion layout, isComplete, section builders), `magic_review_step.dart` (_buildAdolescentMinimalReview), `wizard_story_screen.dart` (step nav), and `age_band_theme.dart` (adolescentTheme). Persona name: SAM, age 16.*
