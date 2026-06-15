# Hidden Parent Layer and Shared Emotion Engine Spec

> **ADDENDUM — MT-254 (2026-06-14): age-gated transparency reverses `child_visibility: hidden` for older bands.**
>
> The original spec below mandates that parent context is fully hidden from the
> child (`child_visibility: "hidden"`, "Do not expose parent-entered context to
> the child"). That remains true for the *raw configuration* — a child never
> sees the parent's trigger/coping/repair selections or the setup screen. But
> hiding the *fact that a story was guided* is itself the ethical problem this
> product is trying not to have: persuasion concealed inside a story a child
> trusts. So this addendum overrides the visibility rule as follows.
>
> **What changed:** after a guided story, the child is offered an optional,
> age-appropriate disclosure ("Story Notes" — the quiet "Why this story? 💛"
> button) naming what the story practiced. Directness scales with band:
>
> - **Sprout 3-5** — relational only ("a grown-up who loves you picked this 💛"); no lesson named (a 3-5yo can't process persuasion).
> - **Explorer 6-8** — names the skill gently + a co-read question.
> - **Adventurer 9-12** — direct, but agency-preserving ("the choices were really yours").
> - **Creator / Adolescent / Adult 13+** — full transparency, respects autonomy.
>
> **What did NOT change:** the raw parent config stays private (the child never
> sees the settings screen or the verbatim selections); the disclosure names the
> *skill*, not the parent's notes. Disclosure lives at the *edge* of the story
> (a separate screen), never inside it, so engagement is preserved.
>
> **Pull, not push:** the child reveal is opt-in (a button), so it never nags.
> Disclosure to the trusted adult is instead *guaranteed* via a parent-side
> "what each story practiced" view. Implementation: `lib/models/story_notes.dart`
> (directness ladder), `lib/screens/story_notes_screen.dart` (reveal + button),
> backend `practiced` field on the story-gen response. The `child_visibility`
> field in the schema below should now be read as
> `"age_gated_disclosure"` for the disclosure layer, while the stored config
> retains `"hidden"`.

## Purpose

Define a hidden parent-controlled layer for one story theme that helps children:

- name feelings
- calm without repression
- repair after mistakes

This is not a separate app mode. It is one of the existing story themes, backed by one shared engine and one shared data model across all age bands.

## Product Principles

- The child experience must feel like a story invitation, not an assessment.
- Parent inputs must never appear as parent language inside child flow.
- The system should support co-regulation and repair, not behavior control dressed up as therapy.
- The engine should translate adult context into story scaffolding, not into diagnosis.
- The same backend structure should serve all age bands; only presentation, copy, complexity, and choice framing should vary by age.

## Theme Positioning

Recommended theme role: this becomes one of the five selectable story themes, framed for the child as a gentle adventure about big moments, messy feelings, and making things better.

Child-facing theme examples:

- Ages 3-5: `Heart Helper Adventure`
- Ages 6-8: `Big Feelings Quest`
- Ages 9-12: `Reset and Repair`
- Ages 13+: `After the Moment`

Parent-facing admin label:

- `Hidden support theme: feelings, calming, and repair`

The child should only see the child-facing theme title and story framing. They should never see terms like `hidden context`, `trigger`, `parental note`, or `behavior goal`.

## Hidden Parent Layer Concept

### Core idea

The hidden parent layer is a private configuration surface attached to a child profile and optionally to a single story request. It gives the story engine enough context to shape the emotional arc without exposing that context directly to the child.

### Parent control goals

Parents should be able to quietly specify:

- what kind of moment has been hard lately
- what feeling language is most useful
- what body cues the child tends to notice
- what calming tools are familiar at home
- what kind of repair outcome would help
- what private context should shape tone, guardrails, and metaphor

### Visibility rules

- Parent setup happens behind a parent gate and outside the child story flow.
- Parent choices are stored as structured metadata, not shown in the child UI.
- Child flow only receives transformed outputs:
  - story setup
  - scene tone
  - helper behaviors
  - choice design
  - repair arc

### Control levels

Recommended three-layer control model:

1. Profile defaults
   - Stable patterns for this child across many stories
   - Example: tends to shut down after conflict, responds well to breathing plus redo language

2. Theme defaults
   - Reusable settings for this specific theme
   - Example: always favor naming feelings before problem-solving

3. Story-session override
   - Temporary context for today
   - Example: rough drop-off this morning, avoid school-specific wording

Resolution order:

- session override
- theme default
- profile default

## Recommended Shared Data Model

Use one structured object, called `parent_hidden_context`, that contains a normalized emotional support model. The six requested fields should exist as first-class members in the generation payload, while `parent_hidden_context` acts as the wrapper plus privacy and policy metadata.

### Top-level shape

```json
{
  "feeling": {},
  "trigger": {},
  "body_signal": [],
  "coping_tool": [],
  "repair_goal": {},
  "parent_hidden_context": {}
}
```

### 1. `feeling`

Purpose: the emotional state the story should help the child name and move with.

Recommended structure:

```json
{
  "id": "frustrated",
  "label_child": "frustrated",
  "label_parent": "frustrated after conflict",
  "family": "anger",
  "intensity": 3,
  "secondary_options": ["embarrassed", "left_out"],
  "valence": "unpleasant"
}
```

Notes:

- `label_child` is approved child-safe vocabulary by age band.
- `label_parent` can be more specific and is never shown to the child.
- `family` supports prompt logic and analytics without requiring the child to use exact vocabulary.
- `secondary_options` help the engine widen emotional nuance without forcing one rigid label.

### 2. `trigger`

Purpose: the situational pattern that activates the feeling.

Recommended structure:

```json
{
  "id": "transition_peer_conflict",
  "category": "social",
  "summary_child_safe": "something went wrong during a busy moment",
  "summary_internal": "argument during cleanup transition",
  "sensitivity": "private",
  "recency": "today",
  "repeat_pattern": true
}
```

Notes:

- `summary_child_safe` is abstracted and can feed metaphor or setup.
- `summary_internal` is for parent and engine only.
- `category` helps theme selection and scene generation.
- Avoid person names, school names, exact locations, or identifiable incidents unless there is a clear operational need.

### 3. `body_signal`

Purpose: body-based cues the story can mirror to normalize emotional awareness.

Recommended structure:

```json
[
  {
    "id": "tight_chest",
    "label_child": "chest feels tight",
    "body_zone": "chest",
    "intensity_hint": "medium"
  },
  {
    "id": "hot_face",
    "label_child": "face feels hot",
    "body_zone": "face",
    "intensity_hint": "high"
  }
]
```

Notes:

- Keep this optional and low-count. One to three body signals is enough.
- Use sensory language, not clinical interpretation.

### 4. `coping_tool`

Purpose: tools the story can model and offer naturally through characters and choices.

Recommended structure:

```json
[
  {
    "id": "dragon_breath",
    "type": "regulation",
    "label_child": "dragon breaths",
    "mechanic": "slow_exhale",
    "familiarity": "known",
    "when_to_offer": "early"
  },
  {
    "id": "redo_words",
    "type": "repair",
    "label_child": "try-again words",
    "mechanic": "apology_or_repair_script",
    "familiarity": "known",
    "when_to_offer": "late"
  }
]
```

Notes:

- `type` should support at least `regulation`, `connection`, `repair`, `sensory`, and `movement`.
- `familiarity` helps the engine prefer known tools first.
- `when_to_offer` supports pacing.

### 5. `repair_goal`

Purpose: what “better” looks like after the hard moment.

Recommended structure:

```json
{
  "id": "make_amends_and_reconnect",
  "success_shape": "child repairs relationship after mistake",
  "child_visible_goal": "make it better",
  "non_goals": ["perfect behavior", "instant compliance", "forced apology"],
  "target_actions": ["pause", "name feeling", "repair action"],
  "resolution_style": "warm_realistic"
}
```

Notes:

- This should define the emotional end-state, not a behavior score.
- `non_goals` prevents coercive or shaming arcs.

### 6. `parent_hidden_context`

Purpose: hidden wrapper for policy, guardrails, privacy, and generation hints.

Recommended structure:

```json
{
  "source": "parent",
  "theme_id": "feelings_repair_theme",
  "profile_scope": "session",
  "child_visibility": "hidden",
  "prompt_strategy": {
    "directness": "metaphor_first",
    "avoid_explicit_reenactment": true,
    "avoid_parent_voice": true,
    "avoid_moralizing": true
  },
  "safety": {
    "do_not_name_real_people": true,
    "do_not_recreate_exact_incident": true,
    "do_not_assign_diagnosis": true
  },
  "private_notes": "Had a meltdown after snapping at sibling. Parent wants support for calming and repair without shame."
}
```

Notes:

- `private_notes` should be optional, short, and treated as sensitive.
- This wrapper is also the right place for storage metadata like timestamps, consent state, and retention policy.

## Unified Backend Entity

To keep architecture simple, the backend should treat this as one reusable `EmotionalSupportContext` object attached to any story request in this theme.

Recommended canonical schema:

```json
{
  "theme_id": "feelings_repair_theme",
  "age_band": "6-8",
  "emotional_support_context": {
    "feeling": {},
    "trigger": {},
    "body_signal": [],
    "coping_tool": [],
    "repair_goal": {},
    "parent_hidden_context": {}
  }
}
```

This should be valid for:

- one-off story generation
- pick-a-path generation
- saved story reruns
- future analytics with de-identified aggregates

## How These Fields Flow Into Story Generation

### Generation pipeline

1. Parent config exists outside child flow.
2. Child selects the theme like any other theme.
3. Backend resolves hidden context from profile defaults plus session override.
4. A prompt assembler transforms raw parent context into child-safe story instructions.
5. The model generates:
   - emotional setup
   - metaphorical challenge
   - helper character behavior
   - regulation moments
   - repair arc
6. Post-processing checks that the output stayed child-safe and non-moralizing.

### Translation rule

Parent inputs should never pass raw into the child prompt. They should be translated into story directives.

Example translation:

- Raw parent input:
  - `trigger.summary_internal = "argument with sibling after cleanup"`
  - `repair_goal.success_shape = "repair relationship after yelling"`

- Prompt-ready transformed instruction:
  - `Create a story about a character whose big feelings spill out during a busy moment. The story should gently help them notice the feeling, calm enough to think, and choose a warm repair action.`

### Prompt contract

Recommended internal prompt sections for this theme:

- `Feeling target`
- `Hidden trigger pattern`
- `Body cues to mirror`
- `Regulation tools to model`
- `Repair destination`
- `Tone guardrails`
- `Age-band writing recipe`

### Story-writing requirements

For this theme, generation should consistently follow this arc:

1. Felt sense
   - something is off
   - body clue appears

2. Naming
   - the character notices or wonders about the feeling
   - no external narrator labels the child as a problem

3. Calming
   - a coping tool appears as help, ritual, creature ability, or scene mechanic
   - calming is used to regain choice, not suppress emotion

4. Repair
   - the character notices impact
   - the story opens a path to reconnect, redo, help, or apology

5. Hopeful ending
   - realistic repair
   - no shame sermon
   - no perfection ending

### What the model should avoid

- direct retelling of a real-life incident
- parent-sounding explanations
- “good kids do X” language
- punishment fantasy framed as healing
- forced confession or apology
- labeling the child as angry, difficult, rude, manipulative, or out of control

## How Pick-A-Path Should Use These Fields

Pick-a-path should use the same `EmotionalSupportContext`, but choice logic should express it through interactive decisions rather than explicit teaching.

### Choice design rules

Every branch set should subtly support one of these functions:

- notice
- pause
- express
- reconnect
- repair

At least one choice per major node should preserve agency without escalating shame.

### Field-by-field use in interactive structure

#### `feeling`

Use it to shape:

- internal tension of the scene
- language options for self-expression
- helper character responses
- branch tone

Example:

- `frustrated` produces impatient energy, fast pacing, and choices like:
  - `take a beat`
  - `say what went wrong`
  - `storm ahead`

#### `trigger`

Use it to select:

- scene type
- environmental metaphor
- friction pattern

Example:

- `transition_peer_conflict` can become:
  - crowded bridge
  - mixed-up teamwork task
  - sudden change in quest rules

The trigger should be abstracted, not copied literally.

#### `body_signal`

Use it to:

- add embodied cues in narration
- unlock regulation choices
- signal rising stakes before a rupture

Example:

- if `tight_chest`, offer:
  - `put a hand on your chest and breathe with the firefly`
  - `ask the companion to slow down with you`

#### `coping_tool`

Use it to:

- generate support choices
- influence helper powers
- create repeatable mechanics across nodes

Example:

- `dragon_breath` becomes a reusable calm mechanic
- `redo_words` appears later as a repair option after the consequence lands

#### `repair_goal`

Use it to govern:

- end-of-branch success criteria
- what “good progress” means
- which endings are allowed

Example:

- if goal is `make_amends_and_reconnect`, acceptable endings include:
  - honest repair attempt
  - shared redo
  - asking for help fixing harm

Unacceptable endings include:

- winning by domination
- fake apology with no reconnection
- adult rescue that erases agency unless age requires strong scaffolding

#### `parent_hidden_context`

Use it to apply hidden rules:

- metaphor-first vs direct framing
- incident abstraction level
- do-not-say constraints
- sensitivity controls

### Branch architecture recommendation

Use a five-beat interactive spine:

1. `Signal`
   - something feels off

2. `Choice Under Stress`
   - first emotionally loaded choice

3. `Regulation Opportunity`
   - calming tool enters naturally

4. `Impact and Repair`
   - the effect of the earlier moment becomes visible

5. `Reconnection Ending`
   - multiple acceptable repair endings

This preserves story engagement while making repair a lived outcome rather than a lecture.

## Privacy and COPPA-Safe Recommendations

### Data minimization

- Store normalized tags instead of long free-text whenever possible.
- Default to controlled vocabularies for feeling, trigger category, body signals, coping tools, and repair goals.
- Keep `private_notes` optional and short.
- Do not require exact incident details to generate a useful story.

### Child privacy

- Do not expose parent-entered context to the child.
- Do not present story output as “because your parent said...”
- Do not show retrospective behavior analysis or labels in the child UI.

### COPPA-safe handling

- Treat all hidden parent context for users under 13 as child-related sensitive product data.
- Collect only what is necessary to personalize the story.
- Avoid personal identifiers in hidden context:
  - full names
  - school names
  - addresses
  - teacher names
  - medical details

### Storage policy

Recommended retention split:

- structured tags: can persist as profile defaults
- session override: auto-expire after configurable window
- free-text private notes: shortest retention, ideally removable per story or auto-pruned

### Access controls

- Parent-only read/write for hidden context
- No child-facing history screen for hidden context
- Deletion pathway should remove both structured context and free-text notes

### Analytics

Safe:

- aggregate counts of selected feeling families
- aggregate counts of coping tool usage
- age-band completion rates

Avoid:

- storing raw private notes in analytics
- event names that encode sensitive incidents
- inference labels like `anger_problem_child` or `repair_deficit`

## One Backend Structure Across All Age Bands

### Shared backend

All age bands should use the same:

- `theme_id`
- `EmotionalSupportContext`
- prompt contract
- branch spine
- safety rules

### Age-specific adaptation layer

Only these should vary by age band:

- vocabulary
- sentence length
- metaphor density
- explicitness of feeling labels
- number and complexity of choices
- degree of co-regulation from helper characters
- repair action sophistication

### Recommended age-band behavior

#### Ages 3-5

- very concrete feeling words
- body cues simple and sensory
- coping tools become creature rituals or rhythm actions
- repair looks like redo, help fix, gentle apology, reconnect through action
- more helper scaffolding

Child copy style:

- “Uh-oh, something feels wiggly inside.”
- “Want to take dragon breaths or hold the glowing pebble?”

#### Ages 6-8

- feeling words can broaden
- choices include naming plus simple action
- repair can include taking turns, retrying words, or making amends

Child copy style:

- “That feeling got really big.”
- “What would help you steady yourself?”

#### Ages 9-12

- more nuance in mixed feelings
- stronger cause/effect awareness
- repair can include ownership without shame
- choices can reflect social complexity and self-awareness

Child copy style:

- “Part of you wants to hide. Part of you wants to fix it.”

#### Ages 13+

- richer emotional ambiguity
- more dignity, less overt reassurance
- repair can include boundaries, accountability, and honest conversation
- helper characters should not feel babyish or preachy

Child copy style:

- “The moment got away from you. What do you want to do with what happens next?”

## Recommended Parent UX

Parent UX should be minimal, structured, and fast.

Recommended invisible setup flow:

1. Select child profile
2. Open hidden support settings under parent gate
3. Choose:
   - feeling
   - trigger pattern
   - body signals
   - coping tools already used at home
   - repair goal
4. Optional short private note
5. Save as:
   - for today
   - for this theme
   - for this child profile

Recommended parent copy:

- “Shape the story quietly.”
- “Choose what kind of support the story should build in.”
- “Your child will not see these notes directly.”

## Acceptance Criteria

- A child can enter the theme without seeing any parent-specific framing.
- The generated story clearly supports feeling naming, calming, and repair.
- The story does not sound like a lesson or behavior correction script.
- Pick-a-path choices preserve agency and include non-shaming repair routes.
- The same backend payload works for every age band.
- Age variation is handled by presentation and generation style, not schema forks.
- Parent-entered context is private, minimal, and COPPA-safe.

## Recommended Next Step

Before implementation, align on three things:

1. Controlled vocabulary lists for each field
2. Prompt transformation rules from parent input to child-safe story instructions
3. Which existing theme slot and child-facing theme names to use per age band
