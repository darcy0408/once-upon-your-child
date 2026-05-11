# Playwright Smoke Test — How I Drive the App for You

This is the runbook the Claude session uses to smoke-test Story Weaver via the Playwright MCP. After a code change, ask: **"Run the Playwright smoke test"** and I'll execute the steps below, capture console errors + screenshots, and report what broke.

## Prerequisites (one-time per session)

1. Flutter web dev server running on `http://localhost:8080`:
   ```powershell
   flutter run -d web-server --web-port=8080 --web-hostname=localhost
   ```
2. **Backend running on `127.0.0.1:5000`** — otherwise Stripe + TTS calls 401/503 and story-gen never completes. Start it from wherever the Python backend lives.
3. Playwright MCP server connected (verify with `claude mcp list` — `mcp__playwright__*` tools should appear).

## Flutter canvas-mode caveats (verified 2026-05-11)

Flutter web renders to `<canvas>`. Playwright's accessibility snapshot will see a sparse semantics tree until Flutter's accessibility mode is enabled.

**First action after navigation:** dispatch a click on the hidden a11y placeholder to unlock semantics:
```js
mcp__playwright__browser_evaluate({ function: "() => { document.querySelector('flt-semantics-placeholder')?.click(); return 'enabled'; }" })
```
Then `browser_snapshot` returns a full tree and clicks-by-label work.

**Scrolling is hard.** Window scroll doesn't move Flutter content (it's rendered in canvas). Programmatic `WheelEvent` dispatch on `flt-glass-pane` does NOT scroll. Keyboard `End`/`PageDown` does NOT scroll. To get past scroll-gated screens (e.g., COPPA parental consent), options are:
- Add a debug-build bypass to the screen
- Use `page.mouse.wheel()` (Playwright API) with cursor positioned over the canvas
- Pre-seed `SharedPreferences` to skip the gate

**Use `flutter build web` + static serve, NOT `flutter run -d web-server`.** The web-server device requires the Dart Debug Chrome extension; without it, `main()` never runs and you get a blank page. Build once:
```powershell
flutter build web --no-tree-shake-icons
cd build\web; python -m http.server 8080
```

**Static dev backend on `127.0.0.1:5000`:**
```powershell
cd C:\dev\story-weaver-app
python -m backend.run
```
Without it: Stripe `/api/stripe/subscription-status/...` 401, TTS 503 (expected fallback, but loud in console).

## Flow under test: Hero Creator → Story Generation → Result Screen

This is the highest-leverage flow because it exercises:
- Wizard step navigation
- Form input + validation
- Backend story-gen call
- Per-page illustration prefetcher (recent risk area)
- Story result screen rendering

### Steps

1. `mcp__playwright__browser_navigate` → `http://localhost:8080`
2. `mcp__playwright__browser_wait_for` → text indicating splash/home loaded
3. `mcp__playwright__browser_console_messages` → capture any startup errors. Surface anything red.
4. `mcp__playwright__browser_take_screenshot` → baseline.png (initial state)
5. `mcp__playwright__browser_snapshot` → accessibility tree, to find click targets
6. Click "Create Story" or wizard entry (use snapshot to find exact label)
7. Walk hero creator steps:
   - Story type page: pick one
   - Scene page: pick a scene
   - Creative brief: fill superpower + quest with valid text
   - Companion selector: pick one
   - Feeling: pick one
   - Magic review: confirm
8. Trigger generation. `mcp__playwright__browser_network_requests` → capture the `/generate-story` call (or whatever endpoint). Verify status 200 and response shape.
9. Wait for result screen. `mcp__playwright__browser_wait_for` → story title or page indicator.
10. `mcp__playwright__browser_take_screenshot` → result.png
11. Click through pages, capture screenshots of each. Watch for missing illustrations (per_page_illustration_prefetcher regression).
12. Final `mcp__playwright__browser_console_messages` dump → catch any errors that fired during the flow.

### Pass criteria

- No red console errors before, during, or after the flow
- `/generate-story` returns 200 with expected JSON shape
- Result screen renders with title + first page
- Each story page has an illustration (no broken-image icons in screenshots)

### Fail handling

When something breaks:
1. Capture: screenshot at point of failure, full console dump, last network request.
2. Write a one-paragraph failure summary at the top of the next response.
3. Do NOT attempt to fix — that's a separate decision the dev makes.

## Additional flows to add later

- **Avatar reference photo** (commit 01859be6 risk area): pick photo → assert MIME header on request → check avatar appears
- **Paywall gating** (commit 8c516e02 risk area): exceed free-tier image cap → assert upsell appears
- **Subscription checkout**: known broken per memory — skip until Stripe audit fixes land

## When to re-run

- After every meaningful change to: `lib/screens/wizard_steps/*`, `lib/story_result_screen.dart`, `lib/services/per_page_illustration_prefetcher.dart`, `lib/widgets/per_page_illustration.dart`, image-gen or story-gen backend.
- Before committing anything that touches the wizard or story result.
