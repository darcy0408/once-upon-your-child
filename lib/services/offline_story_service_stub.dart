// Stub implementation of OfflineStoryService for web platform
// Uses SharedPreferences for local story persistence
//
// MT-130: SharedPreferences / localStorage has a ~5 MB ceiling. Base64-encoded
// illustrations can easily exceed that for multi-page stories. To stay safe on
// web we keep illustration data (coverImageBase64 + pageIllustrationsJson) for
// at most [_maxIllustratedStories] stories, ordered by most-recently saved.
// When the cap would be exceeded the oldest illustrated stories have their art
// fields stripped before writing — text and metadata are always preserved.
// This is a web-only guard; the native Isar path is unaffected.

import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models.dart';
import '../models/local/story_local.dart';

class OfflineStoryService {
  static const String _storageKey = 'isar_stories';

  /// Maximum number of stories that retain illustration data on web.
  /// Typical illustrated story: cover (~300 KB base64) + 5 pages (~250 KB each)
  /// = ~1.5 MB per story. Three stories ≈ 4.5 MB, safely under the 5 MB cap.
  static const int _maxIllustratedStories = 3;

  // Stub constructor that accepts any argument
  OfflineStoryService(dynamic isar);

  // BUG: every mutating method here did getString -> decode -> mutate ->
  // setString with no serialization, so two concurrent operations could each
  // read the same snapshot and the second setString would silently drop the
  // first's write. This mutex serializes the full read-modify-write cycle
  // against the single storage key (all instances share one localStorage key,
  // hence static).
  static Future<void> _writeLock = Future<void>.value();

  static Future<T> _synchronized<T>(Future<T> Function() action) {
    final Future<T> result = _writeLock.then((_) => action());
    // Keep the chain alive even if an action throws.
    _writeLock = result.then((_) {}, onError: (_) {});
    return result;
  }

  /// Writes [stories] to storage, evicting oldest entries if the browser's
  /// localStorage quota (~5 MB) rejects the write. Illustration art is dropped
  /// first (oldest illustrated story), then whole oldest stories as a last
  /// resort. Best-effort: returns without throwing if nothing is left to free.
  Future<void> _writeStories(
      SharedPreferences prefs, List<dynamic> stories) async {
    while (true) {
      try {
        await prefs.setString(_storageKey, json.encode(stories));
        return;
      } catch (_) {
        // setString throws QuotaExceededError on web when localStorage is full.
        if (!_evictOne(stories)) return;
      }
    }
  }

  /// Frees space in [stories]. Strips art from the oldest illustrated story if
  /// any carry art; otherwise removes the single oldest story (lowest id).
  /// Returns false when there is nothing left to evict.
  bool _evictOne(List<dynamic> stories) {
    int? artIdx;
    int? artId;
    int? anyIdx;
    int? anyId;
    for (int i = 0; i < stories.length; i++) {
      final s = stories[i] as Map<String, dynamic>;
      final id = (s['id'] as int?) ?? 0;
      if (anyId == null || id < anyId) {
        anyId = id;
        anyIdx = i;
      }
      final hasArt =
          s['coverImageBase64'] != null || s['pageIllustrationsJson'] != null;
      if (hasArt && (artId == null || id < artId)) {
        artId = id;
        artIdx = i;
      }
    }
    if (artIdx != null) {
      final s = Map<String, dynamic>.from(stories[artIdx] as Map<String, dynamic>);
      s.remove('coverImageBase64');
      s.remove('pageIllustrationsJson');
      stories[artIdx] = s;
      return true;
    }
    if (anyIdx != null) {
      stories.removeAt(anyIdx);
      return true;
    }
    return false;
  }

