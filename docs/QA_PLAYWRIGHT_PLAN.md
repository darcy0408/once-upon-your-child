# Story Weaver — Playwright QA Test Plan

**Purpose:** Comprehensive browser-automation test plan for a fresh Claude Sonnet session to execute against the Story Weaver app. Covers 6 age bands + 8 cross-cutting regression tests.

**Hand-off:** Give Sonnet this file path. Sonnet should read the whole plan, confirm environment, then execute sequentially.

---

## Environment Setup

### Local Development

```bash
# Frontend
cd /c/dev/story-weaver-app
flutter run -d chrome
# Port varies — may be localhost:5000, 8080, or auto-assigned. Check terminal output.

# Backend
cd backend
python app.py
# Runs on http://localhost:5000
# Verify: curl http://localhost:5000/health
```

### Production

- **Frontend:** https://grand-light-production-68d9.up.railway.app
- **Backend:** https://story-weaver-app-production.up.railway.app

### Expected Latency

- Story generation: p50 ≈ 42.5s, p95 ≈ 44.9s (real Gemini)
- Avatar generation: ~60s (Gemini image gen)
- TTS synthesis: 2–5s (ElevenLabs)

### Playwright MCP Lockfile Recovery (if needed)

If `mcp__playwright__browser_*` fails with `Error: Browser is already in use for ...mcp-chrome-for-testing-<hash>`:

Exit Claude Code, then run in PowerShell:
```powershell
Get-CimInstance Win32_Process | Where-Object { $_.CommandLine -like '*playwright/mcp*' -or $_.CommandLine -like '*mcp-chrome-for-testing*' } | ForEach-Object { Stop-Process -Id $_.ProcessId -Force }
Remove-Item "C:\Users\darcy\AppData\Local\ms-playwright\mcp-chrome-for-testing-*\lockfile" -Force -ErrorAction SilentlyContinue
```
Then restart Claude Code.

### Before each band — clear storage

```javascript
localStorage.clear();
sessionStorage.clear();
```

---

## Test Matrix — 6 Age Bands (Critical Path)

Run one complete flow per band. Then run cross-cutting regression tests once at the end.

---

### BAND 1 — Sprout (Ages 3–5)

**Flow:** Age-Gate → Name → Gender → Archetype → Feeling → Scenario → Magic Review → Story → Reader

```
STEP 1 — Welcome & Age Gate
  - Expect: Splash screen (4s fade), then welcome teaser "Story Weaver / Your hero. Your story."
  - Expect: TTS "Welcome to Story Weaver!"
  - Action: Tap age circle "3"
  - Assert: Sprout theme applied (warm, bubbly, rounded corners)

STEP 2 — Name Entry
  - Action: Type "Alex"
  - Assert: Bubble shows "Hi Alex!" with bounce animation
  - Assert: TTS plays "Hi Alex!..." (natural pause, not robotic)
  - Action: Tap Continue

STEP 3 — Gender Selection
  - Assert: Boy image loads from assets/images/ui/gender/gender_sprout_boy.png (200 OK)
  - Assert: Girl image loads from assets/images/ui/gender/gender_sprout_girl.png (200 OK)
  - Assert: Tap scales image 1.08× + brightens
  - Action: Select boy

STEP 4 — Hero Creator (Sprout Archetype)
  - Expect: 4 archetype cards in 2×2 grid
  - Assert: Names: "Brave Hero!", "Art Maker!", "Super Fast!", "Animal Friend!"
  - Assert: Each card shows gendered variant (boy/girl)
  - Assert: Wiggle animation on unselected cards
  - Action: Tap "Brave Hero!" → selected state (border/checkmark)
  - Action: Continue

STEP 5 — Feeling Selection
  - Expect: 4 core emotions (Happy, Sad, Mad, Scared) in 2×2 grid, no scroll needed
  - Assert: Warm band colors (not clinical)
  - Action: Tap "Happy"

STEP 6 — Scenario
  - Expect: Life Quest scenario cards with young tone
  - Action: Tap first scenario

STEP 7 — Magic Review
  - Expect: "Hero: Alex" below orb
  - Assert: Archetype shows "Brave Hero!" (band-specific, not "Thinker")
  - Assert: CTA = "Make Magic!"
  - Action: Tap "Make Magic!"

STEP 8 — Story Generation & Reader
  - Expect: Sprout loading animation (egg wobble + tap interaction)
  - Assert: No console 404s during load
  - Assert: Story loads within 45s
  - Assert: Typewriter reveal + page flip works
  - Assert: Story is age-appropriate (simple language, short paragraphs, no violence)
  - Assert: TTS plays first page
  - Action: Tap "Next Page" 2–3×; no rendering breaks

PASS: All 8 steps complete, story readable, 0 console 404s, Sprout theme applied throughout.
```

