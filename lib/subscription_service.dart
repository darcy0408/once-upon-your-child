// lib/subscription_service.dart

import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'subscription_models.dart';

class SubscriptionService {
  static const String _kSubscriptionKey = 'user_subscription';
  static const String _kUsageStatsKey = 'usage_stats';

  /// Get current user subscription
  Future<UserSubscription> getSubscription() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_kSubscriptionKey);

    if (raw != null && raw.isNotEmpty) {
      try {
        final json = jsonDecode(raw) as Map<String, dynamic>;
        return UserSubscription.fromJson(json);
      } catch (e) {
        return UserSubscription();
      }
    }

    return UserSubscription();
  }

  /// Update user subscription
  Future<void> setSubscription(UserSubscription subscription) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = jsonEncode(subscription.toJson());
    await prefs.setString(_kSubscriptionKey, raw);
  }

  /// Upgrade to a paid tier
  Future<void> upgradeToPremium(SubscriptionTier tier) async {
    final subscription = UserSubscription(
      tier: tier,
      subscriptionStartDate: DateTime.now(),
      subscriptionEndDate: DateTime.now().add(const Duration(days: 365)),
      isActive: true,
      subscriptionId: 'sub_${DateTime.now().millisecondsSinceEpoch}',
    );
    await setSubscription(subscription);
  }

  /// Downgrade to free tier
  Future<void> downgradeToFree() async {
    await setSubscription(UserSubscription());
  }

  /// Get usage stats
  Future<UsageStats> getUsageStats() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_kUsageStatsKey);

    UsageStats stats;
    if (raw != null && raw.isNotEmpty) {
      try {
        final json = jsonDecode(raw) as Map<String, dynamic>;
        stats = UsageStats.fromJson(json);
      } catch (e) {
        stats = UsageStats();
      }
    } else {
      stats = UsageStats();
    }

    // Auto-reset if needed
    if (stats.needsMonthlyReset()) {
      stats = stats.resetMonthly();
      await _saveUsageStats(stats);
    } else if (stats.needsDailyReset()) {
      stats = stats.resetDaily();
      await _saveUsageStats(stats);
    }

    return stats;
  }

  /// Save usage stats
  Future<void> _saveUsageStats(UsageStats stats) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = jsonEncode(stats.toJson());
    await prefs.setString(_kUsageStatsKey, raw);
  }

  /// Record a story creation
  Future<void> recordStoryCreation() async {
    final stats = await getUsageStats();
    final updated = stats.incrementStory();
    await _saveUsageStats(updated);
  }

  /// Check if user can create a story
  Future<bool> canCreateStory() async {
    final subscription = await getSubscription();
    final limits = subscription.limits;

    // Unlimited stories for family tier
    if (limits.unlimitedStories) {
      return true;
    }

    final stats = await getUsageStats();

    // Check daily limit
    if (limits.maxStoriesPerDay > 0 &&
        stats.storiesCreatedToday >= limits.maxStoriesPerDay) {
      return false;
    }

    // Check monthly limit
    if (limits.maxStoriesPerMonth > 0 &&
        stats.storiesCreatedThisMonth >= limits.maxStoriesPerMonth) {
      return false;
    }

    return true;
  }

  /// Get remaining stories for today
  Future<int> getRemainingStoriesToday() async {
    final subscription = await getSubscription();
    final limits = subscription.limits;

    if (limits.unlimitedStories) {
      return -1; // -1 means unlimited
    }

    final stats = await getUsageStats();
    final remaining = limits.maxStoriesPerDay - stats.storiesCreatedToday;
    return remaining > 0 ? remaining : 0;
  }

  /// Get remaining stories for this month
  Future<int> getRemainingStoriesThisMonth() async {
    final subscription = await getSubscription();
    final limits = subscription.limits;

    if (limits.unlimitedStories) {
      return -1; // -1 means unlimited
    }

    final stats = await getUsageStats();
    final remaining = limits.maxStoriesPerMonth - stats.storiesCreatedThisMonth;
    return remaining > 0 ? remaining : 0;
  }

  /// Check if a feature is available for current tier
  Future<bool> hasFeature(String featureName) async {
    final subscription = await getSubscription();
    final limits = subscription.limits;

    switch (featureName) {
      case 'multi_character_stories':
        return limits.multiCharacterStories;
      case 'export_stories':
        return limits.exportStories;
      case 'ad_free':
        return limits.adFree;
      case 'priority_support':
        return limits.prioritySupport;
      case 'early_access':
        return limits.earlyAccess;
      default:
        return false;
    }
  }

  /// Check if theme is available
  Future<bool> isThemeAvailable(String theme) async {
    final subscription = await getSubscription();
    final limits = subscription.limits;
    return limits.availableThemes.contains(theme);
  }

  /// Check if companion is available
  Future<bool> isCompanionAvailable(String companion) async {
    // All companions are free for now
    return true;
  }

  /// Check if user can create more characters
  Future<bool> canCreateCharacter(int currentCharacterCount) async {
    final subscription = await getSubscription();
    final limits = subscription.limits;
    return currentCharacterCount < limits.maxCharacters;
  }

  /// Get max characters allowed
  Future<int> getMaxCharacters() async {
    final subscription = await getSubscription();
    return subscription.limits.maxCharacters;
  }

  /// Reset usage stats (for testing)
  Future<void> resetUsageStats() async {
    await _saveUsageStats(UsageStats());
  }

  /// Activate Isabela tester profile with all features unlocked
  Future<void> activateIsabelaTester() async {
    final testerSubscription = UserSubscription(
      tier: SubscriptionTier.family,
      subscriptionStartDate: DateTime.now(),
      subscriptionEndDate:
          DateTime.now().add(const Duration(days: 36500)), // 100 years
      isActive: true,
      subscriptionId: 'isabela_tester_profile',
    );

    await setSubscription(testerSubscription);
    await resetUsageStats();

    print('Isabela tester profile activated with all features!');
  }
}
