import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

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
  static const String _tokenKey = 'story_weaver_auth_token';

  Future<Map<String, String>> _buildAuthHeaders() async {
    // Ensure anonymous auth token exists via ApiServiceManager.
    await ApiServiceManager().getUserId();
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString(_tokenKey);
    return {
      'Content-Type': 'application/json',
      if (token != null && token.isNotEmpty) 'Authorization': 'Bearer $token',
    };
  }

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

      if (response.statusCode == 404) {
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

  Map<String, dynamic> _decodeBody(String body) {
    if (body.isEmpty) {
      return {};
    }
    return jsonDecode(body) as Map<String, dynamic>;
  }
}
