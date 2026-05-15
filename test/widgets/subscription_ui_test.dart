import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:story_weaver_app/models/subscription_status.dart';
import 'package:story_weaver_app/services/subscription_service.dart';
import 'package:story_weaver_app/widgets/subscription_status_banner.dart';
import 'dart:async';

class MockSubscriptionService extends SubscriptionService {
  final _controller = StreamController<SubscriptionStatus>();

  @override
  Stream<SubscriptionStatus> get statusStream => _controller.stream;

  void emitStatus(SubscriptionStatus status) {
    _controller.add(status);
  }

  @override
  void dispose() {
    _controller.close();
    super.dispose();
  }
}

void main() {
  testWidgets('SubscriptionStatusBanner shows loading state', (WidgetTester tester) async {
    final service = MockSubscriptionService();
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SubscriptionStatusBanner(subscriptionService: service),
        ),
      ),
    );

    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(find.text('Syncing subscription status...'), findsOneWidget);
  });

  testWidgets('SubscriptionStatusBanner shows subscription data', (WidgetTester tester) async {
    final service = MockSubscriptionService();
    final subscriptionStatus = SubscriptionStatus(
      userId: '123',
      tier: SubscriptionTier.premium,
      status: 'active',
      currentPeriodEnd: DateTime.now().add(const Duration(days: 30)),
      cancelAtPeriodEnd: false,
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SubscriptionStatusBanner(subscriptionService: service),
        ),
      ),
    );

    service.emitStatus(subscriptionStatus);
    await tester.pump();

    expect(find.text('Current plan: Premium'), findsOneWidget);
    expect(find.text('Status: Active'), findsOneWidget);
  });
}
