"""Report generator for audit 05.

Reads a run's generations.jsonl + scores.jsonl (+ agreement.jsonl) and
renders audit-reports/05-ai-quality-<date>.md with per-cell distributions,
Critical-cell detection, inter-judge agreement, and a drift section.

Pure stdlib — no numpy. Handles partial scoring: if judging is incomplete
the report states coverage rather than failing.

    python -m backend.eval.report --run-id <id>
    python -m backend.eval.report --run-id <id> --out audit-reports/05-ai-quality-20260522.md
"""

from __future__ import annotations

import argparse
import json
import math
import statistics
import sys
import time
from collections import defaultdict
from pathlib import Path

from . import rubrics
from .harness import RESULTS_ROOT

# age_band_fit score below this counts as a failure for Critical detection.
AGE_FIT_FAIL_BELOW = 3
CRITICAL_FAIL_PCT = 20.0  # audit spec: >=20% age-fit failures in a cell = Critical


def _read_jsonl(path: Path) -> list[dict]:
    if not path.exists():
        return []
    rows = []
    for line in path.read_text(encoding="utf-8").splitlines():
        line = line.strip()
        if not line:
            continue
        try:
            rows.append(json.loads(line))
        except json.JSONDecodeError:
            continue
    return rows


def _mean_ci(values: list[float]) -> tuple[float, float]:
    """Return (mean, half-width of 95% CI). Half-width 0 when N<2."""
    if not values:
        return (0.0, 0.0)
    m = statistics.fmean(values)
    if len(values) < 2:
        return (m, 0.0)
    se = statistics.stdev(values) / math.sqrt(len(values))
    return (m, 1.96 * se)


def _numeric(scores: list[dict], rubric: str) -> list[float]:
    out = []
    for s in scores:
        v = s.get(rubric)
        if v is None or isinstance(v, bool):
            continue
        try:
            out.append(float(v))
        except (TypeError, ValueError):
            continue
    return out


