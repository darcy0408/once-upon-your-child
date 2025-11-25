// lib/dialogs/upgrade_prompt_dialog.dart
// Upgrade prompt with tier comparison table

import 'package:flutter/material.dart';

class UpgradePromptDialog extends StatelessWidget {
  final bool isSoftPrompt; // true = soft prompt, false = hard limit
  final int storiesUsed;
  final int storiesLimit;
  final int accountAgeDays;
  final int daysRemainingInGracePeriod;

  const UpgradePromptDialog({
    Key? key,
    required this.isSoftPrompt,
    required this.storiesUsed,
    required this.storiesLimit,
    required this.accountAgeDays,
    this.daysRemainingInGracePeriod = 0,
  }) : super(key: key);

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
                'You\'ve used $storiesUsed out of $storiesLimit free stories this month.',
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
                'You\'ve reached your monthly limit of $storiesLimit stories.',
                style: const TextStyle(fontSize: 16),
              ),
              const SizedBox(height: 12),
              Text(
                'Upgrade to continue creating unlimited therapeutic stories for your family!',
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
                    'Get unlimited stories for ~\$0.10-0.50/month using your own Gemini API key!',
                    style: TextStyle(fontSize: 12, color: Colors.blue[800]),
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
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Continue'),
          ),
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: Text(isSoftPrompt ? 'Maybe Later' : 'Cancel'),
        ),
        ElevatedButton(
          onPressed: () {
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
            'Stories/Month',
            '$storiesLimit',
            'Unlimited',
            'Unlimited',
          ),
          _tierRow(
            context,
            'Illustrations',
            'Learning mode only',
            '1 per story',
            '2 per story',
          ),
          _tierRow(
            context,
            'Characters',
            '1',
            'Unlimited',
            'Unlimited',
          ),
          _tierRow(
            context,
            'Interactive Stories',
            'Limited',
            'Unlimited',
            'Unlimited',
          ),
          _tierRow(
            context,
            'Price',
            '\$0',
            '\$9.99/mo',
            '\$14.99/mo',
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
    Key? key,
    required this.daysRemaining,
    this.onTap,
  }) : super(key: key);

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
    Key? key,
    required this.used,
    required this.limit,
    required this.isInGracePeriod,
    required this.color,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    if (isInGracePeriod || limit >= 999) {
      return const SizedBox.shrink();
    }

    final percentage = (used / limit).clamp(0.0, 1.0);

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.3)),
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
