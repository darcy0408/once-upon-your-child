// lib/services/payment/payment_channel_io.dart
//
// STORE-1 (MT-143): the MOBILE payment channel — StoreKit / Play Billing.
//
// Selected by the conditional import in `payment_channel.dart` for any build
// with `dart.library.io` (iOS and Android). The web build compiles
// `payment_channel_web.dart` instead, so nothing here — including the
// `in_app_purchase` plugin — is linked into the web bundle.
//
// This is a thin adapter over `IapService`; it exists so the paywall UI talks
// only to the `PaymentChannel` interface and never imports a store plugin.

import '../../subscription_models.dart';
import 'iap_service.dart';
import 'payment_channel_interface.dart';
import 'payment_models.dart';

/// In-app-purchase-backed [PaymentChannel] for the iOS/Android store builds.
class PaymentChannelIap implements PaymentChannel {
  PaymentChannelIap({IapService? iapService})
      : _iap = iapService ?? IapService();

  final IapService _iap;

  @override
  PaymentChannelKind get kind {
    // The store builds run on exactly one of the two IAP backends; reporting
    // appleIap as the generic "store" default is fine — the verification path
    // re-detects the concrete platform at receipt time.
    return PaymentChannelKind.appleIap;
  }

  @override
  bool get isStoreChannel => true;

  @override
  Future<void> initialize() => _iap.initialize();

  @override
  Future<List<PaymentProduct>> loadProducts() => _iap.loadProducts();

  @override
  Future<PurchaseResult> purchase({
    required SubscriptionTier tier,
    required String userId,
  }) {
    return _iap.purchase(tier: tier, userId: userId);
  }

  @override
  Future<PurchaseResult> restorePurchases({required String userId}) {
    return _iap.restorePurchases(userId: userId);
  }

  @override
  void dispose() => _iap.dispose();
}

/// Factory referenced by the conditional import in `payment_channel.dart`.
PaymentChannel createPlatformPaymentChannel() => PaymentChannelIap();
