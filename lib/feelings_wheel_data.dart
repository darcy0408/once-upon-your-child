// lib/feelings_wheel_data.dart
// Feelings Wheel Data Structure for Flutter
// Cross-platform compatible with React web app

import 'package:flutter/material.dart';

class Feeling {
  final String id;
  final String name;
  final String emoji;
  final String eyeType;
  final String mouthType;
  final Color? color;

  const Feeling({
    required this.id,
    required this.name,
    required this.emoji,
    required this.eyeType,
    required this.mouthType,
    this.color,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'emoji': emoji,
        'eyeType': eyeType,
        'mouthType': mouthType,
      };
}

class SecondaryFeeling extends Feeling {
  final List<String> tertiary;

  const SecondaryFeeling({
    required super.id,
    required super.name,
    required super.emoji,
    required super.eyeType,
    required super.mouthType,
    required this.tertiary,
  });
}

class CoreEmotion extends Feeling {
  final List<SecondaryFeeling> secondary;

  const CoreEmotion({
    required super.id,
    required super.name,
    required super.emoji,
    required super.eyeType,
    required super.mouthType,
    required super.color,
    required this.secondary,
  });
}

class SelectedFeeling {
  final String core;
  final String secondary;
  final String tertiary;
  final String emoji;
  final String eyeType;
  final String mouthType;
  final Color color;

  const SelectedFeeling({
    required this.core,
    required this.secondary,
    required this.tertiary,
    required this.emoji,
    required this.eyeType,
    required this.mouthType,
    required this.color,
  });

  Map<String, dynamic> toJson() => {
        'core': core,
        'secondary': secondary,
        'tertiary': tertiary,
        'emoji': emoji,
        'eyeType': eyeType,
        'mouthType': mouthType,
        'color': '#${color.value.toRadixString(16).substring(2)}',
      };

  factory SelectedFeeling.fromJson(Map<String, dynamic> json) {
    return SelectedFeeling(
      core: json['core'] ?? '',
      secondary: json['secondary'] ?? '',
      tertiary: json['tertiary'] ?? '',
      emoji: json['emoji'] ?? '',
      eyeType: json['eyeType'] ?? 'Happy',
      mouthType: json['mouthType'] ?? 'Smile',
      color: _parseColor(json['color']),
    );
  }

