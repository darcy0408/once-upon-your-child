import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sentry_flutter/sentry_flutter.dart';

import 'main_story.dart';
import 'services/app_tts_service.dart';
import 'services/isar_service.dart';
import 'services/firebase_analytics_service.dart';
import 'services/screen_time_service.dart';
import 'services/subscription_service.dart';
import 'services/storage_migration.dart';
import 'screens/times_up_screen.dart';

Future<void> main() async {
  await SentryFlutter.init(
    (options) {
      options.dsn =
          'https://56313041925cdc0d25e6f83dd9f5529b@o4510948068491264.ingest.us.sentry.io/4510948091559936';
      options.tracesSampleRate = 0.2;
      options.environment = kReleaseMode ? 'production' : 'development';
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
