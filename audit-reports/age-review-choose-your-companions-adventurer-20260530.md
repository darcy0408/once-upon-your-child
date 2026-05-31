# Choose Your Companions — Adventurer (9–11) Age-Band Review

**Date:** 2026-05-30
**Screen:** Choose your companions (hero creator wizard, companions page)
**Band:** Adventurer (9–11)
**Widget files grounded:**
- `lib/screens/wizard_steps/hero_creator_step.dart` — `_buildAdventureTeamPage` (line 1762), `_buildCompanionShowcase`, `_buildCompanionGrid`, "Add from Photo / Add My Pet / Add a Grown-up" buttons (lines 1908–1964)
- `lib/widgets/hero_creator/pet_card.dart` — `HeroPetCard.didUpdateWidget` (line 85), `_addCompanionWithType` (line 267)
- `lib/widgets/hero_creator/companion_widgets.dart` — companion tile rendering

## Age-Band Check

Adventurer (9–11). User-confirmed. The cinematic dark-purple palette, named-companion lore, and gendered/sparkle particle effects all read squarely at this band — not babyish, not teen-edgy.

## Three-Lens Walkthrough

### Child lens (an Adventurer 9–11)
- **First noticed:** the 4 animated companion cards with sparkle particles and named characters ("Aller", "Bookie Robin", "Rex", "Kodiak")
- **Second:** the "Choose your companions" header
- **Third:** the "2 My Companions" counter at top with "Bookie Robin is ready!" status line
- **What they tap:** one of the named cards (highest visual draw — sparkle + name + 1-line lore hook)
- **What they want next:** clear "you picked this one" confirmation and a quick path to the next step

### Psychologist lens
- **Reading level:** mixed. "Three-power support sprite — burst, blast, harmonic" is upper-Adventurer at best — "sprite" is fine, "harmonic" is upper-band vocabulary, and "three-power support" reads gamer/Discord-fluent (skews boys, upper end). A 9-year-old reader at floor of band will skim past the lore.
- **Attention span:** the page requires scrolling to reach the "Next: Choose Your Scene" CTA. Adventurer attention can handle scroll, but a CTA below the fold risks the child not realizing the step is completable.
- **Working memory:** 4 named companions + 2 empty `+` slots + 3 "Add" buttons + "So Solo" toggle = ~10 simultaneous decisions visible. Upper end of Adventurer's chunking comfort.
- **Motor precision:** companion cards adequately sized; the small `+` placeholder slots at the top are at the lower margin.
- **Emotional safety:** the "So Solo — no companions" exit is a healthy opt-out that doesn't shame the child. Good.

### Parent lens
- **Love:** "So Solo" is a clear no-pressure opt-out. Companion lore is age-appropriate, not violent or scary. Optional photo upload (not required to proceed).
- **Distrust:** No privacy reassurance near "Add from Photo" — a parent tapping that button on behalf of their child has no idea where the photo goes. The recently-discovered "Add from Photo" bug (button did nothing visible — fixed in PR `fix/add-from-photo-auto-trigger-picker`) would have been the #1 trust-eroder for parents.

## Age-Appropriateness Scorecard

| Category | Score (1–10) | Evidence |
|---|---|---|
| Reading level | 6 | "Three-power support sprite — burst, blast, harmonic" leans upper-band; floor-of-band readers will skim. Companion names themselves are fine. |
| Visual maturity fit | 8 | Cinematic dark purple + sparkle particles + heroic-art portraits read aspirational, not toddler, not teen-edgy. On-brand. |
| Clarity | 5 | Two redundant ways to add companions (the `+` slot at top + the "Add from Photo / Add My Pet" buttons farther down). "Next: Choose Your Scene" CTA below fold on a Pixel/iPhone-sized screen. |
| Delight | 8 | Sparkle particles, named characters with backstories, status line ("Bookie Robin is ready!") all build engagement. |
| Frustration risk | 6 | The button bug (fixed) was high. "Next" being below fold + the redundant add-paths are mild ongoing friction. |
| Parent trust | 5 | No photo-handling reassurance. Engagement-loop framing (named companions w/ lore) is a mild parental flag, contextual. |
| Overall age fit | 7 | Good band targeting, mid-level polish needed. |

## Band-Shift Check

