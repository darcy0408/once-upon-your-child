# Story Weaver App - Complete Deployment Guide

**Goal:** Deploy with minimal cost, maximum reliability
**Strategy:** Netlify free tier (frontend) + Railway paid (backend), with Railway backup ready

> **⚠️ ARCHIVED (2026-07-17):** This guide's Netlify/Railway frontend strategy is obsolete. Frontend is now **Cloudflare Pages** at onceuponyourchild.app (cutover 2026-07-15; the Netlify site and the Railway `grand-light` frontend service have both been deleted). Backend remains on Railway per Part 3/Option B below. Kept for historical reference only — do not follow the Netlify steps.

---

## Quick Decision Guide

### Use Netlify Free If:
- ✅ It's a new month (free tier reset)
- ✅ You can monitor bandwidth usage
- ✅ You're okay switching mid-month if needed

### Switch to Railway If:
- ⚠️ Netlify shows >80GB used this month
- ⚠️ You want simpler management (one platform)
- ⚠️ You need predictable costs

---

## Part 1: Backend Deployment (Railway) - ALREADY DONE ✅

Your backend should already be running. Let's verify:

### Step 1.1: Check Railway Backend Status

1. Go to https://railway.app/
2. Log in to your account
3. Find "story-weaver-app-production" (or similar project name)
4. Check if backend service is running
5. Copy the backend URL (should be like: `https://story-weaver-app-production.up.railway.app`)

### Step 1.2: Test Backend

Open terminal and run:
```bash
curl https://story-weaver-app-production.up.railway.app/health
```

**Expected Response:**
```json
{"status": "healthy"}
```

If this works → Backend is good! ✅

If not → Let me know the error and we'll fix it.

---

## Part 2: Frontend Deployment (Choose Your Path)

### 🎯 OPTION A: Netlify (FREE) - RECOMMENDED TO START

#### Step A1: Check Netlify Status

1. Go to https://netlify.com/
2. Log in to your account
3. Check current month's bandwidth usage (Dashboard → Account → Bandwidth)
4. If < 20GB used → You're good to proceed!

#### Step A2: Build the Frontend Locally (TEST)

```bash
# Make sure you're in the project root
cd C:\dev\story-weaver-app

# Build for production
flutter build web --release --dart-define=FLUTTER_WEB_USE_SKIA=true --dart-define=FLAVOR=production
```

**Expected output:** `build/web/` folder created

#### Step A3: Deploy to Netlify

**Method 1: Netlify CLI (Easiest)**

```bash
# Install Netlify CLI (if not installed)
npm install -g netlify-cli

# Login to Netlify
netlify login

# Deploy (from project root)
netlify deploy --prod --dir=build/web
```

**Method 2: Netlify Web UI**

1. Go to Netlify dashboard
2. Click "Add new site" → "Deploy manually"
3. Drag and drop the `build/web` folder
4. Done!

**Method 3: GitHub Auto-Deploy (Best for ongoing updates)**

1. Push your code to GitHub
2. In Netlify: "Add new site" → "Import from Git"
3. Select your repository
4. Build settings:
   - **Build command:** `flutter build web --release --dart-define=FLUTTER_WEB_USE_SKIA=true --dart-define=FLAVOR=production`
   - **Publish directory:** `build/web`
5. Add build image: Go to "Site settings" → "Build & deploy" → "Environment" → Add:
   ```
   Build image: Ubuntu Focal 20.04
   ```
6. Create `.netlify/install_flutter.sh` script (see below)
7. Deploy!

#### Step A4: Monitor Bandwidth

**Important:** Check bandwidth weekly!

1. Netlify Dashboard → Account → Bandwidth
2. If you see >80GB → Time to switch to Railway
3. Each avatar load, each page view counts toward bandwidth

---

### 🎯 OPTION B: Railway (PAID but PREDICTABLE)

#### Step B1: Prepare Frontend for Railway

Your `railway.toml` already has frontend config! Just need to deploy it.

#### Step B2: Deploy Frontend to Railway

**Option 1: Railway CLI**

```bash
# Install Railway CLI
npm i -g @railway/cli

# Login
railway login

# Link to your project
railway link

# Deploy frontend service
railway up --service frontend
```

**Option 2: Railway Dashboard**

1. Go to your Railway project
2. Click "New Service"
3. Select "GitHub Repo"
4. Choose your repository
5. Configure:
   - **Name:** frontend
   - **Dockerfile:** Dockerfile.frontend
   - **Environment Variables:**
     ```
     BACKEND_URL=https://story-weaver-app-production.up.railway.app
     ```
6. Deploy!

#### Step B3: Configure Backend URL in Frontend

Railway will build with this:
```bash
--dart-define=CUSTOM_BACKEND_URL=$BACKEND_URL
```

This overrides the default backend URL in `flavor_config.dart`.

---

## Part 3: Verification Checklist

### ✅ Backend Tests

```bash
# Health check
curl https://your-backend-url.up.railway.app/health

# Test story generation endpoint
curl -X POST https://your-backend-url.up.railway.app/generate-story \
  -H "Content-Type: application/json" \
  -d '{"character":"Test","theme":"adventure","age":8}'
```

### ✅ Frontend Tests

1. **Load the site:** Open your frontend URL
2. **Check console:** Open browser DevTools (F12), look for errors
3. **Test features:**
   - [ ] Homepage loads
   - [ ] Character creation works
   - [ ] Avatar gallery displays (55 avatars)
   - [ ] Story generation works (connects to backend)
   - [ ] Stories display correctly

