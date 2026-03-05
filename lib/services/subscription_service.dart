import '../models/subscription_status.dart';
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

  void dispose() {
    _syncService.dispose();
  }
}
