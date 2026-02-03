// lib/widgets/mood_lantern_selector.dart
/// Mood Lantern Selector - An enchanted collection of glowing lanterns
/// for children to choose their story's emotional ingredient.
///
/// Design philosophy: "Picking a magic ingredient" not "checking an emotion box"
///
/// Features:
/// - 7 beautiful lantern images with vivid chakra colors
/// - Animated glow effects for selected/unselected states
/// - Short magic description visible under each lantern
/// - Warm, inviting visual design
library;

import 'package:flutter/material.dart';
import '../data/mood_lantern_data.dart';
import '../feelings_wheel_data.dart';

/// Callback type for lantern selection.
typedef OnLanternSelected = void Function(SelectedFeeling feeling);

/// Main Mood Lantern Selector widget.
///
/// Displays a collection of glowing lanterns in a responsive grid.
/// Tap a lantern to select that mood for the story.
class MoodLanternSelector extends StatefulWidget {
  final OnLanternSelected? onFeelingSelected;
  final String? initialLanternId;
  final Color backgroundColor;

  const MoodLanternSelector({
    super.key,
    this.onFeelingSelected,
    this.initialLanternId,
    this.backgroundColor = const Color(0xFFFFF8E1), // Warm cream
  });

  @override
  State<MoodLanternSelector> createState() => _MoodLanternSelectorState();
}

class _MoodLanternSelectorState extends State<MoodLanternSelector>
    with TickerProviderStateMixin {
  String? _selectedLanternId;
  late AnimationController _glowController;
  late Animation<double> _glowAnimation;
  late AnimationController _idleController;
  late Animation<double> _idleAnimation;

  @override
  void initState() {
    super.initState();
    _selectedLanternId = widget.initialLanternId;

    // Glow animation for selected lantern (brighter, faster)
    _glowController = AnimationController(
      duration: const Duration(milliseconds: 1200),
      vsync: this,
    )..repeat(reverse: true);
    _glowAnimation = Tween<double>(begin: 0.7, end: 1.0).animate(
      CurvedAnimation(parent: _glowController, curve: Curves.easeInOut),
    );

    // Idle animation for unselected lanterns (subtle, slower)
    _idleController = AnimationController(
      duration: const Duration(milliseconds: 2500),
      vsync: this,
    )..repeat(reverse: true);
    _idleAnimation = Tween<double>(begin: 0.85, end: 1.0).animate(
      CurvedAnimation(parent: _idleController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _glowController.dispose();
    _idleController.dispose();
    super.dispose();
  }

  void _selectLantern(MoodLantern lantern) {
    setState(() {
      _selectedLanternId = lantern.id;
    });
    widget.onFeelingSelected?.call(lantern.toSelectedFeeling());
  }

  MoodLantern? get _selectedLantern =>
      _selectedLanternId != null ? getLanternById(_selectedLanternId!) : null;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge([_glowAnimation, _idleAnimation]),
      builder: (context, child) {
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Title
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Text(
                'Choose Your Story\'s Magic ✨',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: const Color(0xFF5D4037), // Warm brown
                    ),
                textAlign: TextAlign.center,
              ),
            ),

            // Subtitle instruction
            Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: Text(
                'Tap a lantern to pick the feeling for your adventure',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: const Color(0xFF795548),
                      fontStyle: FontStyle.italic,
                    ),
                textAlign: TextAlign.center,
              ),
            ),

            // Lantern grid - no container box, just the lanterns
            _LanternGrid(
              selectedLanternId: _selectedLanternId,
              glowIntensity: _glowAnimation.value,
              idleIntensity: _idleAnimation.value,
              onLanternTap: _selectLantern,
            ),

            // Selected lantern expanded description
            if (_selectedLantern != null) ...[
              const SizedBox(height: 16),
              _MoodDescription(lantern: _selectedLantern!),
            ],
          ],
        );
      },
    );
  }
}

/// Responsive grid of lanterns - adapts to screen width.
class _LanternGrid extends StatelessWidget {
  final String? selectedLanternId;
  final double glowIntensity;
  final double idleIntensity;
  final ValueChanged<MoodLantern> onLanternTap;

  const _LanternGrid({
    required this.selectedLanternId,
    required this.glowIntensity,
    required this.idleIntensity,
    required this.onLanternTap,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final availableWidth = constraints.maxWidth;

        // Calculate lantern size based on screen width
        // Aim for 4 lanterns per row on narrow, 7 on wide
        final int lanternsPerRow = availableWidth < 400 ? 3 : (availableWidth < 600 ? 4 : 7);
        final double lanternSize = ((availableWidth - (lanternsPerRow * 8)) / lanternsPerRow).clamp(50.0, 75.0);

        return Wrap(
          alignment: WrapAlignment.center,
          spacing: 4,
          runSpacing: 12,
          children: kMoodLanterns.map((lantern) {
            final isSelected = selectedLanternId == lantern.id;
            return _LanternWidget(
              lantern: lantern,
              isSelected: isSelected,
              glowIntensity: isSelected ? glowIntensity : idleIntensity,
              onTap: () => onLanternTap(lantern),
              size: lanternSize,
            );
          }).toList(),
        );
      },
    );
  }
}

/// Individual lantern widget with image, glow animation, and magic label.
class _LanternWidget extends StatelessWidget {
  final MoodLantern lantern;
  final bool isSelected;
  final double glowIntensity;
  final VoidCallback onTap;
  final double size;

