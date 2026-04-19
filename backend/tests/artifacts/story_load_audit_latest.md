# Story Load Audit

- Generated (UTC): `2026-04-19T17:14:12.779652+00:00`
- Target endpoint: `/generate-story`

## Scenarios
### sync_fast_path
- Requests: `24`
- Concurrency: `6`
- Status counts: `{'200': 24}`
- Errors: `0`
- Latency ms: `{'min': 181.88, 'p50': 182.79, 'p95': 213.73, 'p99': 214.53, 'max': 214.67, 'mean': 189.48}`

### timeout_async_fallback
- Requests: `16`
- Concurrency: `4`
- Status counts: `{'202': 16}`
- Errors: `0`
- Latency ms: `{'min': 1.2, 'p50': 6.27, 'p95': 9.31, 'p99': 9.74, 'max': 9.85, 'mean': 5.83}`

### quota_error_429
- Requests: `12`
- Concurrency: `4`
- Status counts: `{'429': 12}`
- Errors: `12`
- Latency ms: `{'min': 29.96, 'p50': 40.18, 'p95': 60.17, 'p99': 62.01, 'max': 62.48, 'mean': 44.21}`
- Sample errors: `[{'status_code': 429, 'error': 'QUOTA_EXCEEDED', 'message': 'Google Gemini API quota exceeded. Please try again later.'}, {'status_code': 429, 'error': 'QUOTA_EXCEEDED', 'message': 'Google Gemini API quota exceeded. Please try again later.'}, {'status_code': 429, 'error': 'QUOTA_EXCEEDED', 'message': 'Google Gemini API quota exceeded. Please try again later.'}, {'status_code': 429, 'error': 'QUOTA_EXCEEDED', 'message': 'Google Gemini API quota exceeded. Please try again later.'}, {'status_code': 429, 'error': 'QUOTA_EXCEEDED', 'message': 'Google Gemini API quota exceeded. Please try again later.'}]`

### real_provider_baseline
- Requests: `5`
- Concurrency: `1`
- Status counts: `{'200': 5}`
- Errors: `0`
- Latency ms: `{'min': 21998.95, 'p50': 42453.69, 'p95': 44928.72, 'p99': 45111.22, 'max': 45156.84, 'mean': 35431.68}`
- Providers: `{'gemini': 5}`
- Perf ms: `{'prompt_build_ms': {'min': 0.0, 'p50': 0.0, 'p95': 0.0, 'p99': 0.0, 'max': 0.0, 'mean': 0.0}, 'ai_call_ms': {'min': 19994.0, 'p50': 25560.0, 'p95': 40332.4, 'p99': 42980.08, 'max': 43642.0, 'mean': 27897.2}, 'validation_ms': {'min': 1.0, 'p50': 3.0, 'p95': 4.0, 'p99': 4.0, 'max': 4.0, 'mean': 2.8}, 'total_ms': {'min': 21149.0, 'p50': 42293.0, 'p95': 44726.2, 'p99': 44900.44, 'max': 44944.0, 'mean': 35121.6}}`

### concurrency_ramp_c1
- Requests: `24`
- Concurrency: `1`
- Status counts: `{'200': 24}`
- Errors: `0`
- Latency ms: `{'min': 182.58, 'p50': 183.41, 'p95': 185.97, 'p99': 187.14, 'max': 187.49, 'mean': 183.99}`

### concurrency_ramp_c4
- Requests: `24`
- Concurrency: `4`
- Status counts: `{'200': 24}`
- Errors: `0`
- Latency ms: `{'min': 182.45, 'p50': 183.84, 'p95': 190.1, 'p99': 193.0, 'max': 193.75, 'mean': 184.7}`

### concurrency_ramp_c8
- Requests: `24`
- Concurrency: `8`
- Status counts: `{'200': 24}`
- Errors: `0`
- Latency ms: `{'min': 181.85, 'p50': 183.53, 'p95': 189.86, 'p99': 190.3, 'max': 190.3, 'mean': 184.31}`

### concurrency_ramp_c16
- Requests: `24`
- Concurrency: `16`
- Status counts: `{'200': 24}`
- Errors: `0`
- Latency ms: `{'min': 182.0, 'p50': 187.5, 'p95': 197.91, 'p99': 202.11, 'max': 203.35, 'mean': 188.67}`

### concurrency_ramp_c32
- Requests: `24`
- Concurrency: `32`
- Status counts: `{'200': 24}`
- Errors: `0`
- Latency ms: `{'min': 183.28, 'p50': 187.72, 'p95': 203.16, 'p99': 209.11, 'max': 210.79, 'mean': 190.21}`

## Concurrency Ramp

| concurrency | p95_ms | mean_ms | errors |
| --- | ---: | ---: | ---: |
| 1 | 185.97 | 183.99 | 0 |
| 4 | 190.1 | 184.7 | 0 |
| 8 | 189.86 | 184.31 | 0 |
| 16 | 197.91 | 188.67 | 0 |
| 32 | 203.16 | 190.21 | 0 |

## Fallback Switchover
- `fallback_switchover: total=154ms provider_sequence=gemini(fail:401)->openrouter(fail:no_key)->static`

## Reset Check
- Initial statuses: `[200, 200, 429]`
- After wait status: `200`
- First response headers: `{'X-RateLimit-Limit': '2', 'X-RateLimit-Remaining': '1', 'X-RateLimit-Reset': '1776619040'}`
