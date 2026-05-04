// Stub implementation for web platform
import 'dart:convert';
import '../../models.dart';

class StoryLocal {
  int id = 0;
  String storyId = '';
  String title = '';
  String storyText = '';
  String theme = '';
  bool isFavorite = false;
  String? imageUrl;
  DateTime createdAt = DateTime.now();
  bool isSyncedToServer = false;
  bool isInteractive = false;
  String? wisdomGem;
  String? charactersJson;

  static StoryLocal fromJson(Map<String, dynamic> json) {
    return StoryLocal()
      ..storyId = json['storyId']?.toString() ?? ''
      ..title = json['title']?.toString() ?? ''
      ..storyText = json['storyText']?.toString() ?? json['story_text']?.toString() ?? ''
      ..theme = json['theme']?.toString() ?? ''
      ..isFavorite = json['isFavorite'] == true
      ..imageUrl = json['imageUrl']?.toString() ?? json['image_url']?.toString()
      ..createdAt = json['createdAt'] != null
          ? (DateTime.tryParse(json['createdAt'].toString()) ?? DateTime.now())
          : DateTime.now()
      ..isSyncedToServer = json['isSyncedToServer'] == true
      ..isInteractive = json['isInteractive'] == true
      ..wisdomGem = json['wisdomGem']?.toString()
      ..charactersJson = json['charactersJson']?.toString();
  }

  static StoryLocal fromSavedStory(SavedStory saved) {
    return StoryLocal()
      ..storyId = saved.id
      ..title = saved.title
      ..storyText = saved.storyText
      ..theme = saved.theme
      ..isFavorite = false
      ..createdAt = saved.createdAt
      ..isSyncedToServer = true
      ..charactersJson = saved.characters.isNotEmpty
          ? jsonEncode(saved.characters.map((c) => c.toJson()).toList())
          : null;
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'storyId': storyId,
      'title': title,
      'storyText': storyText,
      'theme': theme,
      'isFavorite': isFavorite,
      'imageUrl': imageUrl,
      'createdAt': createdAt.toIso8601String(),
      'isSyncedToServer': isSyncedToServer,
      'isInteractive': isInteractive,
      'wisdomGem': wisdomGem,
      'charactersJson': charactersJson,
    };
  }

  List<Character> get characters => _decodeCharacters();

  String get identifier => storyId.isNotEmpty ? storyId : id.toString();

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
      // Ignore malformed payloads
    }
    return [];
  }
}
