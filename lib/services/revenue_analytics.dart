import 'package:firebase_analytics/firebase_analytics.dart';

class RevenueAnalytics {
  RevenueAnalytics._();

  static FirebaseAnalytics get _analytics => FirebaseAnalytics.instance;

  static Future<void> trackSubscriptionStarted({
    required String planType,
    required double price,
  }) async {
    try {
      await _analytics.logEvent(
        name: 'subscription_started',
        parameters: {
          'plan_type': planType,
          'price': price,
        },
      );
    } catch (e) {
      debugPrint('RevenueAnalytics error: ${e.toString()}');
    }
  }

  static Future<void> trackPurchase({
    required String itemId,
    required double value,
  }) async {
    try {
      await _analytics.logPurchase(
        currency: 'USD',
        value: value,
        items: [AnalyticsEventItem(itemId: itemId)],
      );
    } catch (e) {
      debugPrint('RevenueAnalytics error: ${e.toString()}');
    }
  }
}
