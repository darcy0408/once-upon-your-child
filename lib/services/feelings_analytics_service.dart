import 'firebase_analytics_service.dart';

class FeelingsAnalyticsService {
  FeelingsAnalyticsService._();

  static Future<void> trackScreenViewed() {
    return FirebaseAnalyticsService.logEvent('feelings_corner_viewed', {
      'screen': 'feelings_corner',
      'timestamp': DateTime.now().toIso8601String(),
    });
  }

  static Future<void> trackCheckInLogged({
    required String emotion,
    required int intensity,
  }) {
    return FirebaseAnalyticsService.logEvent('feelings_check_in', {
      'emotion': emotion,
      'intensity': intensity,
      'voluntary': true,
      'screen': 'feelings_corner',
    });
  }

  static Future<void> trackReminderToggled(bool enabled) {
    return FirebaseAnalyticsService.logEvent('feelings_reminder_toggled', {
      'enabled': enabled,
      'screen': 'feelings_corner',
    });
  }
}
