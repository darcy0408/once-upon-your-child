# MT-171 — Gemini → OpenRouter Migration Brief

**Severity:** Highest open legal blocker (audit 04 L-AI-01).
**Status:** Scoping complete (2026-05-20). Awaiting Darcy decisions in §8 before Phase 1 implementation.
**Owning ticket:** `docs/MANUAL_TASKS.md` MT-171.

Every Gemini call site below currently violates Google's Gemini API Additional Terms because the product is positioned for ages 3–17. Migration to OpenRouter (option A in the ticket) is the only path that preserves the product thesis.

---

## 1. Audit of call sites

Every direct `from google import genai` import in production code (excluding `tests/`, scripts, and `generate_*` one-offs):

| # | File | Surface | Data sent | Replacement |
|---|---|---|---|---|
| 1 | `backend/services/story_generation_service.py` (`StoryGenerationService.generate_story`, L111-245) | Story text generation. Uses `gemini-2.5-flash` (paid) / `gemini-2.5-flash-lite` (free tier), 4-key rotation, child-safety thresholds, 90s timeout. | Free-text story prompt (theme, hero name pseudonymized, age band, virtue, companions). No PII (M-7 already strips). | OpenRouter chat completions — Claude 4.7 Sonnet (`anthropic/claude-sonnet-4.7`) for paid; Llama 3.3 70B Instruct (`meta-llama/llama-3.3-70b-instruct`) or `mistralai/mistral-nemo` for free. |
| 2 | `backend/services/openrouter_story_generator.py` (L17, L42) | Existing text fallback, currently pinned to free Llama 3.2 3B. | Same as #1. | Upgrade default model to Claude 4.7 Sonnet (paid path) and keep Llama 3.3 8B/70B free for free tier. |
| 3 | `backend/gemini_image_generator.py` — `generate_story_illustration` (L321-537) | Illustration generation, `gemini-2.5-flash-image` ("Nano Banana"), accepts optional `custom_avatar_base64` reference image. | Prompt + optional avatar reference photo. | OpenRouter `google/gemini-2.5-flash-image` is **the same model** but routed through OpenRouter's commercial terms — verify their ToS permit child-directed apps, otherwise use `black-forest-labs/flux-1.1-pro` or Cloudflare Workers AI Flux Schnell (already wired per `.env.example` L42–45). For reference-image conditioning, use Replicate PhotoMaker (already wired in `avatar_generation_service`). |
| 4 | `backend/gemini_image_generator.py` — `generate_coloring_page` (L539-691) | B/W line-art coloring pages. | Prompt + optional reference. | Same as #3. Flux Schnell handles line-art well; Replicate `prompthero/openjourney` or SDXL with negative-prompt color suppression. |
| 5 | `backend/gemini_image_generator.py` — `generate_custom_avatar` (L693-754) | Photo-to-stylized-avatar from child photo. | **Child photo bytes** + prompt. Highest-sensitivity surface. | Replicate PhotoMaker-Style (already the fallback in `avatar_generation_service.py:65-78`) — promote to primary. |
| 6 | `backend/gemini_image_generator.py` — `tweak_gallery_avatar` (L756-818) | Edit gallery avatar features. | Existing avatar webp + edit prompt. | OpenRouter Flux Kontext (image-editing). |
| 7 | `backend/gemini_image_generator.py` — `generate_character_avatar` (L820-922) | Stylized avatar without photo. | Prompt only. | OpenRouter Flux Schnell / SDXL. |
| 8 | `backend/gemini_image_generator.py` — `generate_pet_avatar` (L924-1001) | Pet photo → magical pet avatar. | Pet photo + prompt. | Replicate PhotoMaker (no child face — lower risk but still Gemini-ToS-bound today). |
| 9 | `backend/services/avatar_generation_service.py` — `_analyze_photo_features` (L491-555) | Best-effort vision-to-text descriptor extraction. `gemini-2.5-flash`, 12s timeout. | Child photo. | OpenRouter vision model — `anthropic/claude-haiku-4.5` (cheap, fast vision) or `google/gemini-2.5-flash` via OpenRouter (same ToS-routing question). Safest: `anthropic/claude-haiku-4.5`. |
| 10 | `backend/utils/content_moderator.py` (L21, L238-241) | Post-generation child-safety classifier, `gemini-2.5-flash-lite`. | Story text. | OpenRouter `anthropic/claude-haiku-4.5` or self-hosted moderation. Lightweight, JSON-mode required. |
| 11 | `backend/services/chronicle_prompt_service.py` (L29-39, L130, L175) | Chronicle (parental insights / memory threading). Uses `response_mime_type="application/json"`. | Story summaries. | Claude 4.7 Sonnet via OpenRouter — supports JSON mode through `response_format`. |
| 12 | `backend/services/interactive_adventure_service.py` (L38-58, L525) | Pick-a-path adventure step generator. Uses `response_mime_type="application/json"` + `thinking_config(thinking_budget=0)`. | Adventure state. | Claude 4.7 Sonnet; Claude's "thinking" disabled by default (no port concern). |
| 13 | `backend/routes/utility_routes.py` (L143-247) `/debug-gemini` | Diagnostic endpoint. | None. | Rename to `/debug-llm`; route to provider-agnostic check. |
| 14 | `backend/routes/health_routes.py` (L51) | Health probe pings genai. | None. | Same — provider-agnostic. |
| 15 | `backend/encryption_utils.py` (L257) | Stray genai import inside BYOK verification path. | Verifies user-supplied Gemini key. | Delete entirely once BYOK is deprecated (see Open Questions). |
| 16 | `backend/app.py` (L428-499, L745-756) | Wires `GEMINI_API_KEY` / `GEMINI_MODEL` into app config and constructs all services. | n/a | Add `STORY_GEN_PROVIDER` switch (see §4). |

