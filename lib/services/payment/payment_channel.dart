// lib/services/payment/payment_channel.dart
//
// STORE-1 (MT-143): platform-dispatched entry point for the payment channel.
//
// This mirrors the project's existing conditional-import split (see
// `lib/services/isar_service.dart`). The web build gets `PaymentChannelWeb`
// (Stripe); every non-web build (iOS/Android — `dart.library.io`) gets
// `PaymentChannelIap` (StoreKit / Play Billing).
//
// Because the selection happens at COMPILE time:
//   - the `in_app_purchase` plugin is never linked into the web bundle;
//   - the Stripe `url_launcher` checkout path is never reachable on mobile,
//     satisfying the brief's "Stripe path must be compiled out on mobile".
//
// Callers should obtain the channel only through [createPaymentChannel].

export 'payment_channel_interface.dart';
export 'payment_models.dart';

import 'payment_channel_interface.dart';
import 'payment_channel_web.dart'
    if (dart.library.io) 'payment_channel_io.dart';

/// Build the [PaymentChannel] appropriate for the current platform.
///
/// Web  -> Stripe Checkout.
/// iOS/Android -> in-app purchase (StoreKit / Play Billing).
PaymentChannel createPaymentChannel() => createPlatformPaymentChannel();

/// True when this build sells through a device store (StoreKit / Play
/// Billing) rather than Stripe. Compile-time constant from the platform
/// split above — lets UI adapt (e.g. hide the annual toggle while the
/// stores only have monthly products) without instantiating a channel.
const bool isStoreBillingPlatform = kStoreBillingPlatform;
