// lib/services/payment/iap_verification_service.dart
//
// STORE-1 (MT-143): the client half of server-side receipt verification.
//
// NEVER trust the client's claim of a purchase — the backend must validate the
// receipt with Apple/Google. This service only RELAYS the platform receipt /
// purchase token to the backend, which does the real validation and resolves
// the tier (see backend/routes/iap_routes.py).
//
// Mobile-only: reached exclusively via `iap_service.dart`.

import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:in_app_purchase/in_app_purchase.dart';

import '../../config/flavor_config.dart';
import '../../subscription_models.dart';
import '../api_service_manager.dart';
import 'payment_models.dart';

/// Sends store receipts to the backend verification endpoints.
class IapVerificationService {
  IapVerificationService({http.Client? httpClient})
      : _httpClient = httpClient ?? http.Client(),
        _baseUrl = FlavorConfig.instance.backendUrl;

  final http.Client _httpClient;
  final String _baseUrl;

  static const Duration _timeout = Duration(seconds: 25);

  /// Verify [purchase] with the backend for [platform].
  ///
  /// Posts to `/api/iap/apple/verify` or `/api/iap/google/verify`. On a 200 the
  /// backend has validated the receipt with the store and applied the tier;
  /// the response carries the resolved tier so the UI can update immediately
  /// (the authoritative copy still arrives via SubscriptionSyncService).
  Future<PurchaseResult> verify({
    required String userId,
    required PurchaseDetails purchase,
    required PaymentChannelKind platform,
  }) async {
    final endpoint = switch (platform) {
      PaymentChannelKind.appleIap => '/api/iap/apple/verify',
      PaymentChannelKind.googleIap => '/api/iap/google/verify',
      PaymentChannelKind.stripeWeb =>
        throw ArgumentError('Stripe is not verified through the IAP path.'),
    };

    // `serverVerificationData` is the StoreKit receipt (base64) on iOS and the
    // purchase token on Android. The backend re-derives everything else from
    // it via the store APIs — we only need product ID + user binding here.
    final body = <String, dynamic>{
      'user_id': userId,
      'product_id': purchase.productID,
      'verification_data': purchase.verificationData.serverVerificationData,
      'source': purchase.verificationData.source,
      // Android needs the package name + token split out for the Play
      // Developer API; iOS ignores these. The backend tolerates nulls.
      'purchase_id': purchase.purchaseID,
      'transaction_date': purchase.transactionDate,
    };

    try {
      final response = await _httpClient
          .post(
            Uri.parse('$_baseUrl$endpoint'),
            headers: await ApiServiceManager.authHeaders(),
            body: jsonEncode(body),
          )
          .timeout(_timeout);

      if (response.statusCode == 200) {
        final data = _decode(response.body);
        final tierName = data['tier'] as String?;
        final tier = SubscriptionTier.values.firstWhere(
          (t) => t.name == tierName,
          orElse: () => SubscriptionTier.premium,
        );
        return PurchaseResult.success(tier);
      }

      // 400/409 = receipt rejected by the store; 402 = not entitled.
      final detail = _safeError(response.body);
      return PurchaseResult.error(
        'Purchase verification failed (${response.statusCode}): $detail',
      );
    } catch (error) {
      return PurchaseResult.error('Network error verifying purchase: $error');
    }
  }

  Map<String, dynamic> _decode(String body) {
    if (body.isEmpty) return <String, dynamic>{};
    final decoded = jsonDecode(body);
    return decoded is Map<String, dynamic> ? decoded : <String, dynamic>{};
  }

  String _safeError(String body) {
    try {
      final data = _decode(body);
      return (data['error'] as String?) ?? body;
    } catch (_) {
      return body;
    }
  }
}
