import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

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
  try {
    await FirebaseAnalyticsService.initialize();
  } catch (e) {
    // Firebase initialization failed - continue without analytics
  }

  runApp(
    const ProviderScope(
      child: StoryWeaverApp(),
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
