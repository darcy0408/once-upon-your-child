// lib/offline_story_cache.dart

import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

class CachedStory {
  final String id;
  final String title;
  final String storyText;
  final String characterName;
  final String theme;
  final String? companion;
  final DateTime cachedAt;
  final bool isFavorite;

  CachedStory({
    required this.id,
    required this.title,
    required this.storyText,
    required this.characterName,
    required this.theme,
    this.companion,
    required this.cachedAt,
    this.isFavorite = false,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'storyText': storyText,
      'characterName': characterName,
      'theme': theme,
      'companion': companion,
      'cachedAt': cachedAt.toIso8601String(),
      'isFavorite': isFavorite,
    };
  }

  factory CachedStory.fromJson(Map<String, dynamic> json) {
    return CachedStory(
      id: json['id'] as String,
      title: json['title'] as String,
      storyText: json['storyText'] as String,
      characterName: json['characterName'] as String,
      theme: json['theme'] as String,
      companion: json['companion'] as String?,
      cachedAt: DateTime.parse(json['cachedAt'] as String),
      isFavorite: json['isFavorite'] as bool? ?? false,
    );
  }
}

class OfflineStoryCache {
  static const String _cacheKey = 'offline_story_cache';
  static const int _maxCachedStories = 50; // Limit to prevent storage issues

  /// Cache a story for offline access
  Future<void> cacheStory(CachedStory story) async {
    final prefs = await SharedPreferences.getInstance();
    final stories = await getAllCachedStories();

    // Check if story already exists
    final existingIndex = stories.indexWhere((s) => s.id == story.id);
    if (existingIndex != -1) {
      // Update existing story
      stories[existingIndex] = story;
    } else {
      // Add new story
      stories.add(story);

      // Remove oldest stories if we exceed the limit
      if (stories.length > _maxCachedStories) {
        // Sort by cached date and remove oldest non-favorites
        stories.sort((a, b) => b.cachedAt.compareTo(a.cachedAt));
        final nonFavorites = stories.where((s) => !s.isFavorite).toList();
        if (nonFavorites.isNotEmpty) {
          stories.remove(nonFavorites.last);
        }
      }
    }

    // Save to SharedPreferences
    final jsonList = stories.map((s) => s.toJson()).toList();
    await prefs.setString(_cacheKey, jsonEncode(jsonList));
  }

  /// Get all cached stories
  Future<List<CachedStory>> getAllCachedStories() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonString = prefs.getString(_cacheKey);

    if (jsonString == null || jsonString.isEmpty) {
      return [];
    }

    try {
      final jsonList = jsonDecode(jsonString) as List;
      return jsonList.map((json) => CachedStory.fromJson(json as Map<String, dynamic>)).toList();
    } catch (e) {
      print('Error loading cached stories: $e');
      return [];
    }
  }

  /// Get a specific cached story by ID
  Future<CachedStory?> getCachedStory(String id) async {
    final stories = await getAllCachedStories();
    try {
      return stories.firstWhere((s) => s.id == id);
    } catch (e) {
      return null;
    }
  }

  /// Get recent stories (most recently cached first)
  Future<List<CachedStory>> getRecentStories({int limit = 10}) async {
    final stories = await getAllCachedStories();
    stories.sort((a, b) => b.cachedAt.compareTo(a.cachedAt));
    return stories.take(limit).toList();
  }

  /// Get favorite stories
  Future<List<CachedStory>> getFavoriteStories() async {
    final stories = await getAllCachedStories();
    return stories.where((s) => s.isFavorite).toList();
  }

  /// Toggle favorite status
  Future<void> toggleFavorite(String storyId) async {
    final stories = await getAllCachedStories();
    final index = stories.indexWhere((s) => s.id == storyId);

    if (index != -1) {
      final story = stories[index];
      stories[index] = CachedStory(
        id: story.id,
        title: story.title,
        storyText: story.storyText,
        characterName: story.characterName,
        theme: story.theme,
        companion: story.companion,
        cachedAt: story.cachedAt,
        isFavorite: !story.isFavorite,
      );

      final prefs = await SharedPreferences.getInstance();
      final jsonList = stories.map((s) => s.toJson()).toList();
      await prefs.setString(_cacheKey, jsonEncode(jsonList));
    }
  }

  /// Delete a cached story
  Future<void> deleteCachedStory(String storyId) async {
    final stories = await getAllCachedStories();
    stories.removeWhere((s) => s.id == storyId);

    final prefs = await SharedPreferences.getInstance();
    final jsonList = stories.map((s) => s.toJson()).toList();
    await prefs.setString(_cacheKey, jsonEncode(jsonList));
  }

  /// Clear all cached stories (except favorites)
  Future<void> clearCache({bool includeFavorites = false}) async {
    if (includeFavorites) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_cacheKey);
    } else {
      final stories = await getAllCachedStories();
      final favorites = stories.where((s) => s.isFavorite).toList();

      final prefs = await SharedPreferences.getInstance();
      final jsonList = favorites.map((s) => s.toJson()).toList();
      await prefs.setString(_cacheKey, jsonEncode(jsonList));
    }
  }

  /// Get cache statistics
  Future<CacheStatistics> getCacheStatistics() async {
    final stories = await getAllCachedStories();
    final totalStories = stories.length;
    final favoriteCount = stories.where((s) => s.isFavorite).length;

    // Calculate approximate storage size (rough estimate)
    final jsonString = jsonEncode(stories.map((s) => s.toJson()).toList());
    final sizeInBytes = utf8.encode(jsonString).length;
    final sizeInKB = (sizeInBytes / 1024).round();

    return CacheStatistics(
      totalStories: totalStories,
      favoriteCount: favoriteCount,
      sizeInKB: sizeInKB,
      oldestStory: stories.isEmpty ? null : stories.reduce((a, b) => a.cachedAt.isBefore(b.cachedAt) ? a : b).cachedAt,
      newestStory: stories.isEmpty ? null : stories.reduce((a, b) => a.cachedAt.isAfter(b.cachedAt) ? a : b).cachedAt,
    );
  }

  /// Check if a story is cached
  Future<bool> isStoryCached(String storyId) async {
    final story = await getCachedStory(storyId);
    return story != null;
  }
}

class CacheStatistics {
  final int totalStories;
  final int favoriteCount;
  final int sizeInKB;
  final DateTime? oldestStory;
  final DateTime? newestStory;

  CacheStatistics({
    required this.totalStories,
    required this.favoriteCount,
    required this.sizeInKB,
    this.oldestStory,
    this.newestStory,
  });

  String get formattedSize {
    if (sizeInKB < 1024) {
      return '$sizeInKB KB';
    } else {
      final sizeInMB = (sizeInKB / 1024).toStringAsFixed(2);
      return '$sizeInMB MB';
    }
  }
}