## 2. Model map (recommended)

| Capability | OpenRouter model (paid) | OpenRouter model (free) |
|---|---|---|
| Story text (long-form prose, JSON output) | `anthropic/claude-sonnet-4.7` | `meta-llama/llama-3.3-70b-instruct` |
| JSON-mode short structured output (chronicle, adventure) | `anthropic/claude-haiku-4.5` | `meta-llama/llama-3.3-8b-instruct` |
| Content moderation classifier | `anthropic/claude-haiku-4.5` | `meta-llama/llama-3.3-8b-instruct` |
| Vision-to-text photo analysis | `anthropic/claude-haiku-4.5` (vision) | same |
| Text-to-image illustration | Cloudflare Flux Schnell (free daily quota) → Replicate Flux Schnell ($0.003/img) | same |
| Text-to-image coloring pages | Flux Schnell with `--no color` negative | same |
| Photo-to-avatar (child face) | Replicate PhotoMaker-Style | n/a |
| Image-edit (gallery tweak) | Replicate Flux Kontext | n/a |

**Verify before code lands:** OpenRouter's own Acceptable Use Policy. As of late 2025 it allows child-directed apps; confirm current language. If OpenRouter routes underlying Google Gemini models, the upstream Gemini ToS may still apply — pin to Anthropic/Meta/Flux to be safe.

## 3. Prompt-portability issues

- **`response_mime_type="application/json"`** used in `chronicle_prompt_service.py:36` and `interactive_adventure_service.py:54`. OpenRouter equivalent: `response_format={"type":"json_object"}` (OpenAI-compatible). Claude supports it natively; some Llama models do not — fall back to "respond with raw JSON, no markdown" prompt instruction.
- **`thinking_config(thinking_budget=0)`** at `interactive_adventure_service.py:57` — Gemini-specific. Drop on port; Claude has its own thinking model, but it is opt-in via `extra_body={"thinking":{"type":"disabled"}}` if needed.
- **`SafetySetting(category=..., threshold=...)`** at `story_generation_service.py:19-36` and `gemini_image_generator.py:25-46` — Gemini-specific. Claude/Llama have no equivalent knob; safety is enforced via system prompt + the existing post-gen `content_moderator.py` layer (which itself migrates).
- **`response_modalities=["IMAGE"]`** at `gemini_image_generator.py:280, 475, 675, 807` — Gemini-image-specific. New image providers return images natively; this flag disappears.
- **`types.Part.from_bytes(...)` reference-image payloads** — replaced by OpenRouter's `image_url: data:image/png;base64,...` content-part format, or by passing input image bytes to Replicate.
- **Gemini block-reason / finish-reason parsing** (`_extract_text` at `story_generation_service.py:43-86`) — Claude's stop reasons are `end_turn` / `max_tokens` / `tool_use`; Llama doesn't expose granular safety blocks. Rewrite `_extract_text` per provider; preserve the `_SAFETY_FALLBACK` user-visible string.
- **`google.api_core.exceptions.ResourceExhausted`** caught at `story_generation_service.py:173`, `openrouter_story_generator.py:10`, `tasks/story_tasks.py:21,115` — replace with HTTP 429 detection (already present in `openrouter_story_generator.py:67`). The `google.api_core` import in `openrouter_story_generator.py:10` is unused legacy and can be removed.
- **Multi-key rotation** (`GOOGLE_API_KEY_2/3/4`) is Gemini-only because OpenRouter handles per-account rate-limits transparently. Drop on port.