def aggregate(run_dir: Path, primary_judge: str | None = None) -> dict:
    """Compute per-cell distributions.

    When `primary_judge` is set, the per-cell table reflects only that
    judge's scores (so N == unique samples). Other judges' scores still
    feed inter-judge agreement. If `primary_judge` is None, the judge
    with the most rows wins automatically — typically the 100%-complete
    judge.
    """
    generations = _read_jsonl(run_dir / "generations.jsonl")
    score_rows = _read_jsonl(run_dir / "scores.jsonl")
    agreement_rows = _read_jsonl(run_dir / "agreement.jsonl")

    completed = [g for g in generations if g.get("status") == "complete"]
    errored = [g for g in generations if g.get("status") == "error"]

    # cell_id -> list of per-judge score dicts (one entry per scored sample)
    by_cell_scores: dict[str, list[dict]] = defaultdict(list)
    judges_seen: dict[str, int] = defaultdict(int)
    for row in score_rows:
        # Flat schema (one row per cell+sample+judge)
        if "judge" in row and isinstance(row.get("scores"), dict):
            judges_seen[row["judge"]] += 1
            by_cell_scores[row["cell_id"]].append(
                {"judge": row["judge"], **row["scores"]}
            )
            continue
        # Legacy nested schema (one row per cell with scores={judge: {...}})
        per_judge = row.get("scores", {})
        if not isinstance(per_judge, dict):
            continue
        for judge, s in per_judge.items():
            if isinstance(s, dict):
                judges_seen[judge] += 1
                by_cell_scores[row["cell_id"]].append({"judge": judge, **s})

    # Pick the primary judge: explicit arg, else the one with most rows.
    if primary_judge is None and judges_seen:
        primary_judge = max(judges_seen.items(), key=lambda kv: kv[1])[0]

    # cell_id -> (mode, age_band)
    cell_meta: dict[str, tuple[str, str]] = {}
    for g in completed:
        cell_meta.setdefault(g["cell_id"], (g["mode"], g["age_band"]))

    # Aggregate per (mode, age_band).
    cells: dict[tuple[str, str], dict] = {}
    for cell_id, scores in by_cell_scores.items():
        mode, band = cell_meta.get(cell_id, ("?", "?"))
        key = (mode, band)
        bucket = cells.setdefault(key, {"scores": [], "n_samples": 0})
        bucket["scores"].extend(scores)

    summary: dict = {
        "run_dir": str(run_dir),
        "generations_total": len(generations),
        "generations_complete": len(completed),
        "generations_errored": len(errored),
        "scored_samples": len(score_rows),
        "judges": dict(sorted(judges_seen.items())),
        "primary_judge": primary_judge,
        "cells": {},
        "critical": [],
        "agreement": None,
    }

    if agreement_rows:
        vals = [a["agreement"] for a in agreement_rows if "agreement" in a]
        if vals:
            summary["agreement"] = {
                "mean": statistics.fmean(vals),
                "n": len(vals),
                "below_80pct": sum(1 for v in vals if v < 0.8),
            }

    for (mode, band), bucket in sorted(cells.items()):
        scores = bucket["scores"]
        if primary_judge:
            scores = [s for s in scores if s.get("judge") == primary_judge]
        narr_m, narr_ci = _mean_ci(_numeric(scores, "narrative_coherence"))
        age_vals = _numeric(scores, "age_band_fit")
        age_m, age_ci = _mean_ci(age_vals)
        mode_vals = _numeric(scores, "mode_adherence")
        refusal_vals = _numeric(scores, "refusal_flag")
        age_fails = sum(1 for v in age_vals if v < AGE_FIT_FAIL_BELOW)
        age_fail_pct = (100.0 * age_fails / len(age_vals)) if age_vals else 0.0
        cell = {
            "n_scored": len(scores),
            "narrative_coherence": (round(narr_m, 2), round(narr_ci, 2)),
            "age_band_fit": (round(age_m, 2), round(age_ci, 2)),
            "age_fail_pct": round(age_fail_pct, 1),
            "mode_adherence_pct": (
                round(100.0 * statistics.fmean(mode_vals), 1) if mode_vals else None
            ),
            "refusal_pct": (
                round(100.0 * statistics.fmean(refusal_vals), 1)
                if refusal_vals
                else None
            ),
        }
        summary["cells"][f"{mode}|{band}"] = cell
        if age_vals and age_fail_pct >= CRITICAL_FAIL_PCT:
            summary["critical"].append(
                {
                    "cell": f"{mode}|{band}",
                    "age_fail_pct": round(age_fail_pct, 1),
                    "n": len(age_vals),
                }
            )
    return summary


