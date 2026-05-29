# Assistive-Technology (AT) Verification Recipe

**App:** Once Upon YOUR Child (codebase: Story Weaver)
**Standard:** WCAG 2.2 Level AA
**Audience:** solo developer, self-running screen-reader verification
**Created:** 2026-05-22 — Accessibility remediation, Phase 0.2

This recipe is a concrete, repeatable manual procedure for verifying the app
with the three screen readers that matter for our platforms:

| Platform | Screen reader | Covered below |
|----------|---------------|---------------|
| Android  | TalkBack      | Section 1 |
| iOS      | VoiceOver     | Section 2 |
| Web (Chrome) | NVDA      | Section 3 |

Every pass walks the **same critical journey** (Section 4) and fills in the
**per-screen checklist** (Section 5). Automated coverage (`flutter test
test/a11y/`, the `a11y_lint` custom lint rules, and `@axe-core/cli` —
Section 6) catches regressions cheaply; this manual recipe is the ground
truth, because only a real screen reader exposes focus order, announcement
quality, and gesture reachability.

> Run the full recipe before each release and after any change to onboarding,
> the wizard, or the reader.

---

## 1. Android — TalkBack

### 1.1 Enable

1. Build/install a debug or profile build on a physical device
   (`flutter run -d <device>` or install the APK). TalkBack behaves
   differently on emulators — use real hardware.
2. **Settings → Accessibility → TalkBack → On.** Confirm the "use TalkBack?"
   dialog with the two-finger… actually: tap once to select **OK**, then
   double-tap to activate.
3. Optional but recommended: **Settings → Accessibility → TalkBack →
   Settings → Advanced → Developer settings → Display speech output** so you
   can *see* every announcement on screen while testing.
4. Shortcut to toggle TalkBack quickly: hold **both volume keys** for 3s
   (enable this under TalkBack → Settings → Shortcut).

### 1.2 Navigate

| Action | Gesture |
|--------|---------|
| Move to next element | Swipe **right** |
| Move to previous element | Swipe **left** |
| Activate focused element (tap) | **Double-tap** anywhere |
| Read continuously from top | Swipe **down then up** (or use the menu) |
| Scroll a list/page | **Two-finger** swipe up/down |
| Explore by touch | Drag one finger around the screen |
| Open TalkBack menu | Swipe **up then right** |
| Go back | Swipe **down then left** (L-shape) |

### 1.3 What to listen for

- Every focusable control announces a **name** + **role**
  ("Submit your name, button"), never just "button" or a raw icon name.
- Focus order matches reading order (top→bottom, left→right).
- Decorative imagery is **skipped** (not focusable).
- State changes (selected age, listening mic) are announced.

Walk the journey in Section 4; fill in Section 5.

---

## 2. iOS — VoiceOver

### 2.1 Enable

1. Install a build on a physical iPhone (`flutter run -d <device>` or
   TestFlight/Xcode). Use real hardware — the simulator's VoiceOver is
   limited.
2. **Settings → Accessibility → VoiceOver → On.**
3. Set up the toggle shortcut: **Settings → Accessibility → Accessibility
   Shortcut → VoiceOver.** Now **triple-click the side/home button** turns it
   on and off — essential, because the device is hard to operate with
   VoiceOver on if something goes wrong.
4. Optional: **Settings → Accessibility → VoiceOver → Caption Panel → On** to
   see announcements as text at the bottom of the screen.

### 2.2 Navigate

| Action | Gesture |
|--------|---------|
| Move to next element | Swipe **right** |
| Move to previous element | Swipe **left** |
| Activate focused element | **Double-tap** anywhere |
| Read all from current position | **Two-finger swipe down** |
| Scroll | **Three-finger** swipe up/down |
| Explore by touch | Drag one finger |
| Go back (top-left nav) | Tap top-left area, double-tap; or use the rotor |
| Rotor (change navigation mode) | **Two-finger twist** |

### 2.3 What to listen for

Same criteria as TalkBack (Section 1.3). Additionally:

- VoiceOver announces text fields as "text field" and reads the
  `labelText` / `Semantics(label:)`; an unlabelled field announces only
  "text field" — a failure.
- The rotor → "Headings" should let you jump between section headings if any
  are exposed.

---

## 3. Web (Chrome) — NVDA

### 3.1 Enable

1. NVDA is Windows-only and free: download from
   <https://www.nvaccess.org/download/>. Install (or run the portable copy).
2. Build the web app locally and serve it:
   ```powershell
   flutter build web
   # then serve the build (any static server), e.g.:
   dart pub global activate dhttpd   # one-time, optional
   dhttpd --path build/web --port 8080
   ```
   Or run the dev build: `flutter run -d chrome`.
   > NOTE: the app renders with the CanvasKit web renderer. Flutter exposes a
   > semantics tree to the browser only **after** the user activates the
   > hidden "Enable accessibility" placeholder button. With NVDA running,
   > press **Tab** once on first load — NVDA reads "Enable accessibility,
   > button"; activate it so the semantics tree is built. (See the project
   > note `playwright_canvaskit_technique` for background.)
3. Start NVDA (**Ctrl+Alt+N**). The **NVDA modifier key** is `Insert` (or
   `CapsLock` if you ticked that during install).

