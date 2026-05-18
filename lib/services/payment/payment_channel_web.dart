// lib/services/payment/payment_channel_web.dart
//
// STORE-1 (MT-143): the WEB payment channel — Stripe Checkout.
//
// This is the default channel for any build that has `dart.library.html`
// available (the Flutter web build). It is a thin adapter over the existing,
// working `StripeService`: it does NOT change Stripe behaviour, it only
// re-shapes it to the `PaymentChannel` interface so the paywall UI is
// channel-agnostic.
//
// The store builds (iOS/Android) compile `payment_channel_io.dart` instead, so
// none of this Stripe code is reachable on mobile — that is the App Store /
// Play policy requirement.

import 'package:flutter/foundation.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../subscription_models.dart';
import '../stripe_service.dart';
import 'payment_channel_interface.dart';
import 'payment_models.dart';

/// Stripe-backed [PaymentChannel] for the web build.
class PaymentChannelWeb implements PaymentChannel {
  PaymentChannelWeb({StripeService? stripeService})
      : _stripeService = stripeService ?? StripeService();

  final StripeService _stripeService;

  @override
  PaymentChannelKind get kind => PaymentChannelKind.stripeWeb;

  @override
  bool get isStoreChannel => false;

  @override
  Future<void> initialize() async {
    // Stripe Checkout is created on demand server-side; no client-side store
    // connection to warm. Intentionally a no-op.
  }

  @override
  Future<List<PaymentProduct>> loadProducts() async {
    // Web prices are static marketing prices from TierPricing — Stripe is the
    // authority on what is actually charged (via the server-side Price ID).
    return TierPricing.allTiers
        .where((p) => p.tier != SubscriptionTier.free)
        .map(
          (p) => PaymentProduct(
            tier: p.tier,
            productId: p.tier.name,
            title: p.tier.displayName,
            priceLabel: '\$${p.monthlyPrice.toStringAsFixed(2)}/mo',
            description: p.features.isNotEmpty ? p.features.first : '',
          ),
        )
        .toList(growable: false);
  }

  @override
  Future<PurchaseResult> purchase({
    required SubscriptionTier tier,
    required String userId,
  }) async {
    if (tier == SubscriptionTier.free) {
      return PurchaseResult.error('Free tier is not purchasable.');
    }
    try {
      final session = await _stripeService.createCheckoutSession(
        tier: tier.name,
        userId: userId,
      );
      final checkoutUrl = session['checkout_url'] as String?;
      if (checkoutUrl == null || checkoutUrl.isEmpty) {
        return PurchaseResult.error('No checkout URL received from server.');
      }
      final checkoutUri = Uri.tryParse(checkoutUrl);
      if (checkoutUri == null) {
        return PurchaseResult.error('Invalid checkout URL.');
      }
      final launched = await launchUrl(
        checkoutUri,
        mode: LaunchMode.externalApplication,
      );
      if (!launched) {
        return PurchaseResult.error('Could not open the payment page.');
      }
      // Checkout opened in an external browser. The real entitlement lands
      // asynchronously via the Stripe webhook (backend/routes/webhook_handler.py),
      // so the caller should refresh subscription status, not assume success.
      return PurchaseResult.pending('Redirected to Stripe Checkout.');
    } catch (error) {
      debugPrint('Stripe checkout failed: $error');
      return PurchaseResult.error('Payment error: $error');
    }
  }

  @override
  Future<PurchaseResult> restorePurchases({required String userId}) async {
    // Web entitlement is account-bound and synced from the backend on every
    // launch (SubscriptionSyncService). There is nothing device-local to
    // restore, unlike StoreKit / Play Billing.
    return PurchaseResult.pending('Subscription status is synced automatically.');
  }

  @override
  void dispose() {
    // No listeners or store connection to release.
  }
}

/// Factory referenced by the conditional import in `payment_channel.dart`.
PaymentChannel createPlatformPaymentChannel() => PaymentChannelWeb();
