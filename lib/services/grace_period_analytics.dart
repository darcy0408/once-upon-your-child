import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:flutter/foundation.dart';

class GracePeriodAnalytics {
  GracePeriodAnalytics._();

  static FirebaseAnalytics get _analytics => FirebaseAnalytics.instance;

  static Future<void> bannerViewed({required int daysRemaining}) async {
    try {
      await _analytics.logEvent(
        name: 'grace_period_banner_viewed',
        parameters: {'days_remaining': daysRemaining},
      );
    } catch (e) {
      if (kDebugMode) {
        print('Analytics error (non-critical): $e');
      }
    }
  }

  static Future<void> softPromptShown({
    required int used,
    required int limit,
    required int accountAgeDays,
  }) async {
    try {
      await _analytics.logEvent(
        name: 'grace_period_soft_prompt_shown',
        parameters: {
          'used': used,
          'limit': limit,
          'account_age_days': accountAgeDays,
        },
      );
    } catch (e) {
      if (kDebugMode) {
        print('Analytics error (non-critical): $e');
      }
    }
  }

  static Future<void> hardLimitReached({
    required int used,
    required int limit,
    required int accountAgeDays,
  }) async {
    try {
      await _analytics.logEvent(
        name: 'grace_period_hard_limit_reached',
        parameters: {
          'used': used,
          'limit': limit,
          'account_age_days': accountAgeDays,
        },
      );
    } catch (e) {
      if (kDebugMode) {
        print('Analytics error (non-critical): $e');
      }
    }
  }

  static Future<void> upgradePromptClicked({required String promptType}) async {
    try {
      await _analytics.logEvent(
        name: 'upgrade_prompt_clicked',
        parameters: {'prompt_type': promptType},
      );
    } catch (e) {
      if (kDebugMode) {
        print('Analytics error (non-critical): $e');
      }
    }
  }
}
