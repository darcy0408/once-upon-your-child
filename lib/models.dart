// lib/models.dart
import 'dart:convert';

import 'package:flutter/material.dart';
import 'avatar_models.dart';
import 'services/avatar_service.dart';
import 'models/generated_avatar.dart';

class Character {
  final String id;
  final String name;
  final int age;
  final String role;
  final String? gender;
  final String? characterStyle;
  final String? magicType;
  final String? challenge;
  final List<String>? likes;
  final List<String>? dislikes;
  final List<String>? fears;
  final List<String>? strengths;
  final List<String>? personalityTraits;
  final Map<String, int>? personalitySliders;
  final List<String>? goals;
  final String? comfortItem;
  final String? hair;
  final String? eyes;
  final String? skinTone;
  final String? hairstyle;
  final String? outfit;
  final String? currentEmotion;
  final String? currentEmotionCore;
  final CharacterAvatar? avatar; // DiceBear avatar (legacy)
  final GeneratedAvatar? generatedAvatar; // AI-generated avatar (new)

  Character({
    required this.id,
    required this.name,
    required this.age,
    required this.role,
    this.gender,
    this.characterStyle,
    this.magicType,
    this.challenge,
    this.likes,
    this.dislikes,
    this.fears,
    this.strengths,
    this.personalityTraits,
    this.personalitySliders,
    this.goals,
    this.comfortItem,
    this.hair,
    this.eyes,
    this.skinTone,
    this.hairstyle,
    this.outfit,
    this.currentEmotion,
    this.currentEmotionCore,
    this.avatar,
    this.generatedAvatar,
    this.pets,
    this.friends,
  });

  final List<Map<String, dynamic>>? pets;
  final List<String>? friends;

