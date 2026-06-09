# Adolescent Antihero Saga — Design

**Status:** Proposed (design only — not yet built)
**Band:** Adolescent (15–17)
**Author:** Session ado-ux (UX audit follow-on)
**Related:** MT-235 Hero Saga (Creator); Superhero Mode (Explorer/Adventurer/Creator)

---

## 1. Why this exists

The Adolescent band is **hard-excluded** from the marquee feature of the two bands on either side of it.

- `imagine_it_screen.dart:351–356` gates the "Be a superhero!" button to `explorer || adventurer || creator`.
- `hero_creator_story_type_page.dart:596–598` gates the superhero story-type orb to `explorer || adventurer`.
- `superhero_entry_screen.dart:47–50` documents it directly: *"Sprout … Explorer … Adventurer … Creator (13–14 — Hero Saga) … **15+ has no tier yet.**"*
- A test asserts the gap: `imagine_it_screen_test.dart` — *"Adolescent band does NOT show the superhero button."*

So a 15–17 user watches Creator (12–14) get a serialized hero saga and gets nothing comparable. This is the single largest **delight gap** for the band.

**The trap:** do not simply unlock the existing flow. It is comic-book-juvenile and would read as babyish to a 16-year-old:
- `superhero_reveal_screen.dart` frames the portrait as a comic cover with an **"ISSUE #1"** tab and gold frame.
- 🦸 emoji and copy like **"Suiting up…"** / **"Turning {hero} into a superhero!"**
- Power names are playground-tier: **"Fly in the sky," "Be super fast," "Turn invisible," "Ride a dragon," "Do real magic," "Outsmart the villain"** (`hero_creator_story_type_page.dart:206–214`).

The answer is a **deliberate Adolescent tier** — a mature reskin of the *same saga engine*, not a new engine and not an unlock.

---

## 2. Concept

**Working title:** *The Double Life* (in-app saga name — see Open Questions for alternates: "Vigilante," "Shadow Saga").

Not a caped superhero. The protagonist is **someone ordinary with a power, secret, or edge no one around them knows about** — and the saga is about what they *do* with it and what it *costs* them. The register is the band's existing **`atmospheric`** story tone (`magic_review_step.dart:412`) and its cinematic teal/near-black identity (`age_band_theme.dart:465–505`).

Three pillars that separate it from the Creator superhero tier:

1. **Moral ambiguity over good-vs-evil.** The Creator tier already nudges this ("real villain, real stakes," `hero_creator_story_type_page.dart:604`). Adolescent goes further: the antagonist has a point; the protagonist's methods are questionable; choices have downsides.
2. **Consequence, not power fantasy.** Every issue, using the power costs something — a relationship, a secret slipping, a line crossed. This is the SEL spine (see §6), not gore or grimdark.
3. **A double life.** The tension is concealment vs. authenticity — the most age-resonant theme for 15–17 (identity, who-knows-the-real-me). Maps cleanly onto the band's "Inner Map" / "Under the surface" framing.

---

## 3. Reuse map — this is an extension, not a rebuild

The Hero Saga engine (MT-235) already exists and is band-parameterized. The work is **a new band branch + a new backend prompt tier + a reskin**, not new architecture.

