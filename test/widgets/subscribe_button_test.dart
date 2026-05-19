import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import '../../lib/subscription_models.dart';
import '../../lib/services/stripe_service.dart';
import '../../lib/widgets/subscribe_button.dart';

class _FakeStripeService extends StripeService {
  _FakeStripeService();

  @override
  Future<Map<String, dynamic>> createCheckoutSession({
    required String tier,
    String? userId,
  }) async {
    return {'checkout_url': 'https://example.com/checkout'};
  }

  @override
  Future<Map<String, dynamic>> getSubscriptionStatus(String userId) async {
    return {'status': 'inactive', 'tier': 'free'};
  }

  @override
  Future<bool> cancelSubscription(String userId) async {
    return true;
  }
}

void main() {
  group('SubscribeButton Widget Tests', () {
    testWidgets('displays subscribe button for premium tier', (WidgetTester tester) async {
      bool wasPressed = false;
      
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SubscribeButton(
              tier: SubscriptionTier.premium,
              onSuccess: () => wasPressed = true,
              stripeService: _FakeStripeService(),
            ),
          ),
        ),
      );

      // Verify the button displays correct text. SubscriptionTier.premium
      // renders as "Premium" (SubscriptionTier.displayName).
      expect(find.text('Subscribe to Premium'), findsOneWidget);
      
      // Verify the button has the correct icon
      expect(find.byIcon(Icons.star), findsOneWidget);
      
      // Verify button is enabled initially
      expect(find.byType(ElevatedButton), findsOneWidget);
    });

    testWidgets('displays subscribe button for family tier', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SubscribeButton(
              tier: SubscriptionTier.family,
              onSuccess: () {},
              stripeService: _FakeStripeService(),
            ),
          ),
        ),
      );

      // Verify the button displays correct text
      expect(find.text('Subscribe to Family'), findsOneWidget);
      
      // Verify the button has the correct icon
      expect(find.byIcon(Icons.family_restroom), findsOneWidget);
    });

    testWidgets('shows loading state when processing', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SubscribeButton(
              tier: SubscriptionTier.premium,
              onSuccess: () {},
              stripeService: _FakeStripeService(),
            ),
          ),
        ),
      );

      // Tap the button to trigger loading
      await tester.tap(find.byType(ElevatedButton));
      await tester.pump();

      // Verify loading state
      expect(find.text('Processing...'), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });
  });
}
