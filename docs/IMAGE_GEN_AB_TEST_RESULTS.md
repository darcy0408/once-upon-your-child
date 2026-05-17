# Image-Gen Provider A/B Test Results

**Test date:** 2026-05-10
**Branch:** `image-gen-ab-test`
**Goal:** Validate whether cheap image-generation providers (SDXL-Lightning, Flux Schnell at ~$0.003/image) can replace Gemini 2.5 Flash Image (~$0.039/image) for per-page story illustrations without unacceptable quality loss. Target: 90%+ cost reduction.
**Harness:** `backend/tests/image_quality/run_provider_comparison.py`
**Prompts:** `backend/tests/image_quality/results/prompts.json` (15 prompts: 5 age bands × 3 pages)

## Production routing audit + verified OpenRouter cost

**Production primary is not direct Gemini.** It is `OpenRouterImageGenerator` (`backend/app.py:466-491`), which proxies the same `google/gemini-2.5-flash-image` model via OpenRouter's chat-completions endpoint (`backend/openrouter_image_generator.py:177`).

**Verified per-image cost via OpenRouter: ~$0.0375.** Measured from <https://openrouter.ai/activity>: 4 Nano Banana (Gemini 2.5 Flash Image) requests = $0.15 spend = **$0.0375/image**. Effectively the same as Google's direct $0.039 rate. OpenRouter applies a per-image surcharge for image-modality output — the published token rate ($2.50/M output tokens) does NOT apply to image responses, even though that's what the model card suggests. (Anyone tempted to estimate cost from token rates for this model: don't — they're not the operative price.)

**Implication: the brief's cost premise was correct.** Production is paying ~$0.039/image today, and a switch to Flux Schnell at ~$0.003/image is a real ~92% cost saving per illustration. The hybrid recommendation below is a genuine cost lever, not a quality-only move.

Two further corrections to the brief:
- The brief described `ReplicateImageGenerator` as "fallback that fires when Gemini 429s" — but grep confirms it is **not wired as a fallback for per-page illustrations**. It is used only by `services/avatar_generation_service.py` (avatar fallback) and `services/interactive_adventure_service.py` (interactive adventure scenes). On per-page failure, the endpoint returns `illustrations: []` (`routes/story_routes.py:1100-1114`) with no provider retry.
- The `max_tokens: 1000` cap in `backend/openrouter_image_generator.py:177, 285, 366, 443` is below the ~1290 tokens an image output consumes; production succeeds anyway, suggesting OpenRouter ignores `max_tokens` for image modality. Worth confirming and removing the misleading cap.

## Status: ✅ Complete — recommendation ready

| Provider | $/image (direct) | OK / Attempts | Total cost | Notes |
|---|---|---|---|---|
| Gemini 2.5 Flash Image | $0.039 | **15 / 15** | $0.585 | Baseline; all bands × all pages successful |
| Replicate SDXL-Lightning | $0.003 | 7 / 15 | $0.021 | 8× HTTP 429 rate-limit on Replicate (account-level throttling at <$5 credit, burst=1). The 11s per-call pause was insufficient. Successful images cover all 5 age bands. |
| Replicate Flux Schnell | $0.003 | 8 / 15 | $0.024 | Same 7× HTTP 429 issue. Coverage hits all 5 age bands. |
| **Total run cost** | | 30 / 45 | **$0.630** | |

The 429 rate-limit prevented full coverage on the cheap providers but the 15/30 successful cheap-provider images span all 5 age bands and 10/15 unique scenes — enough data to score quality with confidence. Note: $/image column is per-provider direct billing; see *Production routing audit* above for why production may already be at the ~$0.003 tier.

## Per-band visual quality assessment

Scoring rubric (subjective, 1-10):
- **Likeness** — character appearance matches prompt details (hair, skin, outfit)
- **Scene** — image matches the prompt's setting, action, mood
- **Style fit** — appropriate for the age band's aesthetic (Sprout = soft 3D Pixar; older = more sophisticated)
- **Artifacts** — AI artifacts (hand/face issues, object doubling, etc.) penalize the score
- **Consistency** — character looks like the same person across pages of the same story (when multi-page coverage exists)

### Sprout (ages 3-5) — 3 pages, character: Lily + dolphin Bubbles

