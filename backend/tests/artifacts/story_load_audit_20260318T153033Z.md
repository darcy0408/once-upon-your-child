# Story Load Audit

- Generated (UTC): `2026-03-18T15:30:31.632823+00:00`
- Target endpoint: `/generate-story`

## Scenarios
### sync_fast_path
- Requests: `24`
- Concurrency: `6`
- Status counts: `{'401': 24}`
- Errors: `24`
- Latency ms: `{'min': 0.7, 'p50': 0.83, 'p95': 37.24, 'p99': 38.1, 'max': 38.21, 'mean': 8.29}`
- Sample errors: `[{'status_code': 401, 'error': 'Authentication required', 'message': None}, {'status_code': 401, 'error': 'Authentication required', 'message': None}, {'status_code': 401, 'error': 'Authentication required', 'message': None}, {'status_code': 401, 'error': 'Authentication required', 'message': None}, {'status_code': 401, 'error': 'Authentication required', 'message': None}]`

### timeout_async_fallback
- Requests: `16`
- Concurrency: `4`
- Status counts: `{'401': 16}`
- Errors: `16`
- Latency ms: `{'min': 0.81, 'p50': 1.06, 'p95': 1.8, 'p99': 1.87, 'max': 1.89, 'mean': 1.13}`
- Sample errors: `[{'status_code': 401, 'error': 'Authentication required', 'message': None}, {'status_code': 401, 'error': 'Authentication required', 'message': None}, {'status_code': 401, 'error': 'Authentication required', 'message': None}, {'status_code': 401, 'error': 'Authentication required', 'message': None}, {'status_code': 401, 'error': 'Authentication required', 'message': None}]`

### quota_error_429
- Requests: `12`
- Concurrency: `4`
- Status counts: `{'401': 12}`
- Errors: `12`
- Latency ms: `{'min': 0.79, 'p50': 1.05, 'p95': 1.7, 'p99': 1.76, 'max': 1.78, 'mean': 1.13}`
- Sample errors: `[{'status_code': 401, 'error': 'Authentication required', 'message': None}, {'status_code': 401, 'error': 'Authentication required', 'message': None}, {'status_code': 401, 'error': 'Authentication required', 'message': None}, {'status_code': 401, 'error': 'Authentication required', 'message': None}, {'status_code': 401, 'error': 'Authentication required', 'message': None}]`

### concurrency_ramp_c1
- Requests: `24`
- Concurrency: `1`
- Status counts: `{'401': 24}`
- Errors: `24`
- Latency ms: `{'min': 0.71, 'p50': 0.86, 'p95': 1.38, 'p99': 1.88, 'max': 2.03, 'mean': 0.93}`
- Sample errors: `[{'status_code': 401, 'error': 'Authentication required', 'message': None}, {'status_code': 401, 'error': 'Authentication required', 'message': None}, {'status_code': 401, 'error': 'Authentication required', 'message': None}, {'status_code': 401, 'error': 'Authentication required', 'message': None}, {'status_code': 401, 'error': 'Authentication required', 'message': None}]`

### concurrency_ramp_c4
- Requests: `24`
- Concurrency: `4`
- Status counts: `{'401': 24}`
- Errors: `24`
- Latency ms: `{'min': 0.74, 'p50': 0.9, 'p95': 1.25, 'p99': 1.78, 'max': 1.93, 'mean': 0.95}`
- Sample errors: `[{'status_code': 401, 'error': 'Authentication required', 'message': None}, {'status_code': 401, 'error': 'Authentication required', 'message': None}, {'status_code': 401, 'error': 'Authentication required', 'message': None}, {'status_code': 401, 'error': 'Authentication required', 'message': None}, {'status_code': 401, 'error': 'Authentication required', 'message': None}]`

### concurrency_ramp_c8
- Requests: `24`
- Concurrency: `8`
- Status counts: `{'401': 24}`
- Errors: `24`
- Latency ms: `{'min': 0.84, 'p50': 0.97, 'p95': 1.76, 'p99': 1.84, 'max': 1.84, 'mean': 1.07}`
- Sample errors: `[{'status_code': 401, 'error': 'Authentication required', 'message': None}, {'status_code': 401, 'error': 'Authentication required', 'message': None}, {'status_code': 401, 'error': 'Authentication required', 'message': None}, {'status_code': 401, 'error': 'Authentication required', 'message': None}, {'status_code': 401, 'error': 'Authentication required', 'message': None}]`

### concurrency_ramp_c16
- Requests: `24`
- Concurrency: `16`
- Status counts: `{'401': 24}`
- Errors: `24`
- Latency ms: `{'min': 0.8, 'p50': 1.01, 'p95': 2.26, 'p99': 3.14, 'max': 3.38, 'mean': 1.26}`
- Sample errors: `[{'status_code': 401, 'error': 'Authentication required', 'message': None}, {'status_code': 401, 'error': 'Authentication required', 'message': None}, {'status_code': 401, 'error': 'Authentication required', 'message': None}, {'status_code': 401, 'error': 'Authentication required', 'message': None}, {'status_code': 401, 'error': 'Authentication required', 'message': None}]`

### concurrency_ramp_c32
- Requests: `24`
- Concurrency: `32`
- Status counts: `{'401': 24}`
- Errors: `24`
- Latency ms: `{'min': 0.74, 'p50': 0.95, 'p95': 1.68, 'p99': 2.05, 'max': 2.16, 'mean': 1.08}`
- Sample errors: `[{'status_code': 401, 'error': 'Authentication required', 'message': None}, {'status_code': 401, 'error': 'Authentication required', 'message': None}, {'status_code': 401, 'error': 'Authentication required', 'message': None}, {'status_code': 401, 'error': 'Authentication required', 'message': None}, {'status_code': 401, 'error': 'Authentication required', 'message': None}]`

## Concurrency Ramp

| concurrency | p95_ms | mean_ms | errors |
| --- | ---: | ---: | ---: |
| 1 | 1.38 | 0.93 | 24 |
| 4 | 1.25 | 0.95 | 24 |
| 8 | 1.76 | 1.07 | 24 |
| 16 | 2.26 | 1.26 | 24 |
| 32 | 1.68 | 1.08 | 24 |

## Fallback Switchover
- `fallback_switchover: total=2ms provider_sequence=unknown`

## Reset Check
- Initial statuses: `[200, 200, 429]`
- After wait status: `200`
- First response headers: `{'X-RateLimit-Limit': '2', 'X-RateLimit-Remaining': '1', 'X-RateLimit-Reset': '1773847834'}`
