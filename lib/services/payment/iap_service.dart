// lib/services/payment/iap_service.dart
//
// STORE-1 (MT-143): the mobile in-app-purchase engine — StoreKit (iOS) and
// Google Play Billing (Android), via the official `in_app_purchase` plugin.
//
// This file is ONLY compiled into the iOS/Android store builds — it is reached
// exclusively through `payment_channel_io.dart`, which the web build never
// imports. So the `in_app_purchase` dependency is never linked on web.
//
// Trust model: a purchase reported by the plugin is NEVER trusted on its own.
// On every `purchased` / `restored` event we ship the platform receipt /
// purchase token to the backend (`/api/iap/apple/verify` or
// `/api/iap/google/verify`); the backend validates it with Apple/Google and is
// the sole authority on the resulting tier.

import 'dart:async';
import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:in_app_purchase/in_app_purchase.dart';

import '../../subscription_models.dart';
import 'iap_verification_service.dart';
import 'payment_models.dart';

/// Drives the StoreKit / Play Billing purchase lifecycle and hands every
/// receipt to [IapVerificationService] for server-side validation.
class IapService {
  IapService({
    InAppPurchase? inAppPurchase,
    IapVerificationService? verificationService,
  })  : _iap = inAppPurchase ?? InAppPurchase.instance,
        _verifier = verificationService ?? IapVerificationService();

  final InAppPurchase _iap;
  final IapVerificationService _verifier;

  StreamSubscription<List<PurchaseDetails>>? _purchaseSub;

  /// The user the current purchase/restore is being attributed to. Set when a
  /// purchase is initiated so the async stream listener knows which Story
  /// Weaver account to verify the receipt against.
  String? _activeUserId;

  /// Completer for the in-flight purchase/restore so [purchase] /
  /// [restorePurchases] can await the asynchronous store callback.
  Completer<PurchaseResult>? _pending;

  bool _initialized = false;

  /// The store product IDs STORE-1 sells. Must match the consoles.
  static const Set<String> _productIds = {
    kIapProductPremiumMonthly,
    kIapProductFamilyMonthly,
  };

  /// Connect to the store and start listening for purchase updates.
  Future<void> initialize() async {
    if (_initialized) return;
    final available = await _iap.isAvailable();
    if (!available) {
      // Store unreachable (e.g. sandbox not signed in). Surfaced lazily when
      // loadProducts / purchase is called.
      debugPrint('IapService: store not available on this device.');
    }
    _purchaseSub ??= _iap.purchaseStream.listen(
      _onPurchaseUpdates,
      onError: (Object error) {
        debugPrint('IapService purchase stream error: $error');
        _completePending(PurchaseResult.error('Store error: $error'));
      },
    );
    _initialized = true;
  }

  /// Query the store for the subscription products and their localised prices.
  Future<List<PaymentProduct>> loadProducts() async {
    await initialize();
    final response = await _iap.queryProductDetails(_productIds);
    if (response.error != null) {
      debugPrint('IapService.loadProducts error: ${response.error}');
    }
    if (response.notFoundIDs.isNotEmpty) {
      // TODO(STORE-1 / owner): product IDs missing from the store consoles.
      // Create `premium_monthly` / `family_monthly` in App Store Connect AND
      // the Google Play Console before the IAP path can be tested.
      debugPrint(
        'IapService: product IDs not found in store: ${response.notFoundIDs}',
      );
    }
    final products = <PaymentProduct>[];
    for (final details in response.productDetails) {
      final tier = tierForIapProductId(details.id);
      if (tier == null) continue;
      products.add(
        PaymentProduct(
          tier: tier,
          productId: details.id,
          title: details.title.isNotEmpty ? details.title : tier.displayName,
          priceLabel: details.price,
          description: details.description,
        ),
      );
    }
    return products;
  }

