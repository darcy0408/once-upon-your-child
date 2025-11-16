// lib/character_evolution.dart

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'therapeutic_models.dart';
import 'emotions_learning_system.dart';

/// Represents a character's emotional growth and development
class CharacterEvolution {
  final String characterId;
  final Map<TherapeuticGoal, int> therapeuticProgress; // 0-100 progress per goal
  final Map<String, int> emotionMastery; // emotion_id -> mastery level (0-100)
  final List<CharacterMilestone> milestones;
  final Map<String, dynamic> evolvedTraits; // Dynamic traits that change with growth
  final DateTime lastUpdated;

  CharacterEvolution({
    required this.characterId,
    required this.therapeuticProgress,
    required this.emotionMastery,
    required this.milestones,
    required this.evolvedTraits,
    required this.lastUpdated,
  });

  /// Calculate overall character development score
  double get overallDevelopmentScore {
    if (therapeuticProgress.isEmpty && emotionMastery.isEmpty) return 0.0;

    final therapeuticAvg = therapeuticProgress.isNotEmpty
        ? therapeuticProgress.values.reduce((a, b) => a + b) / therapeuticProgress.length
        : 0.0;

    final emotionAvg = emotionMastery.isNotEmpty
        ? emotionMastery.values.reduce((a, b) => a + b) / emotionMastery.length
        : 0.0;

    return (therapeuticAvg + emotionAvg) / 2;
  }

  /// Get current development stage
  CharacterDevelopmentStage get developmentStage {
    final score = overallDevelopmentScore;
    if (score >= 80) return CharacterDevelopmentStage.master;
    if (score >= 60) return CharacterDevelopmentStage.advanced;
    if (score >= 40) return CharacterDevelopmentStage.intermediate;
    if (score >= 20) return CharacterDevelopmentStage.beginner;
    return CharacterDevelopmentStage.novice;
  }

  Map<String, dynamic> toJson() => {
        'character_id': characterId,
        'therapeutic_progress': therapeuticProgress.map((k, v) => MapEntry(k.name, v)),
        'emotion_mastery': emotionMastery,
        'milestones': milestones.map((m) => m.toJson()).toList(),
        'evolved_traits': evolvedTraits,
        'last_updated': lastUpdated.toIso8601String(),
      };

  factory CharacterEvolution.fromJson(Map<String, dynamic> json) {
    return CharacterEvolution(
      characterId: json['character_id'] ?? '',
      therapeuticProgress: (json['therapeutic_progress'] as Map<String, dynamic>?)
              ?.map((k, v) => MapEntry(
                  TherapeuticGoal.values.firstWhere((goal) => goal.name == k),
                  v as int))
              .cast<TherapeuticGoal, int>() ??
          {},
      emotionMastery: (json['emotion_mastery'] as Map<String, dynamic>?)
              ?.map((k, v) => MapEntry(k, v as int)) ??
          {},
      milestones: (json['milestones'] as List<dynamic>?)
              ?.map((m) => CharacterMilestone.fromJson(m))
              .toList() ??
          [],
      evolvedTraits: json['evolved_traits'] ?? {},
      lastUpdated: DateTime.tryParse(json['last_updated'] ?? '') ?? DateTime.now(),
    );
  }
}

/// Represents a significant milestone in character development
class CharacterMilestone {
  final String id;
  final String title;
  final String description;
  final TherapeuticGoal? goal;
  final String? emotionId;
  final DateTime achievedAt;
  final int progressIncrease; // How much progress this milestone represents

  CharacterMilestone({
    required this.id,
    required this.title,
    required this.description,
    this.goal,
    this.emotionId,
    required this.achievedAt,
    required this.progressIncrease,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'description': description,
        'goal': goal?.name,
        'emotion_id': emotionId,
        'achieved_at': achievedAt.toIso8601String(),
        'progress_increase': progressIncrease,
      };

  factory CharacterMilestone.fromJson(Map<String, dynamic> json) {
    return CharacterMilestone(
      id: json['id'] ?? '',
      title: json['title'] ?? '',
      description: json['description'] ?? '',
      goal: json['goal'] != null
          ? TherapeuticGoal.values.firstWhere((g) => g.name == json['goal'])
          : null,
      emotionId: json['emotion_id'],
      achievedAt: DateTime.tryParse(json['achieved_at'] ?? '') ?? DateTime.now(),
      progressIncrease: json['progress_increase'] ?? 0,
    );
  }
}

/// Character development stages
enum CharacterDevelopmentStage {
  novice,      // 0-19% development
  beginner,    // 20-39% development
  intermediate,// 40-59% development
  advanced,    // 60-79% development
  master,      // 80-100% development
}

extension CharacterDevelopmentStageExtension on CharacterDevelopmentStage {
  String get displayName {
    switch (this) {
      case CharacterDevelopmentStage.novice:
        return 'Novice Explorer';
      case CharacterDevelopmentStage.beginner:
        return 'Growing Friend';
      case CharacterDevelopmentStage.intermediate:
        return 'Confident Helper';
      case CharacterDevelopmentStage.advanced:
        return 'Wise Guide';
      case CharacterDevelopmentStage.master:
        return 'Emotional Champion';
    }
  }

