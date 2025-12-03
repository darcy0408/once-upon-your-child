import 'dart:async';

import 'package:flutter/material.dart';
// import 'package:sentry_flutter/sentry_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
// import 'package:story_weaver_app/services/secure_storage_service.dart';

import 'config/environment.dart';
import 'main_story.dart';
import 'theme/app_theme.dart';
import 'onboarding_screen.dart';
import 'services/onboarding_service.dart';
import 'services/parental_consent_service.dart';
import 'services/firebase_analytics_service.dart';
import 'services/subscription_service.dart';
import 'screens/age_gate_screen.dart';

const String _sentryDsn = String.fromEnvironment(
  'SENTRY_DSN',
  defaultValue: '',
);

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // One-time migration to secure storage - disabled for now
  // final prefs = await SharedPreferences.getInstance();
  // final migrated = prefs.getBool('secure_storage_migrated') ?? false;
  // if (!migrated) {
  //   await SecureStorageService.migrateFromSharedPreferences();
  // }

  // Sentry disabled for now
  // if (_sentryDsn.isEmpty) {
    await _initializeAnalytics();
    runApp(const StoryWeaverApp());
    return;
  // }

  // await SentryFlutter.init(
  //   (options) {
  //     options.dsn = _sentryDsn;
  //     options.environment = Environment.isDevelopment
  //         ? 'development'
  //         : Environment.isStaging
  //             ? 'staging'
  //             : 'production';
  //     options.tracesSampleRate = 0.1;
  //     options.beforeSend = (event, {hint}) {
  //       final dsn = options.dsn;
  //       if (Environment.isDevelopment || dsn == null || dsn.isEmpty) {
  //         return null;
  //       }
  //       return event;
  //     };
  //     options.enableTimeToFullDisplayTracing = false;
  //   },
  //   appRunner: () async {
  //     await _initializeAnalytics();
  //     runApp(const StoryWeaverApp(enableSentryNavigation: true));
  //   },
  // );
}

Future<void> _initializeAnalytics() async {
  // Initialize Firebase with graceful degradation
  try {
    await FirebaseAnalyticsService.initialize();
    // Track app start after Firebase initialization
    // TODO: Add PerformanceAnalytics tracking
    // await PerformanceAnalytics.trackAppStart();
  } catch (e, stackTrace) {
    // await Sentry.captureException(e, stackTrace);
    print('Analytics initialization error: $e');
  }
}

class StoryWeaverApp extends StatefulWidget {
  const StoryWeaverApp({
    super.key,
    this.enableSentryNavigation = false,
  });

  final bool enableSentryNavigation;

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
      // navigatorObservers: widget.enableSentryNavigation
      //     ? [
      //         SentryNavigatorObserver(),
      //       ]
      //     : const [],
      navigatorObservers: const [],
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
