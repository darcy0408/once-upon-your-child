// Stub implementation of OfflineStoryService for web platform
// Uses SharedPreferences for local story persistence

import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/local/story_local.dart';

class OfflineStoryService {
  static const String _storageKey = 'isar_stories';

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
    
    int index = stories.indexWhere((s) => s['id'] == story.id || (story.storyId.isNotEmpty && s['storyId'] == story.storyId));
    
    if (index >= 0) {
      stories[index] = storyData;
    } else {
      stories.add(storyData);
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
