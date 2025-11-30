# OpenRouter Image Generation - Quick Test Guide

## ✅ Current Status

**OpenRouter is ALREADY CONFIGURED** in your Railway deployment!

- Environment Variable: `OPENROUTER_API_KEY` is set
- Backend Code: Configured to auto-detect and use OpenRouter
- Cost: **FREE** (using `flux-1-schnell-free` model)

## 🧪 How to Test

### Option 1: Quick Test (Recommended)

**Run the test script:**

```bash
test_openrouter_images.bat
```

This will:
1. Send a test request to your production backend
2. Request 1 illustration of "Luna befriending a dragon"
3. Show you the response with image URL(s)

### Option 2: Manual cURL Test

```bash
curl -X POST https://story-weaver-app-production.up.railway.app/generate-illustrations \
  -H "Content-Type: application/json" \
  -d "{\"scene_description\": \"A brave 7-year-old named Luna befriends a tiny dragon in a magical forest\", \"character_name\": \"Luna\", \"style\": \"vibrant watercolor children's book illustration\", \"num_images\": 1, \"age\": 7}"
```

### Option 3: Check Railway Logs

```bash
railway logs --service story-weaver-app
```

**Look for this line on startup:**
```
Image generator initialized with OpenRouter (cost-optimized)
```

If you see this instead, OpenRouter isn't working:
```
Image generator initialized with Gemini
```

## 📊 Expected Response

### ✅ Success Response:

```json
{
  "illustrations": [
    {
      "id": "abc123_0",
      "prompt": "vibrant watercolor children's book illustration...",
      "image_url": "https://openrouter.ai/storage/...",
      "format": "png",
      "generated_at": "2025-11-29T..."
    }
  ],
  "count": 1,
  "used_user_key": false
}
```

### ❌ Error Response (if OpenRouter key is missing/invalid):

```json
{
  "error": "Image generation requires an API key",
  "hint": "Please provide your Gemini API key or upgrade to premium"
}
```

## 🔍 Troubleshooting

### Problem: Getting Gemini errors instead of OpenRouter

**Solution:**
1. Check Railway environment variables: `railway variables`
2. Verify `OPENROUTER_API_KEY` is set
3. Restart the Railway service: `railway restart`

### Problem: "OpenRouter API error: 401"

**Solution:**
- Your OpenRouter API key is invalid or expired
- Create a new key at https://openrouter.ai/keys
- Update Railway: `railway variables set OPENROUTER_API_KEY=sk-or-v1-...`

### Problem: "OpenRouter API error: 429"

**Solution:**
- You've hit the rate limit (free tier: ~10 images/minute)
- Wait 60 seconds and try again
- Consider upgrading your OpenRouter account

### Problem: Response has no image_url

**Solution:**
- Check Railway logs for detailed error: `railway logs`
- The Flux model might be temporarily unavailable
- The response format might have changed (rare)

## 💰 Cost Information

### OpenRouter (Current Setup):
- Model: `black-forest-labs/flux-1-schnell-free`
- Cost: **$0.00 per image** (FREE tier)
- Speed: ~3-5 seconds per image
- Rate Limit: ~10 images/minute

### Gemini (Fallback):
- Model: `gemini-imagen-2`
- Cost: ~$0.04 per image
- Speed: ~2-3 seconds per image
- Rate Limit: Depends on your API quota

## 🎯 Next Steps

1. **Test it now**: Run `test_openrouter_images.bat`
2. **Check the logs**: Confirm "OpenRouter (cost-optimized)" appears
3. **Update your key**: If you created a new one with limits/expiry
4. **Monitor usage**: Check https://openrouter.ai/activity for costs

## 📝 What Codex Meant

> **"Hooked the app to a cheaper image path"**
> = The backend now checks for `OPENROUTER_API_KEY` and uses it instead of Gemini

> **"Railway) to auto-use SDXL"**
> = When deployed to Railway with the env variable set, it auto-uses Stable Diffusion XL (via Flux)

> **"Trigger /generate-illustrations and watch logs"**
> = Send a POST request to the endpoint and check Railway logs to confirm OpenRouter is being used

> **"feature flag to switch providers per request/tier"**
> = Codex can add code to let you choose Gemini vs OpenRouter per API call or user tier

## ✨ Summary

**You're already set up!** Just:
1. Run `test_openrouter_images.bat` to verify
2. Check the logs to see "OpenRouter (cost-optimized)"
3. You should get back image URLs in the response

**No further setup needed** - your OpenRouter key is already in Railway and the code is already configured to use it!
