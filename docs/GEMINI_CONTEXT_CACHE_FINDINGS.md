# Gemini Explicit Context Caching — Findings

**Date:** 2026-05-17
**Scope:** Text story generation (`backend/services/story_generation_service.py`,
`backend/services/story_service.py`).
**Outcome:** Explicit context caching **NOT implemented** — see reasoning below.
The findings note replaces the code change per the task brief ("if it is NOT
clean, do not force it").

## What was investigated

The brief asked whether the per-age-band system prompt has a large, stable,
reused prefix that explicit caching (`client.caches.create` + `cached_content`)
could amortize.

Files read:

- `StoryGenerationService.generate_story()` — the actual Gemini call.
- `AdvancedStoryEngine.generate_enhanced_prompt()` (`story_service.py:507`) —
  the standard prompt builder.
- `_build_bedtime_prompt`, `_build_learning_to_read_prompt`,
  `_build_rhyme_time_prompt`, and the Superhero `PromptService.build_story_prompt`
  path — the other prompt builders.

## What was found

1. **No separate system instruction.** `generate_story()` calls
   `generate_content(model=..., contents=prompt, config=...)` — the entire
   prompt is passed as a single `contents` string. There is no
   `system_instruction` and no `cached_content` argument anywhere. Explicit
   caching is keyed on a stable content block; there is no such block here.

2. **The prompt has no stable prefix.** Every prompt builder returns one
   f-string with request-specific values interpolated *throughout*, starting
   at the top. For the standard path (`generate_enhanced_prompt`), the prompt
   opens:

   > `**PERSONA**: Master Storyteller...`
   > `You are a MASTER STORYTELLER creating a {story_length} adventure for {character}{gender_text} (age {age}).`

   The first variable (`{story_length}`, `{character}`, `{age}`) lands in the
   **second sentence**. The age-band rule blocks (`young_delight_rules`,
   `complexity_instruction`, `per_page_words`, `safety_reinforcement`, etc.)
   are themselves conditional on `age` *and* embed `{character}` inline (e.g.
   the RULE OF THREE and COMPANION VOICE rules name the hero directly). There
   is no contiguous prefix of meaningful size that is byte-identical across
   two different requests.

3. **The shared age-band text is small and fragmented.** The genuinely stable
   per-band text (safety reinforcement, complexity instruction, delight rules
   minus the interpolated hero name) is a few hundred tokens at most, and it
   is interleaved with variable content rather than sitting in one block.
   Gemini explicit caching has a minimum cacheable size (~1024–4096 tokens
   depending on model) and requires the cached content to be a *prefix*. The
   stable material here is both below that floor and not prefix-contiguous.

4. **Implicit caching already covers the realistic win.** Gemini 2.5 models
   (both `gemini-2.5-flash` and `gemini-2.5-flash-lite`) perform implicit
   caching automatically and bill cache hits at a discount with zero code
   changes and zero cache-management risk. Whatever repeated-prefix overlap
   exists between consecutive same-band requests is already eligible for the
   implicit discount.

## Recommendation

**Do not implement explicit context caching for text generation.** Reasons:

- There is no large (>2000-token), stable, prefix-contiguous block to cache —
  the prompt is variable from sentence two onward.
- Explicit caching would require restructuring every prompt builder to split a
  fixed system block from the variable body, plus cache lifecycle code
  (create/reuse/expire per age band per prompt version, TTL tuning, miss
  handling). That is a large, fragile change for a prefix that is below the
  minimum cacheable size anyway.
- Implicit caching on the 2.5 models already captures the available savings
  with no maintenance surface.

The realized cost win from this task is **Task 1** (free tier on
`gemini-2.5-flash-lite`), which is implemented and is a much larger, lower-risk
lever (~6x cheaper input for the non-paying segment).

### If explicit caching is ever revisited

It would only become worthwhile if the prompts are first refactored so that
each age band has a genuine fixed system-instruction block (passed via
`config.system_instruction`) that is **byte-identical** across requests and
**above the model's minimum cacheable token count**. That refactor is a
prerequisite, not a side effect, and should be scoped as its own task.
