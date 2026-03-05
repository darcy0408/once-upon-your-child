# Story Load Threshold Check

- Source artifact: `2026-02-20T18:07:03.962767+00:00`
- Result: `PASS`

## Scenario Latencies
- `sync_fast_path`: p95=210.7 ms, mean=194.42 ms, status={'200': 24}
- `timeout_async_fallback`: p95=15.3 ms, mean=10.36 ms, status={'202': 16}
- `quota_error_429`: p95=66.52 ms, mean=50.3 ms, status={'429': 12}

## Reset Check
- initial=[200, 200, 429] after_wait=200

## Findings
- All thresholds passed.