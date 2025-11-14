import 'package:firebase_analytics/firebase_analytics.dart';

class PrivacyService {
  PrivacyService._();

  static Future<void> setAnalyticsConsent(bool consented) async {
    await FirebaseAnalytics.instance.setAnalyticsCollectionEnabled(consented);
  }

  static Future<void> resetAnalyticsData() async {
    await FirebaseAnalytics.instance.resetAnalyticsData();
  }
}
