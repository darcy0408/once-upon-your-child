import 'dart:convert';

import 'models.dart';
import 'models/cached_story.dart';
import 'services/isar_service.dart';

class OfflineStoryCache {
  static const int _maxCachedStories = 50;

  Future<void> cacheStory(CachedStory cachedStory) async {
    await IsarService.cacheOrUpdateStory(cachedStory);
    await _enforceLimit();
  }

  Future<void> cacheSavedStory(SavedStory story) async {
    await IsarService.cacheStory(story);
    await _enforceLimit();
  }

  Future<List<CachedStory>> getAllCachedStories() {
    return IsarService.isar.cachedStorys
        .where()
        .sortByCachedAtDesc()
        .findAll();
  }

  Future<List<CachedStory>> getFavoriteStories() {
    return IsarService.isar.cachedStorys
        .filter()
        .isFavoriteEqualTo(true)
        .sortByCachedAtDesc()
        .findAll();
  }

  Future<CachedStory?> getCachedStory(String storyId) {
    return _findByStoryId(storyId);
  }

  Future<CacheStatistics> getCacheStatistics() async {
    final stories = await getAllCachedStories();
    final totalStories = stories.length;
    final favoriteCount = stories.where((s) => s.isFavorite).length;

    final payload = jsonEncode(stories.map((story) => {
          'storyId': story.storyId,
          'title': story.title,
          'theme': story.theme,
          'cachedAt': story.cachedAt.toIso8601String(),
          'isFavorite': story.isFavorite,
        }).toList());
    final sizeInKB = (utf8.encode(payload).length / 1024).round();

    return CacheStatistics(
      totalStories: totalStories,
      favoriteCount: favoriteCount,
      sizeInKB: sizeInKB,
      oldestStory: stories.isEmpty
          ? null
          : stories.reduce((a, b) =>
              a.cachedAt.isBefore(b.cachedAt) ? a : b).cachedAt,
      newestStory: stories.isEmpty
          ? null
          : stories.reduce((a, b) =>
              a.cachedAt.isAfter(b.cachedAt) ? a : b).cachedAt,
    );
  }

  Future<void> toggleFavorite(String storyId) async {
    await IsarService.toggleFavorite(storyId);
  }

  Future<void> deleteCachedStory(String storyId) async {
    await IsarService.deleteCachedStory(storyId);
  }

  Future<void> clearCache({bool includeFavorites = false}) async {
    await IsarService.clearCache(includeFavorites: includeFavorites);
  }

  Future<bool> isStoryCached(String storyId) async {
    return (await _findByStoryId(storyId)) != null;
  }

  Future<CachedStory?> _findByStoryId(String storyId) {
    return IsarService.findStory(storyId);
  }

  Future<void> _enforceLimit() async {
    await IsarService.enforceCacheLimit(_maxCachedStories);
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
    }
    final sizeInMB = (sizeInKB / 1024).toStringAsFixed(2);
    return '$sizeInMB MB';
  }
}
