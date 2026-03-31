# Story Load Audit

- Generated (UTC): `2026-03-30T13:03:57.281677+00:00`
- Target endpoint: `/generate-story`

## Scenarios
### sync_fast_path
- Requests: `24`
- Concurrency: `6`
- Status counts: `{'200': 24}`
- Errors: `0`
- Latency ms: `{'min': 181.18, 'p50': 182.4, 'p95': 207.29, 'p99': 207.53, 'max': 207.58, 'mean': 188.12}`

### timeout_async_fallback
- Requests: `16`
- Concurrency: `4`
- Status counts: `{'202': 16}`
- Errors: `0`
- Latency ms: `{'min': 2.95, 'p50': 4.16, 'p95': 6.99, 'p99': 8.1, 'max': 8.38, 'mean': 4.66}`

### quota_error_429
- Requests: `12`
- Concurrency: `4`
- Status counts: `{'429': 12}`
- Errors: `12`
- Latency ms: `{'min': 19.23, 'p50': 30.17, 'p95': 44.27, 'p99': 48.75, 'max': 49.87, 'mean': 31.69}`
- Sample errors: `[{'status_code': 429, 'error': 'QUOTA_EXCEEDED', 'message': 'Google Geminin API quota exceeded. Please try again later.'}, {'status_code': 429, 'error': 'QUOTA_EXCEEDED', 'message': 'Google Geminin API quota exceeded. Please try again later.'}, {'status_code': 429, 'error': 'QUOTA_EXCEEDED', 'message': 'Google Geminin API quota exceeded. Please try again later.'}, {'status_code': 429, 'error': 'QUOTA_EXCEEDED', 'message': 'Google Geminin API quota exceeded. Please try again later.'}, {'status_code': 429, 'error': 'QUOTA_EXCEEDED', 'message': 'Google Geminin API quota exceeded. Please try again later.'}]`

### concurrency_ramp_c1
- Requests: `24`
- Concurrency: `1`
- Status counts: `{'200': 24}`
- Errors: `0`
- Latency ms: `{'min': 181.22, 'p50': 181.66, 'p95': 182.27, 'p99': 185.54, 'max': 186.52, 'mean': 181.9}`

### concurrency_ramp_c4
- Requests: `24`
- Concurrency: `4`
- Status counts: `{'200': 24}`
- Errors: `0`
- Latency ms: `{'min': 181.15, 'p50': 181.57, 'p95': 182.27, 'p99': 182.41, 'max': 182.44, 'mean': 181.63}`

### concurrency_ramp_c8
- Requests: `24`
- Concurrency: `8`
- Status counts: `{'200': 24}`
- Errors: `0`
- Latency ms: `{'min': 180.88, 'p50': 181.85, 'p95': 182.71, 'p99': 182.76, 'max': 182.77, 'mean': 181.87}`

### concurrency_ramp_c16
- Requests: `24`
- Concurrency: `16`
- Status counts: `{'200': 24}`
- Errors: `0`
- Latency ms: `{'min': 180.84, 'p50': 181.51, 'p95': 182.21, 'p99': 182.97, 'max': 183.18, 'mean': 181.53}`

### concurrency_ramp_c32
- Requests: `24`
- Concurrency: `32`
- Status counts: `{'200': 24}`
- Errors: `0`
- Latency ms: `{'min': 181.32, 'p50': 181.86, 'p95': 182.41, 'p99': 182.55, 'max': 182.59, 'mean': 181.84}`

## Concurrency Ramp

| concurrency | p95_ms | mean_ms | errors |
| --- | ---: | ---: | ---: |
| 1 | 182.27 | 181.9 | 0 |
| 4 | 182.27 | 181.63 | 0 |
| 8 | 182.71 | 181.87 | 0 |
| 16 | 182.21 | 181.53 | 0 |
| 32 | 182.41 | 181.84 | 0 |

## Fallback Switchover
- `fallback_switchover: total=2558ms provider_sequence=gemini(fail:401)->openrouter(fail:no_key)->static`

## Reset Check
- Initial statuses: `[200, 200, 429]`
- After wait status: `200`
- First response headers: `{'X-RateLimit-Limit': '2', 'X-RateLimit-Remaining': '1', 'X-RateLimit-Reset': '1774875849'}`
