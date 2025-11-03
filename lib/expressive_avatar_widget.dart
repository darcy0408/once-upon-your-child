// lib/expressive_avatar_widget.dart
// Animated avatar display that layers therapeutic feeling cues atop Avataaars art.

import 'package:flutter/material.dart';
import 'avatar_models.dart';
import 'customizable_avatar_widget.dart';
import 'feelings_wheel_data.dart';

class ExpressiveAvatarWidget extends StatefulWidget {
  final CharacterAvatar avatar;
  final SelectedFeeling? feeling;
  final double size;
  final bool showLabel;

  const ExpressiveAvatarWidget({
    super.key,
    required this.avatar,
    this.feeling,
    this.size = 300,
    this.showLabel = true,
  });

  @override
  State<ExpressiveAvatarWidget> createState() => _ExpressiveAvatarWidgetState();
}

class _ExpressiveAvatarWidgetState extends State<ExpressiveAvatarWidget>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _bounce;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2400),
    )..repeat(reverse: true);

    _bounce = Tween<double>(begin: 0, end: -12).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final feeling = widget.feeling;
    final showLabel = widget.showLabel && feeling != null;

    return SizedBox(
      width: widget.size,
      height: widget.size + (showLabel ? 56 : 0),
      child: Stack(
        alignment: Alignment.center,
        clipBehavior: Clip.none,
        children: [
          CustomizableAvatarWidget(
            avatar: widget.avatar,
            size: widget.size,
          ),
          if (feeling != null) ...[
            AnimatedBuilder(
              animation: _bounce,
              builder: (context, child) => Positioned(
                top: 12 + _bounce.value,
                child: _FeelingBadge(
                  emoji: feeling.emoji,
                  color: feeling.color,
                ),
              ),
            ),
            if (showLabel)
              Positioned(
                bottom: 0,
                child: _FeelingLabel(text: feeling.tertiary),
              ),
          ],
        ],
      ),
    );
  }
}

class _FeelingBadge extends StatelessWidget {
  final String emoji;
  final Color color;

  const _FeelingBadge({
    required this.emoji,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 74,
      height: 74,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: color.withOpacity(0.9),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.18),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      alignment: Alignment.center,
      child: Text(
        emoji,
        style: const TextStyle(fontSize: 36),
      ),
    );
  }
}

class _FeelingLabel extends StatelessWidget {
  final String text;

  const _FeelingLabel({required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFFFD93D), Color(0xFFFFA94D)],
        ),
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.18),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Text(
        text,
        style: const TextStyle(
          fontFamily: 'Quicksand',
          fontSize: 16,
          fontWeight: FontWeight.w700,
          color: Colors.white,
          shadows: [
            Shadow(
              color: Colors.black26,
              blurRadius: 4,
            ),
          ],
        ),
      ),
    );
  }
}
