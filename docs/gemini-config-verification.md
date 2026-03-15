# Gemini Configuration Verification

This checklist documents how Gemini is configured in the current backend and how to verify that the deployed service can actually use it for image generation.

## 1. Required Environment Variables

### Required for Gemini image generation

- `GEMINI_API_KEY`
  - Required by `backend/gemini_image_generator.py`.
  - Also used by the Flask app bootstrap in `backend/app.py`.
- `GEMINI_MODEL`
  - Used for text-generation paths and exposed by health/version endpoints.
  - Default in config is `gemini-2.5-flash`.
  - This is not the image model used by `GeminiImageGenerator`, but it still needs to be correct for the rest of the backend.

### Gemini image-provider specific configuration

- Image model is currently hard-coded inside `backend/gemini_image_generator.py` as:
  - `gemini-2.0-flash-preview-image-generation`
- `GEMINI_IMAGE_REQUEST_TIMEOUT_SECONDS`
  - Optional.
  - Default: `120`
  - Used by `GeminiImageGenerator` for image requests.

### Related Gemini runtime configuration

- `GEMINI_REQUEST_TIMEOUT_SECONDS`
  - Optional.
  - Default commonly used elsewhere: `90`
  - Used by text-generation services, not by the image generator itself.
- `DISABLE_GEMINI_IMAGE`
  - Optional feature flag.
  - If true-ish (`1`, `true`, `yes`), Gemini image generation is disabled in parts of the app.
  - This can make Gemini look "broken" even when the API key is valid.

### Not required for Gemini, but affects actual image-provider selection

- `OPENROUTER_API_KEY`
  - If present, `backend/app.py` prefers OpenRouter as the global `image_generator`.
  - Gemini becomes the fallback, not the primary provider, for story illustrations and coloring pages.
- `REPLICATE_API_TOKEN`
  - Used by custom-avatar fallback logic in `backend/services/avatar_generation_service.py`.

## 2. How To Verify Locally

### Quick config sanity check

From repo root:

```powershell
python backend/verify_key.py
```

What it does:

- Reads `GEMINI_API_KEY`
- Uses `GEMINI_MODEL` or defaults to `gemini-2.5-flash`
- Makes a minimal Gemini text request

Expected result:

- Success: prints `Success` and the response text.
- Failure: prints a clear error such as missing key, `429`, or another API error.

This verifies general Gemini connectivity, but not the image model specifically.

### Recommended live test for the Gemini image provider

From repo root:

```powershell
python -c "import os; from google import genai; from google.genai import types; client = genai.Client(api_key=os.environ['GEMINI_API_KEY']); resp = client.models.generate_content(model='gemini-2.0-flash-preview-image-generation', contents='Create a tiny friendly blue star on a plain white background.', config=types.GenerateContentConfig(response_modalities=['IMAGE'])); print('candidates=', len(getattr(resp, 'candidates', []) or []))"
```

Expected result:

- Success: prints `candidates=` with a value greater than `0`.
- Failure: raises an exception. The exception text is what you need to inspect.

### Optional REST check with `curl`

This is useful to prove the API key can reach Gemini over HTTPS, but it does not reflect the repo's Python SDK path as closely as the Python test above.

```bash
curl -sS -X POST \
  "https://generativelanguage.googleapis.com/v1beta/models/${GEMINI_MODEL:-gemini-2.5-flash}:generateContent?key=${GEMINI_API_KEY}" \
  -H "Content-Type: application/json" \
  -d '{
    "contents": [
      {
        "parts": [
          { "text": "Reply with exactly: System Online" }
        ]
      }
    ]
  }'
```

Expected result:

- Success: JSON response containing generated text similar to `System Online`.
- Failure: JSON error payload or HTTP error status.

### Local app-level checks

If the backend is running locally:

```bash
curl -s http://127.0.0.1:5000/health
curl -s http://127.0.0.1:5000/health/detailed
```

Important:

- These endpoints do **not** validate live Gemini connectivity.
- They only report whether the backend has an API key configured.

## 3. How To Verify In Production

### Deployed environment checks

In Railway or the deployed backend environment, verify:

- `GEMINI_API_KEY` is present and non-empty.
- `GEMINI_MODEL` is set to the intended text model.
- `DISABLE_GEMINI_IMAGE` is not accidentally enabled.
- If you expect Gemini to handle story illustrations directly, make sure `OPENROUTER_API_KEY` is absent or intentionally unused.

### Runtime behavior checks

1. Check `/health`
   - Confirm `has_api_key: true`
   - Confirm the reported `model` matches the intended text model
2. Check `/health/detailed`
   - Confirm `checks.gemini_api.configured` is `true`
3. Use an admin account to hit `/debug-gemini`
   - This is the only built-in route that currently performs a live Gemini request
   - It tests text generation, not the image model
4. Exercise a real image flow
   - Human custom avatar: `POST /avatar/generate-custom-avatar`
   - Pet avatar: `POST /avatar/generate-pet-avatar`
   - Story illustrations: `POST /generate-illustrations`

### Deployment workflow check

Current GitHub workflows do not inject Gemini configuration into the backend at deploy time:

- `.github/workflows/backend-deploy.yml` logs into Railway and runs `railway up --detach`
- `.github/workflows/canary-deployment.yml` does the same for canary
- `.github/workflows/health-monitoring.yml` only checks `/health`

Implication:

- Gemini secrets must be present in Railway service/environment configuration.
- A successful GitHub deploy does not prove Gemini is configured correctly.

