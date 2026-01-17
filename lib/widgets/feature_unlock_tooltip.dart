import 'package:flutter/material.dart';
import '../services/feature_unlock_service.dart';

/// Tooltip widget that shows unlock requirements for locked features
class FeatureUnlockTooltip extends StatelessWidget {
  final FeatureType feature;
  final Widget child;
  final String? userId;
  final bool showTooltip;

  const FeatureUnlockTooltip({
    super.key,
    required this.feature,
    required this.child,
    this.userId,
    this.showTooltip = true,
  });

  @override
  Widget build(BuildContext context) {
    if (!showTooltip) {
      return child;
    }

    return FutureBuilder<UnlockProgress>(
      future: FeatureUnlockService().getUnlockProgress(feature, userId),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return child;
        }

        final progress = snapshot.data!;
        if (progress.unlocked) {
          return child;
        }

        return Tooltip(
          message: _getTooltipMessage(progress),
          decoration: BoxDecoration(
            color: Theme.of(context).primaryColor.withValues(alpha: 0.9),
            borderRadius: BorderRadius.circular(8),
          ),
          textStyle: const TextStyle(
            color: Colors.white,
            fontSize: 14,
            fontWeight: FontWeight.w500,
          ),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          showDuration: const Duration(seconds: 3),
          child: Opacity(
            opacity: 0.6,
            child: child,
          ),
        );
      },
    );
  }

  String _getTooltipMessage(UnlockProgress progress) {
    final featureName = progress.featureName;
    final remaining = progress.storiesRemaining;

    if (remaining == 0) {
      return '$featureName is unlocked!';
    } else if (remaining == 1) {
      return 'Create 1 more story to unlock $featureName';
    } else {
      return 'Create $remaining more stories to unlock $featureName';
    }
  }
}

/// Celebration dialog for newly unlocked features
class FeatureUnlockCelebrationDialog extends StatelessWidget {
  final FeatureUnlockCelebration celebration;

  const FeatureUnlockCelebrationDialog({
    super.key,
    required this.celebration,
  });

  static void show(BuildContext context, FeatureUnlockCelebration celebration) {
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (context) => FeatureUnlockCelebrationDialog(celebration: celebration),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
      ),
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              Theme.of(context).primaryColor.withValues(alpha: 0.1),
              Theme.of(context).primaryColor.withValues(alpha: 0.05),
            ],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Celebration icon
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: Theme.of(context).primaryColor,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.celebration,
                color: Colors.white,
                size: 40,
              ),
            ),

            const SizedBox(height: 16),

            // Title
            Text(
              celebration.message,
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
                color: Theme.of(context).primaryColor,
              ),
              textAlign: TextAlign.center,
            ),

            const SizedBox(height: 12),

            // Description
            Text(
              celebration.description,
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                color: Colors.black87,
                height: 1.4,
              ),
              textAlign: TextAlign.center,
            ),

            const SizedBox(height: 24),

            // Continue button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => Navigator.of(context).pop(),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text(
                  'Awesome!',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Progress indicator for feature unlocks
class FeatureUnlockProgressIndicator extends StatelessWidget {
  final FeatureType feature;
  final String? userId;
  final double size;

  const FeatureUnlockProgressIndicator({
    super.key,
    required this.feature,
    this.userId,
    this.size = 24,
  });

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<UnlockProgress>(
      future: FeatureUnlockService().getUnlockProgress(feature, userId),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return SizedBox(
            width: size,
            height: size,
            child: const CircularProgressIndicator(strokeWidth: 2),
          );
        }

        final progress = snapshot.data!;
        if (progress.unlocked) {
          return Icon(
            Icons.check_circle,
            color: Colors.green,
            size: size,
          );
        }

        return SizedBox(
          width: size,
          height: size,
          child: CircularProgressIndicator(
            value: progress.currentProgress,
            strokeWidth: 2,
            backgroundColor: Colors.grey[300],
            valueColor: AlwaysStoppedAnimation<Color>(
              Theme.of(context).primaryColor,
            ),
          ),
        );
      },
    );
  }
}

/// Lock icon overlay for locked features
class FeatureLockOverlay extends StatelessWidget {
  final bool isLocked;
  final Widget child;
  final double iconSize;

  const FeatureLockOverlay({
    super.key,
    required this.isLocked,
    required this.child,
    this.iconSize = 16,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        child,
        if (isLocked)
          Positioned(
            top: 4,
            right: 4,
            child: Container(
              padding: const EdgeInsets.all(2),
              decoration: BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.1),
                    blurRadius: 2,
                    offset: const Offset(0, 1),
                  ),
                ],
              ),
              child: Icon(
                Icons.lock,
                color: Theme.of(context).primaryColor,
                size: iconSize,
              ),
            ),
          ),
      ],
    );
  }
}
