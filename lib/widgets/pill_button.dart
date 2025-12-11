import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// PillButton - A rounded pill-shaped button with an emoji and text
///
/// Design specs:
/// - Min touch target: 64x64px (WCAG AAA)
/// - Fully rounded corners (pill shape)
/// - Emoji on left, text on right
/// - High contrast borders for selected state
/// - Supports gold/cream color variants
class PillButton extends StatelessWidget {
  final String emoji;
  final String label;
  final bool isSelected;
  final VoidCallback onTap;
  final PillButtonVariant variant;
  final bool isEnabled;

  const PillButton({
    super.key,
    required this.emoji,
    required this.label,
    required this.onTap,
    this.isSelected = false,
    this.variant = PillButtonVariant.cream,
    this.isEnabled = true,
  });

  @override
  Widget build(BuildContext context) {
    final backgroundColor = _getBackgroundColor();
    final borderColor = isSelected ? AppColors.primary : Colors.transparent;
    final textColor = isEnabled ? AppColors.textDark : AppColors.textDisabled;

    return Semantics(
      button: true,
      enabled: isEnabled,
      selected: isSelected,
      label: '$label button',
      child: InkWell(
        onTap: isEnabled ? onTap : null,
        borderRadius: BorderRadius.circular(AppRadius.pill),
        child: Container(
          constraints: const BoxConstraints(
            minHeight: AppTouchTargets.minSize,
            minWidth: 120, // Enough for emoji + short text
          ),
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.lg,
            vertical: AppSpacing.sm,
          ),
          decoration: BoxDecoration(
            color: backgroundColor,
            borderRadius: BorderRadius.circular(AppRadius.pill),
            border: Border.all(
              color: borderColor,
              width: isSelected ? 2.0 : 0,
            ),
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: AppColors.goldLight.withAlpha(102), // 40% opacity
                      blurRadius: 8,
                      spreadRadius: 2,
                    ),
                  ]
                : null,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Emoji icon
              Text(
                emoji,
                style: const TextStyle(fontSize: 24),
              ),
              const SizedBox(width: AppSpacing.sm),
              // Label text
              Flexible(
                child: Text(
                  label,
                  style: Theme.of(context).textTheme.labelMedium?.copyWith(
                        color: textColor,
                        fontWeight: FontWeight.w600,
                      ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Color _getBackgroundColor() {
    if (!isEnabled) {
      return AppColors.textDisabled.withAlpha(51); // 20% opacity
    }

    switch (variant) {
      case PillButtonVariant.cream:
        return AppColors.cream;
      case PillButtonVariant.purple:
        return AppColors.primaryLight.withAlpha(51); // 20% opacity
      case PillButtonVariant.gold:
        return AppColors.goldLight.withAlpha(77); // 30% opacity
    }
  }
}

enum PillButtonVariant {
  cream, // Default soft cream color
  purple, // Light purple tint
  gold, // Light gold tint
}
