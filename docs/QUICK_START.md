# Story Weaver - Quick Start Guide

**Updated:** 2026-01-10 (Post-restart recovery)

---

## ✅ Current Status

- **Backend:** Railway (deployed, running)
- **Frontend:** Choose deployment method below
- **App:** Compiles successfully ✅
- **Avatars:** 55/155 complete (80 remaining)

---

## 🚀 1. Deploy Your App (Choose One)

### Option A: Free to Start (Recommended)
```bash
# Deploy frontend to Netlify (free 100GB/month)
# Backend stays on Railway (already deployed)

# See: DEPLOYMENT_GUIDE_COMPLETE.md → Part 2, Option A
```

**When to switch:** If you hit 80GB bandwidth this month

### Option B: Predictable Cost
```bash
# Deploy both to Railway ($10-20/month total)
# One platform, no bandwidth worries

# See: DEPLOYMENT_GUIDE_COMPLETE.md → Part 2, Option B
```

---

## 🎨 2. Generate Remaining Avatars (80 to go!)

### Quick Method (30-60 minutes of work):

```bash
# Step 1: Extract prompts for easy copy-paste
python tools/extract_prompts.py

# Step 2: Open Discord + Midjourney
# Copy prompts from prompts_to_copy.txt
# Paste in Discord: /imagine [prompt]
# Download each as 56.png, 57.png, etc.

# Step 3: Track your progress (optional but helpful!)
python tools/progress_tracker.py

# Step 4: Optimize all new avatars
cd backend/tools
python optimize_avatars.py

# Step 5: Copy to Flutter assets
cp avatarImages/optimized/*.webp assets/avatars/midjourney/
flutter pub get

# Done! 155 avatars ready! 🎉
```

**Cost:** $10 for Midjourney Basic subscription (one month)

---

## 🧪 3. Test Locally

```bash
# Run the app
flutter run -d chrome

# Test these features:
# ✅ Homepage loads
# ✅ Character creation
# ✅ Avatar gallery (all avatars display)
# ✅ Feelings wheel
# ✅ Story generation
```

---

## 📚 Full Documentation

| File | Purpose |
|------|---------|
| `DEPLOYMENT_GUIDE_COMPLETE.md` | Complete deployment instructions (Netlify or Railway) |
| `DEPLOYMENT_PLAN.md` | Architecture overview and technical details |
| `MIDJOURNEY_BATCH_WORKFLOW.md` | Avatar generation workflow |
| `TEAM_COORDINATION.md` | Team activity log (all work from previous instances) |

---

## 🛠️ Helper Tools Created

All in `tools/` folder:

1. **extract_prompts.py** - Extract all 100 Midjourney prompts for easy copy-paste
2. **rename_batch.py** - Auto-rename downloaded images (image1.png → 56.png)
3. **progress_tracker.py** - Interactive checklist to track which avatars are done

Plus existing:
4. **optimize_avatars.py** (in `backend/tools/`) - Optimize avatars (PNG → WebP, resize)

---

## 💰 Cost Summary

| Scenario | Monthly Cost | Notes |
|----------|--------------|-------|
| **Option A: Netlify + Railway** | $5-20 | Free if < 100GB bandwidth |
| **Option B: Railway Only** | $10-20 | Predictable, no bandwidth worry |
| **Midjourney (one-time)** | $10 | For remaining 80 avatars |

**Recommended:** Start with Option A, switch to B if needed mid-month

---

## ❓ Common Questions

**Q: Which deployment should I use?**
A: Try Netlify free tier first (resets monthly), Railway as backup

**Q: How long to generate 80 avatars?**
A: 30-60 minutes of copy-paste work + 5 min optimization

**Q: Can you automate Midjourney?**
A: No direct access, but the tools above make it much faster!

**Q: What if I hit Netlify limits?**
A: Switch to Railway mid-month (see DEPLOYMENT_GUIDE_COMPLETE.md)

**Q: How do I verify backend is running?**
A: `curl https://story-weaver-app-production.up.railway.app/health`

---

## 🎯 Recommended Next Steps

1. **Today:**
   - [ ] Verify backend is running on Railway
   - [ ] Deploy frontend (choose Option A or B)
   - [ ] Test the live app

2. **This Week:**
   - [ ] Generate remaining 80 avatars (30-60 min work)
   - [ ] Optimize and integrate them
   - [ ] Test with all 155 avatars

3. **Later:**
   - [ ] Set up Cloudflare CDN for avatars (zero cost hosting)
   - [ ] Add monitoring/error tracking
   - [ ] Fix deprecation warnings

---

## 🆘 Need Help?

**Compilation errors?** All fixed! ✅

**Deployment issues?** See DEPLOYMENT_GUIDE_COMPLETE.md

**Avatar workflow questions?** See MIDJOURNEY_BATCH_WORKFLOW.md

**Something else?** Check TEAM_COORDINATION.md for what each instance worked on

---

**Ready to deploy?** Start with section 1 above! 🚀
