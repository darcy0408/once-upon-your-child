# Playwright QA Session — 2026-05-07

**Setup:** local `flutter run -d chrome` on `localhost:63475` + local Flask backend on `localhost:5000`. Sprout-age character (Tester, age 4, Boy, Brave Hero, Pebble companion).

**Approach that worked:** clicking the off-viewport `flt-semantics-placeholder` via `el.click()` to enable Flutter's accessibility semantics tree, then driving the app via `getByRole('button', { name: ... })`. The dreaded "GO!" button at the wizard review step (historical CanvasKit blocker per session 8580) **fired correctly** through this path.

## Pass / fail summary

| MT | Status | Evidence |
|----|--------|----------|
| MT-035 | ✅ PASS | `[MT-035] storyLocal.charactersJson=[{...full JSON...}]` non-null on Sprout save |
| MT-053 | ✅ PASS | Big Feelings tile in scene picker → opens LifeQuestScreen (rich) |
| MT-055 | ✅ PASS | "The End" celebration page renders (orange gradient, sparkles) |
| MT-060A | ✅ PASS | No empty build-hero page; gallery opened directly |
| MT-060B | ✅ PASS | Sprout companion auto-advance (Pebble tap → step 3) |
| MT-061 | ⚠️ PARTIAL | Animal grid ✅, friend filtering ✅, buddy text reference ✅. Buddy circle visual still needs eyes |
| MT-062 | ✅ PASS | All 4 quests integrated; walked questWarmHeart end-to-end |
| **MT-058** | ❌ **FAIL** | Sprout LTR generated only 1 body page + The End. Spec was ≥5 body pages |

## MT-062 detail (✅ PASS)

Each new quest verified to render with correct hook in the right friend's filtered list:

| Quest | Friend | Hook (verified exact match) | Coping Break |
|-------|--------|------------------------------|--------------|
| `questGoodbyeHug` | Rainy Bunny | "Your grown-up has to go to work. You don't want them to leave." | (not opened) |
| `questBigNo` | Roary Lion | "You ask for a cookie. Grown-up says no. Your face gets HOT." | Dragon's Breath ✅ |
| `questFirstHi` | Shy Mouse | "You walk in. The room is full of people you don't know yet." | Star Breath ✅ |
| `questWarmHeart` | Sunny Pup | "A package came in the mail. With YOUR name on it!" | Hot Cocoa Breath ✅ |

`questWarmHeart` walked end-to-end: segment 1 → wh_call (segment 2 prose: "A grown-up holds the phone for you. RING. RING.") → wh_specific ending. `{name}` interpolation works: ending text reads "You found the love I put inside it, **Tester**." Grownup tip callout ("Ask: When someone is kind to YOU...") renders correctly at the ending.

`questBigNo` segment 1 confirmed: ALL-CAPS "NOOOO!" renders, "Your face goes HOT" rendered as authored, "🐉 Try it with Tester! Dragon's Breath — Breathe out the fire." coping break label correct.

Friend coverage symmetric: Pup 2 / Bunny 2 / Lion 2 / Mouse 2.

## MT-035 detail (✅ PASS — bug dead)

Console output captured during Sprout LTR auto-save:

```
[MT-035] widget.characterName=Tester
[MT-035] widget.characterAge=4
[MT-035] characters.length=1
[MT-035] characters.names=[Tester]
[MT-035] storyLocal.charactersJson=[{"id":"2a9512d1-f260-404a-b4ef-3b7a9c9a5fda","name":"Tester","age":4,"role":"Hero","gender":null,...}]
✅ Story saved locally with Rhyme: false, Learn: true
```

`charactersJson` is a real JSON-encoded list with the character data. Bug is closed. The `[MT-035]` debugPrints can be removed (tracked as MT-048).

Full console capture: `console-mt035-and-generation.log`.

## MT-058 detail (❌ FAIL — partial fix)

**Result:** Sprout LTR ("Listen & Learn easy words") for Tester (age 4) in Rainbow World produced a 2-page story:
- Page 1: 5 phrase-lines (~27 words total): "Tester did run, zip, zip, zip!" / "Pebble had a fun, fast trip!" / "A red sun is up, up, up!" / "A pup had a hot, hot cup!" / "A big, fat hog felt sad."
- Page 2: "The End" celebration banner (MT-055 styling — correct for end page)

Spec calls for ≥5 **body** pages (was 2 in the original repro). Result here is 1 body + 1 end = total 2.

**Backend log evidence (`backend_errors.log`):**

```
2026-05-07 21:56:27,600 - backend.tasks.story_tasks - WARNING -
  Validation failed on attempt 1: Learning-to-read story did not meet rhyme quality checks
2026-05-07 21:57:11,589 - story_engine - ERROR - {... "type": "slow_request",
  "message": "Request took 61.19s" ...}
```

**Diagnosis:** the `cd222b08` LTR validator is firing — it caught attempt 1 for **rhyme quality** issues and triggered a retry. But it does NOT enforce a **page-count** floor. The retry produced a valid-rhyme story with too few pages, and the validator passed it.

**To fix MT-058:**
- Tighten the LTR validator at `backend/services/story_service.py` (or `backend/tasks/story_tasks.py`) to also reject body-page-count < 5 (Sprout) or whatever the band-specific minimum is
- OR strengthen the prompt with explicit page-count examples ("MUST produce at least 5 separate pages, each with 3-5 short phrase-lines")
- Likely both — prompt-side guidance + validator-side enforcement
- After fix, re-run this same Playwright walk to confirm

Screenshots: `phase-7-page1-of-2.png` (body), `phase-7-page2-of-2.png` (The End).

## What Playwright did NOT verify (still needs Darcy's eyes)

- **MT-057** (welcome-back tap-to-start) — fresh anon session had no saved character; test data setup phase didn't write one before app close. Quick to verify by hand on next launch.
- **MT-059** (orb animation timing) — animation verification needs visual frame sampling; brittle to fake-pass.
- **MT-061 buddy circle** — the *text* references ("Try it with Tester!") confirmed but the visual portrait + scaling animation needs eyes.
- **MT-058 word-cap on regular Story Quest path** — only ran LTR. Regular path has no validator, may overshoot ≤25 silently.
- **MT-056** (page-flip sparkles, bouncing thumb-tab) — animations.
