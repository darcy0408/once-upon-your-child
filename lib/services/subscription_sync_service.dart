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

  static final SubscriptionSyncService _instance =
      SubscriptionSyncService._internal();

  factory SubscriptionSyncService() => _instance;

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
  }

  void dispose() {
    _subscriptionController.close();
  }
}
