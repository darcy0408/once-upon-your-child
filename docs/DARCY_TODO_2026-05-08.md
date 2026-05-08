# Darcy's Personal Runbook — 2026-05-08

What's left after the Playwright session yesterday + Codex tasks (if you fired them).
Everything below needs YOUR eyes, account, key, or judgment.

**Time budget:** ~75-90 min if you do all four phases. Phases 1-2 are the high-value chunk (~20 min).

---

## Phase 1 — Visual verifies (browser, ~15 min)

**Chrome should still be open at `localhost:63475` from yesterday's Playwright session.** If not, restart `flutter run -d chrome` in the repo root. The saved character "Tester" (age 4, Boy, Brave Hero, Pebble) should already be in localStorage.

### 1A — MT-057: Welcome-back tap-to-start (3 min)

**Navigation:** Refresh the Chrome tab (Ctrl+R). The welcome screen should now show a Welcome Back tile (Tester).

**Look for:**
- ✅ Top prompt reads **"Tap your character to start a story!"** in **16px white w600** — should be noticeably bigger/brighter than the surrounding text
- ✅ Bottom CTA is a **small underlined "Or create someone new"** with a `+` icon (NOT a gold filled button)
- ✅ Tap the Tester tile → auto-advances into wizard with character pre-loaded; no "Go" press
- ✅ "Or create someone new" → loads create-new flow

**If broken:** prompt text or icon style mismatch in `lib/screens/wizard_steps/hero_creator_step.dart:_buildPage0()`. Mark MT-057 closed if all pass.

---

### 1B — MT-061 buddy portrait visual (3 min)

> Yesterday's Playwright pass confirmed the **text** ("Try it with Tester! Hot Cocoa Breath..."). Need your eyes on the **visual portrait + scaling animation**.

**Navigation:** Tester → wizard → Big Feelings scene tile → Sunny Pup → tap **The Warm Heart** → tap the **Hot Cocoa Breath** coping break button on segment 1.

**Look for:**
- ✅ Intro card shows the **Pup portrait in a soft accent-glow circle** (not the orb)
- ✅ "Let's go!" → practice frame shows **Pup clipped to a circle scaling 0.45→1.0** with the breath, NOT the orb
- ✅ Glow swells with the buddy

Then test the orb fall-through:
- Switch character to an **Explorer (age 7)** → My Quests → Coping Toolbox → tap Belly Breath → confirm **orb (not buddy)** animates per MT-059

If both visuals correct, mark MT-061 done.

---

### 1C — MT-059 orb animation timing (4 min)

> The Explorer-side check from 1B already covers the orb. Add the other two patterns:

- ✅ **Belly Breath** — blue orb grows 4s → holds → shrinks 4s → 4 cycles → "You did it!"
- ✅ **Dragon's Breath** — orange orb, 4s in / 1s hold / 6s out × 3
- ✅ **5-4-3-2-1** — green orb stays at half scale, prompt text cycles every 6-12s

If orbs are visibly static (no scale change), `294d6e67` didn't take. Otherwise, mark MT-059 done.

---

### 1D — MT-056 page-flip polish (3 min)

> Walk a Sprout story to its body pages and flip a page.

**Navigation:** New Story with Tester → Story Quest (not LTR) → generate → flip pages.

**Look for:**
- ✅ Page-flip sparkle burst is **noticeably bigger** than the standard 6-spark fan (Sprout/Explorer get a 9-spark, larger, longer-lasting variant)
- ✅ Right-edge thumb-tab arrow gives a **subtle bounce every ~4.5s** when stationary

Cross-band: walk an Adventurer (age 9) story — confirm original 6-spark + non-bouncing fade.

If both work, mark MT-056 done.

---

### 1E — MT-055 "The End" page (already verified ✅)

I already saw this in the Playwright pass — orange gradient banner with sparkles + "The End" red text. Just confirm it visually if you want; mark done if so.

---

## Phase 2 — Decisions + commit/push (~10 min)

### 2A — Push or not?

**3 commits pending on local main, none pushed:**
- `56865c6b` MT-062 integration + MT-035 print + QA script
- `d574ac2d` QA walkthrough rewrite
- `a0f95b19` Playwright session findings + MT closures

**If Codex fired the tasks I drafted yesterday and committed too, check first:**
```powershell
git log --oneline -10
```

**If you're ready, push:**
```powershell
git push
```

This will trigger Railway redeploy of the backend (no backend changes were made, so just a routine deploy) and Netlify rebuild of `grand-light` (which DOES include the MT-062 quests).

> ⚠️ Don't push if you're going to investigate MT-058 and want to fix it before deploying. The MT-062 quests are good to ship, but consider whether the MT-058 page-count regression should be fixed first.

### 2B — MT-058 fix decision

The Playwright pass found Sprout LTR still produces **1 body page + 1 The End** (= 2 total) when spec is ≥5. Backend log shows the validator is firing for **rhyme quality** but not **page count**.

**Fix paths (pick one or both):**
1. **Prompt-side** — `backend/services/story_service.py` LTR prompt path. Add explicit "MUST produce at least 5 separate pages, each with 3-5 short phrase-lines" with examples.
2. **Validator-side** — wherever the LTR rhyme validator lives (`backend/tasks/story_tasks.py` per the warning), add a body-page-count floor check (Sprout: ≥5, Explorer: ≥4, etc.). Reject + retry if too few pages.

