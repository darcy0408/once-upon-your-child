import 'dart:convert';

import 'package:http/http.dart' as http;

import '../config/flavor_config.dart';
import 'api_service_manager.dart';

/// Handles all Stripe-related API calls from the frontend.
class StripeService {
  StripeService({http.Client? httpClient})
      : _httpClient = httpClient ?? http.Client(),
        _baseUrl = FlavorConfig.instance.backendUrl;

  final http.Client _httpClient;
  final String _baseUrl;

  static const Duration _defaultTimeout = Duration(seconds: 20);

  Future<Map<String, String>> _buildAuthHeaders() =>
      ApiServiceManager.authHeaders();

  /// Create a Stripe Checkout session and return the response payload.
  Future<Map<String, dynamic>> createCheckoutSession({
    required String tier,
    String? userId,
  }) async {
    try {
      final response = await _httpClient
          .post(
            Uri.parse('$_baseUrl/api/stripe/create-checkout-session'),
            headers: await _buildAuthHeaders(),
            body: jsonEncode({
              'tier': tier,
              'user_id': userId,
            }),
          )
          .timeout(_defaultTimeout);

      if (response.statusCode == 200) {
        return _decodeBody(response.body);
      }

      throw Exception(
        'Failed to create checkout session: ${response.body}',
      );
    } catch (error) {
      throw Exception('Network error creating checkout session: $error');
    }
  }

  /// Fetch the subscription status for a specific user.
  Future<Map<String, dynamic>> getSubscriptionStatus(String userId) async {
    if (userId.startsWith('anon_')) {
      return {'status': 'inactive', 'tier': 'free'};
    }
    try {
      final response = await _httpClient
          .get(
            Uri.parse('$_baseUrl/api/stripe/subscription-status/$userId'),
            headers: await _buildAuthHeaders(),
          )
          .timeout(_defaultTimeout);

      if (response.statusCode == 200) {
        return _decodeBody(response.body);
      }

      if (response.statusCode == 404 || response.statusCode == 403) {
        // 404 = no subscription record; 403 = anonymous/guest user not yet
        // registered — both map to free tier rather than a hard error.
        return {'status': 'inactive', 'tier': 'free'};
      }

      throw Exception(
        'Failed to get subscription status: ${response.body}',
      );
    } catch (error) {
      throw Exception('Network error getting subscription status: $error');
    }
  }

  /// Create a Stripe Billing Portal session. Returns the portal URL string.
  Future<String> createPortalSession() async {
    try {
      final response = await _httpClient
          .post(
            Uri.parse('$_baseUrl/api/stripe/create-portal-session'),
            headers: await _buildAuthHeaders(),
            body: jsonEncode({}),
          )
          .timeout(_defaultTimeout);

      if (response.statusCode == 200) {
        final data = _decodeBody(response.body);
        final url = data['portal_url'] as String?;
        if (url != null && url.isNotEmpty) return url;
        throw Exception('Portal URL missing from response');
      }

      throw Exception('Failed to create portal session: ${response.body}');
    } catch (error) {
      throw Exception('Network error creating portal session: $error');
    }
  }

  /// Cancel a user's subscription (at period end). Returns true on success.
  Future<bool> cancelSubscription(String userId) async {
    try {
      final response = await _httpClient
          .post(
            Uri.parse('$_baseUrl/api/stripe/cancel-subscription'),
            headers: await _buildAuthHeaders(),
            body: jsonEncode({'user_id': userId}),
          )
          .timeout(_defaultTimeout);

      return response.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  /// Redeem a gift subscription code for the authenticated user.
  ///
  /// On success, returns the backend's resolved subscription payload
  /// (tier / subscription_status / current_period_end) — the same shape
  /// [getSubscriptionStatus] returns, so callers can feed it straight into
  /// [SubscriptionStatus.fromBackendPayload] if needed. Callers should still
  /// refresh via `SubscriptionSyncService` so every listener picks up the
  /// change.
  ///
  /// On failure throws a [GiftRedeemException] carrying a user-facing
  /// message (unknown code / already redeemed / rate-limited / network
  /// error) so the UI can show it directly.
  Future<Map<String, dynamic>> redeemGiftCode(String code) async {
    late final http.Response response;
    try {
      response = await _httpClient
          .post(
            Uri.parse('$_baseUrl/api/gift/redeem'),
            headers: await _buildAuthHeaders(),
            body: jsonEncode({'code': code}),
          )
          .timeout(_defaultTimeout);
    } catch (error) {
      throw GiftRedeemException('Network error redeeming gift code: $error');
    }

    final data = _decodeBody(response.body);

    if (response.statusCode == 200) {
      return data;
    }

    final message = (data['error'] as String?) ??
        'Could not redeem this code. Please try again.';
    throw GiftRedeemException(message);
  }

  Map<String, dynamic> _decodeBody(String body) {
    if (body.isEmpty) {
      return {};
    }
    return jsonDecode(body) as Map<String, dynamic>;
  }
}

/// Thrown by [StripeService.redeemGiftCode] on any failure. [message] is
/// already user-facing (sourced from the backend's `error` field, or a
/// generic fallback) — safe to show directly in a SnackBar/dialog.
class GiftRedeemException implements Exception {
  GiftRedeemException(this.message);

  final String message;

  @override
  String toString() => message;
}
