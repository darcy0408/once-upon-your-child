import 'dart:async';

import 'package:flutter/material.dart';

import 'config/environment.dart';
import 'main_story.dart';
import 'theme/app_theme.dart';
import 'onboarding_screen.dart';
import 'services/onboarding_service.dart';
import 'services/firebase_analytics_service.dart';
import 'services/performance_analytics.dart';
import 'services/subscription_service.dart';
import 'character_creation_screen_enhanced.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Firebase with graceful degradation
  try {
    await FirebaseAnalyticsService.initialize();
    // Track app start after Firebase initialization
    await PerformanceAnalytics.trackAppStart();
  } catch (e) {
    // Firebase initialization failed - continue without analytics
  }

  runApp(const StoryWeaverApp());
}

class StoryWeaverApp extends StatefulWidget {
  const StoryWeaverApp({super.key});

  @override
  State<StoryWeaverApp> createState() => _StoryWeaverAppState();
}

class _StoryWeaverAppState extends State<StoryWeaverApp> {
  final OnboardingService _onboardingService = const OnboardingService();
  final SubscriptionService _subscriptionService = SubscriptionService();
  bool? _hasCompletedOnboarding;

  @override
  void initState() {
    super.initState();
    unawaited(_subscriptionService.initialize());
    _loadOnboardingStatus();
  }

  Future<void> _loadOnboardingStatus() async {
    final hasCompleted = await _onboardingService.hasCompletedOnboarding();
    if (mounted) {
      setState(() {
        _hasCompletedOnboarding = hasCompleted;
      });
    }
  }

  Future<void> _handleOnboardingFinished() async {
    await _onboardingService.markOnboardingComplete();
    if (mounted) {
      setState(() {
        _hasCompletedOnboarding = true;
      });
    }
  }

  void _navigateToCharacterDemo() {
    // Navigate to character creation screen during onboarding
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => const CharacterCreationScreenEnhanced(),
      ),
    );
  }

  void _navigateToStoryDemo() {
    // Navigate to story creation screen during onboarding
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => const StoryCreatorApp(),
      ),
    );
  }

  Widget _buildLoading() {
    return const MaterialApp(
      home: Scaffold(
        body: Center(
          child: CircularProgressIndicator(),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final status = _hasCompletedOnboarding;
    if (status == null) {
      return _buildLoading();
    }

    if (status) {
      return const StoryCreatorApp();
    }

    return MaterialApp(
      title: Environment.appName,
      theme: AppTheme.light(primaryColor: Environment.primaryColor),
      debugShowCheckedModeBanner: !Environment.isProduction,
      home: OnboardingScreen(
        onFinished: _handleOnboardingFinished,
        onSkipConfirmed: _handleOnboardingFinished,
        onTryCharacterDemo: _navigateToCharacterDemo,
        onPreviewStoryDemo: _navigateToStoryDemo,
      ),
      builder: (context, child) {
        if (child == null || !Environment.showFlavorBanner) {
          return child ?? const SizedBox.shrink();
        }
        return Banner(
          message: Environment.bannerLabel,
          location: BannerLocation.topStart,
          color: Environment.bannerColor,
          textStyle: const TextStyle(
            fontWeight: FontWeight.bold,
            letterSpacing: 1.2,
          ),
          child: child,
        );
      },
    );
  }
}
