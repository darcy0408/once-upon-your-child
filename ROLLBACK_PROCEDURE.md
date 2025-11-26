# Rollback Procedure (Railway - Backend & Frontend)

Use this playbook if a new deployment causes failures. Prefer the quickest safe path: revert to last known good build and verify health.

## 1) Pause and Triage
- Identify the broken service (backend or frontend).
- Capture the failing commit hash, error logs, and time of incident.
- Decide: rollback vs. hotfix. Default to rollback to restore service.

## 2) Backend Rollback (Railway)
1) Open Railway → `story-weaver-app` backend service → Deployments.
2) Select the last known good deployment and click **Redeploy** (or promote).
3) If code-level rollback is needed, `git revert <bad_commit>` → push to `main` → trigger redeploy.
4) Confirm env vars still present (GEMINI_API_KEY, STRIPE_API_KEY, STRIPE_PRICE_ID_PREMIUM, STRIPE_PRICE_ID_FAMILY, DATABASE_URL).
5) Watch logs until Gunicorn boots without errors.

## 3) Frontend Rollback (Railway Edge)
1) Open Railway → frontend service → Deployments.
2) Redeploy the last successful build (or redeploy previous commit from `main`).
3) Clear CDN cache if applicable (or force-redeploy).

## 4) Post-Rollback Verification (must do)
- `/health` and `/health/detailed` return 200 and show DB OK.
- Basic story generation works (standard + interactive start).
- Stripe keys present; subscription flow loads (test mode acceptable).
- BYOK wizard loads and key validation endpoint reachable.
- Content safety: story renders, report button posts without 5xx.
- Frontend loads at `grand-light-production-68d9.up.railway.app`.
- Analytics calls do not throw console errors (Firebase init graceful).

## 5) Communicate
- Notify `engineering@storyweaver.app` and `ops@storyweaver.app` with: incident time, root cause (if known), rollback version, and any remaining risk.
- Log the action in TEAM_COORDINATION.md (include time and deployment ID).

## 6) Follow-Up
- Create a fix branch; add tests/guards for the regression.
- Schedule a controlled redeploy after the fix passes tests.
