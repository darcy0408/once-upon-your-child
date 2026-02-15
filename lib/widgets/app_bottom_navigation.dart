import 'package:flutter/material.dart';
import '../services/feature_unlock_service.dart';
import 'feature_unlock_tooltip.dart';

class AppBottomNavigationBar extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int> onTap;
  final String? userId;

  const AppBottomNavigationBar({
    super.key,
    required this.currentIndex,
    required this.onTap,
    this.userId,
  });

  @override
  Widget build(BuildContext context) {
    return BottomNavigationBar(
      currentIndex: currentIndex,
      onTap: onTap,
      type: BottomNavigationBarType.fixed,
      selectedItemColor: Colors.purple,
      unselectedItemColor: Colors.grey,
      showUnselectedLabels: true,
      items: [
        const BottomNavigationBarItem(
          icon: _NavIcon(icon: Icons.auto_stories),
          label: 'Stories',
        ),
        BottomNavigationBarItem(
          icon: FeatureUnlockTooltip(
            feature: FeatureType.characterCreation,
            userId: userId,
            child: const _NavIcon(icon: Icons.library_books),
          ),
          label: 'Library',
        ),
        BottomNavigationBarItem(
          icon: FeatureUnlockTooltip(
            feature: FeatureType.advancedSettings,
            userId: userId,
            child: const _NavIcon(icon: Icons.settings),
          ),
          label: 'Settings',
        ),
      ],
    );
  }
}

class _NavIcon extends StatelessWidget {
  final IconData icon;

  const _NavIcon({required this.icon});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 48,
      height: 48,
      child: Center(
        child: Icon(icon, size: 26),
      ),
    );
  }
}
