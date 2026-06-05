# Audit 14 — Story Quality and Persona Walkthrough: Adventurer Band (Ages 9-11)

Date: 2026-06-03
Scope: Full wizard-to-reader journey and generated-story craft for the
Adventurer age band, viewed through four personas (child-9, child-11,
parent-of-9, parent-of-11).
Method: code and prompt-template review of the live generation path, plus
three live Gemini stories (hybrid sampling) scored against a craft rubric that
deliberately separates narrative engineering from vocabulary.
Evidence: every craft finding cites a generated sample (hashed, in
`generation-samples/`) and the responsible prompt fragment by file:line.

## Executive Summary

The founder's instinct is correct and the cause is mechanical, not mysterious.
Adventurer stories are strong on description and word choice and weak on
supporting-character depth, plot construction, stakes, and excitement. Those
four weak dimensions are exactly the ones the engine stops scaffolding for this
band.

The single most important finding: the only place in the standard story engine
that mandates a companion emotional arc, a rule-of-three escalation, and a
page-ending hook is the `YOUNG READER DELIGHT RULES` block, and that block is
gated to age 7 and under (`backend/services/story_service.py:884-902`). From
age 8 up — the entire Adventurer band — those three craft engines are simply
switched off. Older children, who can handle more story craft, receive less.

Two structural facts compound it. First, the UI treats 9-11 as one "Adventurer"
band, but the backend routes age 9-10 to the `8-10` constraint table and age 11
to the `11-13` table (`story_service.py:452`). The `11-13` table carries hard
complexity targets (an internal-reflection beat, a no-win-option decision) that
the `8-10` table lacks, so a 9-year-old's story is structurally thinner than an
11-year-old's from identical inputs — confirmed live: Sample A (age 9) scored
4.7 overall; Sample B (age 11, same inputs) scored 6.5. Second, companions read
flat partly because their identity never fully reaches the model: three of the
four Adventurer companions (Atlas, Nyx, Kodiak) fail an id match in
`WizardDataMapper._getCompanionData` (`wizard_data_mapper.dart:741`) and arrive
as name plus a behavior mannerism only — their powers and sensory tells are
dropped — and even matched companions lose their `description` because the
engine never renders it (`story_service.py:692-709`).

Diction is not the problem. Across all three samples Language scored 8/10; the
prose is vivid and age-pitched. The gap to a 10/10 narrative is craft, and craft
is fixable in prompt strings.

### Top 5 changes by score-lift-per-effort

Ranked highest lift-per-effort first. Full before/after directives in the
Remediation Plan.

1. R1 — Add a supporting-cast depth block for ages 8-12 (companion want, flaw,
   arc, and one resolution beat only they can do). Effort: Low (prompt string).
   Lift: Supporting Cast +3-4, Plot +1.
2. R2 — Add a momentum block for ages 8-12 (escalate the problem twice, one
   try/fail before the win, curiosity page-hooks — no fear). Effort: Low.
   Lift: Stakes +2-3, Excitement +2.
3. R4 — Extend a light `hard_complexity_constraints` floor down to age 9-10 so
   the 9-year-old gets the no-win decision and reflection beat the 11-year-old
   already gets. Effort: Low. Lift: age-9 Plot +2, Stakes +1.
4. R3 — Render companion `description` in the engine and forward it for every
   companion (closes the Atlas/Nyx/Kodiak power-drop). Effort: Low.
   Lift: Supporting Cast +1-2.
5. R5 — Pass companion behavior/description into Pick-a-Path and lift the
   2-companion cap (`interactive_adventure_prompt_builder.py:1396-1411`).
   Effort: Medium. Lift: Pick-a-Path Supporting Cast +3.

Projected effect: Standard age-9 overall 4.7 to ~7.5; age-11 6.5 to ~8.3. The
remaining path to 10/10 is iteration plus illustration and narration, covered in
the Projected 10/10 Path.

## Journey Map

