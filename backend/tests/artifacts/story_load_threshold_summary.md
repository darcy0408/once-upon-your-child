# Story Load Threshold Check

- Source artifact: `2026-03-18T15:30:31.632823+00:00`
- Result: `FAIL`

## Scenario Latencies
- `sync_fast_path`: p95=37.24 ms, mean=8.29 ms, status={'401': 24}
- `timeout_async_fallback`: p95=1.8 ms, mean=1.13 ms, status={'401': 16}
- `quota_error_429`: p95=1.7 ms, mean=1.13 ms, status={'401': 12}
- `concurrency_ramp_c1`: p95=1.38 ms, mean=0.93 ms, status={'401': 24}
- `concurrency_ramp_c4`: p95=1.25 ms, mean=0.95 ms, status={'401': 24}
- `concurrency_ramp_c8`: p95=1.76 ms, mean=1.07 ms, status={'401': 24}
- `concurrency_ramp_c16`: p95=2.26 ms, mean=1.26 ms, status={'401': 24}
- `concurrency_ramp_c32`: p95=1.68 ms, mean=1.08 ms, status={'401': 24}

## Reset Check
- initial=[200, 200, 429] after_wait=200

## Findings
- concurrency_ramp_c16.errors=24.0 breached threshold == 0.0
- timeout_async_fallback status counts are unexpected; expected all 202 responses
- quota_error_429 status counts are unexpected; expected all 429 responses