# Companion Powers Proposal (Audit 14, RC-3 follow-up)

Status: DRAFT for founder approval. No code has been changed.

## Why this exists

Band-specific companions (Pebble, Mochi, Atlas, Nyx, Tide, etc.) currently
reach the story model with a species description and a `behaviorPattern`, but
no defined ability. Only the generic backend `magicCompanions` (tiny dragon,
owl, cat, dog, unicorn, fox) and the Robin variants carry `signaturePower` /
`powerConstraint` / `sensoryTell`. As a result the model can describe these
companions but can't have them *do* anything distinctive to help solve a story
problem. This proposal gives each named non-robin companion a concrete,
non-combat magical ability in the established voice.

## The four friends, one power each, growing up

Each animal keeps ONE power idea that matures as the child does — simple and
visible for the little ones, subtle and wise for the oldest. Same soul, grown up.
(The bird/Robin already has this via its existing Guardian Flight power, so it is
not re-listed here.)

| Animal | Sprout 3-5 | Explorer 6-8 | Adventurer 9-11 | Creator 12-14 | Adolescent 15-17 | Adult 18+ |
|---|---|---|---|---|---|---|
| Dragon — *shows you the way* | Pebble: glitter points where to go | Ember: a rainbow path to follow | Atlas: maps every route | Cipher: finds the flaw in a plan | Zephyr: senses the next move | Tide: reads the deep pattern |
| Cat — *finds what's hidden* | Mochi: glows near something special | Clover: senses the true way through | Nyx: finds the way out through shadow | Vesper: spots what doesn't fit | Shade: reveals the real truth | Onyx: names what's really going on |
| Dog to Wolf — *senses and steadies* | Sunny: a trail that leads you home | Biscuit: senses where adventure is | Kodiak: smells the storm hours ahead | Lore: remembers what worked before | Frost: feels where the ground gives | Cinder: lights the way when it's time |

The body grows up alongside the power, too — the cat goes kitten to panther to
leopard, the dog goes puppy to husky to wolf.

## Where these values would be wired in (once approved)

The mapper already resolves band-specific companions by a `${band}_${id}` key:

- `companionBehaviorPatterns` and `companionDescriptions` live in
  `lib/data/companion_personality_data.dart`, keyed `${AgeBand.name}_${id}`.
- `WizardDataMapper` (`lib/screens/wizard_steps/wizard_data_mapper.dart`,
  around lines 162-188) looks those up by `bandKey` and, for companions with no
  `magicCompanions` id match, forwards `description` + `behaviorPattern` only.

The implementation would add a third parallel map in the same data file:

```dart
const Map<String, String> companionPowers = { ... };          // signaturePower
const Map<String, String> companionPowerConstraints = { ... };
const Map<String, String> companionSensoryTells = { ... };
```

