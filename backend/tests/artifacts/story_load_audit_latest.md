# Story Load Audit

- Generated (UTC): `2026-04-19T20:58:42.179821+00:00`
- Target endpoint: `/generate-story`

## Scenarios
### sync_fast_path
- Requests: `24`
- Concurrency: `6`
- Status counts: `{'200': 24}`
- Errors: `0`
- Latency ms: `{'min': 182.25, 'p50': 185.5, 'p95': 213.68, 'p99': 220.15, 'max': 221.99, 'mean': 192.49}`

### timeout_async_fallback
- Requests: `16`
- Concurrency: `4`
- Status counts: `{'202': 16}`
- Errors: `0`
- Latency ms: `{'min': 4.11, 'p50': 11.08, 'p95': 12.89, 'p99': 12.92, 'max': 12.93, 'mean': 9.75}`

### quota_error_429
- Requests: `12`
- Concurrency: `4`
- Status counts: `{'429': 12}`
- Errors: `12`
- Latency ms: `{'min': 39.74, 'p50': 58.7, 'p95': 73.71, 'p99': 77.68, 'max': 78.67, 'mean': 58.07}`
- Sample errors: `[{'status_code': 429, 'error': 'QUOTA_EXCEEDED', 'message': 'Google Gemini API quota exceeded. Please try again later.'}, {'status_code': 429, 'error': 'QUOTA_EXCEEDED', 'message': 'Google Gemini API quota exceeded. Please try again later.'}, {'status_code': 429, 'error': 'QUOTA_EXCEEDED', 'message': 'Google Gemini API quota exceeded. Please try again later.'}, {'status_code': 429, 'error': 'QUOTA_EXCEEDED', 'message': 'Google Gemini API quota exceeded. Please try again later.'}, {'status_code': 429, 'error': 'QUOTA_EXCEEDED', 'message': 'Google Gemini API quota exceeded. Please try again later.'}]`

### real_provider_baseline
- Requests: `5`
- Concurrency: `1`
- Status counts: `{'200': 5}`
- Errors: `0`
- Latency ms: `{'min': 19130.6, 'p50': 20225.72, 'p95': 42355.73, 'p99': 42409.39, 'max': 42422.81, 'mean': 28705.37}`
- Providers: `{'gemini': 5}`
- Perf ms: `{'prompt_build_ms': {'min': 0.0, 'p50': 0.0, 'p95': 0.0, 'p99': 0.0, 'max': 0.0, 'mean': 0.0}, 'ai_call_ms': {'min': 18802.0, 'p50': 19725.0, 'p95': 35230.8, 'p99': 38301.28, 'max': 39068.9, 'mean': 23359.46}, 'validation_ms': {'min': 0.6, 'p50': 2.3, 'p95': 5.14, 'p99': 5.51, 'max': 5.6, 'mean': 2.6}, 'total_ms': {'min': 18998.6, 'p50': 20065.2, 'p95': 42008.1, 'p99': 42235.06, 'max': 42291.8, 'mean': 28347.26}}`

### concurrency_ramp_c1
- Requests: `24`
- Concurrency: `1`
- Status counts: `{'200': 24}`
- Errors: `0`
- Latency ms: `{'min': 181.82, 'p50': 183.44, 'p95': 184.52, 'p99': 184.76, 'max': 184.83, 'mean': 183.37}`

### concurrency_ramp_c4
- Requests: `24`
- Concurrency: `4`
- Status counts: `{'200': 24}`
- Errors: `0`
- Latency ms: `{'min': 181.6, 'p50': 182.95, 'p95': 185.17, 'p99': 190.87, 'max': 192.57, 'mean': 183.41}`

### concurrency_ramp_c8
- Requests: `24`
- Concurrency: `8`
- Status counts: `{'200': 24}`
- Errors: `0`
- Latency ms: `{'min': 181.97, 'p50': 184.67, 'p95': 194.21, 'p99': 196.71, 'max': 197.44, 'mean': 186.43}`

### concurrency_ramp_c16
- Requests: `24`
- Concurrency: `16`
- Status counts: `{'200': 24}`
- Errors: `0`
- Latency ms: `{'min': 181.92, 'p50': 186.1, 'p95': 196.17, 'p99': 196.91, 'max': 197.06, 'mean': 187.41}`

### concurrency_ramp_c32
- Requests: `24`
- Concurrency: `32`
- Status counts: `{'200': 24}`
- Errors: `0`
- Latency ms: `{'min': 182.09, 'p50': 183.41, 'p95': 188.07, 'p99': 192.62, 'max': 193.96, 'mean': 184.44}`

## Concurrency Ramp

| concurrency | p95_ms | mean_ms | errors |
| --- | ---: | ---: | ---: |
| 1 | 184.52 | 183.37 | 0 |
| 4 | 185.17 | 183.41 | 0 |
| 8 | 194.21 | 186.43 | 0 |
| 16 | 196.17 | 187.41 | 0 |
| 32 | 188.07 | 184.44 | 0 |

## Fallback Switchover
- `fallback_switchover: total=181ms provider_sequence=gemini(fail:401)->openrouter(fail:no_key)->static`

## Reset Check
- Initial statuses: `[200, 200, 429]`
- After wait status: `200`
- First response headers: `{'X-RateLimit-Limit': '2', 'X-RateLimit-Remaining': '1', 'X-RateLimit-Reset': '1776632476'}`
