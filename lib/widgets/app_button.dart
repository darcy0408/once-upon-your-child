import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class AppButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final bool isSecondary;
  final IconData? icon;
  final String? semanticLabel; // NEW

  const AppButton.primary({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.semanticLabel, // NEW
  }) : isSecondary = false;

  const AppButton.secondary({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.semanticLabel, // NEW
  }) : isSecondary = true;

  @override
  Widget build(BuildContext context) {
    final child = Row(
      mainAxisAlignment: MainAxisAlignment.center,
      mainAxisSize: MainAxisSize.max,
      children: [
        if (icon != null) ...[
          Icon(icon, size: 18),
          const SizedBox(width: 8),
        ],
        Flexible(
          child: Text(
            label,
            textAlign: TextAlign.center,
            // Ellipsis without an explicit maxLines collapses to a SINGLE
            // line, which made long labels unreadable — Pick-a-Path renders
            // each branch choice through this button, so a child was picking
            // between "Step into the library's doorway and ask the arc…"
            // and two other truncated sentences (MT-393). The button's height
            // is a minimum, so it grows to fit the wrapped label.
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );

    if (isSecondary) {
      return Tooltip(
        message: semanticLabel ?? label,
        child: OutlinedButton(
          onPressed: onPressed,
          style: OutlinedButton.styleFrom(
            minimumSize: const Size(double.infinity, 52),
            foregroundColor: AppColors.primary,
            // See the note on the primary button below: without an explicit
            // disabled colour Flutter substitutes onSurface at 38%, which is
            // unreadable here.
            disabledForegroundColor: AppColors.primary.withValues(alpha: 0.55),
            side: const BorderSide(color: AppColors.primary, width: 2),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
          ),
          child: child,
        ),
      );
    }

    return Tooltip(
      message: semanticLabel ?? label,
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          minimumSize: const Size(double.infinity, 52),
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          // styleFrom does NOT derive disabled colours from the enabled ones —
          // omit these and Flutter falls back to the theme's onSurface at 12%
          // background / 38% foreground. Measured on the dark band scaffold
          // that lands at 1.14:1, i.e. effectively invisible.
          //
          // This is not cosmetic. Pick-a-Path renders every branch choice
          // through this button and disables them all while the next segment
          // generates. A reader reported not being able to tell what the
          // buttons said; the request behind that tap took 32 seconds, so the
          // choices sat unreadable for the whole wait.
          //
          // These values measure 7.7:1 over the same scaffold — clearly still
          // "dimmed", but legible. Related measured table: the project's
          // dark-background contrast notes (white38 fails, white54 passes).
          disabledBackgroundColor: AppColors.primary.withValues(alpha: 0.45),
          disabledForegroundColor: Colors.white.withValues(alpha: 0.75),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
        child: child,
      ),
    );
  }
}
