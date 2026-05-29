# Cold Start Path Trace

Source: `lib/main.dart:19-100`. Every step below runs on the platform main thread
before `runApp`. Timings are code-derived estimates (no device profiling was run);
treat them as ordering and relative-cost guidance, not measured values.

## Initialization sequence

| # | Step | File:Line | Blocks first frame | Estimated cost (mid-tier Android) | Notes |
|---|------|-----------|--------------------|-----------------------------------|-------|
| 1 | `SentryFlutter.init` wrapper | main.dart:20 | Yes (wraps everything) | 30-120ms | SDK init; `beforeSend`/`beforeBreadcrumb` hooks are cheap closures |
| 2 | `WidgetsFlutterBinding.ensureInitialized` | main.dart:76 | Yes | 20-60ms | Standard binding bring-up |
| 3 | `await IsarService.getInstance()` | main.dart:78 | Yes | 80-300ms | Opens DB, registers 6 schemas; `inspector: true` adds overhead even in release |
| 4 | `await StorageMigration.migrateFromSharedPreferences()` | main.dart:79 | Yes | First launch: 300-2000ms / later: ~1-5ms | One-time: short-circuits via flag after first run (storage_migration.dart:18-21) |
| 5 | `unawaited(AppTtsService.instance.init())` | main.dart:80 | No (fire-and-forget) | 0ms to frame; 30-60s background | Prewarms ~100 phrases over network with retries - network saturation risk |
| 6 | `ScreenTimeService.instance.start()` | main.dart:81 | Yes | <1ms | Starts a 1-minute timer; negligible |
| 7 | `await FirebaseAnalyticsService.initialize()` | main.dart:87 | Yes | 100-500ms | `Firebase.initializeApp()` is native and blocking; collection stays disabled |
| 8 | `runApp(ProviderScope(StoryWeaverApp))` | main.dart:93 | - | - | First frame scheduled here |
| 9 | `SubscriptionService.initialize()` | main.dart:121-122 | No (postFrameCallback) | Off critical path | Network sync with 1s/2s/4s retry backoff; anonymous users short-circuit |

## Critical-path sum (blocking first frame)

- Steps 1+2+3+7 (every launch): roughly **230-980ms** before first frame.
- Add step 4 on first-ever launch with story history: **+300-2000ms**.

## Removable from the critical path

- Step 7 (Firebase): move into the `addPostFrameCallback` already used for
  SubscriptionService. Analytics collection is disabled at init anyway, so no
  event is lost by deferring. Saves 100-500ms off first frame.
- Step 3 inspector flag: gate `inspector` on `!kReleaseMode` in
  `isar_service_io.dart:39`.
- Step 5 prewarm: already non-blocking for the frame, but bound it (cap phrase
  count, add a total wall-clock timeout) so it does not saturate the network
  while the user is on the first screen.