| Layer | Existing asset | Adolescent change |
|---|---|---|
| Saga model | `lib/models/hero_saga.dart` | Reuse as-is (nemesis, status, next_hook). Possibly add `moralWeight`/`costPaid` fields (Phase 3). |
| Saga store | `lib/services/hero_saga_store.dart` | Reuse as-is. |
| Saga provider | `lib/providers/hero_saga_provider.dart` | Reuse; remove the Creator-only gate (below). |
| Entry dispatcher | `superhero_entry_screen.dart:47–66` | Add `adolescent` branch; load saga for adolescent too. |
| Saga recap | `superhero_welcome_back_screen.dart` ("PREVIOUSLY IN YOUR SAGA") | Reuse; re-skin gold→teal, comic→noir. |
| Costume picker | `superhero_costume_screen.dart` | Reframe as **"Signature"** (how they're known: a tag, a mask, a method). |
| Power picker | `superhero_power_screen.dart` | Reframe as **"Edge"** with mature names (§5). |
| Reveal | `superhero_reveal_screen.dart` | Replace comic "ISSUE #1" cover with a **noir title card** (§4). |
| Entry gates | `imagine_it_screen.dart:351–356`, `hero_creator_story_type_page.dart:596–598` | Add `adolescent` **only after T10 backend tier exists** (do not half-enable). |
| Backend tier | `T9_SUPERHERO_CREATOR` | New **`T10_ANTIHERO_ADOLESCENT`** prompt tier (§7). |

**Critical sequencing:** the entry gates must NOT add `adolescent` until `T10_ANTIHERO_ADOLESCENT` exists on the backend. Today, `superhero_entry_screen.dart:64–66` does `band == AgeBand.creator ? saga : null` — flipping the UI on without a backend tier would route an Adolescent request to a Creator-tier prompt (wrong register) or fail.

---

## 4. Visual / tonal reskin

The single most important change vs. the Creator flow.

| Element | Creator (current) | Adolescent (proposed) |
|---|---|---|
| Frame metaphor | Comic-book cover, "ISSUE #1" tab, gold frame | **Noir title card** — letterboxed, thin teal rule, episode label "Chapter 01" (not "Issue") |
| Accent | Gold `#FFD700` | Band teal `#00BCD4` / deep teal `#00838F` |
| Background | Bright | Near-black gradient `#070B14 → #0A1018` (band default) |
| Type | Fredoka (rounded, playful) | Merriweather for title, SourceSansPro for chrome (band fonts) |
| Loading copy | "Suiting up…" / "Turning {hero} into a superhero!" | **"Going under…"** / **"Setting the scene for {hero}…"** |
| Emoji | 🦸 throughout | None (band `showParticles:false`, `sparkleIntensity:0.0`) |
| Reveal motion | Sparkle burst | Slow fade + subtle film-grain; gated by reduce-motion |

---

## 5. The "Edge" roster (replaces powers)

Capability framed as something a real teenager could *almost* have, not flight/laser-eyes. Each is dual-edged (the cost is baked into the name's subtext), which feeds the consequence pillar.

| Edge | What it does | Built-in cost (story hook) |
|---|---|---|
| **Read the room** | Senses what people are really feeling/hiding | Can't switch it off; knows things they wish they didn't |
| **Bend the odds** | Small probabilities tilt their way | The luck has to come from *somewhere* |
| **Never get caught** | Slips notice, covers tracks | The better they hide, the more alone they are |
| **Borrowed time** | Brief replays / second tries | Each rewind frays something |
| **The tell** | Always knows when someone's lying | Including the people they love |
| **Ghost** | Move unseen, unheard | Easy to disappear for real |

Selecting an Edge seeds the backend prompt's conflict and the nemesis's counter (see §7). Roster size: ship 6 (parity with Explorer's 6; Creator has 8 — can expand in Phase 3).

---

## 6. SEL / safety spine

This is a children's app; "antihero" must stay age-appropriate and therapeutic, not edgelord.

- **Through-line:** power & responsibility → concealment vs. authenticity → consequences & repair. Every saga arc should let the protagonist face a cost and choose how to respond.
- **Guardrails (carry forward existing content-safety):**
  - No glorified real-world violence, weapons, self-harm, or substances. The "edge" is interpersonal/perceptual, not lethal.
  - Villains are *people with reasons*, not monsters; resolution favors understanding/consequence over domination.
  - Reuse the existing crisis-resources off-ramp pattern (`life_quest_screen.dart` `_crisisQuestIds`) if an arc touches genuinely heavy themes.
- **Tone lock (mirror the boundary-skills pattern):** consequence-not-narration; the cost is *shown* through events, not lectured. ~1-in-N issues centers the cost explicitly.
- Backend output safety filter already applies to all generated story text — no new bypass.

---

## 7. Backend — `T10_ANTIHERO_ADOLESCENT`

A new prompt tier parallel to `T9_SUPERHERO_CREATOR`. Inputs: protagonist (name/desire/archetype/Edge), nemesis state, `prior_saga` (the returnable-saga continuity from MT-235), chosen Signature.

Prompt register requirements:
- Second-person or close-third, `atmospheric` tone, Young-Adult reading level.
- Open *in medias res*; end every issue on a `next_hook` cliffhanger (already in the saga model).
- Bake the Edge's **cost** into the issue's central tension.
- Nemesis persists and adapts across issues (`prior_saga.nemesis`, `prior_saga.next_hook`).
- Word ceiling per the band's existing per-page scaling.

Output must conform to the existing story JSON contract so the reader/saga store consume it unchanged.

---

## 8. Phased plan

**Phase 1 — MVP (vertical slice, one Edge, no new art)**
1. Add `T10_ANTIHERO_ADOLESCENT` backend tier + prompt.
2. `superhero_entry_screen.dart`: add `adolescent` branch; load saga for adolescent (`band == AgeBand.creator || band == AgeBand.adolescent`).
3. Reskin copy only (loading strings, "Chapter" not "Issue," teal not gold) behind a band check — no new art yet.
4. Reframe power picker labels to the Edge roster (§5) for adolescent.
5. Flip the two entry gates to include `adolescent`.
6. Tests: a six-band test asserting adolescent now *shows* the entry (inverse of the current exclusion test) + a saga round-trip test for adolescent.

**Phase 2 — Identity polish**
- Noir reveal title card (replace comic cover for adolescent).
- "Signature" reframe of the costume screen.
- Welcome-back recap re-skin (teal/noir).

**Phase 3 — Depth**
- Nemesis arcs that escalate across issues; `moralWeight`/`costPaid` on the saga model.
- Expand Edge roster to 8; ally roster; season finale (mirror Creator Hero Saga Phase 3 plans).
- Optional: Adolescent ↔ Adult tier sharing.

---

## 9. Open questions for Darcy

1. **In-app name:** *The Double Life* / *Vigilante* / *Shadow Saga* / keep "Hero Saga" with an antihero skin? (Affects copy + analytics.)
2. **How dark is too dark?** Confirm the content ceiling — "morally grey & consequence-driven" vs. keeping it closer to the Creator "real stakes" line.
3. **Scope of first ship:** Phase 1 vertical slice (one Edge, copy reskin, shared art) to validate appetite, or wait for Phase 2 art before exposing it?
4. **Reuse vs. fork the saga model:** add `moralWeight`/`costPaid` now, or keep the Creator model and layer cost in the prompt only?

---

## 10. Suggested tracking

- **MT (new):** "Adolescent Antihero Saga — Phase 1 vertical slice (T10 tier + entry + Edge reskin)."
- Cross-reference MT-235 (Hero Saga) and the Superhero Mode work as the engine being extended.