  static Color _parseColor(String? colorString) {
    if (colorString == null) return const Color(0xFFFFD93D);
    final hex = colorString.replaceAll('#', '');
    return Color(int.parse('FF$hex', radix: 16));
  }
}

// Feelings Wheel Data
class FeelingsWheelData {
  static const List<CoreEmotion> coreEmotions = [
    CoreEmotion(
      id: 'happy',
      name: 'Happy',
      color: Color(0xFFFFD93D),
      emoji: '😊',
      eyeType: 'Happy',
      mouthType: 'Smile',
      secondary: [
        SecondaryFeeling(
          id: 'joyful',
          name: 'Joyful',
          emoji: '😄',
          eyeType: 'Happy',
          mouthType: 'Twinkle',
          tertiary: ['Excited', 'Cheerful', 'Playful', 'Energetic'],
        ),
        SecondaryFeeling(
          id: 'content',
          name: 'Content',
          emoji: '😌',
          eyeType: 'Default',
          mouthType: 'Smile',
          tertiary: ['Calm', 'Peaceful', 'Relaxed', 'Satisfied'],
        ),
        SecondaryFeeling(
          id: 'proud',
          name: 'Proud',
          emoji: '😊',
          eyeType: 'Happy',
          mouthType: 'Smile',
          tertiary: ['Confident', 'Strong', 'Capable', 'Brave'],
        ),
      ],
    ),
    CoreEmotion(
      id: 'sad',
      name: 'Sad',
      color: Color(0xFF6495ED),
      emoji: '😢',
      eyeType: 'Dizzy',
      mouthType: 'Concerned',
      secondary: [
        SecondaryFeeling(
          id: 'lonely',
          name: 'Lonely',
          emoji: '😔',
          eyeType: 'Dizzy',
          mouthType: 'Concerned',
          tertiary: ['Left out', 'Forgotten', 'Alone', 'Isolated'],
        ),
        SecondaryFeeling(
          id: 'hurt',
          name: 'Hurt',
          emoji: '😢',
          eyeType: 'Dizzy',
          mouthType: 'Concerned',
          tertiary: ['Disappointed', 'Let down', 'Upset', 'Heartbroken'],
        ),
        SecondaryFeeling(
          id: 'worried',
          name: 'Worried',
          emoji: '😟',
          eyeType: 'Surprised',
          mouthType: 'Concerned',
          tertiary: ['Nervous', 'Anxious', 'Stressed', 'Uneasy'],
        ),
      ],
    ),
    CoreEmotion(
      id: 'angry',
      name: 'Angry',
      color: Color(0xFFFF6B6B),
      emoji: '😠',
      eyeType: 'EyeRoll',
      mouthType: 'Serious',
      secondary: [
        SecondaryFeeling(
          id: 'frustrated',
          name: 'Frustrated',
          emoji: '😤',
          eyeType: 'EyeRoll',
          mouthType: 'Serious',
          tertiary: ['Annoyed', 'Bothered', 'Irritated', 'Impatient'],
        ),
        SecondaryFeeling(
          id: 'mad',
          name: 'Mad',
          emoji: '😡',
          eyeType: 'EyeRoll',
          mouthType: 'Serious',
          tertiary: ['Furious', 'Outraged', 'Livid', 'Explosive'],
        ),
        SecondaryFeeling(
          id: 'jealous',
          name: 'Jealous',
          emoji: '😒',
          eyeType: 'EyeRoll',
          mouthType: 'Concerned',
          tertiary: ['Envious', 'Resentful', 'Left out', 'Wanting'],
        ),
      ],
    ),
    CoreEmotion(
      id: 'scared',
      name: 'Scared',
      color: Color(0xFF9B59B6),
      emoji: '😨',
      eyeType: 'Surprised',
      mouthType: 'Concerned',
      secondary: [
        SecondaryFeeling(
          id: 'afraid',
          name: 'Afraid',
          emoji: '😰',
          eyeType: 'Surprised',
          mouthType: 'Concerned',
          tertiary: ['Frightened', 'Terrified', 'Panicked', 'Alarmed'],
        ),
        SecondaryFeeling(
          id: 'nervous',
          name: 'Nervous',
          emoji: '😬',
          eyeType: 'Surprised',
          mouthType: 'Concerned',
          tertiary: ['Worried', 'Anxious', 'Jittery', 'Tense'],
        ),
        SecondaryFeeling(
          id: 'confused',
          name: 'Confused',
          emoji: '😕',
          eyeType: 'Surprised',
          mouthType: 'Default',
          tertiary: ['Uncertain', 'Unsure', 'Puzzled', 'Lost'],
        ),
      ],
    ),
    CoreEmotion(
      id: 'surprised',
      name: 'Surprised',
      color: Color(0xFFFF9FF3),
      emoji: '😮',
      eyeType: 'Surprised',
      mouthType: 'Default',
      secondary: [
        SecondaryFeeling(
          id: 'amazed',
          name: 'Amazed',
          emoji: '😲',
          eyeType: 'Surprised',
          mouthType: 'Twinkle',
          tertiary: ['Astonished', 'Shocked', 'Stunned', 'Wow'],
        ),
        SecondaryFeeling(
          id: 'excited',
          name: 'Excited',
          emoji: '🤩',
          eyeType: 'Happy',
          mouthType: 'Twinkle',
          tertiary: ['Thrilled', 'Eager', 'Pumped', 'Energized'],
        ),
      ],
    ),
    CoreEmotion(
      id: 'disgusted',
      name: 'Disgusted',
      color: Color(0xFF7CB342),
      emoji: '🤢',
      eyeType: 'EyeRoll',
      mouthType: 'Concerned',
      secondary: [
        SecondaryFeeling(
          id: 'grossed-out',
          name: 'Grossed Out',
          emoji: '🤮',
          eyeType: 'EyeRoll',
          mouthType: 'Concerned',
          tertiary: ['Yucky', 'Icky', 'Nasty', 'Eww'],
        ),
        SecondaryFeeling(
          id: 'uncomfortable',
          name: 'Uncomfortable',
          emoji: '😣',
          eyeType: 'Default',
          mouthType: 'Concerned',
          tertiary: ['Awkward', 'Uneasy', 'Weird', 'Off'],
        ),
      ],
    ),
  ];

  // Helper method to get all feelings as flat list
  static List<Map<String, dynamic>> getAllFeelings() {
    List<Map<String, dynamic>> feelings = [];

    for (var core in coreEmotions) {
      feelings.add({
        'level': 'core',
        'id': core.id,
        'name': core.name,
        'emoji': core.emoji,
        'color': core.color,
        'eyeType': core.eyeType,
        'mouthType': core.mouthType,
      });

      for (var secondary in core.secondary) {
        feelings.add({
          'level': 'secondary',
          'coreId': core.id,
          'coreColor': core.color,
          'id': secondary.id,
          'name': secondary.name,
          'emoji': secondary.emoji,
          'eyeType': secondary.eyeType,
          'mouthType': secondary.mouthType,
        });

        for (var tertiary in secondary.tertiary) {
          feelings.add({
            'level': 'tertiary',
            'coreId': core.id,
            'coreColor': core.color,
            'secondaryId': secondary.id,
            'name': tertiary,
            'eyeType': secondary.eyeType,
            'mouthType': secondary.mouthType,
          });
        }
      }
    }

    return feelings;
  }

  // Get feeling by name
  static Map<String, dynamic>? getFeelingByName(String name) {
    return getAllFeelings().firstWhere(
      (f) => f['name'].toString().toLowerCase() == name.toLowerCase(),
      orElse: () => {},
    );
  }
}
