# Story Load Audit

- Generated (UTC): `2026-03-18T15:34:53.512799+00:00`
- Target endpoint: `/generate-story`

## Scenarios
### sync_fast_path
- Requests: `24`
- Concurrency: `6`
- Status counts: `{'200': 19, '500': 4, '401': 1}`
- Errors: `5`
- Latency ms: `{'min': 55.27, 'p50': 218.99, 'p95': 450.55, 'p99': 684.79, 'max': 754.14, 'mean': 275.22}`
- Sample errors: `[{'status_code': 500, 'error': "(sqlite3.InterfaceError) bad parameter or other API misuse\n[SQL: SELECT user.id AS user_id, user.username AS user_username, user.email AS user_email, user.password_hash AS user_password_hash, user.created_at AS user_created_at, user.role AS user_role, user.subscription_tier AS user_subscription_tier, user.subscription_status AS user_subscription_status, user.current_period_end AS user_current_period_end, user.cancel_at_period_end AS user_cancel_at_period_end, user.stripe_customer_id AS user_stripe_customer_id, user.stories_created_count AS user_stories_created_count, user.gemini_api_key_encrypted AS user_gemini_api_key_encrypted, user.has_byok AS user_has_byok, user.stories_generated_this_month AS user_stories_generated_this_month, user.illustrations_generated_this_month AS user_illustrations_generated_this_month, user.usage_reset_date AS user_usage_reset_date, user.declared_age AS user_declared_age, user.is_under_13 AS user_is_under_13 \nFROM user \nWHERE user.id = ?]\n[parameters: ('story-load-audit-user',)]\n(Background on this error at: https://sqlalche.me/e/20/rvf5)", 'message': None}, {'status_code': 500, 'error': "(sqlite3.InterfaceError) bad parameter or other API misuse\n[SQL: SELECT user.id AS user_id, user.username AS user_username, user.email AS user_email, user.password_hash AS user_password_hash, user.created_at AS user_created_at, user.role AS user_role, user.subscription_tier AS user_subscription_tier, user.subscription_status AS user_subscription_status, user.current_period_end AS user_current_period_end, user.cancel_at_period_end AS user_cancel_at_period_end, user.stripe_customer_id AS user_stripe_customer_id, user.stories_created_count AS user_stories_created_count, user.gemini_api_key_encrypted AS user_gemini_api_key_encrypted, user.has_byok AS user_has_byok, user.stories_generated_this_month AS user_stories_generated_this_month, user.illustrations_generated_this_month AS user_illustrations_generated_this_month, user.usage_reset_date AS user_usage_reset_date, user.declared_age AS user_declared_age, user.is_under_13 AS user_is_under_13 \nFROM user \nWHERE user.id = ?]\n[parameters: ('story-load-audit-user',)]\n(Background on this error at: https://sqlalche.me/e/20/rvf5)", 'message': None}, {'status_code': 500, 'error': "(sqlite3.InterfaceError) bad parameter or other API misuse\n[SQL: SELECT user.id AS user_id, user.username AS user_username, user.email AS user_email, user.password_hash AS user_password_hash, user.created_at AS user_created_at, user.role AS user_role, user.subscription_tier AS user_subscription_tier, user.subscription_status AS user_subscription_status, user.current_period_end AS user_current_period_end, user.cancel_at_period_end AS user_cancel_at_period_end, user.stripe_customer_id AS user_stripe_customer_id, user.stories_created_count AS user_stories_created_count, user.gemini_api_key_encrypted AS user_gemini_api_key_encrypted, user.has_byok AS user_has_byok, user.stories_generated_this_month AS user_stories_generated_this_month, user.illustrations_generated_this_month AS user_illustrations_generated_this_month, user.usage_reset_date AS user_usage_reset_date, user.declared_age AS user_declared_age, user.is_under_13 AS user_is_under_13 \nFROM user \nWHERE user.id = ?]\n[parameters: ('story-load-audit-user',)]\n(Background on this error at: https://sqlalche.me/e/20/rvf5)", 'message': None}, {'status_code': 401, 'error': 'User not found', 'message': None}, {'status_code': 500, 'error': "(sqlite3.InterfaceError) bad parameter or other API misuse\n[SQL: SELECT user.id AS user_id, user.username AS user_username, user.email AS user_email, user.password_hash AS user_password_hash, user.created_at AS user_created_at, user.role AS user_role, user.subscription_tier AS user_subscription_tier, user.subscription_status AS user_subscription_status, user.current_period_end AS user_current_period_end, user.cancel_at_period_end AS user_cancel_at_period_end, user.stripe_customer_id AS user_stripe_customer_id, user.stories_created_count AS user_stories_created_count, user.gemini_api_key_encrypted AS user_gemini_api_key_encrypted, user.has_byok AS user_has_byok, user.stories_generated_this_month AS user_stories_generated_this_month, user.illustrations_generated_this_month AS user_illustrations_generated_this_month, user.usage_reset_date AS user_usage_reset_date, user.declared_age AS user_declared_age, user.is_under_13 AS user_is_under_13 \nFROM user \nWHERE user.id = ?]\n[parameters: ('story-load-audit-user',)]\n(Background on this error at: https://sqlalche.me/e/20/rvf5)", 'message': None}]`

