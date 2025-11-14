// lib/character_evolution.dart

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'models.dart';
import 'therapeutic_models.dart';

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
      default:
        return 'Unknown';
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
      default:
        return 'Unknown stage';
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
      default:
        return Colors.grey;
    }
  }
}

/// Represents a character's emotional and therapeutic evolution
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
        'evolved_traits': evolvedTraits,
        'milestones': milestones.map((m) => m.toJson()).toList(),
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
      evolvedTraits: json['evolved_traits'] ?? {},
      milestones: (json['milestones'] as List<dynamic>?)
              ?.map((m) => CharacterMilestone.fromJson(m))
              .toList() ??
          [],
      lastUpdated: DateTime.tryParse(json['last_updated'] ?? '') ?? DateTime.now(),
    );
  }
}

/// Service to manage character evolution and growth
class CharacterEvolutionService {
  static const String _evolutionKey = 'character_evolution_data';

  /// Get evolution data for a character
  Future<CharacterEvolution?> getCharacterEvolution(String characterId) async {
    // TODO: Implement actual data persistence
    // For now, return mock data
    return CharacterEvolution(
      characterId: characterId,
      therapeuticProgress: {},
      emotionMastery: {},
      milestones: [],
      evolvedTraits: {},
      lastUpdated: DateTime.now(),
    );
  }

  /// Update character evolution based on therapeutic session
  Future<void> updateCharacterEvolution(
    String characterId,
    TherapeuticGoal? goal,
    String? emotionId,
    int progressIncrease,
  ) async {
    // TODO: Implement actual data persistence
    // For now, just log the update
    debugPrint('Updating evolution for character $characterId: goal=$goal, emotion=$emotionId, progress=$progressIncrease');
  }
}

/// Extension methods for Character class
extension CharacterEvolutionExtension on Character {
  /// Get evolution data for this character
  Future<CharacterEvolution?> getEvolution() async {
    // TODO: Implement API call to get evolution data
    // For now, return mock data
    return CharacterEvolution(
      characterId: id,
      therapeuticProgress: {},
      emotionMastery: {},
      milestones: [],
      evolvedTraits: {},
      lastUpdated: DateTime.now(),
    );
  }
}