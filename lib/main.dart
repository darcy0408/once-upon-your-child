import 'dart:async';

import 'package:flutter/material.dart';

import 'config/environment.dart';
import 'main_story.dart';
import 'theme/app_theme.dart';
import 'onboarding_screen.dart';
import 'services/onboarding_service.dart';
import 'services/parental_consent_service.dart';
import 'services/firebase_analytics_service.dart';
import 'services/subscription_service.dart';
import 'screens/age_gate_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Firebase with graceful degradation
  try {
    await FirebaseAnalyticsService.initialize();
    // Track app start after Firebase initialization
    // TODO: Add PerformanceAnalytics tracking
    // await PerformanceAnalytics.trackAppStart();
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
  final ParentalConsentService _consentService = const ParentalConsentService();
  bool? _hasCompletedOnboarding;
  bool? _hasConsent;

  @override
  void initState() {
    super.initState();
    unawaited(_subscriptionService.initialize());
    _loadStartupState();
  }

  Future<void> _loadStartupState() async {
    final hasCompleted = await _onboardingService.hasCompletedOnboarding();
    final consentGranted = await _consentService.hasConsent();
    if (mounted) {
      setState(() {
        _hasCompletedOnboarding = hasCompleted;
        _hasConsent = consentGranted;
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

  Future<void> _handleConsentCompleted() async {
    if (mounted) {
      setState(() => _hasConsent = true);
    }
  }

  Widget _buildLoading() {
    return _buildThemedApp(
      const Scaffold(
        body: Center(
          child: CircularProgressIndicator(),
        ),
      ),
    );
  }

  Widget _buildThemedApp(Widget home) {
    return MaterialApp(
      title: Environment.appName,
      theme: AppTheme.light(primaryColor: Environment.primaryColor),
      debugShowCheckedModeBanner: !Environment.isProduction,
      home: home,
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

  @override
  Widget build(BuildContext context) {
    final onboardingStatus = _hasCompletedOnboarding;
    final consentStatus = _hasConsent;

    if (onboardingStatus == null || consentStatus == null) {
      return _buildLoading();
    }

    // TEMPORARY: Skip age gate for family demo
    // if (!consentStatus) {
    //   return _buildThemedApp(
    //     AgeGateScreen(
    //       consentService: _consentService,
    //       onConsentCompleted: _handleConsentCompleted,
    //     ),
    //   );
    // }

    if (onboardingStatus || true) {  // TEMPORARY: Always skip to main app
      return const StoryCreatorApp();
    }

    return _buildThemedApp(
      OnboardingScreen(
        onFinished: _handleOnboardingFinished,
        onSkipConfirmed: _handleOnboardingFinished,
      ),
    );
  }
}
