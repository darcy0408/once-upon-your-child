# Pick-A-Path Image Generation Guide

## Current Status: FREE Testing Mode ✅

Your app is currently in **MOCK_TESTING_MODE**, which means:
- ✅ Image generation code runs without errors
- ✅ **NO API calls made** = **$0.00 cost**
- ✅ Stories generate normally (just without images)
- ✅ Safe to test as much as you want

## How Images Work

### Testing Mode (Current - FREE)
```env
# backend/.env
MOCK_TESTING_MODE=true
```
- Image generation returns instantly
- No API calls
- No costs
- Perfect for development

### Production Mode (When Ready)
```env
# backend/.env
MOCK_TESTING_MODE=false
REPLICATE_API_TOKEN=r8_xxxxxxxxxxxxxxxxxxxxx
```
- Real images generated via Replicate API
- Cost: ~$0.003 per image (3/10th of a cent)
- Example: 100 stories × 7 segments = 700 images = **$2.10**

## Enabling Real Images (When Ready)

### Step 1: Get Replicate API Token (Free Tier Available)

1. Go to https://replicate.com
2. Sign up for free account
3. Go to https://replicate.com/account/api-tokens
4. Create new token
5. Copy the token (starts with `r8_`)

### Step 2: Add Token to Backend

Edit `backend/.env`:
```env
REPLICATE_API_TOKEN=r8_your_token_here
MOCK_TESTING_MODE=false
```

### Step 3: Restart Backend

```bash
cd backend
python app.py
```

That's it! Images will now generate for real.

## Cost Breakdown

Using **SDXL-Lightning** (fastest, cheapest model):

| Item | Cost |
|------|------|
| Per image | $0.003 |
| Per story (7 segments) | $0.021 |
| 100 stories | $2.10 |
| 1,000 stories | $21.00 |

### Compared to Other Services:
- **DALL-E 3**: $0.04 per image (13x more expensive)
- **Stability AI**: $0.01 per image (3x more expensive)
- **Replicate SDXL-Lightning**: $0.003 per image ✅ **CHEAPEST**

## Image Quality

SDXL-Lightning produces:
- High quality children's book style illustrations
- Fast generation (~2-4 seconds per image)
- Age-appropriate styles (automatically adjusted)
- Consistent character appearance
- Companion characters included

## Testing Before Going Live

1. **Keep MOCK_TESTING_MODE=true** while developing
2. Test all your story flows
3. When ready for images, generate **1-2 test stories** with real mode
4. Check image quality
5. If satisfied, deploy to production

## Monitoring Costs

Check your Replicate usage at:
https://replicate.com/account/billing

They show:
- Real-time costs
- Per-model breakdown
- Daily/monthly totals

## Alternative: Free Self-Hosted Option

If you want **$0 cost** images, you can:
1. Run Stable Diffusion locally (requires GPU)
2. Use the model for free
3. Slower but completely free

Let me know if you want help setting this up!

## Questions?

- **Q: Will this slow down my app?**
  - A: In mock mode, NO (instant). In real mode, images generate in ~2-4 seconds but users still get their story text immediately.

- **Q: Can I disable images for certain stories?**
  - A: Yes, just don't include `image_description` in the segment data.

- **Q: Can I change the art style?**
  - A: Yes! Edit the prompts in `backend/replicate_image_generator.py`

- **Q: What happens if I run out of Replicate credits?**
  - A: Image generation fails gracefully - stories still work, just without images.
