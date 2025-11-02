import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

import 'models.dart';

/// Local persistence for stories (v2).
/// Stores a JSON array of SavedStory objects under the key [_kStoriesV2].
class StorageService {
  static const String _kStoriesV2 = 'saved_stories_v2';

  /// Load all saved stories (new v2 format). Also migrates legacy v1 if found.
  Future<List<SavedStory>> loadStories() async {
    final prefs = await SharedPreferences.getInstance();

    // Try v2 first
    final v2Raw = prefs.getString(_kStoriesV2);
    if (v2Raw != null && v2Raw.isNotEmpty) {
      final list = (jsonDecode(v2Raw) as List)
          .map((e) => SavedStory.fromJson(e as Map<String, dynamic>))
          .toList();
      return list;
    }

    // No v2 found: migrate older plain text list if you had one in the past (optional).
    // If you never stored legacy stories, you can remove this whole migration block.
    // Example of a legacy key:
    // final legacy = prefs.getStringList('saved_stories');
    // if (legacy != null && legacy.isNotEmpty) {
    //   final migrated = legacy.map((text) {
    //     return SavedStory(
    //       title: 'Saved Story',
    //       storyText: text,
    //       theme: 'Adventure',
    //       characters: const <Character>[],
    //       createdAt: DateTime.now(),
    //     );
    //   }).toList();
    //   await _saveAll(migrated);
    //   await prefs.remove('saved_stories');
    //   return migrated;
    // }

    return <SavedStory>[];
  }

  /// Save (append) one story.
  Future<void> saveStory(SavedStory story) async {
    final list = await loadStories();
    list.insert(0, story); // newest first
    await _saveAll(list);
  }

  /// Delete story by index (as shown in UI list).
  Future<void> deleteStoryAt(int index) async {
    final list = await loadStories();
    if (index < 0 || index >= list.length) return;
    list.removeAt(index);
    await _saveAll(list);
  }

  /// Toggle favorite status for a story by ID.
  Future<void> toggleFavorite(String storyId) async {
    final list = await loadStories();
    final index = list.indexWhere((s) => s.id == storyId);
    if (index == -1) return;

    list[index] = list[index].copyWith(isFavorite: !list[index].isFavorite);
    await _saveAll(list);
  }

  /// Update an existing story by ID.
  Future<void> updateStory(SavedStory updatedStory) async {
    final list = await loadStories();
    final index = list.indexWhere((s) => s.id == updatedStory.id);
    if (index == -1) {
      // If not found, add it
      list.insert(0, updatedStory);
    } else {
      list[index] = updatedStory;
    }
    await _saveAll(list);
  }

  /// Find a story by ID.
  Future<SavedStory?> findStoryById(String storyId) async {
    final list = await loadStories();
    try {
      return list.firstWhere((s) => s.id == storyId);
    } catch (_) {
      return null;
    }
  }

  /// Clear all stories (optional – not used by default UI).
  Future<void> clearAll() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_kStoriesV2);
  }

  // -----------------------------
  // Internal helpers
  // -----------------------------
  Future<void> _saveAll(List<SavedStory> list) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = jsonEncode(list.map((e) => e.toJson()).toList());
    await prefs.setString(_kStoriesV2, raw);
  }
}
