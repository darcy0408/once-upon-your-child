"""Eval-harness runner.

Iterates every (mode, age_band, test_input) cell, calls the configured
provider, writes one JSONL row per cell to results/<run-id>/generations.jsonl.

Hard budget cap. Resume-safe (idempotent on re-run). Calibration mode
runs a 10-cell slice for pipeline validation before full spend.

This file is a SCAFFOLD. Provider integration is stubbed at `_call_provider`.
The cost-cap, resume, and dry-run logic are real and tested without API calls.

Usage:
    python -m backend.eval.harness --dry-run
    python -m backend.eval.harness --budget 5 --calibration --provider gemini
    python -m backend.eval.harness --budget 25 --provider gemini
    python -m backend.eval.harness --budget 75 --provider openrouter --resume <run-id>
"""

from __future__ import annotations

import argparse
import hashlib
import itertools
import json
import os
import sys
import time
import uuid
from dataclasses import asdict, dataclass
from pathlib import Path
from typing import Iterator

from . import prompt_registry, test_set

RESULTS_ROOT = Path(__file__).parent / "results"

# Per-call rough cost estimates (USD); used when provider response doesn't report.
# Update when models or pricing change.
COST_ESTIMATE_PER_CELL_USD = {
    "gemini": 0.0012,  # gemini-2.5-flash, ~2k in / 3k out
    "gemini-flash-lite": 0.0003,
    "openrouter-claude-sonnet": 0.045,
    "openrouter-llama-70b": 0.0017,
}


@dataclass(frozen=True)
class Cell:
    template_id: str
    mode: str
    age_band: str
    test_id: str

    @property
    def cell_id(self) -> str:
        return f"{self.template_id}|{self.mode}|{self.age_band}|{self.test_id}"


@dataclass
class RunConfig:
    run_id: str
    provider: str
    budget_usd: float
    calibration: bool
    dry_run: bool
    filter: str | None = None


def all_cells() -> Iterator[Cell]:
    """Yield one Cell per (mode, age_band, test_input). The 30 test inputs ARE
    the per-cell sample count required by the audit spec — drift re-runs are
    a separate pass, not a multiplier here.
    """
    for mode, age_band in prompt_registry.VALID_CELLS:
        templates = prompt_registry.for_cell(mode, age_band)
        if not templates:
            continue
        template_id = templates[0].template_id
        for t in test_set.TEST_INPUTS:
            yield Cell(
                template_id=template_id,
                mode=mode,
                age_band=age_band,
                test_id=t.test_id,
            )


def calibration_cells() -> Iterator[Cell]:
    """10-cell slice spanning every mode + the two adversarial trauma cells."""
    seen_modes: set[str] = set()
    for mode, age_band in prompt_registry.VALID_CELLS:
        if mode in seen_modes:
            continue
        seen_modes.add(mode)
        templates = prompt_registry.for_cell(mode, age_band)
        if not templates:
            continue
        yield Cell(
            template_id=templates[0].template_id,
            mode=mode,
            age_band=age_band,
            test_id="C01",
        )
    # Two adversarial cells in the elevated-scrutiny set
    yield Cell("T1_STANDARD", "standard", "8-10", "A06")
    yield Cell("T1_STANDARD", "standard", "8-10", "A07")
    # Two repeats for drift signal
    yield Cell("T1_STANDARD", "standard", "5-7", "C01")
    yield Cell("T1_STANDARD", "standard", "5-7", "C01")


def _existing_completed_cells(run_dir: Path) -> set[str]:
    jsonl = run_dir / "generations.jsonl"
    if not jsonl.exists():
        return set()
    completed: set[str] = set()
    with jsonl.open("r", encoding="utf-8") as f:
        for line in f:
            line = line.strip()
            if not line:
                continue
            try:
                row = json.loads(line)
            except json.JSONDecodeError:
                # Treat a corrupt last line as incomplete; will overwrite.
                continue
            if row.get("status") == "complete":
                completed.add(row["cell_id"] + "|" + str(row["sample_idx"]))
    return completed


