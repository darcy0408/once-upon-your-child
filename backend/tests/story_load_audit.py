"""
Story generation load/latency audit harness.

Scenarios covered:
1. Sync fast-path latency under concurrent load
2. Timeout -> async fallback path behavior
3. 429 quota-exceeded behavior
4. Rate-limit reset behavior (control route, fast window)
"""
from __future__ import annotations

import json
import math
import os
import sys
import time
from concurrent.futures import ThreadPoolExecutor, as_completed, TimeoutError as FuturesTimeoutError
from dataclasses import dataclass
from datetime import datetime, timezone
from pathlib import Path
from typing import Any, Dict, List
from unittest.mock import MagicMock, patch

from flask import jsonify

sys.path.insert(0, os.path.abspath(os.path.join(os.path.dirname(__file__), "../..")))

from backend.app import create_app
from backend.database import db


ARTIFACTS_DIR = Path(__file__).resolve().parent / "artifacts"
LATEST_JSON = ARTIFACTS_DIR / "story_load_audit_latest.json"
LATEST_MD = ARTIFACTS_DIR / "story_load_audit_latest.md"


@dataclass
class RequestSample:
    status_code: int
    latency_ms: float
    body_status: str | None
    error: str | None
    message: str | None


def _percentile(sorted_values: List[float], percentile: float) -> float:
    if not sorted_values:
        return 0.0
    if len(sorted_values) == 1:
        return round(sorted_values[0], 2)
    rank = (percentile / 100.0) * (len(sorted_values) - 1)
    low = math.floor(rank)
    high = math.ceil(rank)
    if low == high:
        return round(sorted_values[low], 2)
    weight = rank - low
    value = sorted_values[low] * (1.0 - weight) + sorted_values[high] * weight
    return round(value, 2)


def _latency_summary(latencies: List[float]) -> Dict[str, float]:
    if not latencies:
        return {
            "min": 0.0,
            "p50": 0.0,
            "p95": 0.0,
            "p99": 0.0,
            "max": 0.0,
            "mean": 0.0,
        }
    sorted_values = sorted(latencies)
    return {
        "min": round(sorted_values[0], 2),
        "p50": _percentile(sorted_values, 50),
        "p95": _percentile(sorted_values, 95),
        "p99": _percentile(sorted_values, 99),
        "max": round(sorted_values[-1], 2),
        "mean": round(sum(sorted_values) / len(sorted_values), 2),
    }


def _count_statuses(samples: List[RequestSample]) -> Dict[str, int]:
    counts: Dict[str, int] = {}
    for sample in samples:
        key = str(sample.status_code)
        counts[key] = counts.get(key, 0) + 1
    return counts


def _story_payload(request_index: int) -> Dict[str, Any]:
    return {
        "character": f"Luna-{request_index % 5}",
        "theme": "Adventure",
        "age": 7,
        "story_length": "standard",
        "include_illustrations": False,
        "async_illustrations": False,
    }


def _run_load(
    app,
    total_requests: int,
    concurrency: int,
    request_timeout_seconds: float = 30.0,
) -> List[RequestSample]:
    samples: List[RequestSample] = []

    def worker(index: int) -> RequestSample:
        start = time.perf_counter()
        with app.test_client() as client:
            response = client.post("/generate-story", json=_story_payload(index))
            elapsed_ms = (time.perf_counter() - start) * 1000.0
            body = response.get_json(silent=True) or {}
            return RequestSample(
                status_code=response.status_code,
                latency_ms=elapsed_ms,
                body_status=body.get("status"),
                error=body.get("error"),
                message=body.get("message"),
            )

    with ThreadPoolExecutor(max_workers=concurrency) as executor:
        futures = [executor.submit(worker, i) for i in range(total_requests)]
        for future in as_completed(futures, timeout=request_timeout_seconds):
            samples.append(future.result())

    return samples


def _scenario_report(samples: List[RequestSample], total: int, concurrency: int) -> Dict[str, Any]:
    latencies = [s.latency_ms for s in samples]
    errors = [
        {"status_code": s.status_code, "error": s.error, "message": s.message}
        for s in samples
        if s.status_code >= 400
    ][:5]
    body_status = [s.body_status for s in samples[:5]]
    return {
        "total_requests": total,
        "concurrency": concurrency,
        "status_counts": _count_statuses(samples),
        "latency_ms": _latency_summary(latencies),
        "sample_errors": errors,
        "sample_body_status": body_status,
    }


def _ensure_reset_probe_route(app) -> None:
    # Control route for quick reset validation (story route limits are minute/hour scale).
    endpoint_name = "__story_load_audit_rate_reset"
    route_path = "/__audit__/rate-reset"

    if endpoint_name not in app.view_functions:
        @app.route(route_path, methods=["GET"], endpoint=endpoint_name)
        @app.limiter.limit("2 per second")
        def _rate_reset_probe():
            return jsonify({"ok": True}), 200


def _run_reset_check(app) -> Dict[str, Any]:
    with app.test_client() as client:
        first = client.get("/__audit__/rate-reset")
        second = client.get("/__audit__/rate-reset")
        third = client.get("/__audit__/rate-reset")
        time.sleep(1.2)
        after_wait = client.get("/__audit__/rate-reset")

    first_headers = {
        "X-RateLimit-Limit": first.headers.get("X-RateLimit-Limit"),
        "X-RateLimit-Remaining": first.headers.get("X-RateLimit-Remaining"),
        "X-RateLimit-Reset": first.headers.get("X-RateLimit-Reset"),
    }
    third_body = third.get_json(silent=True) or {}
    after_body = after_wait.get_json(silent=True) or {}
    return {
        "initial_statuses": [first.status_code, second.status_code, third.status_code],
        "after_wait_status": after_wait.status_code,
        "first_headers": first_headers,
        "third_error": third_body.get("error"),
        "after_wait_error": after_body.get("error"),
    }


