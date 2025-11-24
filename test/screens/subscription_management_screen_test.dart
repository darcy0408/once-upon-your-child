import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:story_weaver_app/models/subscription_status.dart';
import 'package:story_weaver_app/screens/subscription_management_screen.dart';
import 'package:story_weaver_app/services/stripe_service.dart';

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

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const usagePayload = {
    'stories_this_month': 45,
    'stories_limit': 100,
    'characters_count': 3,
    'characters_limit': 5,
    'period_start': '2025-11-01T00:00:00Z',
    'period_end': '2025-12-01T00:00:00Z',
  };

  SubscriptionStatus buildStatus() => SubscriptionStatus(
        userId: 'user-123',
        tier: SubscriptionTier.premium,
        status: 'active',
        currentPeriodEnd: DateTime.utc(2025, 12, 1),
        cancelAtPeriodEnd: false,
      );

  MockClient buildClient() {
    return MockClient((request) async {
      if (request.method == 'GET' &&
          request.url.path.contains('/usage-stats')) {
        return http.Response(jsonEncode(usagePayload), 200);
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

  Widget buildScreen({http.Client? client, StripeService? stripeService}) {
    final httpClient = client ?? buildClient();
    return MaterialApp(
      home: SubscriptionManagementScreen(
        httpClient: httpClient,
        subscriptionLoader: (_) async => buildStatus(),
        subscriptionSyncer: (_) async {},
        userIdResolver: () async => 'user-123',
        stripeService: stripeService ?? _StubStripeService(),
      ),
    );
  }

  testWidgets('displays subscription info', (tester) async {
    await tester.pumpWidget(buildScreen());
    await tester.pumpAndSettle();

    expect(find.text('Current Plan'), findsOneWidget);
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
}
