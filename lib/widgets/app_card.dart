import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class AppCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final VoidCallback? onTap;
  final Color? color;

  const AppCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(AppSpacing.md),
    this.onTap,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    final card = Container(
      decoration: BoxDecoration(
        color: color ?? AppColors.cream.withValues(alpha: 0.7),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.2)),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.08),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      // Wrap in a transparent Material so ListTile/SwitchListTile children have
      // a Material ancestor for ink splashes. Without it, newer Flutter throws
      // "ListTile background color or ink splashes may be invisible" (the
      // DecoratedBox above has a background color), which fails widget tests
      // under the CI Flutter channel. Transparency keeps the card's look intact.
      child: Padding(
        padding: padding,
        child: Material(
          type: MaterialType.transparency,
          child: child,
        ),
      ),
    );

    if (onTap != null) {
      return InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: card,
      );
    }

    return card;
  }
}
