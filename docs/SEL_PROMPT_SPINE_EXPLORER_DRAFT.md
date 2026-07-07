# SEL Prompt Spine — Explorer (6–8) Worked Example — DRAFT

**Status:** Review draft (Fable pass, 2026-07-07). Not committed, not implemented. Owner approves the
shape here before this rolls to the other five bands.
**Scope:** The live standard-story path only (`AdvancedStoryEngine.generate_enhanced_prompt`,
`backend/services/story_service.py`). Superhero mode and the Interactive Adventure builder are
structurally disconnected from all of this — tracked as follow-ups (§8), not this chunk.
**Related:** `docs/SEL_FRAMEWORK_ALIGNMENT.md` (CASEL/ASCA crosswalk this refines),
`docs/PROMPT_CEILING_PASS_2026-07-05.md`, MT-232 (boundary-skills phases 2–5), memory
`boundary_skills_feature.md` (locked tone).

---

## 1. The finding that drives the design

The prompt builder has two dedicated SEL blocks — `_build_feelings_instruction` and
`_get_virtue_instruction` — and **both are empty in the default story**. They fire only when a
parent uses the Big Feelings flow or types therapeutic keywords into free text
(`story_service.py:1061-1063`). A 7-year-old generating a dragon story gets a well-built
*emotional arc* (the EMOTIONAL SPINE block guarantees that) but **zero real-life-situation
content and zero named-feeling/coping practice** unless an adult opted in.

So "teach feelings + real-life situations through stories" is not a tightening job — it needs
**one new ambient block** that is on by default in every story, plus targeted tightening of the
existing blocks. The design below does both, and deliberately generalizes MT-232 Phase 2
("ambient boundary beats woven into ordinary stories") from boundaries to the full CASEL 5.

**Design principles (locked-tone compliant):**
1. **One story, one skill.** Every default story carries exactly ONE small skill moment. Never two.
2. **Rotation, not repetition.** The skill rotates across ~11 real-kid situations, so no single
   situation appears in more than ~1-in-10 stories — under the locked ~1-in-5 boundary-beat cap.
3. **Consequence, not narration.** The skill is *causally load-bearing*: the plot turns because of
   it. No character ever explains it. (The existing rule-of-three / TRY-FAIL scaffolding is the
   natural engine — an early attempt fails *because* the feeling went unhandled; the final attempt
   works *because* of the copyable action.)
4. **The fantasy stays fantasy.** The situation wears a costume. The dragon won't take turns with
   the sky; the bridge only holds two friends walking together. Transfer happens through shape,
   not setting.
5. **Parent context wins.** If the parent picked a focus (Big Feelings context or therapeutic
   keywords), the rotation is skipped — their chosen skill is the story's skill.

---

## 2. CASEL targeting for Explorer (6–8)

CASEL's early-elementary benchmarks for this band, mapped to what the stories should practice:

| CASEL competency | 6–8 developmental form | Carried by (this design) |
|---|---|---|
| Self-Awareness | Name the feeling + one body clue; feelings have sizes | Echo step 2 (feeling-first, body-first) — every story |
| Self-Management | Concrete stop-think-act steps, not principles; coping = a *visible action* | Echo step 3 (copyable action); situations 3, 5, 8, 12 |
| Social Awareness | Read another's face/body; notice who's left out | Situations 2, 7 (other-focused entries) |
| Relationship Skills | Ask to join; take turns; say no kindly; ask for help | Situations 1, 2, 4, 9, 10 |
| Responsible Decision-Making | Truth after a mistake; fair play; try again | Situations 6, 8, 11 |

