"""
Story generation load/latency audit harness.

Scenarios covered:
1. Sync fast-path latency under concurrent load
2. Timeout -> async fallback path behavior
3. 429 quota-exceeded behavior
4. Rate-limit reset behavior (control route, fast window)
"""
from __future__ import annotations

import argparse
from contextlib import ExitStack
import json
import math
import os
import sys
import time
from concurrent.futures import ThreadPoolExecutor, as_completed, TimeoutError as FuturesTimeoutError
from dataclasses import dataclass
from datetime import datetime, timedelta, timezone
from pathlib import Path
from types import SimpleNamespace
from typing import Any, Dict, List
from unittest.mock import MagicMock, patch

import jwt
from flask import jsonify

_PATH_CANDIDATES = [
    Path.cwd().resolve(),
    Path.cwd().resolve().parent,
    Path(__file__).resolve().parents[2],
    Path(__file__).resolve().parents[1],
]
for candidate in _PATH_CANDIDATES:
    candidate_str = str(candidate)
    if candidate_str not in sys.path:
        sys.path.insert(0, candidate_str)

from backend.app import create_app
from backend.database import db
from backend.models.user import User


ARTIFACTS_DIR = Path(__file__).resolve().parent / "artifacts"
LATEST_JSON = ARTIFACTS_DIR / "story_load_audit_latest.json"
LATEST_MD = ARTIFACTS_DIR / "story_load_audit_latest.md"
ROUTE_PATCH_TARGETS = ("backend.routes.story_routes", "routes.story_routes")
TASK_PATCH_TARGETS = ("backend.tasks.story_tasks", "tasks.story_tasks")
AUTH_PATCH_TARGETS = ("backend.middleware.auth", "middleware.auth")


@dataclass
class RequestSample:
    status_code: int
    latency_ms: float
    body_status: str | None
    error: str | None
    message: str | None
    perf: Dict[str, Any] | None = None


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


def _extract_story_payload(body: Dict[str, Any]) -> Dict[str, Any]:
    if not isinstance(body, dict):
        return {}
    story = body.get("story")
    if isinstance(story, dict):
        return story
    result = body.get("result")
    if isinstance(result, dict) and isinstance(result.get("story"), dict):
        return result["story"]
    return {}


def _extract_perf(body: Dict[str, Any]) -> Dict[str, Any] | None:
    story_payload = _extract_story_payload(body)
    perf = story_payload.get("_perf")
    return perf if isinstance(perf, dict) else None


def _ensure_audit_user(app) -> dict[str, str]:
    token = jwt.encode(
        {
            "user_id": "story-load-audit-user",
            "sub": "story-load-audit-user",
            "email": "story-load-audit@example.com",
            "exp": int((datetime.now(timezone.utc) + timedelta(hours=1)).timestamp()),
        },
        app.config.get("JWT_SECRET_KEY", "dev-secret-key"),
        algorithm="HS256",
    )

    return {
        "Authorization": f"Bearer {token}",
        "Content-Type": "application/json",
    }


def _run_request(app, payload: Dict[str, Any], headers: Dict[str, str]) -> RequestSample:
    start = time.perf_counter()
    with app.test_client() as client:
        response = client.post("/generate-story", json=payload, headers=headers)
        elapsed_ms = (time.perf_counter() - start) * 1000.0
        body = response.get_json(silent=True) or {}
        return RequestSample(
            status_code=response.status_code,
            latency_ms=elapsed_ms,
            body_status=body.get("status"),
            error=body.get("error"),
            message=body.get("message"),
            perf=_extract_perf(body),
        )


def _run_load(
    app,
    total_requests: int,
    concurrency: int,
    request_timeout_seconds: float = 30.0,
    payload_factory=_story_payload,
    headers: Dict[str, str] | None = None,
) -> List[RequestSample]:
    samples: List[RequestSample] = []
    request_headers = headers or {}

    def worker(index: int) -> RequestSample:
        return _run_request(app, payload_factory(index), request_headers)

    with ThreadPoolExecutor(max_workers=concurrency) as executor:
        futures = [executor.submit(worker, i) for i in range(total_requests)]
        for future in as_completed(futures, timeout=request_timeout_seconds):
            samples.append(future.result())

    return samples


