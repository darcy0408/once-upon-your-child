// lib/dialogs/upgrade_prompt_dialog.dart
// Upgrade prompt with tier comparison table

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../screens/byok_setup_wizard.dart';
import '../services/grace_period_analytics.dart';
import '../settings_screen.dart';

class UpgradePromptDialog extends StatelessWidget {
  final bool isSoftPrompt; // true = soft prompt, false = hard limit
  final int storiesUsed;
  final int storiesLimit;
  final int accountAgeDays;
  final int daysRemainingInGracePeriod;

  const UpgradePromptDialog({
    super.key,
    required this.isSoftPrompt,
    required this.storiesUsed,
    required this.storiesLimit,
    required this.accountAgeDays,
    this.daysRemainingInGracePeriod = 0,
  });

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Row(
        children: [
          Icon(
            isSoftPrompt ? Icons.info : Icons.lock,
            color: isSoftPrompt ? Colors.orange : Colors.red,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              isSoftPrompt ? 'Usage Update' : 'Story Limit Reached',
              style: const TextStyle(fontSize: 18),
            ),
          ),
        ],
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (isSoftPrompt) ...[
              Text(
                'You\'ve used $storiesUsed out of $storiesLimit free stories today.',
                style: const TextStyle(fontSize: 16),
              ),
              const SizedBox(height: 12),
              if (daysRemainingInGracePeriod > 0)
                Text(
                  'You have $daysRemainingInGracePeriod more ${daysRemainingInGracePeriod == 1 ? "day" : "days"} of unlimited stories!',
                  style: TextStyle(
                    color: Colors.green[700],
                    fontWeight: FontWeight.bold,
                  ),
                )
              else
                Text(
                  'Your 3-day grace period ended ${accountAgeDays - 3} ${accountAgeDays - 3 == 1 ? "day" : "days"} ago. Upgrade for unlimited stories!',
                  style: TextStyle(color: Colors.grey[700]),
                ),
            ] else ...[
              Text(
                'You\'ve reached your daily limit of $storiesLimit stories.',
                style: const TextStyle(fontSize: 16),
              ),
              const SizedBox(height: 12),
              Text(
                'Upgrade to keep the adventures going — unlimited stories for your whole family!',
                style: TextStyle(color: Colors.grey[700]),
              ),
            ],

            const SizedBox(height: 24),

            // Tier comparison table
            _buildTierComparison(context),

            const SizedBox(height: 16),

