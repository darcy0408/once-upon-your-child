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

/// Compile-time marker: this build's payments go through a device store
/// (StoreKit / Play Billing). Surfaced through `payment_channel.dart` so UI
/// can adapt (e.g. hide billing options the store products don't cover)
/// without instantiating a channel.
const bool kStoreBillingPlatform = true;

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
    BillingPeriod billingPeriod = BillingPeriod.monthly,
  }) {
    // TODO(STORE-1 / owner): annual store products (`premium_annual`) don't
    // exist in App Store Connect / the Play Console yet, so billingPeriod is
    // accepted but ignored here — every IAP purchase is monthly for now.
    // App Store review sim 2026-07-17 Finding 2 (Guideline 3.1.2): the paywall
    // hides the Yearly toggle on store builds (kStoreBillingPlatform) so the
    // UI can no longer sell "Yearly (Save 50%)" against this monthly charge.
    // When premium_annual exists, honor billingPeriod here AND un-hide the
    // toggle.
    return _iap.purchase(
      tier: tier,
      userId: userId,
      billingPeriod: billingPeriod,
    );
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
