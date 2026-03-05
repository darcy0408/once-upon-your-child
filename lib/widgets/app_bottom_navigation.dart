import 'package:flutter/material.dart';
import '../services/feature_unlock_service.dart';
import '../theme/age_band_theme.dart';
import 'feature_unlock_tooltip.dart';

class AppBottomNavigationBar extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int> onTap;
  final String? userId;
  final int childAge;

  const AppBottomNavigationBar({
    super.key,
    required this.currentIndex,
    required this.onTap,
    this.userId,
    this.childAge = 8,
  });

  @override
  Widget build(BuildContext context) {
    final band = ageBandFromAge(childAge);

    // Nav height and icon size scale up for younger users (larger touch targets).
    final double iconSize;
    final double navHeight;
    switch (band) {
      case AgeBand.sprout:
        iconSize = 30;
        navHeight = 72;
        break;
      case AgeBand.explorer:
        iconSize = 28;
        navHeight = 64;
        break;
      case AgeBand.adventurer:
      case AgeBand.creator:
        iconSize = 26;
        navHeight = 60;
        break;
    }

    // Age-appropriate tab definitions. Settings is hidden for under-13.
    // NOTE: main_story.dart may reference tab index 3 (Settings). When childAge < 13
    // there are only 3 tabs — currentIndex is clamped below to prevent crashes,
    // but callers should be updated to avoid passing index 3 for under-13 users.
    final List<_TabConfig> tabConfigs;
    switch (band) {
      case AgeBand.sprout:
        tabConfigs = [
          _TabConfig(Icons.auto_stories, 'Stories'),
          _TabConfig(Icons.favorite_rounded, 'My Feelings'),
          _TabConfig(Icons.collections_bookmark, 'My Books'),
        ];
        break;
      case AgeBand.explorer:
        tabConfigs = [
          _TabConfig(Icons.auto_stories, 'Stories'),
          _TabConfig(Icons.local_florist, 'My Garden'),
          _TabConfig(Icons.library_books, 'Library'),
        ];
        break;
      case AgeBand.adventurer:
        tabConfigs = [
          _TabConfig(Icons.auto_stories, 'Stories'),
          _TabConfig(Icons.spa, 'Feelings Garden'),
          _TabConfig(Icons.library_books, 'Library'),
        ];
        break;
      case AgeBand.creator:
        tabConfigs = [
          _TabConfig(Icons.auto_stories, 'Stories'),
          _TabConfig(Icons.psychology, 'Feelings'),
          _TabConfig(Icons.library_books, 'Library'),
          _TabConfig(Icons.settings, 'Settings'),
        ];
        break;
    }

    // Clamp to avoid an index-out-of-range crash when Settings is hidden.
    final clampedIndex = currentIndex.clamp(0, tabConfigs.length - 1);

    final items = <BottomNavigationBarItem>[];
    for (var i = 0; i < tabConfigs.length; i++) {
      final cfg = tabConfigs[i];
      Widget iconWidget = _NavIcon(icon: cfg.icon, size: iconSize);
      if (i == 2) {
        iconWidget = FeatureUnlockTooltip(
          feature: FeatureType.characterCreation,
          userId: userId,
          child: iconWidget,
        );
      } else if (i == 3) {
        iconWidget = FeatureUnlockTooltip(
          feature: FeatureType.advancedSettings,
          userId: userId,
          child: iconWidget,
        );
      }
      items.add(BottomNavigationBarItem(icon: iconWidget, label: cfg.label));
    }

    return SizedBox(
      height: navHeight,
      child: BottomNavigationBar(
        currentIndex: clampedIndex,
        onTap: onTap,
        type: BottomNavigationBarType.fixed,
        selectedItemColor: Colors.purple,
        unselectedItemColor: Colors.grey,
        showUnselectedLabels: true,
        items: items,
      ),
    );
  }
}

class _TabConfig {
  final IconData icon;
  final String label;
  const _TabConfig(this.icon, this.label);
}

class _NavIcon extends StatelessWidget {
  final IconData icon;
  final double size;

  const _NavIcon({required this.icon, this.size = 26});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 48,
      height: 48,
      child: Center(
        child: Icon(icon, size: size),
      ),
    );
  }
}
