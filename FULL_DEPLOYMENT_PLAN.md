# Story Weaver App - Full Deployment Plan

**Date:** 2026-01-27
**Status:** DEPLOYED - Both services live on Railway
**Version:** 4.0

---

## Executive Summary

Story Weaver is a therapeutic AI storytelling app for children ages 3-17+. It occupies a unique market position combining:
- AI-generated personalized stories (like StoryBee/Oscar)
- Therapeutic framework (like Zoy/Storybook)
- **3-Level Feelings Wheel** with 124 custom face expressions (unique to Story Weaver)

Both frontend and backend are deployed on Railway.

---

## Current Architecture

| Component | Technology | Deployment | URL |
|-----------|------------|------------|-----|
| Backend | Flask/Python + Gunicorn | Railway | `story-weaver-app-production.up.railway.app` |
| Frontend | Flutter Web + nginx | Railway | `grand-light-production-68d9.up.railway.app` |
| Database | PostgreSQL | Railway (auto) | Internal |
| AI | Gemini API | Google Cloud | gemini-2.0-flash-exp |
| Payments | Stripe | Stripe.com | Configured |

### How Deployment Works

```
git push origin main
        │
        ├──► Railway builds Backend (Dockerfile)
        │    └── gunicorn -w 1 -b 0.0.0.0:$PORT wsgi:app
        │
        └──► Railway builds Frontend (Dockerfile.frontend)
             ├── Stage 1: Flutter build web --release
             └── Stage 2: nginx serves build/web
```

### Key Files

| File | Purpose |
|------|---------|
| `Dockerfile` | Backend build (Flask + Gunicorn) |
| `Dockerfile.frontend` | Frontend build (Flutter → nginx) |
| `railway.toml` | Railway multi-service config |
| `nginx.conf` | Frontend SPA routing + caching + security headers |
| `lib/config/flavor_config.dart` | Frontend → Backend URL mapping |

---

## Current Deployment Status (Verified 2026-01-27)

### Backend Health
```json
{
  "database": "ok",
  "environment": "production",
  "has_api_key": true,
  "model": "gemini-2.0-flash-exp",
  "status": "ok",
  "stripe_configured": true,
  "stripe_family_price": true,
  "stripe_premium_price": true,
  "version": "1.0.2"
}
```

### Frontend
- Serving Flutter web app via nginx
- Production flavor: points to `story-weaver-app-production.up.railway.app`
- SPA routing configured (all paths → index.html)
- Gzip compression enabled
- Static asset caching (1 year)
- Security headers (X-Frame-Options, X-Content-Type-Options, X-XSS-Protection)

---

## Critical: CORS Configuration

The backend uses `RAILWAY_FRONTEND_URL` env var to allow the frontend origin.

**You MUST verify this is set in Railway Dashboard → Backend Service → Variables:**

```
RAILWAY_FRONTEND_URL=https://grand-light-production-68d9.up.railway.app
```

Without this, the frontend will get CORS errors on every API call.

### All Required Backend Environment Variables

| Variable | Required | Status | Notes |
|----------|----------|--------|-------|
| `FLASK_ENV` | ✅ | ✅ Set | `prod` (in railway.toml) |
| `FLASK_CONFIG` | ✅ | ✅ Set | `prod` (in railway.toml) |
| `GEMINI_API_KEY` | ✅ | ✅ Set | Verified via health check |
| `SECRET_KEY` | ✅ | ✅ Set | Required in production |
| `JWT_SECRET_KEY` | ✅ | ✅ Set | Required in production |
| `DATABASE_URL` | ✅ | ✅ Auto | Railway PostgreSQL plugin |
| `RAILWAY_FRONTEND_URL` | ✅ | ⚠️ VERIFY | `https://grand-light-production-68d9.up.railway.app` |
| `MOCK_TESTING_MODE` | Recommended | ✅ Set | `false` for real AI |
| `SENTRY_DSN` | Optional | ❌ Not set | Add for error monitoring |
| `STRIPE_SECRET_KEY` | ✅ | ✅ Set | Verified via health check |
| `STRIPE_WEBHOOK_SECRET` | ✅ | ✅ Set | For webhook verification |