This upgrades `SEL_FRAMEWORK_ALIGNMENT.md` rows that are currently ◐/○: **B-SMS 4** (delayed
gratification — turn-taking, currently "not targeted"), **B-SMS 5** (perseverance — currently "not
directly authored"), **B-SS 1/B-SS 3** (assertive scripts, adult help-seeking — currently ◐), and
makes the "ambient beats" half of **B-SS 8** shipped instead of planned.

---

## 3. The new block: REAL-LIFE ECHO

New builder `_build_real_life_echo(age, situation, character)` in `story_service.py`, injected
after `{virtue_instruction}{emotional_spine}` (line ~1188), skipped when parent context is present:

```python
echo = "" if (feelings_instruction or virtue_instruction) else \
    _build_real_life_echo(age, _pick_situation(...), character)
```

**Proposed prompt text (Explorer register):**

```
**REAL-LIFE ECHO** (invisible skill practice — weave in, never announce):
This story quietly gives {character} one moment of real-kid practice: {skill_label}.
1. THE ECHO: Somewhere inside the adventure, one beat of the main problem takes the SHAPE
   of this real situation: {situation}. Keep the magic — the situation wears a costume
   (a dragon who won't take turns with the sky; a bridge that only holds two friends
   walking together). The child should feel "that's like me" without the story ever
   leaving its world.
2. FEELING FIRST, BODY FIRST: When the moment lands, {character} feels it in the body
   before acting — {body_cue}. Name the feeling simply, by name. Invent fresh wording
   for THIS story; never reuse a stock line.
3. THE SMALL ACTION IS THE KEY: What turns the moment is a small, copyable action a real
   6-8 year old could do tomorrow: {copyable_action}. {character} (or the companion) DOES
   it on the page — and the plot visibly improves BECAUSE of it. Not magic, not luck, not
   a grown-up fixing it. If the story uses multiple attempts, an earlier attempt may fail
   precisely because the feeling went unhandled (rushing while frustrated, grabbing
   instead of asking, giving up too soon) — and this action is why the final attempt works.
4. NO LESSON WORDS: No character explains why it worked. Nobody says "it's important
   to..." or "see, when you...". The proof is what happens next in the story — the door
   opens, the friend stays, the game turns fun again. If a sentence sounds like advice,
   cut it and show the result instead.
```

~170 tokens. Slots (`{skill_label}`, `{situation}`, `{body_cue}`, `{copyable_action}`) come from
the situation map below — the model gets ONE concrete situation per story, not the menu.

### EXPLORER_SITUATION_MAP (the rotation)

| # | key | skill_label | situation | body_cue | copyable_action | CASEL | ASCA |
|---|---|---|---|---|---|---|---|
| 1 | left_out_self | noticing you're left out and asking to join | watching others play/do the exciting thing without you | chest goes heavy, watching from the edge | walking over and asking "Can I play too?" | Relationship | B-SS 2 |
| 2 | left_out_other | noticing someone ELSE is left out and making room | a side character hangs back at the edge of the action | {character} spots the clue: someone standing apart, quiet | inviting them in by name, making a space | Social Awareness | B-SS 2/M 2 |
| 3 | losing_game | losing without melting down | losing a race/game/contest fair and square | face goes hot, eyes feel prickly | one big slow breath, then something kind to the winner ("Good race") | Self-Mgmt | B-SMS 2 |
| 4 | taking_turns | waiting for a turn when both want the same thing | two characters want the same thing at the same moment | grabby, buzzing hands | offering the other the FIRST turn, or saying "turns?" out loud | Self-Mgmt/Relationship | B-SMS 4 |
| 5 | scary_first_try | trying something new while still scared | a first time — the jump, the dark tunnel, the new door | butterflies, wobbly knees | saying the fear out loud to the companion, then trying the smallest first step | Self-Awareness | B-SMS 6 |
| 6 | truth_after_mistake | telling the truth after breaking something | {character} causes an accident and could hide it | wobbly tummy, wanting to disappear | saying what happened out loud + helping fix it (the world answers honesty with repair, never humiliation) | Resp. Decision | B-SS 5 |
| 7 | friend_sad | reading a friend's feelings from their face | the companion goes quiet or droopy mid-adventure | ({character} notices: drooping ears, a too-quiet voice) | sitting close, asking "What's wrong?", listening all the way to the end | Social Awareness | B-SS 4 |
| 8 | frustration_reset | cooling the volcano feeling when it won't work | the thing keeps failing or breaking | hot volcano feeling rising from tummy to ears | putting it down, one slow dragon breath, looking again with fresh eyes | Self-Mgmt | B-SMS 7 |
| 9 | saying_no | the uh-oh feeling and saying "no thank you" | someone pushes {character} toward a thing that feels wrong | the uh-oh feeling — a small tummy-squeeze that says *wait* | standing still, saying "No thank you," staying kind AND firm; a true friend stays after you say no | Self-Aware/Relationship | B-SS 8 |
| 10 | asking_for_help | asking for help before the stuck gets bigger | {character} is stuck and tries to hide it | tight shoulders, pretending it's fine | asking the companion for help — and the helper is GLAD to be asked | Relationship | B-SS 3 |
| 11 | try_again | starting over after a flop | the first plan collapses completely | the give-up feeling, heavy arms | saying "one more try," changing ONE thing, trying again | Self-Mgmt | B-SMS 5 |
| 12 | worry_out_loud | shrinking a worry by saying it | a worry about what's ahead grows page by page | a worry-knot in the tummy that gets tighter when hidden | telling the companion the worry — hearing it get smaller once it's out | Self-Awareness | B-SMS 7 |

Notes:
- **#9 carries the locked boundary tone verbatim** ("uh-oh feeling", consequence-not-narration,
  friend-stays-after-no). At 1-of-12 rotation it sits well under the ~1-in-5 cap.
