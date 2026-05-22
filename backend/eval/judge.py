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
import re
import sys
from pathlib import Path

from . import providers, rubrics, test_set
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


JUDGE_SYSTEM = (
    "You are a strict evaluation judge. You output ONLY a single JSON object "
    "of rubric scores. No prose, no code fences, no refusals."
)

# Cache one client per judge identifier so we don't re-auth per call.
_JUDGE_CLIENTS: dict[str, object] = {}


def _extract_json(text: str) -> dict:
    """Pull the first JSON object out of a model response."""
    text = text.strip()
    # Strip ```json fences if present.
    fence = re.match(r"^```(?:json)?\s*(.*?)\s*```$", text, re.DOTALL)
    if fence:
        text = fence.group(1).strip()
    try:
        return json.loads(text)
    except json.JSONDecodeError:
        match = re.search(r"\{.*\}", text, re.DOTALL)
        if match:
            return json.loads(match.group(0))
        raise


def _judge_client(judge_name: str):
    """Build (and cache) the provider client for a judge identifier.

      github-models[:<model>]  -> GitHub Models (default gpt-4.1)
      gemini[:<model>]         -> Gemini API   (default gemini-2.5-flash)
      gemini-pro               -> Gemini API   (gemini-2.5-pro)
    """
    if judge_name in _JUDGE_CLIENTS:
        return _JUDGE_CLIENTS[judge_name]
    base, _, variant = judge_name.partition(":")
    if base == "github-models":
        model = ("openai/" + variant) if variant else providers.GITHUB_JUDGE_MODEL
        client = providers.GitHubModelsClient(model=model)
    elif base == "gemini":
        client = providers.GeminiClient(model=variant or providers.GEMINI_JUDGE_MODEL)
    elif base == "gemini-pro":
        client = providers.GeminiClient(model="gemini-2.5-pro")
    else:
        raise ValueError(f"Unknown judge identifier: {judge_name}")
    _JUDGE_CLIENTS[judge_name] = client
    return client


def _call_judge(judge_name: str, prompt: str) -> dict:
    """Dispatch a judge call by identifier and return parsed rubric scores."""
    client = _judge_client(judge_name)
    result = client.complete(system=JUDGE_SYSTEM, user=prompt, max_tokens=512)
    if result.error:
        raise RuntimeError(f"{judge_name} judge call failed: {result.error}")
    return _extract_json(result.text)


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
            # The harness persists raw story text per sample under stories/.
            # Filename matches harness.story_filename(): <cell_id>_s<sample_idx>.txt
            story_path = (run_dir / "stories"
                          / f"{row['cell_id'].replace('|', '_')}_s{row['sample_idx']}.txt")
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


def ping(judge_name: str) -> int:
    """One trivial call to confirm a judge's credentials and endpoint work."""
    try:
        client = _judge_client(judge_name)
        result = client.ping()
    except Exception as exc:  # noqa: BLE001
        print(f"[judge] ping FAILED ({judge_name}): {exc}", file=sys.stderr)
        return 1
    if result.error:
        print(f"[judge] ping FAILED ({model}): {result.error}", file=sys.stderr)
        return 1
    print(f"[judge] ping OK  model={result.model}  "
          f"reply={result.text!r}  latency={result.latency_ms}ms")
    return 0


def main(argv: list[str] | None = None) -> int:
    p = argparse.ArgumentParser()
    p.add_argument("--run-id", help="Run id under results/ to score.")
    p.add_argument("--judges", default="github-models",
                   help="Comma-separated judge identifiers.")
    p.add_argument("--ping", action="store_true",
                   help="Connectivity check only; one trivial call, no scoring.")
    args = p.parse_args(argv if argv is not None else sys.argv[1:])
    judges = [j.strip() for j in args.judges.split(",") if j.strip()]
    if args.ping:
        rc = 0
        for j in judges:
            rc |= ping(j)
        return rc
    if not args.run_id:
        print("[judge] --run-id is required unless --ping is used", file=sys.stderr)
        return 1
    return score_run(args.run_id, judges)


if __name__ == "__main__":
    raise SystemExit(main())
