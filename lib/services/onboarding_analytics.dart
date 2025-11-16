import 'package:firebase_analytics/firebase_analytics.dart';

class OnboardingAnalytics {
  OnboardingAnalytics._();

  static FirebaseAnalytics get _analytics => FirebaseAnalytics.instance;

  static Future<void> trackOnboardingCompleted({
    required int timeSpentSeconds,
    required bool skippedAnyStep,
  }) async {
    await _analytics.logEvent(
      name: 'onboarding_completed',
      parameters: {
        'time_spent_seconds': timeSpentSeconds,
        'skipped_any_step': skippedAnyStep,
      },
    );
  }

  static Future<void> trackFeatureViewed(String featureName) async {
    await _analytics.logEvent(
      name: 'feature_viewed',
      parameters: {'feature_name': featureName},
    );
  }
}
