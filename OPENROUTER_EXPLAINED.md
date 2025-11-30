# OpenRouter Setup - Simple Explanation

## What Codex Did

Codex added code to your backend that automatically uses **OpenRouter** instead of **Gemini** for generating images when you have an `OPENROUTER_API_KEY` environment variable set.

### The Key Parts:

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
- When your app starts, it checks for `OPENROUTER_API_KEY`
- If found → uses OpenRouter (cheaper/free)
- If not found → falls back to Gemini (more expensive)

---

## Your Current Setup

✅ **OPENROUTER_API_KEY is already set in Railway**

I checked and confirmed:
- Key exists: `sk-or-v1-46f7...`
- Format is correct
- Backend code is configured to use it

---

## How to Create an OpenRouter API Key

If you need to create a NEW key or update the existing one:

### Step 1: Go to OpenRouter
Visit: https://openrouter.ai/keys

### Step 2: Click "Create Key"

### Step 3: Fill Out the Form

| Field | What to Enter | Why |
|-------|--------------|-----|
| **Name** | `story-weaver-image` | Just a label to identify this key |
| **Credit limit** | `$5` or `$10` | Prevents overspending if there's a bug |
| **Reset limit every** | `monthly` | Auto-resets your budget each month |
| **Expiration** | `No expiration` | Keeps working forever (or set to 30-60 days for security) |

### Step 4: Copy the Key

After clicking "Create", you'll see a key like:
```
sk-or-v1-abc123def456...
```

**⚠️ COPY IT IMMEDIATELY** - you won't see it again!

### Step 5: Add to Railway

```bash
railway variables set OPENROUTER_API_KEY=sk-or-v1-YOUR-KEY-HERE
```

Then restart the service:
```bash
railway restart
```

---

## How to Test It

### Quick Test (Easiest)

1. **Run the test script:**
   ```bash
   test_openrouter_images.bat
   ```

2. **Look at the response:**
   - ✅ Good: `{"illustrations": [...], "count": 1}`
   - ❌ Bad: `{"illustrations": [], "count": 0}`

### Check the Logs

```bash
railway logs --service story-weaver-app
```

**What to look for on startup:**
```
Image generator initialized with OpenRouter (cost-optimized)
```

**If you see this instead, something's wrong:**
```
Image generator initialized with Gemini
```

---

## Current Test Result

I just tested your production backend and got:
```json
{"count": 0, "illustrations": [], "used_user_key": false}
```

**What this means:**
- ✅ The endpoint is working
- ✅ The request went through
- ❌ No images were generated

**Possible reasons:**
1. The OpenRouter API key might be invalid/expired
2. The free Flux model might be rate-limited
3. There could be an error in the OpenRouter API call (check logs)

---

## How to Fix Empty Results

### Option 1: Check Logs for Errors

```bash
railway logs --service story-weaver-app | grep -i "openrouter"
```

Look for:
- `OpenRouter API error: 401` = Invalid key
- `OpenRouter API error: 429` = Rate limited
- `OpenRouter API error: 500` = OpenRouter service issue

### Option 2: Verify Your Key is Valid

1. Go to https://openrouter.ai/activity
2. Check if you see recent API calls
3. Check if your key is active

### Option 3: Test Locally

You can test the OpenRouter integration locally:

```bash
cd backend
python openrouter_image_generator.py
```

This will run the test code at the bottom of the file and show you exactly what's happening.

---

## Cost Comparison

| Provider | Model | Cost per Image | Speed |
|----------|-------|----------------|-------|
| **OpenRouter** | Flux-1-Schnell (Free) | **$0.00** | ~5 sec |
| OpenRouter | SDXL | ~$0.002 | ~3 sec |
| Gemini | Imagen-2 | ~$0.04 | ~2 sec |

**Your setup uses the FREE tier** 🎉

---

## What Codex Meant (Translation)

> **"Hooked the app to a cheaper image path"**
>
> → The backend now checks for `OPENROUTER_API_KEY` and uses it if available

> **"if OPENROUTER_API_KEY is set, the backend now prefers the cost-optimized"**
>
> → If you have the env variable, it uses OpenRouter instead of Gemini

> **"Live image tests still need a valid key (not available here)"**
>
> → Codex couldn't test it live because they don't have your API keys

> **"Trigger /generate-illustrations and watch logs to confirm OpenRouter is used"**
>
> → Make a POST request to the endpoint and check the logs to see if it says "OpenRouter (cost-optimized)"

---

## Next Steps

1. **Check Railway logs** to see if there are OpenRouter errors:
   ```bash
   railway logs --service story-weaver-app
   ```

2. **If you see errors**, create a new OpenRouter key and update Railway

3. **If no errors but empty results**, the issue might be with the free Flux model - consider using a paid model

4. **Test again** with the test script after any changes

---

## Summary

- ✅ OpenRouter integration is already in your code
- ✅ `OPENROUTER_API_KEY` is already set in Railway
- ⚠️ Currently returning empty illustrations (needs debugging)
- 🎯 Next: Check logs for errors and verify the API key is valid

**You're 90% there!** Just need to debug why the API calls aren't returning images.
