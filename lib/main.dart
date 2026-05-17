import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sentry_flutter/sentry_flutter.dart';

import 'config/environment.dart';
import 'main_story.dart';
import 'services/app_tts_service.dart';
import 'services/isar_service.dart';
import 'services/firebase_analytics_service.dart';
import 'services/screen_time_service.dart';
import 'services/sentry_consent_gate.dart';
import 'services/subscription_service.dart';
import 'services/storage_migration.dart';
import 'screens/times_up_screen.dart';

Future<void> main() async {
  await SentryFlutter.init(
    (options) {
      options.dsn = Environment.sentryDsn;
      options.environment = kReleaseMode ? 'production' : 'development';
      // Don't ship dev/test errors or traces to Sentry — local logs are richer
      // and a single bad headless run can flood the project (see STORY-WEAVER-1K).
      // STORE-2: keep the release sample rate well below 1.0 so a child's
      // session never floods the project even after consent is granted.
      options.sampleRate = kReleaseMode ? 0.2 : 0.0;
      options.tracesSampleRate = kReleaseMode ? 0.2 : 0.0;
      // STORE-2 (COPPA §312.5 / Apple Kids-Category 1.3, 5.1.4): never attach
      // device/user PII to events from a children's app.
      options.sendDefaultPii = false;
      options.beforeSend = (event, hint) {
        // STORE-2: Sentry's init() must wrap runApp, so it cannot be deferred.
        // Instead, drop EVERY event until a parental-consent decision has
        // enabled reporting (consent granted AND declared age >= 13). This
        // mirrors how Firebase Analytics collection is consent-gated.
        if (!SentryConsentGate.isReportingEnabled) {
          return null;
        }
        final isDwds = event.exceptions?.any((ex) =>
                ex.stackTrace?.frames.any((f) =>
                    (f.fileName?.contains('dwds/src/injected/client.js') ??
                        false) ||
                    (f.absPath?.contains('dwds/src/injected/client.js') ??
                        false)) ??
                false) ??
            false;
        return isDwds ? null : event;
      };
    },
    appRunner: () async {
      WidgetsFlutterBinding.ensureInitialized();

      await IsarService.getInstance();
      await StorageMigration.migrateFromSharedPreferences();
      unawaited(AppTtsService.instance.init());
      ScreenTimeService.instance.start();

      // Initialize Firebase with graceful degradation
      // Skip Firebase on web debug builds to avoid window.dart assertion warnings
      if (!kIsWeb || kReleaseMode) {
        try {
          await FirebaseAnalyticsService.initialize();
        } catch (e) {
          // Firebase initialization failed - continue without analytics
        }
      }

      runApp(
        const ProviderScope(
          child: StoryWeaverApp(),
        ),
      );
    },
  );
}

class StoryWeaverApp extends ConsumerStatefulWidget {
  const StoryWeaverApp({super.key});

  @override
  ConsumerState<StoryWeaverApp> createState() => _StoryWeaverAppState();
}

class _StoryWeaverAppState extends ConsumerState<StoryWeaverApp> {
  final SubscriptionService _subscriptionService = SubscriptionService();
  late final StreamSubscription<int> _windDownSub;
  late final StreamSubscription<int> _limitSub;
  late final StreamSubscription<void> _bedtimeSub;
  bool _timesUpVisible = false;

  @override
  void initState() {
    super.initState();
    // Defer until after the first frame so the auth token has time to
    // restore from secure storage before we hit backend endpoints.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(_subscriptionService.initialize());
    });
    _windDownSub = ScreenTimeService.instance.onWindDown.listen((remaining) {
      rootScaffoldMessengerKey.currentState?.showSnackBar(
        SnackBar(
          content: Text(
            '$remaining minutes left! Time to start wrapping up.',
          ),
          backgroundColor: Colors.orange,
          duration: const Duration(seconds: 5),
        ),
      );
    });
    _limitSub = ScreenTimeService.instance.onLimitReached.listen((_) {
      unawaited(_showTimesUp('limit'));
    });
    _bedtimeSub = ScreenTimeService.instance.onBedtimeLockout.listen((_) {
      unawaited(_showTimesUp('bedtime'));
    });
  }

  Future<void> _showTimesUp(String reason) async {
    if (_timesUpVisible) {
      return;
    }
    final navigator = rootNavigatorKey.currentState;
    if (navigator == null) {
      return;
    }
    _timesUpVisible = true;
    try {
      await navigator.push<bool>(
        MaterialPageRoute(
          builder: (_) => TimesUpScreen(reason: reason),
          fullscreenDialog: true,
        ),
      );
    } finally {
      _timesUpVisible = false;
    }
  }

  @override
  void dispose() {
    _windDownSub.cancel();
    _limitSub.cancel();
    _bedtimeSub.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Skip onboarding and go directly to the main app (Wizard flow)
    return const StoryCreatorApp();
  }
}
