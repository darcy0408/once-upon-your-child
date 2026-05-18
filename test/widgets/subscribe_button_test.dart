import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:story_weaver_app/subscription_models.dart';
import 'package:story_weaver_app/services/payment/payment_channel.dart';
import 'package:story_weaver_app/widgets/subscribe_button.dart';

/// Fake [PaymentChannel] — STORE-1 (MT-143) replaced the direct StripeService
/// dependency with the platform-dispatched PaymentChannel abstraction.
class _FakePaymentChannel implements PaymentChannel {
  _FakePaymentChannel({this.result});

  /// If null, [purchase] never completes (used to assert the loading state).
  final PurchaseResult? result;

  @override
  PaymentChannelKind get kind => PaymentChannelKind.stripeWeb;

  @override
  bool get isStoreChannel => false;

  @override
  Future<void> initialize() async {}

  @override
  Future<List<PaymentProduct>> loadProducts() async => const [];

  @override
  Future<PurchaseResult> purchase({
    required SubscriptionTier tier,
    required String userId,
  }) async {
    if (result == null) {
      // Stay pending forever so the loading state is observable.
      return Completer<PurchaseResult>().future;
    }
    return result!;
  }

  @override
  Future<PurchaseResult> restorePurchases({required String userId}) async =>
      PurchaseResult.pending();

  @override
  void dispose() {}
}

void main() {
  group('SubscribeButton Widget Tests', () {
    testWidgets('displays subscribe button for premium tier',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SubscribeButton(
              tier: SubscriptionTier.premium,
              userId: 'test-user',
              onSuccess: () {},
              paymentChannel:
                  _FakePaymentChannel(result: PurchaseResult.pending()),
            ),
          ),
        ),
      );

      expect(find.text('Subscribe to Premium'), findsOneWidget);
      expect(find.byIcon(Icons.star), findsOneWidget);
      expect(find.byType(ElevatedButton), findsOneWidget);
    });

    testWidgets('displays subscribe button for family tier',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SubscribeButton(
              tier: SubscriptionTier.family,
              userId: 'test-user',
              onSuccess: () {},
              paymentChannel:
                  _FakePaymentChannel(result: PurchaseResult.pending()),
            ),
          ),
        ),
      );

      expect(find.text('Subscribe to Family'), findsOneWidget);
      expect(find.byIcon(Icons.family_restroom), findsOneWidget);
    });

    testWidgets('shows loading state when processing',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SubscribeButton(
              tier: SubscriptionTier.premium,
              userId: 'test-user',
              onSuccess: () {},
              // No result -> purchase stays pending -> loading state holds.
              paymentChannel: _FakePaymentChannel(),
            ),
          ),
        ),
      );

      await tester.tap(find.byType(ElevatedButton));
      await tester.pump();

      expect(find.text('Processing...'), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });
  });
}