The wizard presents four steps for the Adventurer band. Internally the steps
live inside `HeroCreatorStep` plus `MagicReviewStep`; the moon-phase progress
labels are `['My Character', 'My Companions', 'My Setting', launchStoryLabel]`
(`lib/screens/wizard_story_screen.dart:656-661`).

| # | Step | Key copy (file:line) | Taps | Wait |
|---|------|----------------------|------|------|
| 1 | Hero Creator | "What is your hero's name?" (`hero_creator_step.dart:1446`); gender is Boy/Girl only | 4-5 | Avatar gen 3-10s if photo-to-cartoon |
| 2 | Companion Selector | "Choose a Travel Buddy" / "Who will join you on this adventure?" (`companion_selector_step.dart:781,793`); rich descriptions shown; "Go Solo" fallback | 1-4 | None |
| 3 | Setting / Feeling | scenario carousel with a one-line mission hook for Adventurer+; Guardian Mode behind a "What is A + B?" math gate | 1-10 | None |
| 4 | Magic Review | "Review Your Adventure" (`magic_review_step.dart:1245`); length chips Short tale / Story time / Big adventure; launch | 1-2 | 3-2-1 countdown (first 3 launches) then 15-30s |
| - | Generation wait | Single line "Your adventure is being written..." plus spinner; phase progress is shown only to mature bands (`magic_review_step.dart:127,492`) | - | 15-30s |
| - | Reader | Open-book reader, "Reading Level: Middle Grade" badge, favorite/share/text-scale | per page | - |

Companions are presented with full personality descriptions in the selector
(not names only) — for example Atlas: "A blue-green scholar dragon with a
compass medallion who knows every constellation..."
(`lib/data/companion_data.dart` and `companion_personality_data.dart:32-42`).
The journey-level problem is not what the child sees; it is how little of that
identity survives the trip to the model (see Root-Cause RC-3).

## Four-Persona Friction Log

Category is Friction (journey) or Craft (story). Severity: Critical / High /
Medium / Low, where Critical breaks engagement for a 9-11 reader or makes the
story forgettable.

