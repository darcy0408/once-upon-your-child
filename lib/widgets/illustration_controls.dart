// lib/widgets/illustration_controls.dart
// Tier-based illustration controls with clear messaging

import 'package:flutter/material.dart';

class IllustrationControls extends StatelessWidget {
  final String subscriptionTier; // 'free', 'premium', 'family'
  final bool isLearningToReadMode;
  final bool hasUserApiKey;
  final int currentIllustrationCount;
  final VoidCallback? onGenerateMore;
  final VoidCallback? onUpgrade;

  const IllustrationControls({
    super.key,
    required this.subscriptionTier,
    required this.isLearningToReadMode,
    required this.hasUserApiKey,
    required this.currentIllustrationCount,
    this.onGenerateMore,
    this.onUpgrade,
  });

  @override
  Widget build(BuildContext context) {
    // Determine what to show based on tier and current state
    final shouldShowAutoMessage = _shouldShowAutoMessage();
    final shouldShowUpgrade = _shouldShowUpgrade();
    final shouldShowGenerateButton = _shouldShowGenerateButton();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (shouldShowAutoMessage) _buildAutoMessage(context),
        if (shouldShowUpgrade) _buildUpgradePrompt(context),
        if (shouldShowGenerateButton) _buildGenerateButton(context),
      ],
    );
  }

  bool _shouldShowAutoMessage() {
    // Show explanation of why illustrations appeared automatically
    if (subscriptionTier == 'family' && currentIllustrationCount >= 2) return true;
    if (subscriptionTier == 'premium' && currentIllustrationCount >= 1) return true;
    if (isLearningToReadMode && currentIllustrationCount >= 1) return true;
    return false;
  }

  bool _shouldShowUpgrade() {
    // Show upgrade prompt for free tier (unless learning-to-read mode or BYOK)
    return subscriptionTier == 'free' &&
           !isLearningToReadMode &&
           !hasUserApiKey &&
           currentIllustrationCount == 0;
  }

  bool _shouldShowGenerateButton() {
    // Show generate button only if:
    // - Family tier and less than 2 illustrations
    // - Premium tier and less than 1 illustration
    // - Free tier with BYOK
    if (subscriptionTier == 'family' && currentIllustrationCount < 2) return true;
    if (subscriptionTier == 'premium' && currentIllustrationCount < 1) return true;
    if (subscriptionTier == 'free' && hasUserApiKey) return true;
    return false;
  }

  Widget _buildAutoMessage(BuildContext context) {
    String message;
    IconData icon;
    Color color;

    if (subscriptionTier == 'family') {
      message = '✓ 2 illustrations included automatically with Family plan!';
      icon = Icons.family_restroom;
      color = Colors.purple;
    } else if (subscriptionTier == 'premium') {
      message = '✓ 1 illustration included automatically with Premium plan!';
      icon = Icons.star;
      color = Colors.amber;
    } else {
      message = '✓ 1 free illustration for learning-to-read mode!';
      icon = Icons.school;
      color = Colors.blue;
    }

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color, width: 2),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 28),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              message,
              style: TextStyle(
                color: color,
                fontWeight: FontWeight.bold,
                fontSize: 14,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildUpgradePrompt(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.purple[100]!, Colors.pink[100]!],
        ),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.palette, color: Colors.purple, size: 28),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Want automatic illustrations?',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            'Upgrade to Premium for 1 illustration per story, or Family for 2 illustrations!',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: _upgradeButton(context, 'Premium\n\$9.99/mo', 'premium'),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _upgradeButton(context, 'Family\n\$14.99/mo', 'family'),
              ),
            ],
          ),
          const SizedBox(height: 8),
          TextButton.icon(
            onPressed: () {
              // Navigate to BYOK setup
              // Note: This route should be added to main app routing
              Navigator.pushNamed(context, '/settings/api-key');
            },
            icon: const Icon(Icons.key, size: 16),
            label: const Text('Or bring your own Gemini API key'),
            style: TextButton.styleFrom(
              foregroundColor: Colors.purple,
              textStyle: const TextStyle(fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }

  Widget _upgradeButton(BuildContext context, String label, String tier) {
    return ElevatedButton(
      onPressed: () => onUpgrade?.call(),
      style: ElevatedButton.styleFrom(
        backgroundColor: tier == 'family' ? Colors.purple : Colors.amber,
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
      ),
      child: Text(
        label,
        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
        textAlign: TextAlign.center,
      ),
    );
  }

  Widget _buildGenerateButton(BuildContext context) {
    String label;
    if (subscriptionTier == 'family' && currentIllustrationCount == 1) {
      label = 'Generate 2nd Illustration';
    } else if (subscriptionTier == 'premium' && currentIllustrationCount == 0) {
      label = 'Generate Illustration';
    } else {
      label = 'Generate Illustration';
    }

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 12),
      child: ElevatedButton.icon(
        onPressed: onGenerateMore,
        icon: const Icon(Icons.palette),
        label: Text(label),
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.purple,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          minimumSize: const Size(double.infinity, 50),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
    );
  }
}

/// Extension to show illustration counter chip
class IllustrationCounter extends StatelessWidget {
  final int current;
  final int max;

  const IllustrationCounter({
    super.key,
    required this.current,
    required this.max,
  });

  @override
  Widget build(BuildContext context) {
    return Chip(
      label: Text('$current of $max'),
      backgroundColor: Colors.purple[100],
      labelStyle: const TextStyle(
        fontWeight: FontWeight.bold,
        fontSize: 13,
      ),
    );
  }
}
