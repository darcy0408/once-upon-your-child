// lib/paywall_dialog.dart

import 'package:flutter/material.dart';
import 'subscription_service.dart';
import 'subscription_models.dart';
import 'premium_upgrade_screen.dart';

/// Paywall dialog shown when user hits tier limits
class PaywallDialog {
  /// Show limit reached dialog for stories
  static Future<bool> showStoryLimitDialog(
    BuildContext context, {
    required int remainingToday,
    required int remainingMonth,
  }) async {
    final subscriptionService = SubscriptionService();
    final subscription = await subscriptionService.getSubscription();

    if (!context.mounted) return false;

    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        title: Row(
          children: [
            Icon(
              Icons.lock,
              color: Colors.orange.shade700,
              size: 28,
            ),
            const SizedBox(width: 8),
            const Expanded(
              child: Text(
                'Story Limit Reached',
                style: TextStyle(fontSize: 20),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (remainingToday == 0)
              Text(
                'You\'ve used all ${subscription.limits.maxStoriesPerDay} stories for today!',
                style: const TextStyle(fontSize: 16),
              )
            else
              Text(
                'You\'ve reached your monthly limit of ${subscription.limits.maxStoriesPerMonth} stories.',
                style: const TextStyle(fontSize: 16),
              ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.purple.shade50,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.star, color: Colors.deepPurple),
                      const SizedBox(width: 8),
                      const Text(
                        'Upgrade to Premium',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  const Text('Get unlimited stories every day!'),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Maybe Later'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.deepPurple,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
            ),
            child: const Text('Upgrade Now'),
          ),
        ],
      ),
    );

    if (result == true && context.mounted) {
      final upgraded = await Navigator.push<bool>(
        context,
        MaterialPageRoute(
          builder: (_) => const PremiumUpgradeScreen(
            customMessage: 'Create unlimited stories for your kids!',
          ),
        ),
      );
      return upgraded ?? false;
    }

    return false;
  }

  /// Show feature locked dialog
  static Future<bool> showFeatureLockedDialog(
    BuildContext context, {
    required String featureName,
    required String description,
  }) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        title: Row(
          children: [
            Icon(
              Icons.lock_outline,
              color: Colors.deepPurple,
              size: 28,
            ),
            const SizedBox(width: 8),
            const Expanded(
              child: Text(
                'Premium Feature',
                style: TextStyle(fontSize: 20),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              featureName,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              description,
              style: const TextStyle(fontSize: 16),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.purple.shade50,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.deepPurple.shade200),
              ),
              child: Row(
                children: [
                  Icon(Icons.star, color: Colors.amber, size: 24),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Text(
                      'Unlock with Premium or Family plan',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Not Now'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.deepPurple,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
            ),
            child: const Text('See Plans'),
          ),
        ],
      ),
    );

    if (result == true && context.mounted) {
      final upgraded = await Navigator.push<bool>(
        context,
        MaterialPageRoute(
          builder: (_) => PremiumUpgradeScreen(
            requiredFeature: featureName,
            customMessage: description,
          ),
        ),
      );
      return upgraded ?? false;
    }

    return false;
  }

  /// Show character limit dialog
  static Future<bool> showCharacterLimitDialog(
    BuildContext context, {
    required int maxCharacters,
  }) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        title: Row(
          children: [
            Icon(
              Icons.people_outline,
              color: Colors.orange.shade700,
              size: 28,
            ),
            const SizedBox(width: 8),
            const Expanded(
              child: Text(
                'Character Limit Reached',
                style: TextStyle(fontSize: 20),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'You\'ve reached your limit of $maxCharacters character${maxCharacters == 1 ? '' : 's'}.',
              style: const TextStyle(fontSize: 16),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Colors.purple.shade50,
                    Colors.blue.shade50,
                  ],
                ),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.star, color: Colors.amber),
                      const SizedBox(width: 8),
                      const Text(
                        'Premium: 5 characters',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Icon(Icons.stars, color: Colors.amber),
                      const SizedBox(width: 8),
                      const Text(
                        'Family: 20 characters',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.deepPurple,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
            ),
            child: const Text('Upgrade'),
          ),
        ],
      ),
    );

    if (result == true && context.mounted) {
      final upgraded = await Navigator.push<bool>(
        context,
        MaterialPageRoute(
          builder: (_) => const PremiumUpgradeScreen(
            customMessage: 'Create characters for your whole family!',
          ),
        ),
      );
      return upgraded ?? false;
    }

    return false;
  }

  /// Show theme/companion locked dialog
  static Future<bool> showContentLockedDialog(
    BuildContext context, {
    required String contentType,
    required String contentName,
  }) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        title: Row(
          children: [
            Icon(
              Icons.lock,
              color: Colors.deepPurple,
              size: 28,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                '$contentType Locked',
                style: const TextStyle(fontSize: 20),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.stars,
              size: 64,
              color: Colors.amber.shade600,
            ),
            const SizedBox(height: 16),
            Text(
              '"$contentName" is a premium $contentType',
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            const Text(
              'Upgrade to unlock all themes and companions!',
              style: TextStyle(fontSize: 14),
              textAlign: TextAlign.center,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Choose Another'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.deepPurple,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
            ),
            child: const Text('Unlock'),
          ),
        ],
      ),
    );

    if (result == true && context.mounted) {
      final upgraded = await Navigator.push<bool>(
        context,
        MaterialPageRoute(
          builder: (_) => PremiumUpgradeScreen(
            customMessage: 'Unlock all $contentType options!',
          ),
        ),
      );
      return upgraded ?? false;
    }

    return false;
  }
}
