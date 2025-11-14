import 'package:flutter/material.dart';

import 'main_story.dart';
import 'theme/app_theme.dart';
import 'onboarding_screen.dart';
import 'services/onboarding_service.dart';
import 'services/firebase_analytics_service.dart';
import 'services/performance_analytics.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Temporarily disabled for testing therapeutic features
  // await FirebaseAnalyticsService.initialize();
  // await PerformanceAnalytics.trackAppStart();
  runApp(const StoryWeaverApp());
}

class StoryWeaverApp extends StatefulWidget {
  const StoryWeaverApp({super.key});

  @override
  State<StoryWeaverApp> createState() => _StoryWeaverAppState();
}

class _StoryWeaverAppState extends State<StoryWeaverApp> {
  final OnboardingService _onboardingService = const OnboardingService();
  bool? _hasCompletedOnboarding;

  @override
  void initState() {
    super.initState();
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
      title: 'Story Weaver Onboarding',
      theme: AppTheme.light(),
      home: OnboardingScreen(
        onFinished: _handleOnboardingFinished,
        onSkipConfirmed: _handleOnboardingFinished,
      ),
    );
  }
}
