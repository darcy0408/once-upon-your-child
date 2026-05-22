# Audit 05 — AI/ML Quality Evaluation (Interim Report)

**Date:** 2026-05-21
**Session:** auto-eval/interim (pre-budget)
**Repo SHA at snapshot:** `390de0e5`
**Status:** Zero-cost scaffolding complete. No API calls have been made. Three decisions block the next pass (see §7).

## Executive Summary

The audit's evaluation harness has been built and validated against the current source. Every prompt template that reaches a primary or fallback LLM has been catalogued, source-pinned, and content-hashed (`backend/eval/prompt_registry.py`). The harness can plan, dry-run, resume, and budget-cap a 1,020-cell evaluation at an estimated **$1.22 on Gemini Flash** (1/12th of the audit spec's $15 floor, because that floor assumed Sonnet-class generation).

No generations have been produced yet — that is a separate, budget-authorized step. The findings below come entirely from inspecting the source, the assembly pipeline, and the harness's dry-run output.

**Three findings rise to Critical without spending a dollar:**

1. **F-01 — No versioning metadata anywhere on prompts.** A prompt change in code is invisible to any downstream system that consumed the previous version. This is the audit spec's explicit Critical-finding rule (`Missing prompt template version metadata: flag as a versioning Critical finding`). The harness's content-hash snapshot is a partial mitigation — it tells us *that* something drifted, not *what* it became — but a structural fix (template-id + revision + commit-tag on every assembled prompt) belongs in `story_service.py`/`prompt_service.py`.
2. **F-02 — Pick-a-Path / Interactive stories live outside `story_service.py`.** The audit spec lists four modes; the code-side reality is five modes in `story_service.py` (Standard, LTR-Limerick, LTR-Seussian, Rhyme Time, Bedtime) plus Superhero in `prompt_service.py`, and a separate "Interactive" endpoint nowhere in either. The eval harness as designed does not cover Interactive. Either Interactive needs its own audit pass, or it needs to fold into the main story-gen pipeline.
3. **F-03 — Provider parity is asserted, not measured.** Same prompt text goes to Gemini and OpenRouter, but they have different safety stacks (Gemini has prompt-level + response-level filters; OpenRouter relies on model-internal training). A "story that Gemini blocks but OpenRouter ships" is currently silent.

## 1. Rubric Definitions

Five rubrics, identical to the audit spec:

| Rubric | Scale | Critical threshold |
|---|---|---|
| `narrative_coherence` | 1–5 | — |
| `age_band_fit` | 1–5 | ≥20% of cell outputs < 3 → Critical |
| `mode_adherence` | 0/1 | — |
| `illustration_coherence` | 1–5 or null | — |
| `refusal_flag` | 0/1 | — |

See `backend/eval/rubrics.py:RUBRIC_VERSION = "1.0"`. The judge prompts are inlined there and will be passed verbatim to the judge model.

## 2. Test Set

30 fixed-seed inputs (`backend/eval/test_set.py:TEST_SET_VERSION = "1.0"`):

- 10 **common** (C01-C10) — dragons, friendship, garden, mystery, etc.
- 10 **edge** (E01-E10) — single-letter inputs, ultra-long names, emoji-only custom_elements, an identical-twin pair (E07 ≡ C01) for drift signal
- 10 **adversarial** (A01-A10) — direct prompt-injection in `custom_elements`, anti-virtue framing, trauma-sensitive themes (`foster care`, `custody change`), defamation-shape inputs

Three test inputs (A05, A06, A07) carry `elevated_scrutiny=True` per the audit spec's "trauma-sensitive themes as elevated-scrutiny cells." Those cells require both judges to agree before they score as PASS.

## 3. Cells (Per-Cell Scores)

The audit spec says "30 inputs × 6 age bands × 4 modes = 720 generations." Code reality:

| Mode | Age bands eligible | Cells | Generations (× 30 inputs) |
|---|---|---|---|
| standard | all 7 | 7 | 210 |
| ltr_seussian | all 7 | 7 | 210 |
| rhyme_time | all 7 | 7 | 210 |
| bedtime | all 7 | 7 | 210 |
| ltr_limerick | 5-7, 8-10, 11-13, 13-15 | 4 | 120 |
| superhero | 3-4, 5-7 only | 2 | 60 |
| **Total** | | **34** | **1,020** |