| ID | Title | Perspective | Category | Severity | File:Line | Description | Remediation | Effort |
|----|-------|-------------|----------|----------|-----------|-------------|-------------|--------|
| FR-01 | Companion personality shown but discarded | parent-of-9 | Friction | High | wizard_data_mapper.dart:741; story_service.py:692-709 | The selector sells Atlas/Nyx/Kodiak with vivid descriptions; the model never receives those descriptions, so the story does not deliver the companion the parent was sold | R3 | Low |
| FR-02 | Gender is Boy/Girl only | parent-of-9 | Friction | Low | hero_creator_step.dart (gender picker) | Binary picker; no neutral option for a child who wants one | Add a third option / free pronoun field | Low |
| FR-03 | Guardian Mode math gate adds friction | parent-of-11 | Friction | Medium | feeling_selection_step.dart (Story DNA gate) | A parent personalizing the story must solve "What is A + B?" before the deeper inputs unlock; meant to keep kids out, but it taxes the buying parent | Remember unlock per session | Low |
| FR-04 | Single-line wait feels long | child-9 | Friction | Medium | magic_review_step.dart:127,492 | Adventurer sees one static line plus a spinner for 15-30s; mature bands get phase progress. A 9-year-old reads the wait as "stuck" | Give 9-11 the staged progress copy | Low |
| FR-05 | Some selector copy stretches a struggling 9yo | child-9 | Friction | Low | companion_data.dart:178,196 | "constellation", "cosmic", "medallion" are great for 11 but stretchy for a 9-year-old still consolidating reading; fine with audio, but audio is opt-in | Keep; rely on the Magic Ear button | Low |
| FR-06 | Experience reads young to an 11yo | child-11 | Friction | Medium | wizard_story_screen.dart:656-661 | Travel Buddy framing, emoji, countdown — an 11-year-old can find the wrapper babyish even when the story is fine | Offer a lighter-chrome variant at the top of the band | Medium |
| CR-01 | Companions are set dressing, not agents | child-11 | Craft | Critical | story_service.py:884-902 (gating) | In Sample A (`ea8d1f`) Atlas and Nyx stay perfectly in character but take no decisive action, want nothing, and never change; Zoe solves the climax alone | R1 | Low |
| CR-02 | Stakes do not escalate | child-9 | Craft | High | story_service.py:884-902; AGE_CONSTRAINTS 8-10 | Sample A establishes a threat (vanishing path) then never tightens it; the crystal is woken on the first real attempt with no setback | R2 | Low |
| CR-03 | Resolution is unearned | parent-of-9 | Craft | High | story_service.py:933-934 | Sample A resolves by Zoe imagining "energy from her own heart" — a power introduced at the climax, not set up earlier; contrast Sample B (`0dfef1`), which resolves through Zoe's established geology knowledge | R2, R4 | Low |
| CR-04 | 9-year-old story is thinner than 11-year-old story | parent-of-11 | Craft | Critical | story_service.py:452,853-859 | Same inputs: Sample A (age 9) has no internal-reflection beat and no no-win decision; Sample B (age 11) has both, because only the 11-13 band carries hard complexity targets | R4 | Low |
| CR-05 | No page-turn pull | child-9 | Craft | Medium | story_service.py:891,900 (hook rule gated to age 7) | The mandatory page-ending hook exists only for ages 5-7; Adventurer pages often end on calm, resolved beats | R2 | Low |
| CR-06 | Pick-a-Path companions are name-only | child-11 | Craft | High | interactive_adventure_prompt_builder.py:1396-1411 | Interactive mode sends companions as "{name} [SPEAKING]" with no description, power, or behavior, and caps at 2 — flatter than Standard | R5 | Medium |
| CR-07 | Learning-to-Read is a mode mismatch risk | parent-of-11 | Craft | Low | story_service.py:1397-1406 | For ages 9-12 LTR produces limericks (decodable, deliberate for reluctant readers); valid but easy to mis-sell to an 11-year-old expecting a "real" story | Label the mode clearly in UI | Low |

## Story Craft Scorecard

Full machine-readable matrix in `story-scorecard.csv` (3 stories x 4 personas).
Sub-scores are the editor's craft assessment of the text; the experiential
dimensions (Plot, Stakes, Excitement) and Language reading-fit are adjusted per
persona where developmental position genuinely changes perception. Character
Depth and Supporting Cast are properties of the text and held constant across
personas.

Editor base scores (craft, persona-invariant dimensions):

| Sample | Hash | Char | Cast | Plot | Stakes | Excite | Lang | Note |
|--------|------|------|------|------|--------|--------|------|------|
| A (age 9) | `ea8d1f` | 6 | 3 | 4 | 3 | 4 | 8 | Companions inert; linear plot; no escalation; climax power unset up |
| B (age 11) | `0dfef1` | 7 | 5 | 7 | 6 | 6 | 8 | Internal-monologue beat, no-win decision, earned geology resolution |
| C (age 10) | `4639b4` | 7 | 6 | 7 | 5 | 6 | 8 | Robin is an active agent (kept her power payload); warm emotional arc |

Divergence worth noting: the largest persona split is on Sample A between
child-9 (4.7) and child-11 (4.2) — an 11-year-old finds the same story too easy.
The largest cross-sample split is Supporting Cast: 3 (Atlas/Nyx, powers dropped)
versus 6 (Robin, full payload) — a direct, controlled demonstration of RC-3.

### Craft-vs-diction separation

Language scored 8 on every sample; Stakes/Excitement averaged 4-5. The "fun
words" are doing their job and are not the deficit. Holding Language aside, the
unweighted craft mean (Char, Cast, Plot, Stakes, Excite) is 4.0 for the
9-year-old sample versus 6.2 for the 11-year-old — the gap the founder feels.

### Supporting-character depth test