- **One younger (Explorer 6–8):** Companion lore vocabulary ("harmonic", "three-power support") is too dense. Names are fine. Sparkle effects still land. Scrolling past the Next CTA more dangerous at this band (lower attention span). Verdict: **too advanced for Explorer**.
- **One older (Creator 12–14):** Sparkle particles start to feel slightly babyish at 13+. Companion lore is fine. Layout still works. Verdict: **borderline acceptable for Creator's younger half (12), edges toward too-young by 14**.

This confirms targeting is correct for Adventurer specifically.

## Too Advanced or Too Babyish

- **Too advanced for some readers in band:** "Three-power support sprite — burst, blast, harmonic" assumes gaming/MMO vocabulary. A floor-of-band 9-year-old who doesn't game will not parse "three-power support". Recommend rewording.
- **Borderline babyish:** sparkle-particle density is heavy. At the upper edge of band (11), this starts to feel kid-show. Consider per-companion intensity tuning.

## Confusion & Frustration

| ID | Title | Lens | Severity | Element | Issue | Recommendation | Autonomous? | Effort |
|---|---|---|---|---|---|---|---|---|
| C-001 | "Add from Photo" did nothing | Child + Parent | **Blocker** | "Add from Photo" / "Add My Pet" buttons | Buttons set pending state but never invoked the photo picker — looked like the screen reset to itself | Fixed in PR `fix/add-from-photo-auto-trigger-picker` (commit `89827d63`). Picker now auto-opens. | Y | Done |
| C-002 | Redundant "add companion" entry points | Child | Medium | `+` slots at top of showcase row + the three "Add" buttons below | Two visually distinct ways to do the same thing creates "which is the right one?" confusion | Group the `+` slots and the three "Add" buttons into one labeled "Custom friends" section, OR remove the `+` slots from the showcase row and rely on the buttons | Y | M |
| C-003 | "Next" below the fold | Child | Medium | "Next: Choose Your Scene" button | A child who fills the team but doesn't scroll thinks the step is incomplete | Sticky-bottom the Next CTA OR ensure it stays in viewport once the team has ≥1 companion | Y | S |
| C-004 | "Harmonic" vocabulary skews older | Child + Psych | Low | Companion-card description text (`_buildCompanionGrid`) | Floor-of-band 9-year-olds will skim past dense gamer-vocab descriptions | Pass companion descriptions through a band-aware shortener; replace genre jargon with concrete actions ("blasts beams of light" instead of "harmonic burst") | N (founder-decision: content tone) | M |

## Layout & Usability

- **Tap targets:** the 4 companion cards are well-sized. The `+` slots in the showcase row are smaller than the band's 48px floor — measure and bump if needed.
- **Spacing:** vertical rhythm is generous, which is good for the band but pushes Next CTA below fold.
- **Visual hierarchy:** unclear. The 4 named cards (the actual companion picks) and the 3 "Add" buttons (custom companion paths) currently have equal visual weight, which they shouldn't — picking from the gallery is the primary path.
- **Redundancy:** the `+` slot row + the three "Add" buttons cover the same intent twice with different visual languages.
- **Navigation clarity:** Next CTA is the only forward path but it can disappear below the fold — that's the failure case to fix.

## Delight Levers

1. **Companion intro animation on first tap.** When a child taps a companion card for the first time, play a 600 ms "I choose you" zoom + particle burst from that card. *Why this band:* Adventurers respond to ritualistic commitment moments — making the choice feel earned, not casual.
2. **Team-assembly chord.** When the 2nd, 3rd, 4th companion is added, play a building chord/hum sound. *Why this band:* 9–11 year olds love "team complete" feedback from games (Pokemon, Sonic) and recognize the audio pattern.
3. **Per-companion micro-quote.** Replace the lore description with the companion's "first line" on tap — like a card flip revealing "I run faster than the wind." *Why this band:* Adventurers parse character through voice/dialog more readily than third-person description.
4. **Earned slot reveals.** Empty `+` slots could appear faded until the child has picked at least one named companion ("you've got a teammate now — add another?"). *Why this band:* progressive disclosure rewards each commitment without showing all the empty space at once.
5. **Visible team-status line.** "Bookie Robin is ready!" / "Trio assembled!" — this status line already exists; just make it bigger and more celebratory. *Why this band:* status acknowledgement scratches the same itch as game achievement banners.

## Parent Trust (Love / Distrust)

**Love (current):**
- "So Solo — no companions" opt-out, plainly visible
- Photo upload is optional, not required to advance
- Companion lore is age-appropriate, non-violent