- **#8 deliberately names "dragon breath"-style pacing** — same technique as
  `coping_techniques.dart`'s Dragon's Breath, so the in-story action and the Coping Toolbox
  reinforce each other.
- **Selection:** deterministic — `situation = MAP[hash(story_request_id) % len(MAP)]` (or seeded
  random). Deterministic keeps the eval harness reproducible and avoids `Date/random`-style drift
  in prompt versioning.
- `dual entries (#1/#2)` split self-advocacy from other-noticing — different competencies, both
  top-frequency 6–8 situations.

---

## 4. Tightening pass on the existing live blocks (the audit half)

**(a) `VIRTUE_MAP` keyword gaps** (`story_service.py:186-299`). Parents type these words and today
they match nothing — the block silently stays empty:

| Missing keywords | Proposed virtue → instruction |
|---|---|
| `worried`, `worry`, `nervous` | → existing **courage** entry (same as anxiety/fear/scared) |
| `left out`, `lonely`, `excluded` | → existing **inclusion** entry |
| `losing`, `lose`, `sore loser` | → NEW **grace**: "The protagonist loses at something fair and square. Show the hot flash of it honestly, then one small generous act toward the winner — and what that act unlocks." |
| `mistake`, `sorry`, `honest`, `lying`, `truth` | → NEW **honesty**: "The protagonist causes a mistake they could hide, and tells the truth instead. The world answers with repair, never humiliation — fixing it together IS the resolution." |
| `turns`, `waiting`, `wait` | → existing **patience** entry |
| `boundaries`, `saying no`, `say no` | → NEW **self-respect**: "The protagonist feels the uh-oh feeling, names it internally, and says a clear kind no. The story shows the no being respected — and anyone who pushes past it is shown to be in the wrong, gently." |
| `shy`, `asking for help`, `ask for help` | → NEW **reaching out**: "The protagonist asks for help before the problem grows, and the helper is glad to be asked. Asking is shown as strength, never defeat." |

The `boundaries` gap is the sharpest finding: **the app's flagship therapeutic goal has no
keyword in the map**, so even a parent who types "working on boundaries" gets nothing.

**(b) `_build_feelings_instruction` — split the 6–14 block.** One register currently serves both
a 6-year-old and a 14-year-old (`story_service.py:365-372`), and it's 3 thin bullets next to the
rich ≤5 preschool rules. Proposed dedicated 6–8 block (9–14 keeps the current text for now):

```
**FEELINGS-FIRST GUIDANCE**:
{feelings_prompt}{theme_rule}
- Open by naming the feeling and one body clue ({character} feels it somewhere specific).
- The coping action must be something a real 6-8 year old could copy tomorrow — visible,
  concrete, doable — and it changes what happens next inside the plot.
- Feelings can change size: show the feeling getting smaller or softer AFTER the action,
  not because time passed.
- If anyone got hurt along the way, include one small repair beat — checking on them,
  fixing the thing, a genuine sorry — woven into the action, not a ceremony.
- End with safety, reconnection, or relief rather than a lecture.
```