Applying the test "does each companion show a distinct want, flaw, or voice, or
function as set dressing": Atlas and Nyx (Sample A) pass on voice/mannerism,
fail on want, flaw, and arc — set dressing. Robin (Sample C) passes on voice and
recurring function (she scouts, distracts a squirrel and a terrier, brings
gifts) but still has no internal want or arc. No companion in any sample changes
across the story.

### Stakes ladder check

Sample A: flat — one threat stated on page 3, unchanged until resolution on page
10. Sample B: a genuine ladder — dimming becomes more frequent (p6), a "deep
shudder" plunges sections dark (p7), then the three-exits no-win decision (p11).
Sample C: low external stakes by design (quiet emotional theme), internal
tension only. The difference between A and B is entirely attributable to the
11-13 band's hard complexity targets.

### 9-vs-11 differentiation analysis

The band needs intra-band tiering or a unified-and-raised floor. Today a
9-year-old and an 11-year-old in the same UI band get different constraint
tables, and the younger one gets the weaker one. Recommendation: do not lower
the 11-year-old; raise the 9-10 floor (R4) so both get a no-win decision and a
reflection beat, scaled in length. This closes most of the perceived gap without
changing word-count constraints (which the audit was instructed not to touch).

## Root-Cause Analysis

### RC-1 (Critical) — Craft scaffolding is gated to age 7 and under

`young_delight_rules` is the only block that mandates a companion arc
(doubt to courage), a rule-of-three escalation, and a mandatory page-ending hook
— and it is built only for `age <= 5` and `age <= 7`
(`story_service.py:884-902`). For ages 8+ the variable stays empty and the
prompt loses all three. The Adventurer band therefore has no enforced companion
arc, no enforced escalation, and no page-hook. This is the primary driver of
flat companions (CR-01), flat stakes (CR-02), and weak pacing (CR-05).

### RC-2 (Critical) — One UI band straddles two backend constraint tables

`_get_age_band` maps age 9-10 to `8-10` and age 11 to `11-13`
(`story_service.py:452`). Only the `11-13` path sets
`hard_complexity_constraints` — 30% compound/complex sentences, a no-win
decision, an internal reflection paragraph (`story_service.py:853-859`). The
`8-10` path sets none. Result: structurally thinner stories for 9-10-year-olds
(CR-04), confirmed by Sample A vs B. The same straddle exists independently in
the Pick-a-Path builder (`interactive_adventure_prompt_builder.py:278-294`,
with `MORAL_COMPLEXITY_INSTRUCTION` gated to 11-13 at line 510).

### RC-3 (High) — Companion identity is lost before the model sees it

Two compounding defects:
1. `WizardDataMapper._getCompanionData` matches the selected companion against
   `magicCompanions`, whose ids are `dragon/owl/cat/dog/unicorn/fox/robin`
   (`wizard_data_mapper.dart:741-752`, `companion_data.dart:28-106`). "Atlas",
   "Nyx", and "Kodiak" match none, so they ship as name plus a band behavior
   line only — `signaturePower`, `powerConstraint`, `sensoryTell` are dropped.
   Only "Rockin' Robin" matches (contains "robin").
2. The engine renders `signaturePower`, `powerConstraint`, `sensoryTell`, and
   `behaviorPattern` but never renders `description`
   (`story_service.py:692-709`), so even a fully matched companion loses the
   exact text the selector showed the user.

This is why Robin (Sample C, full payload) is an active agent at Supporting Cast
6 while Atlas/Nyx (Sample A, powers dropped) sit at 3.

### RC-4 (High) — The standard path has no "companion enables the resolution" rule

The "Three-Key Lock" climax requirement (hero ability + companion power +
setting must combine to resolve) exists in `PromptService`
(`prompt_service.py:134-142`) but `PromptService.build_story_prompt` is wired
only for the superhero theme (`story_tasks.py:1026`). Standard stories go
through `AdvancedStoryEngine.generate_enhanced_prompt`
(`story_tasks.py:1097`), which has no equivalent. So nothing forces the
companion to matter to the plot — the engine asks only that they "be in the
story" and "follow this behavior throughout" (`story_service.py:711-714,921`).
The good mechanism exists in a sibling module and is not in the active path.

