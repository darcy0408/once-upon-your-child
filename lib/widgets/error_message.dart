import 'package:flutter/material.dart';
import '../theme/age_band_theme.dart';
import '../theme/app_theme.dart';

class ErrorMessage extends StatelessWidget {
  final String title;
  final String message;
  final VoidCallback? onRetry;

  const ErrorMessage({
    super.key,
    required this.title,
    required this.message,
    this.onRetry,
  });

  /// A red that stays legible on the band's card. `AppColors.error` is ~3.3:1
  /// on the 9+ bands' dark cards, so those get a light red instead.
  static Color _accentOn(Color surface) => surface.computeLuminance() < 0.5
      ? const Color(0xFFFF8A80)
      : AppColors.error;

  @override
  Widget build(BuildContext context) {
    // Same resolution AppCard uses. Without this the widget inherited the
    // global light textTheme and drew near-black body text on the band's dark
    // gradient — the message was there but effectively unreadable on every
    // band 9+, which is how MT-382(e)'s child-safe copy was found to be
    // invisible in the 360x740 render.
    final band =
        Theme.of(context).extension<AgeBandThemeData>() ?? explorerTheme;
    final accent = _accentOn(band.cardColor);

    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: band.cardColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: accent.withValues(alpha: 0.45)),
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.error_outline, color: accent),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Text(
                    title,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          color: accent,
                          fontWeight: FontWeight.bold,
                        ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              message,
              style: Theme.of(context)
                  .textTheme
                  .bodyMedium
                  ?.copyWith(color: band.onCard),
            ),
            if (onRetry != null) ...[
              const SizedBox(height: AppSpacing.md),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton.icon(
                  onPressed: onRetry,
                  style: TextButton.styleFrom(foregroundColor: accent),
                  icon: const Icon(Icons.refresh),
                  label: const Text('Try again'),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
