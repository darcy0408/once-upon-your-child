// lib/offline_story_cache.dart

import 'package:isar/isar.dart';

import 'models/cached_story.dart';
import 'services/isar_service.dart';

class OfflineStoryCache {
  static const int _maxCachedStories = 50;

  Future<void> cacheStory(CachedStory cachedStory) async {
    final existing = await _findByStoryId(cachedStory.storyId);
    if (existing != null) {
      cachedStory.id = existing.id;
    }

    await IsarService.isar.writeTxn(() async {
      await IsarService.isar.cachedStorys.put(cachedStory);
      await _enforceLimit();
    });
  }

  Future<List<CachedStory>> getAllCachedStories() async {
    return IsarService.isar.cachedStorys.where().sortByCreatedAtDesc().findAll();
  }

  Future<List<CachedStory>> getFavoriteStories() async {
    return IsarService.isar.cachedStorys
        .filter()
        .isFavoriteEqualTo(true)
        .sortByCreatedAtDesc()
        .findAll();
  }

  Future<CachedStory?> getCachedStory(String storyId) async {
    return _findByStoryId(storyId);
  }

  Future<void> toggleFavorite(String storyId) async {
    final story = await _findByStoryId(storyId);
    if (story == null) return;
    await IsarService.isar.writeTxn(() async {
      story.isFavorite = !(story.isFavorite ?? false);
      await IsarService.isar.cachedStorys.put(story);
    });
  }

  Future<void> deleteCachedStory(String storyId) async {
    final story = await _findByStoryId(storyId);
    if (story == null) return;
    await IsarService.isar.writeTxn(() async {
      await IsarService.isar.cachedStorys.delete(story.id);
    });
  }

  Future<void> clearCache({bool includeFavorites = false}) async {
    if (includeFavorites) {
      await IsarService.isar.writeTxn(() =>
          IsarService.isar.cachedStorys.where().deleteAll());
    } else {
      final nonFavorites = await IsarService.isar.cachedStorys
          .filter()
          .isFavoriteEqualTo(false)
          .findAll();
      await IsarService.isar.writeTxn(() async {
        for (final story in nonFavorites) {
          await IsarService.isar.cachedStorys.delete(story.id);
        }
      });
    }
  }

  Future<bool> isStoryCached(String storyId) async {
    return (await _findByStoryId(storyId)) != null;
  }

  Future<CachedStory?> _findByStoryId(String storyId) {
    return IsarService.isar.cachedStorys
        .filter()
        .storyIdEqualTo(storyId)
        .findFirst();
  }

  Future<void> _enforceLimit() async {
    final count = await IsarService.isar.cachedStorys.count();
    if (count <= _maxCachedStories) return;

    final overflow = count - _maxCachedStories;
    final oldest = await IsarService.isar.cachedStorys
        .where()
        .sortByCreatedAt()
        .limit(overflow)
        .findAll();
    await IsarService.isar.cachedStorys.deleteAll(oldest.map((s) => s.id).toList());
  }
}
