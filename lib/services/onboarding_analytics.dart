import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:flutter/foundation.dart' show kIsWeb;

class OnboardingAnalytics {
  OnboardingAnalytics._();

  static FirebaseAnalytics? get _analytics {
    // Disable Firebase Analytics on web due to compatibility issues
    if (kIsWeb) return null;
    return FirebaseAnalytics.instance;
  }

  static Future<void> trackOnboardingCompleted({
    required int timeSpentSeconds,
    required bool skippedAnyStep,
  }) async {
    if (_analytics == null) return; // Skip on web
    await _analytics!.logEvent(
      name: 'onboarding_completed',
      parameters: {
        'time_spent_seconds': timeSpentSeconds,
        'skipped_any_step': skippedAnyStep,
      },
    );
  }

  static Future<void> trackFeatureViewed(String featureName) async {
    if (_analytics == null) return; // Skip on web
    await _analytics!.logEvent(
      name: 'feature_viewed',
      parameters: {'feature_name': featureName},
    );
  }

  static Future<void> trackOnboardingSkipped({int? step}) async {
    if (_analytics == null) return; // Skip on web
    await _analytics!.logEvent(
      name: 'onboarding_skipped',
      parameters: {
        if (step != null) 'step': step,
      },
    );
  }
}