  const _LanternWidget({
    required this.lantern,
    required this.isSelected,
    required this.glowIntensity,
    required this.onTap,
    this.size = 65,
  });

  /// Get a short magic label for the lantern (visible always)
  String get _shortMagic {
    switch (lantern.coreEmotion.toLowerCase()) {
      case 'happy':
        return 'Joy & Smiles';
      case 'angry':
        return 'Stand Up';
      case 'sad':
        return 'Comfort';
      case 'fearful':
        return 'Courage';
      case 'silly':
        return 'Giggles';
      case 'calm':
        return 'Peace';
      case 'excited':
        return 'Adventure';
      default:
        return lantern.coreEmotion;
    }
  }

  @override
  Widget build(BuildContext context) {
    // More vivid color for better visibility
    final vividColor = HSLColor.fromColor(lantern.color)
        .withSaturation(0.85)
        .withLightness(0.5)
        .toColor();

    return GestureDetector(
      onTap: onTap,
      child: Semantics(
        button: true,
        selected: isSelected,
        label: '${lantern.name} lantern, ${lantern.storyMagic}',
        child: AnimatedScale(
          scale: isSelected ? 1.1 : 1.0,
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOutBack,
          child: SizedBox(
            width: size + 16, // Add padding for glow effect
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Lantern with glow
                SizedBox(
                  width: size + 16,
                  height: size + 16,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      // Outer glow effect - vivid color
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 300),
                        width: size,
                        height: size,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: vividColor.withValues(
                                alpha: isSelected
                                    ? 0.7 * glowIntensity
                                    : 0.3 * glowIntensity,
                              ),
                              blurRadius: isSelected ? 25 : 12,
                              spreadRadius: isSelected ? 8 : 2,
                            ),
                            if (isSelected)
                              BoxShadow(
                                color: vividColor.withValues(alpha: 0.4),
                                blurRadius: 40,
                                spreadRadius: 15,
                              ),
                          ],
                        ),
                      ),
                      // Lantern image - use colorBlendMode for tinting if needed
                      AnimatedOpacity(
                        duration: const Duration(milliseconds: 200),
                        opacity: isSelected ? 1.0 : 0.8,
                        child: Image.asset(
                          lantern.imagePath,
                          width: size - 4,
                          height: size - 4,
                          fit: BoxFit.contain,
                          // Don't use color filter - let PNG transparency work
                          errorBuilder: (context, error, stackTrace) {
                            // Fallback to colored circle with emoji
                            return Container(
                              width: size - 4,
                              height: size - 4,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                gradient: RadialGradient(
                                  colors: [
                                    vividColor.withValues(alpha: 0.9),
                                    vividColor.withValues(alpha: 0.6),
                                  ],
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: vividColor.withValues(alpha: 0.5),
                                    blurRadius: 10,
                                    spreadRadius: 2,
                                  ),
                                ],
                              ),
                              child: Center(
                                child: Text(
                                  lantern.emoji,
                                  style: TextStyle(fontSize: size * 0.35),
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                      // Selection ring
                      if (isSelected)
                        Container(
                          width: size + 4,
                          height: size + 4,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: vividColor,
                              width: 3,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 4),
                // Lantern name - always visible
                Text(
                  lantern.name,
                  style: TextStyle(
                    fontSize: isSelected ? 12 : 10,
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                    color: isSelected ? vividColor : const Color(0xFF5D4037),
                  ),
                  textAlign: TextAlign.center,
                ),
                // Short magic description - always visible
                Text(
                  _shortMagic,
                  style: TextStyle(
                    fontSize: 9,
                    fontWeight: FontWeight.w400,
                    color: isSelected
                        ? vividColor.withValues(alpha: 0.8)
                        : const Color(0xFF8D6E63),
                    fontStyle: FontStyle.italic,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Expanded description showing the selected lantern's full magic text.
class _MoodDescription extends StatelessWidget {
  final MoodLantern lantern;

  const _MoodDescription({required this.lantern});

  @override
  Widget build(BuildContext context) {
    // More vivid color
    final vividColor = HSLColor.fromColor(lantern.color)
        .withSaturation(0.85)
        .withLightness(0.45)
        .toColor();

    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 300),
      transitionBuilder: (child, animation) {
        return FadeTransition(
          opacity: animation,
          child: SlideTransition(
            position: Tween<Offset>(
              begin: const Offset(0, 0.1),
              end: Offset.zero,
            ).animate(animation),
            child: child,
          ),
        );
      },
      child: Container(
        key: ValueKey(lantern.id),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        margin: const EdgeInsets.symmetric(horizontal: 8),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              vividColor.withValues(alpha: 0.15),
              vividColor.withValues(alpha: 0.08),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: vividColor.withValues(alpha: 0.5),
            width: 2,
          ),
          boxShadow: [
            BoxShadow(
              color: vividColor.withValues(alpha: 0.2),
              blurRadius: 15,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              lantern.emoji,
              style: const TextStyle(fontSize: 24),
            ),
            const SizedBox(width: 12),
            Flexible(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${lantern.name} Magic',
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: vividColor,
                        ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    lantern.storyMagic,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          fontStyle: FontStyle.italic,
                          color: const Color(0xFF5D4037),
                        ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
