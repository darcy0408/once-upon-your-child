# Adult Band (18+) UX Audit — 2026-03-31

**Auditor:** Claude Sonnet 4.6
**Method:** Six Hats walkthrough + full codebase audit
**Persona:** Alex, 32, uses the app alone for reflective storytelling after work

---

## White Hat — Facts

### What the adult band is

- `AgeBand.adult` maps to ages 18+ (`ageBandFromAge(age) >= 18`)
- Theme: deep slate backgrounds (`#08080E`–`#0A0A12`), warm amber-gold accent (`#BFA45A`), `SourceSansPro` UI / `Merriweather` story text
- `sparkleIntensity: 0.0`, `showParticles: false`, `preferDarkMode: true`
- Touch targets: 48 px; corner radius: 4–8 px; type scale: 0.85×

### Navigation

Adults get 3 tabs (Stories, Library, Settings). The Feelings tab is **explicitly removed** (`isAdult ? -1 : 1`). No replacement is shown.

### Scenarios (13 total)

| Scenario | Has adultTitle? |
|----------|----------------|
| doorway_seasons | ✅ "Doors We Can't Reopen" |
| volcano_dragons | ✅ "The Weight of Old Fire" |
| neon_jungle | ✅ "The Light That Waits" *(added this session)* |
| crystal_cavern | ✅ "What Echoes Back" |
| storm_chaser_sky | ✅ "The Storm You've Been Feeding" *(added this session)* |
| vanishing_colors | ✅ "When Meaning Dissolves" |
| brave_friend | ✅ "The Cost of Showing Up" |
| standing_tall | ✅ "Holding the Line" |
| big_feelings_quest | ✅ "Sitting With It" (hidden for adults anyway) |
| change_is_coming | ✅ "Starting Over" |
| safe_space | — "Imagine It" (universal; works fine) |
| midnight_mystery | ✅ "Every Answer Costs Something" *(added this session)* |
| survival_island | ✅ "Only What You Carry" *(added this session)* |

### Companions (4, peer-framed)

Thunder Wolf, Shadow Panther, Crystal Phoenix, Robin — all described as equals or "chosen family", not helpers or guardians.

### Feelings vocabulary

30 emotions including 5 adult-exclusive: Melancholy, Contentment, Indignation, Dread, Anticipation.

### Assets

~68 files: 8 archetypes, 4 companions, 32+ feelings PNGs, 4 scenes, backgrounds, UI characters.

---

## Red Hat — Feelings

The dark amber aesthetic immediately signals "this is for me" — it doesn't look like a children's app with a dark mode toggle, it genuinely feels considered. The companion copy (Thunder Wolf: "Not here to protect you — here to run the same storm") is excellent: it treats the user as a peer, not a patient.

Removing the Feelings tab is the right call. Being funnelled into a "how does your hero feel?" childlike flow would be jarring. But right now, removing it leaves a gap that feels like something was just deleted. Adults who want the app for emotional reflection have nowhere to go except story — which is actually the right destination, but isn't obvious.

---

## Black Hat — Risks & Gaps

### 1. No emotional regulation path (HIGH)

Big Feelings Quest is hidden; meditation is planned but not built. Adults currently have **zero dedicated emotional support flow**. Story-as-therapy is valid, but the app offers no onramp — there's no indication the story can serve this purpose, no prompts that frame it that way.

### 2. No adult-specific world bibles (MEDIUM)

Only `doorway_seasons` has an `adultWorldBible`. All other scenarios fall back to `matureWorldBible` (written for Creator/Adolescent, ages 13–17). The content isn't wrong for adults but it doesn't hit the existential register that the adult titles promise. A story titled "Doors We Can't Reopen" shouldn't be world-built the same as a story for a 13-year-old.

### 3. Archetypes unchanged (MEDIUM)

All 8 archetypes are shared verbatim across all bands — names like "The Storm Rider", "The Quiz Whiz", "The Heart Healer". These read as heroic-journey framing for younger users. For adults, they land awkwardly. The adult band has `adultTitle` on scenarios; it could use something similar for archetypes.

### 4. No thematic question layer for adults (LOW)

Scenarios have `creatorThematicQuestion` (e.g. "What storm are you running from?") but no `adultThematicQuestion`. Adults could benefit from a deeper, more introspective prompt layer at story launch.

### 5. Title-only upgrade (LOW)

Four scenarios (fixed this session) previously fell back to `matureTitle`/`creatorTitle`. Now all 12 active scenarios have adult-specific titles. But titles alone don't change how the story is constructed — the world bibles are still mature-band prose.

---

## Yellow Hat — What Works

- **Companion personas are genuinely adult-quality.** The copy for Thunder Wolf and Shadow Panther in particular is striking and distinctive.
- **Feeling vocabulary is right.** Melancholy, Dread, Contentment, Anticipation — these are adult emotional states, not translated child emotions.
- **Visual theme is coherent.** Amber-on-near-black with Merriweather for story text feels editorial.
- **Asset coverage is complete.** Nothing is missing from the image sets.
- **Dark mode by default.** Not a toggle, just the right choice for the band.
- **Bedtime wizard prompts are excellent.** "Tonight's Story Focus" options (Burnout & Rest, Examining Assumptions, Creative Block, Finding Purpose) are genuinely useful adult framings.

---

## Green Hat — Opportunities

### Immediate (this sprint)

1. ~~Add adult titles to 4 missing scenarios~~ ✅ **Done this session**
2. Add `adultWorldBible` to the 3 most-used scenarios (doorway_seasons already has one; volcano_dragons, neon_jungle, storm_chaser_sky are natural next candidates) — deepens the existential register
3. Add `adultThematicQuestion` field (optional) — shown at the "Begin" button, sets a reflective frame before the story starts

### Next sprint

4. **Guided meditation feature** — highest-impact gap; replaces the missing emotional tool. See `memory/project_guided_meditation.md` for scope.
5. **Adult archetype rename layer** — add `adultName` to `ArchetypeData` (same pattern as `youngChildName`). E.g. "The Storm Rider" → "The One Who Runs Toward It"; "The Heart Healer" → "The One Who Stays".

### Future

6. **Adult onboarding moment** — after age selection, a brief sentence that frames what adults can use the app for ("Reflective stories, built around you. No magic required."). Currently the generic "Welcome to Story Weaver" TTS line does this work but it's thin.

---

## Blue Hat — Process

### Fixed this session

| # | Fix | Status |
|---|-----|--------|
| S1 | Adult scenario titles (neon_jungle, storm_chaser_sky, midnight_mystery, survival_island) | ✅ Done |

### Deferred

| # | Gap | Priority |
|---|-----|----------|
| D1 | `adultWorldBible` for top 3 scenarios | Medium |
| D2 | `adultThematicQuestion` field + UI | Low |
| D3 | Adult archetype `adultName` layer | Medium |
| D4 | Guided meditation feature | High — next major feature |

---

## Summary

The adult band is **functional and tastefully designed** — the theme, companion personas, and feelings vocabulary are genuinely good. The scenario title gap is now closed (all 12 active scenarios have adult-specific titles). The significant outstanding work is:

1. **World bibles** — most scenarios still use mature-band prose beneath adult titles
2. **Guided meditation** — the only real emotional path for adults, not yet built
3. **Archetype naming** — minor but noticeable; heroic-journey framing skews young

The adult user can currently open the app, pick an age-appropriate scenario, choose a peer companion, launch a story, and have a genuinely adult experience. That's a solid baseline.
