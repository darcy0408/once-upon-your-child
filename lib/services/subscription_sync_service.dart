import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/subscription_status.dart';
import 'user_identity_service.dart';
import 'stripe_service.dart';

class SubscriptionSyncService {
  SubscriptionSyncService._internal({StripeService? stripeService})
      : _stripeService = stripeService ?? StripeService();

  static SubscriptionSyncService? _instance;

  factory SubscriptionSyncService() => _instance ??= SubscriptionSyncService._internal();

  @visibleForTesting
  SubscriptionSyncService.forTest({StripeService? stripeService})
      : _stripeService = stripeService ?? StripeService();

  @visibleForTesting
  static void resetInstance([SubscriptionSyncService? mock]) {
    _instance = mock;
  }

  final StripeService _stripeService;
  final StreamController<SubscriptionStatus> _subscriptionController =
      StreamController<SubscriptionStatus>.broadcast();
  SubscriptionStatus? _currentStatus;
  bool _cacheHydrated = false;

  static const String _cacheKey = 'subscription_status';
  static const List<Duration> _retrySchedule = [
    Duration(seconds: 1),
    Duration(seconds: 2),
    Duration(seconds: 4),
  ];

  Stream<SubscriptionStatus> get subscriptionStream =>
      _subscriptionController.stream;
  SubscriptionStatus? get currentStatus => _currentStatus;

  Future<void> initialize({String? userId}) async {
    if (!_cacheHydrated) {
      await _hydrateFromCache();
      _cacheHydrated = true;
    }
    await syncSubscriptionStatus(userId: userId);
  }

  Future<void> syncSubscriptionStatus({String? userId}) async {
    final resolvedUserId =
        userId ?? await UserIdentityService.getOrCreateUserId();

    // Anonymous users (prefixed 'anon_') have no Stripe record — skip the
    // network call and emit free tier immediately to avoid 403 console noise.
    if (resolvedUserId.startsWith('anon_')) {
      _emit(SubscriptionStatus(
        userId: resolvedUserId,
        tier: SubscriptionTier.free,
        status: 'inactive',
        cancelAtPeriodEnd: false,
      ));
      return;
    }

    try {
      final status = await _fetchWithRetry(resolvedUserId);
      await _cacheSubscriptionStatus(status);
      _emit(status);
    } catch (error, stackTrace) {
      debugPrint('Subscription sync failed: $error');
      debugPrint('$stackTrace');

      final cached = await _getCachedSubscriptionStatus();
      if (cached != null) {
        _emit(cached);
      }
    }
  }

  Future<SubscriptionStatus> _fetchWithRetry(String userId) async {
    Object? lastError;
    for (var attempt = 0; attempt < _retrySchedule.length; attempt++) {
      try {
        return await _fetchFromBackend(userId);
      } catch (error) {
        lastError = error;
        if (attempt == _retrySchedule.length - 1) {
          break;
        }
        await Future.delayed(_retrySchedule[attempt]);
      }
    }
    if (lastError is Exception) {
      throw lastError;
    }
    throw Exception('Subscription fetch failed');
  }

  Future<SubscriptionStatus> _fetchFromBackend(String userId) async {
    final data = await _stripeService.getSubscriptionStatus(userId);
    return SubscriptionStatus.fromBackendPayload(userId, data);
  }

  Future<void> _hydrateFromCache() async {
    final cached = await _getCachedSubscriptionStatus();
    if (cached != null) {
      _emit(cached);
    }
  }

  Future<void> _cacheSubscriptionStatus(SubscriptionStatus status) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_cacheKey, json.encode(status.toJson()));
  }

  Future<SubscriptionStatus?> _getCachedSubscriptionStatus() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_cacheKey);
    if (raw == null || raw.isEmpty) {
      return null;
    }
    try {
      final data = json.decode(raw) as Map<String, dynamic>;
      return SubscriptionStatus.fromJson(data);
    } catch (_) {
      return null;
    }
  }

  void _emit(SubscriptionStatus status) {
    _currentStatus = status;
    _subscriptionController.add(status);
    // Mirror the tier/status into the legacy `is_paid_premium` SharedPref bool
    // so the two readers (`ApiServiceManager.hasPremiumAccess`,
    // `ProgressionService.hasPaidPremium`) reflect the real subscription state.
    // Truthy when tier is paid AND status is in any "has access" state:
    //   active    → fully paid
    //   trialing  → 14-day free trial (Premium features active)
    //   past_due  → Stripe dunning window (~3 weeks of retries; keep access)
    // Anything else (canceled, incomplete_expired, etc.) → false.
    unawaited(_writePaidPremiumPref(status));
  }

  static Future<void> _writePaidPremiumPref(SubscriptionStatus status) async {
    try {
      final isPaid = status.tier != SubscriptionTier.free &&
          (status.status == 'active' ||
              status.status == 'trialing' ||
              status.status == 'past_due');
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('is_paid_premium', isPaid);
    } catch (_) {
      // Pref write failures are non-fatal — readers fall back to false.
    }
  }

  void dispose() {
    _subscriptionController.close();
  }
}
