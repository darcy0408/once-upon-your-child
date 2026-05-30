# Big Feelings / Life Quest Theme Spec for Ages 9-12 (Adventurer)

Companion to `big-feelings-theme-spec-ages-6-8.md`. Defines the emotional-learning
experience for the Adventurer band. Drives the MT-199 Phase 2 build (new Life Quests,
9-12 coping tier, identification depth, reflection, and the **Standing On Your Own** track).

## Purpose

Help a 9-12-year-old (1) **name** what they feel with real precision, (2) understand that a
feeling is information, not a problem to be deleted, (3) build coping that buys them enough
steadiness to **think and choose**, and (4) make their own deliberate decisions when people —
kids *or* adults — pressure them, let them down, or behave unsafely. The throughline for this
band is **agency**: you get to choose, even when it's hard, even when it's different from the group.

## Experience Principles

- **Socially real, never therapeutic-sounding.** This age can smell a "lesson" instantly. The
  story respects them; the learning is in the choices, not in narration.
- **The emotion is not the problem.** The pressure, the misunderstanding, the impulse, or the
  fallout is the problem. Calming is "regaining choice," not "shutting the feeling down."
- **No good-kid trick answer.** Choices have believable social costs and benefits. Repair is
  brave and credible, not neat or instant.
- **You are the decider.** Adults can steady a scene, but the child still makes the key choice —
  *except* where safety requires an adult, and there the lesson is that reaching out IS the choice.
- **Mixed feelings are normal.** Name two at once (scared AND angry; relieved AND guilty).

## Target Age Calibration

- Reading: Grade 3-5; second-person ("you"); 12-20 word sentences; Merriweather body prose.
- Feeling vocabulary: precise words (humiliated, overwhelmed, resentful, conflicted, betrayed,
  torn) introduced naturally, not defined.
- Choices: 2-3 per segment; path depth 6-8 segments.
- Tone: the stakes are social and real (belonging, fairness, reputation, safety, autonomy).

## Theme Positioning

Surfaced as **Life Quests** (not "Big Feelings", which is the younger framing). Entry is a flat
quest selector + a coping toolbox; optionally pre-filtered by a feeling the child picked. An
Adventurer companion (Atlas/Robin/Nyx/Kodiak) can act as a guide voice.

## Core Loop

Name the feeling → Notice the pressure (what's really the problem?) → **Pause** (you don't have to
react now) → **Check** (Is this safe? Is this mine? What do I actually want?) → **Choose** (your
call, with real consequences) → see the outcome → optional coping moment → optional repair →
reflect (one line, optional journal).

## Screen Flow (reuse existing surfaces)

Reuses `LifeQuestScreen`, `BigFeelingsFlowScreen`, `FeelingsBadgeGrid`/`FeelingsCloudPicker`,
`BodyOutlineWidget`, `CopingPracticeSheet`, `crisis_resources_panel.dart`. Phase 2 adds:

1. **Feeling check-in** — reach the secondary/tertiary feelings (level-2 picker already supports
   9+; surface it for Adventurer rather than stopping at the 8-card grid).
2. **Body signal** — 9-12 signals (tight throat, pit in stomach, restlessness, numbness, heat in
   the face) rather than sharing Explorer's set.
3. **Coping moment** — 9-12 framing ("get steady enough to think / get your power back"), plus a
   private/solo option (journaling, step away) for kids who don't want a visible breathing exercise.
4. **Reflection / journal** — extend the Creator-only `journalEntry` to Adventurer: an optional
   one-line "what I'd do next time."

## Expanded Feeling Vocabulary (9-12 families)

Build on the existing 9+ wheel; emphasize these precise tween words inside quests:

- **Anger family:** annoyed, frustrated, resentful, indignant ("that's not fair"), betrayed.
- **Worry family:** nervous, anxious, overwhelmed, dread, on-edge.
- **Sad family:** disappointed, let down, lonely, left out, hurt.
- **Shame family:** embarrassed, humiliated, exposed, self-conscious.
- **Pressure family:** torn, conflicted, trapped, pressured, "going along with it."
- **Mixed:** relieved-but-guilty, excited-but-scared, angry-but-hurt.

## Trigger Options (9-12)

- **Peer dynamics:** left out of a group, a friend turned on you, a secret spread, online drama.
- **Fairness / boundary:** blamed for something you didn't do, a rule applied unfairly, talked over.
- **Performance:** a test, a tryout, a presentation, comparing yourself to others.
- **Pressure:** dared to do something, "everyone's doing it," pushed to pick a side.
- **Being let down:** an adult broke a promise; someone you count on wasn't there.
- **Identity:** feeling different, not fitting in, figuring out what *you* think.

## Coping Tool Selection Model (9-12)

Same energy-matching logic as 6-8, but framed for autonomy and re-tagged for older language:

- **High-energy outward (anger):** body release first (Dragon's Breath → "get your power back so
  you don't do something you'll regret").
- **High-energy inward (anxiety/overwhelm):** safety cue + grounding (5-4-3-2-1 → "get your feet
  back under you so you can think").
- **Stuck / pressured:** buy time ("you don't have to answer right now") + a private reset
  (journaling, step away, name it to yourself).
- Tool effect framing: coping = **preparation to choose**, never "calm down and obey."

Add a 9-11 coping tier in `FeelingDetails.copingForAge` (today it jumps 6-8 → 12+).

## Pick-a-Path Choice Design

Three choice archetypes per beat, none of them a trick:
- **Impulsive** (react now — relatable, has a real cost, never punished cruelly).
- **Regulated** (pause/cope first, then act).
- **Connection / voice** (speak up, ask, set a boundary, reach a trusted adult).

Choices change the **social outcome** believably. Show the hero being wrong and correcting. Repair
costs a little courage and is never instant or perfect.

## THE "STANDING ON YOUR OWN" TRACK (priority)

A dedicated thread teaching 9-12-year-olds how to respond to people — kids or adults — who don't
do what they should, and how to make a deliberate choice instead of going with the flow.

### The decision frame the quests teach: **Pause · Check · Choose · Reach**
- **Pause:** You don't have to react or answer right now. Stepping away is a move, not a loss.
- **Check:** *Is this safe? Is this mine to fix? What do I actually want — not what the group wants?*
- **Choose:** Make your call out loud or with your feet. Different from the group is allowed.
- **Reach:** If it's big, unsafe, or not yours to carry — tell a trusted adult. That is strength,
  not tattling.

### Safety ladder (graduated stakes)
1. **Everyday pressure** — a friend wants you to exclude someone or be mean; the group's doing
   something you don't want to. *Skill: say no and stay yourself; keep the friendship if you can.*
2. **Rule-breaking pressure** — dared/pushed to break a rule (sneak out, cheat, a shoplifting dare).
   *Skill: a deliberate no; an exit; who you'd tell.*
3. **Dangerous pressure** — a peer offers something unsafe (vaping/alcohol/drugs), or pushes toward
   real danger. *Skill: a firm refusal script, leaving, and telling a trusted adult — without shame.*
4. **An unsafe adult** — a grown-up isn't being safe (e.g., has been drinking and wants to drive;
   an adult asks you to keep an unsafe secret; an adult's behavior scares or burdens you).
   *Skill: this isn't your fault and isn't yours to fix; keep yourself safe; find another trusted
   adult; it's okay to tell.*

### Non-negotiable safety rules (apply to all tiers, hard rules for tiers 3-4)
- **Always validate** the child's feelings; never imply they caused the situation.
- **Never depict the child fixing an adult's problem** (e.g., managing a parent's drinking). The
  child's job is their own safety and reaching another trusted adult.
- **Always provide an off-ramp:** a named trusted adult and the `crisis_resources_panel`, shown at
  the start and end of tier 3-4 quests (model the existing `someone_needs_help` quest).
- **Refusal is always honored** in the narrative — saying no never makes things worse in a way that
  blames the child. Social cost can be real but the story affirms the choice.
- **No graphic content:** keep it about the child's feelings and choice; never depict substance use
  mechanics, never glamorize, never frighten gratuitously. Moderation tier for 9-12 must permit this
  honest-but-non-graphic depiction while blocking gore/sexual/graphic-substance content.
- **Repair / outcome** centers the child's safety and self-respect, not a tidy fix of the other person.

### Quest catalogue (Phase 2 build)

Non-sensitive (build + ship):
| id | title | feelings | track tier |
|----|-------|----------|-----------|
| questFriendTurned | "The Friend Who Turned" | hurt, betrayed, angry | peer / repair |
| questBlamed | "It Wasn't Me" | indignant, frustrated, anxious | fairness |
| questBigTest | "The Big Day" | nervous, overwhelmed, dread | performance |
| questLeftOutOnline | "Left on Read" | left out, hurt, anxious | peer / online |
| questPickASide | "Pick a Side" | torn, pressured, anxious | everyday pressure (tier 1) |
| questTheDare | "The Dare" | torn, nervous, pressured | rule-breaking (tier 2) |

Sensitive (**author, then FLAG FOR DARCY REVIEW before shipping** — content judgment is the
owner's, not the model's):
| id | title | feelings | track tier |
|----|-------|----------|-----------|
| questTheOffer | "The Offer" | torn, scared, pressured | dangerous: peer offers vaping/drugs (tier 3) |
| questRideHome | "The Ride Home" | scared, worried, torn | unsafe adult: a grown-up who's been drinking (tier 4) |
| questSecretWeight | "The Secret" | burdened, anxious, conflicted | unsafe adult: asked to keep an unsafe secret (tier 4) |

Tier 3-4 quests `recommendedBands` = Adventurer (+ Creator/Adolescent where appropriate), carry a
`copingBreakId`, a `crisisResources: true` flag pattern, and a `grownupTip` aimed at the caregiver.

## Reflection Moments (not teachy)

- Mid-story: "You notice your hands have stopped shaking. The choice is yours now." (no lecture)
- End: an optional one-line journal — "Next time someone pushes me, I could ___." Stored via the
  `journalEntry` field, surfaced for Adventurer.
- Grown-up tip (caregiver-facing, italic): e.g. "Ask: *What would you do if it happened for real?*"

## Success Criteria

A 9-12-year-old, after a Life Quest, can: pick a precise feeling word; describe the pressure
separately from the feeling; name one coping move that buys thinking time; articulate a choice that
is *theirs*; and, for the Standing-On-Your-Own quests, name a trusted adult and know that reaching
out is strength and that an adult's unsafe behavior is not their fault or their job to fix.

## Content Guardrails

- All the non-negotiable safety rules above.
- Backend: extend the "AGES 9-12 BIG FEELINGS RULES" block with a mixed-feelings rule and explicit
  decision/refusal scaffolding; add a 9-12 moderation tier in `content_moderator.py` that permits
  honest pressure/peril for SEL while hard-blocking gore, sexual content, and graphic substance use.
- **Human review gate:** `questTheOffer`, `questRideHome`, `questSecretWeight` (and any tier 3-4
  content) ship only after owner review.
