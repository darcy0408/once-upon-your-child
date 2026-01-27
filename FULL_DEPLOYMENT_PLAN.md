# Story Weaver App - Full Deployment Plan

**Date:** 2026-01-26
**Status:** Ready for Execution
**Version:** 3.0

---

## Executive Summary

Story Weaver is a therapeutic AI storytelling app for children ages 3-17+. It occupies a unique market position combining:
- AI-generated personalized stories (like StoryBee/Oscar)
- Therapeutic framework (like Zoy/Storybook)
- **3-Level Feelings Wheel** with 124 custom face expressions (unique to Story Weaver)

This plan covers deploying the app to production with the Feelings Wheel as the core differentiator.

---

## Current Architecture

| Component | Technology | Deployment |
|-----------|------------|------------|
| Frontend | Flutter Web | Netlify |
| Backend | Flask/Python | Railway |
| Database | PostgreSQL | Railway (auto) |
| AI | Gemini API | Google Cloud |
| CDN | Cloudflare | Optional |

---

## Pre-Deployment: Critical Fixes

### 1. Feelings Wheel Refactor (BEFORE DEPLOYMENT)

See `FEELINGS_WHEEL_REFACTOR_PLAN.md` for full details.

**Quick Summary:**
- [ ] Remove inappropriate emotions (Aroused, Intimate, Violated, Auctiole)
- [ ] Refactor wheel to use progressive REPLACEMENT (not concentric rings)
- [ ] Verify all 124 face images load correctly

**Why Critical:** The Feelings Wheel is your competitive differentiator. It must work flawlessly.

### 2. Recent Bug Fixes (Already Committed)

| Date | Fix | Status |
|------|-----|--------|
| 01-24 | Character persistence (offline sync) | ✅ |
| 01-24 | Illustration display fix | ✅ |
| 01-24 | Backend `illustrations` undefined fix | ✅ |
| 01-24 | Avatar URL vs base64 handling | ✅ |
| 01-24 | Age-gated feelings wheel restored | ✅ |
| 01-17 | Rate limiting on all routes | ✅ |
| 01-17 | Input validation & sanitization | ✅ |

---

## Phase 1: Pre-Deployment Verification

### 1.1 Code Quality Check

```bash
# Check git status
git status
git log origin/main..HEAD

# Run Flutter analyzer
flutter analyze

# Run tests
flutter test
cd backend && python -m pytest tests/ -v
```

### 1.2 Local Testing

```bash
# Start backend
cd backend
source venv/bin/activate  # or venv\Scripts\activate on Windows
flask run

# Start frontend (new terminal)
flutter run -d chrome
```

**Test Checklist:**
- [ ] Create character with avatar
- [ ] Select feeling using wheel (Age 6+)
- [ ] Select mood using MoodMagicPicker (Age ≤5)
- [ ] Generate story
- [ ] View illustrations (if MOCK_TESTING_MODE=false)
- [ ] Character persists after refresh

### 1.3 Build Verification

```bash
flutter build web --release --dart-define=FLAVOR=production
```

---

## Phase 2: Backend Deployment (Railway)

### 2.1 Railway Project Setup

**Project ID:** `36b27716-089f-4441-9b9d-af942a6df7aa`
**Dashboard:** https://railway.app/project/36b27716-089f-4441-9b9d-af942a6df7aa

### 2.2 Required Environment Variables

| Variable | Required | Value/Notes |
|----------|----------|-------------|
| `FLASK_ENV` | ✅ | `prod` |
| `FLASK_CONFIG` | ✅ | `prod` |
| `GEMINI_API_KEY` | ✅ | Get from https://aistudio.google.com/app/apikey |
| `SECRET_KEY` | ✅ | Generate: `python -c 'import secrets; print(secrets.token_hex(32))'` |
| `JWT_SECRET_KEY` | ✅ | Generate: `python -c 'import secrets; print(secrets.token_hex(32))'` |
| `DATABASE_URL` | ✅ | Auto-set by Railway PostgreSQL |
| `MOCK_TESTING_MODE` | Recommended | `false` for real AI, `true` for testing |
| `SENTRY_DSN` | Optional | Get from https://sentry.io |
| `ALLOWED_ORIGINS` | Recommended | Your Netlify URL |

### 2.3 Deploy Command

```bash
git push origin main  # Auto-deploys via Railway GitHub integration
```

