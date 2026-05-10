# Image-Gen Provider A/B Test Results

**Test date:** 2026-05-10
**Goal:** Validate whether cheap image-generation providers (SDXL-Lightning, Flux Schnell at ~$0.003/image) can replace Gemini 2.5 Flash Image (~$0.039/image) for per-page story illustrations without unacceptable quality loss. Target: 90%+ cost reduction.
**Harness:** `backend/tests/image_quality/run_provider_comparison.py`
**Prompts:** 5 age bands × 3 pages each × 3 providers = 45 images planned. See `backend/tests/image_quality/results/prompts.json`.

## Status: ⚠️ BLOCKED — Replicate billing exhausted

**Block:** Replicate API returns HTTP 402 "Insufficient credit" on every cheap-provider call. Affects both `bytedance/sdxl-lightning-4step` (SDXL) and `black-forest-labs/flux-schnell` (Flux Schnell).

**Evidence:**
- Earlier test attempt (manifest timestamp 2026-05-10T10:01:40) failed on the first SDXL call: `Replicate create failed: 402 {"title":"Insufficient credit","detail":"You have insufficient credit to run this model..."}` — latency 0.43s, indicating a billing-layer reject, not a model issue.
- Replicate billing page: https://replicate.com/account/billing

**What we DO have:** 15 Gemini baseline images, ~$0.59 of generation cost. These establish "what good looks like" for visual scoring once the cheap providers are unblocked.

## To unblock

Two paths:

1. **Fund Replicate** — add ~$5 credit at https://replicate.com/account/billing, wait a few minutes per their docs, re-run `python backend/tests/image_quality/run_provider_comparison.py`. Estimated cost for the cheap-provider half: $0.09 (30 images × ~$0.003).
2. **Try alternative cheap providers** — fal.ai, Together.ai, OpenRouter passthrough. Would require adding new client logic to the harness; see "Alternative providers" section below.

Recommend (1). $5 of Replicate credit covers ~1,600 cheap-provider calls — far more than this test needs and useful as a permanent fallback for production load.

## Cost analysis (verified, independent of test outcome)

Per-call cost estimates from public 2026 pricing (Verified):

| Provider | $/image | Reference-photo (img2img) | Quality vs Gemini |
|---|---|---|---|
| Gemini 2.5 Flash Image | $0.039 | Native multi-modal | baseline |
| Replicate SDXL-Lightning | $0.003 | yes (img2img) | TBD — not yet tested |
| Replicate Flux Schnell | $0.003 | limited | TBD — not yet tested |
| Replicate Recraft v3 | $0.04 | yes | TBD — premium-priced cheap alt |
| OpenAI DALL-E 3 | $0.04-0.08 | limited | comparable to Gemini |
| Stable Diffusion 3.5 | $0.04 | yes | comparable to Gemini |

### Cost impact at current Family worst-case caps (200 illustrated pages/mo)

| Provider | Per-user image cost/mo | Phase 1 Family margin (decided $19.99) | Phase 1 Family margin ($14.99 alt) |
|---|---|---|---|
| Gemini Image (status quo) | 200 × $0.039 = **$7.80** | +$4.78 / 25% | **−$0.08 LOSS** |
| SDXL-Lightning (if quality holds) | 200 × $0.003 = **$0.60** | +$11.98 / 60% | +$7.12 / 47% |
| Flux Schnell (if quality holds) | 200 × $0.003 = **$0.60** | +$11.98 / 60% | +$7.12 / 47% |

**Single biggest economic lever in the matrix.** If quality holds, flipping primary unlocks Family at $14.99 (3240's D1 proposal) AND moves Premium worst-case margin from 28% to ~75%.

## Visual quality assessment

**Status:** pending — only Gemini baseline available. Will be filled in once the cheap-provider half can run.

Scoring rubric (for fill-in once images are available):

| Criterion | What we look for |
|---|---|
| Character likeness consistency across pages | Same kid/companion looks the same in pages 1, 2, 3 of the same story |
| Scene coherence | Image matches the prompt's setting, action, and mood |
| Kid-appropriate aesthetic | Warm, soft, inviting; no horror artifacts; no uncanny faces |
| AI-artifact level | Hands, eyes, facial proportions; merged limbs; weird text |
| Style match per age band | Sprout = soft storybook; Adolescent = sophisticated cinematic |

## Recommendation (preliminary, pending visual data)

If SDXL-Lightning OR Flux Schnell holds visual parity with Gemini: **flip primary for per-page illustrations**, keep Gemini as fallback. Save Imagen quota for avatars (where likeness matters most).

If both cheap providers fall short on character likeness: **stay on Gemini for per-page**, but invest in `tencentarc/photomaker-style` (already wired for avatars at `backend/replicate_image_generator.py:282`) to capture the avatar cost savings without quality risk.

If both fail entirely: keep current pipeline; revisit when newer cheap models ship.

## Next steps for whoever picks this up

1. Add Replicate credit (~$5 at https://replicate.com/account/billing).
2. Re-run `python backend/tests/image_quality/run_provider_comparison.py` from repo root. ~3-4 minutes.
3. Visually review the 30 cheap-provider images side-by-side with the 15 Gemini baseline images (organized by age band and page).
4. Fill in the "Visual quality assessment" section above with per-provider scores.
5. Update the "Recommendation" section based on visual results.
6. If the recommendation is to flip primary, file an MT for the production routing change in `story_routes.py` / `story_tasks.py`. Do NOT make the production change in the same session as this writeup — that's a separate decision Darcy needs to approve.

## Constraints (from Plan 1 brief)

- Do NOT change which generator is primary in production until Darcy approves.
- Phase 1 monetization commit (`6bef121b`) and Sprout pagination fix (`add7e31b`) landed on main while this test was blocked — those are unrelated and stable.
- Branch `image-gen-ab-test` was created earlier but is now orphan-equivalent (1 commit behind main); rebase or recreate from main when ready.
