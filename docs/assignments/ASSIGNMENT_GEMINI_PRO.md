# Assignment: Gemini Pro — Firefox Testing + Launch Readiness Review
**Date:** 2026-03-18
**Tool:** Gemini Pro
**Nature:** Testing, analysis, documentation — no code changes expected

You are working on the Story Weaver children's storytelling app.
Repo root: `C:/dev/story-weaver-app`

After completing each task, update `TEAM_COORDINATION.md` at the repo root with a session entry, then commit:
```bash
git add TEAM_COORDINATION.md
git commit -m "docs: <short description>"
```

---

## Task 1 — Firefox Integration Testing

**Context:** Previous cross-browser testing noted Firefox coverage as incomplete because Firefox automation was unstable. We need to know if the app actually works in Firefox.

**Goal:** Manually test the app in Firefox and document results.

**Steps:**
1. Start the local app (requires Darcy to have backend and Flutter running — coordinate)
   - Backend: `http://127.0.0.1:5000/health` should return 200
   - Frontend: `http://localhost:8080` (or whatever port Flutter chose)
2. Open Firefox (not Chrome, not Edge — specifically Firefox)
3. Go through this checklist and mark PASS/FAIL:

| Test | Expected | Result |
|------|----------|--------|
| App loads at localhost | Title "Story Weaver" appears | |
| Age selection shows | Age band selector visible | |
| Character creation | Can select a character | |
| Companion selection | Can select a companion | |
| Story wizard completes | Story text appears | |
| Images/illustrations load | Images visible (not broken) | |
| Fonts render | Text looks clean, no boxes/squares | |
| TTS/audio plays | Audio plays when story reads aloud | |
| Navigation works | Bottom nav switches screens | |
| Coloring book | Can generate coloring pages | |

4. Document any Firefox-specific console errors you see in browser devtools
5. Write results to `TEAM_COORDINATION.md`

---

## Task 2 — Launch Readiness Assessment

**Goal:** Review the deployment plan and write a concise go/no-go summary.

**Steps:**
1. Read `docs/DEPLOYMENT_PLAN_2026-03-18.md`
2. Read the recent entries in `TEAM_COORDINATION.md` (the root one — focus on 2026-03-18 entries)
3. Read `docs/COPPA_AUDIT.md`
4. Write a brief (1-2 page) launch readiness summary covering:
   - What is confirmed working
   - What is still unverified (as of the time you write this)
   - COPPA compliance status
   - Any risks you think need to be noted
   - Your go / no-go recommendation with rationale
5. Save as `docs/LAUNCH_READINESS_2026-03-18.md`
6. Add a brief entry to `TEAM_COORDINATION.md` noting this review was completed

---

## Task 3 — Review Privacy Policy for Completeness

**Goal:** Verify `PRIVACY_POLICY.md` is complete per the COPPA audit findings.

**Steps:**
1. Read `PRIVACY_POLICY.md` (in the repo root or docs/)
2. Read `docs/COPPA_AUDIT.md`
3. Check that the following are present (they should be — COPPA fixes were applied):
   - [ ] Third-party services named: Google Gemini, ElevenLabs, Stripe, Railway
   - [ ] What data is shared with each third-party
   - [ ] Photo/avatar on-device-only statement
   - [ ] Parental Rights deletion section with step-by-step instructions
   - [ ] Operator contact information (name, address, phone)
4. If anything is missing, note it in `TEAM_COORDINATION.md` as a follow-up item
5. Do NOT edit the Privacy Policy unless you find something clearly missing from the COPPA audit list above

---

## Reference: App Context

- Children's storytelling app (ages 2 through adult)
- Backend: Python/Flask on Railway at `https://story-weaver-app-production.up.railway.app`
- Frontend: Flutter Web on Railway at `https://grand-light-production-68d9.up.railway.app`
- 6 age bands: sprout, explorer, adventurer, creator, adolescent, adult
- Key features: AI story generation (Gemini), illustrations, TTS (ElevenLabs), BYOK, bedtime mode, Big Feelings therapy mode, coloring book
- COPPA compliance is intentional (children's app)
