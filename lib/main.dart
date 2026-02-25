import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sentry_flutter/sentry_flutter.dart';

import 'main_story.dart';
import 'services/isar_service.dart';
import 'services/firebase_analytics_service.dart';
import 'services/subscription_service.dart';
import 'services/storage_migration.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await IsarService.getInstance();
  await StorageMigration.migrateFromSharedPreferences();

  // Initialize Firebase with graceful degradation
  // Skip Firebase on web debug builds to avoid window.dart assertion warnings
  if (!kIsWeb || kReleaseMode) {
    try {
      await FirebaseAnalyticsService.initialize();
    } catch (e) {
      // Firebase initialization failed - continue without analytics
    }
  }

  await SentryFlutter.init(
    (options) {
      options.dsn = 'https://56313041925cdc0d25e6f83dd9f5529b@o4510948068491264.ingest.us.sentry.io/4510948091559936';
      options.tracesSampleRate = 0.2;
      options.environment = kReleaseMode ? 'production' : 'development';
    },
    appRunner: () => runApp(
      const ProviderScope(
        child: StoryWeaverApp(),
      ),
    ),
  );
}

class StoryWeaverApp extends ConsumerStatefulWidget {
  const StoryWeaverApp({super.key});

  @override
  ConsumerState<StoryWeaverApp> createState() => _StoryWeaverAppState();
}

class _StoryWeaverAppState extends ConsumerState<StoryWeaverApp> {
  final SubscriptionService _subscriptionService = SubscriptionService();

  @override
  void initState() {
    super.initState();
    unawaited(_subscriptionService.initialize());
  }

  @override
  Widget build(BuildContext context) {
    // Skip onboarding and go directly to the main app (Wizard flow)
    return const StoryCreatorApp();
  }
}
