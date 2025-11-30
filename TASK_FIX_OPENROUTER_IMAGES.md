# Task: Fix OpenRouter Image Generation

**Agent Assignment:** Backend Agent (Codex recommended - started this integration)
**Priority:** MEDIUM-HIGH (Cost optimization)
**Status:** Blocked - Need correct API documentation
**Current:** Gemini works but expensive (~$0.04/image)
**Goal:** OpenRouter working (~$0.003/image, 90% savings)

---

## Problem Summary

OpenRouter image generation integration is partially complete but not working:

✅ **What Works:**
- OpenRouter initializes correctly
- Global variable fixed
- API key set and valid
- Code structure is correct

❌ **What Doesn't Work:**
- All model IDs return 400 "not a valid model ID"
- Tried: `flux-1.1-pro`, `flux-pro`, `flux-1-schnell-free`
- All fail with same error

---

## Research Needed

### Question 1: Does OpenRouter Support Image Generation via Chat API?
- Current approach: Using `/chat/completions` endpoint
- Assumption: Image models respond with markdown containing image URLs
- **Need to verify:** Is this the correct approach?

### Question 2: What are the Correct Model IDs?
- Tried various flux model IDs - all invalid
- **Need to find:** List of valid image-generation model IDs
- **Check:** OpenRouter's official model list

### Question 3: Alternative Approach?
- Maybe OpenRouter doesn't do image generation through chat API
- Maybe there's a different endpoint for images
- **Research:** OpenRouter's actual image generation method

---

## Resources to Check

1. **OpenRouter Documentation:**
   - https://openrouter.ai/docs
   - Check for image generation specific docs
   - Look for example code

2. **OpenRouter Model List:**
   - https://openrouter.ai/models
   - Filter by "image" or "vision" models
   - Get exact model IDs

3. **OpenRouter Discord/Community:**
   - Ask how image generation works
   - Get working example code

4. **Alternative:**
   - Check if OpenRouter partners with specific image providers
   - Maybe need to use their API directly

---

## Current Code Location

**File:** `backend/openrouter_image_generator.py`

**Current Approach (Lines 60-103):**
```python
response = requests.post(
    f"{self.base_url}/chat/completions",
    headers={
        "Authorization": f"Bearer {self.api_key}",
        "HTTP-Referer": "https://story-weaver-app-production.up.railway.app",
        "X-Title": "Story Weaver App",
        "Content-Type": "application/json",
    },
    json={
        "model": "black-forest-labs/flux-1-schnell-free",  # Not working!
        "messages": [
            {
                "role": "user",
                "content": prompt
            }
        ],
    },
    timeout=60,
)
```

**Expected Response Format:**
```python
# Expecting markdown with image URL
content = data['choices'][0]['message']['content']
# Format: ![image](https://...)
```

---

## Possible Solutions

### Option A: Find Correct Model IDs
If chat API approach is correct, just need right model names:
1. Get model list from OpenRouter
2. Find image generation models
3. Update model IDs in code
4. Test

### Option B: Different API Endpoint
If OpenRouter has separate image endpoint:
1. Find correct endpoint (not `/chat/completions`)
2. Update request format
3. Update response parsing
4. Test

### Option C: Use Different Provider
If OpenRouter doesn't actually do cheap image generation:
1. Research alternatives (Replicate, Together AI, etc.)
2. Compare pricing
3. Implement new provider
4. Test

### Option D: Optimize Gemini Usage
If alternatives don't work:
1. Keep using Gemini (current fallback)
2. Optimize prompts to reduce cost
3. Cache common images
4. Rate limit image generation

---

## Testing Steps

Once you find the solution:

1. **Update code** in `openrouter_image_generator.py`
2. **Deploy** to Railway
3. **Test** with curl:
   ```bash
   curl -X POST https://story-weaver-app-production.up.railway.app/generate-illustrations \
     -H "Content-Type: application/json" \
     -d '{"scene_description": "A happy dragon", "num_images": 1}'
   ```
4. **Verify** response contains image URL
5. **Check** image URL is accessible
6. **Monitor** OpenRouter dashboard for usage/costs

---

## Success Criteria

- [ ] OpenRouter API returns 200 status (not 400)
- [ ] Response contains valid image URL
- [ ] Image URL loads successfully
- [ ] Images match prompt description
- [ ] Cost is ~$0.003-0.006 per image
- [ ] No errors in Railway logs

---

## Fallback Plan

If OpenRouter doesn't work or takes too long:

**Keep Gemini** (current working solution):
- Cost: ~$0.04/image
- Quality: Good
- Reliability: High
- **Already working!**

Then optimize costs by:
- Limiting image generation to premium users
- Caching popular images
- Reducing image size
- Using lower quality Gemini model

---

## Communication

When you start working on this, post in TEAM_COORDINATION.md:

```markdown
## Agent 1 - Backend API | [DATE]

### Working On
- Researching OpenRouter image generation API
- Goal: Find correct model IDs or alternative approach

### Findings
- [What you discovered from docs/community]
- [Correct API approach]
- [Model IDs that work]

### Next Steps
- [Update code]
- [Test]
- [Deploy]
```

---

## Notes from Previous Attempts

1. **global variable bug** - Fixed ✅
2. **Wrong endpoint** (`/images/generations`) - Changed to `/chat/completions` ✅
3. **Model IDs invalid** - Still blocked ❌

**All model IDs tried:**
- `stabilityai/stable-diffusion-xl-base-1.0` → 405 error
- `black-forest-labs/flux-1.1-pro` → 400 "not valid model ID"
- `black-forest-labs/flux-pro` → 400 "not valid model ID"
- `black-forest-labs/flux-1-schnell-free` → 400 "not valid model ID"

**Logs show:**
```
OpenRouter API error: 400 - {"error":{"message":"MODEL_ID is not a valid model ID","code":400}}
```

---

## Estimated Time

- **Research:** 1-2 hours
- **Implementation:** 30 minutes - 1 hour
- **Testing:** 30 minutes
- **Total:** 2-4 hours

---

## Priority Justification

**MEDIUM-HIGH because:**
- ✅ Gemini fallback works (not blocking users)
- ❌ Current cost is 10x higher than it could be
- 💰 Saving 90% on image costs is significant
- 📈 As usage grows, costs will too

**Can be done in parallel with:**
- Character customization sliders
- Frontend polish
- Bug fixes

---

**Ready to research?** Start by checking https://openrouter.ai/docs for image generation examples!
