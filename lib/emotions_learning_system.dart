// lib/emotions_learning_system.dart

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Emotion categories for kids to learn
enum EmotionCategory {
  happy,      // Joy, excited, proud, grateful
  sad,        // Disappointed, lonely, hurt
  angry,      // Frustrated, annoyed, furious
  scared,     // Worried, nervous, afraid
  surprised,  // Amazed, shocked, confused
  calm,       // Peaceful, relaxed, content
  mixed,      // Conflicted, overwhelmed
}

/// Individual emotion with teaching info
class Emotion {
  final String id;
  final String name;
  final String emoji;
  final EmotionCategory category;
  final String description;
  final String physicalSigns; // "Your heart beats fast, hands shake"
  final List<String> copingStrategies;
  final String colorHex;
  final int intensityLevel; // 1-5 (1 = mild, 5 = intense)

  const Emotion({
    required this.id,
    required this.name,
    required this.emoji,
    required this.category,
    required this.description,
    required this.physicalSigns,
    required this.copingStrategies,
    required this.colorHex,
    this.intensityLevel = 3,
  });

  Color get color => Color(int.parse(colorHex.substring(1), radix: 16) + 0xFF000000);
}

/// How a character felt in a story moment
class EmotionMoment {
  final String emotion;
  final String situation;
  final String copingStrategy;
  final DateTime timestamp;

  EmotionMoment({
    required this.emotion,
    required this.situation,
    required this.copingStrategy,
    required this.timestamp,
  });

  Map<String, dynamic> toJson() => {
        'emotion': emotion,
        'situation': situation,
        'coping_strategy': copingStrategy,
        'timestamp': timestamp.toIso8601String(),
      };

  factory EmotionMoment.fromJson(Map<String, dynamic> json) => EmotionMoment(
        emotion: json['emotion'],
        situation: json['situation'],
        copingStrategy: json['coping_strategy'],
        timestamp: DateTime.parse(json['timestamp']),
      );
}

/// Child's current emotion check-in
class EmotionCheckIn {
  final String emotionId;
  final int intensity; // 1-5
  final String? whatHappened; // Optional context
  final String? whatHelped; // What they tried
  final DateTime timestamp;

  EmotionCheckIn({
    required this.emotionId,
    required this.intensity,
    this.whatHappened,
    this.whatHelped,
    required this.timestamp,
  });

  Map<String, dynamic> toJson() => {
        'emotion_id': emotionId,
        'intensity': intensity,
        'what_happened': whatHappened,
        'what_helped': whatHelped,
        'timestamp': timestamp.toIso8601String(),
      };

  factory EmotionCheckIn.fromJson(Map<String, dynamic> json) => EmotionCheckIn(
        emotionId: json['emotion_id'],
        intensity: json['intensity'],
        whatHappened: json['what_happened'],
        whatHelped: json['what_helped'],
        timestamp: DateTime.parse(json['timestamp']),
      );
}

/// Service to manage emotion learning
class EmotionsLearningService {
  static const String _checkInsKey = 'emotion_check_ins';
  static const String _learnedEmotionsKey = 'learned_emotions';
  static const String _storyMomentsKey = 'emotion_story_moments';

