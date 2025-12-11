import 'dart:convert';

import 'package:isar/isar.dart';

import '../../models.dart';

part 'story_local_io.g.dart';

@collection
class StoryLocal {
  Id id = Isar.autoIncrement;

  @Index()
  late String storyId;

  late String title;
  late String storyText;
  late String theme;
  bool isFavorite = false;
  String? imageUrl;

  @Index()
  late DateTime createdAt;

  bool isSyncedToServer = false;
  bool isInteractive = false;
  String? wisdomGem;
  String? charactersJson;

  static StoryLocal fromJson(Map<String, dynamic> json) {
    return StoryLocal()
      ..storyId = json['id']?.toString() ?? json['storyId']?.toString() ?? ''
      ..title = json['title'] ?? ''
      ..storyText = json['storyText'] ?? json['story_text'] ?? ''
      ..theme = json['theme'] ?? ''
      ..isFavorite = json['isFavorite'] ?? json['is_favorite'] ?? false
      ..imageUrl = json['imageUrl'] ?? json['image_url']
      ..createdAt = json['createdAt'] != null
          ? DateTime.tryParse(json['createdAt'].toString()) ?? DateTime.now()
          : DateTime.now()
      ..isInteractive = json['isInteractive'] ?? json['is_interactive'] ?? false
      ..wisdomGem = json['wisdomGem'] ?? json['wisdom_gem']
      ..charactersJson = _encodeCharactersFromJson(json['characters'])
      ..isSyncedToServer = true;
  }

  static StoryLocal fromSavedStory(SavedStory savedStory) {
    return StoryLocal()
      ..storyId = savedStory.id
      ..title = savedStory.title
      ..storyText = savedStory.storyText
      ..theme = savedStory.theme
      ..isFavorite = savedStory.isFavorite
      ..createdAt = savedStory.createdAt
      ..isInteractive = savedStory.isInteractive
      ..wisdomGem = savedStory.wisdomGem
      ..charactersJson = _encodeCharacters(savedStory.characters);
  }

  Map<String, dynamic> toJson() => {
        'id': storyId,
        'title': title,
        'storyText': storyText,
        'theme': theme,
        'isFavorite': isFavorite,
        'imageUrl': imageUrl,
        'createdAt': createdAt.toIso8601String(),
        'isInteractive': isInteractive,
        'wisdomGem': wisdomGem,
        'characters': _decodeCharacters().map((c) => c.toJson()).toList(),
      };

  @ignore
  List<Character> get characters => _decodeCharacters();

  @ignore
  String get identifier => storyId.isNotEmpty ? storyId : id.toString();

  static String? _encodeCharacters(List<Character> characters) {
    if (characters.isEmpty) return null;
    return jsonEncode(characters.map((c) => c.toJson()).toList());
  }

  static String? _encodeCharactersFromJson(dynamic raw) {
    if (raw == null) return null;
    try {
      if (raw is String) return raw;
      if (raw is List) {
        return jsonEncode(raw);
      }
    } catch (_) {
      return null;
    }
    return null;
  }

  List<Character> _decodeCharacters() {
    if (charactersJson == null || charactersJson!.isEmpty) {
      return [];
    }
    try {
      final decoded = jsonDecode(charactersJson!);
      if (decoded is List) {
        return decoded
            .whereType<Map<String, dynamic>>()
            .map(Character.fromJson)
            .toList();
      }
    } catch (_) {
      // Ignore malformed payloads and default to empty list.
    }
    return [];
  }
}
