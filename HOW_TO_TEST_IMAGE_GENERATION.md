# How to Test Image Generation

## Quick Test Methods

### Method 1: Via curl (Command Line) ✅ EASIEST

**Test the correct backend:**
```bash
curl -X POST https://story-weaver-app-production.up.railway.app/generate-illustrations \
  -H "Content-Type: application/json" \
  -d '{"scene_description": "A happy dragon in a sunny forest", "character_name": "Luna", "num_images": 1, "age": 7}'
```

**Expected Success Response:**
```json
{
  "illustrations": [
    {
      "id": "some-uuid_0",
      "prompt": "...",
      "image_url": "https://openrouter.ai/...",
      "format": "png",
      "generated_at": "2025-11-29T..."
    }
  ],
  "count": 1,
  "used_user_key": false
}
```

**Current Response (Problem):**
```json
{
  "count": 0,
  "illustrations": [],
  "used_user_key": false
}
```

---

### Method 2: Via Frontend (User Testing)

1. **Open the app:**
   - https://grand-light-production-68d9.up.railway.app

2. **Create a story with image:**
   - Create/select a character
   - Select an emotion
   - **Check the "Include illustration" checkbox** ✅
   - Generate story

3. **Check result:**
   - ✅ Image should appear in the story result
   - ❌ If no image, check browser console for errors

---

### Method 3: Check Logs

**See if OpenRouter is initialized:**
```bash
railway logs | grep "Image generator"
```

**Expected to see:**
```
Image generator initialized with OpenRouter (cost-optimized)
```

**If you see this instead:**
```
Image generator initialized with Gemini
```
Then OpenRouter key isn't being picked up.

---

## Debugging Steps

### Step 1: Verify Environment Variable

```bash
railway variables | grep OPENROUTER
```

Should show:
```
OPENROUTER_API_KEY  │ sk-or-v1-...
```

### Step 2: Check if Backend Has Restarted

The backend needs to restart after you set the environment variable.

**Force a restart:**
```bash
# Option A: Redeploy
railway up

# Option B: Restart via Railway dashboard
# Go to Deployments → "Redeploy" button
```

### Step 3: Watch Logs During Startup

```bash
railway logs
```

Look for during startup:
- `"Image generator initialized with OpenRouter (cost-optimized)"` ← Want this!
- `"Image generator initialized with Gemini"` ← Don't want this (fallback)

### Step 4: Test OpenRouter Directly

Create this test file in `backend/`:

```python
# backend/test_openrouter_direct.py
import os
from openrouter_image_generator import OpenRouterImageGenerator

# Test if key is accessible
key = os.getenv("OPENROUTER_API_KEY")
print(f"OPENROUTER_API_KEY exists: {bool(key)}")
print(f"Key starts with: {key[:15] if key else 'N/A'}")

# Test generation
if key:
    generator = OpenRouterImageGenerator(api_key=key)
    print("\nTesting image generation...")

    result = generator.generate_story_illustration(
        scene_description="A happy dragon",
        character_name="Luna",
        num_images=1
    )

    if result:
        print(f"✅ SUCCESS! Generated {len(result)} image(s)")
        print(f"Image URL: {result[0]['image_url']}")
    else:
        print("❌ FAILED: No images generated")
else:
    print("❌ No OPENROUTER_API_KEY found")
```

**Run it:**
```bash
cd backend
railway run python test_openrouter_direct.py
```

---

## Common Issues & Solutions

### Issue 1: Returns 0 Images

**Symptoms:**
```json
{"count": 0, "illustrations": [], "used_user_key": false}
```

**Possible Causes:**
1. OpenRouter API key not set or invalid
2. Backend hasn't restarted to pick up new key
3. OpenRouter API error (rate limit, no credits, etc.)
4. Exception being caught silently

**Solutions:**
1. Verify key: `railway variables | grep OPENROUTER`
2. Restart backend: `railway up`
3. Check OpenRouter dashboard: https://openrouter.ai/activity
4. Check logs for errors: `railway logs | grep -i error`

### Issue 2: "Image generator initialized with Gemini"

**Cause:** Backend started before OPENROUTER_API_KEY was set

**Solution:**
1. Verify key is set: `railway variables | grep OPENROUTER`
2. Force restart: `railway up`
3. Check logs again

### Issue 3: OpenRouter API Error

**Check logs for:**
```
OpenRouter API error: 401  ← Invalid API key
OpenRouter API error: 402  ← No credits
OpenRouter API error: 429  ← Rate limited
```

**Solutions:**
- 401: Check key is correct in Railway variables
- 402: Add credits at https://openrouter.ai/credits
- 429: Wait a bit, or add credits to increase rate limit

### Issue 4: Images Generate But Don't Display in Frontend

**Symptoms:**
- API returns image URLs
- Frontend doesn't show images

**Check:**
1. Browser console for CORS errors
2. Image URLs are accessible (copy URL to browser)
3. Frontend is using correct backend URL

---

## Verification Checklist

After setup, verify:

- [ ] `railway variables | grep OPENROUTER` shows the key
- [ ] Backend has restarted (check deployment timestamp)
- [ ] Logs show "Image generator initialized with OpenRouter"
- [ ] curl test returns images with URLs
- [ ] Frontend "Include illustration" generates images
- [ ] Images display in story results
- [ ] OpenRouter dashboard shows requests: https://openrouter.ai/activity

---

## What We Know So Far

✅ OPENROUTER_API_KEY is set in Railway
✅ STRIPE_API_KEY is set in Railway
✅ Code is in place (openrouter_image_generator.py)
✅ Endpoint responds (/generate-illustrations)
❌ Returns 0 images
❓ No "Image generator initialized" message in logs

**Next Step:** Force backend restart and watch for initialization message.

---

## Quick Commands Reference

```bash
# Check environment variables
railway variables | grep OPENROUTER

# Watch logs
railway logs

# Force restart
railway up

# Test endpoint
curl -X POST https://story-weaver-app-production.up.railway.app/generate-illustrations \
  -H "Content-Type: application/json" \
  -d '{"scene_description": "dragon", "num_images": 1}'

# Check OpenRouter usage
# Go to: https://openrouter.ai/activity
```

---

**Last Updated:** 2025-11-29 by Claude (Supervisor)
**Status:** Investigating why 0 images are returned
