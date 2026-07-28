import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../theme/age_band_theme.dart';

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
    final band = Theme.of(context).extension<AgeBandThemeData>() ?? explorerTheme;
    final card = Container(
      decoration: BoxDecoration(
        color: color ?? band.cardColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: band.primary.withValues(alpha: 0.25)),
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
          child: DefaultTextStyle.merge(
            style: TextStyle(color: band.onCard),
            // ListTile does NOT read the DefaultTextStyle above it: it resolves
            // its title/subtitle from ListTileTheme, falling back to the global
            // textTheme, whose ink is picked for a light surface. So every
            // ListTile inside an AppCard rendered its title in near-black on
            // the card's dark band color while sibling plain Text was correct —
            // visible in Settings, where the Dashboard / Weekly Recap / Child
            // Profiles / Subscription titles were unreadable but their
            // subtitles were fine. Setting the ListTileTheme here fixes the
            // whole class at once instead of per call site.
            child: ListTileTheme.merge(
              textColor: band.onCard,
              iconColor: band.onCard,
              child: IconTheme.merge(
                data: IconThemeData(color: band.onCard),
                child: child,
              ),
            ),
          ),
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