  factory Character.fromJson(Map<String, dynamic> json) {
    CharacterAvatar? avatar;
    final avatarJson = json['avatar'];
    if (avatarJson is Map<String, dynamic>) {
      avatar = CharacterAvatar.fromJson(avatarJson);
    } else if (avatarJson is String) {
      try {
        final parsed = jsonDecode(avatarJson);
        if (parsed is Map<String, dynamic>) {
          avatar = CharacterAvatar.fromJson(parsed);
        }
      } catch (_) {
        // leave avatar null if parsing fails
      }
    }
    final dynamic ageValue = json['age'];
    final int parsedAge = ageValue is int
        ? ageValue
        : ageValue is num
            ? ageValue.toInt()
            : int.tryParse(ageValue?.toString() ?? '') ?? 0;
            
    // Robustly parse personality sliders
    Map<String, int>? sliderValues;
    final sliderJson = json['personality_sliders'];
    if (sliderJson is Map) {
      final sanitized = <String, int>{};
      sliderJson.forEach((key, value) {
        final parsed = _parseSliderValue(value);
        if (parsed != null) {
          sanitized[key.toString()] = parsed;
        }
      });
      if (sanitized.isNotEmpty) {
        sliderValues = sanitized;
      }
    }

    // Robustly parse pets
    List<Map<String, dynamic>>? petsList;
    if (json['pets'] is List) {
      try {
        petsList = (json['pets'] as List)
            .where((item) => item is Map)
            .map((item) {
              try {
                return Map<String, dynamic>.from(item as Map);
              } catch (_) {
                return null;
              }
            })
            // Filter out nulls from failed conversions
            .where((item) => item != null)
            .cast<Map<String, dynamic>>()
            .toList();
      } catch (e) {
        debugPrint('Error parsing pets: $e');
        petsList = [];
      }
    }

    // Robustly parse friends
    List<String>? friendsList;
    if (json['friends'] is List) {
      friendsList = (json['friends'] as List)
          .map((e) => e.toString())
          .toList();
    }

    // Parse generated avatar
    GeneratedAvatar? generatedAvatar;
    final generatedAvatarJson = json['generated_avatar'];
    if (generatedAvatarJson is Map<String, dynamic>) {
      try {
        generatedAvatar = GeneratedAvatar.fromJson(generatedAvatarJson);
      } catch (e) {
        debugPrint('Error parsing generated avatar: $e');
      }
    }

    return Character(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? 'Unknown',
      age: parsedAge,
      role: json['role']?.toString() ?? 'Hero',
      gender: json['gender']?.toString(),
      characterStyle: json['character_style']?.toString(),
      magicType: json['magic_type']?.toString(),
      challenge: json['challenge']?.toString(),
      likes: json['likes'] != null ? (json['likes'] as List).map((e) => e.toString()).toList() : null,
      dislikes:
          json['dislikes'] != null ? (json['dislikes'] as List).map((e) => e.toString()).toList() : null,
      fears: json['fears'] != null ? (json['fears'] as List).map((e) => e.toString()).toList() : null,
      strengths: json['strengths'] != null ? (json['strengths'] as List).map((e) => e.toString()).toList() : null,
      personalityTraits: json['personality_traits'] != null ? (json['personality_traits'] as List).map((e) => e.toString()).toList() : null,
      personalitySliders: sliderValues,
      goals: json['goals'] != null ? (json['goals'] as List).map((e) => e.toString()).toList() : null,
      comfortItem: json['comfort_item']?.toString(),
      hair: json['hair']?.toString(),
      eyes: json['eyes']?.toString(),
      skinTone: json['skin_tone']?.toString(),
      hairstyle: json['hairstyle']?.toString(),
      outfit: json['outfit']?.toString(),
      currentEmotion: json['current_emotion']?.toString(),
      currentEmotionCore: json['current_emotion_core']?.toString(),
      avatar: avatar,
      generatedAvatar: generatedAvatar,
      pets: petsList,
      friends: friendsList,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'age': age,
        'role': role,
        'gender': gender,
        'character_style': characterStyle,
        'magic_type': magicType,
        'challenge': challenge,
        'likes': likes,
        'dislikes': dislikes,
        'fears': fears,
        'strengths': strengths,
        'personality_traits': personalityTraits,
        'personality_sliders': personalitySliders,
        'goals': goals,
        'comfort_item': comfortItem,
        'hair': hair,
        'eyes': eyes,
        'skin_tone': skinTone,
        'hairstyle': hairstyle,
        'outfit': outfit,
        'current_emotion': currentEmotion,
        'current_emotion_core': currentEmotionCore,
        if (avatar != null) 'avatar': avatar!.toJson(),
        if (generatedAvatar != null) 'generated_avatar': generatedAvatar!.toJson(),
        'pets': pets,
        'friends': friends,
      };

  /// Generate avatar URL for this character using DiceBear API
  String get avatarUrl {
    return AvatarService.generateAvatarUrl(
      characterId: id,
      hairColor: hair,
      eyeColor: eyes,
      outfit: null, // outfit field not currently used
    );
  }

  /// Build avatar widget for this character
  Widget buildAvatar({double size = 100}) {
    return AvatarService.buildAvatarWidget(
      characterId: id,
      hairColor: hair,
      eyeColor: eyes,
      outfit: null, // outfit field not currently used
      size: size,
    );
  }

  /// Update character evolution data (for therapeutic progression tracking)
  Future<void> updateEvolution({
    required String emotionId,
    required int intensity,
    required Map<String, dynamic> copingStrategies,
    required bool storyCompleted,
  }) async {
    // This would typically call an API to update evolution data
    // For now, it's a placeholder that would integrate with the backend
    debugPrint(
      'Updating evolution for character $name: emotion=$emotionId, intensity=$intensity',
    );
  }
}

int? _parseSliderValue(dynamic value) {
  if (value is num) {
    return value.clamp(0, 100).round();
  }
  if (value is String) {
    final parsed = double.tryParse(value);
    if (parsed != null) {
      return parsed.clamp(0, 100).round();
    }
  }
  return null;
}

// ---------------------
// NEW MODEL FOR STORIES
// ---------------------
class SavedStory {
  final String id;
  final String title;
  final String storyText;
  final String theme;
  final List<Character> characters;
  final DateTime createdAt;
  final bool isInteractive;
  final bool isFavorite;
  final String? wisdomGem;