### 2.4 Verify Deployment

```bash
curl https://story-weaver-app-production.up.railway.app/health
```

Expected:
```json
{"status": "healthy", "database": "connected"}
```

---

## Phase 3: Frontend Deployment (Netlify)

### 3.1 Netlify Configuration

**Site ID:** `db36a9a4-9712-46ff-adac-6477362e60de`

Already configured in `netlify.toml`:
```toml
[build]
  publish = "build/web"
  command = "source .netlify/install_flutter.sh && flutter build web --release --dart-define=FLUTTER_WEB_USE_SKIA=true --dart-define=FLAVOR=production"

[[redirects]]
  from = "/*"
  to = "/index.html"
  status = 200
```

### 3.2 GitHub Secrets (for CI/CD)

Add to GitHub → Settings → Secrets → Actions:

| Secret | Value |
|--------|-------|
| `NETLIFY_AUTH_TOKEN` | Your Netlify personal access token |
| `NETLIFY_SITE_ID` | `db36a9a4-9712-46ff-adac-6477362e60de` |
| `RAILWAY_TOKEN` | Your Railway API token |
| `RAILWAY_PROJECT_ID` | `36b27716-089f-4441-9b9d-af942a6df7aa` |

### 3.3 Deploy Options

**Option A: Netlify Dashboard (First Deploy)**
1. Go to https://app.netlify.com
2. Add new site → Import from GitHub
3. Select `story-weaver-app` repository
4. Build settings auto-detected from `netlify.toml`
5. Deploy

**Option B: Netlify CLI**
```bash
npm install -g netlify-cli
flutter build web --release --dart-define=FLAVOR=production
netlify deploy --prod --dir=build/web
```

**Option C: Git Push (After Connected)**
```bash
git push origin main  # Auto-deploys
```

### 3.4 Post-Deploy: Update CORS

After getting your Netlify URL, add to Railway:
```
ALLOWED_ORIGINS=https://your-site.netlify.app
```

---

## Phase 4: Database Setup

### 4.1 PostgreSQL (Railway)

Railway auto-provisions PostgreSQL when you add the plugin:
1. Railway Dashboard → Your Project
2. Click "+ New" → Database → PostgreSQL
3. `DATABASE_URL` automatically added to environment

### 4.2 Run Migrations

The backend auto-creates tables on startup, but if needed:
```bash
railway run python -c "from backend.app import create_app; app = create_app(); app.app_context().push(); from backend.models import db; db.create_all()"
```

---

## Phase 5: Post-Deployment Testing

### 5.1 Critical User Flows

| Flow | Test Steps | Expected Result |
|------|------------|-----------------|
| Young Child (Age 4) | Create character → MoodMagicPicker → Generate | Story uses selected mood |
| Older Child (Age 10) | Create character → Feelings Wheel → Select Happy → Playful → Generate | Story incorporates playful feeling |
| Deep Emotion (Age 12) | Wheel → Sad → Lonely → "Left out" → Generate | Story addresses loneliness |
| Offline Mode | Disconnect network → View characters | Cached characters visible |
| Character Persistence | Create character → Close app → Reopen | Character still exists |

### 5.2 Feelings Wheel Verification

- [ ] Core wheel shows 7 emotions with face images
- [ ] Tapping emotion shows secondary options
- [ ] No inappropriate words visible (Aroused, Intimate, etc.)
- [ ] Center hub shows selected emotion + face
- [ ] Final selection generates story

### 5.3 Health Endpoints

```bash
# Backend
curl https://story-weaver-app-production.up.railway.app/health

# Frontend
curl -I https://your-site.netlify.app/
```

---

## Phase 6: Monitoring & Alerts

### 6.1 Sentry (Error Tracking)

1. Create account at https://sentry.io
2. Create Flask project
3. Add `SENTRY_DSN` to Railway env vars
4. Errors auto-reported with stack traces

### 6.2 Railway Alerts

1. Railway Dashboard → Project → Settings → Alerts
2. Set up alerts for:
   - Deployment failures
   - High memory usage
   - Service crashes

### 6.3 Uptime Monitoring (Optional)

Use free tier of:
- UptimeRobot
- Pingdom
- Better Uptime

Monitor: `https://story-weaver-app-production.up.railway.app/health`

---

## Phase 7: Post-Launch Tasks

