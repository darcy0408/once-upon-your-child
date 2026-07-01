import 'package:isar/isar.dart';

import '../models.dart';
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

  Future<StoryLocal?> getStory(String storyId) async {
    return _findByIdentifier(storyId);
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

  // Interactive adventure story methods

  /// Get all in-progress interactive stories (not completed)
  Future<List<StoryLocal>> getInProgressStories() async {
    return _isar.storyLocals
        .filter()
        .isInteractiveEqualTo(true)
        .isCompletedEqualTo(false)
        .sortByCreatedAtDesc()
        .findAll();
  }

  /// Get all completed interactive stories
  Future<List<StoryLocal>> getCompletedInteractiveStories() async {
    return _isar.storyLocals
        .filter()
        .isInteractiveEqualTo(true)
        .isCompletedEqualTo(true)
        .sortByCreatedAtDesc()
        .findAll();
  }

  /// Build a StoryLocal from raw interactive-progress fields and upsert it.
  ///
  /// Lets shared UI code persist progress without referencing the io-only
  /// interactive columns (segment number, inventory, state, tone, length) that
  /// the web StoryLocal stub does not define. The web stub mirrors this method
  /// with a partial implementation.
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
    final story = StoryLocal.fromInteractiveStory(
      storyId: storyId,
      title: title,
      theme: theme,
      tone: tone,
      length: length,
      currentSegmentNumber: currentSegmentNumber,
      isCompleted: isCompleted,
      createdAt: createdAt,
      inventory: inventory,
      state: state,
      characters: characters,
    );
    await saveInteractiveProgress(story);
  }

  /// Save or update interactive story progress
  Future<void> saveInteractiveProgress(StoryLocal story) async {
    if (!story.isInteractive) {
      story.isInteractive = true;
    }

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

  /// Load interactive story progress
  Future<StoryLocal?> loadInteractiveProgress(String storyId) async {
    return _isar.storyLocals
        .filter()
        .storyIdEqualTo(storyId)
        .isInteractiveEqualTo(true)
        .findFirst();
  }

  /// Mark interactive story as completed
  Future<void> markInteractiveAsCompleted(String storyId,
      {String? finalStoryText}) async {
    final story = await _findByIdentifier(storyId);
    if (story == null) return;

    story.isCompleted = true;
    if (finalStoryText != null && finalStoryText.isNotEmpty) {
      story.storyText = finalStoryText;
    }

    await _isar.writeTxn(() async {
      await _isar.storyLocals.put(story);
    });
  }

  /// Delete interactive story progress (only if not completed)
  Future<bool> deleteInteractiveProgress(String storyId) async {
    final story = await _findByIdentifier(storyId);
    if (story == null || !story.isInteractive) return false;

    // Don't allow deleting completed stories through this method
    if (story.isCompleted) return false;

    await _isar.writeTxn(() async {
      await _isar.storyLocals.delete(story.id);
    });

    return true;
  }
}
