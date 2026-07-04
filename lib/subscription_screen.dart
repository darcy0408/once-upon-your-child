import 'package:flutter/material.dart';
import 'package:story_weaver_app/models/subscription_status.dart';
import '../widgets/subscribe_button.dart';
import '../widgets/subscription_status_banner.dart';

/// Example screen showing how to use the SubscribeButton widget
class SubscriptionScreen extends StatelessWidget {
  const SubscriptionScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Choose Your Plan'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.green,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SubscriptionStatusBanner(),
            const SizedBox(height: 16),
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
                        Expanded(
                          child: Text(
                            'Premium — for the whole family',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: Colors.deepPurple,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    const Text('\$9.99/month'),
                    const SizedBox(height: 8),
                    const Text(
                      'Once Upon YOUR Child for the whole family. Every kid, plus mom, dad, even grandma can be in the story together.',
                      style: TextStyle(fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      '• 6 characters — siblings, an adult relative, a pet, a magical companion\n'
                      '• 20 stories per month, 80–100 illustrated pages\n'
                      '• "Whose turn is it?" rotating hero between siblings\n'
                      '• 10,000 chars/mo of premium voice narration\n'
                      '• All 8 themes unlocked\n'
                      '• Ad-free experience',
                    ),
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
            
            const SizedBox(height: 16),
            
            // Family Tier
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.family_restroom, color: Colors.amber),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Family',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: Colors.amber,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    const Text('\$19.99/month'),
                    const SizedBox(height: 8),
                    const Text('• Up to 20 characters\n• Unlimited stories\n• All themes + exclusive\n• Priority support'),
                    const SizedBox(height: 16),
                    SubscribeButton(
                      tier: SubscriptionTier.family,
                      onSuccess: () {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Family subscription initiated!'),
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
