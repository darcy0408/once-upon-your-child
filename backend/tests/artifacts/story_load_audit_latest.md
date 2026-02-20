# Story Load Audit

- Generated (UTC): `2026-02-17T22:23:39.308519+00:00`
- Target endpoint: `/generate-story`

## Scenarios
### sync_fast_path
- Requests: `24`
- Concurrency: `6`
- Status counts: `{'200': 24}`
- Latency ms: `{'min': 183.82, 'p50': 199.66, 'p95': 225.93, 'p99': 230.45, 'max': 231.8, 'mean': 201.11}`

### timeout_async_fallback
- Requests: `16`
- Concurrency: `4`
- Status counts: `{'202': 16}`
- Latency ms: `{'min': 11.59, 'p50': 28.31, 'p95': 34.05, 'p99': 35.01, 'max': 35.25, 'mean': 26.56}`

### quota_error_429
- Requests: `12`
- Concurrency: `4`
- Status counts: `{'429': 12}`
- Latency ms: `{'min': 43.85, 'p50': 67.04, 'p95': 88.7, 'p99': 99.7, 'max': 102.45, 'mean': 66.48}`
- Sample errors: `[{'status_code': 429, 'error': 'QUOTA_EXCEEDED', 'message': 'Google Geminin API quota exceeded. Please try again later.'}, {'status_code': 429, 'error': 'QUOTA_EXCEEDED', 'message': 'Google Geminin API quota exceeded. Please try again later.'}, {'status_code': 429, 'error': 'QUOTA_EXCEEDED', 'message': 'Google Geminin API quota exceeded. Please try again later.'}, {'status_code': 429, 'error': 'QUOTA_EXCEEDED', 'message': 'Google Geminin API quota exceeded. Please try again later.'}, {'status_code': 429, 'error': 'QUOTA_EXCEEDED', 'message': 'Google Geminin API quota exceeded. Please try again later.'}]`

## Reset Check
- Initial statuses: `[200, 200, 429]`
- After wait status: `200`
- First response headers: `{'X-RateLimit-Limit': None, 'X-RateLimit-Remaining': None, 'X-RateLimit-Reset': None}`
