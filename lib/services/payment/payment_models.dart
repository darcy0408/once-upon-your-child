// lib/services/payment/payment_models.dart
//
// STORE-1 (MT-143): shared, platform-agnostic value types for the dual-channel
// payment abstraction. Nothing here imands `stripe` or `in_app_purchase`, so
// this file is safe to import from both the web and the mobile implementation.

import '../../subscription_models.dart';

/// Which billing channel a build uses to sell subscriptions.
///
/// The web build is not distributed through an app store, so it keeps Stripe.
/// The iOS/Android store builds MUST use StoreKit / Play Billing — Apple
/// Guideline 3.1.1 and Google Play's Payments policy both reject a Stripe
/// web-checkout flow for digital goods.
enum PaymentChannelKind {
  /// Stripe Checkout, opened in an external browser. Web build only.
  stripeWeb,

  /// Apple StoreKit in-app purchase. iOS store build.
  appleIap,

  /// Google Play Billing in-app purchase. Android store build.
  googleIap,
}

/// Outcome of a [PaymentChannel.purchase] call.
enum PurchaseOutcome {
  /// The purchase completed and the receipt was accepted by the backend. For
  /// the Stripe web channel this instead means checkout was *launched* — the
  /// real entitlement arrives asynchronously via the Stripe webhook, so the
  /// caller should refresh subscription status rather than assume success.
  success,

  /// Checkout was launched in an external surface (browser / store sheet) and
  /// the result will arrive out-of-band. Used by the Stripe web channel.
  pending,

  /// The user dismissed the store / checkout sheet without paying.
  cancelled,

  /// The purchase failed (network, store error, declined card, etc.).
  error,
}

/// Result of attempting a purchase through a [PaymentChannel].
class PurchaseResult {
  const PurchaseResult({
    required this.outcome,
    this.tier,
    this.message,
  });

  final PurchaseOutcome outcome;

  /// The tier the user ended up entitled to, when known synchronously.
  /// Often null for [PurchaseOutcome.pending] (entitlement is resolved
  /// server-side from the webhook / S2S notification).
  final SubscriptionTier? tier;

  /// Human-readable detail for error / diagnostics surfaces.
  final String? message;

  bool get isSuccess => outcome == PurchaseOutcome.success;
  bool get isCancelled => outcome == PurchaseOutcome.cancelled;
  bool get isError => outcome == PurchaseOutcome.error;

  factory PurchaseResult.success(SubscriptionTier tier) =>
      PurchaseResult(outcome: PurchaseOutcome.success, tier: tier);

  factory PurchaseResult.pending([String? message]) =>
      PurchaseResult(outcome: PurchaseOutcome.pending, message: message);

  factory PurchaseResult.cancelled() =>
      const PurchaseResult(outcome: PurchaseOutcome.cancelled);

  factory PurchaseResult.error(String message) =>
      PurchaseResult(outcome: PurchaseOutcome.error, message: message);
}

/// A purchasable subscription product as presented to the user.
///
/// For the Stripe channel the price strings come from [TierPricing]; for the
/// IAP channels they come from the store (StoreKit / Play Billing localise the
/// price and currency, so [priceLabel] is whatever the store returns).
class PaymentProduct {
  const PaymentProduct({
    required this.tier,
    required this.productId,
    required this.title,
    required this.priceLabel,
    this.description = '',
  });

  /// The Story Weaver tier this product grants.
  final SubscriptionTier tier;

  /// The channel-specific product identifier.
  ///
  /// - Stripe: the tier name (`premium` / `family`) — the backend maps it to a
  ///   Stripe Price ID.
  /// - IAP: the store product ID. The brief standardises these as
  ///   `premium_monthly` / `family_monthly` (see [iapProductIdForTier]).
  final String productId;

  /// Display title, e.g. "Premium".
  final String title;

  /// Localised, store-formatted price, e.g. "$4.99" or "£4.49".
  final String priceLabel;

  /// Optional marketing description.
  final String description;
}

/// Canonical store product IDs, per the STORE-1 brief. These MUST match the
/// product IDs created in App Store Connect and the Google Play Console.
///
/// TODO(STORE-1 / owner): create these exact product IDs in BOTH consoles
/// before the IAP path can be tested against the sandbox / test track.
const String kIapProductPremiumMonthly = 'premium_monthly';
const String kIapProductFamilyMonthly = 'family_monthly';

/// Map a [SubscriptionTier] to its store product ID. Returns null for tiers
/// that are not sold as an in-app product (e.g. [SubscriptionTier.free]).
String? iapProductIdForTier(SubscriptionTier tier) {
  switch (tier) {
    case SubscriptionTier.premium:
      return kIapProductPremiumMonthly;
    case SubscriptionTier.family:
      return kIapProductFamilyMonthly;
    case SubscriptionTier.free:
      return null;
  }
}

/// Inverse of [iapProductIdForTier].
SubscriptionTier? tierForIapProductId(String productId) {
  switch (productId) {
    case kIapProductPremiumMonthly:
      return SubscriptionTier.premium;
    case kIapProductFamilyMonthly:
      return SubscriptionTier.family;
    default:
      return null;
  }
}