## 4. Feature flag design

Add a single env var: **`STORY_GEN_PROVIDER`** with values `gemini` (legacy), `openrouter` (target), `auto` (try OpenRouter, fall back to Gemini — for migration validation only).

Wiring location: `backend/app.py:428-499` (where `GEMINI_API_KEY` is read) and `backend/tasks/story_tasks.py:93-145` (provider sequencing). The provider order in `_generate_story_text_with_metadata` already implements a soft fallback chain — invert it under `STORY_GEN_PROVIDER=openrouter`:

```
if STORY_GEN_PROVIDER == 'openrouter':
    try OpenRouter -> static fallback
elif STORY_GEN_PROVIDER == 'gemini':
    try Gemini -> OpenRouter -> static  (current behavior)
elif STORY_GEN_PROVIDER == 'auto':
    try OpenRouter -> Gemini -> static  (rollback-safe)
```

For images, mirror with `IMAGE_GEN_PROVIDER` = `gemini|openrouter|replicate|cloudflare`. Replicate-first wiring already exists in `avatar_generation_service.py:62-98`; promote it.

Partially wired today: yes — OpenRouter is already the secondary text fallback (`tasks/story_tasks.py:122-141`) and image fallback (`avatar_generation_service.py:84-98`). The flag flip is mostly about **changing the order**, not adding a new code path.

## 5. Test surface

- `backend/tests/conftest.py:34-57` — autouse `mock_gemini` fixture must be paired with a `mock_openrouter` fixture; flip default based on `STORY_GEN_PROVIDER`.
- `backend/tests/unit/test_story_model_tier_selection.py` — pins `_resolve_text_model` tiers to Gemini model strings; needs provider-aware version.
- `backend/tests/unit/test_image_routing.py` — provider routing logic.
- `backend/tests/unit/test_avatar_generation_service.py` — mocks Gemini path; add OpenRouter parity tests.
- `backend/tests/unit/test_pet_avatar.py`, `test_illustration_cache_service.py` — Gemini response shape assumptions.
- `backend/tests/security/test_content_moderator.py` — pinned to `gemini-2.5-flash-lite` response shape.
- `backend/tests/integration/test_story_generation_integration.py`, `test_pick_a_path.py`, `test_six_band_integration.py` — end-to-end provider-name assertions (search for `"gemini"` in expected provider_sequence).
- `backend/tests/image_quality/run_provider_comparison.py` already supports multi-provider comparison — reuse for baselining.
- No integration test pins to Gemini-specific response JSON keys outside the `_extract_text` helper, which is centralized.

## 6. Cost delta (rough)

Cost rates from `backend/services/cost_tracker.py:11-58`. Story Weaver story text avg ~3,000 input tokens + ~1,500 output tokens per story; ~3 illustrations per story.

**Per story today (Gemini 2.5 Flash + Flash-Image):**
- Text: 3000 × $0.075/M + 1500 × $0.30/M ≈ $0.00067
- Images (3): 3 × $0.04 = $0.12
- **Total ≈ $0.121**

**Per story projected (Claude Haiku 4.5 + Flux Schnell on Replicate):**
- Text (Haiku rates ~$1/M input, $5/M output through OpenRouter + 5% markup): 3000 × $1.05/M + 1500 × $5.25/M ≈ $0.011
- Images (3 × Flux Schnell Replicate $0.003): $0.009
- **Total ≈ $0.020 — net cost DECREASE** (driven by Flux Schnell being ~13× cheaper than Gemini Image).

