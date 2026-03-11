// lib/widgets/mood_lantern_selector.dart
/// Mood Lantern Selector - An enchanted collection of floating lanterns
/// for children to choose their story's emotional ingredient.
///
/// Design philosophy: "Picking a magic ingredient" not "checking an emotion box"
///
/// Features:
/// - 7 beautiful lantern images with vivid chakra colors
/// - Animated glow effects for selected/unselected states
/// - Short magic description visible under each lantern
/// - Warm, inviting visual design with floating arrangement
library;

import 'package:flutter/material.dart';
import '../theme/age_band_theme.dart';
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
  /// The character's age, used to display age-appropriate content.
  /// Ages 10+ see mature variants (e.g., "Fury" instead of "Ember").
  final int age;

  const MoodLanternSelector({
    super.key,
    this.onFeelingSelected,
    this.initialLanternId,
    this.backgroundColor = const Color(0xFFFFF8E1), // Warm cream
    this.age = 8, // Default to middle-childhood
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
  late Listenable _combinedAnimation;

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

    // Cache the merged listenable once - don't recreate in build()
    _combinedAnimation = Listenable.merge([_glowAnimation, _idleAnimation]);
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
      animation: _combinedAnimation,
      builder: (context, child) {
        return SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Title
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text(
                  'Choose Your Story\'s Magic ✨',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: const Color(0xFF5D4037), // Warm brown
                        fontSize: 20,
                      ),
                  textAlign: TextAlign.center,
                ),
              ),

              // Subtitle instruction
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Text(
                  'Tap a lantern to pick the feeling for your adventure',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: const Color(0xFF795548),
                        fontStyle: FontStyle.italic,
                        fontSize: 13,
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
                age: widget.age,
              ),

              // Selected lantern expanded description
              if (_selectedLantern != null) ...[
                const SizedBox(height: 16),
                _MoodDescription(lantern: _selectedLantern!, age: widget.age),
              ],
            ],
          ),
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
  final int age;

  const _LanternGrid({
    required this.selectedLanternId,
    required this.glowIntensity,
    required this.idleIntensity,
    required this.onLanternTap,
    required this.age,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final availableWidth = constraints.maxWidth;

        // Calculate lanterns per row based on screen width
        // Very narrow (<300): 3, narrow (<450): 4, medium (<600): 5, wide: 7
        final int lanternsPerRow = availableWidth < 300
            ? 3
            : availableWidth < 450
                ? 4
                : availableWidth < 600
                    ? 5
                    : 7;

        // Each lantern widget needs: size + padding (16) for glow
        // Plus spacing between items (4px)
        // Total width per item = size + 16
        // Available = availableWidth - (spacing * (lanternsPerRow - 1))
        const double glowPadding = 16.0;
        const double spacing = 4.0;
        final double availableForLanterns =
            availableWidth - (spacing * (lanternsPerRow - 1));
        final double lanternSize =
            ((availableForLanterns / lanternsPerRow) - glowPadding)
                .clamp(40.0, 65.0);

        return Wrap(
          alignment: WrapAlignment.center,
          spacing: spacing,
          runSpacing: 16, // Reduced from 24 to save space
          children: kMoodLanterns.asMap().entries.map((entry) {
            final index = entry.key;
            final lantern = entry.value;
            final isSelected = selectedLanternId == lantern.id;
            
            // Floating effect: Stagger odd/even lanterns
            // Reduced stagger from 24 to 16 for better vertical economy
            final double topPadding = index.isEven ? 0.0 : 16.0;

            return Padding(
              padding: EdgeInsets.only(top: topPadding),
              child: _LanternWidget(
                lantern: lantern,
                isSelected: isSelected,
                glowIntensity: isSelected ? glowIntensity : idleIntensity,
                onTap: () => onLanternTap(lantern),
                size: lanternSize,
                age: age,
              ),
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
  final int age;

  const _LanternWidget({
    required this.lantern,
    required this.isSelected,
    required this.glowIntensity,
    required this.onTap,
    required this.age,
    this.size = 65,
  });

  /// Get a short magic label for the lantern (visible always)
  /// Uses age-appropriate variants for tweens/teens (10+)
  String get _shortMagic {
    // For ages 10+, use more mature short labels
    if (age >= 10) {
      switch (lantern.coreEmotion.toLowerCase()) {
        case 'happy':
          return 'Victory';
        case 'angry':
          return 'Justice';
        case 'sad':
          return 'Healing';
        case 'fearful':
          return 'Bravery';
        case 'silly':
          return 'Chaos';
        case 'calm':
          return 'Focus';
        case 'excited':
          return 'Thrill';
        default:
          return lantern.coreEmotion;
      }
    }
    // Default labels for younger children
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

    final band = ageBandFromAge(age);
    final showEmojiAnchor = band == AgeBand.sprout || band == AgeBand.explorer;

    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque, // Better hit testing
      child: Semantics(
        button: true,
        selected: isSelected,
        label: '${lantern.nameForAge(age)} lantern, ${lantern.storyMagicForAge(age)}',
        child: AnimatedScale(
          scale: isSelected ? (size < 50 ? 1.08 : 1.1) : 1.0, // Slightly more pronounced
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
                      // Outer glow effect - vivid color (smaller on narrow screens)
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
                                    ? 0.7 * glowIntensity // Increased alpha
                                    : 0.3 * glowIntensity,
                              ),
                              blurRadius: isSelected ? (size < 50 ? 18 : 24) : 10,
                              spreadRadius: isSelected ? (size < 50 ? 5 : 8) : 2,
                            ),
                          ],
                        ),
                      ),
                      // Lantern image - use colorBlendMode for tinting if needed
                      AnimatedOpacity(
                        duration: const Duration(milliseconds: 200),
                        opacity: isSelected ? 1.0 : 0.85,
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
                                    vividColor.withValues(alpha: 0.95),
                                    vividColor.withValues(alpha: 0.7),
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
                                  style: TextStyle(fontSize: size * 0.45), // Larger fallback emoji
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                      // Selection ring
                      if (isSelected)
                        Container(
                          width: size + 2,
                          height: size + 2,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: vividColor,
                              width: size < 50 ? 2 : 3, // Slightly thicker border
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 2),

                // P2-2: Emoji anchors for ages 5-7 (Sprout/Explorer)
                if (showEmojiAnchor)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 2),
                    child: Text(
                      lantern.emoji,
                      style: const TextStyle(fontSize: 18),
                      textAlign: TextAlign.center,
                    ),
                  ),

                // Lantern name - always visible, smaller on narrow screens
                Text(
                  lantern.nameForAge(age),
                  style: TextStyle(
                    fontSize: size < 50 ? 9.5 : (isSelected ? 11.5 : 10.5),
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.w700,
                    color: isSelected ? vividColor : const Color(0xFF5D4037),
                  ),
                  textAlign: TextAlign.center,
                  overflow: TextOverflow.ellipsis,
                  maxLines: 1,
                ),
                // Short magic description - hide on very small sizes
                if (size >= 48) // Lowered threshold slightly
                  Text(
                    _shortMagic,
                    style: TextStyle(
                      fontSize: 8.5,
                      fontWeight: FontWeight.w400,
                      color: isSelected
                          ? vividColor.withValues(alpha: 0.9)
                          : const Color(0xFF8D6E63),
                      fontStyle: FontStyle.italic,
                    ),
                    textAlign: TextAlign.center,
                    overflow: TextOverflow.ellipsis,
                    maxLines: 1,
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
  final int age;

  const _MoodDescription({required this.lantern, required this.age});

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
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        margin: const EdgeInsets.symmetric(horizontal: 4),
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
              style: const TextStyle(fontSize: 20),
            ),
            const SizedBox(width: 8),
            Flexible(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${lantern.nameForAge(age)} Magic',
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: vividColor,
                        ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    lantern.storyMagicForAge(age),
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
