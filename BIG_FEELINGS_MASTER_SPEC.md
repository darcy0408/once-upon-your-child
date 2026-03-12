# Big Feelings Master Spec

## Product Goal

`Big Feelings` is one of the 5 story themes. It helps children:

- notice what they feel
- name it simply
- connect it to what happened
- see that they have choices
- calm without shame
- repair after mistakes

To the child, it should feel like:

- a story about something real
- a magical helper adventure
- a choose-what-happens-next game

It should not feel like:

- a lesson
- therapy homework
- behavior correction

## Core Design Principles

- Feelings are always okay.
- Behavior still matters.
- Calming is support, not suppression.
- Repair is part of the adventure, not punishment.
- Children learn through story consequences, not explanation.
- Parent guidance stays hidden from the child.

## Shared Story Engine Model

Use this schema across all age bands.

### Child-Facing Fields

- `feeling`
- `trigger`
- `body_signal`
- `coping_tool`
- `repair_goal`
- `interactive_mode`

### Hidden Parent Fields

- `parent_hidden_context`
- `parent_priority_skill`
- `parent_avoidances`
- `parent_repetition_window`
- `parent_real_life_struggle`

### Story Output Goals

Every Big Feelings story should include:

- feeling named early
- body clue named early
- a relatable moment that caused the feeling
- at least one regulation moment
- at least one choice point in interactive mode
- repair if the child-character causes harm
- a safe, non-shaming ending

## Shared Story Arc

All age bands use the same emotional spine:

1. Something happens.
2. The character feels something strongly.
3. The body reacts.
4. The character has an impulse.
5. A helper, tool, or choice appears.
6. The story shows consequences.
7. Repair happens if needed.
8. The character feels safer, clearer, or more connected.

## Age Band Matrix

### Ages 3-5

Goal:

- basic emotion naming
- body clues
- simple helper actions
- very concrete repair

Feelings:

- mad
- sad
- scared
- frustrated

Later:

- lonely
- shy

Flow:

- feeling
- what happened
- body clue
- helper
- story

Interactivity:

- 1 branch for ages 3-4
- 2 small branches for age 5
- 2 choices max per branch

Tone:

- very warm
- playful
- simple
- sensory
- repetitive in a good way

Repair:

- say sorry
- help fix
- gentle hug
- try again

### Ages 6-8

Goal:

- stronger emotional vocabulary
- noticing choices
- trying tools more intentionally
- understanding others' feelings too

Feelings:

- angry
- worried
- frustrated
- sad
- embarrassed
- lonely
- jealous
- excited-but-nervous

Flow:

- feeling
- what happened
- body clue
- choose helper or tool
- story

Interactivity:

- 2-3 branch moments
- 2-3 choices each

Tone:

- still playful
- more cause and effect
- still not teachy

Repair:

- apology
- checking on someone
- making a plan
- retrying with support

### Ages 9-12

Goal:

- mixed feelings
- social conflict
- impulse vs values
- boundaries and repair

Feelings:

- angry
- anxious
- left out
- embarrassed
- disappointed
- overwhelmed
- lonely
- guilty

Flow:

- feeling
- context
- body clue
- goal
- strategy
- story

Interactivity:

- meaningful consequences
- stronger contrast between options
- repair and reflection

Tone:

- less cute
- more emotionally real
- still safe

Repair:

- apology when needed
- boundary-setting
- self-advocacy
- re-entering social situations

### Teen Direction

Goal:

- emotional complexity
- self-knowledge
- relationships
- identity and stress

Use the same engine, but with:

- more nuanced wording
- lower whimsy
- more realistic stakes

## Child Flow By Age Band

### V1 Ages 3-5

1. Tap `Big Feelings`
2. Pick a feeling cloud
3. Pick what happened
4. Pick what the body feels like
5. Pick a helper
6. Story begins
7. One choice point
8. Repair if needed
9. Safe ending

### Ages 6-8

1. Big Feelings
2. Feeling
3. Trigger
4. Body clue
5. Tool or helper choice
6. Story
7. 2-3 choice points
8. Repair and reflection

