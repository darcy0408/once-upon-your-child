// lib/data/mood_lantern_data.dart
/// Mood Lantern data for the enchanted shelf mood selector.
///
/// Each lantern represents a core emotion with magical framing.
/// Colors are inspired by chakra energy centers for a holistic feel.
/// This creates an immersive "picking a magic ingredient" experience
/// rather than a clinical emotion selection.
library;

import 'package:flutter/material.dart';
import '../feelings_wheel_data.dart';

/// Represents a single mood lantern on the enchanted shelf.
class MoodLantern {
  final String id;
  final String name;
  final String coreEmotion;
  final Color color;
  final String emoji;
  final String storyMagic;
  final String imagePath;

  const MoodLantern({
    required this.id,
    required this.name,
    required this.coreEmotion,
    required this.color,
    required this.emoji,
    required this.storyMagic,
    required this.imagePath,
  });

  /// Convert to SelectedFeeling for backend compatibility.
  /// Uses the same format the expanding feelings wheel outputs.
  SelectedFeeling toSelectedFeeling() => SelectedFeeling(
        core: coreEmotion,
        secondary: coreEmotion,
        tertiary: coreEmotion,
        emoji: emoji,
        eyeType: _eyeTypeForEmotion(coreEmotion),
        mouthType: _mouthTypeForEmotion(coreEmotion),
        color: color,
      );

  /// Get appropriate eye type for the emotion
  static String _eyeTypeForEmotion(String emotion) {
    switch (emotion.toLowerCase()) {
      case 'happy':
      case 'excited':
      case 'loved':
        return 'Happy';
      case 'sad':
      case 'fearful':
        return 'Dizzy';
      case 'angry':
        return 'EyeRoll';
      case 'surprised':
      case 'silly':
        return 'Surprised';
      default:
        return 'Default';
    }
  }

  /// Get appropriate mouth type for the emotion
  static String _mouthTypeForEmotion(String emotion) {
    switch (emotion.toLowerCase()) {
      case 'happy':
      case 'calm':
      case 'excited':
      case 'loved':
        return 'Smile';
      case 'sad':
      case 'fearful':
        return 'Concerned';
      case 'angry':
        return 'Serious';
      case 'silly':
        return 'Twinkle';
      default:
        return 'Default';
    }
  }
}

/// The 7 Mood Lanterns for the enchanted shelf.
///
/// Design philosophy: "Picking a magic ingredient" not "checking an emotion box"
/// Colors are inspired by the chakra system for a holistic, magical feel:
/// - Root (Red) -> Ember/Angry
/// - Sacral (Orange/Pink) -> Heartglow/Loved
/// - Solar Plexus (Yellow/Gold) -> Sunshine/Happy
/// - Heart (Green) -> Giggle/Silly
/// - Throat (Blue) -> Raindrop/Sad
/// - Third Eye (Cyan/Indigo) -> Dewdrop/Calm
/// - Crown (Violet/Purple) -> Moonbeam/Fearful
const List<MoodLantern> kMoodLanterns = [
  // Solar Plexus Chakra - Yellow/Gold - Personal Power & Joy
  MoodLantern(
    id: 'sunshine',
    name: 'Sunshine',
    coreEmotion: 'Happy',
    color: Color(0xFFFFB300), // Amber gold
    emoji: '☀️',
    storyMagic: 'Stories full of sunshine and smiles',
    imagePath: 'assets/mood_lanterns/sunshine.png',
  ),
  // Root Chakra - Red - Grounding & Strength
  MoodLantern(
    id: 'ember',
    name: 'Ember',
    coreEmotion: 'Angry',
    color: Color(0xFFE64A19), // Deep orange-red
    emoji: '🔥',
    storyMagic: 'Stories where heroes stand up for what\'s right',
    imagePath: 'assets/mood_lanterns/ember.png',
  ),
  // Throat Chakra - Blue - Expression & Truth
  MoodLantern(
    id: 'raindrop',
    name: 'Raindrop',
    coreEmotion: 'Sad',
    color: Color(0xFF1565C0), // Deep blue
    emoji: '💧',
    storyMagic: 'Stories with gentle comfort and understanding',
    imagePath: 'assets/mood_lanterns/raindrop.png',
  ),
  // Crown Chakra - Violet - Wisdom & Transcendence
  MoodLantern(
    id: 'moonbeam',
    name: 'Moonbeam',
    coreEmotion: 'Fearful',
    color: Color(0xFF7B1FA2), // Deep purple
    emoji: '🌙',
    storyMagic: 'Stories where courage conquers fear',
    imagePath: 'assets/mood_lanterns/moonbeam.png',
  ),
  // Heart Chakra - Green - Love & Connection
  MoodLantern(
    id: 'giggle',
    name: 'Giggle',
    coreEmotion: 'Silly',
    color: Color(0xFF2E7D32), // Forest green
    emoji: '🤭',
    storyMagic: 'Stories bursting with giggles and surprises',
    imagePath: 'assets/mood_lanterns/giggle.png',
  ),
  // Third Eye Chakra - Cyan/Indigo - Intuition & Peace
  MoodLantern(
    id: 'dewdrop',
    name: 'Dewdrop',
    coreEmotion: 'Calm',
    color: Color(0xFF00ACC1), // Cyan teal
    emoji: '🍃',
    storyMagic: 'Stories as peaceful as a quiet forest',
    imagePath: 'assets/mood_lanterns/dewdrop.png',
  ),
  // Sacral Chakra - Pink/Orange - Creativity & Passion
  MoodLantern(
    id: 'heartglow',
    name: 'Heartglow',
    coreEmotion: 'Excited',
    color: Color(0xFFE91E63), // Rose pink
    emoji: '💖',
    storyMagic: 'Stories full of adventure and discovery',
    imagePath: 'assets/mood_lanterns/heartglow.png',
  ),
];

/// Helper to find a lantern by ID.
MoodLantern? getLanternById(String id) {
  try {
    return kMoodLanterns.firstWhere((l) => l.id == id);
  } catch (_) {
    return null;
  }
}

/// Helper to find a lantern by core emotion.
MoodLantern? getLanternByEmotion(String emotion) {
  final lower = emotion.toLowerCase();
  for (final lantern in kMoodLanterns) {
    if (lantern.coreEmotion.toLowerCase() == lower) {
      return lantern;
    }
  }
  return null;
}
