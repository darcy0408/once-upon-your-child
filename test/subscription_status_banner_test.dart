import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:story_weaver_app/models/subscription_status.dart';
import 'package:story_weaver_app/widgets/subscription_status_banner.dart';

void main() {
  SubscriptionStatus buildStatus({
    required SubscriptionTier tier,
    required String status,
  }) {
    return SubscriptionStatus(
      userId: 'user-test',
      tier: tier,
      status: status,
      currentPeriodEnd: DateTime.now().toUtc().add(const Duration(days: 30)),
      cancelAtPeriodEnd: false,
    );
  }

  testWidgets('updates tier label when subscription stream emits',
      (tester) async {
    final controller = StreamController<SubscriptionStatus>();
    addTearDown(controller.close);

    final freeStatus =
        buildStatus(tier: SubscriptionTier.free, status: 'active');
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SubscriptionStatusBanner(
            statusStream: controller.stream,
            initialStatus: freeStatus,
          ),
        ),
      ),
    );

    expect(find.text('Current plan: Free'), findsOneWidget);

    controller.add(
      buildStatus(tier: SubscriptionTier.premium, status: 'active'),
    );
    await tester.pump();

    expect(find.text('Current plan: Adventurer'), findsOneWidget);
  });

  testWidgets('shows status changes when stream updates', (tester) async {
    final controller = StreamController<SubscriptionStatus>();
    addTearDown(controller.close);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SubscriptionStatusBanner(
            statusStream: controller.stream,
            initialStatus:
                buildStatus(tier: SubscriptionTier.family, status: 'trialing'),
          ),
        ),
      ),
    );

    expect(find.text('Status: Trialing'), findsOneWidget);

    controller.add(
      buildStatus(tier: SubscriptionTier.family, status: 'past_due'),
    );
    await tester.pump();

    expect(find.text('Status: Past Due'), findsOneWidget);
  });
}
