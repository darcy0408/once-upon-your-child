# Hero Saga — Creator-band (12–14) Superhero Mode

**Status:** Design + Phase 1 in progress
**Author:** Darcy + Claude, 2026-06-07
**Band:** Creator (12–14). Adolescent/Adult are a later extension.

## Vision

A superhero the kid **returns to and keeps playing** — a serialized comic, not a
one-shot. Each visit is a new *Issue* in an ongoing saga starring the hero they
forged, in a world that remembers their choices. Built for this band's core
developmental drive: *"who am I becoming?"* (identity + competence).

This replaces "no superhero option for Creator" (today Superhero Mode is gated to
Sprout/Explorer/Adventurer only — `imagine_it_screen.dart:351`).

## What already exists (we build on this, not from scratch)

- **`HeroProfile` persistence** (`lib/providers/hero_profile_provider.dart`, per-child
  SharedPreferences key) — already stores a chosen power/costume per child.
- **Welcome-back screen** (`superhero_welcome_back_screen.dart`) — returning heroes
  are recognized instead of re-onboarded. This is the seed of the "return" loop.
- **`SuperheroEntryScreen`** dispatcher — derives band from age, routes to
  welcome-back (returning) or costume picker (first run).
- **Power rosters** per band in `backend/data/superhero_matrix.py`.
- **Backend prompt tiers** `T7_SUPERHERO_EXPLORER` / `T8_SUPERHERO_ADVENTURER`
  (`backend/services/prompt_service.py` / `story_service.py`).
- **Pick-a-Path** branching story engine (reused for Issues).

## The experience

### 1. Forge your hero (once, saved to the profile)
- Codename · origin (*the accident / born with it / the gift / the choice* — pick or type)
- A primary + secondary power (Creator-tier roster — more nuanced than younger bands:
  e.g. strategy, tech, elemental, empathy, illusion)
- Costume + portrait (reuses the avatar→hero portrait pipeline)
- **A personal code** — *"What does your hero refuse to do? What do they fight for?"*
  The therapeutic heart; referenced throughout the saga as a moral compass.
- Home city (name + vibe)
- Auto-seeded **nemesis** embodying the opposite of the hero's code (built-in,
  personal conflict).

### 2. The Issue (each play session)
- Opens on a generated **comic cover** + a *"Previously on…"* recap.
- A self-contained case with branching Pick-a-Path choices that reference the
  hero's **code** and **past events**.
- Ends on a **cliffhanger** + a light one-tap reflection
  (*"Your hero chose mercy. What does that say about who they're becoming?"*).

### 3. Continuity engine *(the returnable magic)*
- Extend `HeroProfile` → `HeroSaga`: hero, code, nemesis state, allies, key choices
  (flags), reputation, issue #, season-arc progress. Seeds every Issue's prompt so
  the world genuinely evolves.

### 4. Progression
- Unlock signature moves / costume upgrades every few Issues; a **season** (~6–8
  Issues) builds to a finale that *tests the hero's code*, then rolls into Season 2.

## Why it fits 12–14
Identity (forge + code), competence (progression), moral weight (choices with
memory), the secret-identity/dual-life theme (being different in different rooms),
and the serialized "what happens next?" hook this band already loves.

## Safety
- No romance (consistent with the Creator-polish PR). Conflict is heroic/moral,
  never graphic. Villains are characterful, not gory or terrorizing.
- The personal-code + reflection beats are the therapeutic spine — growth framed
  as choice, never preachy.
- Reuses existing child-safety image + story safety settings.

## Phasing (small, shippable chunks)

### Phase 1 — Prove the tone *(this PR)*
Goal: a Creator kid can make a **genuinely great, mature-tuned superhero story**,
reusing existing infra. No new persistence beyond what HeroProfile already does.
1. **Expose** the "Be a superhero" entry on the Creator band (`imagine_it_screen.dart`
   gating + any story-type entry).
2. **Extend** `SuperheroEntryScreen` / costume / welcome-back to support
   `AgeBand.creator` (palette, copy register, power roster).
3. **Backend Creator tier**: add a Creator power roster in `superhero_matrix.py`
   + a `T9_SUPERHERO_CREATOR` prompt tier (mature, identity-forward, age-true).
4. Tests: prompt-tier unit test mirroring the Adventurer ones.

### Phase 2 — The returnable saga
`HeroSaga` model + continuity in the prompt; comic covers; "Previously on…";
cliffhangers; the personal-code + reflection beats.

### Phase 3 — Progression & polish
Signature-move unlocks, ally roster, season arc + finale, city map.

## Resolution philosophy (therapeutic guardrail)

Conflicts resolve **non-violently** — through courage, reasoning, empathy,
teamwork, OR **boundaries**. Crucially, **empathy is not universal redemption**:
- Reachable villains (ideological, overlooked, grieving) may *reconsider*.
- Manipulative or unsafe villains (the Benefactor, Nightjar, the Mirror) are
  *stopped and held accountable without harm or humiliation* — not "fixed" by the
  child.

We never imply a kid is responsible for redeeming someone who won't change.
Empathy never requires trust, forgiveness, or continued access. Each villain's
`softens` beat already encodes its correct resolution (reconsider vs boundary).

## Powers = codename + ability (frontend labels)

Each power is a hero-flavoured **codename** plus a plain **ability** so kids know
what they're picking (slice 3 picker shows both):

| Codename | Ability |
|---|---|
| Overclock | Super Speed |
| Skyline | Flight |
| Kinetic | Super Strength |
| Signal Sense | Heightened Perception |
| Magnetism | Inspiration & Rallying *(inspires cooperation — never mind-control)* |
| Anchor | Emotional Connection |
| Cool Head | Calm & De-escalation |
| Equalizer | Fairness & Balance |
| Mastermind | Strategy |
| Technomancer | Technology |

## Slice 2 — `T9_SUPERHERO_CREATOR` prompt requirements

Each generated Issue must include:
1. A visible crisis with real urgency.
2. A hidden truth / mystery behind it.
3. ≥2 genuinely plausible choices — no obvious good-vs-evil answer.
4. A moment where the hero's power **alone is not enough**.
5. A supporting character who disagrees for a *reasonable* reason.
6. A consequence driven by the villain's *belief*, not just their scheme/tech.
7. A resolution of **action + judgment** (not a lecture).
8. A brief, natural closing reflection — never therapy-speak.

Powers must **not** map rigidly to one lesson: sometimes the speed hero must
slow down, the strong hero must be gentle, the strategist must improvise, the
empath must hold a firm boundary.

**Tone (12–14, do NOT sound 8):** avoid cutesy sidekicks, exaggerated comic
dialogue, repetitive moral summaries, adults explaining the lesson, instant
forgiveness, a villain confessing everything in one speech, and "big feelings"
language. The hero earns information, makes mistakes, feels doubt, and discovers
two values can genuinely conflict.