  String get description {
    switch (this) {
      case CharacterDevelopmentStage.novice:
        return 'Just starting their emotional journey';
      case CharacterDevelopmentStage.beginner:
        return 'Learning about feelings and coping skills';
      case CharacterDevelopmentStage.intermediate:
        return 'Building confidence and helping others';
      case CharacterDevelopmentStage.advanced:
        return 'Mastering emotional challenges and guiding others';
      case CharacterDevelopmentStage.master:
        return 'A true champion of emotional intelligence';
    }
  }

  Color get color {
    switch (this) {
      case CharacterDevelopmentStage.novice:
        return Colors.grey;
      case CharacterDevelopmentStage.beginner:
        return Colors.blue;
      case CharacterDevelopmentStage.intermediate:
        return Colors.green;
      case CharacterDevelopmentStage.advanced:
        return Colors.orange;
      case CharacterDevelopmentStage.master:
        return Colors.purple;
    }
  }
}

/// Service to manage character evolution and growth
class CharacterEvolutionService {
  static const String _evolutionKey = 'character_evolution_data';

  /// Get evolution data for a character
  Future<CharacterEvolution?> getCharacterEvolution(String characterId) async {
    final prefs = await SharedPreferences.getInstance();
    final evolutionJson = prefs.getString(_evolutionKey);

    if (evolutionJson == null) return null;

    try {
      final Map<String, dynamic> allEvolution = jsonDecode(evolutionJson);
      final characterEvolution = allEvolution[characterId];
      if (characterEvolution != null) {
        return CharacterEvolution.fromJson(characterEvolution);
      }
    } catch (e) {
      // Handle migration or corrupted data
    }

    return null;
  }

  /// Update character evolution based on therapeutic session
  Future<void> updateCharacterEvolution(
    String characterId,
    TherapeuticGoal? goal,
    String? emotionId,
    int progressIncrease,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    final evolutionJson = prefs.getString(_evolutionKey);
    Map<String, dynamic> allEvolution = {};

    if (evolutionJson != null) {
      try {
        allEvolution = jsonDecode(evolutionJson);
      } catch (e) {
        // Reset if corrupted
      }
    }

    CharacterEvolution evolution;
    final existing = allEvolution[characterId];

    if (existing != null) {
      evolution = CharacterEvolution.fromJson(existing);
    } else {
      evolution = CharacterEvolution(
        characterId: characterId,
        therapeuticProgress: {},
        emotionMastery: {},
        milestones: [],
        evolvedTraits: {},
        lastUpdated: DateTime.now(),
      );
    }

    // Update therapeutic progress
    if (goal != null) {
      final currentProgress = evolution.therapeuticProgress[goal] ?? 0;
      evolution.therapeuticProgress[goal] = (currentProgress + progressIncrease).clamp(0, 100);
    }

    // Update emotion mastery
    if (emotionId != null) {
      final currentMastery = evolution.emotionMastery[emotionId] ?? 0;
      evolution.emotionMastery[emotionId] = (currentMastery + progressIncrease).clamp(0, 100);
    }

    // Check for new milestones
    final newMilestones = _checkForMilestones(evolution, goal, emotionId, progressIncrease);
    evolution.milestones.addAll(newMilestones);

    // Update evolved traits based on progress
    evolution.evolvedTraits = _calculateEvolvedTraits(evolution);

    evolution.lastUpdated = DateTime.now();

    allEvolution[characterId] = evolution.toJson();
    await prefs.setString(_evolutionKey, jsonEncode(allEvolution));
  }

