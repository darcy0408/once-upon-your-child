# Midjourney Batch Generation Workflow

**Goal:** Generate 100 avatars efficiently using Midjourney
**Current:** 55 avatars done, 100 to go (from MIDJOURNEY_100_PROMPTS.md)

---

## What I Can Do vs What You Need to Do

### ✅ What I CAN Do (Automated):
- Extract all 100 prompts into a copy-paste format
- Create a numbered checklist to track progress
- Prepare the optimization script (already exists!)
- Organize downloaded images for processing

### ⚠️ What YOU Need to Do (Manual - Midjourney requires it):
- Have a Midjourney subscription ($10-$30/month)
- Copy-paste prompts into Discord Midjourney bot
- Download generated images
- Run my optimization script

---

## Fastest Workflow (1-2 hours total)

### Phase 1: Batch Generate in Midjourney (30-60 min)

**Setup:**
1. Open Discord with Midjourney bot
2. Open `MIDJOURNEY_100_PROMPTS.md` in another window
3. Have `avatarImages/` folder open

**Process:**
```
1. Copy prompt #1 from file
2. Paste in Discord: /imagine [prompt]
3. Wait 30-60 seconds for generation
4. Click "U1" to upscale (or best version)
5. Right-click → Save image as "56.png" (continuing from your current 55)
6. IMMEDIATELY copy prompt #2 while waiting
7. Repeat!
```

**Pro Tips:**
- Use `/relax` mode if you have Standard plan (unlimited generations)
- Use `/fast` for higher priority (uses fast hours)
- Generate 5-10 at a time, then batch-download
- Number files sequentially: 56.png, 57.png, ..., 155.png

### Phase 2: Batch Optimize (5 minutes)

Once you have all 100 images in `avatarImages/`:

```bash
cd backend/tools
python optimize_avatars.py
```

**What this does automatically:**
- Converts PNG → WebP
- Resizes to 512x512px
- Optimizes quality (reduces 95%+ file size!)
- Backs up originals to `avatarImages/originals/`
- Creates optimized versions in `avatarImages/optimized/`

### Phase 3: Integrate into App (2 minutes)

```bash
# Copy optimized avatars to Flutter assets
cp avatarImages/optimized/*.webp assets/avatars/midjourney/

# Refresh Flutter
flutter pub get

# Test
flutter run -d chrome
```

Done! 155 avatars ready! 🎉

---

## Option: I Can Create a Checklist Tool

Would you like me to create a script that:

1. **Extracts all 100 prompts** into a simple text file (easy copy-paste)
2. **Creates a checklist** to track which ones you've done
3. **Auto-renames files** (you download as image1.png, script renames to 56.png, 57.png, etc.)

This would save you a ton of time organizing!

---

## Time Estimates

| Task | Time | Your Effort |
|------|------|-------------|
| Generate 100 avatars | 30-60 min | Manual (copy-paste prompts) |
| Download images | 5-10 min | Manual (click save) |
| Optimize images | 2-5 min | Automated (run script) |
| Integrate into app | 2 min | Automated (copy command) |
| **TOTAL** | **40-77 min** | ~30 min manual, ~10 min automated |

---

## Cost Estimate

**Midjourney Subscription:**
- **Basic Plan:** $10/month (200 fast generations) - Perfect for this!
- **Standard Plan:** $30/month (Unlimited relaxed) - Overkill unless you need more
- **You need:** 100 generations = $10 Basic plan is enough

**One-time cost:** $10 for Midjourney subscription this month

---

## Alternative: Batch via API (If You Want Full Automation)

Midjourney has an **unofficial API** that could let me automate this, but:
- ⚠️ Requires API key setup
- ⚠️ Not officially supported
- ⚠️ Might be against Midjourney ToS
- ⚠️ More complex setup

**My recommendation:** Just do the manual copy-paste method above. 30 minutes of your time, guaranteed to work!

---

## Want Me to Create the Helper Tools?

I can create:

### Tool 1: Prompt Extractor
```python
# Extracts all 100 prompts into prompts.txt
# One per line, easy to copy-paste
```

### Tool 2: Auto-Renamer
```python
# Renames downloaded images automatically
# image1.png → 56.png
# image2.png → 57.png
# etc.
```

### Tool 3: Progress Tracker
```python
# Interactive checklist
# Mark each prompt as done
# Shows progress: 45/100 complete
```

Should I create these tools for you?

---

## Ready to Start?

**Quick Start:**

1. Subscribe to Midjourney ($10 Basic)
2. Open Discord + MIDJOURNEY_100_PROMPTS.md
3. Copy prompt #1, paste in Discord `/imagine [prompt]`
4. Download as 56.png (continuing from your 55)
5. Repeat 99 more times!
6. Run optimization script
7. Done!

**Want help?** Let me know and I'll create those helper tools above!
