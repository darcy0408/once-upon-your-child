"""
Validate story load audit metrics against baseline thresholds.

Exits with:
- 0 when all thresholds pass
- 1 when one or more thresholds are breached
"""

from __future__ import annotations

import json
import os
from pathlib import Path
from typing import List

DEFAULT_AUDIT_PATH = "backend/tests/artifacts/story_load_audit_latest.json"
DEFAULT_SUMMARY_PATH = "backend/tests/artifacts/story_load_threshold_summary.md"


def _resolve_path(path: Path) -> Path:
    if path.exists():
        return path
    repo_relative = Path(__file__).resolve().parents[2] / path
    if repo_relative.exists():
        return repo_relative
    backend_relative = Path(__file__).resolve().parents[1] / path.name
    if backend_relative.exists():
        return backend_relative
    tests_artifact_fallback = Path(__file__).resolve().parent / "artifacts" / path.name
    if tests_artifact_fallback.exists():
        return tests_artifact_fallback
    return path


def _load_json(path: Path) -> dict:
    path = _resolve_path(path)
    if not path.exists():
        raise FileNotFoundError(f"Audit artifact not found: {path}")
    return json.loads(path.read_text(encoding="utf-8"))


def _get_metric(report: dict, scenario: str, metric: str) -> float:
    if metric == "errors":
        return float(report["scenarios"][scenario].get("error_count", 0))
    return float(report["scenarios"][scenario]["latency_ms"][metric])


def _build_checks(report: dict) -> List[str]:
    failures: List[str] = []

    checks = [
        ("sync_fast_path", "p95", 500.0, "<="),
        ("sync_fast_path", "mean", 300.0, "<="),
        ("timeout_async_fallback", "p95", 200.0, "<="),
        ("quota_error_429", "p95", 250.0, "<="),
        ("concurrency_ramp_c16", "p95", 1000.0, "<="),
        ("concurrency_ramp_c16", "errors", 0.0, "=="),
    ]

    if os.getenv("RUN_REAL_API_TESTS", "").strip().lower() == "true":
        real_provider = report.get("scenarios", {}).get("real_provider_baseline")
        if real_provider and not real_provider.get("skipped"):
            checks.extend(
                [
                    ("real_provider_baseline", "p95", 45000.0, "<="),
                    ("real_provider_baseline", "mean", 20000.0, "<="),
                    ("real_provider_baseline", "p50", 15000.0, "<="),
                ]
            )

    for scenario, metric, threshold, op in checks:
        value = _get_metric(report, scenario, metric)
        if op == "<=" and value > threshold:
            failures.append(
                f"{scenario}.{metric}={value} breached threshold {op} {threshold}"
            )
        if op == "==" and value != threshold:
            failures.append(
                f"{scenario}.{metric}={value} breached threshold {op} {threshold}"
            )

    status_counts = report["scenarios"]["timeout_async_fallback"]["status_counts"]
    if status_counts != {
        "202": report["scenarios"]["timeout_async_fallback"]["total_requests"]
    }:
        failures.append(
            "timeout_async_fallback status counts are unexpected; expected all 202 responses"
        )

    quota_counts = report["scenarios"]["quota_error_429"]["status_counts"]
    if quota_counts != {
        "429": report["scenarios"]["quota_error_429"]["total_requests"]
    }:
        failures.append(
            "quota_error_429 status counts are unexpected; expected all 429 responses"
        )

    reset = report.get("reset_check", {})
    if reset.get("initial_statuses") != [200, 200, 429]:
        failures.append(
            f"reset_check.initial_statuses unexpected: {reset.get('initial_statuses')}"
        )
    if reset.get("after_wait_status") != 200:
        failures.append(
            f"reset_check.after_wait_status unexpected: {reset.get('after_wait_status')}"
        )

    return failures


def _write_summary(summary_path: Path, report: dict, failures: List[str]) -> None:
    summary_path = _resolve_path(summary_path)
    lines = [
        "# Story Load Threshold Check",
        "",
        f"- Source artifact: `{report.get('timestamp_utc', 'unknown')}`",
        f"- Result: `{'FAIL' if failures else 'PASS'}`",
        "",
        "## Scenario Latencies",
    ]

    for name, data in report.get("scenarios", {}).items():
        latency = data.get("latency_ms", {})
        lines.append(
            f"- `{name}`: p95={latency.get('p95')} ms, mean={latency.get('mean')} ms, status={data.get('status_counts')}"
        )

    lines.append("")
    lines.append("## Reset Check")
    reset = report.get("reset_check", {})
    lines.append(
        f"- initial={reset.get('initial_statuses')} after_wait={reset.get('after_wait_status')}"
    )
    lines.append("")
    lines.append("## Findings")
    if failures:
        for item in failures:
            lines.append(f"- {item}")
    else:
        lines.append("- All thresholds passed.")

    summary_path.parent.mkdir(parents=True, exist_ok=True)
    summary_path.write_text("\n".join(lines), encoding="utf-8")


def main() -> int:
    audit_path = Path(os.getenv("STORY_AUDIT_PATH", DEFAULT_AUDIT_PATH))
    summary_path = Path(os.getenv("STORY_AUDIT_SUMMARY_PATH", DEFAULT_SUMMARY_PATH))

    report = _load_json(audit_path)
    failures = _build_checks(report)
    _write_summary(summary_path, report, failures)

    if failures:
        print("Story load threshold check failed:")
        for item in failures:
            print(f"- {item}")
        return 1

    print("Story load threshold check passed.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
