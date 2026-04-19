# Story Load Audit

- Generated (UTC): `2026-04-19T17:10:57.402788+00:00`
- Target endpoint: `/generate-story`

## Scenarios
### sync_fast_path
- Requests: `24`
- Concurrency: `6`
- Status counts: `{'200': 24}`
- Errors: `0`
- Latency ms: `{'min': 181.73, 'p50': 183.93, 'p95': 231.95, 'p99': 234.75, 'max': 235.5, 'mean': 194.99}`

### timeout_async_fallback
- Requests: `16`
- Concurrency: `4`
- Status counts: `{'202': 16}`
- Errors: `0`
- Latency ms: `{'min': 2.02, 'p50': 5.76, 'p95': 11.25, 'p99': 12.76, 'max': 13.14, 'mean': 6.2}`

### quota_error_429
- Requests: `12`
- Concurrency: `4`
- Status counts: `{'429': 12}`
- Errors: `12`
- Latency ms: `{'min': 37.9, 'p50': 62.02, 'p95': 78.83, 'p99': 84.48, 'max': 85.89, 'mean': 60.08}`
- Sample errors: `[{'status_code': 429, 'error': 'QUOTA_EXCEEDED', 'message': 'Google Gemini API quota exceeded. Please try again later.'}, {'status_code': 429, 'error': 'QUOTA_EXCEEDED', 'message': 'Google Gemini API quota exceeded. Please try again later.'}, {'status_code': 429, 'error': 'QUOTA_EXCEEDED', 'message': 'Google Gemini API quota exceeded. Please try again later.'}, {'status_code': 429, 'error': 'QUOTA_EXCEEDED', 'message': 'Google Gemini API quota exceeded. Please try again later.'}, {'status_code': 429, 'error': 'QUOTA_EXCEEDED', 'message': 'Google Gemini API quota exceeded. Please try again later.'}]`

### concurrency_ramp_c1
- Requests: `24`
- Concurrency: `1`
- Status counts: `{'200': 24}`
- Errors: `0`
- Latency ms: `{'min': 182.32, 'p50': 182.98, 'p95': 183.95, 'p99': 184.25, 'max': 184.33, 'mean': 183.11}`

### concurrency_ramp_c4
- Requests: `24`
- Concurrency: `4`
- Status counts: `{'200': 24}`
- Errors: `0`
- Latency ms: `{'min': 182.06, 'p50': 182.83, 'p95': 186.09, 'p99': 186.91, 'max': 187.09, 'mean': 183.2}`

### concurrency_ramp_c8
- Requests: `24`
- Concurrency: `8`
- Status counts: `{'200': 24}`
- Errors: `0`
- Latency ms: `{'min': 181.83, 'p50': 182.79, 'p95': 188.14, 'p99': 192.31, 'max': 193.48, 'mean': 184.05}`

### concurrency_ramp_c16
- Requests: `24`
- Concurrency: `16`
- Status counts: `{'200': 24}`
- Errors: `0`
- Latency ms: `{'min': 181.93, 'p50': 183.87, 'p95': 195.65, 'p99': 197.92, 'max': 198.55, 'mean': 186.22}`

### concurrency_ramp_c32
- Requests: `24`
- Concurrency: `32`
- Status counts: `{'200': 24}`
- Errors: `0`
- Latency ms: `{'min': 182.33, 'p50': 183.9, 'p95': 189.67, 'p99': 193.01, 'max': 193.95, 'mean': 184.62}`

## Concurrency Ramp

| concurrency | p95_ms | mean_ms | errors |
| --- | ---: | ---: | ---: |
| 1 | 183.95 | 183.11 | 0 |
| 4 | 186.09 | 183.2 | 0 |
| 8 | 188.14 | 184.05 | 0 |
| 16 | 195.65 | 186.22 | 0 |
| 32 | 189.67 | 184.62 | 0 |

## Fallback Switchover
- `fallback_switchover: total=2268ms provider_sequence=gemini(fail:401)->openrouter(fail:no_key)->static`

## Reset Check
- Initial statuses: `[200, 200, 429]`
- After wait status: `200`
- First response headers: `{'X-RateLimit-Limit': '2', 'X-RateLimit-Remaining': '1', 'X-RateLimit-Reset': '1776618669'}`
