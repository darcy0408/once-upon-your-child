import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../config/flavor_config.dart';

/// Handles all Stripe-related API calls from the frontend.
class StripeService {
  StripeService({http.Client? httpClient})
      : _httpClient = httpClient ?? http.Client(),
        _baseUrl = FlavorConfig.instance.backendUrl;

  final http.Client _httpClient;
  final String _baseUrl;

  static const Map<String, String> _jsonHeaders = {
    'Content-Type': 'application/json',
  };
  static const Duration _defaultTimeout = Duration(seconds: 20);

  /// Create a Stripe Checkout session and return the response payload.
  Future<Map<String, dynamic>> createCheckoutSession({
    required String tier,
    String? userId,
  }) async {
    try {
      final response = await _httpClient
          .post(
            Uri.parse('$_baseUrl/api/stripe/create-checkout-session'),
            headers: _jsonHeaders,
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
    try {
      final response = await _httpClient
          .get(
            Uri.parse('$_baseUrl/api/stripe/subscription-status/$userId'),
            headers: _jsonHeaders,
          )
          .timeout(_defaultTimeout);

      if (response.statusCode == 200) {
        return _decodeBody(response.body);
      }

      if (response.statusCode == 404) {
        return {'status': 'inactive', 'tier': 'free'};
      }

      debugPrint(
        'Stripe status fetch failed (${response.statusCode}): ${response.body}',
      );
      return {'status': 'inactive', 'tier': 'free'};
    } catch (error) {
      debugPrint('Network error getting subscription status: $error');
      // Fallback to free tier so the UI can still render.
      return {'status': 'inactive', 'tier': 'free'};
    }
  }

  /// Cancel a user's subscription (at period end). Returns true on success.
  Future<bool> cancelSubscription(String userId) async {
    try {
      final response = await _httpClient
          .post(
            Uri.parse('$_baseUrl/api/stripe/cancel-subscription'),
            headers: _jsonHeaders,
            body: jsonEncode({'user_id': userId}),
          )
          .timeout(_defaultTimeout);

      return response.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  Map<String, dynamic> _decodeBody(String body) {
    if (body.isEmpty) {
      return {};
    }
    return jsonDecode(body) as Map<String, dynamic>;
  }
}
