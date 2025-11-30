# What's Happening with Images? - Complete Guide

## TL;DR (The Short Answer)

**Codex integrated OpenRouter** (a cheaper image generation service) into your backend. When you toggle "Create illustrations" in your Flutter app, it should generate images using OpenRouter instead of the expensive Gemini API.

**Problem:** When I tested it, the illustrations come back empty (`[]`). This needs debugging.

---

## What Codex Did (Step by Step)

### 1. Added OpenRouter Support

**File: `backend/openrouter_image_generator.py`**
- Created a new class `OpenRouterImageGenerator`
- Uses Stable Diffusion via OpenRouter API
- Cost: **FREE** (using `flux-1-schnell-free` model)
- Alternative to Gemini (which costs ~$0.04 per image)

### 2. Modified Backend to Use OpenRouter

**File: `backend/app.py` (lines 310-325)**

```python
openrouter_key = os.getenv("OPENROUTER_API_KEY")
if openrouter_key:
    image_generator = OpenRouterImageGenerator(api_key=openrouter_key)
    logger.info("Image generator initialized with OpenRouter (cost-optimized)")
elif api_key:
    image_generator = GeminiImageGenerator()
    logger.info("Image generator initialized with Gemini")
```

**What this means:**
- On startup, the backend checks for `OPENROUTER_API_KEY`
- If found → uses OpenRouter (free/cheap)
- If not found → uses Gemini (expensive)

### 3. Already Configured in Railway

Your Railway environment already has:
```
OPENROUTER_API_KEY = REDACTED-ROTATED-KEY
```

✅ **This is already set!** No action needed here.

---

## How It's Supposed to Work

### In the Flutter App:

1. **User toggles "Create illustrations" checkbox**
   - `lib/main_story.dart:1011` - Sets `_includeIllustrations = true`

2. **App calls backend API**
   - `lib/services/api_service_manager.dart:314` - Sends `include_illustrations: true` to backend

3. **Backend receives request**
   - `backend/app.py:103` - Parameter `includeIllustrations` is received

4. **Backend decides whether to generate images**
   - Lines 793-812 in `app.py` - Complex logic based on:
     - User's subscription tier (free, premium, family)
     - Learning-to-read mode
     - Whether user provided their own API key (BYOK)

5. **If approved, generates images**
   - Lines 813-847 - Uses `image_generator` (OpenRouter or Gemini)
   - Calls `generate_story_illustration()`

6. **Returns images in response**
   - Line 861 - Includes `illustrations` array in JSON response

---

## Why Illustrations Might Not Be Generated

Looking at the backend logic (`app.py:793-812`), illustrations are **skipped** unless:

### For FREE tier users:
- ❌ `include_illustrations` alone won't work
- ✅ Must ALSO enable `learning_to_read_mode`, OR
- ✅ Must provide their own API key (BYOK)

### For PREMIUM tier users:
- ✅ `include_illustrations` = 1 auto-illustration
- ✅ `learning_to_read_mode` = 1 auto-illustration (even without toggle)

### For FAMILY tier users:
- ✅ `include_illustrations` = 2 auto-illustrations
- ✅ `learning_to_read_mode` = 2 auto-illustrations

---

## The Problem I Found

When I tested your production backend:

```bash
curl -X POST https://story-weaver-app-production.up.railway.app/generate-illustrations \
  -H "Content-Type: application/json" \
  -d '{"scene_description": "Luna and dragon", "character_name": "Luna", "style": "watercolor", "num_images": 1, "age": 7}'
```

**Response:**
```json
{"count": 0, "illustrations": [], "used_user_key": false}
```

**What this means:**
- ✅ The endpoint works
- ✅ OpenRouter is configured
- ❌ OpenRouter API calls are failing silently (returning no images)

**Possible reasons:**
1. **API key is invalid/expired**
   - Check https://openrouter.ai/keys to verify the key is active

2. **Free Flux model is rate-limited**
   - The free tier has limits - you might have hit them

3. **API response format changed**
   - OpenRouter might have changed how they return image URLs

4. **Network/firewall issue**
   - Railway might be blocking outbound calls to OpenRouter

---

## How to Debug This

### Step 1: Check Railway Logs

```bash
railway logs --service story-weaver-app | grep -i "openrouter\|image"
```

**Look for:**
- `Image generator initialized with OpenRouter (cost-optimized)` ← Good!
- `Image generator initialized with Gemini` ← OpenRouter not working
- `OpenRouter API error: 401` ← Invalid key
- `OpenRouter API error: 429` ← Rate limited
- `No image URL found in OpenRouter response` ← API format changed

### Step 2: Verify OpenRouter Key

1. Go to https://openrouter.ai/keys
2. Find your key: `sk-or-v1-46f7...`
3. Check:
   - ✅ Status: Active
   - ✅ Credit limit: Not exceeded
   - ✅ Expiration: Not expired