  /// All emotions kids can learn about
  static final List<Emotion> _allEmotions = [
    // HAPPY EMOTIONS
    const Emotion(
      id: 'happy',
      name: 'Happy',
      emoji: '😊',
      category: EmotionCategory.happy,
      description: 'Feeling good and cheerful',
      physicalSigns: 'Smiling, feeling light and energetic',
      copingStrategies: [
        'Share your happiness with others',
        'Remember this moment for later',
        'Do something fun to keep the feeling going',
      ],
      colorHex: '#FFD700',
      intensityLevel: 3,
    ),
    const Emotion(
      id: 'excited',
      name: 'Excited',
      emoji: '🤩',
      category: EmotionCategory.happy,
      description: 'Looking forward to something wonderful',
      physicalSigns: 'Heart racing, can\'t sit still, full of energy',
      copingStrategies: [
        'Take deep breaths to calm down',
        'Talk about what you\'re excited for',
        'Channel energy into movement or dance',
      ],
      colorHex: '#FF6B35',
      intensityLevel: 4,
    ),
    const Emotion(
      id: 'proud',
      name: 'Proud',
      emoji: '😌',
      category: EmotionCategory.happy,
      description: 'Feeling good about something you did',
      physicalSigns: 'Standing tall, smiling, chest feels warm',
      copingStrategies: [
        'Tell someone about your achievement',
        'Write it down to remember',
        'Celebrate your success',
      ],
      colorHex: '#9B59B6',
      intensityLevel: 3,
    ),
    const Emotion(
      id: 'grateful',
      name: 'Grateful',
      emoji: '🥰',
      category: EmotionCategory.happy,
      description: 'Thankful for something or someone',
      physicalSigns: 'Warm feeling in heart, peaceful',
      copingStrategies: [
        'Say thank you',
        'Write a thank you note',
        'Think of 3 things you\'re grateful for',
      ],
      colorHex: '#E91E63',
      intensityLevel: 2,
    ),

    // SAD EMOTIONS
    const Emotion(
      id: 'sad',
      name: 'Sad',
      emoji: '😢',
      category: EmotionCategory.sad,
      description: 'Feeling down or unhappy',
      physicalSigns: 'Tears, heavy feeling, low energy',
      copingStrategies: [
        'Talk to someone you trust',
        'Give yourself a hug',
        'Do something comforting',
        'It\'s okay to cry',
      ],
      colorHex: '#3498DB',
      intensityLevel: 3,
    ),
    const Emotion(
      id: 'disappointed',
      name: 'Disappointed',
      emoji: '😞',
      category: EmotionCategory.sad,
      description: 'When things don\'t go how you hoped',
      physicalSigns: 'Slumped shoulders, sighing, tired',
      copingStrategies: [
        'It\'s okay to feel disappointed',
        'Think about what you can try next time',
        'Do something you enjoy',
        'Remember: setbacks are temporary',
      ],
      colorHex: '#607D8B',
      intensityLevel: 2,
    ),
    const Emotion(
      id: 'lonely',
      name: 'Lonely',
      emoji: '😔',
      category: EmotionCategory.sad,
      description: 'Feeling alone or left out',
      physicalSigns: 'Empty feeling, quiet, wanting company',
      copingStrategies: [
        'Reach out to a friend or family',
        'Do an activity you enjoy',
        'Remember people who care about you',
        'It\'s temporary - you\'re not alone',
      ],
      colorHex: '#34495E',
      intensityLevel: 3,
    ),

    // ANGRY EMOTIONS
    const Emotion(
      id: 'angry',
      name: 'Angry',
      emoji: '😠',
      category: EmotionCategory.angry,
      description: 'Feeling mad or upset',
      physicalSigns: 'Hot face, clenched fists, fast breathing',
      copingStrategies: [
        'Take 5 deep breaths',
        'Count to 10 slowly',
        'Take a break and cool down',
        'Talk about it when you\'re calmer',
        'Squeeze a stress ball',
      ],
      colorHex: '#E74C3C',
      intensityLevel: 4,
    ),
    const Emotion(
      id: 'frustrated',
      name: 'Frustrated',
      emoji: '😤',
      category: EmotionCategory.angry,
      description: 'When something is hard or not working',
      physicalSigns: 'Tense muscles, grumbling, impatient',
      copingStrategies: [
        'Take a break',
        'Try a different approach',
        'Ask for help',
        'Remember: it\'s okay to struggle',
      ],
      colorHex: '#F39C12',
      intensityLevel: 3,
    ),

    // SCARED EMOTIONS
    const Emotion(
      id: 'scared',
      name: 'Scared',
      emoji: '😨',
      category: EmotionCategory.scared,
      description: 'Feeling afraid or frightened',
      physicalSigns: 'Fast heartbeat, shaking, wanting to hide',
      copingStrategies: [
        'Find a safe person',
        'Take slow deep breaths',
        'Remember you\'re safe',
        'Talk about what scares you',
        'Face fears slowly with support',
      ],
      colorHex: '#8E44AD',
      intensityLevel: 4,
    ),
    const Emotion(
      id: 'worried',
      name: 'Worried',
      emoji: '😟',
      category: EmotionCategory.scared,
      description: 'Thinking about things that might go wrong',
      physicalSigns: 'Butterflies in stomach, can\'t stop thinking',
      copingStrategies: [
        'Talk about your worries',
        'Write them down',
        'Think: What\'s the worst that could happen?',
        'Focus on what you can control',
        'Do a calming activity',
      ],
      colorHex: '#7F8C8D',
      intensityLevel: 3,
    ),
    const Emotion(
      id: 'nervous',
      name: 'Nervous',
      emoji: '😬',
      category: EmotionCategory.scared,
      description: 'Uneasy about something coming up',
      physicalSigns: 'Jittery, sweaty palms, fidgeting',
      copingStrategies: [
        'Practice deep breathing',
        'Prepare as much as you can',
        'Remember past times you succeeded',
        'It\'s okay to be nervous',
      ],
      colorHex: '#95A5A6',
      intensityLevel: 2,
    ),

    // SURPRISED EMOTIONS
    const Emotion(
      id: 'surprised',
      name: 'Surprised',
      emoji: '😲',
      category: EmotionCategory.surprised,
      description: 'Something unexpected happened',
      physicalSigns: 'Wide eyes, gasping, sudden energy',
      copingStrategies: [
        'Take a moment to process',
        'Is this a good or challenging surprise?',
        'Share your surprise with others',
      ],
      colorHex: '#1ABC9C',
      intensityLevel: 3,
    ),
    const Emotion(
      id: 'confused',
      name: 'Confused',
      emoji: '😕',
      category: EmotionCategory.surprised,
      description: 'Not understanding what\'s happening',
      physicalSigns: 'Furrowed brow, thinking hard',
      copingStrategies: [
        'Ask questions',
        'It\'s okay not to know everything',
        'Take time to figure it out',
        'Ask for help or explanation',
      ],
      colorHex: '#16A085',
      intensityLevel: 2,
    ),

    // CALM EMOTIONS
    const Emotion(
      id: 'calm',
      name: 'Calm',
      emoji: '😌',
      category: EmotionCategory.calm,
      description: 'Feeling peaceful and relaxed',
      physicalSigns: 'Slow breathing, relaxed muscles, clear mind',
      copingStrategies: [
        'Enjoy this peaceful moment',
        'Notice what helped you feel calm',
        'Use this feeling when stressed',
      ],
      colorHex: '#27AE60',
      intensityLevel: 1,
    ),
    const Emotion(
      id: 'content',
      name: 'Content',
      emoji: '☺️',
      category: EmotionCategory.calm,
      description: 'Satisfied and comfortable',
      physicalSigns: 'Relaxed, gentle smile, at ease',
      copingStrategies: [
        'Appreciate the moment',
        'Think about what makes you content',
        'Share your contentment',
      ],
      colorHex: '#2ECC71',
      intensityLevel: 1,
    ),

    // MIXED EMOTIONS
    const Emotion(
      id: 'overwhelmed',
      name: 'Overwhelmed',
      emoji: '😵',
      category: EmotionCategory.mixed,
      description: 'Too much happening at once',
      physicalSigns: 'Can\'t think clearly, too much going on',
      copingStrategies: [
        'Stop and take deep breaths',
        'Break things into small steps',
        'Ask for help',
        'It\'s okay to take a break',
        'Do one thing at a time',
      ],
      colorHex: '#D35400',
      intensityLevel: 4,
    ),
  ];

