// lib/emotion_avatar_widget.dart
// Simple emoji-based avatar that changes expression based on emotion

import 'package:flutter/material.dart';
import 'emotion_models.dart';

class EmotionAvatarWidget extends StatelessWidget {
  final EmotionState? emotionState;
  final double size;
  final String? characterName;

  const EmotionAvatarWidget({
    super.key,
    this.emotionState,
    this.size = 120,
    this.characterName,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: _getBackgroundGradient(),
        ),
        border: Border.all(
          color: const Color(0xFF4a9d6a),
          width: 3,
        ),
        boxShadow: [
          BoxShadow(
            color: _getBackgroundGradient().first.withOpacity(0.3),
            blurRadius: 12,
            spreadRadius: 2,
          ),
        ],
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Emoji face showing current emotion
          Text(
            _getEmotionEmoji(),
            style: TextStyle(fontSize: size * 0.5),
          ),
          if (characterName != null) ...[
            SizedBox(height: size * 0.05),
            Text(
              characterName!,
              style: TextStyle(
                fontSize: size * 0.12,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ],
      ),
    );
  }

  List<Color> _getBackgroundGradient() {
    if (emotionState == null) {
      return [
        const Color(0xFF6b8f7a),
        const Color(0xFF4a9d6a),
      ];
    }

    switch (emotionState!.core) {
      case CoreEmotion.joy:
        return [const Color(0xFFfbbf24), const Color(0xFFf59e0b)]; // Yellow/gold
      case CoreEmotion.love:
        return [const Color(0xFFec4899), const Color(0xFFdb2777)]; // Pink
      case CoreEmotion.surprise:
        return [const Color(0xFF8b5cf6), const Color(0xFF7c3aed)]; // Purple
      case CoreEmotion.sadness:
        return [const Color(0xFF60a5fa), const Color(0xFF3b82f6)]; // Blue
      case CoreEmotion.fear:
        return [const Color(0xFF9ca3af), const Color(0xFF6b7280)]; // Gray
      case CoreEmotion.anger:
        return [const Color(0xFFf87171), const Color(0xFFef4444)]; // Red
    }
  }

  String _getEmotionEmoji() {
    if (emotionState == null) {
      return '😊'; // Default neutral/happy
    }

    // Return the specific emotion emoji from the feelings wheel
    final specifics = FeelingsWheel.getSpecificEmotions(emotionState!.core);
    final specific = specifics.firstWhere(
      (e) => e.name == emotionState!.specific,
      orElse: () => specifics.first,
    );

    return specific.emoji;
  }
}

/// Compact version for lists
class EmotionAvatarCompact extends StatelessWidget {
  final EmotionState? emotionState;
  final String? characterName;

  const EmotionAvatarCompact({
    super.key,
    this.emotionState,
    this.characterName,
  });

  @override
  Widget build(BuildContext context) {
    return EmotionAvatarWidget(
      emotionState: emotionState,
      size: 60,
      characterName: null, // No name in compact version
    );
  }
}

/// Large version for profile/detail screens
class EmotionAvatarLarge extends StatelessWidget {
  final EmotionState? emotionState;
  final String? characterName;
  final VoidCallback? onTap;

  const EmotionAvatarLarge({
    super.key,
    this.emotionState,
    this.characterName,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final avatar = EmotionAvatarWidget(
      emotionState: emotionState,
      size: 150,
      characterName: characterName,
    );

    if (onTap != null) {
      return GestureDetector(
        onTap: onTap,
        child: avatar,
      );
    }

    return avatar;
  }
}

/// Info card showing current feeling
class CurrentEmotionCard extends StatelessWidget {
  final EmotionState emotionState;

  const CurrentEmotionCard({
    super.key,
    required this.emotionState,
  });

  @override
  Widget build(BuildContext context) {
    final specifics = FeelingsWheel.getSpecificEmotions(emotionState.core);
    final specific = specifics.firstWhere(
      (e) => e.name == emotionState.specific,
      orElse: () => specifics.first,
    );

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1a2f1f),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: const Color(0xFF4a9d6a),
          width: 2,
        ),
      ),
      child: Row(
        children: [
          // Emoji
          Text(
            specific.emoji,
            style: const TextStyle(fontSize: 48),
          ),
          const SizedBox(width: 16),

          // Text
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Current Feeling:',
                  style: TextStyle(
                    fontSize: 14,
                    color: Color(0xFFa8d5ba),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  emotionState.specific,
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF7fd3a8),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  emotionState.core.displayName,
                  style: const TextStyle(
                    fontSize: 14,
                    color: Color(0xFFa8d5ba),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