---

### BAND 2 — Explorer (Ages 6–8)

**Deltas from Sprout:**
- Gender assets: `gender_explorer_{boy|girl}.png`
- Archetype names: "The Brave Explorer", "The Art Wizard", "The Speed Star", "The Animal Whisperer"
- Feeling count: 6 (Excited, Happy, Sad, Mad, Scared, Worried) — positive-first
- Avatar loading: **Constellation animation** (stars appear, lines draw, drifting tap targets)
- CTA: "Make Magic!"

```
STEP 1 — Age 7 → Explorer theme (purple sparkles, magical UI)

STEP 3 — Gender: gender_explorer_{boy|girl}.png loads 200

STEP 4 — Archetypes: 4 cards, Explorer names, gendered variants load
  - Assert: Fallback chain works if gendered missing (→ generic .jpg)

STEP 5 — Feelings: 6 emotions visible without scroll (dynamic aspect ratio)

STEP 8 — Avatar loading: Constellation animation plays
  - Assert: Respects MotionPrefs (no animation if reduceMotion=true)
  - Assert: Progress step label updates every ~15s

PASS: Explorer theme, 6 emotions visible, constellation plays, story generates.
```

---

### BAND 3 — Adventurer (Ages 9–11)

**Deltas:**
- Gender assets: `gender_adventurer_{boy|girl}.png` (heroic action pose)
- Archetype names: "The Quiz Whiz", "The Master Creator", "The Lightning Runner", "The Animal Whisperer"
- Feeling count: 8 (full wheel, may scroll)
- **Companion selector** appears — 7 named companions (Shadow Cat, Robin, Clever Fox, etc.)
- Scenario label: "Life Quest" (NOT "Big Feelings")
- Avatar loading: **Treasure map ink trail** (parchment, teal ink, landmarks, compass)
- CTA: "Start Adventure!"

```
STEP 4 — Hero Creator + Companion
  - Expect: Archetypes, then companion selector below
  - Assert: 7 companion cards from assets/images/companions/adventurer/ (no 404s)
  - Assert: Each companion has tagline
  - Action: Select companion → name shown in selection bar

STEP 5 — "What's going on?" title (Life Quest framing, NOT "Big Feelings")

STEP 7 — Magic Review
  - Assert: Companion name shown (not generic "Companion")
  - Assert: Archetype = "Quiz Whiz" (not "Thinker")
  - Assert: Edit icons on summary rows tappable
  - Assert: CTA = "Start Adventure!"

STEP 8 — Avatar: Treasure map animation plays

PASS: Companion selector works, "Life Quest" labeled, treasure map animates, adventure-tone story.
```

---

### BAND 4 — Creator (Ages 12–14)