**Per story alternative (Claude Sonnet 4.7 for premium):**
- Text (~$3/M input, $15/M output × 1.05): ≈ $0.033
- Images: $0.009
- **Total ≈ $0.042** — still cheaper than today, with higher narrative quality.

The actual current monthly run rate is queryable from `audit_log` where `event_type='api_cost_incurred'` — recommend pulling 30 days before code lands. Free Cloudflare Flux quota likely drops the image cost to **$0** for first ~10k images/day.

## 7. Phased plan

**Phase 1 — Story text behind `STORY_GEN_PROVIDER=openrouter` (1-2 days, shippable & reversible).**
- Land env var in `app.py` + `tasks/story_tasks.py:93-145`.
- Upgrade `openrouter_story_generator.py` to support Claude 4.7 Sonnet (paid) / Llama 3.3 (free) via `_resolve_text_model`-style helper.
- Port `_extract_text` safety-block logic to OpenRouter response shape.
- Add `mock_openrouter` conftest fixture; flip default in CI.
- Roll out by tier: start with free tier (lowest stakes), then BYOK, then premium.

**Phase 2 — Vision + moderation (1-2 days).**
- Migrate `_analyze_photo_features` to Claude Haiku vision.
- Migrate `content_moderator.py` classifier to Claude Haiku JSON mode.
- Migrate `chronicle_prompt_service.py` + `interactive_adventure_service.py` (both already use JSON mode — port `response_format`).

**Phase 3 — Illustrations + coloring + character avatars (2-3 days).**
- Promote Cloudflare Flux Schnell to primary, Replicate Flux Schnell as fallback.
- Migrate `generate_story_illustration`, `generate_coloring_page`, `generate_character_avatar`, `tweak_gallery_avatar`.
- Re-baseline image quality using `tests/image_quality/run_provider_comparison.py`.

**Phase 4 — Photo-based avatars + final removal (1-2 days).**
- Promote Replicate PhotoMaker to primary for `generate_custom_avatar`, `generate_pet_avatar`, `generate_human_companion_avatar`.
- Delete `backend/gemini_image_generator.py`, `backend/services/story_generation_service.py`.
- Drop `google-generativeai` from `requirements.in`, remove `GEMINI_API_KEY` references, update `.env.example`.
- Update Privacy Policy sub-processor section.

Each phase ships behind its own flag and is fully reversible by flipping the env var; no destructive code drops until Phase 4.

## 8. Risks & open questions for Darcy

1. **Default model decision.** Claude 4.7 Sonnet (premium quality, ~$0.04/story) vs Llama 3.3 70B (free-tier, ~$0.005/story) vs an even cheaper Mistral. Need a default per tier.
2. **Cost ceiling.** Should there be a per-user-month hard cap (e.g. $1/free, $10/premium) enforced via the existing `cost_tracker.py` audit_log?
3. **OpenRouter ToS audit.** Has anyone confirmed OpenRouter's Acceptable Use Policy currently permits child-directed apps and that upstream model providers (Anthropic, Meta, Flux) do as well? Anthropic's commercial usage policy is the most permissive in this space; Meta Llama's license is broadly permissive. Need a written record before launch.
4. **BYOK deprecation.** BYOK (`encryption_utils.py:257`, `migrate_byok.py`) lets users supply their own Gemini key — this is also a ToS violation since the app is still directing the call at children. Either deprecate BYOK entirely or restrict it to a future Adult-band (18+) opt-in tier.
5. **Adult band (18+) Gemini retention.** Worth keeping Gemini wired for adults-only stories? Probably no — added complexity for a small surface; recommend single-provider for simplicity.
6. **Free-tier image strategy.** Cloudflare Flux Schnell free quota is ~10k/day. At scale we will overrun; need a decision on rate-limit fallback to paid Replicate or per-user image caps.
7. **Quality re-baseline.** The ticket calls out "content-quality re-baselining" as a risk. Plan to run `tests/image_quality/run_provider_comparison.py` and a sampled story-quality A/B before Phase 1 GA.
8. **Sub-processor disclosure.** PRIVACY_POLICY.md currently names Google; needs to list OpenRouter (and Anthropic/Meta/Replicate as upstreams) before flipping any flag for real users. This is a parallel legal task.
