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
import time
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


def _existing_scores(scores_path: Path) -> tuple[set[tuple[str, int, str]], dict[tuple[str, int], dict[str, dict]]]:
    """Return (set of done (cell_id, sample_idx, judge), and a per-(cell,sample)
    judge->scores dict for agreement computation).
    """
    done: set[tuple[str, int, str]] = set()
    by_sample: dict[tuple[str, int], dict[str, dict]] = {}
    if not scores_path.exists():
        return done, by_sample
    for line in scores_path.read_text(encoding="utf-8").splitlines():
        line = line.strip()
        if not line:
            continue
        try:
            r = json.loads(line)
        except json.JSONDecodeError:
            continue
        cell_id = r.get("cell_id")
        sample_idx = r.get("sample_idx")
        # Flat schema: one row per (cell, sample, judge)
        if "judge" in r and "scores" in r:
            done.add((cell_id, sample_idx, r["judge"]))
            by_sample.setdefault((cell_id, sample_idx), {})[r["judge"]] = r["scores"]
            continue
        # Legacy nested schema: one row per cell, scores is judge->dict
        nested = r.get("scores", {})
        if isinstance(nested, dict):
            for j, s in nested.items():
                done.add((cell_id, sample_idx, j))
                by_sample.setdefault((cell_id, sample_idx), {})[j] = s
    return done, by_sample


def score_run(run_id: str, judges: list[str], throttle_sec: float = 4.0) -> int:
    """Score a generation run. Resume-safe: skips (cell, sample, judge) pairs
    already in scores.jsonl. Per-judge errors (rate limits, JSON parse) are
    logged and the loop continues; cells are revisited on the next run.
    """
    run_dir = RESULTS_ROOT / run_id
    gen_jsonl = run_dir / "generations.jsonl"
    if not gen_jsonl.exists():
        print(f"[judge] no generations file at {gen_jsonl}", file=sys.stderr)
        return 1
    scores_path = run_dir / "scores.jsonl"
    agreement_path = run_dir / "agreement.jsonl"
    done, by_sample = _existing_scores(scores_path)
    seen_agreements: set[tuple[str, int]] = set()
    if agreement_path.exists():
        for line in agreement_path.read_text(encoding="utf-8").splitlines():
            line = line.strip()
            if not line:
                continue
            try:
                r = json.loads(line)
                seen_agreements.add((r["cell_id"], r.get("sample_idx", -1)))
            except (json.JSONDecodeError, KeyError):
                continue

    print(f"[judge] scoring {gen_jsonl} with judges={judges}; "
          f"already_done={len(done)} pairs")

    counts = {"scored": 0, "skipped": 0, "errors": 0}
    for line in gen_jsonl.read_text(encoding="utf-8").splitlines():
        line = line.strip()
        if not line:
            continue
        try:
            row = json.loads(line)
        except json.JSONDecodeError:
            continue
        if row.get("status") != "complete":
            continue
        cell_id = row["cell_id"]
        sample_idx = row["sample_idx"]
        story_path = (run_dir / "stories"
                      / f"{cell_id.replace('|', '_')}_s{sample_idx}.txt")
        if not story_path.exists():
            print(f"[judge] skipping {cell_id} s{sample_idx} — story missing",
                  file=sys.stderr)
            counts["skipped"] += 1
            continue
        story_text = story_path.read_text(encoding="utf-8")
        t = test_set.by_id(row["test_id"])
        prompt = build_judge_prompt(row, story_text, t)

        for judge in judges:
            key = (cell_id, sample_idx, judge)
            if key in done:
                counts["skipped"] += 1
                continue
            try:
                s = _call_judge(judge, prompt)
            except NotImplementedError as exc:
                print(f"[judge] FATAL {judge}: {exc}", file=sys.stderr)
                return 2
            except Exception as exc:  # noqa: BLE001 — log and continue on transient/judge-side errors
                print(f"[judge] err  {judge}  {cell_id} s{sample_idx}  "
                      f"{type(exc).__name__}: {exc}", file=sys.stderr)
                counts["errors"] += 1
                continue
            with scores_path.open("a", encoding="utf-8") as sf:
                sf.write(json.dumps({
                    "cell_id": cell_id, "sample_idx": sample_idx,
                    "judge": judge, "scores": s,
                }) + "\n")
            by_sample.setdefault((cell_id, sample_idx), {})[judge] = s
            done.add(key)
            counts["scored"] += 1
            if throttle_sec > 0:
                time.sleep(throttle_sec)

        # Agreement: emit when 2+ judges have scored this sample and not yet
        # logged.
        if len(judges) >= 2 and (cell_id, sample_idx) not in seen_agreements:
            scored = by_sample.get((cell_id, sample_idx), {})
            present = [scored[j] for j in judges if j in scored]
            if len(present) >= 2:
                ag = _inter_judge_agreement(present[0], present[1])
                with agreement_path.open("a", encoding="utf-8") as af:
                    af.write(json.dumps({
                        "cell_id": cell_id, "sample_idx": sample_idx,
                        "judges": judges[:2], "agreement": ag,
                    }) + "\n")
                seen_agreements.add((cell_id, sample_idx))

    print(f"[judge] done. scored={counts['scored']} skipped={counts['skipped']} "
          f"errors={counts['errors']}")
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
        print(f"[judge] ping FAILED ({result.model}): {result.error}", file=sys.stderr)
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
    p.add_argument("--throttle-sec", type=float, default=4.0,
                   help="Sleep between cells to stay under per-minute rate limits.")
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
    return score_run(args.run_id, judges, throttle_sec=args.throttle_sec)


if __name__ == "__main__":
    raise SystemExit(main())