**Deltas:**
- Gender assets: `gender_creator_{boy|girl}.png` (cool/artistic)
- Archetype names: "Logic Architect", "Vision Architect", "Kinetic Specialist", "Ecological Whisperer"
- Companion count: 4 (Cipher, Rockin' Robin, Vesper, Lore)
- Feeling modal: theme-aware (bandTheme.gradientStart, not hardcoded purple)
- Avatar loading: **Digital canvas** (geometric shapes compose on dark background)
- CTA: "Start Writing!"
- Magic Review header: "Set the premise" (not "Make Magic")
- Creative Brief: additional "Cast & Companions" accordion section

```
STEP 1 — Age 13 → Creator theme (dark editorial, minimal)

STEP 4 — Companions: Cipher, Rockin' Robin, Vesper, Lore
  - Assert: Images load from assets/images/companions/creator/ (no 404s)

STEP 7 — Magic Review (Creator-specific)
  - Expect: "Set the premise" header (not "Make Magic")
  - Assert: Archetype = "Logic Architect" or equivalent band name
  - Action: Tap scenario row edit icon → returns to scenario picker
  - Assert: CTA = "Start Writing!"

STEP 8 — Avatar: Digital canvas animation (minimal, no particles)

CROSS-CHECK — Creative Brief Accordion
  - Expand "Cast & Companions" in Creative Brief
  - Assert: 4 companions load; selection preview works; 0 console 404s

PASS: Creator theme, 4 Creator companions load, "Start Writing!" CTA, canvas animates, "Set the premise" text.
```

---

### BAND 5 — Adolescent (Ages 15–17)

**Deltas:**
- Gender assets: `gender_adolescent_{boy|girl}.png` (mature, cinematic)
- Companion count: 4 (Zephyr, Rockin' Robin, Shade, Frost)
- Avatar loading: **Holographic portal** (chromatic aberration, data rain, silhouette materializes)
- CTA: "Begin" (single word, no exclamation)
- Thematic question: `adolescentThematicQuestion` shown in italics on scenario card (if implemented — per 2026-04-19n plan; currently **not yet implemented**)
- **Audio-Only CTA:** "Want the same pick-a-path story without the screen?" → "Start Audio-Only Adventure"

```
STEP 1 — Age 16 → Adolescent theme (dark teal, cinematic)

STEP 4 — Companions: Zephyr, Rockin' Robin, Shade, Frost
  - Assert: Images from assets/images/companions/adolescent/ load 200

STEP 5 — Scenario: "What's going on?" Life Quest framing
  - Note: adolescentThematicQuestion may NOT yet appear (pending 2026-04-19n Phase 1)

STEP 7 — Magic Review
  - Assert: CTA = "Begin" (single word)
  - If interactiveMode=true:
    - Assert: Audio-only CTA appears: "Want the same pick-a-path story without the screen?"
    - Assert: Button: "Start Audio-Only Adventure"

STEP 8 — Avatar: Holographic portal animation
  - Assert: Tap triggers glitch effect (if tap-responsive)

STEP 9 — Audio-Only (IF CTA TAPPED)
  - Action: Click "Start Audio-Only Adventure"
  - Assert: Navigates to BedtimeWizardScreen(isInteractive: true)
  - Assert: TTS network call returns 200
  - Assert: Audio element loads and plays
  - **KNOWN ISSUE:** Watch for 401 on guest userId — document if seen

PASS: Adolescent theme, 4 companions load, "Begin" CTA, portal animates, audio-only routes without 401.
```

---

### BAND 6 — Adult (Ages 18+)

**Flow differs:** No archetype grid. Creative Brief (name, genre, world, companions). Reflect mode reader.

```
STEP 1 — Age 25 → Adult theme (warm amber, minimal)

STEP 3 — Gender labels: "Man" / "Woman" (not "Boy" / "Girl")

STEP 4 — Creative Brief
  - Sections: Name, Genre chips, World & Setting, Cast & Companions
  - Assert: All sections visible, not collapsed
  - Expand "Cast & Companions" accordion:
    - Assert: 4 Adult companions (Tide, Rockin' Robin, Onyx, Cinder) load from assets/images/companions/adult/
    - Assert: 0 console 404s  ← **BUG-P6-01 regression test**
  - Action: Select companion → name shown

STEP 5 — Story Generation
  - Expect: No avatar generation (adults skip this)
  - Assert: Story loads within 15s (faster adult path)

STEP 6 — Reader (Reflect mode)
  - Assert: Mature-tone story (complex themes, longer text)
  - Assert: End-of-story journaling prompt visible
  - Assert: Bottom nav shows "Reflect" tab (not "Life Quests")

PASS: Creative Brief loads, 4 Adult companions load (0 404s), Reflect mode with journaling prompt.
```

---

## Cross-Cutting Regression Tests (Run Once at End)

### Test 1 — Archetype Chip Visibility (BUG-04 Regression)

```
TRIGGER: Adventurer hero creator (age 10)
ASSERT:
  - [ ] All 4 archetype cards visible (no RenderFlex overflow)
  - [ ] All cards clickable/selectable
  - [ ] Selected card shows checkmark top-right
KNOWN: BUG-04 resolved in 2026-04-19k; regression possible if cards overlap.
```

### Test 2 — Gendered Archetype Images + Press State

```
TRIGGER: Adventurer band, tap archetype cards
ASSERT:
  - [ ] Images show gendered variants matching step-3 gender selection
  - [ ] No placeholder/broken-link icons
  - [ ] Tap scales card 0.94 + white brightness overlay (press-in)
  - [ ] Release → 1.0, overlay fades
  - [ ] Selected → 1.03 + checkmark
COVERAGE:
  - Creator/Adventurer: gendered images exist
  - Explorer/Adolescent/Adult/Sprout: may fall back to generic .jpg — acceptable
```

### Test 3 — Companion Image Loading (BUG-P6-01 Regression) 🔴 CRITICAL

```
BANDS: Explorer, Adventurer, Creator, Adolescent, Adult
TRIGGER: Expand companion selector or Creative Brief accordion
ASSERT PER BAND:
  - [ ] All companion images load (no placeholder icons)
  - [ ] Network tab: 0 × 404 for *.jpg/*.png
  - [ ] URL pattern: assets/images/companions/{band}/{name}.{jpg|png}
SEVERITY: Fix committed 2026-04-19j; visual verification deferred. This test confirms the fix holds.
```

### Test 4 — TTS Warm-Up Phrase Playback

```
TRIGGER: Clear localStorage, start app, enter name "Alex" on Sprout (age 4)
ASSERT:
  - [ ] Welcome TTS on app start: "Hi, welcome to Story Weaver!..."
  - [ ] Name-echo TTS: "Hi Alex!..." with natural pause
  - [ ] Not robotic (= ElevenLabs working; Flutter fallback = robotic voice, acceptable backup)
KNOWN: Local dev needs backend restart with .env loaded; hot reload doesn't pick up API key. Production should work.
```

### Test 5 — Parental Consent (Sticky Footer + Share-to-Grown-up)

```
TRIGGER: Clear localStorage, age 8 (COPPA required)
STEP 1 — Layout
  - [ ] Sticky footer visible (checkbox + scroll hint + "Give Permission ✓")
  - [ ] Footer pinned while scrolling
  - [ ] Scroll hint: keyboard_arrow_down inline, then keyboard_arrow_up in footer
STEP 2 — Scroll Gate
  - At 50% scroll: checkbox disabled, button disabled
  - At 95%+ scroll: both enabled
STEP 3 — Share-to-Grown-up
  - "Send to a grown-up" button top-right of footer
  - Tap → OS share sheet with pre-written message: "Hi! I want to try Story Weaver… Could you look at this together with me?"
  - Cancel → modal closes, flow continues
STEP 4 — Give Permission
  - Check box + tap button → routed to welcome; persists across restart
```

### Test 6 — Audio-Only CTA (Phase 7, Previously Playwright-Blocked) 🔴 CRITICAL

```
TRIGGER: Adolescent or Adult band, magic_review_step.dart, interactiveMode=true
ASSERT CTA APPEARANCE:
  - Mature bands: "Want the same pick-a-path story without the screen?" + "Start Audio-Only Adventure"
  - Young bands: "Want this adventure in audio-only bedtime mode?" + "Start Bedtime Audio Adventure"

ACTION: Tap CTA
ASSERT:
  - [ ] Navigates to BedtimeWizardScreen(isInteractive: true)
  - [ ] 0 × 404 or navigation errors
  - [ ] TTS network call 200
  - [ ] Audio element loads, playable
  - [ ] 0 × 401 Auth errors (KNOWN ISSUE: guest userId may 401 — document if seen)

FAILURE MODES TO WATCH:
  - 401 Unauthorized (guest auth issue — architectural decision pending)
  - 404 for audio file
  - Empty Gemini response
  - Hang >30s (TTS timeout)

COVERAGE: Run for all 6 bands to confirm both CTA variants appear correctly.
```

### Test 7 — Console Error Audit

```
METHOD: Open DevTools Console. Clear. Run one full wizard flow (any band).
ASSERT:
  - [ ] 0 Uncaught errors
  - [ ] 0 undefined/null dereference errors
  - [ ] 0 "Failed to load resource" 404s (except expected stale deletes)
  - [ ] 0 CORS errors (prod may have CORS issue — known; document if seen)
  - [ ] 0 × 401 (except known guest-auth edge case)
  - [ ] TTS calls 200 (Network filter: /api/tts or elevenlabs.io)
  - [ ] Story calls 200 (filter: /api/stories or /api/generate)

KNOWN NOISE (ignore):
  - Deprecated Gemini model warnings in backend logs
  - gemini-2.0-flash-lite deprecation warning
```

### Test 8 — Asset URL 200 Validation

```
METHOD: Network tab during wizard flow, filter Image requests.
ASSETS TO CHECK:
  - assets/images/ui/gender/gender_{band}_{boy|girl}.png → 200
  - assets/images/archetypes/{band}/{archetype}_{boy|girl}.png → 200 or graceful fallback
  - assets/images/companions/{band}/{name}.{jpg|png} → 200
ASSERT:
  - [ ] All band-specific images 200
  - [ ] SafeAssetImage fallback = blank SizedBox (not broken placeholder)
  - [ ] Fallback chain: gendered → generic → blank
REGRESSION: BUG-P6-01 — adult band companion 404s.
```

---

## Known Issues & Failure Watch List

| Issue | Symptom | Workaround |
|-------|---------|------------|
| Playwright MCP lockfile (Windows) | "Browser already in use" | PowerShell recovery script above |
| Guest auth 401 (audio-only) | Audio-only fails with 401 | Document if seen; architectural decision pending |
| CORS on web (prod) | Frontend can't reach backend on Railway | Native/desktop unaffected; known issue |
| ElevenLabs TTS robotic (local) | Robotic Flutter fallback, not ElevenLabs voice | Restart backend with .env loaded |
| Stale avatar cache (web) | Web users see old avatar | Isar doesn't run in browser; SharedPreferences stub, 7-day cache. Clear localStorage to force. |

### Failure Mode Debug Hints

| Failure | Likely Cause |
|---------|--------------|
| Story gen hangs >60s | Gemini rate limit — check Cloud console |
| Avatar gen stuck | gemini-2.5-flash-image timeout — fallback static avatar |
| TTS silent | Missing ELEVENLABS_API_KEY in backend .env |
| 404 on companion image | Band variant missing on disk — check git status |
| Archetype shows generic | Gendered variant not in assets (expected for Adolescent/Adult/Sprout) |
| Console 401 during TTS | Guest auth token invalid (known) |
| COPPA scroll gate broken | Clear localStorage, restart, check parental_consent_screen.dart |

---

## QA Sign-Off Checklist

```
CRITICAL PATHS (Required):
- [ ] Sprout (3-5) full flow
- [ ] Explorer (6-8) full flow, constellation animation
- [ ] Adventurer (9-11) full flow, companion selector, treasure map
- [ ] Creator (12-14) full flow, Creative Brief, digital canvas
- [ ] Adolescent (15-17) full flow, holographic portal, audio-only CTA
- [ ] Adult (18+) full flow, Creative Brief, Reflect mode

REGRESSIONS (Required):
- [ ] Test 1 — Archetype chip visibility
- [ ] Test 2 — Gendered images + press state
- [ ] Test 3 — Companion images 0 × 404 🔴
- [ ] Test 4 — TTS warm-up phrases
- [ ] Test 5 — COPPA sticky footer + share button
- [ ] Test 6 — Audio-only CTA routes without 401 🔴
- [ ] Test 7 — Console audit 0 Uncaught errors
- [ ] Test 8 — Asset URLs 200

OPTIONAL:
- [ ] Animation timing feedback
- [ ] Accessibility (keyboard nav, contrast, TTS coverage)
- [ ] Performance baseline (story ~45s, avatar ~60s, TTS ~3s)
```

---

## Report Format

At end of session, Sonnet should provide:

1. **Summary table:** 6 bands × Pass/Fail
2. **Regression matrix:** 8 tests × Pass/Fail/Blocked
3. **New issues:** Anything not in the watch list (include stack trace + repro)
4. **Screenshots:** (optional) key moments — welcome, archetypes, companions, magic review, audio-only CTA
5. **Console log dump:** if errors found
6. **Next steps:** what to fix/investigate

---

## References

- Project context: `docs/PROJECT_STATUS.md`, `TEAM_COORDINATION.md`
- Playwright lockfile recovery: `C:\Users\darcy\.claude\projects\C--dev-story-weaver-app\memory\reference_playwright_mcp_lockfile.md`
- Phase 7 audio-only origin: TEAM_COORDINATION.md session 2026-04-19i
- Creator/Adolescent differentiation plan (unshipped): TEAM_COORDINATION.md session 2026-04-19n
- BUG-P6-01 fix: TEAM_COORDINATION.md session 2026-04-19j
