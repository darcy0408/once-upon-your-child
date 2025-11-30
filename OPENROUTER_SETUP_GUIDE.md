# OpenRouter Image Generation Setup Guide

## ✅ What Codex Already Did

1. **Created OpenRouter Integration** (`backend/openrouter_image_generator.py`)
   - Uses Stable Diffusion XL (SDXL) via OpenRouter
   - Cost: ~$0.002-0.005 per image (100x cheaper than DALL-E!)
   - Compatible with your existing OpenRouter account

2. **Updated Backend** (`backend/app.py`)
   - Auto-detects OPENROUTER_API_KEY environment variable
   - Falls back to Gemini if OpenRouter key not available
   - Endpoint: `/generate-illustrations`

## ❌ What's Missing

**OPENROUTER_API_KEY is NOT set in Railway!**

Current Railway variables show:
- ✅ GEMINI_API_KEY (set)
- ❌ OPENROUTER_API_KEY (MISSING)

Without this key, the backend will use Gemini instead of OpenRouter (more expensive).

---

## 🚀 Step-by-Step Setup

### Step 1: Create OpenRouter API Key

1. **Go to OpenRouter:**
   - https://openrouter.ai/keys

2. **Create New Key:**
   - Name: `story-weaver-image`
   - Credit limit: Leave blank OR set to $10/month (recommended)
   - Reset limit: Monthly (recommended to prevent overspending)
   - Expiration: No expiration (or 30-60 days if you want to rotate)