def _hash_text(text: str) -> str:
    return hashlib.sha256(text.encode("utf-8")).hexdigest()[:16]


# provider id -> Gemini subscription tier passed to the generation layer.
_PROVIDER_TIER = {
    "gemini": "premium",  # full gemini-2.5-flash
    "gemini-flash-lite": "free",  # gemini-2.5-flash-lite (free-tier model)
}


def story_filename(cell: Cell, sample_idx: int) -> str:
    """Per-sample artifact name. sample_idx keeps drift-pair duplicates
    (identical cell_id, run twice) from overwriting each other."""
    return f"{cell.cell_id.replace('|', '_')}_s{sample_idx}"


def _call_provider(
    cell: Cell, t: test_set.TestInput, provider: str, run_dir: Path, sample_idx: int
) -> dict:
    """Build the assembled prompt, run one generation, persist artifacts.

    Story text is written to run_dir/stories/<cell>_s<idx>.txt and the
    assembled prompt to run_dir/prompts/<cell>_s<idx>.txt so the judge pass
    can read them later. Returns a dict the row-writer serializes to JSONL.
    """
    from . import generation

    if provider not in _PROVIDER_TIER:
        raise NotImplementedError(
            f"Provider '{provider}' not wired for generation yet. "
            f"Supported: {sorted(_PROVIDER_TIER)}. OpenRouter is the "
            "fallback-parity pass and comes later."
        )
    tier = _PROVIDER_TIER[provider]
    out = generation.generate(cell.mode, cell.age_band, t, user_tier=tier)

    safe = story_filename(cell, sample_idx)
    stories_dir = run_dir / "stories"
    prompts_dir = run_dir / "prompts"
    stories_dir.mkdir(parents=True, exist_ok=True)
    prompts_dir.mkdir(parents=True, exist_ok=True)
    (stories_dir / f"{safe}.txt").write_text(out.text, encoding="utf-8")
    (prompts_dir / f"{safe}.txt").write_text(out.prompt, encoding="utf-8")

    return {
        "provider": provider,
        "model": out.model,
        "input_tokens": out.input_tokens,
        "output_tokens": out.output_tokens,
        "cost_usd": out.cost_usd,
        "output": out.text,
        "refused": out.refused,
        "fell_back_to_static": False,
        "prompt_hash": _hash_text(out.prompt),
        "error": out.error,
    }


def _write_row(jsonl: Path, row: dict) -> None:
    with jsonl.open("a", encoding="utf-8") as f:
        f.write(json.dumps(row, ensure_ascii=False) + "\n")


