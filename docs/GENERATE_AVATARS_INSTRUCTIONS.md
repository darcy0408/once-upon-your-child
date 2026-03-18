# Avatar Library Generation Instructions

## Overview
This guide explains how to generate the 35 pre-made avatars for the avatar library.

**⏱️ Estimated Time:** ~2-3 hours total (avatars generate one at a time)
**💰 Cost:** ~$3-5 in API usage (35 avatars × ~$0.10 per generation)

---

## Prerequisites

1. **Gemini API Key** configured in `.env`
2. **Backend dependencies** installed
3. **Stable internet connection**

---

## Step 1: Test with a Single Avatar (Recommended)

Before generating all 35, test with one avatar to verify quality:

```bash
# From project root
cd backend
python scripts/generate_avatar_library.py --test
```

This will:
- Generate the first avatar (Pixar style, "Friendly Explorer")
- Save it to `backend/static/avatar_library/test/test_pixar_001.png`
- Let you verify quality before generating all 35

**Check the test image:**
```bash
# View the test image
start backend/static/avatar_library/test/test_pixar_001.png
```

**If it looks good, proceed to Step 2!**

**If it needs adjustment:**
- Edit prompts in `backend/scripts/generate_avatar_library.py`
- Adjust `build_avatar_prompt()` function
- Test again until satisfied

---

## Step 2: Generate All 35 Avatars

### Option A: Generate All at Once (Recommended)

```bash
python scripts/generate_avatar_library.py
```

This will:
- Generate all 35 avatars sequentially
- Save each as PNG (1024x1024)
- Create thumbnails (256x256)
- Create `avatars.json` metadata
- Take ~2-3 hours total with 5-second delays between generations

**Progress Display:**
```
[1/35] Generating: pixar_001 - Friendly Explorer
  Style: pixar | Age: 8 | girl
  Building prompt for Friendly Explorer...
  Calling Gemini API...
  ✅ Saved full-size: backend/static/avatar_library/pixar_001.png
  ✅ Saved thumbnail: backend/static/avatar_library/thumbs/pixar_001.png
  ✅ Complete!

  Waiting 5 seconds before next generation...
```

### Option B: Generate in Batches

If you want to generate in smaller batches:

```bash
# Generate first 10 (Pixar style)
python scripts/generate_avatar_library.py --limit 10

# Continue with next 9 (Watercolor style)
python scripts/generate_avatar_library.py --start 10 --limit 9

# Continue with next 8 (Cartoon style)
python scripts/generate_avatar_library.py --start 19 --limit 8

# Finish with last 8 (Clay style)
python scripts/generate_avatar_library.py --start 27 --limit 8
```

### Option C: Resume from a Specific Point

If the script stops or fails partway through:

```bash
# Resume from avatar #15
python scripts/generate_avatar_library.py --start 15
```

---

## Step 3: Verify Generated Avatars

After generation completes, check the results:

```bash
# View all generated files
dir backend/static/avatar_library

# Should see:
# - 35 PNG files (pixar_001.png through clay_008.png)
# - thumbs/ folder with 35 thumbnails
# - avatars.json metadata file
```

**Check metadata:**
```bash
type backend\static\avatar_library\avatars.json
```

Should show:
```json
{
  "version": "1.0",
  "generated_at": "2025-12-25T...",
  "total_avatars": 35,
  "avatars": [
    {
      "id": "pixar_001",
      "filename": "pixar_001.png",
      "thumbnail": "thumbs/pixar_001.png",
      "name": "Friendly Explorer",
      ...
    }
  ]
}
```

---

## Step 4: Quality Check

Manually review a sample of avatars to ensure:
- ✅ Non-photorealistic (clearly stylized)
- ✅ Age-appropriate
- ✅ Good quality and detail
- ✅ Diverse representation
- ✅ Matches template description

**View samples:**
```bash
# Open a few to check
start backend\static\avatar_library\pixar_001.png
start backend\static\avatar_library\watercolor_001.png
start backend\static\avatar_library\cartoon_001.png
start backend\static\avatar_library\clay_001.png
```

---

## Troubleshooting

### Problem: Script fails with "No module named..."

**Solution:**
```bash
# Make sure you're in the backend directory
cd backend

# Or run with full path
python -m scripts.generate_avatar_library
```

### Problem: "Gemini API quota exceeded"

**Solution:**
- Wait for quota to reset (usually daily)
- Or generate in smaller batches over multiple days
- Or upgrade API quota if needed

### Problem: Some avatars look photorealistic

**Solution:**
1. Delete the problematic avatar(s)
2. Edit the prompt in `build_avatar_prompt()` to emphasize style more
3. Regenerate just that one:
```python
# In Python console
from scripts.generate_avatar_library import test_single_avatar
test_single_avatar(index=5)  # Replace 5 with the problem index
```

### Problem: Avatar doesn't match description

**Solution:**
1. Check the template in `backend/data/avatar_templates.py`
2. Verify prompt is correct
3. Adjust template description if needed
4. Regenerate

---

## What Happens Next?

After generation, the avatars will be:
1. Served via Flask static route: `/static/avatar_library/pixar_001.png`
2. Displayed in the avatar gallery UI (to be built next)
3. Used as base images for AI refinement
4. Cached in browser for fast loading

---

## Cost Breakdown

**Per Avatar:**
- Generation time: ~30-60 seconds
- API cost: ~$0.08-0.15

**Total for 35 Avatars:**
- Time: 2-3 hours (with delays)
- Cost: ~$3-5
- Storage: ~50MB (full-size + thumbnails)

**This is a ONE-TIME cost!** Once generated, avatars are reused forever.

---

## Generation Statistics

After completion, you should have:

**By Style:**
- Pixar: 10 avatars (28.6%)
- Watercolor: 9 avatars (25.7%)
- Cartoon: 8 avatars (22.9%)
- Clay: 8 avatars (22.9%)

**By Gender:**
- Girl: 18 avatars (51.4%)
- Boy: 17 avatars (48.6%)

**By Skin Tone:**
- Very Light: 3 (8.6%)
- Light: 6 (17.1%)
- Medium Light: 4 (11.4%)
- Medium Tan: 6 (17.1%)
- Tan: 5 (14.3%)
- Brown: 5 (14.3%)
- Dark Brown: 4 (11.4%)
- Very Dark: 2 (5.7%)

**By Age:**
- 7-8 years: 12 (34.3%)
- 9-10 years: 13 (37.1%)
- 11-12 years: 10 (28.6%)

---

## Ready to Generate?

1. ✅ Test with single avatar
2. ✅ Review test result
3. ✅ Generate all 35 avatars
4. ✅ Verify completion
5. ✅ Quality check samples
6. ✅ Proceed to next phase (refinement service)

**Start here:**
```bash
cd backend
python scripts/generate_avatar_library.py --test
```

Good luck! 🎨✨
