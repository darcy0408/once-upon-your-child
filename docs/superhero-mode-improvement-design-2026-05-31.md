# Superhero Mode — Improvement Design & Audit (2026-05-31)

**Bands in scope:** Explorer (6–8) and Adventurer (9–12). Sprout (3–5) stays as-is.
**Author:** Claude (session-driven). **Owner decisions flagged inline as `[OWNER]`.**

---

## 1. Why this doc

Superhero Mode shipped for Adventurer on 2026-05-31 (PR #170) and earlier for Explorer
(PR #6298 era). It works, but three problems hold it back for the 6–12 audience:

1. **It's buried.** It lives behind: Create Story → Hero Creator → setting/story-type step
   → "Imagine It / Make One Up" screen → a gold "Be a superhero!" button under an "or"
   divider (`lib/screens/wizard_steps/imagine_it_screen.dart:321`). That's 4–5 taps deep.
   Most kids will never discover it.
2. **It feels babyish for 9–12.** The Adventurer flow is the *same* 4-tap picker a
   3-year-old uses (color → cape → emblem → power), just with renamed labels and a darker
   palette. No identity, no payoff, no picture.
3. **We already built assets we don't use.**
   - `lib/superhero_name_generator.dart` — a full funny-name + catchphrase + mission
     generator, themed by emotional focus. **Orphaned** (only referenced by the legacy
     `character_creation_screen_enhanced.dart`), not wired into the superhero wizard.
   - `backend/gemini_image_generator.py` already has `generate_custom_avatar`
     (photo→Pixar) and `tweak_gallery_avatar`. The costume color/cape/emblem/power are
     captured into `WizardData` / `HeroProfileLocal` but **never sent to image generation**.

## 2. Current flow (as-built)

```
SuperheroEntryScreen (entry dispatcher, derives band from age)
  ├─ returning user → SuperheroWelcomeBackScreen  (reuse saved hero / edit)
  └─ first run      → SuperheroCostumeScreen       (color → cape → emblem, 3 PageView pages)
                        └─ SuperheroPowerScreen     (2×N power grid, confirm)
                              → saves HeroProfileLocal, sets
                                wizardData.selectedScenario = 'superhero',
                                wizardData.heroSuperpower = '{PowerName} {ChildName}'
                              → pops back to wizard root
```

Backend: `wizardData.selectedScenario == 'superhero'` routes to the band-specific
superhero prompt tier (`T7_SUPERHERO_EXPLORER` / `T8_SUPERHERO_ADVENTURER`) built from
`backend/data/superhero_matrix.py` (villains × problems × powers).

**Data captured today:** `heroCostumeColor`, `heroCapeStyle`, `heroEmblem`, `heroPower`,
`heroSuperpower` (display name). All persisted in `HeroProfileLocal`.

**Gaps:** no hero image; name is a fixed formula; no catchphrase/sidekick/nemesis/origin;
no random roll; no reveal moment; entry is hidden.

---

## 3. The four chunks

### Chunk D — Discoverability / prominence (do FIRST; cheapest, highest reach)

The single highest-leverage change. Today's entry is a secondary button on a sub-screen.
Make it a **first-class story type**.

**D1 (primary):** Add a **"Superhero" mode orb** to the story-type picker
(`hero_creator_story_type_page.dart`) alongside Story Quest / Rhyme Time / Pick a Path,
for Explorer + Adventurer only. Selecting it routes into `SuperheroEntryScreen` (or sets a
pending intent the wizard consumes). This puts it where kids are already choosing what kind
of story to make.
- Orb copy: Explorer "Superhero" / "Be the hero who saves the day"; Adventurer
  "Superhero" / "Real villain, real stakes — you win with brains and heart".
- Emoji 🦸; band-gold accent to match the existing entry styling.

**D2 (secondary, optional):** Keep the existing "Be a superhero!" button on the Imagine It
screen as a redundant entry (no harm), OR promote a small "Superhero" chip on the home/
main story screen for returning heroes who already have a saved `HeroProfileLocal`
(`lib/main_story.dart`). `[OWNER]` decide whether home-screen real estate is worth it.

**Effort:** D1 ~half day (one orb + routing). D2 ~half day if pursued.
**Risk:** low. Pure additive UI + existing route.

---

### Chunk B — Random match + funny names (quick win; code already exists)

Wire the orphaned `SuperheroNameGenerator` into the flow and add a one-tap roll.

**B1 — "🎲 Surprise me!" button** on the costume screen (and/or entry): one tap rolls a
full hero (color + cape + emblem + power + name), with a slot-machine spin animation, then
drops the kid straight at the power-confirm / reveal. Re-rollable. This is the
lowest-effort, highest-replayability feature — kids love re-rolling.

**B2 — Funny name picker.** Replace the fixed `'{Power} {ChildName}'` with a choice:
surface 3 generated names from `SuperheroNameGenerator.generateIdeas(count: 3)` (e.g.
"The Quiet Storm", "Captain Can-Do", "Sir Reacts-a-Lot"), plus a "type my own" field and a
"🎲 reroll names" button. Keep the formula name as one of the options so nothing is lost.

**B3 — Catchphrase.** The generator already returns catchphrases. Let the kid pick/edit one
and **thread it into the story prompt** so the hero actually says it at the climax. Add
`wizardData.heroCatchphrase` and pass it through `wizard_data_mapper` → backend superhero
prompt builder. Big ownership boost for low effort.

**B4 (optional) — Goofy sidekick toggle.** Generator already has gags ("therapy llama named
Hugbug"). One toggle → one prompt line. `[OWNER]` in/out.

**Effort:** B1+B2 ~1 day (generator exists; mostly UI + a spin animation). B3 ~half day
(plumb one field end-to-end + a prompt line). 
**Risk:** low-medium. The generator's tone is therapeutic/young; we should add an
Adventurer-register name pool so 9–12 names don't read too cutesy (see §4).

---

### Chunk A — Superhero portrait from the kid's character (the headline)

Turn the child's existing character avatar into a superhero portrait using their costume +
power choices. Pipeline is ~80% there.

**A1 — Generation.** After power/name confirm, call the avatar pipeline with the child's
**existing avatar as the reference image** + a superhero-transform prompt assembled from
`heroCostumeColor` / `heroCapeStyle` / `heroEmblem` / `heroPower` ("same child's face and
hair, now in a {red} hero suit with a {lightning} chest emblem and a {rainbow} cape,
dynamic {flying} action pose, comic-book lighting, non-photorealistic Pixar style"). Reuse
`generate_custom_avatar` / `tweak_gallery_avatar` in `gemini_image_generator.py`; add a
`superhero_transform` prompt path. Works for both Explorer + Adventurer (one code path).

**A2 — The Reveal.** A "Suiting up…" animation (cape unfurl / emblem ignite) that resolves
into the generated portrait. This is the dopamine payoff the flow currently lacks. Gate the
animation behind `MotionPrefs` (reduce-motion) per the A11Y pattern.

**A3 — Comic-cover framing.** Present the portrait as a Marvel-style cover: hero name banner,
"Issue #1", halftone dots. High screenshot/share value. Reuse the framing approach from the
MT-099 reader chrome if practical.

**A4 — Persistence + reuse.** Save the portrait URL on `HeroProfileLocal` so the
welcome-back screen shows the existing hero portrait, and so the story can use it as the
illustration reference (face-consistent illustrations — ties into MT-129 avatar↔illustration
fidelity).

**Cost / paywall** `[OWNER]`: this is a paid image-gen call (Flux Schnell for non-BYOK,
~per-image cost; BYOK bypasses). Recommend: gate like the existing free-tier illustration
cap — 1 free hero portrait, then upsell; BYOK always on. Reuse the illustration quota
breaker so a Redis outage fails closed.

**Effort:** ~2–3 days (backend prompt path + frontend reveal/cover UI + persistence +
paywall wiring + tests).
**Risk:** medium. Image latency (show the reveal animation as cover for the wait); cost
control; face-likeness quality on a stylized re-render.

---

### Chunk C — Anti-babyish redesign (Adventurer-specific polish; do LAST)

Make the *creation* feel like building a hero, not picking a crayon. Layer on after A/B/D.

- **C1 Lead with archetype/class** ("The Trickster / The Tank / The Brains / The Healer")
  instead of a color swatch — frame like picking a class in a game.
- **C2 Rename color swatches to suit themes** ("Midnight / Inferno / Storm / Toxic") — same
  data, cooler labels. Adventurer only.
- **C3 Origin one-liner** ("Where did your powers come from?": accident / built a suit /
  born with it / chosen) → one prompt line, personalizes the story.
- **C4 Nemesis picker.** `superhero_matrix.py` already has 10 motive-driven Adventurer
  villains — let the kid *choose* their arch-villain instead of the server picking silently.
  Ownership of the antagonist is a strong tween hook.
- **C5 Weakness/quirk** ("super strong, but ticklish") — 9–12s find flaws funnier and more
  relatable than pure power.

**Effort:** ~2–3 days total; independently shippable sub-items.
**Risk:** low-medium (each adds a `WizardData` field + a prompt line + a picker).

---

## 4. Cross-cutting notes

- **Name register split.** `SuperheroNameGenerator` is tuned young/therapeutic. Add an
  Adventurer-tier name pool (cooler, less cutesy) so chunk B doesn't read babyish to 9–12.
- **New `WizardData` / `HeroProfileLocal` fields** introduced across chunks:
  `heroCatchphrase` (B3), `heroPortraitUrl` (A4), `heroOrigin` (C3), `heroNemesisId` (C4),
  `heroWeakness` (C5). Each must be threaded through `wizard_data_mapper.dart` →
  backend superhero prompt builder, and added to the `HeroProfileLocal` Isar/io+stub schema.
- **Backend prompt builder** (`_build_superhero_prompt_explorer/_adventurer`) takes the new
  fields as optional inputs; default behavior unchanged when absent (back-compat).
- **Tests.** Each new field needs: mapper test, prompt-builder test (field present/absent),
  and a widget test for the new picker. Follow the 33-test precedent from PR #170.
- **A11Y.** All new animations gate on `MotionPrefs`; all new tap targets get Semantics
  labels + ≥2 non-color selection cues (per the A11Y-007/014 remediation pattern).

## 5. Recommended sequence

1. **D1** — surface the orb (cheap, unlocks everyone seeing the rest). 
2. **B1+B2** — random roll + funny names (quick win, code exists).
3. **A1–A4** — the portrait (headline, highest wow).
4. **B3, C1–C5** — depth, as time allows.

## 5b. Build status (updated 2026-05-31, same session)

**Shipped + verified this session:**
- **Stale comments fixed** across the 4 superhero screens (were "ages 3-5").
- **Chunk D1 — discoverability.** Superhero is now a first-class, full-width orb on
  the story-type picker for Explorer + Adventurer (`hero_creator_story_type_page.dart` +
  `ImageModeOrb` 🦸 glyph + `_launchSuperheroFromStoryType` in `hero_creator_step.dart`).
  Compiles clean; existing 18 superhero tests still green.
- **Chunk B1 — random match.** "🎲 Surprise me!" on the costume screen rolls a full
  random costume and jumps to the power picker with a random power pre-selected + a
  surprise banner with a reroll (`superhero_costume_screen.dart`, `superhero_power_screen.dart`).
- **Chunk A (backend core) — superhero portrait prompt.** Pure, unit-tested
  `build_superhero_transform_prompt()` + `GeminiImageGenerator.transform_to_superhero()`
  in `gemini_image_generator.py`; 5 new tests in `test_superhero_transform_prompt.py` (green).
  Reuses the existing `_POWER_VISUAL_OVERRIDES`, child-safety settings, and likeness-preservation
  pattern from `tweak_gallery_avatar`.

- **Chunk B2/B3 — funny names + catchphrase.** Cooler Explorer/Adventurer name pools +
  name/catchphrase chooser; `heroCatchphrase` threaded end-to-end into both bands' prompts
  (no-op when absent). Built by a delegated worktree agent; merged in. Flutter + backend
  tests green.
- **Chunk A — superhero portrait, FULLY WIRED + LIVE-VERIFIED.**
  - Backend: `AvatarGenerationService.transform_to_superhero()` + `POST /avatar/transform-superhero`
    (premium-gated, BYOK unlimited, 10MB + magic-byte validation). 3 route tests (stubbed) green.
  - Frontend: `SuperheroPortraitService` (multipart call + 401 retry) → `SuperheroRevealScreen`
    ("Suiting up…" pulse, MotionPrefs-gated, → comic-cover with hero-name banner + ISSUE #1,
    fail-soft fallback). Hooked into `superhero_power_screen._confirm` after save (gated on the
    child having a generated avatar). `heroPortraitUrl` added to `WizardData` (+ clone; not
    serialized — the data URI is large and regenerable).
  - **Live-verified locally** (the `.env` keys DO work — earlier "needs prod key" was wrong;
    "red on main" is purely CI, which has no `.env`): generator + service layers both produced
    correct portraits that preserve the child's likeness and honor color/cape/emblem/power
    (tested blue+rainbow+lightning+flying and purple+matching+star+strategist).

- **Welcome-back persistence — DONE.** `SuperheroPortraitStore` (SharedPreferences, keyed by
  characterId — chosen over an Isar schema field to avoid codegen + ~1-2MB blob bloat) saves the
  portrait on reveal; `SuperheroWelcomeBackScreen` shows it via `FutureBuilder` (gold frame),
  falling back to the emblem badge when absent.

**Remaining for Chunk A (small follow-ups):**
- Optionally feed the portrait as the story illustration reference (ties into MT-129).
- Paywall is currently premium-only; "1 free portrait + upsell" is still an `[OWNER]` call.

**Remaining for Chunk B (deferred):** B4 sidekick toggle.

**Not started:** Chunk C (anti-babyish redesign), Chunk D2 (home-screen chip).

## 6. Owner-decision items

- `[OWNER]` D2: home-screen superhero chip for returning heroes — worth the real estate?
- `[OWNER]` A: paywall model — 1 free portrait + upsell vs. fully paid vs. BYOK-only?
- `[OWNER]` B4: goofy sidekick in or out?
- `[OWNER]` Name register: approve an Adventurer-tier cooler name pool list.
- `[OWNER]` C4: let kids pick the villain, or keep it server-surprise?
