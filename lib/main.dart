import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'config/environment.dart';
import 'main_story.dart';
import 'providers/theme_provider.dart';
import 'theme/app_theme.dart';
import 'onboarding_screen.dart';
import 'services/isar_service.dart';
import 'services/onboarding_service.dart';
import 'services/parental_consent_service.dart';
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
    // Track app start after Firebase initialization
    // TODO: Add PerformanceAnalytics tracking
    // await PerformanceAnalytics.trackAppStart();
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

  Widget _buildLoading() {
    final themeMode = ref.watch(themeModeNotifierProvider);
    return _buildThemedApp(
      themeMode,
      const Scaffold(
        body: Center(
          child: CircularProgressIndicator(),
        ),
      ),
    );
  }

  Widget _buildThemedApp(ThemeMode themeMode, Widget home) {
    final darkTheme = ThemeData.dark().copyWith(
      colorScheme: ColorScheme.fromSeed(
        seedColor: Environment.primaryColor,
        brightness: Brightness.dark,
        primary: AppColors.primary,
        secondary: AppColors.secondary,
      ),
      scaffoldBackgroundColor: const Color(0xFF0F1115),
      appBarTheme: const AppBarTheme(
        elevation: 0,
        backgroundColor: Color(0xFF1A1D23),
        foregroundColor: Colors.white,
      ),
      cardColor: const Color(0xFF1E2229),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: AppColors.primary,
        contentTextStyle: const TextStyle(color: Colors.white),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: const Color(0xFF1E2229),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey.shade700),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: AppColors.primary, width: 2),
        ),
      ),
    );

    return MaterialApp(
      title: Environment.appName,
      theme: AppTheme.light(primaryColor: Environment.primaryColor),
      darkTheme: darkTheme,
      themeMode: themeMode,
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
    final themeMode = ref.watch(themeModeNotifierProvider);

    if (onboardingStatus == null || consentStatus == null) {
      return _buildLoading();
    }

    // TEMPORARY: Skip age gate for family demo
    // if (!consentStatus) {
    //   return _buildThemedApp(
    //     themeMode,
    //     AgeGateScreen(
    //       consentService: _consentService,
    //       onConsentCompleted: _handleConsentCompleted,
    //     ),
    //   );
    // }

    if (onboardingStatus) {  // TEMPORARY: Always skip to main app
      return const StoryCreatorApp();
    }

    return _buildThemedApp(
      themeMode,
      OnboardingScreen(
        onFinished: _handleOnboardingFinished,
        onSkipConfirmed: _handleOnboardingFinished,
      ),
    );
  }
}
