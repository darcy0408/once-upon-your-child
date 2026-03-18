# Story Load Threshold Check

- Source artifact: `2026-03-18T15:37:50.587498+00:00`
- Result: `PASS`

## Scenario Latencies
- `sync_fast_path`: p95=230.47 ms, mean=196.07 ms, status={'200': 24}
- `timeout_async_fallback`: p95=25.11 ms, mean=19.54 ms, status={'202': 16}
- `quota_error_429`: p95=218.33 ms, mean=141.16 ms, status={'429': 12}
- `concurrency_ramp_c1`: p95=183.66 ms, mean=182.42 ms, status={'200': 24}
- `concurrency_ramp_c4`: p95=183.96 ms, mean=182.26 ms, status={'200': 24}
- `concurrency_ramp_c8`: p95=186.24 ms, mean=183.45 ms, status={'200': 24}
- `concurrency_ramp_c16`: p95=183.43 ms, mean=182.5 ms, status={'200': 24}
- `concurrency_ramp_c32`: p95=185.32 ms, mean=183.42 ms, status={'200': 24}

## Reset Check
- initial=[200, 200, 429] after_wait=200

## Findings
- All thresholds passed.