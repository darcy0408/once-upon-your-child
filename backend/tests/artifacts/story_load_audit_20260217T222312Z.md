# Story Load Audit

- Generated (UTC): `2026-02-17T22:23:09.640630+00:00`
- Target endpoint: `/generate-story`

## Scenarios
### sync_fast_path
- Requests: `24`
- Concurrency: `6`
- Status counts: `{'200': 24}`
- Latency ms: `{'min': 183.65, 'p50': 199.8, 'p95': 241.77, 'p99': 245.78, 'max': 246.77, 'mean': 204.42}`

### timeout_async_fallback
- Requests: `16`
- Concurrency: `4`
- Status counts: `{'202': 16}`
- Latency ms: `{'min': 12.52, 'p50': 27.21, 'p95': 36.95, 'p99': 36.97, 'max': 36.98, 'mean': 26.64}`

### quota_error_429
- Requests: `12`
- Concurrency: `4`
- Status counts: `{'429': 12}`
- Latency ms: `{'min': 50.55, 'p50': 67.46, 'p95': 76.1, 'p99': 76.34, 'max': 76.4, 'mean': 66.7}`
- Sample errors: `[{'status_code': 429, 'error': 'QUOTA_EXCEEDED', 'message': 'Google Geminin API quota exceeded. Please try again later.'}, {'status_code': 429, 'error': 'QUOTA_EXCEEDED', 'message': 'Google Geminin API quota exceeded. Please try again later.'}, {'status_code': 429, 'error': 'QUOTA_EXCEEDED', 'message': 'Google Geminin API quota exceeded. Please try again later.'}, {'status_code': 429, 'error': 'QUOTA_EXCEEDED', 'message': 'Google Geminin API quota exceeded. Please try again later.'}, {'status_code': 429, 'error': 'QUOTA_EXCEEDED', 'message': 'Google Geminin API quota exceeded. Please try again later.'}]`

## Reset Check
- Initial statuses: `[200, 200, 200]`
- After wait status: `200`
- First response headers: `{'X-RateLimit-Limit': None, 'X-RateLimit-Remaining': None, 'X-RateLimit-Reset': None}`