### RC-5 (Engine-level) — Companions are mannerisms, not characters

Even where the behavior pattern is rich and does reach the model (it is genuinely
well written — `companion_personality_data.dart:32-42`), it describes a recurring
tic ("Atlas calculates", "Nyx moves along edges") rather than a want, a flaw, or
a capacity to change. The prompt has no instruction asking supporting characters
to want something or to be changed by events. Mannerism keeps them consistent; it
cannot make them feel alive. No clear template source mandates arc for this band —
flag as engine-level, addressed by R1.

## Remediation Plan

All rewrites are additive prompt strings or small render changes. None alters
word-count constraints. Order follows the lift-per-effort ranking.

### R1 — Supporting-cast depth block (ages 8-12)

`story_service.py`, extend the `young_delight_rules` chain (currently ends at
`elif age <= 7`):

```python
elif age <= 12:
    young_delight_rules = f"""
**SUPPORTING-CAST DEPTH RULES** (mandatory for this age):
1. COMPANION WANT + FLAW: Each named companion has ONE concrete want of their
   own and ONE flaw that gets in its way, distinct from {character}'s goal. Show
   the want through action early; let the flaw cost something at least once.
2. COMPANION ARC: At least one companion changes across the story. A belief they
   hold at the start is tested and shifts by the end. Do not announce it; show it
   in what they choose differently.
3. COMPANION DRIVES A BEAT: The resolution depends on at least one companion
   doing something only they would do (their power, knowledge, or nerve).
   {character} cannot solve the climax alone.
4. DISTINCT VOICE: Give each companion a verbal rhythm so two lines of their
   dialogue, names removed, are still tellable apart.
"""
```

Expected: Supporting Cast 3 to 6-7; Plot +1 (companions now generate beats).

### R2 — Momentum block (ages 8-12)

Add alongside R1 (same band branch), keeping excitement curiosity-driven, not
fear-driven, per safety:

```text
**MOMENTUM RULES (ages 8-12)**:
- ESCALATION: The central problem gets harder at least twice before it is
  solved. Name what raises the stakes each time (less time, higher cost, or a
  complication the first fix caused).
- TRY / FAIL: {character} attempts a solution that fails or falls short at least
  once before the real resolution. The final fix must use something established
  earlier in the story, never a power or object introduced at the end.
- FORWARD PULL: End most non-final pages on an open question, a discovery, or an
  action mid-motion. Keep it curiosity, not fear: no peril cliffhangers, no
  threats aimed at the hero.
```

Expected: Stakes 3 to 5-6; Excitement 4 to 6; fixes CR-02, CR-03, CR-05.

### R3 — Render and forward companion description

`story_service.py:698` (add the description line):

```python
desc = c.get("description", "")
chars.append(
    f"{name}"
    + (f" | Who they are: {desc}" if desc else "")
    + (f" | Power: {power}" if power else "")
    + (f" | Constraint: {constraint}" if constraint else "")
    + (f" | Sensory: {sensory}" if sensory else "")
)
```

`wizard_data_mapper.dart` — forward the selector's `Companion.description` for
every companion, including unmatched ones, by passing the description shown in
the UI (available from `defaultCompanions`) into the `companionsOther` dicts even
when `_getCompanionData` returns null. Thorough variant: add the band companions'
power/constraint/sensory to a registry keyed `${band}_${id}` parallel to
`companionBehaviorPatterns`, and look them up the same way.

Expected: Supporting Cast +1-2, concentrated on Atlas/Nyx/Kodiak; removes the
"sold one companion, delivered another" gap (FR-01).

### R4 — Light complexity floor for ages 9-10

`story_service.py:853` (insert before the `age >= 11` branch):

```python
if age >= 9 and age <= 10:
    hard_complexity_constraints = (
        "Include at least one moment where the hero must choose between two "
        "imperfect options and name the cost of the one they pick. "
        "Include at least one short internal reflection (2-3 sentences) where "
        "the hero weighs what to do. "
        "Build a two-step problem: solving the first part reveals or creates the "
        "harder second part."
    )
elif age >= 11 and age <= 13:
    ...  # unchanged
```

