import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models.dart';
import '../models/local/story_local.dart';
import 'isar_service.dart';
import 'offline_story_service.dart';

import 'package:flutter/foundation.dart';
class StorageMigration {
  static const _migrationFlagKey = 'isar_migration_complete';
  static const _cachedStoriesKey = 'cached_stories';
  static const _savedStoriesV2Key = 'saved_stories_v2';
  static const _offlineCacheKey = 'offline_story_cache';

  static Future<void> migrateFromSharedPreferences() async {
    final prefs = await SharedPreferences.getInstance();
    final migrated = prefs.getBool(_migrationFlagKey) ?? false;

    if (migrated) return;

    debugPrint('Starting migration from SharedPreferences to Isar...');

    final isar = await IsarService.getInstance();
    final offlineService = OfflineStoryService(isar);
    var migratedCount = 0;

    final cachedStories = prefs.getStringList(_cachedStoriesKey) ?? [];
    for (final storyJson in cachedStories) {
      try {
        final json = jsonDecode(storyJson) as Map<String, dynamic>;
        final story = StoryLocal.fromJson(json)..isSyncedToServer = true;
        await offlineService.saveStory(story);
        migratedCount++;
      } catch (e) {
        debugPrint('Failed to migrate cached story: $e');
      }
    }

    final savedStoriesRaw = prefs.getString(_savedStoriesV2Key);
    if (savedStoriesRaw != null && savedStoriesRaw.isNotEmpty) {
      try {
        final jsonList = jsonDecode(savedStoriesRaw) as List<dynamic>;
        for (final entry in jsonList) {
          if (entry is Map<String, dynamic>) {
            final saved = SavedStory.fromJson(entry);
            final story = StoryLocal.fromSavedStory(saved)..isSyncedToServer = true;
            await offlineService.saveStory(story);
            migratedCount++;
          }
        }
      } catch (e) {
        debugPrint('Failed to migrate saved stories: $e');
      }
    }

    final offlineCacheRaw = prefs.getString(_offlineCacheKey);
    if (offlineCacheRaw != null && offlineCacheRaw.isNotEmpty) {
      try {
        final jsonList = jsonDecode(offlineCacheRaw) as List<dynamic>;
        for (final entry in jsonList) {
          if (entry is Map<String, dynamic>) {
            final story = StoryLocal.fromJson(entry)..isSyncedToServer = true;
            await offlineService.saveStory(story);
            migratedCount++;
          }
        }
      } catch (e) {
        debugPrint('Failed to migrate offline cache: $e');
      }
    }

    await prefs.setBool(_migrationFlagKey, true);
    await prefs.remove(_cachedStoriesKey);
    await prefs.remove(_savedStoriesV2Key);
    await prefs.remove(_offlineCacheKey);

    debugPrint('Migration complete! Migrated $migratedCount stories.');
  }
}