**Generate new secrets if needed:**
```bash
python -c 'import secrets; print(secrets.token_hex(32))'
```

---

## Pre-Deployment: Feelings Wheel Refactor

See `FEELINGS_WHEEL_REFACTOR_PLAN.md` for full details. Currently being implemented by another instance.

**Quick Summary:**
- [ ] Remove inappropriate emotions (Aroused, Intimate, Violated, Auctiole)
- [ ] Refactor wheel to use progressive REPLACEMENT (not concentric rings)
- [ ] Verify all 124 face images load correctly

**Why Critical:** The Feelings Wheel is your competitive differentiator.

### Recent Bug Fixes (Already Committed & Deployed)

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

## How to Deploy Updates

### Standard Deploy (Both Services)

```bash
# 1. Commit your changes
git add <files>
git commit -m "description of changes"

# 2. Push triggers auto-deploy of BOTH services
git push origin main

# 3. Verify
curl https://story-weaver-app-production.up.railway.app/health
curl https://grand-light-production-68d9.up.railway.app/
```

### Frontend-Only Redeploy

If you only changed Flutter code, Railway will still rebuild both services. To speed things up, you can trigger a manual redeploy of just the frontend in the Railway dashboard.

### Backend-Only Changes

Same process - `git push origin main`. Railway detects which Dockerfiles changed.

---

## Post-Deployment Testing

### Critical User Flows

| Flow | Test Steps | Expected Result |
|------|------------|-----------------|
| Young Child (Age 4) | Create character → MoodMagicPicker → Generate | Story uses selected mood |
| Older Child (Age 10) | Create character → Feelings Wheel → Happy → Playful → Generate | Story incorporates playful feeling |
| Deep Emotion (Age 12) | Wheel → Sad → Lonely → "Left out" → Generate | Story addresses loneliness |
| Offline Mode | Disconnect network → View characters | Cached characters visible |
| Character Persistence | Create character → Close app → Reopen | Character still exists |
| Stripe Subscription | Click subscribe → Complete checkout | Redirects to `grand-light.../subscription-success` |

### Feelings Wheel Verification

- [ ] Core wheel shows 7 emotions with face images
- [ ] Tapping emotion shows secondary options
- [ ] No inappropriate words visible (Aroused, Intimate, etc.)
- [ ] Center hub shows selected emotion + face
- [ ] Final selection generates story

### Health Checks

```bash
# Backend
curl https://story-weaver-app-production.up.railway.app/health

# Frontend
curl -I https://grand-light-production-68d9.up.railway.app/
```

---

## Monitoring & Alerts

### Sentry (Error Tracking) - Recommended

1. Create account at https://sentry.io
2. Create Flask project → Get DSN
3. Add `SENTRY_DSN` to Railway backend env vars
4. Errors auto-reported with stack traces

### Railway Dashboard

- CPU/Memory metrics visible per service
- Deploy logs available for debugging
- Set up alerts: Railway Dashboard → Project → Settings → Alerts

### Uptime Monitoring (Optional)

Free tier options: UptimeRobot, Better Uptime, Pingdom

Monitor: `https://story-weaver-app-production.up.railway.app/health`

---

## Post-Launch Roadmap

### Immediate (Day 1-3)
- [ ] Monitor error rates
- [ ] Watch Railway metrics for performance
- [ ] Test with real users (family/friends)
- [ ] Verify CORS works end-to-end

### Short-term (Week 1-2)
- [ ] Gather user feedback
- [ ] Add missing face images for new emotions
- [ ] Fine-tune feelings wheel animations
- [ ] Custom domain setup (optional)

### Long-term (Month 1+)
- [ ] Mobile app deployment (Android APK, iOS)
- [ ] Implement Guardian Mode
- [ ] Add therapeutic pick-a-path adventures
- [ ] Categorize 55 Midjourney avatars
- [ ] Emotion Insights Dashboard (Pillar 2)
- [ ] Post-Story Emotional Check

