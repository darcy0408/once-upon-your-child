# Prompt Craft Pass — 2026-07-17

Deep literary-craft review of the six standard-path age-band prompts
(`backend/services/story_service.py`, `AdvancedStoryEngine.generate_enhanced_prompt`),
one day after PR #454's rubric-transcription fix. Method: the six-band OpenRouter
harness from `verify_story_prompt_via_openrouter` — fixed inputs per band
(ages 4 / 7 / 10 / 13 / 16 / 30, explicit sensory palette), gpt-5-mini
(`openai/gpt-5-mini`, `max_completion_tokens=28000`), **2 generations per band
before and 2 after** (24 stories total, ~$0.40). Artifacts in session scratchpad
`craft/baseline/` and `craft/after/` (not committed, per #454 precedent).

Verdict up front: #454's leak fixes held (10 of 12 baseline stories zero leak-pattern
hits). What remains is one layer subtler — the model obeys each rule *mechanically*,
narrating its compliance. This pass targets those compliance-narration habits.

---

## 1. Per-band baseline critique

### Sprout (3-5, age 4) — the weakest band. Verdict: coherence crisis.
- **Story logic collapses under constraint load.** g1 ("The Small Bright Bit") is
  a non-sequitur chain: a bread crumb falls, gets a paper plane, "slid into the
  moon". Theme was "A trip to the moon"; no trip occurs. The band's rule stack
  (10-25-word pages, CVC vocab, forbidden words, rule of three, 6-10 sound words,
  page hooks, companion dialogue ×4) crowds out cause-and-effect. g2 was coherent
  (box → flies to moon → pebble mends the dim patch → home), proving the model
  *can* do it — nothing was demanding it.
- **Mechanical opener**: both gens open identically — "Once upon a time, Milo felt
  curious." The EMOTIONAL SPINE's "put the feeling on the page early — named simply"
  bolts the feeling label straight onto the mandated ritual phrase.
- **Companion telegraphese**: Pip's dialogue is body-status reports — "My paws
  jump.", "My ears warm.", "I'm small." — an artifact of feeling+body-cue rules
  bleeding into dialogue. Not how any child's friend talks.
- Emotional beats: present but flat ("Milo felt scared" → "Milo felt brave" — as
  specified, no more). Endings: both land warm and sensory (good). Rhythm: fine
  for read-aloud; g2's "warm rolls" refrain is genuinely charming.

### Explorer (6-8, age 7) — healthiest band. Verdict: solid, two tics.
- Real-life echo (SEL) integration is the app's best trick — "Turns?" offered
  mid-adventure lands exactly as designed.
- **Feeling-naming narrated**: "she even named it: grabby", "She told herself the
  fizzing heat by name" (both gens). The REAL-LIFE ECHO rule "Name the feeling
  simply, by name" gets transcribed as the *act* of naming instead of the name.
- **Orphan sound words**: g2 bolts a bare ALL-CAPS word to the end of nearly every
  page ("CLINK.", "CREAK.", "BONG.", "TAP.", "CLACK.") — sound with no source,
  satisfying the letter of the sound-word rule. One "a TRY knocking sound" glitch in g1.
- Voice, pacing, endings: age-true; hedgehog-knight Bramble's arc (worry → "For
  maps and naps") is the kind of thing the band should produce.

### Adventurer (9-12, age 10) — good bones. Verdict: menu-deliberation formula.
- **Option catalogues**: both gens narrate decisions as tidy either/or menus, twice
  or more per story — "He could try to mend the tear... Or he could chase...",
  "two hard choices: keep trying to force... or follow...". The "two imperfect
  options" constraint is being executed as a visible ledger.
- **Residual leak family**: "Jordan's first plan had not only failed; it had eaten
  a part of what they were chasing" ("first plan" + failure verdict — the #454 bans
  covered "first attempt"/"the plan failed" but not these variants); "a small
  trade-off spinning in his head" (the spine's "a hard trade" surfacing).
- Atmosphere, momentum, and endings are strong (the sleeping-cat-drawn-in-ink
  close of g1 is genuinely earned). Nyx's riddle voice is distinct.