(or a small record/class per key, mirroring `CompanionData`'s three fields),
then `WizardDataMapper` would forward `signaturePower` / `powerConstraint` /
`sensoryTell` in the band-specific branch exactly as it already does for
`magicCompanions` matches. No changes to the selector UI are required — these
fields feed the story prompt, not the cards.

## Voice reference (existing entries, for calibration)

The approved `magicCompanions` powers in `lib/data/companion_data.dart` set the
register: a named power ("Rainbow Fire:", "Star Bark:") stated as one concrete
sentence; a single limiting constraint that creates story tension; and a short
sensory cue (smell / sound / sight). All non-combat, all reveal-or-help rather
than overpower. The drafts below follow that pattern and scale the abstraction
to the band — visible and literal for Sprout/Explorer, subtle and literary for
Adolescent/Adult.

---

## Sprout (3-5)

Gentle, visible, immediately understandable. Powers solve a problem by making
something appear, glow, or feel safe.

| Companion | signaturePower | powerConstraint | sensoryTell |
|---|---|---|---|
| Pebble (purple dragon) | Sparkle Puff: When Pebble huffs, a little cloud of glitter floats in the direction you should go next, lighting the safe way forward. | The glitter only points the way — it can't tell you what is waiting there, so you still have to be brave and look. | A tiny "achoo," then the smell of birthday cake and warm sugar. |
| Mochi (orange kitten) | Treasure Glow: Mochi's gold tail tip glows brighter the closer you get to something special nearby — a hidden door, a friend, a thing worth keeping. | She can feel that something good is close, but never what it is — you still have to look. | A soft golden shimmer and the gentle jingle of her moon charm. |
| Sunny (golden puppy) | Sunbeam Run: When Sunny is happy she races ahead and her star tag leaves a warm glowing trail you can follow back home, even in the dark. | The trail only lasts while she stays happy — if she gets scared or sad, it fades. | A patch of sunshine-warmth on the ground and the smell of fresh grass. |

Behavior ties:
- Pebble — his huffs are already involuntary and proud; the glitter now *shows
  the way* (tightened from the original "finds hidden things," which overlapped
  Mochi the cat) so every dragon shares the same see-the-way soul.
- Mochi — extends "finds treasures in ordinary places" into a real homing glow.
- Sunny — built from "star tag glows the second she spots something" and her
  guide-you-in instinct, with the happiness link mirroring her warmth.

---

## Explorer (6-8)

A little more agency. Powers can shape a path or open a way, but still concrete.

| Companion | signaturePower | powerConstraint | sensoryTell |
|---|---|---|---|
| Ember (pink dragon) | Rainbow Trail: The shimmering paths Ember leaves in the air become solid enough to climb or cross for a short while, turning a good idea into a real bridge. | A trail holds only as long as someone keeps believing the idea behind it — hesitate too long and it thins to mist. | The air smells like rain on warm stone, and stray stars pop from her nose. |
| Clover (orange tabby) | True-North Read: Clover's compass and stardust spiral toward the *right* way through any maze, wood, or muddle — not the shortest, the correct one. | It only points; it won't walk the path for you, and it can't choose between two equally right answers. | Her stardust spins into a slow spiral and her glasses catch a faint blue light. |
| Biscuit (golden puppy) | Shortcut Wand: A wave of Biscuit's wand can open one quick shortcut through something in the way — a hedge, a wall of brambles, a long boring stretch. | She can never aim it on purpose; the shortcut opens somewhere *near* where she pointed, not exactly there. | A trail of gold sparkles and the smell of toasted bread. |

Behavior ties:
- Ember — directly powers up "leaves shimmering rainbow paths" and "treats your
  ideas like the most brilliant thing," with belief as the literal fuel.
- Clover — formalizes her map-reading and "very strong opinion about which path
  is correct" into a power that *is* that correctness.
- Biscuit — built from "once opened a shortcut through a whole forest by
  accident"; the can't-aim constraint keeps her lovable chaos intact.

---

## Adventurer (9-11)

Powers become navigational and read the world — routes, shadows, weather. Still
fully concrete, with constraints that demand the hero's own judgment.

| Companion | signaturePower | powerConstraint | sensoryTell |
|---|---|---|---|
| Atlas (blue-green scholar dragon) | Constellation Map: Atlas can draw the stars overhead down into a glowing map of the land, showing every route between here and where you're going. | He can map what *is* — paths, distances, landmarks — but not what's hidden or what hasn't happened yet; the map shows the terrain, not the danger on it. | A quiet hum like a held breath, and faint star-lines tracing the air in front of his glasses. |
| Nyx (cosmic black cat) | Shadow Passage: Nyx can step into one shadow and out of another nearby, and pull someone with her — always finding the way out of a closed or tangled place. | She can only travel between shadows she can already see, and only when she's certain; if she doubts, the passage won't open. | A breath of cool air, the smell of cold stone, and her cosmic-purple edges going briefly to smoke. |
| Kodiak (galaxy husky) | Storm-Sense: Kodiak reads stardust and scent to know what the weather and the land will do hours ahead, so the pack can move before trouble arrives. | He can feel *that* something is coming and roughly when, never exactly what; he reads nature, not people's choices. | His galaxy fur shimmers and ripples, and the air carries the smell of rain before any cloud shows. |

Behavior ties:
- Atlas — "mapped three routes before anyone finishes asking" becomes a literal
  star-map; "admits when the map was wrong" pairs with the can't-see-danger limit.
- Nyx — "moves along edges... always knows the way out" becomes a real shadow
  passage; the certainty constraint mirrors "won't say what she senses until sure."
- Kodiak — directly from "read stardust like a map and smell storms three hours
  before they arrive."

---

## Creator (12-14)

Powers turn analytical and design-oriented — finding flaws, sensing change,
remembering what worked. More abstract, less spectacle.

| Companion | signaturePower | powerConstraint | sensoryTell |
|---|---|---|---|
| Cipher (gear-breathing dragon) | Flaw-Finder: The gears Cipher breathes settle over any plan, machine, or structure and spin faster where it's about to fail, showing the one weak point. | He can find the flaw but not fix it — and only points to one at a time, the most important one. | The room goes quiet, gears and compass roses orbit slower, then his eyes flash gold when the weak point locks in. |
| Vesper (black cat) | Pattern-Break Sense: Vesper feels the single thing in a scene that doesn't fit the pattern — the detail that's wrong, the change about to land — before anyone else. | She senses *that* something is off, never the whole answer; naming it still takes the hero's own thinking. | A thin trail of purple smoke that drifts, against any breeze, toward the thing that doesn't belong. |
| Lore (white scholar wolf) | Precedent Scroll: Lore's scroll opens to a time something like this was solved before, offering the shape of a solution that worked — not a copy, a starting point. | The scroll only holds what's actually been tried before; for a truly new problem its pages stay blank and he says so. | The dry-paper rustle of a scroll unrolling and the smell of old ink and cedar. |

Behavior ties:
- Cipher — "finds the flaw in a plan before it's a problem... eyes flash gold"
  is lifted almost verbatim into the power and its tell.
- Vesper — "notices the thing that doesn't fit the pattern" made literal; the
  smoke tell reuses her established "trails purple smoke."
- Lore — "carries a scroll of things that worked before... refers to it without
  ceremony" becomes the power; blank-page limit preserves his honesty.

---

## Adolescent (15-17)

Subtle, internal, literary. Powers act on perception, timing, and truth rather
than terrain. Constraints carry emotional weight.

| Companion | signaturePower | powerConstraint | sensoryTell |
|---|---|---|---|
| Zephyr (hooded dragon) | Slipstream Foresight: Flying a half-step ahead, Zephyr can feel the next move before it's made and open a clean line through it — for the group, rarely for herself. | She reads the path, not the people on it; when something gets personal her foresight clouds and she pulls back. | The wind drops to a hush and a faint green seam of light traces the path a moment before anyone takes it. |
| Shade (black panther) | Clarifying Gaze: When Shade looks at a thing being avoided or dressed up, its true shape shows — the real reason, the actual stakes, plainly. | She can reveal what's true but never force anyone to accept it; the hero has to choose to look. | The purple energy around her stills, sound flattens for a breath, and her eyes hold yours without blinking. |
| Frost (blue-eyed wolf) | Read-the-Ground: Frost senses where footing is solid and where it will give way — in terrain, in plans, in moments — and moves first, trusting you to call him back. | He commits before he's certain; without the hero's signal to redirect, he can move wrong and has. | A drop in temperature, frost feathering across the ground where it's safe to step. |

Behavior ties:
- Zephyr — "already three moves ahead," "acts before the plan is finished,"
  and "a wound that makes her pull back when things get close" all map directly,
  the wound becoming the foresight-clouds constraint.
- Shade — "reads the room and reads you with equal precision" / challenges
  rationalization becomes a truth-revealing gaze; "she stays" underwrites the
  can't-force constraint.
- Frost — "moves before consensus... trusts you to call him back when he's
  wrong" is the power and its constraint in one.

---

## Adult (18+)

The most restrained. Powers are wisdom made tangible — pattern, presence,
endurance. They withhold as much as they give, and constraints are about
readiness, not capability.

| Companion | signaturePower | powerConstraint | sensoryTell |
|---|---|---|---|
| Tide (ancient teal dragon) | Deep-Pattern Sight: Tide sees how the present moment has happened before — which details will matter and which won't — and names the one that does. | She'll only name it once, and only what she's actually seen run its course; for the genuinely new, she says she doesn't know. | A slow swell of cool sea-air and the distant sound of water, as if a tide were turning somewhere out of sight. |
| Onyx (dark leopard) | Naming Stillness: Onyx can hold a moment still enough that what a room is really about surfaces on its own — the unspoken thing made plain without drama. | She offers it only when you're ready to hear it; pushed early, the stillness simply doesn't come. | The air goes quiet and unhurried, and her amber eyes settle on you and don't look away first. |
| Cinder (firelight wolf) | Keylight: When the way forward already exists but can't be seen, Cinder's firelight falls on it and makes it walkable — counsel given like a key, only when the door is there. | He can light a door that exists but never make one; if there's no way yet, his light shows only that it isn't time. | A low warmth like banked embers and the soft smell of woodsmoke, steady and unhurried. |

Behavior ties:
- Tide — "has seen this pattern before... knows which details matter because
  she's counted which ones didn't... gives counsel once" is the power verbatim.
- Onyx — "names what the room is actually about, without drama, and waits for
  you to catch up" becomes the stillness; the readiness limit is her patience.
- Cinder — "gives counsel like a key — only when the door is already there"
  is lifted straight into Keylight and its no-door constraint.

---

## Notes for founder review

Most drafts are pulled almost line-for-line from existing canon, so they should
read as natural extensions rather than new lore. Places worth a closer look:

- Biscuit's "can't aim it" constraint is an invention (extrapolated from the
  accidental-forest-shortcut line) — confirm that unpredictability stays
  charming and never strands the hero somewhere worse.
- Nyx's "Shadow Passage" implies short-range teleportation; if literal
  teleportation feels too strong for the brand, an alternative is "always finds
  an existing hidden way out" with no jump. Flagged because it's the boldest
  Adventurer-band power.
- Zephyr is the only companion whose constraint leans on an unnamed emotional
  wound ("foresight clouds when things get personal"). It's faithful to her
  behaviorPattern but is the most narratively loaded limit here — confirm it's
  the tone you want at 15-17.
- Tide and Cinder both have a "I don't know / it isn't time yet" failure mode by
  design (matching their restraint); confirm that's a feature, not a frustration,
  for the Adult band.
- Sensory tells reuse each companion's established cue where one exists (Mochi's
  moon charm, Vesper's purple smoke, Cipher's gold eyes, Onyx's amber gaze) so
  nothing new has to be drawn or animated.