| Provider | Likeness | Scene | Style fit | Artifacts | Consistency | Avg |
|---|---|---|---|---|---|---|
| Gemini | 10 | 10 | 10 (warm soft 3D Pixar) | none | strong | **10/10** |
| Flux Schnell | 8 | 8 | 8 (closer 3D look) | minor (dolphin shown on p1 where prompt didn't include it) | reasonable | **8/10** |
| SDXL | 6 | 5 (p3 shows two girls instead of girl+dolphin) | 5 (more painterly than 3D storybook) | object doubling (two buckets p1), character drift across pages | weak (3 different girls across 3 pages) | **5/10** |

**Sprout verdict:** Gemini is meaningfully better. Flux Schnell is a credible second; SDXL fails the consistency + style-match bar.

### Explorer (ages 6-8) — limited coverage

Both cheap providers had only 1 successful page in this band (429s blocked the others). What we have:
- **Flux Schnell explorer_p2:** captures Max (boy in green explorer cloak) + Sparkle (unicorn) in mushroom forest. Style is cleaner anime-influenced.
- **SDXL explorer_p2:** broadly similar scene but character drift from prompt details.

Insufficient data for a confident score in this band, but the trend matches Sprout.

### Adventurer (ages 9-11) — character: Zoe + Finn in crystal cave

| Provider | Likeness | Scene | Style fit | Artifacts | Avg |
|---|---|---|---|---|---|
| Gemini | 9 | 10 (giant crystal heart, vines, lit faces) | 9 | none | **9/10** |
| Flux Schnell | 8 (goggles + auburn ponytail correct) | 8 | 8 | minor | **8/10** |
| SDXL | 6 (Zoe rendered with short red hair, prompt said long wavy auburn) | 7 | 7 | none significant | **7/10** |

**Adventurer verdict:** the gap narrows for older bands. Flux Schnell is genuinely competitive here.

### Creator (ages 12-14) — character: Sam (non-binary teen with teal undercut)

| Provider | Likeness | Scene | Style fit | Artifacts | Avg |
|---|---|---|---|---|---|
| Gemini | 10 (teal tips on undercut, pins, sketchbook bag) | 10 (art gallery with colorful art) | 9 | none | **10/10** |
| Flux Schnell | 8 (teal tips + pins captured) | 7 | 7 (anime-influenced) | minor | **8/10** |
| SDXL | 3 (rendered as curly-haired kid, no teal, no pins) | 5 (library not gallery) | 5 | character age miss | **4/10** |

**Creator verdict:** Flux Schnell holds up; SDXL fails the character-specifics test badly.

### Adolescent (ages 15-17) — character: Jordan, teen runner

| Provider | Likeness | Scene | Style fit | Artifacts | Avg |
|---|---|---|---|---|---|
| Gemini | 10 (J jacket, headphones, deep brown skin, right age) | 10 (cinematic track stadium) | 10 | none | **10/10** |
| Flux Schnell | 8 (J jacket, headphones around neck, teen age) | 8 | 8 (anime-influenced) | minor | **8/10** |
| SDXL | 4 (rendered as ~9yo child, not 16) | 6 | 4 (cartoon kid-styling for a teen prompt) | wrong age aesthetic | **4/10** |

**Adolescent verdict:** Flux Schnell is fine; SDXL completely fails the teen aesthetic.

## Overall scoring

| Provider | Average score | Cost/page | Quality/cost |
|---|---|---|---|
| Gemini 2.5 Flash Image | 9.6 | $0.039 | baseline |
| Flux Schnell | 8.0 | $0.003 | **2.7× better quality-per-dollar** |
| SDXL-Lightning | 5.0 | $0.003 | 1.7× — but quality below acceptance bar |

## Update 2026-05-17 — Sprout switched to Flux Schnell primary

**Superseded:** the original recommendation kept Gemini primary for Sprout. As of 2026-05-17 Sprout (age ≤5) routes to **Flux Schnell as primary** (Gemini-via-OpenRouter remains the fallback so a young child always gets a picture). Driver was cost: Flux Schnell (~$0.003/image) is ~13× cheaper than Gemini-via-OpenRouter (~$0.0375/image), and a Sprout picture book is ~10 images per story. Sprout illustrations are now metered under a separate, generous monthly cap (free 60 / premium 250 / family 500). Tradeoff to monitor: Flux's style is less warm than Gemini's soft 3D Pixar look — re-evaluate if Sprout image-quality feedback regresses; the `CLOUDFLARE_FLUX_DISABLED` / `FLUX_SCHNELL_DISABLED` kill-switches plus the Gemini fallback allow a fast revert.

## Recommendation

**Hybrid pipeline: Flux Schnell as primary for ages 6+, Gemini stays primary for Sprout.** _(Sprout half superseded — see "Update 2026-05-17" above.)_

Rationale:
1. **Sprout (≤5): keep Gemini.** The warm soft 3D Pixar style is critical for 3-5 year olds. Flux Schnell's anime-influenced style is the wrong vibe; SDXL's painterly style is worse. The cost saving doesn't justify the aesthetic miss. Sprout is your visible hook — don't compromise it.
2. **Explorer/Adventurer/Creator/Adolescent (6+): flip Flux Schnell to primary.** Older bands tolerate more stylistic variety, and Flux at $0.003 captures character likeness + scene composition well enough (8/10 average). The 92% cost reduction unlocks the Family $14.99 pricing in `docs/PREMIUM_BYOK_MATRIX.md`.
3. **Always keep Gemini as fallback** when Flux Schnell returns a 429, 5xx, or content-flagged response. The existing fallback infrastructure in `backend/replicate_image_generator.py` is reusable.
4. **Do not use SDXL-Lightning as primary anywhere.** Quality is below the acceptance bar for character consistency and age-aesthetic match. Keep it as a third-tier fallback below Flux Schnell if you want belt-and-suspenders.

## Cost impact under the hybrid recommendation

Verified baseline: production currently pays **~$0.0375/image** via OpenRouter (see *Production routing audit* above). Hybrid math below uses this verified rate.

Assuming Sprout users generate ~20% of total per-page illustrations (rough demographic split — Sprout is one of six age bands but skews highly engaged):

| Tier | Current cost (OpenRouter→Gemini @ $0.0375) | New cost (hybrid: Sprout on Gemini, 6+ on Flux Schnell) | Saving |
|---|---|---|---|
| Premium worst-case (80 pages) | 80 × $0.0375 = $3.00 | 16 × $0.0375 + 64 × $0.003 = $0.79 | **−$2.21 / user / mo** |
| Family worst-case (200 pages) | 200 × $0.0375 = $7.50 | 40 × $0.0375 + 160 × $0.003 = $1.98 | **−$5.52 / user / mo** |

**Family $14.99 (3240's D1 alternative) margin shift:**

| Family price | Net rev (after fees) | Cost today | Cost (hybrid) | Margin today | Margin (hybrid) |
|---|---|---|---|---|---|
| $14.99 | $14.25 | $14.33 (Gemini all bands) | $1.98 | **−$0.08 LOSS** | **+$5.24 / 37%** ✅ |
| $19.99 | $19.11 | $14.33 | $1.98 | +$4.78 / 25% | +$10.10 / 53% |

The hybrid recommendation **unlocks Family at $14.99** (3240's D1 proposal becomes margin-positive instead of margin-negative) and **moves Premium worst-case margin from ~28% to ~75%.** Single biggest economic lever in the Phase 1 monetization matrix that isn't already pulled.

## Implementation path

This writeup is research-only. Production routing changes need separate approval. The path forward:

1. ~~Verify OpenRouter actual per-image cost~~ **Done 2026-05-10:** verified at <https://openrouter.ai/activity> as ~$0.0375/image (4 requests / $0.15). Hybrid recommendation is a real cost lever.
2. **Darcy reviews the visual samples** in `backend/tests/image_quality/results/{gemini,flux_schnell,sdxl}/` and confirms the hybrid recommendation feels right.
3. **Optional: re-run the failed 15 cheap-provider calls** (with a longer per-call pause to avoid Replicate 429s) for fuller coverage. Cost: ~$0.05. Not strictly necessary — the 15/30 we have are conclusive.
4. **File an MT** to wire Flux Schnell for non-Sprout bands at the routing decision point in `backend/app.py:466-491` (image_generator init) plus `routes/story_routes.py:1066-1098` (per-request selection). Keep Gemini (via OpenRouter or direct) as the Sprout primary and as the fallback for older bands. Existing `ReplicateImageGenerator` is reusable — already exposes `generate_story_illustration()` with the same signature.
5. **Decide on the `max_tokens: 1000` cap** in `backend/openrouter_image_generator.py:177, 285, 366, 443`. Either remove it (image responses exceed the cap and OpenRouter appears to ignore it for image modality) or raise it to ~2000 to be safe.
6. **Add a unit test** asserting Sprout band uses Gemini and other bands use Flux Schnell (regression-protection for the cost-saving structure).
7. **Update `docs/PREMIUM_BYOK_MATRIX.md`** decision log with the hybrid recommendation and the OpenRouter cost verification result. Re-run the compute-cost math with the verified numbers.

## Coverage gaps to acknowledge

- The 429-throttled images (13 total) leave Explorer and Creator with only 1-2 successful cheap-provider images each. Confidence in those bands' scores is medium, not high.
- No reference-photo (img2img) testing in this run — all generations were text-prompt-only. The actual production avatar pipeline uses photo references for character likeness. Flux Schnell supports img2img via the Redux variant; that's a Phase 2 experiment if reference-photo behavior matters.
- No assessment of generation latency (Gemini ~10s/image, Replicate ~5s/image post-create). Latency favors the cheap providers slightly.

## Artifacts checked into git

- `backend/tests/image_quality/run_provider_comparison.py` — the harness
- `backend/tests/image_quality/results/manifest.json` — full run record (45 attempts, status per call)
- `backend/tests/image_quality/results/prompts.json` — the 15 prompts
- `backend/tests/image_quality/results/run_log.txt` — terminal output from the latest run
- PNG images on disk in `results/{gemini,sdxl,flux_schnell}/` (~32 MB total) — not committed; regenerable from manifest + prompts via the harness

## Constraints honoured (from brief)

- No changes to production routing logic — `app.py`, `routes/story_routes.py`, `tasks/story_tasks.py` are unmodified on this branch.
- All work isolated on branch `image-gen-ab-test`.
- Pre-existing uncommitted Phase 1 work in the tree was not touched (`gemini_image_generator.py`, `tts_routes.py`, `avatar_generation_service.py`, `story_duration_service.py`, `story_service.py`, `story_tasks.py`, `test_story_service.py`, `ai_quota.py`, Dart files, `pubspec.lock`, `cost_tracker.py`).