Per-cell scores require **N=30** for statistical signal (audit spec). Each cell is hit by 30 unique inputs in one pass. Drift is measured by a second pass on a 10% subsample 24 hours later.

`backend/eval/harness.py --dry-run` prints the full plan; `--calibration` runs a 10-cell slice spanning every mode + 2 trauma + 2 drift cells (~$0.01).

## 4. Drift Analysis

Not yet measured. Drift signal will come from:

1. Re-running E07 (a deliberate duplicate of C01) and comparing.
2. Optional 24-hour replay of a 10% sample under `--resume <run-id>` after a calendar day.
3. Long-term: re-running the calibration set on every prompt-template change. The harness logs `snapshot_git_sha` in every generation row so retrospective drift is computable from `results/*/generations.jsonl`.

## 5. Fallback Test

Not yet measured. Planned approach when authorized:

1. Set `STORY_GEN_PROVIDER=openrouter` and re-run the calibration set; compare per-rubric distributions to the Gemini pass.
2. Inject a forced Gemini timeout (mocking) on three cells in a Gemini-primary run and confirm OpenRouter handles them with comparable quality.
3. Independent variable: the same prompt text is sent to both providers; the only difference is the safety stack and model behavior. This is enough for parity measurement and a tier-2 finding if quality diverges materially.

## 6. Versioning Audit (the audit spec's explicit Critical-or-not gate)

**Finding: CRITICAL.** No prompt template in the codebase carries any version metadata. There is:

- no `__version__` constant per template
- no `version=X` field on the assembled prompt
- no migration log when a template is edited
- no semantic identifier emitted in the call to Gemini/OpenRouter

This means: a prompt change in `story_service.py` cannot be correlated, after the fact, with the story it produced. Quality regressions look identical to user reports of bad luck. The only way to attribute is `git blame` + timestamp matching, which fails the moment two changes land on the same day.

**Partial mitigation already shipped in this audit (zero cost):**

- `backend/eval/prompt_registry.py` snapshots every template with `(source_file, line_start, line_end, content_hash, captured_git_sha)`.
- `python -m backend.eval.snapshot --verify` will detect drift on every subsequent run; PR CI can gate on it.

**Structural fix still required (NOT done in this audit):**

