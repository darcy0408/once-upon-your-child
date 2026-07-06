# Prompt Ceiling Pass — 2026-07-05 (Fable session)

Second ceiling pass on the story-generation prompt system. The 2026-07-04 pass added
negative craft rules (banned phrases, clean endings, title formula ban). This pass fixed
five structural issues that pass didn't touch — all in the **live standard path**,
`AdvancedStoryEngine.generate_enhanced_prompt` (`backend/services/story_service.py`).

## Context: which prompt is actually live

For normal stories prod uses `AdvancedStoryEngine.generate_enhanced_prompt`
(`story_tasks.py:1553`). `PromptService.build_story_prompt` runs **only for superhero
mode** (`story_tasks.py:1466`). The eval harness mirrors this correctly
(`backend/eval/generation.py`).

## Findings & fixes

### 1. EMOTIONAL HEART was dead code on the main path (HIGH)
The #272 "EMOTIONAL HEART" upgrade (theme-as-spine, earned closing reframe) was added to
`PromptService.build_story_prompt`'s non-superhero body — which nothing in prod executes.
A standard story with no feelings-flow got *zero positive emotional guidance*; only
negative rules ("don't state the lesson"). Negative rules prevent LLM tells; they don't
make a story land.

**Fix:** new `_build_emotional_spine(age, theme, character)` injected into the live
builder, calibrated per band (≤5 / 6-12 / 13-14 / 15+). The existing ENDING craft rule
now defers to it instead of duplicating it.

### 2. POV contradiction silently deleted teen/adult voice (HIGH)
The skeleton hard-mandated "POV (MANDATORY): Third-person throughout… name at least once
per paragraph" for ALL ages, while the band notes three lines later said 13-15 "OR close
first-person", 15-18 "First-person encouraged", adult "Any". Under contradiction, models
follow the MANDATORY rule — the literary-voice upgrade in the band notes never fired.
The per-paragraph name echo is itself an LLM tell at adult register.

**Fix:** POV is now band-conditional. ≤12 keeps the old mandatory text verbatim; 13-14
gets "third limited or close first, choose once and hold"; 15+ gets POV as craft choice.
"Never address the reader as you" retained for all bands (interactive mode's deliberate
2nd-person is a separate builder and untouched).

### 3. Sprout constraint arithmetic didn't fit the page budget (MEDIUM)
A Sprout page is 10-25 words, yet per page the delight rules demanded: 2 ALL-CAPS sound
words + companion speaks in dialogue + page-ending hook + inline explanation of any
non-toddler noun. That consumes the entire budget, so the model dropped rules at
random — the draw-to-draw inconsistency seen in QA.

**Fix:** per-page quotas converted to story-level rates (sound words "on MOST pages,
6-10 across the story"; companion speaks "at least FOUR times across the story") plus an
explicit BUDGET NOTE telling the model the story beat wins conflicts. Page-ending hooks
and the vocabulary check are unchanged (hooks are word-cheap and are the page-turn
engine).

### 4. Self-contradiction: "wonderful" (LOW)
The Sprout forbidden-word list instructed replacing wondrous→**wonderful** while
`craft_rules` bans "wonderful" outright. Pair removed.

### 5. One-size-fits-all persona fought the POV rule (MEDIUM)
"Master Storyteller & World-Builder… readers forget they're reading — they *are* the
hero" (a) contradicted "The reader witnesses {character}'s story, not their own", and
(b) pitched the same immersive-world-builder register at a 3-year-old's bedtime picture
book and an adult literary piece.

**Fix:** new `_get_band_persona(age)` — six band-tuned personas (picture-book author →
early-chapter-book → flashlight middle-grade → YA-who-respects-the-reader → literary YA
→ literary short fiction). Persona is the cheapest register lever a prompt has.

## Not changed (deliberate)

- Superhero, bedtime, rhyme-time, learning-to-read builders — separate prompts, out of
  scope for this pass.
- Interactive (Pick-a-Path) builder — its 2nd-person POV under 15 is a deliberate CYOA
  decision.
- The dead `EMOTIONAL HEART` block in `prompt_service.py` — left in place since the
  superhero path routes around it; removing is a cleanup for a dead-code sweep, not this
  PR.

## Verification

- 66/66 prompt-related tests pass (`test_cinematic_features`, `test_prompt_versioning`,
  `test_prompt_service`, `test_story_age_appropriateness_suite`).
- Smoke render at ages 4/10/16: spine present, band persona correct, POV conditional
  correct, Sprout budget note present, no old-persona leakage.
- A/B against prod model `gpt-5-mini` via OpenRouter: see
  `backend/tests/quality/results/` (gitignored) and the PR description for the judged
  comparison.

## Follow-ups (not blocking)

- Prompt-template revision hash `T1_STANDARD` changes automatically with this diff
  (`prompt_versioning.py` hashes builder source) — story rows will record the new
  revision; no action needed.
- Consider porting the spine to the superhero builders in a later pass — they have their
  own arc rules and were not audited here.
