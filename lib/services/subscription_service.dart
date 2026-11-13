import 'dart:async';

import '../models/subscription_status.dart';
import '../subscription_models.dart';
import 'subscription_sync_service.dart';
import 'user_identity_service.dart';
import 'stripe_service.dart';

class SubscriptionService {
  SubscriptionService({SubscriptionSyncService? syncService})
      : _syncService = syncService ?? SubscriptionSyncService();

  final SubscriptionSyncService _syncService;

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