  /// Record emotion check-in
  Future<void> recordCheckIn(EmotionCheckIn checkIn) async {
    final prefs = await SharedPreferences.getInstance();
    final checkIns = await getCheckIns();
    checkIns.add(checkIn);

    // Keep last 100 check-ins
    if (checkIns.length > 100) {
      checkIns.removeRange(0, checkIns.length - 100);
    }

    await prefs.setString(
      _checkInsKey,
      jsonEncode(checkIns.map((c) => c.toJson()).toList()),
    );

    // Mark emotion as learned
    await _markEmotionLearned(checkIn.emotionId);
  }

  /// Get all check-ins
  Future<List<EmotionCheckIn>> getCheckIns() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonString = prefs.getString(_checkInsKey);

    if (jsonString == null || jsonString.isEmpty) {
      return [];
    }

    try {
      final List list = jsonDecode(jsonString);
      return list.map((json) => EmotionCheckIn.fromJson(json)).toList();
    } catch (e) {
      return [];
    }
  }

  /// Mark an emotion as learned
  Future<void> _markEmotionLearned(String emotionId) async {
    final prefs = await SharedPreferences.getInstance();
    final learned = await getLearnedEmotions();

    if (!learned.contains(emotionId)) {
      learned.add(emotionId);
      await prefs.setString(_learnedEmotionsKey, jsonEncode(learned));
    }
  }

  /// Get learned emotions
  Future<List<String>> getLearnedEmotions() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonString = prefs.getString(_learnedEmotionsKey);

    if (jsonString == null || jsonString.isEmpty) {
      return [];
    }

    try {
      return List<String>.from(jsonDecode(jsonString));
    } catch (e) {
      return [];
    }
  }

  /// Get emotion statistics
  Future<Map<String, int>> getEmotionStats() async {
    final checkIns = await getCheckIns();
    final stats = <String, int>{};

    for (final checkIn in checkIns) {
      stats[checkIn.emotionId] = (stats[checkIn.emotionId] ?? 0) + 1;
    }

    return stats;
  }

  /// Get recent check-ins (last 7 days)
  Future<List<EmotionCheckIn>> getRecentCheckIns({int days = 7}) async {
    final all = await getCheckIns();
    final cutoff = DateTime.now().subtract(Duration(days: days));

    return all.where((c) => c.timestamp.isAfter(cutoff)).toList();
  }

  /// Record emotion moment from story
  Future<void> recordStoryMoment(EmotionMoment moment) async {
    final prefs = await SharedPreferences.getInstance();
    final moments = await getStoryMoments();
    moments.add(moment);

    // Keep last 50 moments
    if (moments.length > 50) {
      moments.removeRange(0, moments.length - 50);
    }

    await prefs.setString(
      _storyMomentsKey,
      jsonEncode(moments.map((m) => m.toJson()).toList()),
    );
  }

  /// Get story moments
  Future<List<EmotionMoment>> getStoryMoments() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonString = prefs.getString(_storyMomentsKey);

    if (jsonString == null || jsonString.isEmpty) {
      return [];
    }

    try {
      final List list = jsonDecode(jsonString);
      return list.map((json) => EmotionMoment.fromJson(json)).toList();
    } catch (e) {
      return [];
    }
  }

  /// Get all emotions
  List<Emotion> getAllEmotions() => _allEmotions;

  /// Get emotion by ID
  Emotion? getEmotionById(String id) {
    try {
      return _allEmotions.firstWhere((e) => e.id == id);
    } catch (e) {
      return null;
    }
  }

  /// Get emotions by category
  List<Emotion> getEmotionsByCategory(EmotionCategory category) {
    return _allEmotions.where((e) => e.category == category).toList();
  }

  /// Generate story prompt with emotion focus
  String generateEmotionStoryPrompt({
    required String characterName,
    required String emotionId,
    String? specificSituation,
  }) {
    final emotion = getEmotionById(emotionId);
    if (emotion == null) return '';

    return '''
Create a story about $characterName learning about the emotion: ${emotion.name}.

In this story, $characterName experiences ${emotion.name} (${emotion.description}).
${specificSituation != null ? 'Situation: $specificSituation' : ''}

The story should:
1. Show how $characterName's body feels (${emotion.physicalSigns})
2. Help them identify they're feeling ${emotion.name}
3. Show them using healthy coping strategies:
   ${emotion.copingStrategies.join('\n   ')}
4. End with $characterName feeling better and understanding this emotion

Make it age-appropriate, engaging, and educational about emotions.
''';
  }
}

/// Emotion wheel widget helper
class EmotionWheel {
  static const Map<EmotionCategory, String> categoryNames = {
    EmotionCategory.happy: 'Happy',
    EmotionCategory.sad: 'Sad',
    EmotionCategory.angry: 'Angry',
    EmotionCategory.scared: 'Scared',
    EmotionCategory.surprised: 'Surprised',
    EmotionCategory.calm: 'Calm',
    EmotionCategory.mixed: 'Mixed',
  };

  static const Map<EmotionCategory, Color> categoryColors = {
    EmotionCategory.happy: Color(0xFFFFD700),
    EmotionCategory.sad: Color(0xFF3498DB),
    EmotionCategory.angry: Color(0xFFE74C3C),
    EmotionCategory.scared: Color(0xFF8E44AD),
    EmotionCategory.surprised: Color(0xFF1ABC9C),
    EmotionCategory.calm: Color(0xFF27AE60),
    EmotionCategory.mixed: Color(0xFFD35400),
  };
}
