# Story Load Audit

- Generated (UTC): `2026-03-18T15:37:50.587498+00:00`
- Target endpoint: `/generate-story`

## Scenarios
### sync_fast_path
- Requests: `24`
- Concurrency: `6`
- Status counts: `{'200': 24}`
- Errors: `0`
- Latency ms: `{'min': 183.42, 'p50': 186.46, 'p95': 230.47, 'p99': 232.29, 'max': 232.75, 'mean': 196.07}`

### timeout_async_fallback
- Requests: `16`
- Concurrency: `4`
- Status counts: `{'202': 16}`
- Errors: `0`
- Latency ms: `{'min': 8.49, 'p50': 19.38, 'p95': 25.11, 'p99': 25.23, 'max': 25.26, 'mean': 19.54}`

### quota_error_429
- Requests: `12`
- Concurrency: `4`
- Status counts: `{'429': 12}`
- Errors: `12`
- Latency ms: `{'min': 67.31, 'p50': 135.12, 'p95': 218.33, 'p99': 221.54, 'max': 222.34, 'mean': 141.16}`
- Sample errors: `[{'status_code': 429, 'error': 'QUOTA_EXCEEDED', 'message': 'Google Geminin API quota exceeded. Please try again later.'}, {'status_code': 429, 'error': 'QUOTA_EXCEEDED', 'message': 'Google Geminin API quota exceeded. Please try again later.'}, {'status_code': 429, 'error': 'QUOTA_EXCEEDED', 'message': 'Google Geminin API quota exceeded. Please try again later.'}, {'status_code': 429, 'error': 'QUOTA_EXCEEDED', 'message': 'Google Geminin API quota exceeded. Please try again later.'}, {'status_code': 429, 'error': 'QUOTA_EXCEEDED', 'message': 'Google Geminin API quota exceeded. Please try again later.'}]`

### concurrency_ramp_c1
- Requests: `24`
- Concurrency: `1`
- Status counts: `{'200': 24}`
- Errors: `0`
- Latency ms: `{'min': 181.57, 'p50': 182.33, 'p95': 183.66, 'p99': 183.8, 'max': 183.84, 'mean': 182.42}`

### concurrency_ramp_c4
- Requests: `24`
- Concurrency: `4`
- Status counts: `{'200': 24}`
- Errors: `0`
- Latency ms: `{'min': 181.27, 'p50': 182.06, 'p95': 183.96, 'p99': 184.52, 'max': 184.68, 'mean': 182.26}`

### concurrency_ramp_c8
- Requests: `24`
- Concurrency: `8`
- Status counts: `{'200': 24}`
- Errors: `0`
- Latency ms: `{'min': 181.59, 'p50': 182.98, 'p95': 186.24, 'p99': 188.58, 'max': 189.24, 'mean': 183.45}`

### concurrency_ramp_c16
- Requests: `24`
- Concurrency: `16`
- Status counts: `{'200': 24}`
- Errors: `0`
- Latency ms: `{'min': 181.72, 'p50': 182.57, 'p95': 183.43, 'p99': 183.48, 'max': 183.49, 'mean': 182.5}`

### concurrency_ramp_c32
- Requests: `24`
- Concurrency: `32`
- Status counts: `{'200': 24}`
- Errors: `0`
- Latency ms: `{'min': 181.72, 'p50': 183.11, 'p95': 185.32, 'p99': 186.26, 'max': 186.54, 'mean': 183.42}`

## Concurrency Ramp

| concurrency | p95_ms | mean_ms | errors |
| --- | ---: | ---: | ---: |
| 1 | 183.66 | 182.42 | 0 |
| 4 | 183.96 | 182.26 | 0 |
| 8 | 186.24 | 183.45 | 0 |
| 16 | 183.43 | 182.5 | 0 |
| 32 | 185.32 | 183.42 | 0 |

## Fallback Switchover
- `fallback_switchover: total=4573ms provider_sequence=gemini(fail:401)->openrouter(fail:no_key)->static`

## Reset Check
- Initial statuses: `[200, 200, 429]`
- After wait status: `200`
- First response headers: `{'X-RateLimit-Limit': '2', 'X-RateLimit-Remaining': '1', 'X-RateLimit-Reset': '1773848285'}`
