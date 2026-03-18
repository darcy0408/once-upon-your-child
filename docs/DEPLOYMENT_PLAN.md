# Story Weaver App - Deployment Plan

**Date:** 2026-01-10
**Status:** Active
**Last Updated:** After computer restart and codebase synchronization

---

## Executive Summary

The Story Weaver App uses a **two-tier deployment architecture**:
- **Backend (Flask/Python API):** Railway
- **Frontend (Flutter Web):** Netlify or Railway (both options available)

All compilation errors have been **resolved**. The app is ready for deployment.

---

## Current Deployment Status

### Backend Service
- **Platform:** Railway
- **URL:** `https://story-weaver-app-production.up.railway.app`
- **Status:** ✅ Deployed (as of Jan 7, 2026)
- **Configuration:** `railway.json`, `Dockerfile`
- **Start Command:** `gunicorn wsgi:app --bind 0.0.0.0:$PORT --timeout 120 --workers 2`
- **Health Check:** `/health` endpoint
- **Workers:** 2 gunicorn workers
- **Timeout:** 120 seconds

### Frontend Service
- **Platform Options:**
  1. **Netlify** (primary, as mentioned in TEAM_COORDINATION.md Jan 7)
  2. **Railway** (multi-service config available in `railway.toml`)
- **Build Output:** `build/web`
- **Configuration Files:**
  - Netlify: `netlify.toml`
  - Railway: `railway.toml`, `Dockerfile.frontend`
- **Build Command:** `flutter build web --release --dart-define=FLUTTER_WEB_USE_SKIA=true --dart-define=FLAVOR=production`

### Build Flavors
1. **Production:**
   - Backend: `https://story-weaver-app-production.up.railway.app`
   - No banner

2. **Staging:**
   - Backend: `https://story-weaver-staging.up.railway.app`
   - Orange banner with "STAGING" label

3. **Development:**
   - Backend: `http://127.0.0.1:5000` (or `http://10.0.2.2:5000` on Android)
   - Green banner with "DEV" label

---

## Recent Changes (Jan 10, 2026)

### Compilation Fixes Applied
1. **avatar_gallery_selector.dart:**
   - Replaced `APIServiceManager().baseUrl` with `Environment.backendUrl`
   - Fixed import to use `../config/environment.dart`
   - Updated `GeneratedAvatar` constructor calls to match model signature

2. **therapeutic_feelings_wheel.dart:**
   - Changed `coreEmotions` to `FeelingsWheelData.coreEmotions` (3 locations)

### Analysis Results
- ✅ **No compilation errors**
- ⚠️ 368 warnings (mostly deprecated `withOpacity` method, `print` statements, unused elements)
- 🟢 **App is ready to run**

---

## Deployment Options

### Option 1: Railway (Backend) + Netlify (Frontend) - RECOMMENDED
**Best for:** Production deployment with CDN benefits

**Pros:**
- Netlify provides global CDN for fast frontend delivery
- Railway handles backend with good Python support
- Separate scaling of frontend and backend
- Free tier available for both services

**Cons:**
- Requires managing two platforms
- Cross-origin requests need CORS configuration

**Deployment Steps:**

#### Backend (Railway)
1. Connect Railway to GitHub repository
2. Deploy using `railway.json` configuration
3. Set environment variables:
   ```
   FLASK_ENV=prod
   FLASK_CONFIG=prod
   GEMINI_API_KEY=<your-key>
   PORT=<auto-set-by-railway>
   ```
4. Verify health check at `/health`

#### Frontend (Netlify)
1. Connect Netlify to GitHub repository
2. Build settings:
   - **Build command:** `source .netlify/install_flutter.sh && flutter build web --release --dart-define=FLUTTER_WEB_USE_SKIA=true --dart-define=FLAVOR=production`
   - **Publish directory:** `build/web`
3. Redirects are configured in `netlify.toml`
4. Verify deployment

**Current Status:** This appears to be the active deployment (based on Jan 7 TEAM_COORDINATION.md entry)

---

### Option 2: Railway (Backend + Frontend) - ALTERNATIVE
**Best for:** Simplified single-platform management

**Pros:**
- Single platform to manage
- Internal Railway networking between services
- Unified billing
- Simplified CORS configuration