### ✅ Integration Test

Full end-to-end test:

1. Create a new character
2. Choose an avatar from gallery
3. Select feelings on the wheel
4. Generate a story
5. Read the story
6. Verify no errors in browser console

---

## Part 4: Monitoring & Switching

### Monitor Netlify Bandwidth (If using Netlify)

**Weekly check:**
```
Week 1: Should be < 25GB
Week 2: Should be < 50GB
Week 3: Should be < 75GB
Week 4: Should be < 100GB
```

**If you exceed 80GB before month end:**

→ **Switch to Railway immediately**

### How to Switch from Netlify to Railway

1. Deploy frontend to Railway (follow Option B above)
2. Update your DNS/domain to point to Railway URL
3. Pause Netlify site (Settings → General → "Stop builds")
4. Done! No code changes needed.

---

## Part 5: Cost Breakdown

### Current Setup (Netlify Free + Railway Backend)

| Service | Cost | Bandwidth | Notes |
|---------|------|-----------|-------|
| Netlify (Free) | $0 | 100GB/month | Resets monthly |
| Railway Backend | ~$5-20 | Unlimited | Based on usage |
| **Total** | **$5-20/month** | | |

### If You Switch to Railway for Both

| Service | Cost | Bandwidth | Notes |
|---------|------|-----------|-------|
| Railway Backend | ~$5-10 | Unlimited | Existing cost |
| Railway Frontend | ~$5-10 | Unlimited | Additional cost |
| **Total** | **$10-20/month** | | |

### Bandwidth Estimates

With 55 avatars (1.86MB optimized):
- **Per user visit:** ~5-10MB (first visit with avatars)
- **Repeat visits:** ~1-2MB (cached avatars)
- **100GB = ~2,000-10,000 users/month** (depends on caching)

With 155 avatars (5-6MB optimized):
- **Per user visit:** ~8-15MB (first visit)
- **100GB = ~1,300-6,600 users/month**

---

## Part 6: Domain Setup (Optional but Recommended)

### Connect Custom Domain

**Netlify:**
1. Netlify Dashboard → Domain settings
2. Add custom domain (e.g., `storyweaver.app`)
3. Update DNS records with your registrar
4. Netlify provides SSL automatically

**Railway:**
1. Railway Dashboard → Settings → Domains
2. Add custom domain
3. Update DNS records (CNAME to Railway)
4. SSL automatic

---

## Files You'll Need

### `.netlify/install_flutter.sh`

Create this file for Netlify builds:

```bash
#!/bin/bash
set -e

# Install Flutter
if [ ! -d "$HOME/flutter" ]; then
  git clone https://github.com/flutter/flutter.git -b stable --depth 1 $HOME/flutter
fi

export PATH="$PATH:$HOME/flutter/bin"
flutter doctor
flutter pub get
```

Make it executable:
```bash
chmod +x .netlify/install_flutter.sh
```

### `nginx.conf` (for Railway frontend)

Already exists in your project! Used by `Dockerfile.frontend`.

---

## Troubleshooting

### Issue: Flutter build fails on Netlify

**Solution:**
1. Check build logs for specific error
2. Verify `.netlify/install_flutter.sh` is executable
3. Try building locally first: `flutter build web --release`

### Issue: Frontend can't connect to backend

**Symptoms:** Stories won't generate, console shows CORS errors

**Solution:**
1. Check backend is running: `curl https://your-backend.up.railway.app/health`
2. Verify `flavor_config.dart` has correct backend URL
3. Check backend CORS settings in `backend/app.py`

### Issue: Avatars not loading

**Symptoms:** Gallery shows broken images

**Solution:**
1. Verify `assets/avatars/midjourney/*.webp` files exist
2. Check `pubspec.yaml` includes assets path
3. Run `flutter pub get` and rebuild

### Issue: "Out of bandwidth" on Netlify

**Solution:** Switch to Railway (follow Part 2, Option B)

---

## Emergency Rollback

### Netlify Rollback
1. Dashboard → Deploys
2. Find last working deploy
3. Click "Publish deploy"
4. Done in ~30 seconds

### Railway Rollback
1. Dashboard → Deployments
2. Click last successful deployment
3. Click "Redeploy"
4. Done in ~2-3 minutes

---

## Next Steps After Deployment

1. **Test thoroughly** - Use the verification checklist above
2. **Set up monitoring:**
   - Netlify bandwidth (if using)
   - Railway usage dashboard
   - Consider Sentry for error tracking
3. **Generate remaining avatars** - 80 more to go!
4. **Update documentation** - Document your final URLs

---

## My Recommendation

**START HERE:**

1. ✅ **Verify backend is running on Railway** (should already be done)
2. ✅ **Check Netlify bandwidth** - Is it < 20GB this month?
   - **YES** → Deploy to Netlify (free!)
   - **NO** → Deploy to Railway
3. ✅ **Monitor weekly** - Set a calendar reminder
4. ✅ **Have Railway ready** - If Netlify hits 80GB, switch immediately

**This gives you the lowest cost while keeping a safety net!**

---

## Questions?

- "How do I check which is deployed now?" → Check Railway and Netlify dashboards
- "Can I use both?" → No, pick one for frontend (backend stays on Railway)
- "What if I hit limits?" → Switch to Railway mid-month, no downtime
- "How do I save costs?" → Use Cloudflare CDN for avatars (separate guide)

---

**Ready to deploy?** Start with Part 1 (verify backend), then choose Option A or B for frontend!
