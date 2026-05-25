# Audit 05 — `superhero | 3-4` fix validated

**Date:** 2026-05-24
**Patch SHA:** see commit `0fbc4dfd` + Bug-3/name follow-up
**Baseline run:** `results/20260522-153126-a76436` (audit 05 main)
**Re-test runs:** `20260524-212553-9751e1` (Bugs 1+2 only), `20260524-213705-cc568f` (all three fixes)

## Result

The Critical cell is no longer Critical. **`age_band_fit` failure rate went from 63.3% → 0.0%** on the same 30 fixed-seed test inputs, judged by the same Gemini judge with the same rubric, against the same model (Gemini Flash-Lite, free tier).

| Metric | Baseline | + Bugs 1+2 | + all 3 fixes |
|---|---|---|---|
| narrative_coherence (1-5 mean) | 3.03 | 2.90 | **4.33** |
| age_band_fit (1-5 mean) | 2.30 | 2.40 | **4.60** |
| age_fail_pct (Critical threshold ≥20%) | **63.3%** | 70.0% | **0.0%** |
| mode_adherence | 100% | 100% | 100% |
| **Critical status** | Critical | Critical | **PASS** |

The cell now scores better than its sibling `superhero | 5-7` did at baseline (age 3.93, narrative 3.90) — the Sprout band has caught up to and slightly exceeded the Explorer band on rubric scoring.

## What we learned

**Bugs 1+2 alone did not move the score.** I had predicted 63% → <10% in the RCA writeup; reality was 63% → 70% (statistically equivalent at N=30). The grammar and metadata-leak issues were real bugs in the prose, but they were not what the judge was primarily penalising. I was overconfident.

**Bug 3 (single-page format) was the load-bearing fix.** Combined with the name-repetition tweak, it dropped failure to zero. The lesson: the judge was reading the structural format as the dominant age-fit signal, not sentence-level grammar.

This is a useful audit-method finding too — when an LLM judge marks a cell "wrong for this band", the cause is more likely format / pacing / density of repetition than vocabulary or grammar. Future RCAs should weight structural issues higher.

## The three fixes (final)

### Bug 1 — beat 2 grammar (`prompt_service.py` near line 336)

```diff
- beat2 = f"Oh no! {villain['name']} came to {villain['action']}."
+ beat2 = (
+     f"Oh no! {villain['name']} is here. "
+     f"{villain['name']} {villain['action']}."
+ )
```

### Bug 2 — beat 4 metadata leak (removed `beat4` Python variable; rewrote the prompt's "4. POWER USED" instruction)

```diff
- 4. POWER USED  — Show {character} using {power_name} to {problem['verb']} the situation. Reference beat 4 idea: "{beat4}" (rewrite naturally; do NOT use the bracketed summary in the prose).
+ 4. POWER USED  — Show {character} using {power_name} in a kind way so that {villain['name']} wants to {problem['verb']}. For example, if the power is a friendly smile, {character} might smile so brightly that {villain['name']} smiles back. Write this beat in your own words — do NOT copy this example sentence.
```

### Bug 3 — output format and name density (this batch)

OUTPUT FORMAT changed from a single-page schema to a multi-page schema (8-12 pages, 5-25 words each). Hard rule added: `Pages: Return between 8 and 12 pages. Each page MUST be 5-25 words.`

Name-repetition rule loosened:

```diff
- Use the hero's name AT LEAST TWICE and the identity tag "{identity_tag}" AT LEAST TWICE.
+ Use the hero's name ONCE or TWICE in your own narration, then refer to them by pronoun (he/she/they) — the beat templates already include the name, so do NOT pile on extra mentions. Use the identity tag "{identity_tag}" ONCE.
```

## Sample output (post-fix, 10 pages, name = "Aurelius-Maximilian" edge case)

```
1. Aurelius-Maximilian put on the bright suit. Today, Aurelius-Maximilian is Super Smile Aurelius-Maximilian!
2. He had a bright cape. It had a star emblem.
3. Oh no! Cranky Crab is here.
4. Cranky Crab snapped at everyone on the beach. Snap! Snap!
5. The beach was not happy.
6. Aurelius-Maximilian said, 'I can help!'
7. He used his Super Smile power. It was a big, bright smile.
8. He smiled at Cranky Crab. His smile was super bright.
9. Cranky Crab smiled — really, the crab was just lonely — and joined the fun.
10. Everyone cheered. Aurelius-Maximilian saved the day!
```

Page 9's reframe ("really, the crab was just lonely") is the kind of empathic beat the Superhero Mode contract is reaching for and rarely hit before. Pronouns now carry most of the narration; the name density is appropriate.

## Cost of this validation

- Re-generate 30 cells: $0.01 total (Gemini Flash-Lite free tier)
- Re-judge 30 cells: $0 (Gemini judge free tier)
- Wall time: ~5 minutes end-to-end

The harness `--filter "superhero|3-4"` flag added during this session makes any future per-cell re-validation a one-liner.

## What this leaves on the table

- **5 Critical cells remain** from the main audit: `ltr_seussian | 15-18`, `13-15`, `adult`, `3-4`, and `rhyme_time | 3-4`. The same approach (RCA → prompt fix → `--filter` re-test) applies. None are likely to share root causes with Superhero Sprout — ltr_seussian's failure pattern is age-band-rigid prose calibration, not template grammar.
- **Inter-judge agreement still at 77.1%** (below 80% calibration bar). Resuming the GitHub Models judge today would lift the GH coverage past 28 and give a confident agreement number.
- **F-01 versioning** is still the right next structural fix. This cell-level validation worked beautifully via the content-hash snapshot mechanism (`snapshot --refresh` after the edit captured the new hash `adcb430286569025`). Persisting that hash on every `Story` row in production would let any future regression be attributed instantly.

## Recommendation

Ship the Superhero Sprout patch as-is. Pick the next Critical cell (likely `ltr_seussian | 15-18` since it's the worst) and repeat the cycle.
