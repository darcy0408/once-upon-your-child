import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:story_weaver_app/feelings_wheel_screen.dart';
import 'package:story_weaver_app/models/subscription_status.dart';
import 'package:story_weaver_app/screens/subscription_management_screen.dart';
import 'package:story_weaver_app/screens/subscription_success_screen.dart';
import 'package:story_weaver_app/services/api_service_manager.dart';
import 'package:story_weaver_app/services/stripe_service.dart';
import 'package:story_weaver_app/services/subscription_sync_service.dart';

import 'golden_test_harness.dart';

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

Widget _buildSubscriptionManagementScreen() {
  return SubscriptionManagementScreen(
    httpClient: _buildClient(),
    subscriptionLoader: (_) async => _buildStatus(),
    subscriptionSyncer: (_) async {},
    userIdResolver: () async => 'user-123',
    stripeService: _StubStripeService(),
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

  testWidgets('Subscription management screen', (tester) async {
    await pumpGoldenApp(tester, _buildSubscriptionManagementScreen());

    await expectLater(
      find.byType(Scaffold),
      matchesGoldenFile('subscription_management_screen.png'),
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

  testWidgets('Feelings wheel screen', (tester) async {
    await pumpGoldenApp(
      tester,
      Scaffold(
        appBar: AppBar(title: const Text('Feelings Wheel')),
        body: const SafeArea(
          child: Padding(
            padding: EdgeInsets.all(16),
            child: SingleChildScrollView(
              child: FeelingsWheelScreen(ageYears: 8),
            ),
          ),
        ),
      ),
    );

    await expectLater(
      find.byType(Scaffold),
      matchesGoldenFile('feelings_wheel_screen.png'),
    );
  });
}