### timeout_async_fallback
- Requests: `16`
- Concurrency: `4`
- Status counts: `{'202': 12, '401': 3, '500': 1}`
- Errors: `4`
- Latency ms: `{'min': 34.96, 'p50': 46.84, 'p95': 100.14, 'p99': 102.44, 'max': 103.02, 'mean': 57.89}`
- Sample errors: `[{'status_code': 401, 'error': 'User not found', 'message': None}, {'status_code': 401, 'error': 'User not found', 'message': None}, {'status_code': 401, 'error': 'User not found', 'message': None}, {'status_code': 500, 'error': "(sqlite3.InterfaceError) bad parameter or other API misuse\n[SQL: SELECT user.id AS user_id, user.username AS user_username, user.email AS user_email, user.password_hash AS user_password_hash, user.created_at AS user_created_at, user.role AS user_role, user.subscription_tier AS user_subscription_tier, user.subscription_status AS user_subscription_status, user.current_period_end AS user_current_period_end, user.cancel_at_period_end AS user_cancel_at_period_end, user.stripe_customer_id AS user_stripe_customer_id, user.stories_created_count AS user_stories_created_count, user.gemini_api_key_encrypted AS user_gemini_api_key_encrypted, user.has_byok AS user_has_byok, user.stories_generated_this_month AS user_stories_generated_this_month, user.illustrations_generated_this_month AS user_illustrations_generated_this_month, user.usage_reset_date AS user_usage_reset_date, user.declared_age AS user_declared_age, user.is_under_13 AS user_is_under_13 \nFROM user \nWHERE user.id = ?]\n[parameters: ('story-load-audit-user',)]\n(Background on this error at: https://sqlalche.me/e/20/rvf5)", 'message': None}]`

### quota_error_429
- Requests: `12`
- Concurrency: `4`
- Status counts: `{'401': 2, '429': 8, '500': 2}`
- Errors: `12`
- Latency ms: `{'min': 9.54, 'p50': 175.96, 'p95': 266.95, 'p99': 322.42, 'max': 336.28, 'mean': 163.78}`
- Sample errors: `[{'status_code': 401, 'error': 'User not found', 'message': None}, {'status_code': 429, 'error': 'QUOTA_EXCEEDED', 'message': 'Google Geminin API quota exceeded. Please try again later.'}, {'status_code': 429, 'error': 'QUOTA_EXCEEDED', 'message': 'Google Geminin API quota exceeded. Please try again later.'}, {'status_code': 429, 'error': 'QUOTA_EXCEEDED', 'message': 'Google Geminin API quota exceeded. Please try again later.'}, {'status_code': 429, 'error': 'QUOTA_EXCEEDED', 'message': 'Google Geminin API quota exceeded. Please try again later.'}]`

### concurrency_ramp_c1
- Requests: `24`
- Concurrency: `1`
- Status counts: `{'200': 24}`
- Errors: `0`
- Latency ms: `{'min': 189.28, 'p50': 199.05, 'p95': 231.29, 'p99': 237.04, 'max': 238.57, 'mean': 205.23}`

