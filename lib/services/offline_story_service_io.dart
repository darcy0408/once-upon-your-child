import 'package:isar/isar.dart';

import '../models/local/story_local_io.dart';

class OfflineStoryService {
  final Isar _isar;

  OfflineStoryService(this._isar);

  Future<void> saveStory(StoryLocal story) async {
    if (story.storyId.isEmpty) {
      story.storyId = DateTime.now().millisecondsSinceEpoch.toString();
    }

    await _isar.writeTxn(() async {
      final existing = await _isar.storyLocals
          .filter()
          .storyIdEqualTo(story.storyId)
          .findFirst();
      if (existing != null) {
        story.id = existing.id;
      }
      await _isar.storyLocals.put(story);
    });
  }

  Future<List<StoryLocal>> getAllStories() async {
    return _isar.storyLocals.where().sortByCreatedAtDesc().findAll();
  }

  Future<List<StoryLocal>> getFavorites() async {
    return _isar.storyLocals
        .filter()
        .isFavoriteEqualTo(true)
        .sortByCreatedAtDesc()
        .findAll();
  }

  Future<void> toggleFavorite(String storyId) async {
    final story = await _findByIdentifier(storyId);
    if (story == null) return;

    story.isFavorite = !story.isFavorite;
    await _isar.writeTxn(() async {
      await _isar.storyLocals.put(story);
    });
  }

  Future<void> deleteStory(String storyId) async {
    final story = await _findByIdentifier(storyId);
    if (story == null) return;

    await _isar.writeTxn(() async {
      await _isar.storyLocals.delete(story.id);
    });
  }

  Future<List<StoryLocal>> getUnsyncedStories() async {
    return _isar.storyLocals.filter().isSyncedToServerEqualTo(false).findAll();
  }

  Future<void> markAsSynced(String storyId) async {
    final story = await _findByIdentifier(storyId);
    if (story == null) return;

    story.isSyncedToServer = true;
    await _isar.writeTxn(() async {
      await _isar.storyLocals.put(story);
    });
  }

  Future<void> clearAll() async {
    await _isar.writeTxn(() async {
      await _isar.storyLocals.clear();
    });
  }

  Future<StoryLocal?> _findByIdentifier(String storyId) async {
    final match = await _isar.storyLocals.filter().storyIdEqualTo(storyId).findFirst();
    if (match != null) return match;

    final numericId = int.tryParse(storyId);
    if (numericId != null) {
      return _isar.storyLocals.get(numericId);
    }
    return null;
  }
}