### Ages 9-12

1. Big Feelings
2. Feeling
3. Context
4. Body clue
5. Goal
6. Strategy
7. Story branches
8. Repair or boundary outcome

## V1 Scope

Build this first.

### Age Band

- 3-5 only

### Feelings

- mad
- sad
- scared

### Trigger Set

Mad:

- had to wait
- someone said no
- something broke

Sad:

- lost something
- miss someone
- left out

Scared:

- dark
- loud sound
- something new

### Body Clues

- hot face
- tight tummy
- fast heart
- tears

### Helpers

- dragon breaths
- ask for help
- squeeze hug

### Interactive Mode

- 1 branch
- 2 choices
- both safe
- one includes repair

### Repair Beats

- say sorry
- help fix it
- check on friend
- try again

### Hidden Parent Contexts For V1

- sibling fights
- trouble hearing `no`
- bedtime worry
- yelling when mad

## Parent Hidden Layer

Parents should be able to quietly set real-life struggles.

### Hidden Parent Options

- trouble waiting
- sibling conflict
- yelling when angry
- hitting when upset
- separation anxiety
- school drop-off worry
- bedtime anxiety
- perfectionism or meltdown after mistakes
- friendship hurt
- hard time apologizing

### How It Works

The child sees:

- the normal Big Feelings theme

The engine uses hidden parent context to influence:

- trigger options
- story opening
- helper behavior
- likely branch paths
- repair opportunities
- ending emphasis

### Example

If parent sets:

- `parent_real_life_struggle = trouble_apologizing_after_yelling`

Then a `mad` story may:

- start with a yell impulse
- include a friend or sibling reaction
- create a repair moment
- model apology and reconnection

Without ever telling the child:

- `this story was selected because of your behavior`

## Prompt And Story Rules

### Opening Rules

For all Big Feelings stories:

- name the feeling in the first lines
- name a body clue in the first lines
- start with a relatable child-scale event

Examples:

- `Maya was so mad. Her face felt hot.`
- `Owen felt scared. His heart went thump-thump.`
- `Lila felt sad. Big tears came fast.`

### Interactive Rules

Choices should be:

- emotionally meaningful
- simple
- behavior-based
- never moralizing

Bad:

- `Choose the correct coping skill`

Good:

- `Roar and stomp`
- `Take a dragon breath`
- `Ask for help`

### Repair Rules

Repair should happen when:

- someone gets hurt
- someone gets scared
- something gets broken
- the relationship bumps

Repair can include:

- apology
- helping fix
- checking in
- trying again
- using gentler words

### Ending Rules

Endings should say:

- the feeling changed or got smaller
- the child-character was not bad
- the relationship or situation got safer

## UX Requirements

### Ages 3-5

- 88-96px touch targets
- icon + 1-2 word labels
- audio-first
- max 3 choices on setup screens
- max 2 choices in branch screens
- one big idea per screen

### Ages 6-8

- slightly more text okay
- can support 3 choices
- can support one helper-selection screen

### Ages 9-12

- more context text
- still avoid dense setup
- more nuanced branches

## Content Guardrails

Do:

- validate the feeling
- show body awareness
- give choices
- show repair
- keep tone warm

Do not:

- shame
- moralize
- flatten every ending into `happy`
- imply the feeling must disappear
- use therapy jargon in child copy

## Recommended Build Phases

### Phase 1

Build V1 for ages 3-5 only.

Deliver:

- feeling cloud screen
- trigger screen
- body clue screen
- helper screen
- Big Feelings story generation
- one interactive branch model
- one repair path

### Phase 2

Add hidden parent context support.

Deliver:

- parent controls for hidden struggles
- mapper payload support
- story prompt support

### Phase 3

Expand to ages 6-8.

Deliver:

- richer feelings
- more tool choice
- 2-3 branches
- stronger empathy and repair

### Phase 4

Expand to ages 9-12.

Deliver:

- social nuance
- self-talk
- boundary and repair patterns

