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

  // Persisted illustrations so a re-opened story shows its pictures without
  // regenerating them (regeneration costs server money/time).
  String? coverImageBase64; // base64 of the cover illustration bytes
  String?
      pageIllustrationsJson; // JSON array of base64 strings, indexed by page

  // PDF export (premium keepsake feature): mirrors story_local_io.dart's
  // pagesJson field. Keep both in sync — this file has no codegen, so it is
  // just a plain field, but the shape (JSON array of page strings) must match.
  String? pagesJson;

  // Story Notes (MT-254): parent-selected focus(es) this story was guided
  // toward. Persisted so a re-opened guided story still offers the disclosure.
  String? practiced;

  static StoryLocal fromJson(Map<String, dynamic> json) {
    return StoryLocal()
      ..storyId = json['storyId']?.toString() ?? ''
      ..title = json['title']?.toString() ?? ''
      ..storyText =
          json['storyText']?.toString() ?? json['story_text']?.toString() ?? ''
      ..theme = json['theme']?.toString() ?? ''
      ..isFavorite = json['isFavorite'] == true
      ..imageUrl = json['imageUrl']?.toString() ?? json['image_url']?.toString()
      ..createdAt = json['createdAt'] != null
          ? (DateTime.tryParse(json['createdAt'].toString()) ?? DateTime.now())
          : DateTime.now()
      ..isSyncedToServer = json['isSyncedToServer'] == true
      ..isInteractive = json['isInteractive'] == true
      ..wisdomGem = json['wisdomGem']?.toString()
      ..charactersJson = json['charactersJson']?.toString()
      ..coverImageBase64 = json['coverImageBase64']?.toString()
      ..pageIllustrationsJson = json['pageIllustrationsJson']?.toString()
      ..pagesJson = _encodePagesFromJson(
          json['pagesJson'] ?? json['pages_json'] ?? json['pages'])
      ..practiced =
          json['practiced']?.toString() ?? json['practiced_focus']?.toString();
  }

  static String? _encodePagesFromJson(dynamic raw) {
    if (raw == null) return null;
    try {
      if (raw is String) return raw.isEmpty ? null : raw;
      if (raw is List) {
        return raw.isEmpty
            ? null
            : jsonEncode(raw.map((e) => e.toString()).toList());
      }
    } catch (_) {
      return null;
    }
    return null;
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
          : null
      ..coverImageBase64 = saved.coverImageBase64
      ..pageIllustrationsJson = saved.pageIllustrationsJson
      ..pagesJson = (saved.pages != null && saved.pages!.isNotEmpty)
          ? jsonEncode(saved.pages)
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
      'coverImageBase64': coverImageBase64,
      'pageIllustrationsJson': pageIllustrationsJson,
      'pagesJson': pagesJson,
      'practiced': practiced,
    };
  }

  List<Character> get characters => _decodeCharacters();

  /// Decoded page-by-page text, preferring [pagesJson] when present. Returns
  /// an empty list (never throws) for null/malformed payloads so callers can
  /// fall back to splitting flat [storyText] instead.
  List<String> get pages {
    if (pagesJson == null || pagesJson!.isEmpty) return const [];
    try {
      final decoded = jsonDecode(pagesJson!);
      if (decoded is List) {
        return decoded.map((e) => e.toString()).toList();
      }
    } catch (_) {
      // Ignore malformed payloads and default to empty list.
    }
    return const [];
  }

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