Expected: closes most of the age-9 vs age-11 gap (CR-04, RC-2); age-9 Plot +2,
Stakes +1, without touching word counts.

### R5 — Pick-a-Path companion context

`interactive_adventure_prompt_builder.py:1396-1411`:

```python
@staticmethod
def _build_companion_context(companions):
    if not companions:
        return "solo on this adventure"
    out = []
    for comp in companions[:3]:  # was [:2]
        name = comp.get("name", "friend")
        if "species" in comp:
            out.append(f"{name} the {comp.get('species', 'pet')} [ANIMAL]")
        else:
            who = comp.get("behaviorPattern") or comp.get("description") or ""
            tail = f" - {who}" if who else ""
            out.append(f"{name} [SPEAKING]{tail}")
    return "joined by " + " and ".join(out)
```

Requires the interactive route to forward `behaviorPattern`/`description` (the
Standard payload already carries them). Expected: Pick-a-Path Supporting Cast
~2 to ~5 (CR-06).

### Secondary (journey)

- FR-04: give the 9-11 band the staged progress copy mature bands already get
  (`magic_review_step.dart:492`). Low effort, reduces perceived wait.
- FR-03: persist the Guardian Mode unlock for the session so the math gate is
  asked once. Low effort.
- FR-06: offer a lighter-chrome presentation toggle at the top of the band for
  the 11-year-old who finds Travel-Buddy framing young. Medium.

## Projected 10/10 Path

| Sample | Now | After R1+R2 | After R1+R2+R3+R4 | Path to 10 |
|--------|-----|-------------|-------------------|------------|
| A (age 9) | 4.7 | ~6.6 | ~7.5 | Iterate companion-arc wording; add illustration + narration; one more escalation beat |
| B (age 11) | 6.5 | ~7.8 | ~8.3 | Push a costly decision with lasting consequence; let a companion arc intersect the theme |
| C (age 10) | 6.5 | ~7.6 | ~8.0 | Give Robin a want of her own; raise external stakes a notch without adding fear |

Sequence: ship R1, R2, R4 together (one prompt-string change plus one tiny
conditional — the highest combined lift), then R3, then R5. Re-run
`backend/tests/quality/adventurer_audit_gen.py` and re-score the same three
inputs to confirm the deltas before broadening. The route from ~8 to 10 is no
longer a single code defect; it is craft iteration on the new instructions plus
the multimodal layer (illustration consistency and narration), which are
out of scope here but are what turns a structurally sound story into a memorable
one.

## Validation — Before/After (R1 + R2 + R4 implemented)

R1, R2, and R4 were implemented in `story_service.py` (commit on branch
`adventurer-craft-fixes`) and re-run on identical inputs. Block scoping was
verified: cast+momentum fire ages 8-12; the 9-10 floor fires only at 9-10 (not
age 8 or 11); the 11-13 targets are untouched.

| Sample | Dim (Char/Cast/Plot/Stakes/Excite/Lang) | Before (`0810`) | After (`0946`) | Overall |
|--------|------------------------------------------|-----------------|----------------|---------|
| A age 9 (`14198d0aabdc`) | | 6/3/4/3/4/8 | 7/6/6.5/5.5/6/8 | 4.7 to ~6.5 (+1.8) |
| B age 11 (`560f27858a32`) | | 7/5/7/6/6/8 | 8/7.5/7.5/7/7/8.5 | 6.5 to ~7.6 (+1.1) |
| C age 10 (`0f760b80b4f2`) | | 7/6/7/5/6/8 | 7.5/6.5/7/5.5/6.5/8 | 6.5 to ~6.8 (+0.3) |

