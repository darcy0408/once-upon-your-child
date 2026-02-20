# Story Load Audit

- Generated (UTC): `2026-02-20T18:05:52.189474+00:00`
- Target endpoint: `/generate-story`

## Scenarios
### sync_fast_path
- Requests: `24`
- Concurrency: `6`
- Status counts: `{'200': 24}`
- Latency ms: `{'min': 182.02, 'p50': 188.71, 'p95': 209.81, 'p99': 210.89, 'max': 211.13, 'mean': 191.83}`

### timeout_async_fallback
- Requests: `16`
- Concurrency: `4`
- Status counts: `{'202': 16}`
- Latency ms: `{'min': 7.34, 'p50': 10.66, 'p95': 12.74, 'p99': 13.21, 'max': 13.33, 'mean': 10.59}`

### quota_error_429
- Requests: `12`
- Concurrency: `4`
- Status counts: `{'429': 12}`
- Latency ms: `{'min': 30.04, 'p50': 48.12, 'p95': 58.55, 'p99': 64.05, 'max': 65.43, 'mean': 46.61}`
- Sample errors: `[{'status_code': 429, 'error': 'QUOTA_EXCEEDED', 'message': 'Google Geminin API quota exceeded. Please try again later.'}, {'status_code': 429, 'error': 'QUOTA_EXCEEDED', 'message': 'Google Geminin API quota exceeded. Please try again later.'}, {'status_code': 429, 'error': 'QUOTA_EXCEEDED', 'message': 'Google Geminin API quota exceeded. Please try again later.'}, {'status_code': 429, 'error': 'QUOTA_EXCEEDED', 'message': 'Google Geminin API quota exceeded. Please try again later.'}, {'status_code': 429, 'error': 'QUOTA_EXCEEDED', 'message': 'Google Geminin API quota exceeded. Please try again later.'}]`

## Reset Check
- Initial statuses: `[200, 200, 200]`
- After wait status: `200`
- First response headers: `{'X-RateLimit-Limit': None, 'X-RateLimit-Remaining': None, 'X-RateLimit-Reset': None}`