### Creator (13-14, age 13) — better than expected. Verdict: minor leaks, real voice.
- Band identity note: age 13 draws AGE_CONSTRAINTS["11-13"] tone notes but the YA
  persona and teen craft rules — a hybrid. In practice the output reads distinctly
  from both Adventurer (school-scale social stakes, interiority) and Adolescent
  (third person, shorter, less noir) — differentiation is real.
- Leaks: "The plan had a downside:" (the 11-13 rule quoted its own anti-example
  noun); "That was the change: he stepped into the risk he'd always avoided" —
  the model shows the companion's change *and then captions it*. One POV slip
  ("her secret was not mine alone").
- Deliberation menus appear here too (p10 of g1 is a four-option catalogue).
- Emotional beats and endings: strong; Theo's joke-armor characterization is
  exactly the band register.

### Adolescent (15-17, age 16) — most ambitious, most damaged. Verdict: essay-coda syndrome.
- **Worst single artifact of the batch** (g1): "every time I pictured my father's
  face—no, stop, no family members—and the way he'd taught me... erase that."
  The SAFETY rule "Do NOT invent characters or family members not provided"
  transcribed as an in-prose self-correction. A reader sees the puppet strings.
- **Lesson recap paragraphs**: "For my part, I learned that a record of a moment
  could be misleading...", "We had both learned how dangerous and how necessary
  deciding was." CLEAN ENDING only polices the final sentence; first-person teen
  narrators write reflective-essay codas three paragraphs earlier.
- **Arc captioning**: "She had shifted without making a proclamation." / "Her
  actions had been the hinge." / "her shift had moved her from a rigid love of
  the map to..." — showing then telling the companion arc, repeatedly.
- **Multi-coda sag**: both gens spend their last 3-4 pages on chained aftermaths
  (hearing → talk → weeks later → months later). Momentum dies at 75%.
- Voice: first person, distinct from every other band; scene-level prose is
  frequently excellent ("the name landed like a gavel").

### Adult (18+, age 30) — strongest prose. Verdict: same telling-after-showing tax.
- Both gens are genuinely literary (kettle-tick time-keeping; "an argument-colored
  sky"). Grief theme handled with restraint despite "CONFLICT: A magical mystery
  needs solving." pushing light fabulism into a grounded brief.
- **Arc captioning again**: "Sam changed in ways that were not dramatized" (while
  dramatizing it), "That tiny, private tenderness felt like an alteration: an
  action that quietly contradicted his old habit", "The sentence itself was the
  change." One "a want wrapped in a sentence too short to hold it" (skeleton-check
  word). g2: "That was the trade: privacy in exchange for help" appears in the
  *Creator* g2 — same family.
- **Multi-coda**: g1 ends four times (pages 14-17: drive home / weeks later /
  ordinary morning / last trip).

### Cross-band systematic findings (ranked by impact)
1. **Compliance narration** — the model shows what a rule asks, then *captions* it
   (change, trade, failure verdicts, feeling-naming, option menus). Successor to
   #454's vocabulary transcription: the words are new, the tell is the same. All
   bands 7+.
2. **Sprout coherence** — no rule demanded cause-and-effect or theme delivery; the
   constraint stack rewards rule-satisfaction over story logic.
3. **Teen/adult ending discipline** — lesson recaps and epilogue chains cluster in
   the last quarter, exactly where a parent reads "AI slop".
4. **Grounded-theme friction at 13+** — default conflict line said "magical
   mystery" even where IMAGINATIVE ELEMENTS says grounded is equally valid.

---

## 2. Changes made (all in `backend/services/story_service.py`)

Prompt side:
- **STRICT_OUTPUT_CONSTRAINTS rule 3**: added the change/trade-caption family to
  the banned transcription forms ("That was the change:", "That was the trade:",
  "She had shifted", "His actions had been the hinge") + a no-self-editing-traces
  clause (the "—no, stop, no family members—" failure). Rule 4 extended from
  endings-only to lesson sentences *anywhere* ("learned that", "we both learned",
  "I realized that what mattered...").
