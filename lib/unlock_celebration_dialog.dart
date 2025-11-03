// lib/unlock_celebration_dialog.dart

import 'package:flutter/material.dart';
import 'services/progression_service.dart';

class UnlockCelebrationDialog extends StatelessWidget {
  final List<String> unlockedFeatures;
  final ProgressionService progressionService;

  const UnlockCelebrationDialog({
    required this.unlockedFeatures,
    required this.progressionService,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
      ),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 400),
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Celebration emoji
            const Text(
              '🎉',
              style: TextStyle(fontSize: 64),
            ),
            const SizedBox(height: 16),

            // Title
            const Text(
              'New Feature Unlocked!',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),

            // Feature cards
            ...unlockedFeatures.map((featureKey) {
              return Container(
                margin: const EdgeInsets.only(bottom: 16),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.purple.shade50,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: Colors.purple.shade200,
                    width: 2,
                  ),
                ),
                child: Column(
                  children: [
                    Row(
                      children: [
                        Icon(
                          _getFeatureIcon(featureKey),
                          color: Colors.purple.shade700,
                          size: 32,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            progressionService.getFeatureName(featureKey),
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Colors.purple,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      progressionService.getFeatureDescription(featureKey),
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey.shade700,
                      ),
                    ),
                  ],
                ),
              );
            }),

            const SizedBox(height: 8),

            // Encouragement message
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.green.shade50,
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Text(
                'Keep creating stories to unlock more amazing features!',
                style: TextStyle(
                  fontSize: 13,
                  fontStyle: FontStyle.italic,
                ),
                textAlign: TextAlign.center,
              ),
            ),

            const SizedBox(height: 24),

            // Close button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => Navigator.of(context).pop(),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.purple,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text(
                  'Awesome!',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  IconData _getFeatureIcon(String featureKey) {
    switch (featureKey) {
      case UnlockableFeatures.fantasyMode:
        return Icons.auto_awesome;
      case UnlockableFeatures.animalEarsTails:
        return Icons.pets;
      case UnlockableFeatures.customColors:
        return Icons.palette;
      case UnlockableFeatures.superheroMode:
        return Icons.flash_on;
      case UnlockableFeatures.interactiveStories:
        return Icons.alt_route;
      default:
        return Icons.star;
    }
  }

  /// Show the unlock celebration dialog
  static Future<void> show(
    BuildContext context,
    List<String> unlockedFeatures,
  ) async {
    if (unlockedFeatures.isEmpty) return;

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => UnlockCelebrationDialog(
        unlockedFeatures: unlockedFeatures,
        progressionService: ProgressionService(),
      ),
    );
  }
}
