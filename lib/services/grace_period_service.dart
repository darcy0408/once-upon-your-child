// lib/services/grace_period_service.dart
// Manages the 3-day grace period for free tier users

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class GracePeriodService {
  static const String _accountCreatedKey = 'account_created_at';
  static const String _storiesThisMonthKey = 'stories_this_month';
  static const String _lastResetKey = 'last_story_reset';
  static const String _hasSeenGracePeriodEndKey = 'has_seen_grace_period_end';

  // Grace period configuration
  static const int gracePeriodDays = 3;
  static const int freeTierStoryLimit = 10; // 10 stories/month free tier
  static const int unlimitedLimit = 999; // Effectively unlimited

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

  /// Get story limit based on tier and grace period
  static Future<int> getStoryLimit(String tier) async {
    if (tier == 'premium' || tier == 'family') {
      return unlimitedLimit; // Unlimited for paid tiers
    }

    if (await isInGracePeriod()) {
      return unlimitedLimit; // Unlimited during grace period
    }

    return freeTierStoryLimit; // Free tier limit after grace period
  }

  /// Get stories used this month
  static Future<int> getStoriesUsedThisMonth() async {
    final prefs = await SharedPreferences.getInstance();

    // Check if we need to reset counter (new month)
    final lastReset = prefs.getString(_lastResetKey);
    final now = DateTime.now();

    if (lastReset == null) {
      await prefs.setString(_lastResetKey, now.toIso8601String());
      await prefs.setInt(_storiesThisMonthKey, 0);
      return 0;
    }

    final lastResetDate = DateTime.parse(lastReset);
    if (now.month != lastResetDate.month || now.year != lastResetDate.year) {
      // New month - reset counter
      await prefs.setString(_lastResetKey, now.toIso8601String());
      await prefs.setInt(_storiesThisMonthKey, 0);
      return 0;
    }

    return prefs.getInt(_storiesThisMonthKey) ?? 0;
  }

  /// Increment story count
  static Future<void> incrementStoryCount() async {
    final prefs = await SharedPreferences.getInstance();
    final current = await getStoriesUsedThisMonth();
    await prefs.setInt(_storiesThisMonthKey, current + 1);
  }

  /// Check if user can generate story and get detailed status
  static Future<GracePeriodStatus> getStatus(String tier) async {
    final limit = await getStoryLimit(tier);
    final used = await getStoriesUsedThisMonth();
    final isGrace = await isInGracePeriod();
    final accountAge = await getAccountAgeDays();
    final daysRemaining = await getDaysRemainingInGracePeriod();

    final canGenerate = used < limit;

    // Determine if we should show soft prompt (approaching limit in transition period)
    // Days 4-7: Show soft prompts when approaching 80% of limit
    final isTransitionPeriod = accountAge >= gracePeriodDays && accountAge <= 7;
    final isApproachingLimit = used >= (limit * 0.8);
    final shouldShowSoftPrompt = tier == 'free' && isTransitionPeriod && isApproachingLimit;

    // Hard limit reached
    final shouldShowHardLimit = tier == 'free' && !isGrace && used >= limit;

    return GracePeriodStatus(
      canGenerate: canGenerate,
      storiesUsed: used,
      storiesLimit: limit,
      isInGracePeriod: isGrace,
      daysRemainingInGracePeriod: daysRemaining,
      accountAgeDays: accountAge,
      shouldShowSoftPrompt: shouldShowSoftPrompt,
      shouldShowHardLimit: shouldShowHardLimit,
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
    await prefs.remove(_storiesThisMonthKey);
    await prefs.remove(_lastResetKey);
    await prefs.remove(_hasSeenGracePeriodEndKey);
  }
}

/// Status object returned by GracePeriodService
class GracePeriodStatus {
  final bool canGenerate;
  final int storiesUsed;
  final int storiesLimit;
  final bool isInGracePeriod;
  final int daysRemainingInGracePeriod;
  final int accountAgeDays;
  final bool shouldShowSoftPrompt;
  final bool shouldShowHardLimit;
  final String tier;

  GracePeriodStatus({
    required this.canGenerate,
    required this.storiesUsed,
    required this.storiesLimit,
    required this.isInGracePeriod,
    required this.daysRemainingInGracePeriod,
    required this.accountAgeDays,
    required this.shouldShowSoftPrompt,
    required this.shouldShowHardLimit,
    required this.tier,
  });

  /// Get percentage of stories used
  double get usagePercentage => (storiesUsed / storiesLimit).clamp(0.0, 1.0);

  /// Get usage description for UI
  String get usageDescription {
    if (isInGracePeriod) {
      return 'Unlimited stories for $daysRemainingInGracePeriod more ${daysRemainingInGracePeriod == 1 ? "day" : "days"}!';
    } else if (tier == 'free') {
      return '$storiesUsed / $storiesLimit stories this month';
    } else {
      return 'Unlimited stories';
    }
  }

  /// Get color for usage indicator
  Color get usageColor {
    if (isInGracePeriod) return Colors.green;
    if (usagePercentage >= 1.0) return Colors.red;
    if (usagePercentage >= 0.8) return Colors.orange;
    return Colors.blue;
  }

  @override
  String toString() {
    return 'GracePeriodStatus(canGenerate: $canGenerate, used: $storiesUsed/$storiesLimit, '
        'gracePeriod: $isInGracePeriod, accountAge: $accountAgeDays days, tier: $tier)';
  }
}
