# Task 2 — Content Moderator Model Bump

**Model:** Sonnet
**Estimated effort:** 15–30 min

## Background

`backend_errors.log` (most recent line, 2026-04-20 16:49) shows:

```
backend.utils.content_moderator - WARNING - content_moderator:
classifier error (ClientError("404 NOT_FOUND. {'error': {'code': 404,
'message': 'This model models/gemini-2.0-flash-lite is no longer
available to new users. Please update your code to use a newer model
for the latest features and improvements.', 'status': 'NOT_FOUND'}}")),
failing open
```

**Why this matters:** the content moderator is **failing open** — meaning generated stories are no longer being safety-classified before being served to kids. This is a silent safety regression on a therapeutic children's app. **Treat as P0.**

## Call sites to update

Grep has already found all references. Three files mention `gemini-2.0-flash-lite`:

| File | Line | Purpose |
|------|------|---------|
| `backend/utils/content_moderator.py` | 21 | `_CLASSIFIER_MODEL` constant — primary target |
| `backend/utils/content_moderator.py` | 93 | second literal inside a fallback call — update both for consistency |
| `backend/services/story_generation_service.py` | 166 | `fallback_model` for story generation when the main model fails |
| `backend/cost_tracking.py` | 26 | pricing table key — update if pricing needs to match new model, or add a new key |

## Replacement model

Pick a current, cheap, fast Gemini classifier model. As of 2026-01 the sensible replacements are:

- `gemini-2.5-flash-lite` — direct successor, cheapest + fastest
- `gemini-2.5-flash` — a tier up, more accurate, slightly pricier

**Recommendation:** `gemini-2.5-flash-lite` for the moderator (speed matters, decision is binary-ish), and the same for the story fallback unless there's a reason to bias toward quality.

**Verify the exact model ID** before committing — check https://ai.google.dev/gemini-api/docs/models or whichever SDK version `backend/requirements.txt` pins. Don't guess; a second 404 defeats the purpose.

## Cost tracking

`backend/cost_tracking.py:26` has pricing keyed on `gemini-2.0-flash-lite`. Either:

- Add a new entry for `gemini-2.5-flash-lite` with updated pricing, **and** keep the old one for historical logs; or
- Replace the key in place if no historical tracking is at risk.

Check the file structure and pick whichever is more consistent with how pricing is already handled.

## Verification

After the swap:

1. Start the backend locally (`python backend/app.py` or however it's run in this repo — check `backend/README.md` or the root `Makefile`).
2. POST to `/generate-story` with any valid payload.
3. Watch the logs. The `content_moderator: classifier error` warning should be **gone**, and you should see a normal classify path run.
4. Confirm no 404s in `backend_errors.log`.

## Deliverable

1. Code change across the files above.
2. A short note appended to `TEAM_COORDINATION.md` under a **2026-04-21** entry: "Content moderator model bump — `gemini-2.0-flash-lite` → `<chosen model>`. Was failing open (404). Verified locally: classifier runs."
3. Commit with `fix(moderator): bump classifier model from deprecated gemini-2.0-flash-lite to <chosen-model>`.

## Notes

- **Don't** silently remove the failing-open behavior — that's a separate safety question. Just restore the happy path.
- If the new model's SDK signature differs (it shouldn't for a minor version bump), verify `google-generativeai` package version in `backend/requirements.txt` supports it.
