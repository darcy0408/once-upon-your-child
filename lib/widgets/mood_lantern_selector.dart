// lib/widgets/mood_lantern_selector.dart
/// Mood Lantern Selector - An enchanted shelf of glowing lanterns
/// for children to choose their story's emotional ingredient.
///
/// Design philosophy: "Picking a magic ingredient" not "checking an emotion box"
///
/// Features:
/// - 7 beautiful lantern images on an enchanted wooden shelf
/// - Animated glow effects for selected/unselected states
/// - Environment color tint that responds to selection
/// - Magical story framing text for each mood
library;

import 'package:flutter/material.dart';
import '../data/mood_lantern_data.dart';
import '../feelings_wheel_data.dart';

/// Callback type for lantern selection.
typedef OnLanternSelected = void Function(SelectedFeeling feeling);

/// Main Mood Lantern Selector widget.
///
/// Displays an enchanted shelf with 7 glowing lanterns.
/// Tap a lantern to select that mood for the story.
class MoodLanternSelector extends StatefulWidget {
  final OnLanternSelected? onFeelingSelected;
  final String? initialLanternId;
  final Color backgroundColor;

  const MoodLanternSelector({
    super.key,
    this.onFeelingSelected,
    this.initialLanternId,
    this.backgroundColor = const Color(0xFFF5E6D3),
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
              padding: const EdgeInsets.only(bottom: 16),
              child: Text(
                'Choose Your Story\'s Magic',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: const Color(0xFF4A3728),
                    ),
                textAlign: TextAlign.center,
              ),
            ),

            // Environment with color tint
            _EnvironmentContainer(
              selectedLantern: _selectedLantern,
              backgroundColor: widget.backgroundColor,
              child: _LanternShelf(
                selectedLanternId: _selectedLanternId,
                glowIntensity: _glowAnimation.value,
                idleIntensity: _idleAnimation.value,
                onLanternTap: _selectLantern,
              ),
            ),

            // Selected lantern description
            if (_selectedLantern != null) ...[
              const SizedBox(height: 20),
              _MoodDescription(lantern: _selectedLantern!),
            ],
          ],
        );
      },
    );
  }
}

/// Environment container with animated color tint.
class _EnvironmentContainer extends StatelessWidget {
  final MoodLantern? selectedLantern;
  final Color backgroundColor;
  final Widget child;

  const _EnvironmentContainer({
    required this.selectedLantern,
    required this.backgroundColor,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    final tintColor = selectedLantern?.color ?? backgroundColor;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 500),
      curve: Curves.easeOut,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: RadialGradient(
          center: Alignment.center,
          radius: 1.2,
          colors: [
            tintColor.withValues(alpha: 0.2),
            backgroundColor.withValues(alpha: 0.9),
            Colors.black.withValues(alpha: 0.15),
          ],
          stops: const [0.0, 0.6, 1.0],
        ),
        boxShadow: [
          BoxShadow(
            color: tintColor.withValues(alpha: 0.3),
            blurRadius: 30,
            spreadRadius: 5,
          ),
        ],
      ),
      child: child,
    );
  }
}

/// The shelf holding the lanterns - responsive layout.
class _LanternShelf extends StatelessWidget {
  final String? selectedLanternId;
  final double glowIntensity;
  final double idleIntensity;
  final ValueChanged<MoodLantern> onLanternTap;

