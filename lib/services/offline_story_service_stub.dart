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
import '../models/local/story_local.dart';

class OfflineStoryService {
  static const String _storageKey = 'isar_stories';

  /// Maximum number of stories that retain illustration data on web.
  /// Typical illustrated story: cover (~300 KB base64) + 5 pages (~250 KB each)
  /// = ~1.5 MB per story. Three stories ≈ 4.5 MB, safely under the 5 MB cap.
  static const int _maxIllustratedStories = 3;

  // Stub constructor that accepts any argument
  OfflineStoryService(dynamic isar);

  Future<void> saveStory(StoryLocal story) async {
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

    await prefs.setString(_storageKey, json.encode(stories));
  }

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

  Future<void> toggleFavorite(String storyId) async {
    final prefs = await SharedPreferences.getInstance();
    final String? storiesJson = prefs.getString(_storageKey);
    if (storiesJson == null) return;

    List<dynamic> stories = json.decode(storiesJson);
    int index = stories.indexWhere((s) => s['storyId'] == storyId);
    
    if (index >= 0) {
      stories[index]['isFavorite'] = !(stories[index]['isFavorite'] ?? false);
      await prefs.setString(_storageKey, json.encode(stories));
    }
  }

  Future<void> deleteStory(String storyId) async {
    final prefs = await SharedPreferences.getInstance();
    final String? storiesJson = prefs.getString(_storageKey);
    if (storiesJson == null) return;

    List<dynamic> stories = json.decode(storiesJson);
    stories.removeWhere((s) => s['storyId'] == storyId);
    await prefs.setString(_storageKey, json.encode(stories));
  }

  Future<void> updateStory(StoryLocal story) async {
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