- **SILENT SKELETON CHECK** (8-12, 13-18, adult): word list extended ("downside",
  "the trade", numbered plans/tries, "shift" as a person-noun) and a second pass
  added: delete any sentence that captions a change/choice/trade already shown.
- **COMPANION ARC** (8-12, 13-18, adult): "show it, then STOP" — never follow the
  changed behavior with an explanation sentence.
- **TRY/FAIL** (8-12, 13-18): banned-example set widened to "their first plan",
  "Plan A", "They had failed.", "It hadn't worked.".
- **Deliberation rules** (hard complexity constraints 9-10, 11-13, 14-18): weighing
  happens once, inside the scene, never a recurring either/or catalogue; 11-13
  anti-example no longer hands the model the word "downside".
- **Aftermath budget**: teen block rule 7b + adult block rule 4b — at most ONE
  closing scene/time-skip after the turn; no epilogue chains; reflection lives in
  scene action, not summary paragraphs.
- **Sprout**: new delight rule 6 STORY LOGIC (every page must answer "why did that
  happen?", theme's simple promise must be kept, nothing happens "just because");
  EMOTIONAL SPINE rule 1 now bans bolting "felt curious" onto the opening line —
  feeling shown through action first, named a page or two in; companion dialogue
  must be sayable by a small child ("Wait for me!"), body-status reports banned.
- **Explorer**: sound words must be the sound OF an action in an adjacent sentence —
  bare ALL-CAPS words parked at page ends are a FAIL. REAL-LIFE ECHO rule 2: the
  feeling word appears in dialogue/thought; narrating the act of naming is a FAIL.
- **Emotional spine (≤12 and 13-14)**: "a hard trade"/"A real trade" reworded to
  remove the copyable noun ("something given up or lost").
- **CONFLICT default** now band-conditional: 13+ gets "A tension at the heart of
  the theme comes to a head..." instead of "A magical mystery needs solving."

Post-processing net:
- `_FAILURE_ANNOUNCEMENT_PATTERN`: now also catches "They/We had failed." variants.
- `_META_LEAK_TERMS`: + "that was the change", "that was the trade" (multi-word,
  high-precision; the short-declarative branch of `_strip_meta_leakage` strips them).
- New `_ESCALATION_LABEL_PATTERN` in `_strip_attempt_labels`: "The first/second/
  third escalation came/arrived/hit..." → "More pressure came/arrived/hit..."
  (ordinal label excised in place, event kept). Added after round 3 caught one
  Adolescent draw numbering its escalations despite the prompt ban — those
  sentences are long, so the short-declarative filter branch can never reach
  them. Unit tests added in `backend/tests/test_strip_attempt_labels.py`
  (3 new cases; 10 pass).

---

## 3. Before/after validation (2 gens per band per round)

Leak-pattern regex scan (21 patterns incl. the #454 set): baseline 4 hits across
12 stories → **after 0 hits across 12 stories**. Pattern-family greps
(feeling-naming narration, change/trade captions, "learned that" recaps,
either/or catalogues): baseline 12 matching stories → after 0 true positives
(4 grep matches, all legitimate plot verbs like "someone had shifted split
times").

Concrete prose deltas, same fixed inputs per band:

**Sprout** — biggest single win: story coherence.
- Before (g1): crumb → paper plane → "It slid into the moon." No trip to the moon
  occurs; page-to-page causality absent. Opens "Once upon a time, Milo felt curious."
  (both gens, identical). Pip: "My paws jump." / "My ears warm."
- After (g1): a real round trip — silver moon-patch lifts Milo up, a loose pebble
  is the moon's problem, three causal tries (press → blow → blanket), pebble
  reseated, "The moon's pale patch stitched whole again," home to bed. Feeling
  named on p2, not in the opener. Pip now talks like a friend: "I'm scared.",
  "Try gentle, Milo.", "Hold tight!", "Look up, Milo!"
- Residual: my spine rule's example action ("pressing a nose to the window") was
  copied by both gens — the example is now removed from the rule (invent-fresh
  wording instead); re-validated in round 3.

**Explorer** — both tics gone.
- Before (g2): five pages end in a bare caps word with no source — "CLINK.",
  "CREAK.", "BONG.", "TAP.", "CLACK."; "She named it the fizzing heat", "She told
  herself the fizzing heat by name".
- After (g2): every sound word is caused — "the shelf sneezed a pile of volumes
  down. CRASH.", "he hit the thin board and the shelf showed a hidden latch.
  CLACK." Feeling appears as the character's own line; zero naming-narration.
- Residual: the rewritten echo rule's example line ("I'm so frustrated!") was
  copied verbatim → example removed from the rule; re-validated in round 3.

**Adventurer** — menu-deliberation collapsed to one embodied weighing.
- Before (g1): two+ tidy catalogues ("He could try to mend the tear... Or he could
  chase..."), plus "Jordan's first plan had not only failed; it had eaten...",
  "a small trade-off spinning in his head".
- After (g1): exactly one weighing passage, held inside the scene ("Both choices
  felt brittle... Jordan felt the tightness under his ribs and decided—he would
  go."); no plan-numbering, no failure verdicts, no "trade-off".
- Residual: one idiomatic "now Jordan felt the cost of that" (borderline; reads
  naturally).

**Creator** — leak nouns gone, weighing now singular and embodied.
- Before: "The plan had a downside:", "That was the change: he stepped into the
  risk...", "That was the trade: privacy in exchange for help." (g2), one POV slip.
- After: zero occurrences of downside/change-caption/trade-caption in either gen;
  the one option passage is embodied ("Her chest felt like it had two doors and
  each one opened into a room she did not want to enter."). No POV slips.

**Adolescent** — worst offenses eliminated; one soft residual.
- Before (g1): in-prose safety self-correction ("—no, stop, no family members—...
  erase that"); "My first plan was not brave."; "For my part, I learned that...";
  "We had both learned..."; "She had shifted without making a proclamation.";
  both gens close with 3-4 chained epilogues.
- After: no self-editing traces, no "learned that" recaps, no plan-numbering;
  both gens end in a single aftermath scene on a concrete image (hand on the
  repaired turf seam as rain starts). Residual (g1): "Her change was a practice,
  not a proclamation." — a paraphrase of the anti-example my new rule quoted;
  the quotable noun was removed from the rule and the band re-validated in
  round 3. One "she had learned the cost of silence" idiom survived.
- Round 3 (post-tweak, 2 gens): no lesson recaps, single-coda endings held.
  One bad draw (g1) numbered its escalations ("The first/second/third escalation
  came/arrived/hit...") — the #454 leak recurring stochastically; now excised by
  the new post-filter (see below). g2 showed the *negation-caption* variant
  ("There was no proclamation. The change lived in what she did next:") — the
  model narrating its obedience to the don't-announce rule; documented as a
  known residual (see Not-Fixed #8), no safe post-filter exists for it.

**Adult** — captioning gone, single-movement endings.
- Before (g1): "Sam changed in ways that were not dramatized", "That tiny, private
  tenderness felt like an alteration: an action that quietly contradicted his old
  habit...", "a want wrapped in a sentence too short to hold it"; four chained
  endings (p14-17). (g2): "The sentence itself was the change."
- After (g1): ending is one scene, uninterpreted — "Sam touched the small hairline
  crack in the teacup with a fingertip, then set the cup on the saucer and left it
  there... not solved but carried." No want/flaw/arc nouns, no change-captions.
- Residual (g2): "In that gesture... Sam changed the direction of the day" — a
  plot statement, not a rubric caption; acceptable. g2 overran the 5200-word hard
  cap by ~6% (5507) — pre-existing ceiling behavior, not introduced by this pass.

Round-3 spot re-validation (sprout / explorer / adolescent, 2 gens each, after
removing the three quotable examples the first version of these rules had
introduced — the #454 law applies to fix-rules too):
- Sprout: openers now varied (tapping the window glass / a kite on a fence);
  no copied example actions; coherence held (both gens are causal round trips
  to the moon); feeling named on p2-p3, never in the opener.
- Explorer: clean both gens; no "I'm so frustrated!" copy; sound words all
  anchored to actions.
- Adolescent: see residuals above — one escalation-numbering draw (now netted
  by the post-filter) and one negation-caption; otherwise clean, single-coda,
  strong first-person voice.

Test status: full backend suite in the worktree — **1874 passed, 1 failed**;
the failure is `tests/smoke/test_production_smoke.py::TestCoppaAgeGateSmoke::
test_no_age_session_blocked_with_age_required`, a live-prod smoke test that
asserts the COPPA age gate is ON — prod has the COPPA flags OFF by owner
decision since 2026-07-15, so this is environmental, unrelated to this pass
(the age-gate flag state, not the prompt code). Prompt-related suites re-run
after the final tweaks: 185 passed. `black --check` and `flake8` clean on the
edited file.

---

## 4. Deliberately NOT fixed (prioritized for later sessions)

1. **SAFETY_GUARDRAILS register at 15+/adult** — "Keep the tone warm... full of
   wonder" and "no scary imagery... for children" sit verbatim in the Adolescent
   and Adult prompts, contradicting those bands' own tone notes ("moral ambiguity",
   "existential stakes"). Fix = band-conditional wording that keeps every hard
   content limit but drops the child-register lines for 15+. Deferred because
   safety-text edits deserve their own review pass, not a craft-pass rider.
2. **CUSTOM REQUESTS block child-register at adult** — "safe for the child",
   "ride a dragon" example, rendered for 30-year-olds. Cosmetic; no observed harm.
3. **Creator band identity** — age 13 draws "11-13" tone notes + YA persona + teen
   rules (hybrid), and its Tone line says "third-person limited" while the POV rule
   allows close first-person. Output quality was fine, so left alone; a clean fix
   is a dedicated 13-14 AGE_CONSTRAINTS entry, which touches word-count tables and
   tests — its own session.
4. **Adventurer "wonder" mandatory element at 13** — "a moment of genuine wonder"
   applies through age 13; harmless but slightly off-register for grounded teen
   themes (coping_instruction switches at 14).
5. **Explorer refrain quality** — no rule guards against semantically-empty sound
   effects ("a TRY knocking sound"); low frequency, revisit if it recurs.
6. **Superhero/saga path** (`prompt_service.py`) — saga continuity blocks reviewed
   statically: Explorer's warm "LAST TIME..." recap and Adventurer's momentum block
   are well-built (no debt-mechanics at 6-8 — deliberate; allies reused not
   reintroduced). Not exercised live this pass (standard path was the target);
   the arc-caption ban added to STRICT_OUTPUT_CONSTRAINTS does not flow to that
   path's builders — porting the same clause to the superhero band builders is a
   cheap follow-up.
7. **First-person POV verification for Adolescent** — both baseline gens chose
   first person (good, differentiated); no rule guarantees the 15-18 "narrator has
   a personality" note survives contradiction with the global name-echo rules if
   inputs vary. Watch, don't fix.
8. **Negation-captioning (Adolescent)** — the model sometimes narrates its
   obedience to the don't-announce rules ("There was no proclamation. The change
   lived in what she did next:"). Rule-side bans of negations tend to feed the
   very nouns they ban; no safe post-filter exists (negated announcement
   sentences are often legitimate prose). Frequency ~1 draw in 6 at this band.
   If it persists on prod, the next lever is a rewrite-pass instruction scoped
   to the final two pages only.
9. **Adult hard word-cap adherence** — one after-round adult draw overran the
   5200-word HARD LIMIT by ~6% (5507). Pre-existing behavior (ceiling language
   untouched by this pass); if it matters, tighten the stated ceiling below the
   real budget rather than adding more emphasis.
10. **Sprout companion stock lines** — the companion-dialogue rule's positive
   examples ("Wait for me!") get copied occasionally. They are natural kid
   lines, so harmless per-story, but across a subscriber's library they will
   read stock. Fix is example-free phrasing like the round-3 spine fix.
