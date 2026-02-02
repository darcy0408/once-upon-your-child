// lib/data/mood_vocab.dart
/// Mood Magic vocabulary with age-appropriate synonyms.
///
/// Each base mood has synonyms organized by age range:
/// - "young" (ages 3-6): Simple, concrete feeling words
/// - "middle" (ages 7-9): Expanded emotional vocabulary
/// - "older" (ages 10+): Nuanced emotional terms
///
/// This replaces the heavy 3-tier feelings wheel with a lighter
/// single-tap mood selection system.
library;


import 'package:flutter/material.dart';

/// Represents a single mood with its synonyms and visual styling.
class MoodEntry {
  final String id;
  final String baseName;
  final Color color;
  final String emoji;
  final List<String> youngSynonyms;
  final List<String> middleSynonyms;
  final List<String> olderSynonyms;

  const MoodEntry({
    required this.id,
    required this.baseName,
    required this.color,
    required this.emoji,
    required this.youngSynonyms,
    required this.middleSynonyms,
    required this.olderSynonyms,
  });

  /// Get synonyms appropriate for the given age.
  List<String> synonymsForAge(int age) {
    if (age <= 6) return youngSynonyms;
    if (age <= 9) return middleSynonyms;
    return olderSynonyms;
  }

  /// Get all synonyms (for search/filtering).
  List<String> get allSynonyms => [
        ...youngSynonyms,
        ...middleSynonyms,
        ...olderSynonyms,
      ];
}

/// The 6 base moods for Mood Magic.
///
/// Colors are chosen for good contrast and child-friendliness:
/// - Happy: Warm yellow/amber
/// - Sad: Cool blue
/// - Angry: Strong red
/// - Scared: Deep purple
/// - Calm: Soft green
/// - Surprised: Bright pink
const List<MoodEntry> moodVocabulary = [
  MoodEntry(
    id: 'happy',
    baseName: 'Happy',
    color: Color(0xFFFFA726), // Amber
    emoji: '😊',
    youngSynonyms: ['happy', 'glad', 'good', 'smiley'],
    middleSynonyms: ['joyful', 'excited', 'cheerful', 'proud', 'playful'],
    olderSynonyms: ['elated', 'content', 'optimistic', 'grateful', 'confident'],
  ),
  MoodEntry(
    id: 'sad',
    baseName: 'Sad',
    color: Color(0xFF5C6BC0), // Indigo
    emoji: '😢',
    youngSynonyms: ['sad', 'blue', 'down', 'teary'],
    middleSynonyms: ['upset', 'lonely', 'disappointed', 'hurt', 'left out'],
    olderSynonyms: ['melancholy', 'discouraged', 'vulnerable', 'grieving', 'heartbroken'],
  ),
  MoodEntry(
    id: 'angry',
    baseName: 'Angry',
    color: Color(0xFFEF5350), // Red
    emoji: '😠',
    youngSynonyms: ['mad', 'grumpy', 'cross', 'upset'],
    middleSynonyms: ['angry', 'frustrated', 'annoyed', 'bothered', 'cranky'],
    olderSynonyms: ['furious', 'irritated', 'resentful', 'bitter', 'indignant'],
  ),
  MoodEntry(
    id: 'scared',
    baseName: 'Scared',
    color: Color(0xFF7E57C2), // Deep Purple
    emoji: '😨',
    youngSynonyms: ['scared', 'afraid', 'shy', 'nervous'],
    middleSynonyms: ['worried', 'anxious', 'frightened', 'uneasy', 'tense'],
    olderSynonyms: ['terrified', 'panicked', 'insecure', 'overwhelmed', 'vulnerable'],
  ),
  MoodEntry(
    id: 'calm',
    baseName: 'Calm',
    color: Color(0xFF66BB6A), // Green
    emoji: '😌',
    youngSynonyms: ['calm', 'quiet', 'cozy', 'relaxed'],
    middleSynonyms: ['peaceful', 'content', 'comfortable', 'safe', 'mellow'],
    olderSynonyms: ['serene', 'tranquil', 'centered', 'composed', 'at ease'],
  ),
  MoodEntry(
    id: 'surprised',
    baseName: 'Surprised',
    color: Color(0xFFEC407A), // Pink
    emoji: '😮',
    youngSynonyms: ['surprised', 'wow', 'amazed', 'curious'],
    middleSynonyms: ['shocked', 'excited', 'confused', 'wondering', 'startled'],
    olderSynonyms: ['astonished', 'bewildered', 'awestruck', 'perplexed', 'intrigued'],
  ),
];

/// Helper to find a mood by ID.
MoodEntry? getMoodById(String id) {
  try {
    return moodVocabulary.firstWhere((m) => m.id == id);
  } catch (_) {
    return null;
  }
}

/// Helper to find a mood by any of its synonyms.
MoodEntry? getMoodBySynonym(String synonym) {
  final lower = synonym.toLowerCase();
  for (final mood in moodVocabulary) {
    if (mood.baseName.toLowerCase() == lower ||
        mood.allSynonyms.any((s) => s.toLowerCase() == lower)) {
      return mood;
    }
  }
  return null;
}