---

## Rollback Plan

### Quick Rollback
```bash
git revert HEAD
git push origin main
# Railway auto-redeploys both services
```

### Via Railway Dashboard
1. Go to the service → Deployments tab
2. Click on a previous successful deployment
3. Click "Redeploy"

### Stable Commits
| Commit | Description | Date |
|--------|-------------|------|
| `8e0371b` | Deployment docs added | 01-27 |
| `7e63031` | Character persistence fix | 01-24 |
| `c2f45f4` | Bug fix session complete | 01-24 |
| `d2ee406` | Mood Magic feature | Earlier |

### If Feelings Wheel Breaks
Temporary fix in `feeling_selection_step.dart`:
```dart
// Force all ages to use simple MoodMagicPicker
if (age <= 5) → change to: if (true)
```

---

## Environment URLs

| Environment | Frontend | Backend |
|-------------|----------|---------|
| **Production** | `https://grand-light-production-68d9.up.railway.app` | `https://story-weaver-app-production.up.railway.app` |
| Staging | `https://story-weaver-staging.up.railway.app` | `https://story-weaver-staging-api.up.railway.app` |
| Development | `http://localhost:8080` (flutter run -d chrome) | `http://localhost:5000` (flask run) |

---

## Security Checklist

- [x] Rate limiting on all routes (5-60/min depending on route)
- [x] Input validation (age 0-120, text sanitization)
- [x] JWT auth for sensitive endpoints
- [x] CORS configured for frontend origin (via RAILWAY_FRONTEND_URL)
- [x] No secrets in code (all in env vars)
- [x] HTTPS enforced (Railway auto-TLS)
- [x] Security headers via nginx (X-Frame-Options, X-Content-Type-Options, X-XSS-Protection)
- [x] Stripe webhook signature verification
- [ ] Sentry configured (add SENTRY_DSN)

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

**The Feelings Wheel is your moat.**

---

## Quick Reference

| Resource | URL |
|----------|-----|
| Railway Dashboard | https://railway.app/project/36b27716-089f-4441-9b9d-af942a6df7aa |
| Backend (Production) | https://story-weaver-app-production.up.railway.app |
| Frontend (Production) | https://grand-light-production-68d9.up.railway.app |
| Backend Health | https://story-weaver-app-production.up.railway.app/health |
| GitHub Repo | https://github.com/darcy0408/story-weaver-app |
| Gemini API Keys | https://aistudio.google.com/app/apikey |
| Sentry | https://sentry.io |
| Stripe Dashboard | https://dashboard.stripe.com |

---

## Deployment Checklist (Copy This)

```
PRE-DEPLOYMENT
[x] Backend healthy on Railway
[x] Frontend serving on Railway
[x] Flutter web build succeeds
[x] Flutter analyze passes (0 errors, 93 warnings)
[ ] Feelings wheel refactored (in progress - other instance)

RAILWAY BACKEND
[x] FLASK_ENV = prod
[x] GEMINI_API_KEY set
[x] SECRET_KEY set
[x] JWT_SECRET_KEY set
[x] DATABASE_URL auto-set
[x] STRIPE configured
[ ] RAILWAY_FRONTEND_URL = https://grand-light-production-68d9.up.railway.app
[ ] SENTRY_DSN set (optional)

RAILWAY FRONTEND
[x] Dockerfile.frontend builds successfully
[x] nginx serving Flutter web app
[x] SPA routing working
[x] Production flavor pointing to correct backend

POST-DEPLOYMENT
[ ] Create character works end-to-end
[ ] Feelings wheel works (after refactor)
[ ] Story generation works
[ ] Illustrations display
[ ] Stripe checkout redirects work
[ ] No CORS errors in browser console
```

---

**Document Version:** 4.0
**Last Updated:** 2026-01-27
**Author:** Claude (Opus 4.5)
