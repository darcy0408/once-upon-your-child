import 'package:flutter/material.dart';
import '../widgets/subscribe_button.dart';
import '../models/subscription_tier.dart';

/// Example screen showing how to use SubscribeButton widget
class SubscriptionExampleScreen extends StatelessWidget {
  const SubscriptionExampleScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Choose Your Plan'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.green,
        elevation: 0,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Upgrade Your Story Experience',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
            
            // Premium Tier
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.star, color: Colors.deepPurple),
                        const SizedBox(width: 8),
                        Text(
                          'Premium',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: Colors.deepPurple,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    const Text('\$9.99/month'),
                    const SizedBox(height: 8),
                    const Text('• Enhanced features\n• Priority support\n• Ad-free experience'),
                    const SizedBox(height: 16),
                    SubscribeButton(
                      tier: SubscriptionTier.premium,
                      onSuccess: () {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Premium subscription initiated!'),
                            backgroundColor: Colors.green,
                          ),
                        );
                        // Navigate to success screen or update UI
                      },
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}