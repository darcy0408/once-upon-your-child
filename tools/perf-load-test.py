#!/usr/bin/env python3
"""R0 Capture 3: synthetic story-generation load against STAGING.

Captures real p50/p95/p99 latency for the story-generation path so the audit's
per-segment table stops being code-derived estimates (sample size 0). See
audit-reports/r0-baseline-capture-runbook.md.

SAFETY: never point this at production. The script refuses to run unless
STAGING_BASE_URL is set, hard-blocks a small denylist of known prod hosts,
AND requires the resolved host to positively look like staging (contain a
"staging" token or be in an explicit allowlist) — so a future prod-host rename
can't silently re-open the hole. Per the audit safety protocol, if no staging
environment exists this capture is blocked on infrastructure — do not
substitute prod.

Usage (PowerShell):
    $env:STAGING_BASE_URL = "https://staging-xxx.up.railway.app"
    python tools/perf-load-test.py --mode happy   --samples 50 --concurrency 5
    python tools/perf-load-test.py --mode illustrated --samples 50 --concurrency 5

Modes:
    happy        text-only stories (include_illustrations=false) — baseline.
    illustrated  request illustrations too (PERF-03 verification: 4-image set
                 wall-clock should be ~1x a single image, not 4x).

Results print to stdout and append a row per segment to
audit-reports/perf-traces/segment-latency.csv (schema:
Segment | p50 | p95 | p99 | Sample Size | Date | Environment).
"""

from __future__ import annotations

import argparse
import concurrent.futures
import csv
import os
import statistics
import sys
import time
from datetime import date
from pathlib import Path

import requests

# Hosts this script must never load-test. Substring match, case-insensitive.
# Add your real prod host here as defence-in-depth.
_PROD_DENYLIST = (
    "grand-light",
    "onceuponyourchild",
    "story-weaver-app.up.railway.app",
    "pages.dev",
)

# Positive allowlist (substring match, case-insensitive). The resolved URL must
# either contain a "staging" token OR match one of these explicit hosts. This is
# the load-bearing guard: the denylist alone fails open if prod is ever renamed
# to a host not on the list, but this allowlist fails CLOSED — an unknown host is
# refused unless an operator deliberately adds it here.
_STAGING_TOKENS = ("staging",)
_HOST_ALLOWLIST = (
    # Add explicit non-"staging"-named staging/test hosts here (e.g. an
    # ephemeral preview host) so the positive check still recognises them.
    "127.0.0.1",
    "localhost",
)

REPO_ROOT = Path(__file__).resolve().parent.parent
CSV_PATH = REPO_ROOT / "audit-reports" / "perf-traces" / "segment-latency.csv"


def _resolve_base_url() -> str:
    base = (os.environ.get("STAGING_BASE_URL") or "").strip().rstrip("/")
    if not base:
        sys.exit(
            "STAGING_BASE_URL is not set. Point it at a STAGING host, e.g.\n"
            '  $env:STAGING_BASE_URL = "https://staging-xxx.up.railway.app"\n'
            "Do NOT use production (audit safety protocol)."
        )
    low = base.lower()
    for bad in _PROD_DENYLIST:
        if bad in low:
            sys.exit(
                f"Refusing to run: '{bad}' looks like production ({base}).\n"
                "This tool is staging-only. See r0-baseline-capture-runbook.md."
            )
    # Positive guard: in addition to clearing the denylist, the host MUST look
    # like a known staging/test target. A future prod-host rename therefore
    # can't silently re-open the hole — an unrecognised host fails closed.
    is_allowed = any(tok in low for tok in _STAGING_TOKENS) or any(
        host in low for host in _HOST_ALLOWLIST
    )
    if not is_allowed:
        sys.exit(
            f"Refusing to run: {base} is not a recognised staging host.\n"
            "The URL must contain a 'staging' token or be added to "
            "_HOST_ALLOWLIST in this script. This tool is staging-only; "
            "see r0-baseline-capture-runbook.md."
        )
    return base


def _auth_token(base: str) -> str:
    # Reuses the anonymous-auth path the prod smoke-test recipe relies on, so
    # we exercise authenticated behaviour without UI or a real account.
    r = requests.post(f"{base}/auth/anonymous", json={}, timeout=30)
    r.raise_for_status()
    data = r.json()
    token = data.get("access_token") or data.get("token")
    if not token:
        sys.exit(f"/auth/anonymous returned no access_token: {data!r}")
    return token