**Cons:**
- No global CDN (unless using Railway's CDN feature)
- Potentially higher costs for frontend serving

**Deployment Steps:**

1. Use `railway.toml` configuration for multi-service deployment
2. Deploy both services:
   - Backend: Uses `Dockerfile`
   - Frontend: Uses `Dockerfile.frontend`
3. Set environment variables:
   ```
   # Backend
   FLASK_ENV=prod
   FLASK_CONFIG=prod
   GEMINI_API_KEY=<your-key>

   # Frontend
   BACKEND_URL=${{backend.RAILWAY_PRIVATE_DOMAIN}}
   ```
4. Frontend will be built with `--dart-define=CUSTOM_BACKEND_URL=$BACKEND_URL`

---

## Environment Variables Checklist

### Backend (Railway)
- [ ] `FLASK_ENV=prod`
- [ ] `FLASK_CONFIG=prod`
- [ ] `GEMINI_API_KEY=<your-gemini-api-key>`
- [ ] `PORT` (auto-set by Railway)
- [ ] Database credentials (if using PostgreSQL)
- [ ] Any secret keys for sessions/JWT

### Frontend (Netlify)
- [ ] No environment variables needed at runtime (build-time only)
- [ ] Build-time: `FLAVOR=production` (via `--dart-define`)

### Frontend (Railway - if using Option 2)
- [ ] `BACKEND_URL` (set to backend service URL)

---

## Verification Steps After Deployment

### Backend Health Check
```bash
curl https://story-weaver-app-production.up.railway.app/health
```
Expected response: `{"status": "healthy"}` or similar

### Frontend Access
1. Navigate to deployed URL
2. Verify app loads without errors
3. Check browser console for errors
4. Test story generation flow (requires backend connectivity)

### Integration Test
1. Create a character in the frontend
2. Generate a story
3. Verify story displays correctly
4. Check backend logs for any errors

---

## Current Issues & Recommendations

### ⚠️ Code Quality
- **368 warnings** should be addressed:
  - Replace deprecated `withOpacity()` with `withValues()`
  - Replace `print()` statements with `debugPrint()`
  - Remove unused methods and elements

### 🚀 Avatar Images
- User is generating remaining avatars (80 left of 155 total)
- Current: 55 avatars optimized (1.86MB)
- Projected final size: ~5-6MB for all 155 avatars
- Avatars are bundled in app during development
- **Recommendation:** Follow `CLOUDFLARE_CDN_SETUP.md` for production (zero-cost hosting)

### 🔍 Deployment Verification Needed
- **Action required:** Verify that both services are currently deployed and running
- Check Railway dashboard for backend status
- Check Netlify dashboard for frontend status
- Test live URLs

---

## Next Steps

1. **Immediate:**
   - [ ] Verify backend is running on Railway
   - [ ] Verify frontend is running on Netlify
   - [ ] Test the live application end-to-end
   - [ ] Check that avatar gallery functionality works

2. **Short-term:**
   - [ ] Complete remaining 80 Midjourney avatars
   - [ ] Optimize and integrate new avatars
   - [ ] Consider addressing high-priority warnings
   - [ ] Set up monitoring/error tracking (e.g., Sentry)

3. **Long-term:**
   - [ ] Implement Cloudflare CDN for avatars (as per `CLOUDFLARE_CDN_SETUP.md`)
   - [ ] Set up staging environment
   - [ ] Implement CI/CD pipeline
   - [ ] Address all code quality warnings

---

## Rollback Procedure

If deployment fails:

### Backend Rollback (Railway)
1. Go to Railway dashboard
2. Navigate to deployments
3. Click "Redeploy" on last successful deployment
4. Verify `/health` endpoint responds

### Frontend Rollback (Netlify)
1. Go to Netlify dashboard
2. Navigate to "Deploys"
3. Find last successful deployment
4. Click "Publish deploy"

---

## Support Documentation

- `TEAM_COORDINATION.md` - Team activity log
- `CLOUDFLARE_CDN_SETUP.md` - Avatar CDN setup guide
- `MIDJOURNEY_AVATAR_INTEGRATION_GUIDE.md` - Avatar integration guide
- `netlify.toml` - Netlify configuration
- `railway.json` / `railway.toml` - Railway configurations
- `Dockerfile` - Backend container config
- `Dockerfile.frontend` - Frontend container config

---

## Contact & Access

**Repository:** (GitHub URL would go here)
**Railway Project:** (Railway project ID/URL)
**Netlify Site:** (Netlify site ID/URL)

**Access needed for deployment:**
- GitHub repository access
- Railway account with project access
- Netlify account with site access

---

## Notes from Computer Restart Session

- Multiple Claude and Gemini instances were working on different parts
- All instances logged their work in `TEAM_COORDINATION.md`
- Compilation errors were introduced in:
  - `avatar_gallery_selector.dart` (API service manager usage)
  - `therapeutic_feelings_wheel.dart` (feelings data access)
- All errors have been **resolved** ✅
- App successfully compiles with only warnings

---

**Prepared by:** Claude (Post-restart recovery session)
**Review Status:** Ready for user approval and deployment verification