            // Alternative: BYOK option
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.blue[50],
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.blue[200]!),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.key, color: Colors.blue, size: 20),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Bring Your Own API Key',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.blue[900],
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Custom avatars, illustrations, unlimited stories — free with your own Gemini key (~\$0.10-0.50/month).',
                    style: TextStyle(fontSize: 12, color: Colors.blue[800]),
                  ),
                  const SizedBox(height: 10),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: () async {
                        final container = ProviderScope.containerOf(context);
                        Navigator.pop(context, false);
                        final result = await Navigator.of(context).push<String>(
                          MaterialPageRoute(
                            builder: (_) => const ByokSetupWizardScreen(),
                            fullscreenDialog: true,
                          ),
                        );
                        if (result != null && result.isNotEmpty) {
                          await container.read(settingsProvider.notifier).reload();
                        }
                      },
                      icon: const Icon(Icons.key, size: 16),
                      label: const Text(
                        'Set Up Free Premium →',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.blue[800],
                        side: BorderSide(color: Colors.blue[400]!),
                        padding: const EdgeInsets.symmetric(vertical: 10),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      actions: [
        if (isSoftPrompt)
          TextButton(
            onPressed: () {
              GracePeriodAnalytics.upgradePromptClicked(promptType: 'soft_continue');
              Navigator.pop(context, false);
            },
            child: const Text('Continue'),
          ),
        TextButton(
          onPressed: () {
            GracePeriodAnalytics.upgradePromptClicked(
              promptType: isSoftPrompt ? 'soft_maybe_later' : 'hard_cancel',
            );
            Navigator.pop(context, false);
          },
          child: Text(isSoftPrompt ? 'Maybe Later' : 'Cancel'),
        ),
        ElevatedButton(
          onPressed: () {
            GracePeriodAnalytics.upgradePromptClicked(
              promptType: isSoftPrompt ? 'soft_view_plans' : 'hard_view_plans',
            );
            Navigator.pop(context, true);
            // Navigate to subscription plans
            Navigator.pushNamed(context, '/subscription-plans');
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.purple,
          ),
          child: const Text('View Plans'),
        ),
      ],
    );
  }

  Widget _buildTierComparison(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey[300]!),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        children: [
          _tierRow(
            context,
            'Feature',
            'Free',
            'Premium',
            'Family',
            isHeader: true,
          ),
          _tierRow(
            context,
            'Stories/Day',
            '$storiesLimit',
            '10/day',
            'Unlimited',
          ),
          _tierRow(
            context,
            'Illustrations',
            '❌',
            '1 per story',
            '3 per story',
          ),
          _tierRow(
            context,
            'Characters',
            '1',
            '3',
            'Unlimited 👨‍👩‍👧‍👦',
          ),
          _tierRow(
            context,
            'Interactive Stories',
            '❌',
            '✅',
            '✅',
          ),
          _tierRow(
            context,
            'Custom Avatars',
            '❌',
            '❌',
            '✅',
          ),
          _tierRow(
            context,
            'Price',
            // Prices source of truth: TierPricing (subscription_models.dart)
            '\$0',
            '\$9.99/mo',
            '\$19.99/mo',
          ),
        ],
      ),
    );
  }

  Widget _tierRow(
    BuildContext context,
    String feature,
    String free,
    String premium,
    String family, {
    bool isHeader = false,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: isHeader ? Colors.grey[200] : null,
        border: Border(
          bottom: BorderSide(color: Colors.grey[300]!),
        ),
      ),
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
      child: Row(
        children: [
          Expanded(
            flex: 2,
            child: Text(
              feature,
              style: TextStyle(
                fontWeight: isHeader ? FontWeight.bold : FontWeight.normal,
                fontSize: isHeader ? 14 : 13,
              ),
            ),
          ),
          Expanded(
            child: Text(
              free,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 12,
                fontWeight: isHeader ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          ),
          Expanded(
            child: Text(
              premium,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 12,
                fontWeight: isHeader ? FontWeight.bold : FontWeight.normal,
                color: isHeader ? null : Colors.amber[700],
              ),
            ),
          ),
          Expanded(
            child: Text(
              family,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 12,
                fontWeight: isHeader ? FontWeight.bold : FontWeight.normal,
                color: isHeader ? null : Colors.purple,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Widget to display grace period banner at top of screen
class GracePeriodBanner extends StatelessWidget {
  final int daysRemaining;
  final VoidCallback? onTap;

  const GracePeriodBanner({
    super.key,
    required this.daysRemaining,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    if (daysRemaining <= 0) return const SizedBox.shrink();

    return Material(
      color: Colors.green[100],
      child: InkWell(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              Icon(Icons.celebration, color: Colors.green[700], size: 24),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  '🎉 Grace Period: $daysRemaining more ${daysRemaining == 1 ? "day" : "days"} of unlimited stories!',
                  style: TextStyle(
                    color: Colors.green[900],
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
              ),
              Icon(Icons.info_outline, color: Colors.green[700], size: 20),
            ],
          ),
        ),
      ),
    );
  }
}

/// Widget to display usage indicator
class UsageIndicator extends StatelessWidget {
  final int used;
  final int limit;
  final bool isInGracePeriod;
  final Color color;

  const UsageIndicator({
    super.key,
    required this.used,
    required this.limit,
    required this.isInGracePeriod,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    if (isInGracePeriod || limit >= 999) {
      return const SizedBox.shrink();
    }

    final percentage = (used / limit).clamp(0.0, 1.0);

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Stories This Month',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: color,
                  fontSize: 13,
                ),
              ),
              Text(
                '$used / $limit',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: color,
                  fontSize: 13,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          LinearProgressIndicator(
            value: percentage,
            backgroundColor: Colors.grey[300],
            valueColor: AlwaysStoppedAnimation<Color>(color),
            minHeight: 6,
          ),
        ],
      ),
    );
  }
}
