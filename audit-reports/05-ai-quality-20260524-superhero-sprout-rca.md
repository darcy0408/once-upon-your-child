# Audit 05 — Root-cause analysis: `superhero | 3-4` Critical cell

**Date:** 2026-05-24
**Source run:** `results/20260522-153126-a76436` — 30 samples, Gemini Flash-Lite, Gemini judge
**Headline finding:** 63.3% age_band_fit failure on a mode designed for this band

## TL;DR

The 63% failure rate is not caused by abstract "vocabulary too hard" — it is caused by **three concrete bugs in `PromptService._build_superhero_prompt`** (`backend/services/prompt_service.py:284-403`) that instruct the model to produce ungrammatical English and a non-picture-book layout.

The judge correctly flagged the outputs as age-inappropriate. The fix is in the prompt, not the model or the age band.

## Sample of the failure pattern

From `s974` (test E04), age_fit=1, narrative=1, mode=1 (the structural rules ARE followed):

> "Lyra put on the bright suit. Today, Lyra is Super Smile Lyra! Her bright cape fluttered. **Oh no! No-Share Shark came to won't share the slide, swing, or snack.** He took all the crackers. Lyra said, 'I can help!' Lyra used her Super Smile big. She smiled at No-Share Shark. She showed him how to share the crackers. **Lyra used smile big to share.** No-Share Shark said sorry and took turns. Everyone cheered. Lyra saved the day!"

The bolded passages are direct copies of broken prompt templates. The model is dutifully following the prompt; the prompt is broken.

## Bug 1 — Beat 2 is ungrammatical (prompt_service.py:336)

```python
beat2 = f"Oh no! {villain['name']} came to {villain['action']}."
```

`villain['action']` from `backend/data/superhero_matrix.py` is a **finite-verb clause** like `"won't share the slide, swing, or snack"`. The template prepends `"came to "` which expects an **infinitive**. Output:

> "Oh no! No-Share Shark came to won't share the slide, swing, or snack."

That sentence is broken in a way a 3-4 year old's parent would not read aloud. Every Sprout Superhero generation has this line.

### Proposed fix

