# Story Load Threshold Check

- Source artifact: `2026-02-17T22:23:39.308519+00:00`
- Result: `PASS`

## Scenario Latencies
- `sync_fast_path`: p95=225.93 ms, mean=201.11 ms, status={'200': 24}
- `timeout_async_fallback`: p95=34.05 ms, mean=26.56 ms, status={'202': 16}
- `quota_error_429`: p95=88.7 ms, mean=66.48 ms, status={'429': 12}

## Reset Check
- initial=[200, 200, 429] after_wait=200

## Findings
- All thresholds passed.