**(c) Virtue age caveat straddle.** `_get_virtue_instruction` gives the concrete/no-monologue
caveat to `age <= 7` only (`story_service.py:315-316`) — an 8-year-old Explorer gets the bare
instruction. Change to `age <= 8` (band 8-10's own notes then take over at 9).

**(d) Emotional-spine theme phrasing.** Spine line 1 reads `"{theme}" is the emotional
through-line` — coherent when theme is "overcoming fear," odd when theme is "Space Adventure."
Change to: `Let the feeling at the heart of "{theme}" be the emotional through-line, not a label.`
(All four spine variants have the same issue; fix in the same edit.)

**(e) `_META_LEAK_TERMS` additions** (`story_service.py:154-174`) — safety net for the new block's
craft vocabulary: `"real-life echo"`, `"copyable action"`, `"skill practice"`, `"body clue"`.
**Do NOT add "uh-oh feeling"** — that phrase is *supposed* to appear in kid-facing prose; it's the
locked through-line.

**(f) Unchanged on purpose:** `SAFETY_GUARDRAILS`, `STRICT_OUTPUT_CONSTRAINTS`, the Spark delight
rules, persona lines, POV rules. They audit clean, they're recently ceiling-passed, and keeping the
SEL text in ONE new block (rather than smearing edits across tuned blocks) keeps this auditable,
versionable, and cheap to roll back.

---

## 5. Proof sketch (hand exemplar — the shape the model should hit)

Situation #3 (`losing_game`) inside a kid-picked dragon adventure, Explorer register, condensed:

> Milo and Ember the fox reached the Cloud Race just in time. The prize was the Golden Key —
> and the racer was Storm, the fastest dragon in the whole sky.
>
> WHOOSH! They flew through rings and around towers. Milo leaned low. He flapped hard. But
> Storm crossed the finish cloud first.
>
> Milo's face went hot. His eyes felt prickly. He felt mad — the *losing* kind of mad, the kind
> that wants to shout *again, no fair!*
>
> "Your ears are doing the angry thing," Ember whispered.
>
> Milo took one big, slow breath. In... and out. The hot feeling shrank, just a little. He flew
> up to Storm. "Good race," he said. "You were SO fast on the last turn."
>
> Storm blinked. In one hundred cloud races, no one had ever said *good race* to him. Not once.
> The great dragon lowered his wing — and there, tucked under it, was the Golden Key. "Winners
> keep the key," Storm rumbled. "But friends... friends get to share the sky."
>
> And far below, the clouds turned gold in the morning sun.

Why this passes: feeling named + two body clues; the copyable action (breath + "good race") is
*causally* what unlocks the key — not magic, not luck; nobody explains anything; the theme stayed
dragons; ends on the world, not the lesson.

**Real verification (before any rollout):** run the modified prompt against prod model
`gpt-5-mini` locally via the OpenRouter recipe (`OPENROUTER_API_KEY` in `backend/.env`, write
UTF-8 to file) — 5 stories across different rotation slots, judged against §6. The MT-186 judge
harness can then get a permanent "preachiness" criterion.

## 6. Failure-mode checklist (the eval rubric)

1. **Lesson-leak:** any "learned / it's important to / that's why we / see, when you" anywhere —
   FAIL (CLEAN ENDING only guards the last sentence today; the echo needs mid-story vigilance).
2. **Skill named literally** ("sharing is caring", "that was very brave of you to say no") — FAIL.
3. **Echo hijacks the theme** — situation beat swallows >~25% of pages; the kid asked for dragons,
   not a seminar — FAIL.
4. **Stock-line drift** — same body-cue phrasing across multiple stories in a 5-run batch — FLAG.
5. **A grown-up (or magic) solves it** — the copyable action must be the hero's/companion's — FAIL.
6. **Echo missing** — model ignored the block entirely — FLAG (count across batch).
7. **Double-skill stacking** — echo present alongside parent-context blocks — bug in the
   precedence guard, not the model.

## 7. Implementation sketch (one focused session, after approval)

1. `EXPLORER_SITUATION_MAP` + `_build_real_life_echo()` + `_pick_situation()` (deterministic) +
   the precedence guard + injection line — `story_service.py`.
2. §4a VIRTUE_MAP keyword rows; §4c caveat `<=8`; §4d spine phrasing; §4e leak terms.
3. §4b feelings-instruction 6–8 split.
4. Prompt-versioning: revision hashes auto-update via `inspect.getsource` ✓; refresh the offline
   snapshot registry (`backend/eval/prompt_registry.py` / `snapshot.py --refresh`).
5. OpenRouter 5-story verify batch (§5) against the §6 rubric, per band-slot sampled.
6. Update `SEL_FRAMEWORK_ALIGNMENT.md` coverage rows (§2) + mark MT-232 Phase 2 partially shipped.

## 8. Explicitly out of scope (follow-up chunks)

- **Rollout to the other 5 bands** — same block shape, per-band situation maps and registers:
  Sprout (co-regulation, goodbye/bedtime/my-turn/big-no, repair beats), Adventurer (mixed
  feelings, fairness, belonging, being wrong publicly), Creator (identity, embarrassment, loyalty
  conflicts), Adolescent (pressure, autonomy-with-consequence, being seen — MUST align with the
  antihero care-mandate, not fight it), Adult (probably skip, or acceptance-register only).
- **Superhero mode** gets none of the spine/feelings/virtue machinery (its EMOTIONAL HEART block
  is dead code) — separate wiring chunk.
- **Interactive Adventure builder** has its own duplicate band table + Big Feelings dict — needs
  the echo separately; also the known table-drift problem (3 parallel band tables).
- `TherapeuticGoal` enum still has no wizard UI entry point; `growthPrompt` appears unwired in the
  live `QuestChoice` model; ~6k lines of authored SEL content orphaned behind
  `character_evolution_screen.dart` — inventory-and-decide chunk.
