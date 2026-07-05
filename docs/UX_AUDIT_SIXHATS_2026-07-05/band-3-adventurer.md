# Six Hats UX Audit — Band 3: Adventurer (9–11)

**Run:** prod, fresh anon, age 10, "Kai", Boy, The Quiz Whiz, Atlas, The Crystal Cavern of Echoes, Story Quest + Sci-Fi twist. 14 screens.

## Developmental frame
Fluent readers, competent motor skills, moderate complexity welcome. Kryptonite = anything babyish; wants agency, systems, and identity ("my character", "my mission"). Tolerates ~60–90s waits if framed as production.

## Screen-by-screen highlights

### Wizard p1 — "Create Character"
- **Yellow:** Tone shift lands: steps renamed (My Character / My Companions / My Setting / Start Adventure!), serif book typography, and **cosmic silhouette gender cards** — the strongest gender-art solution in the app (identity without a face forced on you).
- **Black:** Girl still pre-selected by default (P2, all bands).
- **Blue:** **Right**. Playground 9/10.

### Avatar modal
- **Black (revised cross-band finding):** pool weighting is **high-variance, not absent** — Boy pick here: 5♂/3♀ (fine); Boy pick on Sprout run: 1♂/7♀ (catastrophic). Make weighting deterministic (≥6/8 match pick). P1.
- **Black:** avatar faces skew young (6–8-ish) for a 10–11yo; a "less cute, more cool" sub-pool would fit the band. P3.

### Archetype — "Choose your archetype"
- **Yellow:** Best art + copy pairing in the app ("The Quiz Whiz — the strategist who cracks the impossible puzzle when everyone else is stuck"). "Archetype" vocab OK at this band.

### Companions
- **Yellow:** Personality copy is pitch-perfect for 9–11 (Atlas: "Three routes mapped. Option two is most interesting."; Nyx: "Sets boundaries. Finds the exit." — boundary-skills tie-in).
- **Black:** P1 — Next below the fold (same as Explorer). P2 — "Rockin' Robin" kawaii art/name here = MT-281 tonal drift, still live.

### Setting — "Choose your setting"
- **Black:** **P1 — REGRESSION vs PR #243:** the 10yo's setting picker serves the same kawaii-bunny candy "Land of Vanishing Colors" art as the 3yo. Memory says scenarios/adventurer/ art shipped in #243; either orphaned by a later refactor or this page bypasses the per-band dir. Titles upgraded ("The Crystal Cavern of Echoes") but art contradicts. Single highest abandonment risk for this band ("baby app" verdict).
- **Black:** P3 — "Imagine It" tile art is pink-pastel young-girl-coded.

### Story type — "Choose your story type"
- **Yellow:** Genre twist chips (Mystery/Comedy/Sci-Fi/Action/Spooky/Romance) + "Anything special you want?" free text = exactly the agency this band wants.
- **Black:** P2 — **"Romance" chip at 9–11** while #249 renamed romance→friendship for *Creator* (12–14): younger band kept the label the older band dropped. Align: "Friendship".
- **Black:** P3 — "Rhyme Time" reads young at this band; consider demoting/renaming ("Verse Mode"?).

### Review — character sheet + mission
- **Yellow:** THE standout screen of the audit: CLASS/ROLE/POWER/PARTY character sheet + generated MISSION hook ("The Echo-King has borrowed your friend's voice, and you need a clever riddle to get it back") + "MISSION READY" CTA. This is the kind of screen kids screenshot and send friends.
- **Black:** **P1 — "Picture tale · Sci-fi" label after picking Story Quest** — third band in a row (systemic story-type label bug; on Explorer it changed the actual render mode, here cosmetic).

### Generation + Reader — "The Echo-King's Riddle"
- **Yellow:** Staged progress (Entering your world → Finding your hero → Writing → Almost ready) + sparkle-catcher + Cancel. Reader: full literary text pages, band-perfect prose ("shoelaces slapping the metal floor, while Atlas unfolded a crisply creased map one-handed") — name, companion, setting, sci-fi twist, AND the mission hook all honored. Best content output of the three bands so far.
- **Black:** P2 — verify Share (bottom bar) is parent-gated on child accounts. P3 — no illustrations at all in this run's spread (text-only) — intended for the band? If picture-tale label was wrong, illustration placement may be off too.

## Action Plan (Adventurer)

| Priority | Screen | Issue | Change | Effort |
|---|---|---|---|---|
| P1 | Setting picker | Baby scene art regression vs #243 (kawaii bunnies at age 10) | Re-wire scenarios/adventurer/ art (verify code path) | S–M |
| P1 | Review | "Picture tale" label for Story Quest (systemic; changes render mode on Explorer) | Fix story-type mapping/label | S |
| P1 | Companions | Next below fold | Sticky Next pill | S (shared fix) |
| P2 | Story type | "Romance" chip inconsistent with #249 | Rename "Friendship" | S |
| P2 | Companions | Rockin' Robin tonal drift (MT-281) | Re-art/rename for 9+ (keep memorial cross on Robin — only style, never the necklace) | M |
| P2 | Reader | Share gating on child account unverified | Verify + gate | S |
| P3 | Avatar pool | Faces skew young for band | Older-skew sub-pool | M |
| P3 | Story type | Rhyme Time label young | "Verse Mode" or demote | S |
| P3 | Setting | Imagine-It art girl-coded | Band-neutral variants | S |

**Elevate:** the character sheet + mission pattern deserves expansion — persist the CLASS/PARTY sheet as a collectible "hero card" gallery ("Issue #N" saga numbering already exists server-side via the continuity loop); genre-twist chips could stack (Sci-Fi + Spooky) for replay depth.