### concurrency_ramp_c4
- Requests: `24`
- Concurrency: `4`
- Status counts: `{'200': 18, '500': 3, '401': 3}`
- Errors: `6`
- Latency ms: `{'min': 11.65, 'p50': 199.64, 'p95': 226.94, 'p99': 233.71, 'max': 235.71, 'mean': 171.99}`
- Sample errors: `[{'status_code': 500, 'error': "(sqlite3.InterfaceError) bad parameter or other API misuse\n[SQL: SELECT user.id AS user_id, user.username AS user_username, user.email AS user_email, user.password_hash AS user_password_hash, user.created_at AS user_created_at, user.role AS user_role, user.subscription_tier AS user_subscription_tier, user.subscription_status AS user_subscription_status, user.current_period_end AS user_current_period_end, user.cancel_at_period_end AS user_cancel_at_period_end, user.stripe_customer_id AS user_stripe_customer_id, user.stories_created_count AS user_stories_created_count, user.gemini_api_key_encrypted AS user_gemini_api_key_encrypted, user.has_byok AS user_has_byok, user.stories_generated_this_month AS user_stories_generated_this_month, user.illustrations_generated_this_month AS user_illustrations_generated_this_month, user.usage_reset_date AS user_usage_reset_date, user.declared_age AS user_declared_age, user.is_under_13 AS user_is_under_13 \nFROM user \nWHERE user.id = ?]\n[parameters: ('story-load-audit-user',)]\n(Background on this error at: https://sqlalche.me/e/20/rvf5)", 'message': None}, {'status_code': 401, 'error': 'User not found', 'message': None}, {'status_code': 401, 'error': 'User not found', 'message': None}, {'status_code': 500, 'error': "(sqlite3.InterfaceError) bad parameter or other API misuse\n[SQL: SELECT user.id AS user_id, user.username AS user_username, user.email AS user_email, user.password_hash AS user_password_hash, user.created_at AS user_created_at, user.role AS user_role, user.subscription_tier AS user_subscription_tier, user.subscription_status AS user_subscription_status, user.current_period_end AS user_current_period_end, user.cancel_at_period_end AS user_cancel_at_period_end, user.stripe_customer_id AS user_stripe_customer_id, user.stories_created_count AS user_stories_created_count, user.gemini_api_key_encrypted AS user_gemini_api_key_encrypted, user.has_byok AS user_has_byok, user.stories_generated_this_month AS user_stories_generated_this_month, user.illustrations_generated_this_month AS user_illustrations_generated_this_month, user.usage_reset_date AS user_usage_reset_date, user.declared_age AS user_declared_age, user.is_under_13 AS user_is_under_13 \nFROM user \nWHERE user.id = ?]\n[parameters: ('story-load-audit-user',)]\n(Background on this error at: https://sqlalche.me/e/20/rvf5)", 'message': None}, {'status_code': 401, 'error': 'User not found', 'message': None}]`

### concurrency_ramp_c8
- Requests: `24`
- Concurrency: `8`
- Status counts: `{'200': 24}`
- Errors: `0`
- Latency ms: `{'min': 186.92, 'p50': 203.22, 'p95': 235.27, 'p99': 239.26, 'max': 240.32, 'mean': 208.85}`

### concurrency_ramp_c16
- Requests: `24`
- Concurrency: `16`
- Status counts: `{'401': 2, '200': 22}`
- Errors: `2`
- Latency ms: `{'min': 16.83, 'p50': 205.99, 'p95': 234.07, 'p99': 238.46, 'max': 239.55, 'mean': 193.52}`
- Sample errors: `[{'status_code': 401, 'error': 'User not found', 'message': None}, {'status_code': 401, 'error': 'User not found', 'message': None}]`

### concurrency_ramp_c32
- Requests: `24`
- Concurrency: `32`
- Status counts: `{'200': 23, '401': 1}`
- Errors: `1`
- Latency ms: `{'min': 21.74, 'p50': 203.06, 'p95': 237.96, 'p99': 241.77, 'max': 242.62, 'mean': 199.5}`
- Sample errors: `[{'status_code': 401, 'error': 'User not found', 'message': None}]`

## Concurrency Ramp

| concurrency | p95_ms | mean_ms | errors |
| --- | ---: | ---: | ---: |
| 1 | 231.29 | 205.23 | 0 |
| 4 | 226.94 | 171.99 | 6 |
| 8 | 235.27 | 208.85 | 0 |
| 16 | 234.07 | 193.52 | 2 |
| 32 | 237.96 | 199.5 | 1 |

## Fallback Switchover
- `fallback_switchover: total=37464ms provider_sequence=gemini(fail:401)->openrouter(fail:no_key)->static`

## Reset Check
- Initial statuses: `[200, 200, 429]`
- After wait status: `200`
- First response headers: `{'X-RateLimit-Limit': '2', 'X-RateLimit-Remaining': '1', 'X-RateLimit-Reset': '1773848143'}`
