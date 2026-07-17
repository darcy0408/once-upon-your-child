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
  bool isRhyming = false;
  bool isLearningToRead = false;
  String? wisdomGem;
  String? charactersJson;

  // Interactive adventure story progress fields
  int? currentSegmentNumber;
  String? inventoryJson; // JSON string of InventoryItemData list
  String? stateJson; // JSON string of StoryStateData
  bool isCompleted = false;
  String? tone; // whimsical, mystery, sci-fi, fantasy, cozy-adventure
  String? length; // short, medium, long

  // Persisted illustrations so a re-opened story shows its pictures without
  // regenerating them (regeneration costs server money/time).
  String? coverImageBase64; // base64 of the cover illustration bytes
  String?
      pageIllustrationsJson; // JSON array of base64 strings, indexed by page

  // PDF export (premium keepsake feature): the true page-by-page split used
  // when this story was displayed/saved. Without this a re-opened story only
  // has flat `storyText`, so exporting an older save falls back to a
  // best-effort paragraph split — see StoryPdfService. Additive Isar field;
  // old rows deserialize with this null.
  String? pagesJson; // JSON array of page strings, in reading order

  // Story Notes (MT-254): the parent-selected focus(es) this story was guided
  // toward (comma-joined Big Feelings trigger values). Persisted so a re-opened
  // guided story still offers the "Why this story? 💛" disclosure. Null for
  // ordinary stories.
  String? practiced;

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
      ..isRhyming = json['isRhyming'] ?? json['is_rhyming'] ?? false
      ..isLearningToRead =
          json['isLearningToRead'] ?? json['is_learning_to_read'] ?? false
      ..wisdomGem = json['wisdomGem'] ?? json['wisdom_gem']
      ..charactersJson = _encodeCharactersFromJson(json['characters'])
      ..coverImageBase64 =
          json['coverImageBase64'] ?? json['cover_image_base64']
      ..pageIllustrationsJson =
          json['pageIllustrationsJson'] ?? json['page_illustrations_json']
      ..pagesJson = _encodePagesFromJson(
          json['pagesJson'] ?? json['pages_json'] ?? json['pages'])
      ..practiced = json['practiced'] ?? json['practiced_focus']
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
      ..isRhyming = savedStory.isRhyming
      ..isLearningToRead = savedStory.isLearningToRead
      ..wisdomGem = savedStory.wisdomGem
      ..charactersJson = _encodeCharacters(savedStory.characters)
      ..coverImageBase64 = savedStory.coverImageBase64
      ..pageIllustrationsJson = savedStory.pageIllustrationsJson
      ..pagesJson = (savedStory.pages != null && savedStory.pages!.isNotEmpty)
          ? jsonEncode(savedStory.pages)
          : null;
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
        'isRhyming': isRhyming,
        'isLearningToRead': isLearningToRead,
        'wisdomGem': wisdomGem,
        'characters': _decodeCharacters().map((c) => c.toJson()).toList(),
        'coverImageBase64': coverImageBase64,
        'pageIllustrationsJson': pageIllustrationsJson,
        'pagesJson': pagesJson,
        'practiced': practiced,
      };

  /// Decoded page-by-page text, preferring [pagesJson] when present. Returns
  /// an empty list (never throws) for null/malformed payloads so callers can
  /// fall back to splitting flat [storyText] instead.
  @ignore
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

  @ignore
  List<Character> get characters => _decodeCharacters();

  @ignore
  String get identifier => storyId.isNotEmpty ? storyId : id.toString();

  static String? _encodeCharacters(List<Character> characters) {
    if (characters.isEmpty) return null;
    return jsonEncode(characters.map((c) => c.toJson()).toList());
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

  // Interactive story progress helpers
  @ignore
  List<InventoryItemData> get inventory => _decodeInventory();

  @ignore
  StoryStateData? get state => _decodeState();

  List<InventoryItemData> _decodeInventory() {
    if (inventoryJson == null || inventoryJson!.isEmpty) {
      return [];
    }
    try {
      final decoded = jsonDecode(inventoryJson!) as List;
      return decoded
          .whereType<Map<String, dynamic>>()
          .map(InventoryItemData.fromJson)
          .toList();
    } catch (_) {
      return [];
    }
  }

  StoryStateData? _decodeState() {
    if (stateJson == null || stateJson!.isEmpty) {
      return null;
    }
    try {
      final decoded = jsonDecode(stateJson!) as Map<String, dynamic>;
      return StoryStateData.fromJson(decoded);
    } catch (_) {
      return null;
    }
  }

  static String? _encodeInventory(List<InventoryItemData>? inventory) {
    if (inventory == null || inventory.isEmpty) return null;
    return jsonEncode(inventory.map((i) => i.toJson()).toList());
  }

  static String? _encodeState(StoryStateData? state) {
    if (state == null) return null;
    return jsonEncode(state.toJson());
  }

  /// Create StoryLocal from InteractiveStoryData for progress tracking
  static StoryLocal fromInteractiveStory({
    required String storyId,
    required String title,
    required String theme,
    required String tone,
    required String length,
    required int currentSegmentNumber,
    required bool isCompleted,
    required DateTime createdAt,
    List<InventoryItemData>? inventory,
    StoryStateData? state,
    List<Character>? characters,
  }) {
    return StoryLocal()
      ..storyId = storyId
      ..title = title
      ..storyText = '' // Will be filled when completed
      ..theme = theme
      ..tone = tone
      ..length = length
      ..isInteractive = true
      ..currentSegmentNumber = currentSegmentNumber
      ..inventoryJson = _encodeInventory(inventory)
      ..stateJson = _encodeState(state)
      ..isCompleted = isCompleted
      ..createdAt = createdAt
      ..charactersJson = _encodeCharacters(characters ?? []);
  }
}
