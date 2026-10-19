// lib/services/grace_period_service.dart
// Manages the 3-day grace period for free tier users

import 'package:shared_preferences/shared_preferences.dart';

class GracePeriodService {
  static const String _accountCreatedKey = 'account_created_at';
  static const String _hasSeenGracePeriodEndKey = 'has_seen_grace_period_end';

  // Grace period configuration
  static const int gracePeriodDays = 3;

  /// Get user's account age in days
  static Future<int> getAccountAgeDays() async {
    final prefs = await SharedPreferences.getInstance();
    final createdAt = prefs.getString(_accountCreatedKey);

    if (createdAt == null) {
      // First time setup
      final now = DateTime.now().toIso8601String();
      await prefs.setString(_accountCreatedKey, now);
      return 0;
    }

    final created = DateTime.parse(createdAt);
    final now = DateTime.now();
    return now.difference(created).inDays;
  }

  /// Check if user is currently in grace period (first 3 days)
  static Future<bool> isInGracePeriod() async {
    final age = await getAccountAgeDays();
    return age < gracePeriodDays;
  }

  /// Get days remaining in grace period (0 if grace period ended)
  static Future<int> getDaysRemainingInGracePeriod() async {
    final age = await getAccountAgeDays();
    final remaining = gracePeriodDays - age;
    return remaining > 0 ? remaining : 0;
  }

  /// Grace period status for [tier]. Story counts are not tracked here: the
  /// backend owns them (see UsageStatsService).
  static Future<GracePeriodStatus> getStatus(String tier) async {
    final isGrace = await isInGracePeriod();
    final accountAge = await getAccountAgeDays();
    final daysRemaining = await getDaysRemainingInGracePeriod();

    return GracePeriodStatus(
      isInGracePeriod: isGrace,
      daysRemainingInGracePeriod: daysRemaining,
      accountAgeDays: accountAge,
      tier: tier,
    );
  }

  /// Mark that user has seen grace period end notification
  static Future<void> markGracePeriodEndSeen() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_hasSeenGracePeriodEndKey, true);
  }

  /// Check if user has seen grace period end notification
  static Future<bool> hasSeenGracePeriodEnd() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_hasSeenGracePeriodEndKey) ?? false;
  }

  /// Reset grace period (for testing or admin purposes)
  static Future<void> resetGracePeriod() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_accountCreatedKey);
    await prefs.remove(_hasSeenGracePeriodEndKey);
  }
}

/// Status object returned by GracePeriodService
class GracePeriodStatus {
  final bool isInGracePeriod;
  final int daysRemainingInGracePeriod;
  final int accountAgeDays;
  final String tier;

  GracePeriodStatus({
    required this.isInGracePeriod,
    required this.daysRemainingInGracePeriod,
    required this.accountAgeDays,
    required this.tier,
  });

  /// Get usage description for UI
  String get usageDescription {
    if (isInGracePeriod) {
      return 'Unlimited stories for $daysRemainingInGracePeriod more ${daysRemainingInGracePeriod == 1 ? "day" : "days"}!';
    } else if (tier == 'free') {
      return 'Free plan';
    } else {
      return 'Unlimited stories';
    }
  }

  @override
  String toString() {
    return 'GracePeriodStatus(gracePeriod: $isInGracePeriod, '
        'accountAge: $accountAgeDays days, tier: $tier)';
  }
}
