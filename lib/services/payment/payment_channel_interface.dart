// lib/services/payment/payment_channel_interface.dart
//
// STORE-1 (MT-143): the single payment abstraction the paywall UI talks to.
//
// One backend remains the authority on a user's tier. The frontend simply
// needs to (a) present the purchasable products and (b) start a purchase. How
// that purchase is fulfilled differs per build:
//
//   - Web build      -> Stripe Checkout (PaymentChannelWeb wrapping StripeService)
//   - iOS/Android    -> StoreKit / Play Billing (PaymentChannelIap wrapping IapService)
//
// The concrete class is selected at compile time by the conditional import in
// `payment_channel.dart`, so the `in_app_purchase` plugin is never linked into
// the web build and the Stripe checkout code is never reachable on mobile.

import '../../subscription_models.dart';
import 'payment_models.dart';

/// Platform-agnostic contract for selling subscriptions.
///
/// Implementations MUST NOT be trusted as the source of truth for entitlement:
/// every channel verifies the purchase server-side and the backend resolves the
/// tier. A [PurchaseResult] is a UI hint, not an authorisation.
abstract interface class PaymentChannel {
  /// Which billing channel this build is running.
  PaymentChannelKind get kind;

  /// True when this channel uses an in-app store (Apple/Google) rather than
  /// an external browser checkout. Drives UI copy ("Restore purchases" is only
  /// shown for store channels; the Stripe billing-portal link only for web).
  bool get isStoreChannel;

  /// One-time async setup: connect to the store, warm caches, attach the
  /// purchase-update listener. Safe to call more than once.
  Future<void> initialize();

  /// The products the user can buy, in display order. For the Stripe channel
  /// these are derived from [TierPricing]; for IAP they are queried live from
  /// the store so prices/currency are correct per region.
  Future<List<PaymentProduct>> loadProducts();

  /// Start a purchase for [tier].
  ///
  /// - Stripe web: launches Checkout in an external browser and returns
  ///   [PurchaseOutcome.pending] — entitlement arrives via the Stripe webhook.
  /// - IAP: drives the StoreKit / Play Billing sheet, then sends the receipt /
  ///   purchase token to the backend for verification before returning.
  ///
  /// [userId] is the authenticated Story Weaver user. The purchase is tied to
  /// this account server-side so the webhook / receipt-verify endpoint can
  /// resolve which user to entitle.
  Future<PurchaseResult> purchase({
    required SubscriptionTier tier,
    required String userId,
  });

  /// Re-apply any entitlement the user already owns on this device/account.
  ///
  /// Apple REQUIRES a visible "Restore purchases" action. For the Stripe web
  /// channel this is a no-op ([PurchaseOutcome.pending]) — web entitlement is
  /// already account-bound and synced from the backend on every launch.
  Future<PurchaseResult> restorePurchases({required String userId});

  /// Release listeners / store connections. Call on app teardown.
  void dispose();
}
