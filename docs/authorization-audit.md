# Authorization Audit

Date: 2026-03-15

## Auth model

- Protected routes primarily use the custom [`require_auth`](/C:/dev/story-weaver-app/backend/middleware/auth.py) decorator, not `flask-jwt-extended` route guards.
- `require_auth` decodes the JWT, extracts `user_id` or `sub`, loads the `User`, and attaches it to `request.current_user`.
- Ownership enforcement is done either inline with `request.current_user.id` filters or via `@require_owner('user_id')`.

## Protected endpoints

| Endpoint | Method | Result | Notes |
| --- | --- | --- | --- |
| `/achievement/sync` | `POST` | PASS | Uses current authenticated user; no resource ID parameter. |
| `/achievement/data` | `GET` | PASS | Uses current authenticated user; no resource ID parameter. |
| `/achievement/record/story` | `POST` | PASS | Uses current authenticated user; no resource ID parameter. |
| `/achievement/record/character` | `POST` | PASS | Uses current authenticated user; no resource ID parameter. |
| `/achievement/stats` | `GET` | PASS | Uses current authenticated user; no resource ID parameter. |
| `/admin/run-db-optimization` | `POST` | PASS | Admin-only; no user-owned resource ID. |
| `/admin/add-missing-columns` | `POST` | PASS | Admin-only; no user-owned resource ID. |
| `/create-character` | `POST` | PASS | Route overwrites payload `user_id` with `request.current_user.id`. |
| `/characters/<char_id>` | `GET` | PASS | Inline ownership check on `Character.user_id`. |
| `/characters/<char_id>` | `PATCH` / `PUT` | PASS | Inline ownership check on `Character.user_id`. |
| `/characters/<char_id>` | `DELETE` | PASS | Inline ownership check on `Character.user_id`. |
| `/get-characters` | `GET` | PASS | Filters by current user before fetching characters. |
| `/child-profiles/<profile_id>/parent-hidden-context` | `GET` | PASS | Filters by both `user_id` and `child_profile_id`. |
| `/child-profiles/<profile_id>/parent-hidden-context` | `PUT` | PASS | Filters by both `user_id` and `child_profile_id`; does not overwrite another user's row. |
| `/chronicle/summarize-chapter` | `POST` | PASS | Auth required; no resource ID parameter. |
| `/chronicle/compress-arc` | `POST` | PASS | Auth required; no resource ID parameter. |
| `/sync-progression` | `POST` | PASS | Uses `request.current_user`; no resource ID parameter. |
| `/get-progression` | `GET` | PASS | Uses `request.current_user`; no resource ID parameter. |
| `/generate-story` | `POST` | PASS | Uses `request.current_user.id`; validates `character_id` ownership when provided. |
| `/task-status/<task_id>` | `GET` | FIXED | Added task-owner enforcement for pending/processing states to prevent cross-user task polling. |
| `/generate-interactive-story` | `POST` | PASS | Uses `request.current_user.id`; validates `character_id` ownership when provided. |
| `/continue-interactive-story` | `POST` | PASS | Verifies `InteractiveStory.user_id` before continuing `story_id`. |
| `/interactive-story/<story_id>` | `GET` | PASS | Verifies `InteractiveStory.user_id` before returning story data. |
| `/interactive-story/<story_id>/resume` | `GET` | PASS | Verifies `InteractiveStory.user_id` before returning story state. |
| `/generate-illustrations` | `POST` | PASS | Auth required; no user-owned resource ID parameter. |
| `/generate-coloring-pages` | `POST` | PASS | Auth required; no user-owned resource ID parameter. |
| `/create-checkout-session` | `POST` | PASS | Uses authenticated user only; ignores any caller-supplied user ID. |
| `/create-portal-session` | `POST` | PASS | Uses `request.current_user`; no resource ID parameter. |
| `/api/stripe/subscription-status/<user_id>` | `GET` | PASS | Protected by `@require_owner('user_id')`. |
| `/api/user/<user_id>/subscription` | `GET` | PASS | Protected by `@require_owner('user_id')`. |
| `/therapist/clients` | `POST` | PASS | Therapist-only; writes rows with `therapist_id=request.current_user.id`. |
| `/therapist/clients` | `GET` | PASS | Therapist-only; filters by `therapist_id=request.current_user.id`. |
| `/therapist/clients/<client_id>` | `DELETE` | PASS | Filters by both `id` and `therapist_id=request.current_user.id`. |
| `/therapist/clients/<client_id>/goals` | `PUT` | PASS | Filters by both `id` and `therapist_id=request.current_user.id`. |
| `/therapist/clients/<client_id>/progress` | `GET` | PASS | Filters therapist-client link by current therapist before returning child data. |
| `/therapist/clients/<client_id>/report` | `GET` | PASS | Filters therapist-client link by current therapist before returning child data. |
| `/tts/synthesize` | `POST` | PASS | Auth required; no resource ID parameter. |
| `/tts/transcribe` | `POST` | PASS | Auth required; no resource ID parameter. |
| `/api/user/<user_id>/usage-stats` | `GET` | PASS | Protected by `@require_owner('user_id')`. |
| `/api/user/<user_id>/cancel-subscription` | `POST` | PASS | Protected by `@require_owner('user_id')`. |
| `/api/user/<user_id>/age` | `PATCH` | PASS | Protected by `@require_owner('user_id')`. |
| `/api/user/<user_id>/consent` | `POST` | PASS | Protected by `@require_owner('user_id')`. |
| `/api/user/<user_id>/data` | `DELETE` | PASS | Protected by `@require_owner('user_id')`. |
| `/api/user/<user_id>/export` | `GET` | PASS | Protected by `@require_owner('user_id')`. |
| `/quality/score-story` | `POST` | PASS | Auth required; no resource ID parameter. |
| `/debug-gemini` | `GET` | PASS | Admin-only; no user-owned resource ID. |
| `/debug-openrouter` | `GET` | PASS | Admin-only; no user-owned resource ID. |
| `/users/<user_id>/feature-unlocks` | `GET` | PASS | Protected by `@require_owner('user_id')`. |
| `/users/<user_id>/story-created` | `POST` | PASS | Protected by `@require_owner('user_id')`. |
| `/usage/summary` | `GET` | PASS | Admin-only; no user-owned resource ID. |
| `/usage/daily` | `GET` | PASS | Admin-only; no user-owned resource ID. |
| `/usage/mock-mode` | `GET` | PASS | Admin-only; no user-owned resource ID. |
| `/generate-custom-avatar` | `POST` | PASS | Auth required; no user-owned resource ID parameter. |
| `/generate-pet-avatar` | `POST` | PASS | Auth required; no user-owned resource ID parameter. |
| `/generate-avatar` | `POST` | PASS | Auth required; no user-owned resource ID parameter. |
| `/regenerate-avatar` | `POST` | PASS | Auth required; no user-owned resource ID parameter. |
| `/tweak-gallery-avatar` | `POST` | PASS | Auth required; no user-owned resource ID parameter. |
| `/list-avatars` | `GET` | PASS | Protected list of shared gallery assets; not user-owned data. |
| `/select-avatar/<avatar_id>` | `POST` | PASS | Protected selection of shared gallery assets; `avatar_id` is not user-owned data. |

## Intentionally public endpoints

- `/health`
- `/version`
- `/health/detailed`
- `/health/database`
- `/get-story-themes`
- `/report-story`
- `/generate-story-mock` in non-production
- `/generate-illustrations-mock` in non-production
- `/generate-coloring-pages-mock` in non-production
- `/setup-test-account`
- `/auth/anonymous`
- `/auth/login`
- `/auth/refresh`
- `/webhooks/stripe`
- `/stripe/webhook`