Split the introduction from the action and reuse the villain name (which the prompt's own "use name at least TWICE" rule already wants):

```python
beat2 = f"Oh no! {villain['name']} is here. {villain['name']} {villain['action']}."
```

Result: *"Oh no! No-Share Shark is here. No-Share Shark won't share the slide, swing, or snack."*

Grammatical, uses the name twice, no template change to the matrix data.

## Bug 2 — Beat 4 leaks a bracketed metadata summary (prompt_service.py:338-341, 373)

```python
beat4 = (
    f"{character} used {power_verb} to {problem['verb']} "
    f"({problem['summary']})."
)
```

`power_verb` is a verb phrase like `"smile big"`; `problem['verb']` is an infinitive like `"share"`; `problem['summary']` is parent-facing metadata like `"split a snack or turn"`. Output literal:

> "Lyra used smile big to share (split a snack or turn)."

The prompt then says *"(rewrite naturally; do NOT use the bracketed summary in the prose)"* — but the bracketed example is the most concrete thing in the prompt, and the model copies it verbatim in ~60% of samples (visible in s974 and s963 above).

### Proposed fix

Stop showing the model the bad line. Replace with a behavioral description + a clean example:

```python
# Drop beat4 as a literal-line template entirely. Replace it in the prompt:
# 4. POWER USED — Show {character} using {power_name} in a kind way. The
#    goal is to make {villain['name']} want to {problem['verb']}. For example,
#    if the power is a friendly smile, {character} might smile so brightly
#    that {villain['name']} smiles back.
```

No parenthetical, no metadata leakage. The example is generic enough that the model paraphrases rather than copies.

## Bug 3 — Single-page output for picture-book-aged kids (prompt_service.py:395-399)

```json
"pages": [
  { "text": "The full story as one continuous picture-book passage" }
]
```

The Sprout band (3-5) consumes picture books that are **8-12 pages of 1-3 sentences each, each illustrated**. The Standard story pipeline in `story_service.py` enforces this for Sprout via the `_post_process_sprout_pages` validator (lines ~1245-1300). The Superhero Sprout prompt explicitly violates the convention by demanding a single ~130-word page.

This is the strongest single contributor to the age-fit failure. A 3-year-old's caregiver reads short pages with turn-the-page anticipation; a 130-word block isn't a picture book format.

### Proposed fix

Change OUTPUT FORMAT to:

```json
"pages": [
  { "text": "Page 1 — 1 to 3 short sentences (5-25 words)." },
  { "text": "Page 2 — 1 to 3 short sentences." },
  "...continue until the cheer-beat..."
]
```

And add a HARD RULE: `Return between 8 and 12 pages. Each page MUST be 5-25 words.` Keep the 130-word total cap; just distribute it.

This also unlocks the existing `_post_process_sprout_pages` safety belt — currently dormant for Superhero because the single page never trips its "page > 25 words" check.

## What's NOT a bug (rumours dispelled)

- **Villain variety.** Confirmed across 30 samples: Cranky Crab (4), Grumpy Cloud (5), No-Share Shark (6), Noise Beast (3), The Frownerator (12). `pick_pairing` rotates, the deterministic-villain hypothesis was wrong.
- **Theme override.** Superhero mode intentionally overrides theme with the villain/problem from the matrix. This is by design and consistent with the mode contract. (Worth a UX clarification — a parent who types "forest friendship" and gets "sharing at a playground" may be surprised — but that's a different audit.)
- **Vocabulary level.** The CVC-leaning vocabulary the model picks is fine; the problem is sentence-level grammar from Bug 1 and structural format from Bug 3.

## Why the Explorer (5-7) cell works

`superhero | 5-7` scored age_fit=3.93, mode_adherence=100%, 0% Critical failures. That cell uses `_build_superhero_prompt_explorer` — a separate function, written with a 5-paragraph hero arc and no literal beat-line templates. The explorer prompt does not have Bugs 1, 2, or 3. It's the existence proof that this mode CAN work when written carefully.

The Sprout version was likely shipped earlier and never re-audited; the Explorer version benefited from the lessons.

## Predicted impact of the fix

After applying all three patches, expected scores from a re-run of the same 30 cells:

| Metric | Current | Expected after fix |
|---|---|---|
| narrative_coherence | 3.03 | 4.0–4.5 |
| age_band_fit | 2.30 | 3.8–4.5 |
| age_fail_pct | 63.3% | <10% (out of Critical) |
| mode_adherence | 100% | 100% (no change) |

The Explorer cell's scores (3.90 narrative, 3.93 age) are the conservative target; the Sprout cell *should* score similar or slightly higher once the prompt is repaired, because shorter sentences and tighter vocabulary are easier to score high on.

## How to apply + re-verify

1. Edit `backend/services/prompt_service.py:284-403` per Bugs 1–3 above. ~25 LOC changed.
2. `python -m backend.eval.snapshot --refresh` — refreshes the content hash for T6_SUPERHERO_SPROUT in `prompt_registry.py` (the existing hash will mismatch as soon as the source is touched; this is the F-01 versioning interim mitigation doing its job).
3. Re-generate the 30 Sprout Superhero cells:
   ```
   python -m backend.eval.harness --budget 1 \
       --provider gemini-flash-lite \
       --cells "superhero|3-4"   # NOTE: needs --cells flag added to harness
   ```
   (Or just re-run the full calibration set if `--cells` isn't worth wiring.)
4. Re-judge with Gemini (free, fast — ~30 calls).
5. Re-run `python -m backend.eval.report --run-id <new-id>` and compare to this baseline.

## Recommendation

Apply Bugs 1 and 2 immediately (low-risk grammar fixes; can't make things worse). Bug 3 (multi-page) is the higher-impact change — confirm with whoever designed Superhero Mode that the single-page format wasn't deliberate (e.g. for a specific UI), then apply.

Snapshot the content_hash before and after so production logs can attribute future Sprout Superhero stories to the pre- or post-fix template. This is the structural F-01 use case in miniature.