  SavedStory({
    String? id,
    required this.title,
    required this.storyText,
    required this.theme,
    required this.characters,
    required this.createdAt,
    this.isInteractive = false,
    this.isFavorite = false,
    this.wisdomGem,
  }) : id = id ?? DateTime.now().millisecondsSinceEpoch.toString();

  factory SavedStory.fromJson(Map<String, dynamic> json) {
    return SavedStory(
      id: json['id'],
      title: json['title'] ?? 'Untitled Story',
      storyText: json['story_text'] ?? '',
      theme: json['theme'] ?? 'Adventure',
      characters: (json['characters'] as List<dynamic>?)
              ?.map((c) => Character.fromJson(c))
              .toList() ??
          [],
      createdAt: DateTime.tryParse(json['created_at'] ?? '') ?? DateTime.now(),
      isInteractive: json['is_interactive'] ?? false,
      isFavorite: json['is_favorite'] ?? false,
      wisdomGem: json['wisdom_gem'],
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'story_text': storyText,
        'theme': theme,
        'characters': characters.map((c) => c.toJson()).toList(),
        'created_at': createdAt.toIso8601String(),
        'is_interactive': isInteractive,
        'is_favorite': isFavorite,
        'wisdom_gem': wisdomGem,
      };

  SavedStory copyWith({
    String? id,
    String? title,
    String? storyText,
    String? theme,
    List<Character>? characters,
    DateTime? createdAt,
    bool? isInteractive,
    bool? isFavorite,
    String? wisdomGem,
  }) {
    return SavedStory(
      id: id ?? this.id,
      title: title ?? this.title,
      storyText: storyText ?? this.storyText,
      theme: theme ?? this.theme,
      characters: characters ?? this.characters,
      createdAt: createdAt ?? this.createdAt,
      isInteractive: isInteractive ?? this.isInteractive,
      isFavorite: isFavorite ?? this.isFavorite,
      wisdomGem: wisdomGem ?? this.wisdomGem,
    );
  }
}

// ---------------------
// INTERACTIVE STORY MODELS
// ---------------------
class StoryChoice {
  final String id;
  final String text;
  final String description;
  final String? emotionalSkill;

  StoryChoice({
    required this.id,
    required this.text,
    required this.description,
    this.emotionalSkill,
  });

  factory StoryChoice.fromJson(Map<String, dynamic> json) {
    return StoryChoice(
      id: json['id'] ?? '',
      text: json['text'] ?? '',
      description: json['description'] ?? '',
      emotionalSkill: json['emotional_skill'],
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'text': text,
        'description': description,
        if (emotionalSkill != null) 'emotional_skill': emotionalSkill,
      };
}

class StorySegment {
  final String text;
  final List<StoryChoice>? choices;
  final bool isEnding;
  final bool canConclude;

  StorySegment({
    required this.text,
    this.choices,
    this.isEnding = false,
    this.canConclude = false,
  });

  factory StorySegment.fromJson(Map<String, dynamic> json) {
    return StorySegment(
      text: json['text'] ?? '',
      choices: (json['choices'] as List<dynamic>?)
          ?.map((c) => StoryChoice.fromJson(c))
          .toList(),
      isEnding: json['is_ending'] ?? false,
      canConclude: json['can_conclude'] ?? false,
    );
  }

  Map<String, dynamic> toJson() => {
        'text': text,
        'choices': choices?.map((c) => c.toJson()).toList(),
        'is_ending': isEnding,
        'can_conclude': canConclude,
      };
}