Observed effects mapping to the new rules:
- Age-9 climax is no longer solved alone — in after-A, Nyx diagnoses the broken
  flow, Atlas finds and guides the climb, Zoe executes, using shards established
  earlier in the story (R1 rule 3 + R2 set-up rule). The prior hand-wavy
  "imagine energy from her heart" resolution is gone.
- Companions now arc — after-B Atlas shifts from rigid map-perfectionism to
  trusting the unmappable; Nyx moves from silent observer to "trusting her own
  voice." Baseline B had neither (R1 rule 2).
- Age-9 now carries the no-win decision and reflection beats it previously
  lacked (R4).

Caveats: single draw per case, so decimals carry generation variance; the robust
signal is that the age-9 band lifted most, as designed.

Follow-ups implemented after this run (commit `43af74b1`, not yet re-validated):
R3 (engine renders companion `description`; the adventurer companions Atlas/Nyx/
Kodiak now forward their species so the model stops writing them as humans), and
two wording tweaks — the try/fail rule now demands a visible setback (the after-A
fix worked first try with no real setback), and the companion want must be shown
through action rather than stated ("He wanted his maps to be perfect"). A
consolidated multi-draw validation (3 draws each at age 9 and 11) of the full
R1+R2+R4+R3 stack should precede any production rollout.

### Multi-draw validation (n=3 per band, full R1+R2+R4+R3 stack)

Run `20260603-1018` via `backend/tests/quality/adventurer_validation.py`
(drafts in `generation-samples/validation/`). Automated signals across all six
drafts: R3 species rendering 6/6 (Atlas reads as a dragon, Nyx as a cat in every
draft — the pre-fix "companions written as humans" failure is gone); told-want
anti-pattern 0/6 (no "wanted ..." tells); try/fail setback language 5/6.

Craft read: both clean age-9 drafts landed ~6.9-7.1 (draw2 — the warm-pebble fix
fails and accelerates the dimming, Nyx drives the diagnosis, Atlas arcs to
"appreciation for the unmappable"; draw3 — the lantern backfires, Nyx creates the
reflective sheath the climax needs, resolution uses a quartz set up earlier). The
age-11 draft read closely scored ~7.8 (Nyx balances the crystal — Zoe "hadn't
fixed it herself" — Atlas arcs to "a force beyond cartography", full escalation
ladder); the other two age-11 drafts carried the same automated signals. So the
lift holds on average, not just on one draw: age 9 ~4.7 to ~7.0; age 11 ~6.5 to
~7.5+.

One regression to watch before rollout: age-9 draw1 overran to 2324 words / 22
pages (target 1200-1800) and its JSON came back malformed (regex-salvaged). The
richer instructions appear to raise both length and JSON-malformation risk on
some draws — worth a tighter word-ceiling note for the 8-10 band and an eye on
the salvage-rate metric once this ships.

## Safety Notes

No remediation weakens content safety, age-appropriateness, or COPPA-driven
friction. R2 explicitly forbids fear, peril, and threat-to-child cliffhangers as
excitement mechanics. The emotionally-charged sample (Sample C, moving house)
was handled with the existing adaptability scaffolding and stayed warm; richer
plot for this band must not mean heavier trauma. Generated content depicting
only fictional heroes in safe contexts is referenced by hash, not reproduced
beyond the samples directory.

## Methodology and Fidelity Notes

- Live generation used the production model (`gemini-2.5-flash`) through the
  exact standard path (`AdvancedStoryEngine.generate_enhanced_prompt`), with
  companion payloads reproducing `WizardDataMapper` output including its drops.
- Hybrid sampling per scope: three live Standard stories grounding the scorecard;
  Rhyming, Learning-to-Read, and Pick-a-Path assessed from their prompt builders
  (`story_service._build_rhyme_time_prompt`, `_build_learning_to_read_prompt`,
  `InteractiveAdventurePromptBuilder`). Single-shot stories carry generation
  variance; the structural findings (RC-1..RC-5) are code-level and do not depend
  on any single sample.
- Journey copy quoted from the Flutter wizard screens; the reader/wait
  observations are from `magic_review_step.dart` and `story_result_screen.dart`.