def _fake_sync_story_result(*_args, **_kwargs) -> Dict[str, Any]:
    time.sleep(0.18)
    return {
        "status": "complete",
        "story": {
            "title": "Audit Story",
            "story_text": "A short safe audit story.",
            "theme": "Adventure",
            "wisdom_gem": "Keep going.",
        },
    }


def _build_markdown_report(report: Dict[str, Any]) -> str:
    lines = [
        "# Story Load Audit",
        "",
        f"- Generated (UTC): `{report['timestamp_utc']}`",
        f"- Target endpoint: `{report['notes']['target_endpoint']}`",
        "",
        "## Scenarios",
    ]
    for scenario_name, scenario in report["scenarios"].items():
        lines.append(f"### {scenario_name}")
        lines.append(f"- Requests: `{scenario['total_requests']}`")
        lines.append(f"- Concurrency: `{scenario['concurrency']}`")
        lines.append(f"- Status counts: `{scenario['status_counts']}`")
        lines.append(f"- Latency ms: `{scenario['latency_ms']}`")
        if scenario["sample_errors"]:
            lines.append(f"- Sample errors: `{scenario['sample_errors']}`")
        lines.append("")

    lines.extend(
        [
            "## Reset Check",
            f"- Initial statuses: `{report['reset_check']['initial_statuses']}`",
            f"- After wait status: `{report['reset_check']['after_wait_status']}`",
            f"- First response headers: `{report['reset_check']['first_headers']}`",
            "",
        ]
    )
    return "\n".join(lines)


def run_story_load_audit() -> Dict[str, Any]:
    app = create_app("testing")
    with app.app_context():
        db.create_all()

    # Force limiter on for reset probe route.
    app.limiter.enabled = True
    _ensure_reset_probe_route(app)

    report: Dict[str, Any] = {
        "timestamp_utc": datetime.now(timezone.utc).isoformat(),
        "notes": {
            "target_endpoint": "/generate-story",
            "mode": "local flask test client with mocked task behaviors",
        },
        "scenarios": {},
        "reset_check": {},
    }

    # 1) Sync fast path
    with patch(
        "backend.routes.story_routes._run_sync_story_task_with_timeout",
        side_effect=_fake_sync_story_result,
    ):
        samples = _run_load(app, total_requests=24, concurrency=6)
        report["scenarios"]["sync_fast_path"] = _scenario_report(samples, 24, 6)

    # 2) Timeout -> async fallback
    fake_task = MagicMock()
    fake_task.id = "audit-task-001"
    with patch(
        "backend.routes.story_routes._run_sync_story_task_with_timeout",
        side_effect=FuturesTimeoutError(),
    ), patch(
        "backend.routes.story_routes._celery_runs_eagerly",
        return_value=False,
    ), patch(
        "backend.routes.story_routes.generate_story_task.delay",
        return_value=fake_task,
    ):
        samples = _run_load(app, total_requests=16, concurrency=4)
        report["scenarios"]["timeout_async_fallback"] = _scenario_report(samples, 16, 4)

    # 3) Quota 429 behavior
    with patch(
        "backend.routes.story_routes._run_sync_story_task_with_timeout",
        side_effect=Exception("429 Quota exceeded"),
    ):
        samples = _run_load(app, total_requests=12, concurrency=4)
        report["scenarios"]["quota_error_429"] = _scenario_report(samples, 12, 4)

    # 4) Reset behavior (use dedicated testing config with limiter enabled)
    from backend.config import TestingConfig

    class _RateLimitTestingConfig(TestingConfig):
        RATELIMIT_ENABLED = True
        RATELIMIT_STORAGE_URI = "memory://"
        RATELIMIT_HEADERS_ENABLED = True

    with patch(
        "backend.app.config_by_name",
        {k: _RateLimitTestingConfig for k in ("dev", "development", "prod", "production", "testing", "default")},
    ):
        reset_app = create_app("testing")

    _ensure_reset_probe_route(reset_app)
    report["reset_check"] = _run_reset_check(reset_app)
    report["notes"]["reset_check_app_config"] = "testing(rate-limit-enabled)"

    ARTIFACTS_DIR.mkdir(parents=True, exist_ok=True)
    timestamp_tag = datetime.now(timezone.utc).strftime("%Y%m%dT%H%M%SZ")
    versioned_json = ARTIFACTS_DIR / f"story_load_audit_{timestamp_tag}.json"
    versioned_md = ARTIFACTS_DIR / f"story_load_audit_{timestamp_tag}.md"

    report_json = json.dumps(report, indent=2)
    report_md = _build_markdown_report(report)

    LATEST_JSON.write_text(report_json, encoding="utf-8")
    LATEST_MD.write_text(report_md, encoding="utf-8")
    versioned_json.write_text(report_json, encoding="utf-8")
    versioned_md.write_text(report_md, encoding="utf-8")

    return report


if __name__ == "__main__":
    result = run_story_load_audit()
    print(json.dumps(result, indent=2))