def _scenario_report(samples: List[RequestSample], total: int, concurrency: int) -> Dict[str, Any]:
    latencies = [s.latency_ms for s in samples]
    error_count = sum(1 for s in samples if s.status_code >= 400)
    errors = [
        {"status_code": s.status_code, "error": s.error, "message": s.message}
        for s in samples
        if s.status_code >= 400
    ][:5]
    body_status = [s.body_status for s in samples[:5]]
    report = {
        "total_requests": total,
        "concurrency": concurrency,
        "status_counts": _count_statuses(samples),
        "error_count": error_count,
        "latency_ms": _latency_summary(latencies),
        "sample_errors": errors,
        "sample_body_status": body_status,
    }
    perf_samples = [s.perf for s in samples if s.perf]
    if perf_samples:
        report["sample_perf"] = perf_samples[:3]
        report["perf_ms"] = {
            metric: _latency_summary(
                [float(sample[metric]) for sample in perf_samples if metric in sample]
            )
            for metric in ("prompt_build_ms", "ai_call_ms", "validation_ms", "total_ms")
        }
        providers: Dict[str, int] = {}
        for perf in perf_samples:
            provider = str(perf.get("provider", "unknown"))
            providers[provider] = providers.get(provider, 0) + 1
        report["provider_counts"] = providers
    return report


def _skipped_scenario(reason: str, total: int, concurrency: int) -> Dict[str, Any]:
    return {
        "skipped": True,
        "reason": reason,
        "total_requests": total,
        "concurrency": concurrency,
        "status_counts": {},
        "error_count": 0,
        "latency_ms": _latency_summary([]),
        "sample_errors": [],
        "sample_body_status": [],
    }


def _patch_modules(targets: tuple[str, ...], attribute: str, **kwargs):
    stack = ExitStack()
    for target in targets:
        try:
            stack.enter_context(patch(f"{target}.{attribute}", **kwargs))
        except (AttributeError, ModuleNotFoundError):
            continue
    return stack


def _auth_session_get(entity, key):
    entity_name = getattr(entity, "__name__", "")
    if entity_name == "User" and str(key) == "story-load-audit-user":
        return SimpleNamespace(
            id="story-load-audit-user",
            email="story-load-audit@example.com",
            role="user",
            subscription_tier="premium",
        )
    return None


def measure_fallback_switchover(app, headers: Dict[str, str]) -> Dict[str, Any]:
    with patch.dict(
        os.environ,
        {"GEMINI_API_KEY": "invalid-fast-fail", "OPENROUTER_API_KEY": ""},
        clear=False,
    ), _patch_modules(
        TASK_PATCH_TARGETS,
        "StoryGenerationService",
        return_value=MagicMock(generate_story=MagicMock(side_effect=Exception("401 Unauthorized"))),
    ):
        sample = _run_request(app, _story_payload(0), headers)

    perf = sample.perf or {}
    provider_sequence = perf.get("provider_sequence") or []
    summary_line = (
        f"fallback_switchover: total={round(sample.latency_ms)}ms "
        f"provider_sequence={'->'.join(provider_sequence) if provider_sequence else 'unknown'}"
    )
    return {
        "status_code": sample.status_code,
        "body_status": sample.body_status,
        "latency_ms": round(sample.latency_ms, 2),
        "perf": perf,
        "provider_sequence": provider_sequence,
        "summary_line": summary_line,
    }


def _run_concurrency_ramp(app, headers: Dict[str, str]) -> Dict[str, Any]:
    levels = [1, 4, 8, 16, 32]
    scenarios: Dict[str, Any] = {}
    rows: List[Dict[str, Any]] = []

    with _patch_modules(
        ROUTE_PATCH_TARGETS,
        "_run_sync_story_task_with_timeout",
        side_effect=_fake_sync_story_result,
    ):
        for concurrency in levels:
            samples = _run_load(app, total_requests=24, concurrency=concurrency, headers=headers)
            scenario_name = f"concurrency_ramp_c{concurrency}"
            scenario_report = _scenario_report(samples, 24, concurrency)
            scenarios[scenario_name] = scenario_report
            rows.append(
                {
                    "concurrency": concurrency,
                    "p95_ms": scenario_report["latency_ms"]["p95"],
                    "mean_ms": scenario_report["latency_ms"]["mean"],
                    "errors": scenario_report["error_count"],
                }
            )

    return {"scenarios": scenarios, "rows": rows}


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
        if scenario.get("skipped"):
            lines.append(f"- Skipped: `{scenario.get('reason')}`")
            lines.append("")
            continue
        lines.append(f"- Requests: `{scenario['total_requests']}`")
        lines.append(f"- Concurrency: `{scenario['concurrency']}`")
        lines.append(f"- Status counts: `{scenario['status_counts']}`")
        lines.append(f"- Errors: `{scenario.get('error_count', 0)}`")
        lines.append(f"- Latency ms: `{scenario['latency_ms']}`")
        if scenario.get("provider_counts"):
            lines.append(f"- Providers: `{scenario['provider_counts']}`")
        if scenario.get("perf_ms"):
            lines.append(f"- Perf ms: `{scenario['perf_ms']}`")
        if scenario["sample_errors"]:
            lines.append(f"- Sample errors: `{scenario['sample_errors']}`")
        lines.append("")

    if report.get("concurrency_ramp"):
        lines.extend(
            [
                "## Concurrency Ramp",
                "",
                "| concurrency | p95_ms | mean_ms | errors |",
                "| --- | ---: | ---: | ---: |",
            ]
        )
        for row in report["concurrency_ramp"]["rows"]:
            lines.append(
                f"| {row['concurrency']} | {row['p95_ms']} | {row['mean_ms']} | {row['errors']} |"
            )
        lines.append("")

    if report.get("fallback_switchover"):
        lines.extend(
            [
                "## Fallback Switchover",
                f"- `{report['fallback_switchover']['summary_line']}`",
                "",
            ]
        )

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


