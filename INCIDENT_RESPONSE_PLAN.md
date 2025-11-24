# Story Weaver Incident Response Plan

## Severity Levels

### P0 - Critical (Fix Immediately)
- Site completely down (500 errors, won't load)
- Database inaccessible
- Payment processing broken
- Data breach/security incident
- User data exposed

**Response Time:** Immediate (within 15 minutes)

### P1 - High (Fix Within 1 Hour)
- Story generation failing for all users
- Stripe checkout broken
- Major feature completely broken
- Significant performance degradation (>50% slower)

**Response Time:** Within 1 hour

### P2 - Medium (Fix Within 24 Hours)
- Story generation intermittently failing
- Interactive stories not working
- Illustrations not generating
- Slow response times (<50% impact)

**Response Time:** Within 24 hours

### P3 - Low (Fix Within 1 Week)
- UI glitches (cosmetic)
- Minor feature bugs
- Optimization opportunities
- Enhancement requests

**Response Time:** Next sprint/update

## Incident Response Checklist

### Step 1: Identify
- [ ] Confirm the incident (test yourself)
- [ ] Classify severity (P0-P3)
- [ ] Document initial symptoms

### Step 2: Notify
**P0/P1:**
- [ ] Post status update on landing page
- [ ] Send email to active users (if extended)
- [ ] Update social media if widely reported

**P2/P3:**
- [ ] Log in issue tracker
- [ ] Notify team (if applicable)

### Step 3: Diagnose
- [ ] Check Railway backend logs
- [ ] Check Railway frontend deployment status
- [ ] Test health endpoint
- [ ] Test specific failing feature
- [ ] Check Gemini API status
- [ ] Check Stripe dashboard
- [ ] Review recent deployments (potential cause)

### Step 4: Fix
- [ ] Implement fix or rollback
- [ ] Test fix in production
- [ ] Monitor for 15 minutes post-fix
- [ ] Verify metrics return to normal

### Step 5: Document
- [ ] Write incident report
- [ ] Document root cause
- [ ] List preventive measures
- [ ] Update monitoring/alerts if needed

## Common Issues & Quick Fixes

### Issue: Site won't load (500 errors)
**Likely cause:** Railway deployment failed

**Quick fix:**
1. Go to Railway → Backend service → Deployments
2. Find last working deployment
3. Click "Redeploy"
4. Wait 2-3 minutes
5. Test health endpoint

**Prevent:** Enable Railway deployment notifications

### Issue: Story generation returns 500
**Likely cause:** Gemini API key invalid/quota exceeded

**Quick fix:**
1. Check Railway backend logs for "API key" errors
2. If expired: Generate new key at https://aistudio.google.com/app/apikey
3. Update GEMINI_API_KEY in Railway environment variables
4. Redeploy backend
5. Test story generation

**Prevent:** Set up quota alerts in Google Cloud Console

### Issue: Stripe checkout not working
**Likely cause:** Webhook misconfigured or key mismatch

**Quick fix:**
1. Check Stripe dashboard → Webhooks
2. Verify endpoint URL matches production
3. Check for failed webhook deliveries
4. Re-send test webhook
5. Check Railway logs for webhook errors

**Prevent:** Monitor Stripe webhook deliveries daily

### Issue: Database connection errors
**Likely cause:** Railway PostgreSQL restart or connection limit

**Quick fix:**
1. Check Railway → PostgreSQL service status
2. Restart backend service (triggers new connections)
3. Check connection pool settings in app

**Prevent:** Monitor database connection count

### Issue: Slow response times (>30s for stories)
**Likely cause:** Gemini API slowdown or high load

**Quick fix:**
1. Check Gemini API status page
2. Reduce concurrent requests if possible
3. Add caching for common story patterns (future)
4. Upgrade Railway resources if sustained high load

**Prevent:** Set up response time monitoring

## Contact List

**Railway Support:**
- Dashboard: https://railway.app
- Email: team@railway.app
- Discord: https://discord.gg/railway

**Stripe Support:**
- Dashboard: https://dashboard.stripe.com
- Docs: https://stripe.com/docs/support
- Email: support@stripe.com

**Google Cloud (Gemini API):**
- Console: https://console.cloud.google.com
- Support: https://cloud.google.com/support

**Domain Registrar:**
- [Your domain provider contact info]

## Rollback Procedures

**Frontend Rollback:**
1. Railway → Frontend service → Deployments
2. Find last known good deployment
3. Click three dots → "Redeploy"
4. Verify site loads correctly

**Backend Rollback:**
1. Railway → Backend service → Deployments
2. Find last known good deployment
3. Click three dots → "Redeploy"
4. Verify health endpoint returns 200
5. Test story generation

**Database Rollback:**
- Railway handles backups automatically
- Contact Railway support for restore
- Last resort only (avoid if possible)

## Post-Incident Review Template

```
# Incident Report: [Brief Description]

**Date:** 2025-11-XX
**Duration:** [Start] - [End] (X minutes/hours)
**Severity:** PX
**Impact:** [Number of users affected, features broken]

## What Happened
[Detailed timeline of events]

## Root Cause
[Why it happened]

## Fix Applied
[What was done to resolve it]

## Preventive Measures
[What will be done to prevent recurrence]

## Action Items
- [ ] [Specific task 1]
- [ ] [Specific task 2]
```