  Future<void> saveStory(StoryLocal story) => _synchronized(() async {
    final prefs = await SharedPreferences.getInstance();
    final String? storiesJson = prefs.getString(_storageKey);
    List<dynamic> stories = storiesJson != null ? json.decode(storiesJson) : [];

    if (story.id == 0) {
      story.id = DateTime.now().millisecondsSinceEpoch;
    }

    final storyData = story.toJson();

    int index = stories.indexWhere((s) =>
        s['id'] == story.id ||
        (story.storyId.isNotEmpty && s['storyId'] == story.storyId));

    if (index >= 0) {
      stories[index] = storyData;
    } else {
      stories.add(storyData);
    }

    // MT-130: enforce illustration cap to prevent exceeding the localStorage
    // 5 MB ceiling. Identify every story that carries image data and keep only
    // the [_maxIllustratedStories] most-recently saved ones; strip art from
    // the rest. "Most recent" == highest numeric `id` (millisecond timestamp).
    final bool incomingHasArt = story.coverImageBase64 != null ||
        story.pageIllustrationsJson != null;

    if (incomingHasArt) {
      // Collect indices of stories that have art, sorted newest-first by id.
      final illustrated = <int>[];
      for (int i = 0; i < stories.length; i++) {
        final s = stories[i] as Map<String, dynamic>;
        if (s['coverImageBase64'] != null || s['pageIllustrationsJson'] != null) {
          illustrated.add(i);
        }
      }
      illustrated.sort((a, b) {
        final idA = (stories[a] as Map<String, dynamic>)['id'] as int? ?? 0;
        final idB = (stories[b] as Map<String, dynamic>)['id'] as int? ?? 0;
        return idB.compareTo(idA); // descending
      });

      if (illustrated.length > _maxIllustratedStories) {
        // Strip art from the oldest excess entries.
        final toEvict = illustrated.sublist(_maxIllustratedStories);
        for (final idx in toEvict) {
          final s = Map<String, dynamic>.from(
              stories[idx] as Map<String, dynamic>);
          s.remove('coverImageBase64');
          s.remove('pageIllustrationsJson');
          stories[idx] = s;
        }
      }
    }

    await _writeStories(prefs, stories);
  });

  Future<List<StoryLocal>> getAllStories() async {
    final prefs = await SharedPreferences.getInstance();
    final String? storiesJson = prefs.getString(_storageKey);
    if (storiesJson == null) return [];

    List<dynamic> storiesData = json.decode(storiesJson);
    return storiesData.map((data) => StoryLocal.fromJson(data)).toList();
  }

  Future<List<StoryLocal>> getFavorites() async {
    final stories = await getAllStories();
    return stories.where((s) => s.isFavorite).toList();
  }

  Future<void> toggleFavorite(String storyId) => _synchronized(() async {
    final prefs = await SharedPreferences.getInstance();
    final String? storiesJson = prefs.getString(_storageKey);
    if (storiesJson == null) return;

    List<dynamic> stories = json.decode(storiesJson);
    int index = stories.indexWhere((s) => s['storyId'] == storyId);

    if (index >= 0) {
      stories[index]['isFavorite'] = !(stories[index]['isFavorite'] ?? false);
      await _writeStories(prefs, stories);
    }
  });

  Future<void> deleteStory(String storyId) => _synchronized(() async {
    final prefs = await SharedPreferences.getInstance();
    final String? storiesJson = prefs.getString(_storageKey);
    if (storiesJson == null) return;

    List<dynamic> stories = json.decode(storiesJson);
    stories.removeWhere((s) => s['storyId'] == storyId);
    await _writeStories(prefs, stories);
  });

  Future<void> updateStory(StoryLocal story) async {
    // Delegates to saveStory, which acquires the write lock itself — do not
    // wrap here or the nested lock acquisition would deadlock.
    await saveStory(story);
  }

  /// Web counterpart of the io [saveInteractiveProgressFields]. The web
  /// StoryLocal stub does not define the interactive columns (segment number,
  /// inventory, state, tone, length), so only the common fields are persisted;
  /// text/metadata survive a close/reopen, which is enough to avoid orphaning.
  Future<void> saveInteractiveProgressFields({
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
  }) async {
    final story = StoryLocal()
      ..storyId = storyId
      ..title = title
      ..theme = theme
      ..isInteractive = true
      ..createdAt = createdAt
      ..charactersJson = (characters != null && characters.isNotEmpty)
          ? jsonEncode(characters.map((c) => c.toJson()).toList())
          : null;
    // saveStory acquires the write lock.
    await saveStory(story);
  }

  Future<StoryLocal?> getStory(String storyId) async {
    final stories = await getAllStories();
    try {
      return stories.firstWhere((s) => s.storyId == storyId);
    } catch (_) {
      return null;
    }
  }
}
