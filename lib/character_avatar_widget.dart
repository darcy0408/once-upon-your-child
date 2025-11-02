// lib/character_avatar_widget.dart
// Visual avatar widget for characters based on their appearance

import 'package:flutter/material.dart';
import 'models.dart';

class CharacterAvatarWidget extends StatelessWidget {
  final Character character;
  final double size;

  const CharacterAvatarWidget({
    super.key,
    required this.character,
    this.size = 60,
  });

  Color _getSkinToneColor() {
    final skinTone = character.skinTone?.toLowerCase() ?? 'medium';

    switch (skinTone) {
      case 'very light':
      case 'fair':
        return const Color(0xFFFDE7D6);
      case 'light':
        return const Color(0xFFF7D5B7);
      case 'light-medium':
        return const Color(0xFFE8B896);
      case 'medium':
        return const Color(0xFFD19A6D);
      case 'medium-dark':
        return const Color(0xFFB57856);
      case 'dark':
        return const Color(0xFF8D5524);
      case 'very dark':
      case 'deep':
        return const Color(0xFF5C3317);
      default:
        return const Color(0xFFD19A6D);
    }
  }

  Color _getHairColor() {
    final hairColor = character.hair?.toLowerCase() ?? 'brown';

    switch (hairColor) {
      case 'black':
        return Colors.black87;
      case 'brown':
        return const Color(0xFF4A2511);
      case 'blonde':
        return const Color(0xFFFAD7A0);
      case 'red':
        return const Color(0xFFC04000);
      case 'auburn':
        return const Color(0xFF91473E);
      case 'gray':
      case 'grey':
        return Colors.grey.shade600;
      case 'colorful':
        return Colors.purpleAccent;
      default:
        return const Color(0xFF4A2511);
    }
  }

  IconData _getHairstyleIcon() {
    final hairstyle = character.hairstyle?.toLowerCase() ?? 'short';

    switch (hairstyle) {
      case 'curly':
        return Icons.water_drop; // Represents curls
      case 'braids':
        return Icons.format_line_spacing; // Represents braided pattern
      case 'ponytail':
        return Icons.arrow_upward; // Represents pulled up hair
      case 'buns':
        return Icons.circle; // Represents bun shape
      case 'afro':
        return Icons.cloud; // Represents fluffy afro
      case 'straight':
      case 'long':
      case 'short':
      default:
        return Icons.person;
    }
  }

  @override
  Widget build(BuildContext context) {
    final skinColor = _getSkinToneColor();
    final hairColor = _getHairColor();
    final hairstyleIcon = _getHairstyleIcon();

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(
          colors: [
            skinColor.withOpacity(0.8),
            skinColor,
          ],
        ),
        border: Border.all(
          color: hairColor,
          width: size / 15,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Center(
        child: Text(
          character.name.substring(0, 1).toUpperCase(),
          style: TextStyle(
            fontSize: size * 0.4,
            fontWeight: FontWeight.bold,
            color: Colors.black87,
          ),
        ),
      ),
    );
  }
}

// Enhanced avatar with full face representation
class CharacterAvatarEnhanced extends StatelessWidget {
  final Character character;
  final double size;

  const CharacterAvatarEnhanced({
    super.key,
    required this.character,
    this.size = 100,
  });

  Color _getSkinToneColor() {
    final skinTone = character.skinTone?.toLowerCase() ?? 'medium';

    switch (skinTone) {
      case 'very light':
      case 'fair':
        return const Color(0xFFFDE7D6);
      case 'light':
        return const Color(0xFFF7D5B7);
      case 'light-medium':
        return const Color(0xFFE8B896);
      case 'medium':
        return const Color(0xFFD19A6D);
      case 'medium-dark':
        return const Color(0xFFB57856);
      case 'dark':
        return const Color(0xFF8D5524);
      case 'very dark':
      case 'deep':
        return const Color(0xFF5C3317);
      default:
        return const Color(0xFFD19A6D);
    }
  }

  Color _getHairColor() {
    final hairColor = character.hair?.toLowerCase() ?? 'brown';

    switch (hairColor) {
      case 'black':
        return Colors.black87;
      case 'brown':
        return const Color(0xFF4A2511);
      case 'blonde':
        return const Color(0xFFFAD7A0);
      case 'red':
        return const Color(0xFFC04000);
      case 'auburn':
        return const Color(0xFF91473E);
      case 'gray':
      case 'grey':
        return Colors.grey.shade600;
      case 'colorful':
        return Colors.purpleAccent;
      default:
        return const Color(0xFF4A2511);
    }
  }

  Color _getEyeColor() {
    final eyeColor = character.eyes?.toLowerCase() ?? 'brown';

    switch (eyeColor) {
      case 'brown':
        return const Color(0xFF5C4033);
      case 'blue':
        return Colors.blue.shade700;
      case 'green':
        return Colors.green.shade700;
      case 'hazel':
        return const Color(0xFF8E7618);
      case 'gray':
      case 'grey':
        return Colors.grey.shade600;
      case 'amber':
        return const Color(0xFFFFBF00);
      default:
        return const Color(0xFF5C4033);
    }
  }

  @override
  Widget build(BuildContext context) {
    final skinColor = _getSkinToneColor();
    final hairColor = _getHairColor();
    final eyeColor = _getEyeColor();

    return Container(
      width: size,
      height: size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Face
          Container(
            width: size * 0.9,
            height: size * 0.9,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: skinColor,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.15),
                  blurRadius: 8,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
          ),

          // Hair (top)
          Positioned(
            top: 0,
            child: Container(
              width: size * 0.9,
              height: size * 0.4,
              decoration: BoxDecoration(
                color: hairColor,
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(size),
                  topRight: Radius.circular(size),
                ),
              ),
            ),
          ),

          // Eyes
          Positioned(
            top: size * 0.35,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: size * 0.12,
                  height: size * 0.12,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: eyeColor,
                  ),
                ),
                SizedBox(width: size * 0.15),
                Container(
                  width: size * 0.12,
                  height: size * 0.12,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: eyeColor,
                  ),
                ),
              ],
            ),
          ),

          // Smile
          Positioned(
            bottom: size * 0.25,
            child: Container(
              width: size * 0.3,
              height: size * 0.15,
              decoration: BoxDecoration(
                border: Border(
                  bottom: BorderSide(
                    color: Colors.black54,
                    width: size * 0.02,
                  ),
                ),
                borderRadius: BorderRadius.only(
                  bottomLeft: Radius.circular(size * 0.15),
                  bottomRight: Radius.circular(size * 0.15),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