def _one_story_call(base: str, token: str, illustrated: bool) -> tuple[float, int]:
    """Fire one /generate-story request, return (elapsed_seconds, status_code)."""
    body = {
        "character": "Pip",
        "character_details": {"age": 6, "role": "Hero"},
        "theme": "Adventure",
        "age": 6,
        "include_illustrations": illustrated,
    }
    if illustrated:
        body["num_images"] = 4
    t0 = time.monotonic()
    try:
        r = requests.post(
            f"{base}/generate-story",
            headers={"Authorization": f"Bearer {token}"},
            json=body,
            timeout=300,  # max wall-clock for one story
        )
        return time.monotonic() - t0, r.status_code
    except requests.RequestException as exc:
        print(f"  request error: {exc}")
        return time.monotonic() - t0, 0


def _percentile(sorted_vals: list[float], pct: float) -> float:
    """Nearest-rank percentile, bounds-safe for small samples."""
    if not sorted_vals:
        return float("nan")
    k = max(
        0,
        min(len(sorted_vals) - 1, int(round(pct / 100.0 * len(sorted_vals) + 0.5)) - 1),
    )
    return sorted_vals[k]


def _append_csv_row(
    segment: str, p50: float, p95: float, p99: float, n: int, environment: str
) -> None:
    CSV_PATH.parent.mkdir(parents=True, exist_ok=True)
    new_file = not CSV_PATH.exists()
    with CSV_PATH.open("a", newline="", encoding="utf-8") as f:
        w = csv.writer(f, lineterminator="\n")
        if new_file:
            w.writerow(
                ["Segment", "p50", "p95", "p99", "Sample Size", "Date", "Environment"]
            )
        w.writerow(
            [
                segment,
                f"{p50:.1f}s",
                f"{p95:.1f}s",
                f"{p99:.1f}s",
                n,
                date.today().isoformat(),
                environment,
            ]
        )
    print(f"  appended -> {CSV_PATH}")


def main() -> None:
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument("--mode", choices=["happy", "illustrated"], default="happy")
    ap.add_argument(
        "--samples",
        type=int,
        default=50,
        help=">=50 for p95 rigor per audit Quality Controls",
    )
    ap.add_argument(
        "--concurrency",
        type=int,
        default=5,
        help="match a reasonable peak; halt and lower if Gemini rate-limits",
    )
    ap.add_argument("--no-csv", action="store_true", help="print only, don't write CSV")
    args = ap.parse_args()

    base = _resolve_base_url()
    illustrated = args.mode == "illustrated"
    print(f"Target (staging): {base}")
    print(
        f"Mode: {args.mode}  samples={args.samples}  concurrency={args.concurrency}\n"
    )

    token = _auth_token(base)
    results: list[tuple[float, int]] = []
    with concurrent.futures.ThreadPoolExecutor(max_workers=args.concurrency) as ex:
        futures = [
            ex.submit(_one_story_call, base, token, illustrated)
            for _ in range(args.samples)
        ]
        for i, fut in enumerate(concurrent.futures.as_completed(futures), 1):
            elapsed, status = fut.result()
            results.append((elapsed, status))
            print(f"{i}/{args.samples}  {elapsed:6.1f}s  status={status}")

    ok_times = sorted(t for t, s in results if s == 200)
    errors = [s for _, s in results if s != 200]
    print(f"\nsuccess: {len(ok_times)}/{args.samples}   errors: {errors or 'none'}")
    if not ok_times:
        sys.exit("No successful samples — cannot compute percentiles.")

    p50 = statistics.median(ok_times)
    p95 = _percentile(ok_times, 95)
    p99 = _percentile(ok_times, 99)
    print(f"p50: {p50:5.1f}s    p95: {p95:5.1f}s    p99: {p99:5.1f}s")

    # Outlier note (audit Error Handling: investigate p99 >> p95 separately).
    if p95 > 0 and p99 > 2 * p95:
        print(
            f"NOTE: p99 ({p99:.1f}s) >> p95 ({p95:.1f}s) — investigate the tail "
            "(likely PERF-02 sync->async double-generation) separately from baseline."
        )

    if not args.no_csv:
        segment = (
            "Story generation - illustrated (4-image)"
            if illustrated
            else "Story generation - happy path"
        )
        _append_csv_row(segment, p50, p95, p99, len(ok_times), "Staging")


if __name__ == "__main__":
    main()
