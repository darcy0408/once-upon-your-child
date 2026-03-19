# Assignment: Darcy — Manual Steps + Testing
**Date:** 2026-03-18
**Requires:** Railway dashboard access, running the app yourself

---

## Step 1 — Fix CORS (5 minutes, do this FIRST)

This is the biggest blocker. The core story wizard fails in production because the backend doesn't know the frontend URL.

1. Go to [Railway dashboard](https://railway.app) → your **backend** service → **Variables** tab
2. Add a new variable:
   - Key: `RAILWAY_FRONTEND_URL`
   - Value: `https://grand-light-production-68d9.up.railway.app`
3. Railway redeploys automatically (takes ~2 minutes)
4. Open `https://grand-light-production-68d9.up.railway.app` in Chrome
5. Try to create a character and generate a story — if it works, CORS is fixed

No code change needed.

---

## Step 2 — Start Local App (before manual testing)

```bash
# Terminal 1 — Backend
cd C:/dev/story-weaver-app/backend
python app.py

# Terminal 2 — Flutter
cd C:/dev/story-weaver-app
flutter run -d chrome

# Verify backend is up
curl http://127.0.0.1:5000/health
```

If backend doesn't start, check `backend/.env` has `GEMINI_API_KEY` set.

---

## Step 3 — Manual Integration Checklist

For each age band, run through these steps in the app. Mark PASS/FAIL/SKIP.

### Age Bands to Test
- [ ] **Sprout** (2-4 years)
- [ ] **Explorer** (5-7 years)
- [ ] **Adventurer** (8-10 years)
- [ ] **Creator** (11-13 years)
- [ ] **Adolescent** (13-15 years)
- [ ] **Adult** (18+)

### Per-Band Checklist
For each band above:
- [ ] Visual theme loads correctly (colors, fonts, orb images match age band)
- [ ] Character carousel shows diverse options and selecting one sets both gender + skin tone
- [ ] Companion selector shows companions from the correct age band folder (not adventurer for adult/creator)
- [ ] Story generates and is age-appropriate
- [ ] Illustrations generate and match the character
- [ ] Bottom navigation icons match the age band

### Cross-Cutting Scenarios (do once, any age band)
- [ ] **BYOK**: Go to Settings, enter a Gemini API key, generate a story — verify it uses your key
- [ ] **Custom avatar**: Upload a photo, generate custom avatar, verify it appears in story illustrations
- [ ] **Pet avatar**: Upload a pet photo, complete magical transformation, verify in wizard
- [ ] **Parent hidden context**: Go to Parent Controls, set Big Feelings guidance, generate a Big Feelings story — verify guidance was subtly incorporated (child shouldn't see raw parent text)
- [ ] **Bedtime mode**: Launch bedtime wizard, complete voice flow, verify soothing story generated
- [ ] **Coloring book**: After a story, tap Color button, pick 1-5 pages, verify coloring pages generated

### Notes field
Write any issues found here:
```
Issue 1:
Issue 2:
Issue 3:
```

---

## Step 4 — Cross-Browser Testing

After Chrome passes:

### Firefox
- [ ] App loads
- [ ] Story wizard completes
- [ ] Images load
- [ ] Fonts render

### Edge
- [ ] App loads
- [ ] Story wizard completes

### Mobile Chrome (DevTools device emulation)
- [ ] App loads on mobile viewport
- [ ] Touch navigation works

---

## Step 5 — Update Coordination Log

After testing, add results to `TEAM_COORDINATION.md`:

```bash
git add TEAM_COORDINATION.md docs/DEPLOYMENT_PLAN_2026-03-18.md
git commit -m "docs: manual integration test results 2026-03-18"
```

---

## What to Ignore

The "Manual Integration Testing" results in `docs/TEAM_COORDINATION.md` that show all FAILs were environment failures (the AI couldn't start the app), not real product failures. Overwrite those results with your actual test outcomes.