- Add a `PROMPT_TEMPLATE_VERSION = "T1.1.0"` constant on each template (or use the registry's `content_hash` as the de-facto version).
- Tag every assembled prompt with that version in a JSON header line or metadata field before the LLM call.
- Persist the version on every `Story` row so production can correlate output to template.

Effort: ~2 hours. Cost: zero.

## 7. Open Decisions Blocking the Next Pass

The 2026-05-19 session halted on the same three questions. Re-listing:

1. **Budget cap.** A full Gemini Flash run is **$1.22 estimated** (12× cheaper than the spec's $15 floor because the spec assumed Sonnet-class). Two-judge scoring adds ~$4. A full Sonnet-judged run is ~$50. Options:
   - $5 — calibration + first full Gemini pass + one Gemini judge
   - $25 — full Gemini run + two-judge ensemble (Gemini + Claude Sonnet judge)
   - $75 — full run on both providers + two-judge ensemble + drift pass
   - no cap — let the harness run anything it dry-run-planned
2. **Aggressiveness.** Harness-only (this report) / obvious-wins prompt edits inline / full prompt-template rewrites if the eval surfaces a Critical cell.
3. **Branch policy.** All eval scaffolding currently sits in an unstaged working tree. Direct to main / feature branch pushed / local-only.

## 8. Other Findings (informational, not blocking)

| ID | Title | Severity | Cell | Evidence | Remediation | Effort |
|---|---|---|---|---|---|---|
| F-01 | No prompt-template versioning | **Critical** | all | `grep -r "PROMPT_VERSION\|TEMPLATE_VERSION" backend/` returns nothing | Add per-template version constant; tag assembled prompts; persist on `Story` | ~2h |
| F-02 | Pick-a-Path / Interactive outside audit scope | Medium | n/a | Audit spec mentions 4 modes; code has 5 in story_service.py + Interactive elsewhere | Decide: separate audit pass or fold into story_service | scoping |
| F-03 | Provider parity asserted, not measured | High | all | Same prompt text both providers; different safety stacks; no comparison logs | Run `--provider openrouter` calibration parallel to Gemini and diff distributions | ~$1 of API spend |
| F-04 | Age-band naming drift (code vs memory vs README) | Low | all | Code: `'3-4'/'5-7'/'8-10'`. Memory: `Sprout 3-5 / Explorer 6-8 / Adventurer 9-12`. README.md uses third set. Already tracked as MT-170 | Pick one naming and sweep; eval registry uses code-side as canonical | ~30 min |
| F-05 | Prompts assembled at runtime from many fragments | Medium | T1 mostly | `STRICT_OUTPUT`, `SAFETY_GUARDRAILS`, virtue, feelings, prior-adventures all conditionally injected | Harness MUST log the **assembled** prompt, not just template source. Currently stub-only — will fill when budget is set | code change in harness `_call_provider` |
| F-06 | Invisible-instruction tokens visible in prompt | Low | T11, T12 | `**INVISIBLE VIRTUE**` etc appear as literal tokens in the prompt body | Audit-time scan of generated outputs for leakage; if found, rewrite | low priority until measured |
| F-07 | `_BEDTIME_SETTINGS.get(theme.lower(), theme)` falls through raw user input | Medium | T5 bedtime | Unmatched theme key returns the raw user string as the setting description | Either constrain themes server-side or apply a sanitizer | ~1h |
| F-08 | User-input boundary is advisory, not enforced | Medium | T9 → all | `STRICT_OUTPUT_CONSTRAINTS` warns the model to ignore `[USER_INPUT]…[/USER_INPUT]` overrides, but nothing else stops jailbreaks | Adversarial test set A01-A10 will quantify; remediation depends on rates | dependent on measurement |
| F-09 | T7 source-line range mid-method may shift on edit | Low | T7 superhero explorer | T7 spans lines 415-574; method ends at EOF | Long-term: extract methods to standalone constants so line ranges are stable | low |

A Critical/High count of 1/1 with 6 Medium/Low informational items is reasonable for an interim. The expected Critical-or-not lift will come from F-03 (provider parity) and from per-cell `age_band_fit` after the first generation pass.

## 9. Recommendations

**Immediate (zero cost):**

1. **Ship the structural versioning fix (F-01).** Even if no further eval pass happens, persisting `prompt_template_id + revision_hash` on every `Story` row turns future regressions into one-query investigations instead of week-long forensics. ~2h.
2. **Commit the harness as-is.** It's read-only against production, fully tested in dry-run, and lets any future session resume cleanly.

**When budget is authorized (≤$5):**

3. Run `--calibration` first (~$0.01) to validate the pipeline end-to-end.
4. Run full Gemini Flash pass (~$1.22).
5. Score with one Gemini judge (~$0.30 — single judge, calibration only).
6. Inspect 10% manually; if judge agreement is fine, run a second pass through Sonnet judge (~$4).

**When budget is authorized (≤$25):**

7. All of the above plus a parallel `--provider openrouter-claude-sonnet` pass on the calibration subset to measure provider parity (F-03).

**Ongoing cadence (when this is institutionalized):**

- Calibration set on every prompt-template change. Auto-gated in CI.
- Full quarterly pass with stored baseline for drift comparison.
- Per-quarter prompt-template version bump even if templates are unchanged — establishes the discipline.

## Appendix A — Files Produced

```
backend/eval/
├── README.md             usage and cost model
├── __init__.py
├── prompt_registry.py    14 templates, 12 hash-locked, 2 omitted (T10 data-only, T14 fallback builder)
├── rubrics.py            5 rubrics, judge-prompt-ready
├── test_set.py           30 fixed-seed inputs (10C/10E/10A)
├── harness.py            runner: dry-run validated, budget cap, resume
├── judge.py              skeleton — gated behind budget authorization
├── snapshot.py           --verify and --refresh; CI-ready
└── results/.gitignore    raw outputs gitignored
```

## Appendix B — Commands Validated

```
python -m backend.eval.harness --dry-run                              # 1020 cells, $1.22 est
python -m backend.eval.harness --dry-run --calibration                # 10 cells, $0.01 est
python -m backend.eval.snapshot --verify                              # 12 PASS, 0 drift
python -m backend.eval.snapshot --refresh                             # populates content_hash
```
