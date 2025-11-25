import 'package:firebase_analytics/firebase_analytics.dart';

class GracePeriodAnalytics {
  GracePeriodAnalytics._();

  static FirebaseAnalytics get _analytics => FirebaseAnalytics.instance;

  static Future<void> bannerViewed({required int daysRemaining}) async {
    await _analytics.logEvent(
      name: 'grace_period_banner_viewed',
      parameters: {'days_remaining': daysRemaining},
    );
  }

  static Future<void> softPromptShown({
    required int used,
    required int limit,
    required int accountAgeDays,
  }) async {
    await _analytics.logEvent(
      name: 'grace_period_soft_prompt_shown',
      parameters: {
        'used': used,
        'limit': limit,
        'account_age_days': accountAgeDays,
      },
    );
  }

  static Future<void> hardLimitReached({
    required int used,
    required int limit,
    required int accountAgeDays,
  }) async {
    await _analytics.logEvent(
      name: 'grace_period_hard_limit_reached',
      parameters: {
        'used': used,
        'limit': limit,
        'account_age_days': accountAgeDays,
      },
    );
  }

  static Future<void> upgradePromptClicked({required String promptType}) async {
    await _analytics.logEvent(
      name: 'upgrade_prompt_clicked',
      parameters: {'prompt_type': promptType},
    );
  }
}
