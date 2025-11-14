import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

class AppSwitch extends StatelessWidget {
  final bool value;
  final ValueChanged<bool>? onChanged;
  final String? label;
  final String? subtitle;
  final IconData? icon;
  final Widget? trailing;

  const AppSwitch({
    super.key,
    required this.value,
    required this.onChanged,
    this.label,
    this.subtitle,
    this.icon,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    return SwitchListTile(
      contentPadding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.xs,
      ),
      value: value,
      onChanged: onChanged,
      activeColor: AppColors.primary,
      title: label != null
          ? Text(
              label!,
              style: Theme.of(context)
                  .textTheme
                  .titleMedium
                  ?.copyWith(fontWeight: FontWeight.w600),
            )
          : null,
      subtitle:
          subtitle != null ? Text(subtitle!, style: Theme.of(context).textTheme.bodyMedium) : null,
      secondary: icon != null ? Icon(icon, color: AppColors.primary) : null,
      tileColor: Colors.transparent,
    );
  }
}
