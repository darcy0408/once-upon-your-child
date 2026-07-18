# SEL Prompt Spine — Boundary Skills (all bands) — DRAFT

**Status:** DESIGN DRAFT — unbuilt. Sibling of the shipped Explorer spine
(`docs/SEL_PROMPT_SPINE_EXPLORER_DRAFT.md`, §7 shipped 2026-07-07). This doc is MT-232
Phase 2 done properly: ambient boundary beats woven into ordinary stories, per band.
**Scope:** The live standard-story path only (`AdvancedStoryEngine.generate_enhanced_prompt`,
`backend/services/story_service.py` — note: NOT `prompt_service.py`, which is the
superhero/antihero path and is structurally disconnected; see §10). Life Quest CYOA content
(MT-232 Phases 3–5) is a separate chunk.
**Related:** `docs/SEL_PROMPT_SPINE_EXPLORER_DRAFT.md` (the template this mirrors),
`docs/SEL_FRAMEWORK_ALIGNMENT.md` (CASEL/ASCA crosswalk this upgrades), memory
`boundary_skills_feature.md` (LOCKED tone — owner approved 2026-06-07), memory
`prompt_rule_vocabulary_leaks.md` (rule-noun transcription failure mode, PR #454).

---

## 1. What is locked (non-negotiable, owner-approved 2026-06-07)

1. **Consequence, not narration.** The story SHOWS what a kept or crossed boundary causes
   through what happens next in the plot. No character ever explains it, labels it, or
   moralizes. "And that's why…", therapy voice, and fourth-wall lesson talk are hard FAILs.
2. **~1-in-5 cadence.** Roughly one in five default stories carries the beat (~1-in-3 when
   a parent flags boundaries). Never 1-in-1 — saturation breaks the disguise. Within a
   carrying story there is exactly ONE beat (which, in a typical 5-page story, is also
   ~1-in-5 of pages/moments — the two readings converge).
3. **A beat inside the kid's adventure, never the story's topic.** The kid asked for
   dragons; the beat wears the dragon costume.
4. **Three outcomes** every boundary moment maps to — **O1** assert my own limits,
   **O2** notice the "uh-oh" + take a safe next move, **O3** respect others' limits.
   O3 is the most-skipped in the wild; every band's map MUST carry it.
5. **The "uh-oh feeling" / wibbly-tummy body cue** is the approved recurring through-line
   for young bands (ties back to the Sprout emotion section). It is kid-facing vocabulary
   and is ALLOWED in prose — never add it to the leak filter.
6. **Companion dosage:** the companion may say at most ONE short peer-voiced line that
   brushes the skill ("knowing when 'no' is the brave move") — approved at that dosage,
   never more, and never as an explanation of why something worked.

## 2. Design: a second situation map in the SAME machinery — not a new block

The Explorer spine already proved the delivery vehicle: the **REAL-LIFE ECHO** block
(`_build_real_life_echo`, `story_service.py:730`) injected at the
`{virtue_instruction}{emotional_spine}{real_life_echo}` slot (line ~1596), guarded so
parent context wins (line ~1461). Its four numbered rules — echo-in-costume, feeling/body
first, small copyable action that causally turns the plot, NO LESSON WORDS — are exactly
the consequence-not-narration contract, already tuned and already covered by the
`_META_LEAK_TERMS` post-filter ("real-life echo", "copyable action", "skill practice",
"body clue").

**So the boundary spine adds no new prompt block and no new craft vocabulary.** It is:

1. **`BOUNDARY_SITUATION_MAPS`** — per-band situation dicts with the same four slots
   (`skill_label`, `situation`, `body_cue`, `copyable_action`) plus a non-rendered
   `outcome` tag (O1/O2/O3) for tests and analytics. The consequence shape is embedded in
   the slot text itself (the Explorer `saying_no` slot already does this: "a true friend
   stays after you say no") — no new template line, no new transcribable rubric noun.
2. **A server-side cadence gate** — the model never sees "1 in 5"; probability lives in
   Python, so the locked cadence is enforced exactly, not requested.
3. **Band-register variants of the echo block** — the block's wrapper text is
   parameterized per band (age phrase, costume examples, register); see §5.

### Injection + cadence gate (replaces, never stacks)

```python
# story_service.py, generate_enhanced_prompt (~line 1461)
real_life_echo = ""
if not feelings_instruction and not virtue_instruction:
    if _boundary_beat_fires(boundary_flagged):        # p = 1/3 flagged, 1/5 default
        situation = _pick_boundary_situation(age)     # band map, O-coverage rotation
    else:
        situation = _pick_situation()                 # existing generic rotation
    real_life_echo = _build_real_life_echo(age, situation, character)
```

- **One story, one skill.** The boundary beat takes the echo's slot; it never runs
  alongside the generic echo, the feelings block, or the virtue block.
- **Cadence math (Explorer):** the generic map's `saying_no` slot currently fires at
  ~1/12 of default stories. When this ships, **`saying_no` MOVES from
  `EXPLORER_SITUATION_MAP` into the Explorer boundary map** — otherwise total boundary
  presence is 1/5 + (4/5)(1/12) ≈ 0.27, over the cap. After the move it is exactly 1/5.
- **Parent-flag path:** today a parent typing "boundaries" trips the `self-respect`
  virtue on EVERY story (1-in-1 — violates the lock). When `boundary_flagged` is set
  (struggles-picker flag or keyword match: "boundaries", "saying no", "say no",
  "personal space", "speak up"), the request routes here at 1-in-3 and the virtue path
  is bypassed for that keyword family; the other 2-in-3 stories are ordinary stories.
  This is a deliberate behavior change to the keyword path and should be called out in
  the PR.
- **O3 guarantee:** `_pick_boundary_situation` rotates uniformly over the band map, and
  every band map carries ≥1 slot per outcome (asserted by test), so O3 appears at its
  fair share rather than being authored-then-never-selected.

## 3. Craft-vocabulary containment (the transcription failure mode)

Per `prompt_rule_vocabulary_leaks.md`, the model transcribes rule nouns and headings into
prose. Containment rules for everything this feature adds:

1. **No new headings.** The beat rides under the existing `**REAL-LIFE ECHO**` header,
   already in `_META_LEAK_TERMS`. The words "boundary", "boundaries", "consent",
   "assertive", "advocacy", "personal space rule" appear NOWHERE in any rendered
   fragment — not in headers, not in operative sentences, not in slot values.
2. **Slot values use only kid-facing plain words** that are safe even if transcribed:
   "no thank you", "stop, please", "my turn next", "uh-oh feeling", "not ready", "I'm
   out", "still no". A unit test lints every rendered fragment against the blocklist
   {boundar-, consent, assertiv-, advocac-, autonomy}.
3. **`_META_LEAK_TERMS` additions** (post-filter safety net): `"boundary beat"`,
   `"boundary skill"`, `"holding the limit"`. Do NOT add "uh-oh feeling", "no thank
   you", or "personal space" — those are supposed to be sayable in kid-facing prose.
4. **The consequence is described as plot, not principle**, inside slot text: "the game
   stops, then restarts better", "the friend waits — and gets the next turn for real",
   never "the boundary is respected".

## 4. Per-band situation maps

Adult (18+) is skipped for v1 (matches the Explorer doc's §8 call). Five bands ship.
`outcome` is a non-rendered tag. Slot text below is condensed; final values follow the
Explorer map's grain (one vivid concrete cue, consequence folded into the action text).

### Sprout (3–5) — `BOUNDARY_SITUATION_MAPS["sprout"]`

| key | O | skill_label | situation | body_cue | copyable_action (consequence folded in) |
|---|---|---|---|---|---|
| stop_game | O1 | saying "Stop, please!" when a game stops being fun | a game turns too rough, too tickly, too squeezy | wibbly uh-oh tummy, squished-too-tight feeling | holding up one hand and saying "Stop, please!" — the game stops right away, then starts again a gentler, funnier way |
| my_turn | O1 | keeping your turn with kind words | someone grabs the thing right out of the hero's hands | grabby-sad hands, hot cheeks | holding on gently and saying "I'm not done. Your turn next!" — the friend waits, and really does get the next turn |
| hug_check | O3 | asking before a hug and letting the friend pick | the hero wants to hug a small shy creature who goes still and small | the hero spots the clue: the friend gets quiet, tucks in, backs away | stopping, hands in lap, asking "Hug?" and waiting — the friend comes close all by itself, and the coming-close is the treasure |
| stop_means_stop | O3 | stopping the very first time a friend says stop | mid-chase or mid-splash, the friend says "stop!" in a small voice | the friend's voice goes small; their smile is gone | planting feet and stopping right away — the friend's smile comes back and the game gets good again |
| stay_and_tell | O2 | the uh-oh feeling and going to your big person | a sneaky character coaxes the hero away from the path / asks the hero to keep a heavy secret | the uh-oh tummy-squeeze that says *wait* | staying where the light is, holding the companion's paw, telling the big friendly grown-up — who listens, believes, and helps, and nobody is in trouble for telling |

Register notes: scripts are ≤5 words; body cues are tummy/hands/cheeks words; the "world
answers" are warm and immediate (this band cannot hold delayed consequence). The
`stay_and_tell` teller is ALWAYS believed and helped on the page — never scolded, never
doubted (B-SMS 9; this is the one slot where the safe adult, not the child alone, closes
the beat).

### Explorer (6–8) — `BOUNDARY_SITUATION_MAPS["explorer"]`

| key | O | skill_label | situation | body_cue | copyable_action |
|---|---|---|---|---|---|
| saying_no | O1 | *(moves verbatim from `EXPLORER_SITUATION_MAP` — locked wording: uh-oh feeling, "No thank you," kind AND firm, a true friend stays)* | | | |
| keep_the_no | O1 | saying no once more when "please please please" starts | after the hero's no, a friend begs, bargains, sulks | the wobbly want-to-give-in feeling | saying it again once, kindly — "No thank you. Let's do X instead" — and the instead becomes the better adventure, with the friend in it |
| space_bubble | O1 | asking for room when someone is too close | a character keeps crowding, grabbing, leaning on the hero's things | prickly shoulders, the uh-oh | stepping back and saying "I need some room" — the room opens up, and the thing the hero was doing finally works |
| friends_no | O3 | hearing a friend's no and letting it stand | the companion says no to the hero's exciting plan | the hero's hot flash of *but I want to* — and the companion's flat, quiet voice | stopping the asking, saying "Okay. You pick instead" — and the companion's pick turns out to hold the thing they both needed |
| heavy_secret | O2 | heavy secrets get told; sparkly surprises get kept | a character says "don't tell ANYONE" and the secret feels heavy, not sparkly like a birthday surprise | the secret sits like a stone in the tummy | telling the trusted grown-up character — who is glad to be told and helps, and the telling makes the stone feel lighter |

### Adventurer (9–12) — `BOUNDARY_SITUATION_MAPS["adventurer"]`

| key | O | skill_label | situation | body_cue | copyable_action |
|---|---|---|---|---|---|
| dare_pass | O1 | passing on a dare without leaving the group | a dare that feels wrong, with everyone watching | the drop-in-the-stomach no; heat in the face at being watched | "Not that one — I'm out for this bit," and staying present anyway — and the thing the hero kept intact is exactly what the group needs later |
| pile_on | O3 | noticing when teasing stops being funny — and steering off | the group starts ribbing one kid past the fun line | the laugh that stops feeling like laughing; the target's shoulders | not adding on, plus one redirect ("Okay — enough. Your turn on the rope") — the target comes back in and the group's energy resets |
| ask_first | O1 | "ask first" about your things, said plainly | someone takes the hero's gear/map/notebook without asking | the hot flare, the almost-shout | "Ask first — then yes, you can use it" — asked-first becomes how the crew works, and it's what prevents the later mix-up |
| not_talking | O3 | letting "I don't want to talk about it" stand | the companion goes short-answered about something and the hero wants to dig | the itch to keep asking; the companion's clipped words | dropping it and staying alongside — and the companion opens it themselves later, at the moment it matters most |
| name_the_uh_oh | O2 | saying the uh-oh about a plan out loud | the shortcut everyone likes has something wrong about it the hero can feel | the small cold no under the excitement | naming it plainly ("Something's off about this way") and offering the other route — and the route shows everyone why |

### Creator (13–14) — `BOUNDARY_SITUATION_MAPS["creator"]`

| key | O | skill_label | situation | body_cue | copyable_action |
|---|---|---|---|---|---|
| quit_it | O1 | making "quit it" land without a fight | the too-much friend — shoulder grabs, hat swipes, headlock hellos | the flinch the hero keeps swallowing | a level voice, eyes up: "Quit it. I mean it." — it stops, and the friendship is easier afterward, not colder |
| loyal_no | O1 | staying loyal without saying the false thing | a best friend wants the hero to back up a story that isn't true | the twist of wanting to be loyal and honest at once | "I can't say that part. I'll stand with you while you tell it straight" — and standing there is what makes the telling survivable |
| their_stuff | O3 | not reading what isn't yours, even when it's right there | the open notebook / unlocked screen of someone the hero is curious about | the lean-in pull of *just one look* | closing it / turning away — and being the one person they later trust with the real version |
| pile_on_chat | O3 | not feeding a pile-on | the group's jokes converge on one person and get sharper each round | the hero's own joke, already loaded, suddenly heavy | not sending it, changing the subject with something actually funny — the pile-on starves and nobody has to be shamed for it |
| early_exit | O2 | leaving when a hangout tilts wrong | the evening bends toward something with that off feeling | the low hum of wrongness under the fun | the plain exit ("I'm heading out — see you tomorrow") plus a message to a trusted person — the leaving is clean, and tomorrow is normal |

### Adolescent (15–17) — `BOUNDARY_SITUATION_MAPS["adolescent"]`

Must align with the antihero care-mandate register (steady, unglamorous, no cartoon
villains): the pusher is shown gently in the wrong, never demonized; the no never
punishes anyone.

| key | O | skill_label | situation | body_cue | copyable_action |
|---|---|---|---|---|---|
| hold_the_no | O1 | keeping a no steady as the pressure changes shape | a no gets answered with charm, then guilt, then heat | the pull to smooth it over — the going-along feeling | the same no, fewer words each time ("Still no"), staying steady and staying kind — and the plot itself shows the no was load-bearing, with no told-you-so from anyone |
| check_in | O3 | reading hesitation and stopping to ask | mid-plan or mid-moment, the other person goes quiet or stiff | the hero notices: the half-step back, the yes that sounds like a question | stopping to ask "You good? We can bail." and meaning it — and what the evening becomes afterward is realer than what was planned |
| the_exit | O2 | the uh-oh and the clean exit | the night starts going somewhere the hero can feel is wrong | the cold spot under the noise | the plain line ("I'm out — text me tomorrow") and the call for the ride — leaving reads as strength on the page, and costs the hero nothing that mattered |
| no_is_a_sentence | O1 | declining without writing an essay about it | the hero is expected to justify a no until it collapses | the reflex to explain, apologize, explain again | "No, I'm good." — full stop, no speech — and the group recalibrates around it by the next scene |
| their_no_stands | O3 | taking someone's no the first time | someone tells the HERO no — won't come, won't share it, won't stay | the sting, and the urge to ask again in a different shape | taking it the first time, no punishing silence afterward — and the next scene between them is better *because* the no cost nothing |

## 5. Band-register variants of the echo block

`_build_real_life_echo(age, situation, character)` keeps its four-rule shape but gains
per-band wrapper text (age phrase, costume examples, register). The Explorer text stays
exactly as shipped. Two new variants shown in full; Adventurer interpolates
Explorer→teen, Creator uses the teen variant.

**Sprout (≤5) variant** — shorter, budgeted for 10–25-word pages:

```
**REAL-LIFE ECHO** (invisible skill practice — weave in, never announce):
This story quietly gives {character} one tiny moment of practice: {skill_label}.
1. THE ECHO: One beat of the story takes the SHAPE of this real moment: {situation}.
   Keep the magic — the moment wears a costume (a cloud that hugs too tight; a snail
   who tucks into its shell). The beat fits in 2-3 pages, never the whole story.
2. TUMMY FIRST: When the moment lands, show it in the body first — {body_cue} — in
   toddler words, fresh for THIS story.
3. THE TINY ACTION IS THE KEY: What turns the moment is something a real 3-5 year old
   could say or do tomorrow: {copyable_action}. {character} (or the friend) DOES it on
   the page, and the very next thing that happens is better BECAUSE of it — right away,
   on the same page or the next. Not magic, not luck.
4. NO LESSON WORDS: Nobody explains. Nobody says "it's important to..." or "good job
   using your words". The proof is what happens next — the game turns fun, the friend
   comes close, the smile comes back. If a sentence sounds like a grown-up teaching,
   cut it and show the happy result instead.
```

**Teen (13–17) variant** — same skeleton, dial the register:

```
**REAL-LIFE ECHO** (invisible — weave in, never announce):
This story quietly gives {character} one moment of real practice: {skill_label}.
1. THE ECHO: One beat of the main plot takes the SHAPE of this real situation:
   {situation}. Keep the story's own world and stakes — the reader should feel seen,
   never targeted; the story never turns to face them.
2. BODY FIRST: When the moment lands, {character} feels it physically before acting —
   {body_cue}. Name it in fresh, specific words for THIS story; no stock lines.
3. THE SMALL MOVE IS THE HINGE: What turns the moment is something a real teenager
   could actually do tomorrow without it becoming a scene: {copyable_action}.
   {character} DOES it on the page — and the plot visibly bends BECAUSE of it. Not
   luck, not an adult stepping in, not the other person conveniently vanishing. If
   there are multiple attempts, an early one may go wrong precisely because the
   feeling went unhandled — and this move is why the later one lands.
4. NO LESSON WORDS: No character explains why it worked, no inner monologue summarizes
   the takeaway, nobody gets an I-told-you-so. Whoever pushed is shown gently in the
   wrong by events, never punished by the narrator. The proof is the next scene. If a
   sentence sounds like advice, cut it and show the consequence instead.
```

Note rule 4's teen additions (no takeaway-summarizing inner monologue; no narrator
punishment) — those are the two teen-specific leak channels the Explorer wording doesn't
cover.

## 6. CASEL 5 / ASCA mapping

| Framework code | Standard | Carried by | Coverage change in `SEL_FRAMEWORK_ALIGNMENT.md` |
|---|---|---|---|
| **B-SS 8** | Advocacy for self and others; assert self when necessary | O1 slots in all five bands; `pile_on`/`pile_on_chat` (others-advocacy) | ● stays direct; "ambient beats" footnote extends from Explorer-only to five bands |
| B-SS 1 | Assertive communication | Every copyable script ("Stop, please!", "Still no", "Quit it") | ◐ → strengthen note |
| B-SMS 9 | Personal safety skills | `stay_and_tell`, `heavy_secret`, `early_exit`, `the_exit` (O2 family) | ◐ → ● (tell-a-trusted-adult + exit moves now ambient, not opt-in) |
| B-SMS 1 | Responsibility for self and actions | O1 family (owning and holding one's own limit) | ◐ unchanged, add tie |
| B-SS 3 | Positive relationships with adults | `stay_and_tell`, `heavy_secret` (adult is glad to be told, helps, never scolds) | ◐ → strengthen note |
| B-SS 4 / Social Awareness | Empathy; reading others' states | O3 family (`hug_check`, `friends_no`, `not_talking`, `check_in`, `their_no_stands`) | ◐ → strengthen note |
| CASEL Self-Awareness | Interoception before action | The uh-oh/body-cue step in every slot | Already Strong; add five-band note |
| CASEL Relationship Skills | Resisting negative social pressure | `dare_pass`, `hold_the_no`, `no_is_a_sentence` | Named in §1 table "resisting negative social pressure" — first direct content |

## 7. Worked example A — Sprout (age 4, `hug_check`, O3, consent-to-touch)

The shape the model should hit (condensed; real output is 8–10 pages of 10–25 words):

> Once upon a time, Mia and Pip the glowworm tiptoed into the Moss Garden. TIP-TAP,
> TIP-TAP. Somewhere close, something was humming.
>
> There, on a mushroom, sat the Singing Snail! Its shell was shiny like a puddle.
> Mia's arms flew open wide. Mia LOVED hugs.
>
> "Hug!" said Mia. But the snail went FLOOP — all the way inside its shell. The humming
> stopped.
>
> The garden went very quiet. Pip whispered, "Its shell says uh-oh."
>
> So Mia sat down in the moss. She put her hands in her lap. She waited. One... two...
> PEEK! Two little eyes came out.
>
> Mia held out one flat hand, very still, very soft. "You pick," she said.
>
> The snail slid on — SQUISH-squish — right onto her hand! And then...
>
> The snail sang its moss song, just for Mia. Pip glowed like a tiny lamp. And the whole
> garden hummed along.

**Why this passes the locked tone:** the crossed moment (grab-hug → FLOOP, the humming
stops) and the kept moment (hands in lap, "You pick" → the snail chooses, the song
comes) are both pure plot consequence — the song is causally unlocked by the waiting,
not gifted. The other-creature's cue (tucking in) carries O3's noticing step. Pip's one
whispered line is inside the approved companion dosage and names a cue, not a lesson.
Nobody says "we ask before hugs" — the story never turns to the reader. Ends on the
world (the garden humming), not the takeaway.

## 8. Worked example B — Adolescent (age 16, `hold_the_no`, O1, peer pressure)

Excerpt from inside a longer city scavenger-hunt adventure (third-person witness POV):

> The storm drain exhaled cold air at them. Marcus was already crouched at its mouth,
> phone-light skating over the wet concrete. "Cuts off half the route. In and out."
>
> "No," Dez said. "I'm not doing the drain."
>
> "It's barely even water."
>
> "Still no."
>
> Marcus laughed the laugh that wasn't one. "You always do this. Every single time it
> gets good."
>
> There it was — the old pull, the going-along feeling, warm as a hand on the back of
> the neck. Smooth it over. Laugh. Duck in first, even.
>
> Dez's jaw ached from unclenching. "I'll take the footbridge. Meet you at the
> checkpoint." And that was all — no speech attached — just sneakers loud on the gravel
> bank.
>
> The footbridge route was longer, and lonelier, and the wind up top pushed like it had
> an opinion. Halfway across, Dez stopped. Below the far pylon, under one dying sodium
> lamp, somebody had painted the mural — the heron, the seven stars. The third clue.
> Photographed. Logged. Done.
>
> Marcus and Theo reached the checkpoint twenty minutes late, jeans dark to the knee —
> the drain had dead-ended at a bolted grate anyway. Nobody said anything about it.
> Marcus looked at the clue photo for a long moment, then handed back the flashlight —
> Dez's flashlight, borrowed since forever — grip first.
>
> "Northside next," he said, and this time he waited for Dez to nod before he moved.

**Why this passes the locked tone:** the escalation runs charm → guilt ("you always do
this") → and the no gets *shorter*, not louder ("Still no"), which is the copyable move.
The consequence is carried entirely by plot: the kept no leads Dez's route to the clue;
the drain dead-ends; the flashlight handed back grip-first and Marcus *waiting for the
nod* are the world registering the no as load-bearing. Marcus is wrong but not
demonized, wet but not humiliated; nobody — including Dez's inner voice — says a
told-you-so or summarizes a takeaway. The body cue ("the going-along feeling") is named
fresh, in-world. Ends on motion, not moral.

## 9. Failure-mode rubric (inherits Explorer §6, adds boundary-specific FAILs)

1–7. All Explorer §6 checks apply unchanged (lesson-leak, skill named literally, echo
hijacks theme, stock-line drift, adult/magic solves it, echo missing, double-skill
stacking).

8. **Rubric-word leak:** "boundary/boundaries", "consent", "assertive", "personal space
   rule" appear in prose — FAIL (kid-sayable words like "uh-oh feeling", "no thank you",
   "my turn" are fine).
9. **The pusher is demonized:** the character who crossed the line is humiliated,
   exiled, or narrator-punished — FAIL. Gently in the wrong, by events, is the ceiling.
10. **No-as-weapon:** the hero's no punishes someone, or someone's no to the hero is
    framed as a wound to overcome — FAIL (O3 inversion).
11. **The no collapses:** hero says no, gets pushed, and the story rewards giving in —
    FAIL (worst possible outcome for this feature).
12. **Told-you-so:** any character or inner monologue scores points off the consequence
    — FAIL.
13. **Teller doubted (Sprout/Explorer O2):** the trusted adult scolds, doubts, or makes
    the telling feel like trouble — FAIL.
14. **Cadence breach (batch-level):** boundary beats in >~1-in-4 of an unflagged 20-story
    batch, or two beats in one story — gate bug, not a model issue.

## 10. Implementation plan (one focused session per phase, after approval)

**Correction to the build brief:** the wiring point is
`backend/services/story_service.py`, NOT `prompt_service.py`. `prompt_service.py`
(`PromptService.build_story_prompt` + `_build_superhero_prompt*` / antihero) is the
superhero path, which the Explorer spine explicitly left disconnected (Explorer doc §8);
it stays out of scope here too.

**Phase A — code (`story_service.py`):**
1. `BOUNDARY_SITUATION_MAPS: dict[str, dict[str, dict]]` (5 band keys; slots per §4;
   `outcome` tag non-rendered). Move `saying_no` out of `EXPLORER_SITUATION_MAP` into
   the Explorer boundary map (cadence math, §2).
2. `_get_boundary_band(age) -> str | None` (sprout ≤5, explorer ≤8, adventurer ≤12,
   creator ≤14, adolescent ≤17, else None — mirror `_pick_sensory_palette`'s laddering).
3. `_pick_boundary_situation(age, seed=None)` — seed semantics copied from
   `_pick_situation` (sha256, deterministic under seed, uniform random in prod).
4. `_boundary_beat_fires(flagged: bool, seed=None) -> bool` — p=1/3 flagged, 1/5
   default; deterministic under seed for the eval harness.
5. `boundary_flagged` detection: keyword family ("boundaries", "saying no", "say no",
   "personal space", "speak up") checked against `therapeutic_prompt` BEFORE
   `_get_virtue_instruction`; when matched, suppress the `self-respect` virtue route and
   set the flag (behavior change — PR callout).
6. Generalize `_build_real_life_echo` band wrappers per §5 (Explorer text unchanged
   byte-for-byte — it is shipped and verified).
7. Injection guard per §2 at line ~1461; the `{real_life_echo}` template slot is
   untouched.
8. `_META_LEAK_TERMS` += "boundary beat", "boundary skill", "holding the limit".

**Gate:** env flag `BOUNDARY_SPINE_ENABLED` (default **OFF**), read the same way
`ANTIHERO_CRUX_ENABLED` is (config-service pattern), wrapping only the
`_boundary_beat_fires` call — OFF reproduces today's behavior exactly (including
`saying_no` staying in the generic map: make the map-move conditional on the flag, or
ship the move in the same PR that flips it). Flip ON only after the Phase C verify batch
passes.

**Phase B — tests (`backend/tests/unit/test_story_service.py`, mirroring the existing
echo tests):**
- Map completeness: every band map has all four render slots + `outcome`; every band has
  ≥1 of each of O1/O2/O3.
- Vocabulary lint: rendered fragment for every (band × slot) contains none of
  {boundar-, consent, assertiv-, advocac-, autonomy}.
- Determinism: seeded `_pick_boundary_situation` / `_boundary_beat_fires` stable across
  processes.
- Precedence: parent feelings/virtue context present → no boundary beat; beat present →
  generic echo absent (no stacking).
- Flag OFF → prompt byte-identical to current golden output.
- Explorer generic map no longer contains `saying_no` when flag ON.
- Remember: fresh worktrees need `backend/.env` copied before calling test failures real
  (memory `worktree_missing_env_test_failures`).

**Phase C — verification (before flipping the flag):**
- Refresh the prompt snapshot registry (`backend/eval/prompt_registry.py`,
  `snapshot.py --refresh`).
- OpenRouter verify batch against `gpt-5-mini` (recipe in memory
  `verify_story_prompt_via_openrouter`): 2 stories × 5 bands × forced boundary slot
  (seeded), judged against §9; plus one 20-story unflagged batch for the cadence count
  (§9.14).

**Phase D — docs:** update `SEL_FRAMEWORK_ALIGNMENT.md` rows per §6; mark MT-232
Phase 2 shipped; add the boundary maps to the Explorer doc's §8 rollout ledger.

## 11. Explicitly out of scope (unchanged from Explorer §8)

- Superhero mode and the Interactive Adventure builder (own prompt stacks; the
  interactive builder's duplicate band tables are a known drift problem).
- Life Quest CYOA boundary content, the self/others emphasis toggle, and the parent
  struggles-picker UI (MT-232 Phases 3–5) — the `boundary_flagged` keyword hook in
  Phase A.5 is deliberately built so the picker can set the same flag later without
  prompt changes.
- Adult band (18+): no boundary map v1.
- Generic (non-boundary) echo rollout to Sprout/Adventurer/Creator/Adolescent — sibling
  task; the §5 band wrappers built here are shared infrastructure for it.