  const _LanternShelf({
    required this.selectedLanternId,
    required this.glowIntensity,
    required this.idleIntensity,
    required this.onLanternTap,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        // Calculate layout based on available width
        final availableWidth = constraints.maxWidth;

        // For narrow screens, use 2 rows
        if (availableWidth < 500) {
          return _buildTwoRowLayout();
        }

        // For wider screens, single row with wrapping
        return _buildSingleRowLayout();
      },
    );
  }

  Widget _buildSingleRowLayout() {
    return Wrap(
      alignment: WrapAlignment.center,
      spacing: 8,
      runSpacing: 16,
      children: kMoodLanterns.map((lantern) {
        final isSelected = selectedLanternId == lantern.id;
        return _LanternWidget(
          lantern: lantern,
          isSelected: isSelected,
          glowIntensity: isSelected ? glowIntensity : idleIntensity,
          onTap: () => onLanternTap(lantern),
        );
      }).toList(),
    );
  }

  Widget _buildTwoRowLayout() {
    // Split lanterns into two rows: 4 and 3
    final firstRow = kMoodLanterns.take(4).toList();
    final secondRow = kMoodLanterns.skip(4).toList();

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // First row
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: firstRow.map((lantern) {
            final isSelected = selectedLanternId == lantern.id;
            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: _LanternWidget(
                lantern: lantern,
                isSelected: isSelected,
                glowIntensity: isSelected ? glowIntensity : idleIntensity,
                onTap: () => onLanternTap(lantern),
                size: 70,
              ),
            );
          }).toList(),
        ),
        const SizedBox(height: 12),
        // Second row
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: secondRow.map((lantern) {
            final isSelected = selectedLanternId == lantern.id;
            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: _LanternWidget(
                lantern: lantern,
                isSelected: isSelected,
                glowIntensity: isSelected ? glowIntensity : idleIntensity,
                onTap: () => onLanternTap(lantern),
                size: 70,
              ),
            );
          }).toList(),
        ),
      ],
    );
  }
}

/// Individual lantern widget with image and glow animation.
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
    this.size = 80,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Semantics(
        button: true,
        selected: isSelected,
        label: '${lantern.name} lantern, ${lantern.storyMagic}',
        child: AnimatedScale(
          scale: isSelected ? 1.12 : 1.0,
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOutBack,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Lantern with glow
              Stack(
                alignment: Alignment.center,
                children: [
                  // Outer glow effect
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 300),
                    width: size + 20,
                    height: size + 20,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: lantern.color.withValues(
                            alpha: isSelected
                                ? 0.6 * glowIntensity
                                : 0.2 * glowIntensity,
                          ),
                          blurRadius: isSelected ? 30 : 15,
                          spreadRadius: isSelected ? 10 : 3,
                        ),
                      ],
                    ),
                  ),
                  // Lantern image
                  AnimatedOpacity(
                    duration: const Duration(milliseconds: 200),
                    opacity: isSelected ? 1.0 : 0.75 * glowIntensity,
                    child: Image.asset(
                      lantern.imagePath,
                      width: size,
                      height: size,
                      fit: BoxFit.contain,
                      errorBuilder: (context, error, stackTrace) {
                        // Fallback to emoji if image fails
                        return Container(
                          width: size,
                          height: size,
                          decoration: BoxDecoration(
                            color: lantern.color.withValues(alpha: 0.3),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Center(
                            child: Text(
                              lantern.emoji,
                              style: TextStyle(fontSize: size * 0.4),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                  // Selection indicator ring
                  if (isSelected)
                    Container(
                      width: size + 8,
                      height: size + 8,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: lantern.color,
                          width: 3,
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 6),
              // Lantern name
              AnimatedDefaultTextStyle(
                duration: const Duration(milliseconds: 200),
                style: TextStyle(
                  fontSize: isSelected ? 13 : 11,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                  color: isSelected
                      ? lantern.color
                      : const Color(0xFF5D4037),
                ),
                child: Text(lantern.name),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Text description showing the selected lantern's magic.
class _MoodDescription extends StatelessWidget {
  final MoodLantern lantern;

  const _MoodDescription({required this.lantern});

  @override
  Widget build(BuildContext context) {
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
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        decoration: BoxDecoration(
          color: lantern.color.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: lantern.color.withValues(alpha: 0.4),
            width: 2,
          ),
          boxShadow: [
            BoxShadow(
              color: lantern.color.withValues(alpha: 0.15),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  lantern.emoji,
                  style: const TextStyle(fontSize: 28),
                ),
                const SizedBox(width: 12),
                Text(
                  '${lantern.name} Magic',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: lantern.color,
                      ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              lantern.storyMagic,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    fontStyle: FontStyle.italic,
                    color: Colors.black87,
                  ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