**Recommend both.** Prompt is necessary but not sufficient — Gemini ignores prompt sometimes; validator is the safety net.

If you want, I can make these changes now while you walk Phase 1. Or hand it to Codex.

### 2C — Codex check-in

If Codex was running:
- **MT-063 (test fixes):** check `flutter test` is back to green. Look for a commit with message like `test(wizard): update hero_creator_step_test...`
- **MT-046 + MT-047 (prompt rules):** check for a commit with `backend(prompt): split young_delight_rules...`

If either failed, the Codex transcript should explain why; bring it back to me to triage.

---

## Phase 3 — MTs only YOU can do (~30-45 min if all)

### 3A — MT-014, MT-020 — BYOK trio (~15 min)

**Needs:** your real `AIza…` Gemini key + BYOK-subscribed Stripe account.

1. Settings → toggle "Use my own key" (assumes you're on Adventurer or higher tier)
2. BYOK setup wizard runs validation (`models.list()` health check)
3. ✅ Validation succeeds without crashing on empty-candidate response
4. Text field on the BYOK card is **dark text on cream** (readable, not white-on-cream)
5. Generate a multi-page Sprout or Explorer story
6. Page 1 illustration appears as skeleton-then-image within ~10s
7. Flip pages — subsequent pages already ready or close to ready (MT-050 prefetcher)
8. Network tab: only 1 `/generate-illustrations` request in flight at a time
9. Files appear at `<docs>/illustrations/<storyId>/page_*.png`
10. Re-open the same story → all illustrations instant, zero new POSTs

If all green, mark MT-014, MT-020, MT-050 done.

### 3B — MT-016, MT-019 — TTS audio (~5 min)

**ElevenLabs quota was projected to reset 2026-05-05.** Check first:

```powershell
# In a separate window:
$env:TTS_DISABLED='false'  # if it was set
# Then restart the backend if needed
```

Then walk:
- ✅ Sprout opens app — TTS greeting plays cleanly without robotic flutter_tts fallback (MT-016)
- ✅ Generate Sprout Rhyme Time story → "Read to me" narrates with ElevenLabs voice (MT-019)

If still quota-blocked, leave MT-016 and MT-019 open with a note about quota state.

### 3C — Older Sprout walks (~15 min)

These were deferred from earlier sessions. All quick visual checks:

- **MT-018** — Sprout "Make One Up" mic panel: free-form text+mic input on scene picker → enter "the kitchen" → wizard accepts and moves on
- **MT-021** — Sprout walk-through specifics (need to check MT body for what's left)
- **MT-030** — DevTools throttle to verify offline scaffold fallback: open DevTools → Network → Throttling → Offline → tap "New Story" → confirm a personalized scaffold story renders (not an error screen)
- **MT-032, MT-034** — Sprout band-specific walks (check MT bodies)
- **MT-036, MT-037, MT-038, MT-039, MT-040, MT-041** — recently shipped, awaiting verify (each described in MANUAL_TASKS.md)

For each, walk the path described in MANUAL_TASKS.md and mark done if green.

---

## Phase 4 — Backlog/decision items (no rush, ~15-20 min)

### 4A — MT-049 — Stale worktree-agent branches

6 worktree branches with unmerged commits. Each needs a per-branch decision (merge / archive / drop):
```powershell
git branch -a | grep worktree-agent
git log main..<branch-name>  # see what's unique
```
Probable: the two Sprout-band-detection branches collapse into one. Most are 1-2 commits ahead of main.

### 4B — MT-051 — Story Type unlock/showcase design

Design task — bring back a concrete proposal with mockups. Decision points listed in the MT body. No code work until alignment.

### 4C — MT-048 — Remove `[MT-035]` debugPrints

Now that MT-035 is closed, the 5 `[MT-035]` debugPrint lines in `lib/story_result_screen.dart` (lines ~1438-1442 + the one I added at line ~1444) can be removed. 5-min cleanup.

### 4D — Dependabot deferred majors

stripe 14→15, elevenlabs floor 2.45, cryptography 46→47, protobuf 6→7. All blocked on smoke-tests:
- stripe — needs payment-flow walk
- elevenlabs — wait for quota reset, then validate TTS still works
- cryptography / protobuf — backend startup + auth + JWT smoke

Triage when you have a free 30-min window.

---

## What I closed yesterday (DON'T re-walk these)

| MT | How verified |
|---|---|
| MT-035 | Console capture confirmed `charactersJson` non-null |
| MT-053 | Big Feelings tile → LifeQuestScreen |
| MT-055 | "The End" celebration page |
| MT-060A | Skip-empty-build-hero |
| MT-060B | Sprout companion auto-advance |
| MT-062 | All 4 new quests visible + walked one end-to-end |

Full evidence: `docs/qa-screenshots/PLAYWRIGHT_SESSION_2026-05-07.md`

---

## TL;DR — order of operations

1. **Phase 1** (15 min) — walk MT-057, 061-buddy, 059, 056 in one Chrome session
2. **Phase 2** (10 min) — decide push, decide MT-058 fix path, check Codex commits
3. Then either Phase 3 (manual MTs that need your account) or Phase 4 (cleanup/decisions) depending on your energy

If you only have 30 min, do **Phase 1 + Phase 2A push**. That gets MT-062 to production and closes 4 more MTs.
