import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:story_weaver_app/models/subscription_status.dart';
import 'package:story_weaver_app/screens/subscription_management_screen.dart';
import 'package:story_weaver_app/services/api_service_manager.dart';
import 'package:story_weaver_app/services/payment/payment_channel.dart';
import 'package:story_weaver_app/services/stripe_service.dart';

/// Fake [PaymentChannel] mirroring the DI pattern in subscribe_button_test.
/// `isStoreChannel` toggles between the web (Stripe) and mobile (store) paths.
class _FakePaymentChannel implements PaymentChannel {
  _FakePaymentChannel({required this.isStoreChannel});

  @override
  final bool isStoreChannel;

  int restoreCalls = 0;

  @override
  PaymentChannelKind get kind => isStoreChannel
      ? PaymentChannelKind.appleIap
      : PaymentChannelKind.stripeWeb;

  @override
  Future<void> initialize() async {}

  @override
  Future<List<PaymentProduct>> loadProducts() async => const [];

  @override
  Future<PurchaseResult> purchase({
    required SubscriptionTier tier,
    required String userId,
  }) async =>
      PurchaseResult.pending();

  @override
  Future<PurchaseResult> restorePurchases({required String userId}) async {
    restoreCalls++;
    return PurchaseResult.pending('No previous purchases found to restore.');
  }

  @override
  void dispose() {}
}

class _StubStripeService extends StripeService {
  _StubStripeService({this.shouldSucceed = true});

  final bool shouldSucceed;
  bool didCancel = false;

  @override
  Future<Map<String, dynamic>> getSubscriptionStatus(String userId) async {
    return {
      'user_id': userId,
      'tier': 'premium',
      'status': 'active',
      'current_period_end': DateTime.utc(2025, 12, 1).toIso8601String(),
      'cancel_at_period_end': false,
    };
  }

  @override
  Future<bool> cancelSubscription(String userId) async {
    didCancel = true;
    return shouldSucceed;
  }
}

const _usagePayload = {
  'stories_this_month': 45,
  'stories_limit': 100,
  'characters_count': 3,
  'characters_limit': 5,
  'period_start': '2025-11-01T00:00:00Z',
  'period_end': '2025-12-01T00:00:00Z',
};

MockClient _buildMockClient() {
  return MockClient((request) async {
    if (request.method == 'POST' &&
        request.url.path.contains('/auth/anonymous')) {
      return http.Response(
        jsonEncode({'token': 'mock_token', 'user_id': 'user-123'}),
        200,
      );
    }
    if (request.method == 'GET' &&
        request.url.path.contains('/usage-stats')) {
      return http.Response(jsonEncode(_usagePayload), 200);
    }
    if (request.method == 'POST' &&
        request.url.path.contains('/cancel-subscription')) {
      return http.Response(
        jsonEncode({
          'success': true,
          'message': 'Subscription will be canceled at period end',
          'cancel_at_period_end': true,
        }),
        200,
      );
    }
    return http.Response('Not Found', 404);
  });
}

SubscriptionStatus _buildStatus() => SubscriptionStatus(
      userId: 'user-123',
      tier: SubscriptionTier.premium,
      status: 'active',
      currentPeriodEnd: DateTime.utc(2025, 12, 1),
      cancelAtPeriodEnd: false,
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    ApiServiceManager.setTestClient(_buildMockClient());
  });

  tearDown(() {
    ApiServiceManager.setTestClient(null);
  });

  Widget buildScreen({
    http.Client? client,
    StripeService? stripeService,
    PaymentChannel? paymentChannel,
  }) {
    return MaterialApp(
      home: SubscriptionManagementScreen(
        httpClient: client ?? _buildMockClient(),
        subscriptionLoader: (_) async => _buildStatus(),
        subscriptionSyncer: (_) async {},
        userIdResolver: () async => 'user-123',
        stripeService: stripeService ?? _StubStripeService(),
        // Default to the web (Stripe) channel so the Stripe management path is
        // exercised; the mobile tests below inject a store channel explicitly.
        paymentChannel:
            paymentChannel ?? _FakePaymentChannel(isStoreChannel: false),
      ),
    );
  }

  testWidgets('displays subscription info', (tester) async {
    await tester.pumpWidget(buildScreen());
    await tester.pumpAndSettle();

    expect(find.text('Current Plan'), findsOneWidget);
    // SubscriptionTier.premium renders as "Premium" (SubscriptionTier.displayName).
    expect(find.text('Premium'), findsOneWidget);
    expect(find.text('Active'), findsOneWidget);
    expect(find.textContaining('Renews on'), findsOneWidget);
  });

  testWidgets('shows usage stats', (tester) async {
    await tester.pumpWidget(buildScreen());
    await tester.pumpAndSettle();

    expect(find.text('45 / 100 (45%)'), findsOneWidget);
    expect(find.text('3 / 5 (60%)'), findsOneWidget);
    expect(find.byType(LinearProgressIndicator), findsNWidgets(2));
  });

  testWidgets('cancel button shows dialog', (tester) async {
    await tester.pumpWidget(buildScreen());
    await tester.pumpAndSettle();

    await tester.tap(find.text('Cancel Subscription'));
    await tester.pumpAndSettle();

    expect(find.text('Cancel Subscription'), findsWidgets);
    expect(
      find.textContaining('Are you sure? Subscription will end on'),
      findsOneWidget,
    );
  });

  testWidgets('web channel shows the Stripe management affordances',
      (tester) async {
    await tester.pumpWidget(buildScreen());
    await tester.pumpAndSettle();

    expect(find.text('Manage Billing'), findsOneWidget);
    expect(find.text('Cancel Subscription'), findsOneWidget);
    expect(
      find.textContaining('To change or cancel your subscription'),
      findsNothing,
    );
  });

  testWidgets('store channel hides Stripe steering and shows store copy',
      (tester) async {
    await tester.pumpWidget(
      buildScreen(paymentChannel: _FakePaymentChannel(isStoreChannel: true)),
    );
    await tester.pumpAndSettle();

    // Stripe billing-portal + Stripe cancel must be unreachable on store builds.
    expect(find.text('Manage Billing'), findsNothing);
    expect(find.text('Cancel Subscription'), findsNothing);
    // Store-appropriate management copy is shown instead.
    expect(
      find.textContaining('To change or cancel your subscription'),
      findsOneWidget,
    );
  });

  testWidgets('store channel Restore Purchases calls the IAP channel restore',
      (tester) async {
    final channel = _FakePaymentChannel(isStoreChannel: true);
    final stripe = _StubStripeService();

    await tester.pumpWidget(
      buildScreen(stripeService: stripe, paymentChannel: channel),
    );
    await tester.pumpAndSettle();

    // The button renders below the fold on the default 800x600 test
    // viewport; scroll it into view before tapping or the tap silently
    // misses (hits the root view instead) and restoreCalls stays 0.
    await tester.ensureVisible(find.text('Restore Purchases'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Restore Purchases'));
    await tester.pumpAndSettle();

    // Restore routed to StoreKit / Play Billing, not the Stripe backend refresh.
    expect(channel.restoreCalls, 1);
    expect(stripe.didCancel, isFalse);
  });
}
