import 'firebase_analytics_service.dart';

class OnboardingAnalytics {
  static Future<void> trackFeatureViewed(String featureName) async {
    if (!FirebaseAnalyticsService.isInitialized || FirebaseAnalyticsService.analytics == null) {
      return; // Graceful degradation when Firebase unavailable
    }

    try {
      await FirebaseAnalyticsService.analytics!.logEvent(
        name: 'feature_viewed',
        parameters: {'feature_name': featureName},
      );
    } catch (e) {
      // Silently fail if analytics logging fails
    }
  }

  static Future<void> trackOnboardingCompleted({
    required int timeSpentSeconds,
    required bool skippedAnyStep,
  }) async {
    if (!FirebaseAnalyticsService.isInitialized || FirebaseAnalyticsService.analytics == null) {
      return; // Graceful degradation when Firebase unavailable
    }

    try {
      await FirebaseAnalyticsService.analytics!.logEvent(
        name: 'onboarding_completed',
        parameters: {
          'time_spent_seconds': timeSpentSeconds,
          'skipped_any_step': skippedAnyStep,
        },
      );
    } catch (e) {
      // Silently fail if analytics logging fails
    }
  }
}