### 3.2 Navigate

| Action | Key |
|--------|-----|
| Next / previous focusable control | **Tab** / **Shift+Tab** |
| Activate control | **Enter** or **Space** |
| Read next / previous item (browse mode) | **Down** / **Up arrow** |
| Next button / form field / heading | **B** / **F** / **H** |
| Read continuously from here | **NVDA + Down arrow** |
| Stop speech | **Ctrl** |
| Elements list (links/buttons/headings) | **NVDA + F7** |
| Toggle browse vs focus mode | **NVDA + Space** |

### 3.3 What to listen for

- Tabbing reaches **every** interactive control, in a sensible order, and
  each announces a name + role.
- No keyboard trap: you can always Tab *out* of a control / dialog.
- Focus is **visible** (a focus ring or equivalent) — SC 2.4.7.
- Modal dialogs (consent notice, parent-controls prompt) move focus into the
  dialog and trap it there until dismissed — SC 2.4.3.
- Run the `@axe-core/cli` scan (Section 6) against the same build for
  contrast / ARIA / structure issues NVDA cannot surface by ear.

---

## 4. The critical journey

Walk this exact path end-to-end with each screen reader. It is the shortest
route that touches every Phase-0 critical screen.

```
Welcome  →  Parental consent  →  Wizard story step 1  →  Story reader  →  Story result
```

1. **Welcome** — launch the app fresh (clear app data first so onboarding
   shows). Teaser → enter the child's name → pick an age. Use an age **under
   13** so the consent screen appears.
2. **Parental consent** — complete the math/age gate and grant consent.
3. **Wizard story step 1** — the first story-creation step (superpower /
   quest entry). Enter or select something and continue.
4. **Story reader** — open/generate a story and page through it; exercise the
   play/pause and page-navigation controls.
5. **Story result** — reach the result screen; exercise Save / Share / Make
   another.

For each screen, complete the checklist in Section 5.

---

## 5. Per-screen checklist template

Copy this block **once per screen per screen-reader pass**. Mark each item
Pass / Fail / N/A and note the announced text for any failure.

```
Screen: ______________________   Screen reader: TalkBack / VoiceOver / NVDA
Build: ____________   Date: __________   Tester: __________

[ ] Every interactive control is reachable by swipe / Tab.
[ ] Every interactive control announces a NAME (not blank, not an icon code).
[ ] Every interactive control announces its ROLE (button / text field / etc).
[ ] Focus order follows the visual reading order.
[ ] Decorative images / animations are NOT focusable and announce nothing.
[ ] Text fields announce their label/purpose, not just "text field".
[ ] State is announced (selected / checked / listening / disabled).
[ ] Dialogs move focus inside and trap it; dismiss returns focus sensibly.
[ ] No keyboard trap — focus can always move on / out (NVDA pass).
[ ] A visible focus indicator is present (NVDA / keyboard pass).
[ ] Looping animations can be paused/stopped or respect reduced-motion.
[ ] Nothing auto-advances or times out without an accessible warning.

Notes / failures (control → what was announced → expected):
- ______________________________________________________________
- ______________________________________________________________
```

---

## 6. Automated companions

Manual AT testing is the ground truth, but three automated layers catch
regressions between manual passes.

### 6.1 Semantics widget tests

```powershell
flutter test test/a11y/
```

`test/a11y/` contains a working example
(`app_button_semantics_test.dart`) that asserts interactive nodes carry a
non-empty accessible label, plus TODO stubs for the four other critical
screens. Fill the stubs in as those screens are made testable.

### 6.2 Custom lint rules (`a11y_lint`)

```powershell
dart run custom_lint
```

The local `tools/a11y_lint/` plugin flags, at author time:
`no_unlabelled_icon_button`, `no_unlabelled_form_field`, and
`no_unguarded_repeat`. These surface in the IDE and in the command above.

### 6.3 `@axe-core/cli` against a local web build

`@axe-core/cli` runs the axe accessibility engine against a URL and reports
WCAG violations (contrast, ARIA, document structure) that a screen reader
cannot surface by ear. **Do not install it globally** — run it on demand with
`npx`, which downloads it into a temporary cache only:

```powershell
# 1. Build and serve the web app locally (one terminal):
flutter build web
npx --yes http-server build/web -p 8080 --silent

# 2. In a second terminal, scan the served build:
npx --yes @axe-core/cli http://localhost:8080 --exit
```

Notes:
- `--exit` makes the command return a non-zero exit code when violations are
  found — useful if this is later wired into CI.
- `@axe-core/cli` drives headless Chrome; it needs a Chrome/Chromium install
  on the machine (the Flutter web toolchain already requires one).
- The Flutter CanvasKit renderer builds its semantics tree lazily. axe scans
  the DOM, so for the richest results pass a deep link to the screen under
  test, or extend the scan with `--include` once routes are stable.
- To scan a specific screen, navigate there first in a normal browser, copy
  the URL, and pass it to the `@axe-core/cli` command above.

Treat axe findings as a supplement to — never a replacement for — the manual
TalkBack / VoiceOver / NVDA passes in Sections 1–5.
