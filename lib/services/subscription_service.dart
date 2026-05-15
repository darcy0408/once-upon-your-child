import 'dart:async';
import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/subscription_status.dart';
import '../subscription_models.dart';
import 'subscription_sync_service.dart';
import 'user_identity_service.dart';
import 'stripe_service.dart';

class SubscriptionService {
  SubscriptionService({SubscriptionSyncService? syncService})
      : _syncService = syncService ?? SubscriptionSyncService();

  final SubscriptionSyncService _syncService;

  // SharedPref key for the client-side usage counter. The legacy
  // `user_subscription` key is intentionally NOT read here — `SubscriptionSyncService`
  // already mirrors auth-of-record state into `is_paid_premium` + `subscription_status`.
  static const String _kUsageStatsKey = 'usage_stats';

  Stream<SubscriptionStatus> get statusStream =>
      _syncService.subscriptionStream;

  SubscriptionStatus? get currentStatus => _syncService.currentStatus;

  Future<void> initialize([String? userId]) async {
    final resolvedId =
        userId ?? await UserIdentityService.getOrCreateUserId();
    await _syncService.initialize(userId: resolvedId);
  }

  Future<void> refresh([String? userId]) async {
    final resolvedId =
        userId ?? await UserIdentityService.getOrCreateUserId();
    await _syncService.syncSubscriptionStatus(userId: resolvedId);
  }

  Future<Map<String, dynamic>> getSubscriptionStatus([String? userId]) async {
    final resolvedId = userId ?? await UserIdentityService.getOrCreateUserId();
    final stripeService = StripeService();
    return await stripeService.getSubscriptionStatus(resolvedId);
  }

  /// Returns the current subscription as a [UserSubscription] view.
  ///
  /// Derived entirely from the sync service's last-known status. If the sync
  /// service hasn't hydrated yet, callers see a free-tier default (no
  /// SharedPref fallback — the canonical source is the backend cache held by
  /// [SubscriptionSyncService]).
  Future<UserSubscription> getSubscription() async {
    final latest = _syncService.currentStatus;
    if (latest != null) {
      return latest.toUserSubscription();
    }
    return UserSubscription();
  }

  /// Whether the user can create another story right now.
  Future<bool> canCreateStory() async {
    final subscription = await getSubscription();
    final limits = subscription.limits;

    if (limits.unlimitedStories) {
      return true;
    }

    final stats = await _getUsageStats();

    if (limits.maxStoriesPerDay > 0 &&
        stats.storiesCreatedToday >= limits.maxStoriesPerDay) {
      return false;
    }

    if (limits.maxStoriesPerMonth > 0 &&
        stats.storiesCreatedThisMonth >= limits.maxStoriesPerMonth) {
      return false;
    }

    return true;
  }

  /// Remaining stories the user can create today. Returns -1 for unlimited.
  Future<int> getRemainingStoriesToday() async {
    final subscription = await getSubscription();
    final limits = subscription.limits;

    if (limits.unlimitedStories) {
      return -1;
    }

    final stats = await _getUsageStats();
    final remaining = limits.maxStoriesPerDay - stats.storiesCreatedToday;
    return remaining > 0 ? remaining : 0;
  }

  /// Records a story creation, incrementing the client-side usage counter.
  Future<void> recordStoryCreation() async {
    final stats = await _getUsageStats();
    final updated = stats.incrementStory();
    await _saveUsageStats(updated);
  }

  /// Whether the user can create another character given their current count.
  Future<bool> canCreateCharacter(int currentCharacterCount) async {
    final subscription = await getSubscription();
    return currentCharacterCount < subscription.limits.maxCharacters;
  }

  /// Max characters allowed for the current tier.
  Future<int> getMaxCharacters() async {
    final subscription = await getSubscription();
    return subscription.limits.maxCharacters;
  }

  Future<UsageStats> _getUsageStats() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_kUsageStatsKey);

    UsageStats stats;
    if (raw != null && raw.isNotEmpty) {
      try {
        final json = jsonDecode(raw) as Map<String, dynamic>;
        stats = UsageStats.fromJson(json);
      } catch (_) {
        stats = UsageStats();
      }
    } else {
      stats = UsageStats();
    }

    // Auto-reset if the calendar has rolled over since last write.
    if (stats.needsMonthlyReset()) {
      stats = stats.resetMonthly();
      await _saveUsageStats(stats);
    } else if (stats.needsDailyReset()) {
      stats = stats.resetDaily();
      await _saveUsageStats(stats);
    }

    return stats;
  }

  Future<void> _saveUsageStats(UsageStats stats) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = jsonEncode(stats.toJson());
    await prefs.setString(_kUsageStatsKey, raw);
  }

  void dispose() {
    _syncService.dispose();
  }
}

extension SubscriptionStatusMapper on SubscriptionStatus {
  UserSubscription toUserSubscription() {
    return UserSubscription(
      tier: tier,
      subscriptionStartDate: DateTime.now(),
      subscriptionEndDate: currentPeriodEnd,
      isActive: isActive,
      subscriptionId: userId,
    );
  }
}