  /// Check if character has achieved new milestones
  List<CharacterMilestone> _checkForMilestones(
    CharacterEvolution evolution,
    TherapeuticGoal? goal,
    String? emotionId,
    int progressIncrease,
  ) {
    final newMilestones = <CharacterMilestone>[];

    // Check therapeutic goal milestones
    if (goal != null) {
      final progress = evolution.therapeuticProgress[goal] ?? 0;
      final existingMilestoneIds = evolution.milestones.map((m) => m.id).toSet();

      // 25% milestone
      if (progress >= 25 && !existingMilestoneIds.contains('${goal.name}_25')) {
        newMilestones.add(CharacterMilestone(
          id: '${goal.name}_25',
          title: '${goal.displayName} Explorer',
          description: 'Made good progress in understanding ${goal.displayName.toLowerCase()}',
          goal: goal,
          achievedAt: DateTime.now(),
          progressIncrease: progressIncrease,
        ));
      }

      // 50% milestone
      if (progress >= 50 && !existingMilestoneIds.contains('${goal.name}_50')) {
        newMilestones.add(CharacterMilestone(
          id: '${goal.name}_50',
          title: '${goal.displayName} Helper',
          description: 'Became skilled at handling ${goal.displayName.toLowerCase()} situations',
          goal: goal,
          achievedAt: DateTime.now(),
          progressIncrease: progressIncrease,
        ));
      }

      // 75% milestone
      if (progress >= 75 && !existingMilestoneIds.contains('${goal.name}_75')) {
        newMilestones.add(CharacterMilestone(
          id: '${goal.name}_75',
          title: '${goal.displayName} Guide',
          description: 'Mastered ${goal.displayName.toLowerCase()} and can help others',
          goal: goal,
          achievedAt: DateTime.now(),
          progressIncrease: progressIncrease,
        ));
      }

      // 100% milestone
      if (progress >= 100 && !existingMilestoneIds.contains('${goal.name}_100')) {
        newMilestones.add(CharacterMilestone(
          id: '${goal.name}_100',
          title: '${goal.displayName} Champion',
          description: 'Achieved mastery in ${goal.displayName.toLowerCase()}',
          goal: goal,
          achievedAt: DateTime.now(),
          progressIncrease: progressIncrease,
        ));
      }
    }

    // Check emotion mastery milestones
    if (emotionId != null) {
      final mastery = evolution.emotionMastery[emotionId] ?? 0;
      final existingMilestoneIds = evolution.milestones.map((m) => m.id).toSet();

      if (mastery >= 50 && !existingMilestoneIds.contains('${emotionId}_mastery')) {
        final emotion = EmotionsLearningService().getEmotionById(emotionId);
        newMilestones.add(CharacterMilestone(
          id: '${emotionId}_mastery',
          title: '${emotion?.name ?? emotionId} Expert',
          description: 'Mastered understanding and managing ${emotion?.name?.toLowerCase() ?? emotionId} feelings',
          emotionId: emotionId,
          achievedAt: DateTime.now(),
          progressIncrease: progressIncrease,
        ));
      }
    }

    return newMilestones;
  }

  /// Calculate evolved traits based on character progress
  Map<String, dynamic> _calculateEvolvedTraits(CharacterEvolution evolution) {
    final traits = <String, dynamic>{};

    // Confidence trait based on resilience and self-esteem progress
    final resilienceProgress = evolution.therapeuticProgress[TherapeuticGoal.resilience] ?? 0;
    final selfEsteemProgress = evolution.therapeuticProgress[TherapeuticGoal.selfEsteem] ?? 0;
    final confidenceLevel = (resilienceProgress + selfEsteemProgress) ~/ 2;
    traits['confidence'] = confidenceLevel;

    // Empathy trait based on empathy and social skills progress
    final empathyProgress = evolution.therapeuticProgress[TherapeuticGoal.empathy] ?? 0;
    final socialSkillsProgress = evolution.therapeuticProgress[TherapeuticGoal.socialSkills] ?? 0;
    final empathyLevel = (empathyProgress + socialSkillsProgress) ~/ 2;
    traits['empathy'] = empathyLevel;

    // Emotional intelligence based on overall progress
    traits['emotional_intelligence'] = evolution.overallDevelopmentScore.round();

    // Coping skills count
    final copingEmotions = evolution.emotionMastery.entries
        .where((e) => (e.value) >= 30) // Emotions with at least 30% mastery
        .length;
    traits['coping_skills_count'] = copingEmotions;

    return traits;
  }

  /// Get all character evolutions
  Future<Map<String, CharacterEvolution>> getAllCharacterEvolutions() async {
    final prefs = await SharedPreferences.getInstance();
    final evolutionJson = prefs.getString(_evolutionKey);

    if (evolutionJson == null) return {};

    try {
      final Map<String, dynamic> allEvolution = jsonDecode(evolutionJson);
      return allEvolution.map((k, v) => MapEntry(k, CharacterEvolution.fromJson(v)));
    } catch (e) {
      return {};
    }
  }

  /// Reset character evolution (for testing or character restart)
  Future<void> resetCharacterEvolution(String characterId) async {
    final prefs = await SharedPreferences.getInstance();
    final evolutionJson = prefs.getString(_evolutionKey);
    Map<String, dynamic> allEvolution = {};

    if (evolutionJson != null) {
      try {
        allEvolution = jsonDecode(evolutionJson);
      } catch (e) {
        // Reset if corrupted
      }
    }

    allEvolution.remove(characterId);
    await prefs.setString(_evolutionKey, jsonEncode(allEvolution));
  }
}

/// Extension to Character model to include evolution data
extension CharacterEvolutionExtension on Character {
  Future<CharacterEvolution?> getEvolution() async {
    return CharacterEvolutionService().getCharacterEvolution(id);
  }

  Future<void> updateEvolution({
    TherapeuticGoal? goal,
    String? emotionId,
    int progressIncrease = 5,
  }) async {
    await CharacterEvolutionService().updateCharacterEvolution(
      id,
      goal,
      emotionId,
      progressIncrease,
    );
  }
}