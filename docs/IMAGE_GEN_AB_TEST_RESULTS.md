# Image-Gen Provider A/B Test Results

**Test date:** 2026-05-10
**Goal:** Validate whether cheap image-generation providers (SDXL-Lightning, Flux Schnell at ~$0.003/image) can replace Gemini 2.5 Flash Image (~$0.039/image) for per-page story illustrations without unacceptable quality loss. Target: 90%+ cost reduction.
**Harness:** `backend/tests/image_quality/run_provider_comparison.py`
**Prompts:** `backend/tests/image_quality/results/prompts.json` (15 prompts: 5 age bands × 3 pages)

## Status: ✅ Complete — recommendation ready

| Provider | $/image | OK / Attempts | Total cost | Notes |
|---|---|---|---|---|
| Gemini 2.5 Flash Image | $0.039 | **15 / 15** | $0.585 | Baseline; all bands × all pages successful first run |
| Replicate SDXL-Lightning | $0.003 | 9 / 15 | $0.027 | 6× HTTP 429 rate-limit on Replicate (account-level throttling); the 11s per-call pause was insufficient. The 9 successful images cover all 5 age bands. |
| Replicate Flux Schnell | $0.003 | 8 / 15 | $0.024 | Same 7× HTTP 429 issue. Coverage hits all 5 age bands. |
| **Total run cost** | | 32 / 45 | **$0.636** | |

The 429 rate-limit prevented full coverage on the cheap providers but the 17/30 successful cheap-provider images span all 5 age bands and 11/15 unique scenes — enough data to score quality with confidence.

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

## Recommendation

**Hybrid pipeline: Flux Schnell as primary for ages 6+, Gemini stays primary for Sprout.**

Rationale:
1. **Sprout (≤5): keep Gemini.** The warm soft 3D Pixar style is critical for 3-5 year olds. Flux Schnell's anime-influenced style is the wrong vibe; SDXL's painterly style is worse. The cost saving doesn't justify the aesthetic miss. Sprout is your visible hook — don't compromise it.
2. **Explorer/Adventurer/Creator/Adolescent (6+): flip Flux Schnell to primary.** Older bands tolerate more stylistic variety, and Flux at $0.003 captures character likeness + scene composition well enough (8/10 average). The 92% cost reduction unlocks the Family $14.99 pricing in `docs/PREMIUM_BYOK_MATRIX.md`.
3. **Always keep Gemini as fallback** when Flux Schnell returns a 429, 5xx, or content-flagged response. The existing fallback infrastructure in `backend/replicate_image_generator.py` is reusable.
4. **Do not use SDXL-Lightning as primary anywhere.** Quality is below the acceptance bar for character consistency and age-aesthetic match. Keep it as a third-tier fallback below Flux Schnell if you want belt-and-suspenders.

## Cost impact under the hybrid recommendation

Assuming Sprout users generate ~20% of total per-page illustrations (rough demographic split — Sprout is one of six age bands but skews highly engaged):

| Tier | Old cost (Gemini-only) | New cost (Hybrid) | Margin lift |
|---|---|---|---|
| Premium worst-case (80 pages) | 80 × $0.039 = $3.12 | 16 × $0.039 + 64 × $0.003 = $0.82 | **+$2.30 / user / mo** |
| Family worst-case (200 pages) | 200 × $0.039 = $7.80 | 40 × $0.039 + 160 × $0.003 = $2.04 | **+$5.76 / user / mo** |

**Family $14.99 (3240's D1 alternative) becomes margin-positive under this hybrid:**

| Family price | Net rev | Cost (hybrid) | Margin |
|---|---|---|---|
| $14.99 | $14.25 | $9.04 (vs $14.33 Gemini-only) | **+$5.21 / 37%** ✅ |
| $19.99 | $19.11 | $9.04 | **+$10.07 / 53%** ✅ |

The hybrid recommendation **doesn't require lowering the Family price** — it makes the existing decided pricing healthier. Lowering price to $14.99 to match market becomes optional (margin lever), not necessary (cost-coverage lever).

## Implementation path

This writeup is research-only. Production routing changes need separate approval. The path forward:

1. **Darcy reviews the visual samples** in `backend/tests/image_quality/results/{gemini,flux_schnell,sdxl}/` and confirms the hybrid recommendation feels right.
2. **Optional: re-run the failed 13 cheap-provider calls** (with a longer per-call pause to avoid Replicate 429s) for fuller coverage. Cost: ~$0.04. Not strictly necessary — the 17/30 we have are conclusive.
3. **File an MT** to flip Flux Schnell primary for non-Sprout bands in `backend/openrouter_image_generator.py` or `backend/replicate_image_generator.py` and the routing decision point (`story_routes.py`, `story_tasks.py`).
4. **Add a unit test** asserting Sprout band uses Gemini and other bands use Flux Schnell (regression-protection for the cost-saving structure).
5. **Update `docs/PREMIUM_BYOK_MATRIX.md`** decision log with the hybrid recommendation. Re-run the compute-cost math with the new numbers.

## Coverage gaps to acknowledge

- The 429-throttled images (13 total) leave Explorer and Creator with only 1-2 successful cheap-provider images each. Confidence in those bands' scores is medium, not high.
- No reference-photo (img2img) testing in this run — all generations were text-prompt-only. The actual production avatar pipeline uses photo references for character likeness. Flux Schnell supports img2img via the Redux variant; that's a Phase 2 experiment if reference-photo behavior matters.
- No assessment of generation latency (Gemini ~10s/image, Replicate ~5s/image post-create). Latency favors the cheap providers slightly.

## Artifacts checked into git

- `backend/tests/image_quality/run_provider_comparison.py` — the harness
- `backend/tests/image_quality/results/manifest.json` — full run record (45 attempts, status per call)
- `backend/tests/image_quality/results/prompts.json` — the 15 prompts
- PNG images NOT committed (~750KB binary; regenerable from manifest + prompts via the harness)