### Immediate (Day 1-3)
- [ ] Monitor error rates in Sentry
- [ ] Watch Railway metrics for performance
- [ ] Test with real users (family/friends)
- [ ] Fix any critical bugs discovered

### Short-term (Week 1-2)
- [ ] Gather user feedback
- [ ] Optimize slow queries (if any)
- [ ] Add missing face images for new emotions
- [ ] Fine-tune feelings wheel animations

### Long-term (Month 1+)
- [ ] Mobile app deployment (Android APK, iOS)
- [ ] Implement Guardian Mode
- [ ] Add therapeutic pick-a-path adventures
- [ ] Categorize 55 Midjourney avatars

---

## Rollback Plan

### Quick Rollback (< 5 min)
```bash
# Revert last commit
git revert HEAD
git push origin main

# Or redeploy previous version via Railway/Netlify dashboards
```

### Stable Commits (Safe to Roll Back To)
| Commit | Description | Date |
|--------|-------------|------|
| `7e63031` | Character persistence fix | 01-24 |
| `c2f45f4` | Bug fix session complete | 01-24 |
| `d2ee406` | Mood Magic feature | Earlier |

### If Feelings Wheel Breaks
Temporary fix in `feeling_selection_step.dart`:
```dart
// Force all ages to use simple MoodMagicPicker
if (age <= 5) → if (true)
```

---

## Environment URLs

| Environment | Frontend | Backend |
|-------------|----------|---------|
| Production | `https://[your-site].netlify.app` | `https://story-weaver-app-production.up.railway.app` |
| Staging | `https://[staging].netlify.app` | `https://story-weaver-staging.up.railway.app` |
| Development | `http://localhost:3000` | `http://localhost:5000` |

---

## Security Checklist

- [x] Rate limiting on all routes
- [x] Input validation (age 0-120, text sanitization)
- [x] JWT auth for sensitive endpoints
- [x] CORS configured for frontend origin
- [x] No secrets in code (all in env vars)
- [x] HTTPS enforced (via Railway/Netlify)
- [ ] Sentry configured (removes PII from logs)

---

## Competitive Advantage Summary

Story Weaver is the **only** app that combines:

| Feature | Story Weaver | StoryBee | Oscar | Zoy | Storybook |
|---------|--------------|----------|-------|-----|-----------|
| AI Stories | ✅ | ✅ | ✅ | ❌ | ❌ |
| Therapeutic Framework | ✅ | ❌ | ❌ | ✅ | ✅ |
| Feelings Identification | ✅ 3-Level Wheel | ❌ | ❌ | ❌ | ❌ |
| 124 Custom Faces | ✅ | ❌ | ❌ | ❌ | ❌ |
| Age Calibration (3-17+) | ✅ | ❌ | ❌ | Partial | Partial |
| Pick-a-Path Stories | ✅ | ❌ | ❌ | ❌ | ❌ |

**The Feelings Wheel is your moat.** No competitor helps children identify their emotions before generating a therapeutic story tailored to that feeling.

---

## Quick Reference

| Resource | URL |
|----------|-----|
| Railway Dashboard | https://railway.app/project/36b27716-089f-4441-9b9d-af942a6df7aa |
| Netlify Dashboard | https://app.netlify.com |
| Backend Health | https://story-weaver-app-production.up.railway.app/health |
| Gemini API Keys | https://aistudio.google.com/app/apikey |
| Sentry | https://sentry.io |
| GitHub Secrets | https://github.com/[user]/story-weaver-app/settings/secrets/actions |

---

## Deployment Checklist (Copy This)

```
PRE-DEPLOYMENT
[ ] Feelings wheel refactored (see FEELINGS_WHEEL_REFACTOR_PLAN.md)
[ ] All tests pass
[ ] Local testing complete
[ ] Git status clean

BACKEND (Railway)
[ ] Environment variables set
[ ] PostgreSQL added
[ ] Deploy triggered
[ ] Health check passes

FRONTEND (Netlify)
[ ] GitHub connected
[ ] Build succeeds
[ ] Site accessible
[ ] CORS updated in Railway

POST-DEPLOYMENT
[ ] Create character works
[ ] Feelings wheel works
[ ] Story generation works
[ ] Illustrations display
[ ] No errors in Sentry
```

---

**Document Version:** 3.0
**Last Updated:** 2026-01-26
**Author:** Claude (Opus 4.5)