def render(summary: dict) -> str:
    today = time.strftime("%Y-%m-%d")
    L: list[str] = []
    L.append(f"# Audit 05 — AI/ML Quality Evaluation\n")
    L.append(f"**Date:** {today}  ")
    L.append(f"**Run:** `{summary['run_dir']}`\n")

    complete = summary["generations_complete"]
    total = summary["generations_total"]
    scored = summary["scored_samples"]
    primary = summary["primary_judge"]
    L.append("## Coverage\n")
    L.append(
        f"- Generations: **{complete}/{total} complete**, "
        f"{summary['generations_errored']} errored"
    )
    L.append(f"- Scored rows: **{scored}** across judges:")
    for judge, n in summary["judges"].items():
        marker = " (primary)" if judge == primary else ""
        L.append(f"  - {judge}: {n}/{complete} ({100*n/max(1,complete):.1f}%){marker}")
    if primary:
        L.append(
            f"- Per-cell distributions below use **{primary}** "
            "(highest coverage). Other judges feed inter-judge agreement only."
        )
    L.append("")

    L.append("## Critical Cells\n")
    if summary["critical"]:
        L.append(
            f"Cells where >= {CRITICAL_FAIL_PCT:.0f}% of outputs scored "
            f"age_band_fit < {AGE_FIT_FAIL_BELOW}:\n"
        )
        L.append("| Cell | age-fit fail % | N |")
        L.append("|---|---|---|")
        for c in summary["critical"]:
            L.append(f"| {c['cell']} | {c['age_fail_pct']}% | {c['n']} |")
    else:
        L.append("None — no cell crossed the age-fit failure threshold.")
    L.append("")

    L.append("## Per-Cell Scores\n")
    L.append("Mean (95% CI half-width). Mode adherence / refusal as %.\n")
    L.append("| Cell | N | Narrative | Age fit | Age-fail % | Mode adh % | Refusal % |")
    L.append("|---|---|---|---|---|---|---|")
    for cell_id, c in summary["cells"].items():
        narr = f"{c['narrative_coherence'][0]} ±{c['narrative_coherence'][1]}"
        age = f"{c['age_band_fit'][0]} ±{c['age_band_fit'][1]}"
        mode_adh = (
            "-" if c["mode_adherence_pct"] is None else f"{c['mode_adherence_pct']}"
        )
        refusal = "-" if c["refusal_pct"] is None else f"{c['refusal_pct']}"
        L.append(
            f"| {cell_id} | {c['n_scored']} | {narr} | {age} | "
            f"{c['age_fail_pct']} | {mode_adh} | {refusal} |"
        )
    L.append("")

    L.append("## Inter-Judge Agreement\n")
    ag = summary["agreement"]
    if ag:
        L.append(f"- Mean agreement: **{ag['mean']:.1%}** across {ag['n']} cells")
        L.append(f"- Cells below the 80% calibration bar: {ag['below_80pct']}")
        if ag["mean"] < 0.8:
            L.append(
                "- WARNING: mean agreement < 80% — the rubric is ambiguous; "
                "revise judge prompts before locking final scores (audit spec)."
            )
    else:
        L.append(
            "Not computed — needs >= 2 judges. Re-run the judge pass with "
            "`--judges github-models,gemini`."
        )
    L.append("")

    L.append("## Drift Analysis\n")
    L.append(
        "Drift is measured from the E07 test input (a deliberate duplicate "
        "of C01) and the calibration drift pair. Compare the scored E07 and "
        "C01 rows for the same cell once both are judged. A 24-hour replay "
        "of a 10% subsample under `--resume` extends this to time-drift."
    )
    L.append("")

    L.append("## Versioning Audit\n")
    L.append(
        "See `audit-reports/05-ai-quality-20260521-interim.md` finding F-01 "
        "(Critical): no prompt-template version metadata exists in the "
        "codebase. `backend/eval/prompt_registry.py` content-hashes are the "
        "interim mitigation; `python -m backend.eval.snapshot --verify` "
        "detects drift."
    )
    L.append("")

    L.append("## Recommendations\n")
    if summary["critical"]:
        L.append(
            f"1. Address the {len(summary['critical'])} Critical cell(s) above "
            "— inspect the failing outputs and revise the cell's prompt template."
        )
    else:
        L.append("1. No Critical cells — quality bar met across all judged cells.")
    L.append(
        "2. Ship the F-01 versioning fix regardless (per-template version "
        "constant persisted on every Story row)."
    )
    L.append(
        "3. Establish the eval cadence: calibration set on every prompt "
        "change (CI-gated), full pass quarterly with stored drift baseline."
    )
    L.append("")
    return "\n".join(L)


def main(argv: list[str] | None = None) -> int:
    p = argparse.ArgumentParser()
    p.add_argument("--run-id", required=True)
    p.add_argument(
        "--judge",
        default=None,
        help="Filter the per-cell table to this judge. Default: the "
        "judge with the most rows (typically the 100%-complete one).",
    )
    p.add_argument(
        "--out",
        default=None,
        help="Output path. Default: audit-reports/05-ai-quality-<date>.md",
    )
    args = p.parse_args(argv if argv is not None else sys.argv[1:])
    run_dir = RESULTS_ROOT / args.run_id
    if not run_dir.exists():
        print(f"[report] no run dir at {run_dir}", file=sys.stderr)
        return 1
    summary = aggregate(run_dir, primary_judge=args.judge)
    md = render(summary)
    out = (
        Path(args.out)
        if args.out
        else Path(f"audit-reports/05-ai-quality-{time.strftime('%Y%m%d')}.md")
    )
    out.parent.mkdir(parents=True, exist_ok=True)
    out.write_text(md, encoding="utf-8")
    print(
        f"[report] wrote {out}  "
        f"({summary['generations_complete']} gens, {summary['scored_samples']} scored, "
        f"{len(summary['critical'])} critical)"
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
