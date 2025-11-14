import 'package:firebase_analytics/firebase_analytics.dart';

class RevenueAnalytics {
  RevenueAnalytics._();

  static FirebaseAnalytics get _analytics => FirebaseAnalytics.instance;

  static Future<void> trackSubscriptionStarted({
    required String planType,
    required double price,
  }) async {
    await _analytics.logEvent(
      name: 'subscription_started',
      parameters: {
        'plan_type': planType,
        'price': price,
      },
    );
  }

  static Future<void> trackPurchase({
    required String itemId,
    required double value,
  }) async {
    await _analytics.logPurchase(
      currency: 'USD',
      value: value,
      items: [AnalyticsEventItem(itemId: itemId)],
    );
  }
}