**Distrust (current):**
- No "what happens to my child's photo?" reassurance near the "Add from Photo" button
- Button-did-nothing bug (fixed) would have been catastrophic for trust
- Engagement-loop styling (named characters w/ backstories) reads slightly more "trying to hook my kid" than necessary — mild flag

**Fix:** add a small `i` icon next to "Add from Photo" linking to a one-paragraph "your photo is used to generate your companion's portrait, then deleted from the AI provider within 24 hours" disclosure. Even if the actual retention story is more complex, the disclosure existing builds trust.

## Simplification

The cleanest single change: **merge the `+` showcase slots with the three "Add" buttons into one unified "Add a custom companion" section.** Either remove the `+` slots (let the gallery be picks-only and the buttons own the custom path) or make the buttons appear as filler-art when the `+` slots are tapped. The current two-paths-one-goal split is what drives most of the confusion findings above.

## Fix Plan

**P1 — Must Fix**
| # | Fix | Reference |
|---|---|---|
| 1 | "Add from Photo" / "Add My Pet" actually open the camera | DONE — PR `fix/add-from-photo-auto-trigger-picker`, commit `89827d63` |
| 2 | Make "Next: Choose Your Scene" CTA always visible (sticky-bottom or above-fold) | C-003 |
| 3 | Add photo-handling reassurance near "Add from Photo" | Parent-trust gap |

**P2 — Should Improve**
| # | Fix |
|---|---|
| 4 | Resolve the `+` slots vs "Add" buttons redundancy (C-002) |
| 5 | Reword dense companion descriptions for floor-of-band readers (C-004) |
| 6 | Add selection animation when a companion card is tapped (delight lever 1) |

**P3 — Delight Polish**
| # | Fix |
|---|---|
| 7 | Team-assembly chord (delight lever 2) |
| 8 | Per-companion first-line / quote on tap (delight lever 3) |
| 9 | Earned slot reveals (delight lever 4) |
| 10 | Bigger, more celebratory status line (delight lever 5) |

## Autonomous vs Founder-Decision

| Fix | Autonomous? | Files Touched | What I Need From You | Risk | Reversible? |
|---|---|---|---|---|---|
| 1. Photo picker fix | Y (done) | `lib/widgets/hero_creator/pet_card.dart` | Review PR | Low | Y |
| 2. Sticky-bottom Next CTA | Y | `hero_creator_step.dart` `_buildAdventureTeamPage` | None | Low | Y |
| 3. Photo-handling disclosure | Y on UI, Founder on copy | `hero_creator_step.dart`, `parent_controls_screen.dart` | One-paragraph retention copy | Low | Y |
| 4. Resolve `+`/Add redundancy | Founder-Decision | `_buildCompanionShowcase`, `_buildCompanionGrid` | Pick: keep `+` slots or only buttons | Medium | Y |
| 5. Reword companion descriptions | Founder-Decision | Companion data files | Provide age-band-fit copy | Low | Y |
| 6. Selection tap animation | Y | `companion_widgets.dart` | None | Low | Y |
| 7. Team-assembly chord | Founder-Decision | Asset addition needed | Provide / approve sound file | Low | Y |
| 8. Companion first-line quote | Founder-Decision | Companion data files | Provide per-companion quote | Low | Y |
| 9. Earned slot reveals | Y | `_buildCompanionShowcase` | None | Low | Y |
| 10. Bigger status line | Y | `_buildAdventureTeamPage` | None | Low | Y |

## Imagen Prompts

No new imagery needed for this screen — the existing companion portraits, sparkle effects, and slot art are working at this band. The disclosure icon (P1 #3) is a Material `info_outline` icon, no asset commission required.

## Final Checklist

The top three highest-impact fixes for this screen, in order:

1. **Confirm the photo-picker PR lands** (Pull #fix/add-from-photo-auto-trigger-picker) — converts the most painful Blocker from "broken" to "fixed"
2. **Make the Next CTA stay in viewport** — without this, kids who fill their team think the step is broken
3. **Add a 1-line photo-handling disclosure** — biggest single trust boost for the parent lens

Per-lens delight scores (1–10):
- **Child:** 7 — strong engagement signals, hampered by clarity issues
- **Psychologist:** 6 — band targeting is right but vocab + working-memory load need tightening
- **Parent:** 6 — opt-out is good, photo-handling silence is the gap

**Overall:** 7/10. Solid Adventurer-band targeting, fixable clarity and trust gaps. Worth landing the P1 fixes before MT-099's broader reader-screen refactor reaches this companions step.
