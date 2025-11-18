import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:story_weaver_app/models/subscription_status.dart';
import 'package:story_weaver_app/services/subscription_service.dart';
import 'dart:async';

// A mock subscription service for testing
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

class SubscriptionWidget extends StatelessWidget {
  final SubscriptionService subscriptionService;

  const SubscriptionWidget({super.key, required this.subscriptionService});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<SubscriptionStatus>(
      stream: subscriptionService.statusStream,
      builder: (context, snapshot) {
        if (snapshot.hasData) {
          return Text('Tier: ${snapshot.data!.tier.displayName}, Status: ${snapshot.data!.status}');
        }
        return const Text('Loading...');
      },
    );
  }
}

void main() {
  testWidgets('SubscriptionWidget updates when subscription changes', (WidgetTester tester) async {
    final service = MockSubscriptionService();

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SubscriptionWidget(subscriptionService: service),
        ),
      ),
    );

    // Initial state
    expect(find.text('Loading...'), findsOneWidget);

    // Emit a new status
    final premiumStatus = SubscriptionStatus(
      userId: '123',
      tier: SubscriptionTier.premium,
      status: 'active',
      cancelAtPeriodEnd: false,
    );
    service.emitStatus(premiumStatus);
    await tester.pump();

    // Check if the widget updated
    expect(find.text('Tier: Premium, Status: active'), findsOneWidget);

    // Emit another status
    final freeStatus = SubscriptionStatus(
      userId: '123',
      tier: SubscriptionTier.free,
      status: 'canceled',
      cancelAtPeriodEnd: true,
    );
    service.emitStatus(freeStatus);
    await tester.pump();

    // Check if the widget updated again
    expect(find.text('Tier: Free, Status: canceled'), findsOneWidget);

    service.dispose();
  });
}