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
                    const Text('\$9.99/month — or \$59.99/year (save 50%)'),
                    const SizedBox(height: 8),
                    const Text(
                      'Once Upon YOUR Child for the whole family. Every kid, plus mom, dad, even grandma can be in the story together.',
                      style: TextStyle(fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      '• 6 heroes — siblings, an adult relative, a pet, a magical companion\n'
                      '• Up to 10 stories every day, illustrated on every page\n'
                      '• Custom AI avatars that look like your child\n'
                      '• "Whose turn is it?" rotating hero between siblings\n'
                      '• Premium voice narration & continuing sagas\n'
                      '• All themes & companions unlocked',
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
            
          ],
        ),
      ),
    );
  }
}