  /// Buy the product for [tier], attributing it to [userId].
  Future<PurchaseResult> purchase({
    required SubscriptionTier tier,
    required String userId,
  }) async {
    await initialize();

    final productId = iapProductIdForTier(tier);
    if (productId == null) {
      return PurchaseResult.error('Tier ${tier.name} is not purchasable.');
    }
    if (_pending != null && !_pending!.isCompleted) {
      return PurchaseResult.error('A purchase is already in progress.');
    }

    final response = await _iap.queryProductDetails({productId});
    final details = response.productDetails
        .where((d) => d.id == productId)
        .cast<ProductDetails?>()
        .firstWhere((_) => true, orElse: () => null);
    if (details == null) {
      return PurchaseResult.error(
        'Subscription product "$productId" is not available in the store.',
      );
    }

    _activeUserId = userId;
    _pending = Completer<PurchaseResult>();

    // `applicationUserName` ties the store transaction to the Story Weaver
    // account; the backend verify endpoint uses it to resolve the user.
    final purchaseParam = PurchaseParam(
      productDetails: details,
      applicationUserName: userId,
    );

    try {
      // Subscriptions are non-consumable from the plugin's POV.
      await _iap.buyNonConsumable(purchaseParam: purchaseParam);
    } catch (error) {
      _completePending(PurchaseResult.error('Could not start purchase: $error'));
    }

    return _pending!.future;
  }

  /// Re-apply purchases already owned by the signed-in store account.
  /// Apple requires a visible "Restore purchases" action.
  Future<PurchaseResult> restorePurchases({required String userId}) async {
    await initialize();
    if (_pending != null && !_pending!.isCompleted) {
      return PurchaseResult.error('A purchase is already in progress.');
    }
    _activeUserId = userId;
    _pending = Completer<PurchaseResult>();
    try {
      await _iap.restorePurchases();
    } catch (error) {
      _completePending(PurchaseResult.error('Restore failed: $error'));
    }
    // `restorePurchases` replays past purchases through `purchaseStream`; the
    // listener completes `_pending`. If the account owns nothing, no event
    // arrives — guard with a timeout so the UI is never stuck.
    return _pending!.future.timeout(
      const Duration(seconds: 20),
      onTimeout: () =>
          PurchaseResult.pending('No previous purchases found to restore.'),
    );
  }

  /// Handle every purchase-stream event: verify with the backend, then ack.
  Future<void> _onPurchaseUpdates(List<PurchaseDetails> purchases) async {
    for (final purchase in purchases) {
      switch (purchase.status) {
        case PurchaseStatus.pending:
          // Store sheet is still open / payment is processing. Wait.
          break;
        case PurchaseStatus.canceled:
          if (purchase.pendingCompletePurchase) {
            await _iap.completePurchase(purchase);
          }
          _completePending(PurchaseResult.cancelled());
          break;
        case PurchaseStatus.error:
          if (purchase.pendingCompletePurchase) {
            await _iap.completePurchase(purchase);
          }
          _completePending(
            PurchaseResult.error(
              purchase.error?.message ?? 'The purchase could not be completed.',
            ),
          );
          break;
        case PurchaseStatus.purchased:
        case PurchaseStatus.restored:
          await _verifyAndComplete(purchase);
          break;
      }
    }
  }

  /// Server-side receipt verification. The backend validates the receipt with
  /// Apple/Google and applies the entitlement; the client only relays it.
  Future<void> _verifyAndComplete(PurchaseDetails purchase) async {
    final userId = _activeUserId;
    PurchaseResult result;
    try {
      if (userId == null) {
        result = PurchaseResult.error('No user context for purchase.');
      } else {
        result = await _verifier.verify(
          userId: userId,
          purchase: purchase,
          platform: _currentStorePlatform(),
        );
      }
    } catch (error) {
      debugPrint('IAP verification failed: $error');
      result = PurchaseResult.error('Could not verify purchase: $error');
    }

    // ALWAYS finish the transaction with the store, even on a verification
    // failure — an un-acked StoreKit transaction is replayed forever. The
    // backend S2S notifications + a later "Restore purchases" recover any
    // entitlement that a transient verify failure dropped.
    if (purchase.pendingCompletePurchase) {
      await _iap.completePurchase(purchase);
    }
    _completePending(result);
  }

  PaymentChannelKind _currentStorePlatform() {
    if (Platform.isIOS || Platform.isMacOS) {
      return PaymentChannelKind.appleIap;
    }
    return PaymentChannelKind.googleIap;
  }

  void _completePending(PurchaseResult result) {
    final pending = _pending;
    if (pending != null && !pending.isCompleted) {
      pending.complete(result);
    }
  }

  void dispose() {
    _purchaseSub?.cancel();
    _purchaseSub = null;
    _initialized = false;
  }
}
