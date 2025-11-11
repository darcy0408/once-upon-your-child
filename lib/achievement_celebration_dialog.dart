import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'models/achievement.dart';

class AchievementCelebrationDialog extends StatefulWidget {
  const AchievementCelebrationDialog({
    super.key,
    required this.achievements,
  });

  final List<AchievementProgress> achievements;

  static Future<void> show(
    BuildContext context,
    List<AchievementProgress> achievements,
  ) {
    if (achievements.isEmpty) return Future.value();

    return showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => AchievementCelebrationDialog(achievements: achievements),
    );
  }

  @override
  State<AchievementCelebrationDialog> createState() =>
      _AchievementCelebrationDialogState();
}

class _AchievementCelebrationDialogState
    extends State<AchievementCelebrationDialog>
    with SingleTickerProviderStateMixin {
  late final PageController _pageController;
  late final AnimationController _animationController;

  int _currentPage = 0;

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _animationController.dispose();
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
      child: Stack(
        alignment: Alignment.center,
        children: [
          _buildGlowBackdrop(),
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  theme.colorScheme.surface.withValues(alpha: 0.95),
                  theme.colorScheme.primary.withValues(alpha: 0.12),
                ],
              ),
              borderRadius: BorderRadius.circular(28),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.25),
                  blurRadius: 32,
                  offset: const Offset(0, 12),
                ),
              ],
            ),
            padding: const EdgeInsets.fromLTRB(24, 28, 24, 16),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 400, maxHeight: 600),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text(
                      'Achievement Unlocked!',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.6,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      widget.achievements.length == 1
                          ? 'You earned a new badge.'
                          : 'You earned ${widget.achievements.length} new badges!',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color:
                            theme.colorScheme.onSurface.withValues(alpha: 0.8),
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 24),
                    SizedBox(
                      height: 220,
                      child: PageView.builder(
                        controller: _pageController,
                        itemCount: widget.achievements.length,
                        onPageChanged: (value) {
                          setState(() => _currentPage = value);
                        },
                        itemBuilder: (context, index) {
                          final progress = widget.achievements[index];
                          return _AchievementSlide(
                            progress: progress,
                            animation: CurvedAnimation(
                              parent: _animationController,
                              curve: Curves.easeInOut,
                            ),
                          );
                        },
                      ),
                    ),
                    const SizedBox(height: 16),
                    if (widget.achievements.length > 1)
                      _PageDots(
                        count: widget.achievements.length,
                        activeIndex: _currentPage,
                      ),
                    const SizedBox(height: 20),
                    ElevatedButton(
                      onPressed: () => Navigator.of(context).pop(),
                      style: ElevatedButton.styleFrom(
                        minimumSize: const Size(180, 48),
                        backgroundColor: theme.colorScheme.primary,
                        foregroundColor: theme.colorScheme.onPrimary,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      child: const Text(
                        'Keep Going!',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          _buildSparkleLayer(),
        ],
      ),
    );
  }

  Widget _buildGlowBackdrop() {
    return AnimatedBuilder(
      animation: _animationController,
      builder: (context, child) {
        final t = _animationController.value;
        final scale = 1.0 + 0.05 * math.sin(t * math.pi * 2);
        return Transform.scale(
          scale: scale,
          child: Container(
            width: 260,
            height: 260,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: [
                  Colors.white.withValues(alpha: 0.35),
                  Colors.transparent,
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildSparkleLayer() {
    return IgnorePointer(
      child: AnimatedBuilder(
        animation: _animationController,
        builder: (context, child) {
          final t = _animationController.value;
          final opacity = 0.35 + (math.sin(t * math.pi * 2) + 1) * 0.25;
          return Opacity(
            opacity: opacity.clamp(0.2, 0.9),
            child: child,
          );
        },
        child: SizedBox(
          width: 300,
          height: 300,
          child: Stack(
            children: const [
              _Sparkle(offset: Offset(-90, -60), size: 36),
              _Sparkle(offset: Offset(100, -80), size: 28),
              _Sparkle(offset: Offset(-110, 80), size: 24),
              _Sparkle(offset: Offset(120, 70), size: 34),
              _Sparkle(offset: Offset(0, -120), size: 30),
            ],
          ),
        ),
      ),
    );
  }
}

class _AchievementSlide extends StatelessWidget {
  const _AchievementSlide({
    required this.progress,
    required this.animation,
  });

  final AchievementProgress progress;
  final Animation<double> animation;

  @override
  Widget build(BuildContext context) {
    final achievement = progress.achievement;
    final rarityColor = achievement.rarityColor;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Stack(
          clipBehavior: Clip.none,
          children: [
            ScaleTransition(
              scale: Tween<double>(begin: 0.92, end: 1.0).animate(animation),
              child: Container(
                width: 160,
                height: 160,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    colors: [
                      rarityColor.withValues(alpha: 0.85),
                      rarityColor.withValues(alpha: 0.55),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: rarityColor.withValues(alpha: 0.4),
                      blurRadius: 25,
                      offset: const Offset(0, 12),
                    ),
                  ],
                ),
                child: Center(
                  child: Icon(
                    achievement.icon,
                    size: 72,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
            Positioned(
              top: -6,
              right: -6,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.redAccent,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.redAccent.withValues(alpha: 0.45),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: const Text(
                  'NEW',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.8,
                  ),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 18),
        Text(
          achievement.name,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 8),
        _RarityBadge(rarity: achievement.rarity),
        const SizedBox(height: 12),
        Text(
          achievement.description,
          style: TextStyle(
            color: Theme.of(context)
                .colorScheme
                .onSurface
                .withValues(alpha: 0.75),
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }
}

class _PageDots extends StatelessWidget {
  const _PageDots({
    required this.count,
    required this.activeIndex,
  });

  final int count;
  final int activeIndex;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(
        count,
        (index) {
          final isActive = index == activeIndex;
          return AnimatedContainer(
            duration: const Duration(milliseconds: 250),
            margin: const EdgeInsets.symmetric(horizontal: 4),
            height: 8,
            width: isActive ? 20 : 8,
            decoration: BoxDecoration(
              color: isActive
                  ? Theme.of(context).colorScheme.primary
                  : Theme.of(context)
                      .colorScheme
                      .primary
                      .withValues(alpha: 0.3),
              borderRadius: BorderRadius.circular(12),
            ),
          );
        },
      ),
    );
  }
}

class _RarityBadge extends StatelessWidget {
  const _RarityBadge({required this.rarity});

  final AchievementRarity rarity;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        color: rarity.color.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: rarity.color.withValues(alpha: 0.5)),
      ),
      child: Text(
        rarity.label,
        style: TextStyle(
          fontWeight: FontWeight.w600,
          color: rarity.color.darken(0.1),
        ),
      ),
    );
  }
}

class _Sparkle extends StatelessWidget {
  const _Sparkle({
    required this.offset,
    required this.size,
  });

  final Offset offset;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Positioned(
      left: 150 + offset.dx,
      top: 150 + offset.dy,
      child: Icon(
        Icons.auto_awesome,
        size: size,
        color: Colors.white.withValues(alpha: 0.35),
      ),
    );
  }
}

extension on Color {
  Color darken(double amount) {
    final hsl = HSLColor.fromColor(this);
    final adjusted = hsl.withLightness(
      (hsl.lightness - amount).clamp(0.0, 1.0),
    );
    return adjusted.toColor();
  }
}
