# Story Load Audit

- Generated (UTC): `2026-02-20T18:06:20.591797+00:00`
- Target endpoint: `/generate-story`

## Scenarios
### sync_fast_path
- Requests: `24`
- Concurrency: `6`
- Status counts: `{'200': 24}`
- Latency ms: `{'min': 181.51, 'p50': 188.37, 'p95': 200.76, 'p99': 203.01, 'max': 203.68, 'mean': 189.57}`

### timeout_async_fallback
- Requests: `16`
- Concurrency: `4`
- Status counts: `{'202': 16}`
- Latency ms: `{'min': 5.74, 'p50': 8.22, 'p95': 9.42, 'p99': 9.57, 'max': 9.61, 'mean': 8.14}`

### quota_error_429
- Requests: `12`
- Concurrency: `4`
- Status counts: `{'429': 12}`
- Latency ms: `{'min': 29.41, 'p50': 44.45, 'p95': 57.8, 'p99': 57.97, 'max': 58.01, 'mean': 44.72}`
- Sample errors: `[{'status_code': 429, 'error': 'QUOTA_EXCEEDED', 'message': 'Google Geminin API quota exceeded. Please try again later.'}, {'status_code': 429, 'error': 'QUOTA_EXCEEDED', 'message': 'Google Geminin API quota exceeded. Please try again later.'}, {'status_code': 429, 'error': 'QUOTA_EXCEEDED', 'message': 'Google Geminin API quota exceeded. Please try again later.'}, {'status_code': 429, 'error': 'QUOTA_EXCEEDED', 'message': 'Google Geminin API quota exceeded. Please try again later.'}, {'status_code': 429, 'error': 'QUOTA_EXCEEDED', 'message': 'Google Geminin API quota exceeded. Please try again later.'}]`

## Reset Check
- Initial statuses: `[200, 200, 200]`
- After wait status: `200`
- First response headers: `{'X-RateLimit-Limit': None, 'X-RateLimit-Remaining': None, 'X-RateLimit-Reset': None}`
