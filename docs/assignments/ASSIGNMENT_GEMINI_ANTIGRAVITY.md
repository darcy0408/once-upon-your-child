# Assignment: Gemini Antigravity — Flutter/Dart UI Fixes
**Date:** 2026-03-18
**Tool:** Gemini Antigravity (VS Code fork)
**Language:** Dart / Flutter

You are working on the Story Weaver children's storytelling app.
Repo root: `C:/dev/story-weaver-app`
Flutter app is in `lib/` directory.
Backend is Python/Flask in `backend/` — you do not need to touch it for this assignment.

After completing each task, update `TEAM_COORDINATION.md` at the repo root with what you did, then commit:
```bash
git add <changed files> TEAM_COORDINATION.md
git commit -m "fix: <short description>"
```

---

## Task 1 — Fix Companion Assets Loading Wrong Folder (HIGH PRIORITY)

**Problem:** The `companion_selector_step.dart` loads companion images. For age bands `creator`, `adolescent`, and `adult`, it is referencing the `adventurer` asset folder instead of the correct age-band folder. This means companions look wrong for older kids and adults.

**Steps:**
1. Open `lib/screens/wizard_steps/companion_selector_step.dart`
2. Find where companion asset paths are constructed (look for string paths like `assets/images/` or age-band folder names)
3. Find the switch/map that selects the folder per age band
4. Verify: `creator`, `adolescent`, `adult` bands all map to their own folder (e.g., `assets/images/companions/creator/`, etc.)
5. Check `pubspec.yaml` to confirm those folders are declared as assets
6. If folders exist in the file system but aren't in pubspec, add them
7. Run `flutter analyze lib/screens/wizard_steps/companion_selector_step.dart` and fix any errors

**Verify:** The fix is correct if each age band loads companions from its own named folder, not from `adventurer`.

---

## Task 2 — Fix Scenario Card Art 404s (HIGH PRIORITY)

**Problem:** In production (and possibly locally), cards shown in the story theme/adventure picker show as text/emoji instead of images because `assets/images/scenarios/*.png` files return 404.

**Steps:**
1. Search for where scenario/adventure theme images are loaded:
   ```
   grep -r "scenarios" lib/ --include="*.dart" -l
   ```
2. Check that `assets/images/scenarios/` folder exists and contains `.png` files
3. Check `pubspec.yaml` — look for a `flutter: assets:` section and verify `assets/images/scenarios/` is listed
4. If the folder exists but isn't in pubspec, add it
5. If the folder doesn't exist, the images are missing — document this in `TEAM_COORDINATION.md` as "scenario card images not committed to repo"
6. Run `flutter analyze` on the files that reference scenario images

---

## Task 3 — Fix TypeError During Wizard (HIGH PRIORITY)

**Problem:** Browser console logs `TypeError: Cannot read properties of undefined (reading 'toString')` during wizard use. This is a null/undefined reference somewhere in the wizard flow.

**Steps:**
1. Search for `.toString()` calls on potentially nullable values in wizard files:
   ```
   grep -rn "\.toString()" lib/screens/wizard_steps/ --include="*.dart"
   ```
2. Look for cases where a nullable variable (denoted with `?` in Dart) has `.toString()` called directly without a null check
3. Common patterns to look for:
   - `someNullable.toString()` → fix to `someNullable?.toString() ?? ''`
   - `someNullable!.toString()` with unsafe force-unwrap
4. Focus especially on `WizardData` fields that might not be initialized yet when a step first loads
5. Fix any found, run `flutter analyze`, commit

---

## Task 4 — Font Warnings (LOW — do last)

**Problem:** Flutter web logs missing-glyph / Noto font warnings. Font rendering is not clean across the full character set.

**Steps:**
1. Run `flutter run -d chrome` locally and open browser devtools console
2. Look for font-loading warnings like "Could not find font" or "Noto"
3. In `pubspec.yaml`, check the `fonts:` section
4. If custom fonts are declared but the `.ttf`/`.otf` files are missing from the repo, document it
5. If Noto fonts need to be added, check the Flutter docs for how to include them via pubspec
6. A minimal fix: add `uses-material-design: true` in pubspec if missing, which provides the Material icon font

---

## Reference: Project Context

- State management: Riverpod
- Local DB: Isar
- Age bands (6): sprout, explorer, adventurer, creator, adolescent, adult
- Asset structure: `assets/images/ui/<band>/`, `assets/images/orbs/<band>/`, `assets/images/scenarios/`
- Wizard files: `lib/screens/wizard_steps/`
- Key Dart rule: always add `mounted` check before `setState`/`ScaffoldMessenger` after async gaps
- Dart uses camelCase for all method names
