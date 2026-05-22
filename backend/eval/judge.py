"""LLM-judge ensemble for rubric scoring.

Per audit-05 spec:
- Two judge models, inter-judge agreement reported.
- >=10% of judge scores manually reviewed; >=80% agreement required before
  final scoring is locked.

This file is a SCAFFOLD. The actual judge calls are gated behind budget
authorization and not implemented here.

Usage (once authorized):
    python -m backend.eval.judge --run-id <id> --judges gemini,openrouter
"""

from __future__ import annotations

import argparse
import json
import sys
from pathlib import Path

from . import rubrics, test_set
from .harness import RESULTS_ROOT

JUDGE_SYSTEM_PROMPT_TEMPLATE = """You are an evaluation judge for an AI-generated
children's story. You will score one story against multiple rubrics.

Output a single JSON object with one key per rubric and an integer score (or 0/1
for binary rubrics, or null for not-applicable). Do not include prose
commentary. Do not refuse to score.

The story's metadata:
- mode: {mode}
- target age band: {age_band}
- test input bucket: {bucket} (common / edge / adversarial)

Rubrics:

{rubric_block}

Score the following story:

---
{story_text}
---

Return ONLY the JSON object."""


def build_judge_prompt(generation_row: dict, story_text: str, t: test_set.TestInput) -> str:
    rubric_block = "\n\n".join(
        f"### {r.name} ({r.scale})\n{r.judge_prompt.format(age_band=generation_row['age_band'], mode=generation_row['mode'])}"
        for r in rubrics.ALL_RUBRICS
    )
    return JUDGE_SYSTEM_PROMPT_TEMPLATE.format(
        mode=generation_row["mode"],
        age_band=generation_row["age_band"],
        bucket=t.bucket,
        rubric_block=rubric_block,
        story_text=story_text,
    )


def _call_judge(judge_name: str, prompt: str) -> dict:
    """Stub. Replace with provider call once authorized."""
    raise NotImplementedError(
        "Judge calls gated behind budget authorization. "
        "Implement against the same provider clients the harness uses."
    )


def _inter_judge_agreement(scores_a: dict, scores_b: dict) -> float:
    """Cohen-ish agreement on rubric scores, treating 1-5 within +/-1 as agreement
    and binary as exact match. Returns a fraction 0.0-1.0.
    """
    keys = [r.name for r in rubrics.ALL_RUBRICS if r.name in scores_a and r.name in scores_b]
    if not keys:
        return 0.0
    agreed = 0
    for k in keys:
        a, b = scores_a[k], scores_b[k]
        if a is None or b is None:
            continue
        if isinstance(a, bool) or isinstance(b, bool) or k in ("mode_adherence", "refusal_flag"):
            if a == b:
                agreed += 1
        else:
            if abs(int(a) - int(b)) <= 1:
                agreed += 1
    return agreed / max(1, len(keys))


def score_run(run_id: str, judges: list[str]) -> int:
    run_dir = RESULTS_ROOT / run_id
    gen_jsonl = run_dir / "generations.jsonl"
    if not gen_jsonl.exists():
        print(f"[judge] no generations file at {gen_jsonl}", file=sys.stderr)
        return 1
    scores_path = run_dir / "scores.jsonl"
    agreement_path = run_dir / "agreement.jsonl"
    print(f"[judge] scoring {gen_jsonl} with judges={judges}")

    with gen_jsonl.open("r", encoding="utf-8") as f:
        for line in f:
            line = line.strip()
            if not line:
                continue
            try:
                row = json.loads(line)
            except json.JSONDecodeError:
                continue
            if row.get("status") != "complete":
                continue
            # The harness stores output_hash, not raw text — for scoring we need
            # raw text. Once the harness is implemented, also persist a per-cell
            # generations/<cell>.txt under the run dir (gitignored) and read it here.
            story_path = run_dir / "stories" / (row["cell_id"].replace("|", "_") + ".txt")
            if not story_path.exists():
                print(f"[judge] skipping {row['cell_id']} — story text missing", file=sys.stderr)
                continue
            story_text = story_path.read_text(encoding="utf-8")
            t = test_set.by_id(row["test_id"])
            prompt = build_judge_prompt(row, story_text, t)
            try:
                per_judge = {j: _call_judge(j, prompt) for j in judges}
            except NotImplementedError as exc:
                print(f"[judge] {exc}", file=sys.stderr)
                return 2
            # Persist per-judge scores
            with scores_path.open("a", encoding="utf-8") as sf:
                sf.write(json.dumps({"cell_id": row["cell_id"], "scores": per_judge}) + "\n")
            if len(judges) >= 2:
                a, b = list(per_judge.values())[:2]
                agreement = _inter_judge_agreement(a, b)
                with agreement_path.open("a", encoding="utf-8") as af:
                    af.write(json.dumps({"cell_id": row["cell_id"],
                                         "agreement": agreement}) + "\n")
    return 0


def main(argv: list[str] | None = None) -> int:
    p = argparse.ArgumentParser()
    p.add_argument("--run-id", required=True)
    p.add_argument("--judges", default="gemini,openrouter-claude-sonnet",
                   help="Comma-separated judge identifiers.")
    args = p.parse_args(argv if argv is not None else sys.argv[1:])
    return score_run(args.run_id, [j.strip() for j in args.judges.split(",") if j.strip()])


if __name__ == "__main__":
    raise SystemExit(main())