def run(cfg: RunConfig) -> int:
    run_dir = RESULTS_ROOT / cfg.run_id
    run_dir.mkdir(parents=True, exist_ok=True)
    jsonl = run_dir / "generations.jsonl"

    completed = _existing_completed_cells(run_dir)
    cells = list(calibration_cells() if cfg.calibration else all_cells())
    if cfg.filter:
        cells = [c for c in cells if cfg.filter in c.cell_id]
    total = len(cells)
    print(
        f"[harness] run_id={cfg.run_id} provider={cfg.provider} "
        f"budget=${cfg.budget_usd:.2f} cells={total} "
        f"already_complete={len(completed)} dry_run={cfg.dry_run}"
    )

    if cfg.dry_run:
        # Print cell distribution and exit.
        from collections import Counter

        by_cell = Counter((c.mode, c.age_band) for c in cells)
        for (mode, band), n in sorted(by_cell.items()):
            print(f"  {mode:14s} {band:7s} -> {n} generations")
        est_cost = total * COST_ESTIMATE_PER_CELL_USD.get(cfg.provider, 0.005)
        print(f"  estimated total cost: ${est_cost:.2f}")
        if est_cost > cfg.budget_usd:
            print(
                f"  WARN: estimated cost ${est_cost:.2f} exceeds budget ${cfg.budget_usd:.2f}"
            )
        return 0

    spent = 0.0
    per_cell_est = COST_ESTIMATE_PER_CELL_USD.get(cfg.provider, 0.005)
    for i, cell in enumerate(cells, 1):
        sample_key = cell.cell_id + "|" + str(i)
        if sample_key in completed:
            continue
        if spent + per_cell_est > cfg.budget_usd:
            print(
                f"[harness] budget cap reached at ${spent:.2f} / ${cfg.budget_usd:.2f} "
                f"after {i}/{total} cells; halting cleanly."
            )
            _write_row(
                jsonl,
                {
                    "status": "budget_halt",
                    "spent_usd": spent,
                    "cells_remaining": total - i,
                },
            )
            return 0

        t = test_set.by_id(cell.test_id)
        start = time.time()
        try:
            result = _call_provider(cell, t, cfg.provider, run_dir, i)
        except NotImplementedError as exc:
            print(f"[harness] {exc}", file=sys.stderr)
            return 2
        except Exception as exc:
            _write_row(
                jsonl,
                {
                    "status": "error",
                    "cell_id": cell.cell_id,
                    "sample_idx": i,
                    "error": str(exc),
                    "elapsed_s": time.time() - start,
                },
            )
            continue

        spent += result.get("cost_usd", per_cell_est)
        _write_row(
            jsonl,
            {
                "status": "complete",
                "cell_id": cell.cell_id,
                "sample_idx": i,
                "template_id": cell.template_id,
                "mode": cell.mode,
                "age_band": cell.age_band,
                "test_id": cell.test_id,
                "provider": result.get("provider", cfg.provider),
                "model": result.get("model"),
                "latency_ms": int((time.time() - start) * 1000),
                "input_tokens": result.get("input_tokens"),
                "output_tokens": result.get("output_tokens"),
                "cost_usd": result.get("cost_usd", per_cell_est),
                "output_hash": _hash_text(result.get("output", "")),
                "refused": result.get("refused", False),
                "fell_back_to_static": result.get("fell_back_to_static", False),
                "prompt_hash": result.get("prompt_hash"),
                "snapshot_git_sha": prompt_registry.SNAPSHOT_GIT_SHA,
            },
        )
    print(f"[harness] run complete; spent ${spent:.2f} / ${cfg.budget_usd:.2f}")
    return 0


def _parse_args(argv: list[str]) -> RunConfig:
    p = argparse.ArgumentParser()
    p.add_argument(
        "--budget",
        type=float,
        default=5.0,
        help="Hard USD cap. Default $5 (calibration-only).",
    )
    p.add_argument(
        "--provider",
        choices=(
            "gemini",
            "gemini-flash-lite",
            "openrouter-claude-sonnet",
            "openrouter-llama-70b",
        ),
        default="gemini",
    )
    p.add_argument(
        "--calibration",
        action="store_true",
        help="10-cell slice across modes + 4 trauma/drift cells.",
    )
    p.add_argument(
        "--filter",
        type=str,
        default=None,
        help="Substring match against cell_id "
        "(e.g. 'superhero|3-4' to re-run one cell after a fix).",
    )
    p.add_argument(
        "--dry-run",
        action="store_true",
        help="Print the plan and exit; no API calls, no spend.",
    )
    p.add_argument(
        "--resume", type=str, default=None, help="Resume an existing run-id."
    )
    args = p.parse_args(argv)
    run_id = args.resume or time.strftime("%Y%m%d-%H%M%S-") + uuid.uuid4().hex[:6]
    return RunConfig(
        run_id=run_id,
        provider=args.provider,
        budget_usd=args.budget,
        calibration=args.calibration,
        dry_run=args.dry_run,
        filter=args.filter,
    )


def main(argv: list[str] | None = None) -> int:
    cfg = _parse_args(argv if argv is not None else sys.argv[1:])
    return run(cfg)


if __name__ == "__main__":
    raise SystemExit(main())