def run_story_load_audit(enable_real_api: bool = False) -> Dict[str, Any]:
    app = create_app("testing")
    with app.app_context():
        db.create_all()
    auth_headers = _ensure_audit_user(app)

    # Force limiter on for reset probe route.
    app.limiter.enabled = True
    _ensure_reset_probe_route(app)

    report: Dict[str, Any] = {
        "timestamp_utc": datetime.now(timezone.utc).isoformat(),
        "notes": {
            "target_endpoint": "/generate-story",
            "mode": "local flask test client with mocked task behaviors plus optional real-provider probes",
        },
        "scenarios": {},
        "reset_check": {},
    }

    with _patch_modules(
        AUTH_PATCH_TARGETS,
        "db.session.get",
        side_effect=_auth_session_get,
    ):
        # 1) Sync fast path
        with _patch_modules(
            ROUTE_PATCH_TARGETS,
            "_run_sync_story_task_with_timeout",
            side_effect=_fake_sync_story_result,
        ):
            samples = _run_load(app, total_requests=24, concurrency=6, headers=auth_headers)
            report["scenarios"]["sync_fast_path"] = _scenario_report(samples, 24, 6)

        # 2) Timeout -> async fallback
        fake_task = MagicMock()
        fake_task.id = "audit-task-001"
        with _patch_modules(
            ROUTE_PATCH_TARGETS,
            "_run_sync_story_task_with_timeout",
            side_effect=FuturesTimeoutError(),
        ), _patch_modules(
            ROUTE_PATCH_TARGETS,
            "_celery_runs_eagerly",
            return_value=False,
        ), _patch_modules(
            ROUTE_PATCH_TARGETS,
            "generate_story_task.delay",
            return_value=fake_task,
        ):
            samples = _run_load(app, total_requests=16, concurrency=4, headers=auth_headers)
            report["scenarios"]["timeout_async_fallback"] = _scenario_report(samples, 16, 4)

        # 3) Quota 429 behavior
        with _patch_modules(
            ROUTE_PATCH_TARGETS,
            "_run_sync_story_task_with_timeout",
            side_effect=Exception("429 Quota exceeded"),
        ):
            samples = _run_load(app, total_requests=12, concurrency=4, headers=auth_headers)
            report["scenarios"]["quota_error_429"] = _scenario_report(samples, 12, 4)

        real_api_enabled = enable_real_api or os.getenv("RUN_REAL_API_TESTS", "").strip().lower() == "true"
        report["notes"]["real_api_enabled"] = real_api_enabled
        if real_api_enabled:
            if not os.getenv("GEMINI_API_KEY"):
                report["scenarios"]["real_provider_baseline"] = _skipped_scenario(
                    "GEMINI_API_KEY not set; skipping real provider baseline.",
                    5,
                    1,
                )
            else:
                samples = _run_load(
                    app,
                    total_requests=5,
                    concurrency=1,
                    request_timeout_seconds=180.0,
                    headers=auth_headers,
                )
                report["scenarios"]["real_provider_baseline"] = _scenario_report(samples, 5, 1)

        report["fallback_switchover"] = measure_fallback_switchover(app, auth_headers)
        print(report["fallback_switchover"]["summary_line"])

        concurrency_ramp = _run_concurrency_ramp(app, auth_headers)
        report["concurrency_ramp"] = {"rows": concurrency_ramp["rows"]}
        report["scenarios"].update(concurrency_ramp["scenarios"])

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
    parser = argparse.ArgumentParser()
    parser.add_argument(
        "--real-api",
        action="store_true",
        help="Run the optional real-provider baseline against Gemini when GEMINI_API_KEY is set.",
    )
    args = parser.parse_args()
    result = run_story_load_audit(enable_real_api=args.real_api)
    print(json.dumps(result, indent=2))
