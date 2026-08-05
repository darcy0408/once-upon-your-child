import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:story_weaver_app/models/subscription_status.dart';
import 'package:story_weaver_app/screens/subscription_management_screen.dart';
import 'package:story_weaver_app/screens/subscription_success_screen.dart';
import 'package:story_weaver_app/services/api_service_manager.dart';
import 'package:story_weaver_app/services/payment/payment_channel.dart';
import 'package:story_weaver_app/services/stripe_service.dart';
import 'package:story_weaver_app/services/subscription_sync_service.dart';

import 'golden_test_harness.dart';

/// Stands in for the real [PaymentChannel].
///
/// Without this the screen calls `createPaymentChannel()`, which on a non-web
/// test host builds the Play Billing client and throws a channel-error
/// PlatformException — and, worse, makes the captured layout depend on the host
/// platform rather than on the branch under test. [isStore] selects which
/// management UI is captured: the Stripe buttons (web) or the "manage it in
/// your store settings" panel that Apple Guideline 3.1.1 requires.
class _StubPaymentChannel implements PaymentChannel {
  const _StubPaymentChannel({required this.isStore});

  final bool isStore;

  @override
  PaymentChannelKind get kind =>
      isStore ? PaymentChannelKind.googleIap : PaymentChannelKind.stripeWeb;

  @override
  bool get isStoreChannel => isStore;

  @override
  Future<void> initialize() async {}

  @override
  Future<List<PaymentProduct>> loadProducts() async => const [];

  @override
  Future<PurchaseResult> purchase({
    required SubscriptionTier tier,
    required String userId,
    BillingPeriod billingPeriod = BillingPeriod.monthly,
  }) async =>
      throw UnimplementedError('golden tests never start a purchase');

  @override
  Future<PurchaseResult> restorePurchases({required String userId}) async =>
      throw UnimplementedError('golden tests never restore purchases');

  @override
  void dispose() {}
}

class _StubStripeService extends StripeService {
  _StubStripeService({this.shouldSucceed = true});

  final bool shouldSucceed;

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
    return shouldSucceed;
  }
}

MockClient _buildClient() {
  return MockClient((request) async {
    if (request.method == 'POST' &&
        request.url.path.contains('/auth/anonymous')) {
      return http.Response(
        jsonEncode({'token': 'mock_token', 'user_id': 'user-123'}),
        200,
      );
    }
    if (request.method == 'GET' && request.url.path.contains('/usage-stats')) {
      return http.Response(
        jsonEncode({
          'stories_this_month': 45,
          'stories_limit': 100,
          'characters_count': 3,
          'characters_limit': 5,
          'period_start': '2025-11-01T00:00:00Z',
          'period_end': '2025-12-01T00:00:00Z',
        }),
        200,
      );
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

Widget _buildSubscriptionManagementScreen({required bool isStore}) {
  return SubscriptionManagementScreen(
    httpClient: _buildClient(),
    subscriptionLoader: (_) async => _buildStatus(),
    subscriptionSyncer: (_) async {},
    userIdResolver: () async => 'user-123',
    stripeService: _StubStripeService(),
    paymentChannel: _StubPaymentChannel(isStore: isStore),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    ApiServiceManager.setTestClient(_buildClient());
  });

  tearDown(() {
    ApiServiceManager.setTestClient(null);
    SubscriptionSyncService.resetInstance();
  });

  // The web build is what ships today, so it keeps the original golden name.
  testWidgets('Subscription management screen', (tester) async {
    await pumpGoldenApp(
      tester,
      _buildSubscriptionManagementScreen(isStore: false),
    );

    await expectLater(
      find.byType(Scaffold),
      matchesGoldenFile('subscription_management_screen.png'),
    );
  });

  // The store branch replaces the Stripe "Manage Billing"/"Cancel" buttons with
  // a pointer to the store's own settings — required by Apple Guideline 3.1.1
  // and Google Play Payments policy, and previously unpinned.
  testWidgets('Subscription management screen (store build)', (tester) async {
    await pumpGoldenApp(
      tester,
      _buildSubscriptionManagementScreen(isStore: true),
    );

    await expectLater(
      find.byType(Scaffold),
      matchesGoldenFile('subscription_management_screen_store.png'),
    );
  });

  testWidgets('Subscription success screen', (tester) async {
    // SubscriptionSuccessScreen.initState fires a fire-and-forget
    // SubscriptionSyncService().syncSubscriptionStatus(). Seed the singleton
    // with a stub-backed instance so the sync resolves instantly instead of
    // hitting the network and leaving a retry timer pending after teardown.
    SubscriptionSyncService.resetInstance(
      SubscriptionSyncService.forTest(stripeService: _StubStripeService()),
    );

    await pumpGoldenApp(tester, const SubscriptionSuccessScreen());

    await expectLater(
      find.byType(Scaffold),
      matchesGoldenFile('subscription_success_screen.png'),
    );
  });

}