## 4. Common Failure Modes

Below are the most likely failure patterns. The exact provider message can vary, but these are the relevant signatures for this codebase.

### API key missing

Where it shows up:

- Startup logs in `backend/app.py` warn that `GEMINI_API_KEY` is not set.
- `/health` shows `has_api_key: false`
- `/health/detailed` shows Gemini configured as false/unhealthy

Current app behavior:

- Story illustrations/coloring pages may fall back to OpenRouter if configured.
- If no usable image generator exists, illustration endpoints return HTTP `200` with an empty list and an availability message.
- Custom avatar generation can fail with:
  - `Custom avatar generation is not configured. Set GEMINI_API_KEY, REPLICATE_API_TOKEN, or OPENROUTER_API_KEY on the backend.`
- Pet avatar generation can fail with:
  - `Pet avatar generation is not configured. Gemini image generation is unavailable.`

### API key invalid / permission denied

Repo-observed handling:

- `backend/encryption_utils.py` maps invalid-key style failures to:
  - `Invalid API key. Please check your key and try again.`
- Permission-denied style failures are mapped to:
  - `API key doesn't have permission to use Gemini API.`

Likely API symptoms:

- HTTP `401` or `403`
- Error strings containing `invalid`, `API_KEY_INVALID`, `permission`, or `403`

### Model unavailable

Likely symptoms:

- HTTP `404` or `400`
- Error text mentioning model not found, unsupported model, or unavailable model

Important nuance in this repo:

- Text generation uses `GEMINI_MODEL`
- Image generation uses the hard-coded image model `gemini-2.0-flash-preview-image-generation`
- So `/health` can look correct while image generation still fails because the image model is unavailable to the key/project

### Rate limit / quota hit

Repo-observed handling:

- `backend/gemini_image_generator.py` explicitly checks for `429`, `quota`, `exceeded`, and `resource_exhausted`
- Story illustration endpoint returns HTTP `200` with:
  - `illustrations: []`
  - `count: 0`
  - message about quota limits
- Text-generation code also maps quota issues to `QUOTA_EXCEEDED`

Likely symptoms:

- HTTP `429`
- Error strings containing `quota`, `resource_exhausted`, `rate`, or `429`

### Network / firewall / outbound HTTPS blocked

Likely symptoms:

- Connection timeout
- DNS resolution failure
- SSL/TLS handshake failure
- Python exceptions from the SDK before any valid Gemini response is returned

Current app behavior:

- Image generator methods usually catch the exception and return an empty result list.
- That often means user-facing routes return an empty-success response rather than a hard failure, especially for story illustrations.

## 5. Current Fallback Behavior

### Human custom avatars

Current behavior in `backend/services/avatar_generation_service.py`:

1. Try Gemini custom-avatar generation first
2. If that fails, try the configured fallback generator
   - Prefer Replicate if `REPLICATE_API_TOKEN` exists
   - Otherwise OpenRouter
3. If the Replicate fallback fails, try OpenRouter as a tertiary fallback
4. If all fail, the route returns HTTP `500`

User-facing route behavior:

- `POST /avatar/generate-custom-avatar`
- On failure returns:
  - `status: error`
  - `error_code: GENERATION_FAILED`
  - message starting with `Our magic paintbrush hit a snag:`

### Pet avatars

Current behavior in `backend/services/avatar_generation_service.py`:

1. Try Gemini pet-avatar generation first
2. If that fails and a fallback generator exists, try a text-only fallback avatar generation path
3. If all fail, the route returns HTTP `500`

Important limitation:

- Pet avatars depend on Gemini much more directly than custom human avatars.
- If the configured primary generator is OpenRouter instead of Gemini, pet generation can fail because the provider may not implement `generate_pet_avatar`.

User-facing route behavior:

- `POST /avatar/generate-pet-avatar`
- On failure returns:
  - `status: error`
  - `error_code: GENERATION_FAILED`
  - message starting with `Our magic paintbrush hit a snag with the pet avatar:`

### Story illustrations

Current behavior in `backend/app.py` and `backend/routes/story_routes.py`:

1. Global image generator prefers OpenRouter when `OPENROUTER_API_KEY` exists
2. Otherwise falls back to Gemini if `GEMINI_API_KEY` exists
3. If a request supplies `user_api_key`, the route may create a per-request `GeminiImageGenerator`
4. If the generator returns no images, the route returns HTTP `200` with an empty list and a quota/unavailable message
5. If no generator exists at all, the route also returns HTTP `200` with `illustrations: []`

This means:

- Story generation itself can still succeed while illustrations silently degrade to empty output.
- A production outage in Gemini image generation may not show up as a hard application error.

## Health Endpoint Status

There is a `/health` endpoint and a `/health/detailed` endpoint.

What they currently validate:

- Database reachability
- Whether a Gemini API key is configured
- Basic environment/Stripe metadata

What they do **not** validate:

- A live request to Gemini
- Whether the configured key can access the image model
- Whether the hard-coded image model is available
- Whether outbound network access to Google is working

## Recommendation

Add a production-safe Gemini connectivity probe, for example:

- `/health/gemini`
  - Makes a minimal live request to Gemini
  - Preferably tests both:
    - text model configured by `GEMINI_MODEL`
    - image model `gemini-2.0-flash-preview-image-generation`
  - Returns structured failure reasons without exposing secrets

Also consider updating deployment monitoring so it checks that live probe instead of only checking `/health` for `ok`.
