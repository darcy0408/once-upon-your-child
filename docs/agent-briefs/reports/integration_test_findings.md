# Integration Test Findings

Authored from branch `agent/integration-tests`, worktree `C:\dev\story-weaver-app-tests`. These are observations from attempting to build out `integration_test/` coverage per `docs/agent-briefs/BRIEF_integration_tests.md`. The dev should triage; nothing here is a fix.

## 0. Environment / runtime status (read this first)

After this session the toolchain is mostly there but integration tests **still cannot complete a run** on this machine. Here's what's installed and what's blocking.

### Installed during this session

| Component | Why | How |
|---|---|---|
| VS 2022 Build Tools 17.14.31 + `VCTools` workload | Windows desktop builds | `winget install Microsoft.VisualStudio.2022.BuildTools --override "--quiet --wait --add Microsoft.VisualStudio.Workload.VCTools --includeRecommended"` |
| `nuget.exe` (winget alias under `~/AppData/Local/Microsoft/WinGet/Links/`) | `flutter_tts` plugin's CMakeLists.txt requires it | `winget install Microsoft.NuGet` |
| `Microsoft.VisualStudio.Component.VC.ATL` + `.VC.ATLMFC` | `flutter_secure_storage_windows_plugin.cpp` includes `<atlstr.h>` | `vs_BuildTools.exe modify --installPath ... --add Microsoft.VisualStudio.Component.VC.ATL --add Microsoft.VisualStudio.Component.VC.ATLMFC --quiet --wait --norestart` (note: bootstrapper exits 0 *immediately* even with `--wait`; the actual install is delegated to a background `setup.exe`/`msiexec` — verify with `vswhere -property installationVersion` and a `Get-ChildItem ... atlstr.h` probe before assuming it's done). |

### Build-time workaround

`cmake_install.cmake` defaults `CMAKE_INSTALL_PREFIX` to `C:/Program Files/story_weaver_app/` which fails for non-admin users with:

> `file cannot create directory: C:/Program Files/story_weaver_app. Maybe need administrative privileges.`

Workaround used: export `CMAKE_INSTALL_PREFIX=C:/dev/story-weaver-app-tests/build/windows/x64/install` before running `flutter test|drive`. Permanent fix: add a setter in `windows/CMakeLists.txt` that defaults `CMAKE_INSTALL_PREFIX` to `${CMAKE_BINARY_DIR}/install` when the user hasn't set one.

With these in place, **the build pipeline succeeds end-to-end**:

```
Building Windows application...                                    17.1s
✓ Built build\windows\x64\runner\Debug\story_weaver_app.exe
```

Running the binary directly (`./build/windows/x64/runner/Debug/story_weaver_app.exe`) works — it opens the app window cleanly.

### What still blocks the test runner

`flutter test integration_test/foo.dart -d windows` and `flutter drive --driver=test_driver/integration_test.dart --target=integration_test/foo.dart -d windows` both fail at:

```
✓ Built build\windows\x64\runner\Debug\story_weaver_app.exe
Error waiting for a debug connection: The log reader stopped unexpectedly, or never started.
Application failed to start on attempt: 1 (then 2, then 3)
Application failed to start. Will not run test. Quitting.
```

This is a Flutter limitation, not a test-code or app issue. `windows/runner/main.cpp` builds as a Windows GUI subsystem app via `wWinMain`. Such apps have no stdout pipe that the parent process (the flutter tool) can read, so the tool never sees the VM Service URL and gives up. `AttachConsole(ATTACH_PARENT_PROCESS)` only succeeds when the parent owns a console; the Flutter test harness on Windows does not consistently provide one. Reproduced from both Bash and PowerShell.

A `test_driver/integration_test.dart` file was added here to enable the `flutter drive` path, since it's the documented workaround for desktop integration tests. It didn't help, but the file is harmless and correct (standard `integrationDriver()` entrypoint) so it's left in place for when this is fixed upstream or worked around.

**Two viable paths to actually run these tests:**

- **Convert the runner to a console subsystem app.** Edit `windows/runner/CMakeLists.txt` to switch the linker subsystem from `WINDOWS` to `CONSOLE` for debug builds only, OR change `main.cpp` to expose `int main()` and use `AllocConsole()` proactively. Tracked as a Flutter-side issue: see https://github.com/flutter/flutter/issues/93666 and related.
- **Run on an Android emulator.** SDK is installed (`flutter doctor` shows `[✓] Android toolchain`), but no AVD exists. `flutter emulators --create` then `flutter emulators --launch <name>`, then `flutter test integration_test/foo.dart -d <emulator-id>`. Approx 2–4 GB image download.

Until one of those is done, `dart analyze integration_test/*.dart` passing is the strongest verification we have for the new test files.

## 1. Wizard PageView is not deterministically driveable from a test (P0 blocker)

`lib/screens/wizard_steps/hero_creator_step.dart` is a `PageView` with 7 inner pages, several of which:

- **Auto-advance after a delay.** `Page 2: Gender Selection` auto-advances 400ms after a tap; `Page 3: Archetype Selection` and `Custom Avatar Screen` similarly call a 600ms timer (`lib/custom_avatar_screen.dart:344` `_sproutAutoAdvance`).
- **Run pulse animations on archetype cards** that never settle, so `tester.pumpAndSettle()` times out.
- **Have no test keys** on the "next" arrow buttons or the archetype/companion/scene cards — `Semantics(label: 'Role: ...')` is present on archetypes but there's no `Key('test_next_step')` style hook.

Net effect: a `testWidgets` callback driving the wizard has to use `tester.pump(Duration)` with hand-tuned waits between every tap, and even then animation state can leave the test stuck. The compact, robust fix is one of:

- Add a `bool kReducedAnimations` debug flag readable in `HeroCreatorStep` that disables auto-advance and skips the pulse animation when set.
- Add `Key('test_step_next')`-style keys on the per-page "next" arrow and on each archetype/companion/scene card in a stable order. The brief allows test keys on lib files.

Until then, the test `Complete wizard → /generate-story fires → result screen renders` in `integration_test/hero_to_result_e2e_test.dart` is `skip: true` and the only passing assertion in that file is the smoke test (`App boots past onboarding and renders the wizard`).

Files referenced:
- `lib/screens/wizard_steps/hero_creator_step.dart` (lines ~1789+ for image picker hook, plus PageView setup)
- `lib/screens/wizard_story_screen.dart:220` (reads `user_name` pref)

## 2. Custom-avatar request can't be intercepted by `ApiServiceManager.setTestClient` (P1 blocker)

The existing test seam — `ApiServiceManager.setTestClient(http.Client)` at `lib/services/api_service_manager.dart:541` — only intercepts requests that flow through `_testClient` inside `ApiServiceManager.post/get/...`.

The custom-avatar reference-photo flow does NOT use that path. `lib/custom_avatar_screen.dart:417-444` builds an `http.MultipartRequest` directly and calls `request.send()`, which constructs its own internal `IOClient(HttpClient())`. There is no client injection point.

Practical consequences for tests:
- The test in `integration_test/avatar_reference_photo_test.dart` can mock `image_picker` (works fine via `MethodChannel('plugins.flutter.io/image_picker')`) but it cannot intercept the outbound multipart request, so it cannot assert request shape (the `photo` field, the `character_name`/`age`/`gender`/`hair_color`/`eye_color`/`favorite_color` fields, or that the request even fires).
- The brief's P1 ask "assert correct MIME header and request shape" is partially impossible from the Flutter side anyway — the client hardcodes `filename: 'photo.jpg'` regardless of input bytes, and MIME detection is server-side (magic-byte sniff in `backend/services/avatar_generation_service.py`, per commit `01859be6`).

Recommended fix (one of):
- Refactor `_generateAvatar` in `custom_avatar_screen.dart` to accept an optional `http.Client` (default `null`, fall back to `ApiServiceManager._testClient ?? http.Client()`), and pass `request.send(client)` via the optional client.
- Or, add `ApiServiceManager.postMultipart(...)` that consults `_testClient` like the other methods, and route custom-avatar through it.

Either change is small and unblocks the full P1 test.

## 3. `integration_test/story_creation_e2e_test.dart` references stale UI text

The existing template test reads:

```dart
await tester.tap(find.text('Create New Character'));     // STALE
// ...
await tester.tap(find.text('Adventurer'));               // depends on age band
await tester.tap(find.text('Brave'));                    // depends on age band
await tester.tap(find.text('Curious'));                  // depends on age band
await tester.tap(find.text('Continue'));                 // STALE — uses arrow icon, not labelled button
await tester.tap(find.text('Scared'));                   // STALE — feelings step moved out of main wizard
await tester.tap(find.text('A little'));                 // STALE — old intensity picker is gone
await tester.tap(find.text('Create My Story!'));         // VALID (hint text on Sprout final button)
```

`'Create New Character'` does not appear anywhere in the current wizard (the closest is `'Or create someone new'` as a `TextButton.icon` on the "Welcome back" page). Several other strings reference an old "Feelings → intensity" step that has since been split into a separate `LifeQuestScreen`. The test would not pass today even if the toolchain were available.

The brief says "Do not modify existing tests", so this file is left alone — but the dev should plan to either rewrite it against the current wizard text or delete it.

## 4. `app.main()` initializes many real services on every test boot

When a test calls `app.main()`, `lib/main.dart:18-52` runs Sentry init, `WidgetsFlutterBinding.ensureInitialized()`, `IsarService.getInstance()` (touches the real on-disk DB), `StorageMigration.migrateFromSharedPreferences()`, `AppTtsService.instance.init()`, `ScreenTimeService.instance.start()`, and Firebase init (`if (!kIsWeb || kReleaseMode)`).

This is fine for headed runs (`-d windows`) but means tests share state across runs via Isar (`~/Documents/<app>/default.isar` or platform-equivalent). Watch for flake when tests leave saved-character or subscription state behind. Consider a `--dart-define=APP_TEST_MODE=true` switch in `main.dart` that skips Sentry/Isar/Firebase/TTS init when set, so integration tests boot a known-clean app.

## 5. P2 not attempted

Subscription / paywall gating coverage (`integration_test/free_tier_cap_test.dart`) was not started. The brief's 90-min budget had already been consumed by:

- Mapping the wizard PageView surface (item #1).
- Identifying and writing around the multipart-client gap (item #2).
- Discovering the toolchain blocker (item #0).

The shape would be: pre-seed `SharedPreferences` with `is_paid_premium=false`, mock `SubscriptionService.getRemainingStoriesToday() → 0`, attempt to generate, assert `SubscriptionManagementScreen` or upsell text appears. Estimated 30–45 minutes once the toolchain blocker is gone, and only if the wizard-driving issue (#1) is resolved or sidestepped (e.g. by jumping directly into the generate flow via `Navigator.pushNamed`).

## Summary table

| Item | Severity | Blocks |
|---|---|---|
| 0. No VS toolchain installed | Hard blocker | All integration test execution |
| 1. Wizard not driveable without test seams | Soft blocker | Full P0 e2e assertion |
| 2. Multipart not interceptable | Soft blocker | Full P1 network-shape assertion |
| 3. Stale template test text | Cleanup | Future maintenance |
| 4. Real services on every boot | Risk | Cross-run flake |
| 5. P2 unstarted | Scope | Free-tier cap coverage |