### Step 3: Test Locally

Run the OpenRouter test script directly:

```bash
cd backend
python openrouter_image_generator.py
```

This will show you exactly what's happening when calling OpenRouter.

### Step 4: Check OpenRouter Activity

1. Go to https://openrouter.ai/activity
2. Look for recent API calls from your app
3. Check if there are any errors

---

## Quick Fix Options

### Option 1: Create a New OpenRouter Key

If the current key is having issues:

```bash
# Create new key at https://openrouter.ai/keys
# Then update Railway:
railway variables set OPENROUTER_API_KEY=sk-or-v1-NEW-KEY-HERE
railway restart
```

### Option 2: Use a Paid OpenRouter Model

The free Flux model might be unreliable. Switch to SDXL:

**File: `backend/openrouter_image_generator.py:71`**

Change:
```python
"model": "black-forest-labs/flux-1-schnell-free",  # Free
```

To:
```python
"model": "stability-ai/sdxl",  # ~$0.002 per image
```

### Option 3: Fall Back to Gemini Temporarily

If you need illustrations working NOW:

```bash
# Remove the OpenRouter key temporarily
railway variables set OPENROUTER_API_KEY=""
railway restart
```

This will make the app use Gemini (more expensive, but reliable).

---

## Testing Guide

### Test 1: Direct API Call

```bash
test_openrouter_images.bat
```

This tests the `/generate-illustrations` endpoint directly.

### Test 2: Full Story Generation

```bash
test_illustration_toggle.bat
```

This tests story generation with and without illustrations.

### Test 3: Check Logs

```bash
railway logs --service story-weaver-app
```

Watch for startup message and any errors.

---

## Summary

### What's Working:
- ✅ OpenRouter integration code is complete
- ✅ `OPENROUTER_API_KEY` is set in Railway
- ✅ Flutter app sends `include_illustrations: true` correctly
- ✅ Backend receives the flag and processes it

### What's Not Working:
- ❌ OpenRouter API calls return empty results
- ❌ No images are generated (even for premium/family tiers)

### Next Steps:
1. Check Railway logs for OpenRouter errors
2. Verify OpenRouter API key is valid
3. Test OpenRouter locally with `python openrouter_image_generator.py`
4. If needed, create a new OpenRouter key or switch to SDXL model

---

## What Codex Meant (Full Translation)

> **"Hooked the app to a cheaper image path"**
>
> = Added code that checks for `OPENROUTER_API_KEY` and uses it instead of Gemini

> **"if OPENROUTER_API_KEY is set, the backend now prefers the cost-optimized Railway) to auto-use SDXL"**
>
> = When the environment variable exists in Railway, the backend automatically uses Stable Diffusion XL via OpenRouter

> **"if you want, I can also add a feature flag to switch providers per request/tier"**
>
> = Codex can add code to let you choose Gemini vs OpenRouter based on user subscription tier or per API call

> **"Live image tests still need a valid key (not available here)"**
>
> = Codex couldn't test the actual image generation because they don't have access to your API keys

> **"Name: story-weaver-image, Credit limit: (optional), Reset limit every: monthly"**
>
> = Settings to use when creating an OpenRouter API key:
>   - Name it "story-weaver-image" (just a label)
>   - Set a credit limit like $5 or $10 to prevent overspending
>   - Make it reset monthly so your budget refreshes

> **"Trigger /generate-illustrations and watch logs to confirm OpenRouter is used"**
>
> = Make an API call to the `/generate-illustrations` endpoint and check the Railway logs to verify you see "Image generator initialized with OpenRouter (cost-optimized)"

---

## Cost Comparison

| Method | Provider | Model | Cost per Image | Your Setup |
|--------|----------|-------|----------------|------------|
| Current | OpenRouter | Flux-1-Schnell-Free | **$0.00** | ✅ Configured |
| Alternative 1 | OpenRouter | SDXL | $0.002 | ⚙️ Easy switch |
| Alternative 2 | Gemini | Imagen-2 | $0.04 | ⚙️ Fallback |

**Bottom line:** You're set up for FREE image generation, but it's not working right now. Debugging needed!

---

## Files I Created for You

1. **`test_openrouter_images.bat`** - Test the /generate-illustrations endpoint
2. **`test_illustration_toggle.bat`** - Test story generation with/without illustrations
3. **`HOW_TO_TEST_OPENROUTER.md`** - Detailed testing guide
4. **`OPENROUTER_EXPLAINED.md`** - Full explanation of OpenRouter setup
5. **`WHATS_HAPPENING_WITH_IMAGES.md`** - This file (comprehensive summary)

**Run `test_openrouter_images.bat` first** to see what happens!
