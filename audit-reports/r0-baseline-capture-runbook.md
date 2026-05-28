# R0: Performance Baseline Capture Runbook

Date: 2026-05-27
Status: Runbook — execute when you have a device + staging environment

## Purpose

The audit report's per-segment latency table is currently all code-derived
estimates with sample size 0. This runbook captures real numbers so the
audit's recommendations have empirical baselines and the post-fix wins are
measurable. Replaces estimates in
`audit-reports/perf-traces/segment-latency.csv`.

## Three things to capture

| Capture | Source | Effort |
|---------|--------|--------|
| 1. App cold start (Android, mid-tier) | `flutter --trace-startup` on a device | 30 min |
| 2. Wizard frame timing | Flutter DevTools timeline on a debug build | 30 min |
| 3. Story-generation segment latency under load | Python script hitting staging `/generate-story` | 1 hr |

Total time including write-up: ~3 hours.

## Capture 1 — Android cold start with `--trace-startup`

Target: representative **mid-tier Android device** (e.g., Pixel 5, Pixel 6a, or
similar 2022 mid-tier). Avoid flagship devices — they hide real cold-start
problems by being too fast.

```powershell
# From C:\dev\story-weaver-app
# Ensure device is connected and authorized:
flutter devices

# Build a release-mode APK with trace flags. --trace-startup writes a JSON
# timeline file to the device that captures Dart VM startup, first-frame
# rendering, and engine initialization.
flutter run --profile --trace-startup --verbose -d <device-id>

# Stop after the wizard's first screen is fully visible. Pull the trace:
adb pull /data/user/0/com.example.story_weaver_app/cache/start_up_info.json `
  audit-reports/perf-traces/r0-coldstart-android-$(Get-Date -Format yyyyMMdd).json

# Repeat 3 times to get a stable median. Discard the first run (it pays
# install / dex-opt cost the user only pays once).
```

What to extract from each trace JSON:

| Field | Meaning |
|-------|---------|
| `engineEnterTimestampMicros` | When Flutter engine started |
| `timeToFirstFrameRasterizedMicros` | First frame visible |
| `timeToFrameworkInitMicros` | Dart framework ready |

The metric the budget targets is `timeToFirstFrameRasterizedMicros` — the
audit budget is **≤ 2.0s p50, ≤ 3.5s p95**.

Verify in particular that PERF-05 (deferred Firebase init) is reflected: the
delta between framework init and first frame should be tight, not held up by
a synchronous Firebase initialization.

## Capture 2 — Wizard frame timing

Use Flutter DevTools' Performance tab on a `--profile` build (not debug —
debug is too slow to be representative; not release — release strips
profiling).

```powershell
flutter run --profile -d <device-id>
# DevTools URL prints in the console — open in browser.
# In DevTools: Performance tab → "Record" → click through the full wizard
#   (name → age → consent → archetype → companion → review → magic).
# Stop recording. Export the timeline.
```

What to extract:

- **Frame build times.** Filter for frames > 16ms (jank, 60Hz target). Note
  the screens / interactions where they spike.
- **`build()` cost by widget.** Identify any single `build()` call > 8ms.
  PERF-13 and PERF-15 should have flattened the previously-known sources
  (`SafeAssetImage` decode, ListView eager materialization).
- **`Image.decode` time off the GPU thread.** PERF-13's cacheWidth/Height
  should keep this under 4ms per image now.

Output: a brief markdown note appended to this runbook with the actual
p50/p95 frame times observed, and any new jank source surfaced.

## Capture 3 — Synthetic load on staging backend

**Critical safety rule: never run this against production.** Use staging.
If no staging environment exists, this capture is **blocked on infrastructure**
and should be deferred — do not substitute prod, per the audit's safety
protocol.

If staging exists, the script template:

```python
# tools/perf-load-test.py — write this file if absent
import json, time, statistics, requests, concurrent.futures, os, sys

BASE = os.environ.get("STAGING_BASE_URL")  # e.g. https://staging-...railway.app
if not BASE:
    sys.exit("Set STAGING_BASE_URL env var to your staging host. Do NOT use prod.")

def auth_token():
    r = requests.post(f"{BASE}/auth/anonymous", json={}, timeout=30)
    r.raise_for_status()
    return r.json()["access_token"]

def one_story_call(token):
    t0 = time.monotonic()
    r = requests.post(
        f"{BASE}/generate-story",
        headers={"Authorization": f"Bearer {token}"},
        json={
            "character": "Pip",
            "character_details": {"age": 6, "role": "Hero"},
            "theme": "Adventure",
            "age": 6,
            "include_illustrations": False,
        },
        timeout=300,  # max wall-clock for one story
    )
    elapsed = time.monotonic() - t0
    return elapsed, r.status_code, len((r.text or "").encode())

SAMPLES = 50  # ≥50 for p95 rigor per audit Quality Controls
CONCURRENCY = 5  # match a reasonable peak; bump for stress tests later

token = auth_token()
results = []
with concurrent.futures.ThreadPoolExecutor(max_workers=CONCURRENCY) as ex:
    futures = [ex.submit(one_story_call, token) for _ in range(SAMPLES)]
    for i, f in enumerate(concurrent.futures.as_completed(futures), 1):
        elapsed, status, bytes_ = f.result()
        results.append((elapsed, status))
        print(f"{i}/{SAMPLES}  {elapsed:6.1f}s  status={status}")

times = [t for t, s in results if s == 200]
errors = [s for _, s in results if s != 200]
print(f"\nsuccess: {len(times)}/{SAMPLES}  errors: {errors}")
print(f"p50:  {statistics.median(times):.1f}s")
print(f"p95:  {sorted(times)[int(len(times)*0.95)]:.1f}s" if times else "—")
print(f"p99:  {sorted(times)[int(len(times)*0.99)]:.1f}s" if times else "—")
```

Run it three times — once for the **happy path** numbers, once for **PERF-02
verification** (kill the sync timeout via env to force async path; confirm
no double-generation), and once for **PERF-03 verification** (request
`include_illustrations:true, num_images:4`; confirm total wall-clock is
close to 1× single image after the concurrency-3 parallelization, not 4×).

If staging starts triggering Gemini rate limits during the synthetic run,
**halt and lower CONCURRENCY** (audit safety protocol). Don't escalate the
load looking for a breaking point on staging without coordinating with the
provider.

## Writing up the captures

Replace the relevant rows in
`audit-reports/perf-traces/segment-latency.csv` with the captured values:

- `App cold start (subsequent launch)` → from Capture 1 medians
- `Wizard screen frame build` → from Capture 2 p50/p95
- `Story generation - happy path` → from Capture 3 happy run
- `Story generation - unhappy path` → from Capture 3 PERF-02 verification
- `Illustration - per image (Gemini)` and `4-image set` → from Capture 3
  PERF-03 verification

Change the `Environment` column from "Code-derived estimate" to "Staging" or
"Android profile" as appropriate, and update `Sample Size` to the real
sample count.

Then update the audit report's `Per-Segment Latency` table and remove the
"all code-derived estimate" caveat from `Measurement Limitations`.

## What this runbook does NOT cover

- iOS cold start (no iOS device available in the dev environment).
- Web bundle TTI — already captured empirically via `flutter build web`
  (PERF-16).
- Railway container cold start — needs Railway metrics API access; deferred.
- True end-user-perceived latency on real-world networks — synthetic load
  uses the dev laptop's network. For real-world numbers, use a tool like
  WebPageTest or a real test device on cellular.