3. **Copy the Key:**
   - It will look like: `sk-or-v1-...`
   - Save it somewhere safe (you'll need it in next step)

### Step 2: Add Key to Railway

**Option A: Via Railway CLI (Recommended - You're already logged in)**

```bash
# Add the OpenRouter API key to Railway
railway variables --set OPENROUTER_API_KEY=sk-or-v1-YOUR_KEY_HERE
```

Replace `sk-or-v1-YOUR_KEY_HERE` with your actual key.

**Option B: Via Railway Dashboard**

1. Go to https://railway.app
2. Open your project: "radiant-tranquility"
3. Click on "story-weaver-app" service
4. Go to "Variables" tab
5. Click "New Variable"
6. Name: `OPENROUTER_API_KEY`
7. Value: Paste your OpenRouter key
8. Click "Add"

### Step 3: Restart the Backend

The backend needs to restart to pick up the new environment variable.

**Via Railway CLI:**
```bash
railway up
```

OR

**Via Railway Dashboard:**
1. Go to your service
2. Click "Deployments"
3. Click "Redeploy" on the latest deployment

### Step 4: Verify It's Working

**Check Startup Logs:**
```bash
railway logs
```

Look for this line:
```
Image generator initialized with OpenRouter (cost-optimized)
```

If you see this, OpenRouter is active! ✅

If you see this instead:
```
Image generator initialized with Gemini
```

Then OpenRouter key wasn't picked up. ❌

---

## 🧪 Testing Image Generation

### Test 1: Via curl (Command Line)

**Local Backend (if running on port 5000):**
```bash
curl -X POST http://localhost:5000/generate-illustrations \
  -H "Content-Type: application/json" \
  -d "{\"scene_description\": \"A brave 7-year-old named Luna befriends a tiny dragon in a forest\", \"character_name\": \"Luna\", \"style\": \"vibrant watercolor children's book illustration\", \"num_images\": 1, \"age\": 7}"
```

**Production Backend:**
```bash
curl -X POST https://grand-light-production-68d9.up.railway.app/generate-illustrations \
  -H "Content-Type: application/json" \
  -d "{\"scene_description\": \"A brave 7-year-old named Luna befriends a tiny dragon in a forest\", \"character_name\": \"Luna\", \"style\": \"vibrant watercolor children's book illustration\", \"num_images\": 1, \"age\": 7}"
```

**Expected Response:**
```json
{
  "illustrations": [
    {
      "id": "uuid_0",
      "prompt": "...",
      "image_url": "https://...",
      "format": "png",
      "generated_at": "2025-11-29T..."
    }
  ],
  "count": 1,
  "used_user_key": false
}
```

### Test 2: Via Frontend

1. **Open the App:**
   - https://grand-light-production-68d9.up.railway.app

2. **Create a Story:**
   - Create a character
   - Select emotion
   - Check "Include illustration" ✅
   - Generate story

3. **Verify Image Appears:**
   - Story should display with an image
   - Image should be relevant to the story
   - Check browser console for any errors

### Test 3: Via Python Script (Local)

Codex created a test file you can run:

```bash
cd backend
python openrouter_image_generator.py
```

This will:
1. Load your OPENROUTER_API_KEY from environment
2. Generate a test illustration
3. Generate a test coloring page
4. Print the results

---

## 📊 Monitoring & Costs

### Check OpenRouter Usage

1. **Dashboard:**
   - https://openrouter.ai/activity

2. **What to Monitor:**
   - Requests per day
   - Cost per day
   - Total spend this month

### Expected Costs (With SDXL)

| Usage | Cost |
|-------|------|
| 10 images/day | ~$0.03/day = ~$0.90/month |
| 50 images/day | ~$0.15/day = ~$4.50/month |
| 100 images/day | ~$0.30/day = ~$9/month |
| 500 images/day | ~$1.50/day = ~$45/month |

**Compare to DALL-E:**
- 10 images/day = ~$12/month (13x more expensive!)

---

## 🐛 Troubleshooting

### Problem: "Image generator initialized with Gemini"

**Cause:** OPENROUTER_API_KEY not set or not picked up

**Fix:**
1. Verify key is set: `railway variables | grep OPENROUTER`
2. If not there, add it: `railway variables --set OPENROUTER_API_KEY=sk-or-v1-...`
3. Restart backend: `railway up`
4. Check logs: `railway logs`

### Problem: "OpenRouter API error: 401"

**Cause:** Invalid API key

**Fix:**
1. Verify key is correct in OpenRouter dashboard
2. Copy key again (make sure no extra spaces)
3. Update Railway: `railway variables --set OPENROUTER_API_KEY=sk-or-v1-...`
4. Restart backend

### Problem: "OpenRouter API error: 402"

**Cause:** No credits/insufficient credits

**Fix:**
1. Go to https://openrouter.ai/credits
2. Add credits ($5-10 should last a long time)
3. Try generating image again

### Problem: Images not showing in frontend

**Cause:** CORS or image URL issue

**Fix:**
1. Check browser console for errors
2. Verify image URL is accessible (copy URL, paste in browser)
3. Check if OpenRouter URLs are being returned (look at API response)

---

## 💰 Cost Optimization Tips

### Tip 1: Use SDXL (Already Configured)
- Model: `stabilityai/stable-diffusion-xl-base-1.0`
- Cost: ~$0.002-0.005 per image
- Quality: Great for children's book illustrations

### Tip 2: Set Monthly Credit Limit
- OpenRouter dashboard → API Key settings
- Set to $10/month (prevents surprise bills)
- Resets monthly automatically

### Tip 3: Monitor Usage Weekly
- Check https://openrouter.ai/activity
- If costs too high, adjust:
  - Reduce image size (currently 1024x1024)
  - Limit images to premium users only
  - Use cheaper model (flux-schnell: $0.003)

### Tip 4: Alternative Models (If SDXL Too Expensive)

Edit `backend/openrouter_image_generator.py` line 69:

**Current (SDXL):**
```python
"model": "stabilityai/stable-diffusion-xl-base-1.0",  # ~$0.004
```

**Cheaper Alternative:**
```python
"model": "black-forest-labs/flux-schnell",  # ~$0.003 (25% cheaper)
```

**Even Cheaper (Lower Quality):**
```python
"model": "stability-ai/stable-diffusion-2-1",  # ~$0.002
```

---

## 📝 Next Steps After Setup

1. **Verify Setup:**
   - [ ] OPENROUTER_API_KEY set in Railway
   - [ ] Backend restarted
   - [ ] Logs show "Image generator initialized with OpenRouter"

2. **Test:**
   - [ ] curl test passes
   - [ ] Frontend image generation works
   - [ ] Images display correctly in stories

3. **Monitor:**
   - [ ] Check OpenRouter usage after 1 day
   - [ ] Verify costs are reasonable
   - [ ] Adjust if needed

4. **Document:**
   - [ ] Add completion note to TEAM_COORDINATION.md
   - [ ] Update Gemini on testing status

---

## 🎯 Quick Command Reference

```bash
# Check if key is set
railway variables | grep OPENROUTER

# Set the key (replace with your actual key)
railway variables --set OPENROUTER_API_KEY=sk-or-v1-YOUR_KEY_HERE

# Restart backend
railway up

# Check logs
railway logs

# Test locally (if backend running)
cd backend
python openrouter_image_generator.py

# Test production endpoint
curl -X POST https://grand-light-production-68d9.up.railway.app/generate-illustrations \
  -H "Content-Type: application/json" \
  -d '{"scene_description": "A dragon in a forest", "character_name": "Luna", "num_images": 1}'
```

---

## ✅ Success Criteria

You'll know it's working when:

1. **Startup log shows:**
   ```
   Image generator initialized with OpenRouter (cost-optimized)
   ```

2. **API test returns:**
   ```json
   {"illustrations": [...], "count": 1, "used_user_key": false}
   ```

3. **Frontend displays images** in generated stories

4. **OpenRouter dashboard shows** requests and costs

5. **Cost is ~100x cheaper** than DALL-E (~$0.004 vs ~$0.04 per image)

---

**Ready to proceed?** Start with Step 1 above (create OpenRouter API key), then let me know when you have the key and I'll help you add it to Railway!
