// lib/expressive_avatar_widget.dart
// Big expressive cartoon avatar for emotional learning
// 300x300 size with exaggerated features and animations

import 'package:flutter/material.dart';
import 'avatar_models.dart';
import 'feelings_wheel_data.dart';
import 'dart:math' as math;

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
  late AnimationController _controller;
  late Animation<double> _bounceAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    )..repeat(reverse: true);

    _bounceAnimation = Tween<double>(begin: 0, end: -10).animate(
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
    final skinColor = _getSkinColor();
    final hairColor = _getHairColor();

    return SizedBox(
      width: widget.size,
      height: widget.size + (widget.showLabel ? 50 : 0),
      child: Stack(
        alignment: Alignment.center,
        clipBehavior: Clip.none,
        children: [
          // Main avatar with better rendering
          Container(
            width: widget.size,
            height: widget.size,
            child: Stack(
              alignment: Alignment.center,
              children: [
                // Face circle
                Container(
                  width: widget.size * 0.85,
                  height: widget.size * 0.85,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: skinColor,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.15),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                ),

                // Hair (top)
                Positioned(
                  top: 0,
                  child: Container(
                    width: widget.size * 0.85,
                    height: widget.size * 0.45,
                    decoration: BoxDecoration(
                      color: hairColor,
                      borderRadius: BorderRadius.only(
                        topLeft: Radius.circular(widget.size),
                        topRight: Radius.circular(widget.size),
                      ),
                    ),
                  ),
                ),

                // Eyes
                Positioned(
                  top: widget.size * 0.32,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _buildEye(),
                      SizedBox(width: widget.size * 0.18),
                      _buildEye(),
                    ],
                  ),
                ),

                // Mouth
                Positioned(
                  bottom: widget.size * 0.22,
                  child: _buildMouth(),
                ),
              ],
            ),
          ),

          // Animated feeling emoji
          if (widget.feeling != null)
            AnimatedBuilder(
              animation: _bounceAnimation,
              builder: (context, child) {
                return Positioned(
                  top: 10 + _bounceAnimation.value,
                  child: Container(
                    width: 70,
                    height: 70,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: widget.feeling!.color.withOpacity(0.9),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.2),
                          blurRadius: 8,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Center(
                      child: Text(
                        widget.feeling!.emoji,
                        style: const TextStyle(fontSize: 35),
                      ),
                    ),
                  ),
                );
              },
            ),

          // Feeling label
          if (widget.showLabel && widget.feeling != null)
            Positioned(
              bottom: 0,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      const Color(0xFFFFD93D),
                      const Color(0xFFFFA94D),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(25),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.15),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Text(
                  widget.feeling!.tertiary,
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
              ),
            ),
        ],
      ),
    );
  }

  Color _getSkinColor() {
    final Map<String, Color> skinColors = {
      'PorcelainWhite': const Color(0xFFFFF5E6),
      'VeryPale': const Color(0xFFFFE8D1),
      'Light': const Color(0xFFFFDFC4),
      'Pale': const Color(0xFFF0C8A0),
      'Beige': const Color(0xFFEECBA8),
      'Tanned': const Color(0xFFE0AC7E),
      'Yellow': const Color(0xFFD49A6A),
      'Brown': const Color(0xFFC68642),
      'DarkBrown': const Color(0xFFA67C52),
      'Black': const Color(0xFF8D5524),
      'DeepBrown': const Color(0xFF6D4C41),
      'VeryDark': const Color(0xFF4A2C12),
    };
    return skinColors[widget.avatar.skinColor] ?? const Color(0xFFFFDFC4);
  }

  Color _getHairColor() {
    final Map<String, Color> hairColors = {
      'Blonde': const Color(0xFFF4D03F),
      'Brown': const Color(0xFF8B4513),
      'Black': const Color(0xFF2C3E50),
      'Red': const Color(0xFFC0392B),
      'Auburn': const Color(0xFFA04000),
      'PastelPink': const Color(0xFFFF6B9D),
      'BlondeGolden': const Color(0xFFFFD700),
      'SilverGray': const Color(0xFFBDC3C7),
      'Platinum': const Color(0xFFE8E8E8),
      'Blue': const Color(0xFF6495ED),
      'Purple': const Color(0xFF9B59B6),
    };
    return hairColors[widget.avatar.hairColor] ?? const Color(0xFF8B4513);
  }

  Widget _buildEye() {
    if (widget.avatar.eyeType == 'Happy') {
      // Happy curved eyes
      return Container(
        width: widget.size * 0.14,
        height: widget.size * 0.05,
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(
              color: const Color(0xFF2C3E50),
              width: widget.size * 0.01,
            ),
          ),
          borderRadius: BorderRadius.only(
            bottomLeft: Radius.circular(widget.size * 0.07),
            bottomRight: Radius.circular(widget.size * 0.07),
          ),
        ),
      );
    } else if (widget.avatar.eyeType == 'Surprised') {
      // Wide surprised eyes
      return Container(
        width: widget.size * 0.1,
        height: widget.size * 0.1,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: const Color(0xFF2C3E50),
        ),
        child: Center(
          child: Container(
            width: widget.size * 0.04,
            height: widget.size * 0.04,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white,
            ),
          ),
        ),
      );
    } else {
      // Default calm eyes
      return Container(
        width: widget.size * 0.07,
        height: widget.size * 0.07,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: const Color(0xFF2C3E50),
        ),
        child: Center(
          child: Container(
            width: widget.size * 0.02,
            height: widget.size * 0.02,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white,
            ),
          ),
        ),
      );
    }
  }

  Widget _buildMouth() {
    if (widget.avatar.mouthType == 'Smile') {
      // Smiling mouth
      return Container(
        width: widget.size * 0.35,
        height: widget.size * 0.15,
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(
              color: const Color(0xFF2C3E50),
              width: widget.size * 0.012,
            ),
          ),
          borderRadius: BorderRadius.only(
            bottomLeft: Radius.circular(widget.size * 0.18),
            bottomRight: Radius.circular(widget.size * 0.18),
          ),
        ),
      );
    } else if (widget.avatar.mouthType == 'Twinkle') {
      // Excited open mouth
      return Container(
        width: widget.size * 0.25,
        height: widget.size * 0.12,
        decoration: BoxDecoration(
          color: const Color(0xFFFF6B9D),
          borderRadius: BorderRadius.circular(widget.size * 0.06),
        ),
      );
    } else if (widget.avatar.mouthType == 'Concerned') {
      // Concerned frown
      return Container(
        width: widget.size * 0.3,
        height: widget.size * 0.12,
        decoration: BoxDecoration(
          border: Border(
            top: BorderSide(
              color: const Color(0xFF2C3E50),
              width: widget.size * 0.01,
            ),
          ),
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(widget.size * 0.15),
            topRight: Radius.circular(widget.size * 0.15),
          ),
        ),
      );
    } else {
      // Neutral mouth
      return Container(
        width: widget.size * 0.25,
        height: widget.size * 0.02,
        decoration: BoxDecoration(
          color: const Color(0xFF2C3E50),
          borderRadius: BorderRadius.circular(widget.size * 0.01),
        ),
      );
    }
  }
}
