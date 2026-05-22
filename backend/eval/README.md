# Story Weaver Evaluation Harness (Audit 05)

Empirical quality measurement for the story-generation pipeline. Built per the audit spec at `docs/audit-05/prompt.md` (the prompt that produced this harness lives in conversation 3de3 / next-session pickup).

## Why this exists

Subjective "the app works" → measurable evidence we can put in front of grant reviewers, investors, and the team. Specifically:

- Per-age-band × per-mode quality scoring with confidence intervals
- Drift detection on identical prompts (24-hour same-input variance)
- Provider parity (Gemini primary vs OpenRouter fallback)
- Prompt-template versioning baseline (changes-over-time traceable)

## Status

**INTERIM** — harness scaffolded, prompt registry populated, no API calls have been made. The first interim findings report at `audit-reports/05-ai-quality-20260521-interim.md` is generated entirely from source inspection (zero cost).

A budget cap, aggressiveness setting, and branch policy must be decided before any run that calls Gemini/OpenRouter (see "Cost model" below).

## Layout

```
backend/eval/
├── README.md             this file
├── __init__.py
├── prompt_registry.py    every template, source pointer, content hash
├── rubrics.py            5 rubrics + scoring schema per audit spec
├── test_set.py           30 fixed-seed prompts (common/edge/adversarial)
├── harness.py            runner: budget cap, resume, calibration mode
├── judge.py              LLM-judge ensemble skeleton
├── snapshot.py           re-hashes templates against current source; drift detector
└── results/              gitignored — JSONL output, judge logs, failures
```

## How a run works (when authorized)

```
# 1) Validate the prompt registry hashes match current source
python -m backend.eval.snapshot --verify

# 2) Dry-run: print every (template, age_band, mode, test_input) cell and exit
python -m backend.eval.harness --dry-run

# 3) Calibration slice — ~$0.50 across 10 cells, validates the pipeline
python -m backend.eval.harness --budget 5 --calibration

# 4) Full run within a hard cap
python -m backend.eval.harness --budget 25 --provider gemini

# 5) Score with two judges (only after generations exist)
python -m backend.eval.judge --run-id <run-id> --judges gemini,openrouter
```

The harness writes **one JSONL line per cell** to `results/<run-id>/generations.jsonl` and resumes from the last complete line on re-run. Crashes do not waste budget.

## Cost model

Per-generation rough cost (2k input tokens, 3k output):

| Provider | Model | $/run @ 1080 cells |
|---|---|---|
| Gemini Flash | `gemini-2.5-flash` | ~$1.20 |
| Gemini Flash Lite | `gemini-2.5-flash-lite` (free-tier model) | ~$0.30 |
| OpenRouter / Claude Sonnet 4.7 | `anthropic/claude-sonnet-4.7` | ~$48 |
| OpenRouter / Llama 3.3 70B | `meta-llama/llama-3.3-70b-instruct` (free-tier model) | ~$1.80 |

The audit spec's $15–$40 estimate assumed Sonnet-class judging on top of generation; expect generation alone to land near the lower end when using Gemini Flash.

Judging adds another pass: 1080 cells × ~$0.002 per judge × 2 judges = ~$4.30.

The `--budget` flag is enforced as a hard ceiling. The harness tracks cumulative cost from API responses (where available) or from a fallback per-token estimate, and halts with a partial-coverage report if it would exceed the cap.

## Cells

Code reality (not the audit spec's stylized 6 × 4):

- 7 age-band keys: `3-4`, `5-7`, `8-10`, `11-13`, `13-15`, `15-18`, `adult`
- 6 modes: `standard`, `ltr_limerick`, `ltr_seussian`, `rhyme_time`, `bedtime`, `superhero`
- Superhero is only valid on `3-4` and `5-7`
- **Total valid cells:** 36 (see `prompt_registry.VALID_CELLS`)

At 30 samples/cell that's 1080 generations per run.

## Safety

- No real child PII enters the test set. Names are generic (`Pip`, `Lyra`, `Rin`).
- Generated content is hashed before storage; raw text is kept only in `results/<run-id>/` which is gitignored.
- Trauma-sensitive themes (`foster`, `custody`, `loss`) get an elevated-scrutiny tag; their cells are scored by both judges with no auto-promotion to "PASS".
- Cost cap is enforced before any API call; the harness will partial-report rather than overrun.

## Open decisions before next run

1. **Budget cap.** $5 (calibration only) / $25 (partial coverage) / $75 (full × Gemini + 2-judge) / no cap.
2. **Aggressiveness.** Harness + plan only / obvious-wins prompt edits / full prompt-template rewrites.
3. **Branch policy.** Feature branch pushed / local / direct to main.

These were the three questions the 2026-05-19 attempt halted on. Until they're answered, the harness stays at "validated scaffold, no API calls."
