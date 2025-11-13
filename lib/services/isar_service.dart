import 'package:isar/isar.dart';
import 'package:path_provider/path_provider.dart';

import '../models.dart';
import '../models/cached_story.dart';

class IsarService {
  static Isar? _isar;

  static Isar get isar {
    final instance = _isar;
    if (instance == null) {
      throw StateError('IsarService.initialize must be called before use.');
    }
    return instance;
  }

  static bool get isInitialized => _isar != null;

  static Future<void> initialize({String? directoryPath}) async {
    if (isInitialized) return;

    final dirPath =
        directoryPath ?? (await getApplicationDocumentsDirectory()).path;

    _isar = await Isar.open(
      [CachedStorySchema, CachedCharacterSchema],
      directory: dirPath,
    );
  }

  static Future<void> close() async {
    final instance = _isar;
    if (instance != null) {
      await instance.close();
      _isar = null;
    }
  }

  static Future<void> cacheStory(SavedStory story) async {
    final cached = _mapSavedStory(story);
    await isar.writeTxn(() async {
      final existing = await isar.cachedStorys
          .filter()
          .storyIdEqualTo(story.id)
          .findFirst();
      if (existing != null) {
        cached.id = existing.id;
        cached.isFavorite = existing.isFavorite;
        await _deleteCharacters(existing);
      }
      final id = await isar.cachedStorys.put(cached);
      final persisted = await isar.cachedStorys.get(id);
      if (persisted != null) {
        await _saveCharacters(persisted, story.characters);
      }
    });
  }

  static Future<void> cacheOrUpdateStory(CachedStory cachedStory) async {
    final existing = await findStory(cachedStory.storyId);
    if (existing != null) {
      cachedStory.id = existing.id;
      cachedStory.isFavorite = existing.isFavorite;
      cachedStory.cachedAt = cachedStory.cachedAt.isAfter(existing.cachedAt)
          ? cachedStory.cachedAt
          : existing.cachedAt;
    }
    await updateCachedStory(cachedStory);
  }

  static Future<void> updateCachedStory(CachedStory cachedStory) async {
    await isar.writeTxn(() async {
      await isar.cachedStorys.put(cachedStory);
    });
  }

  static Future<void> deleteCachedStory(String storyId) async {
    final story = await findStory(storyId);
    if (story == null) return;
    await isar.writeTxn(() async {
      await _deleteCharacters(story);
      await isar.cachedStorys.delete(story.id);
    });
  }

  static Future<void> toggleFavorite(String storyId) async {
    final story = await findStory(storyId);
    if (story == null) return;
    await isar.writeTxn(() async {
      story.isFavorite = !story.isFavorite;
      await isar.cachedStorys.put(story);
    });
  }

  static Future<void> clearCache({bool includeFavorites = false}) async {
    final stories = includeFavorites
        ? await isar.cachedStorys.where().findAll()
        : await isar.cachedStorys
            .filter()
            .isFavoriteEqualTo(false)
            .findAll();
    if (stories.isEmpty) return;

    await isar.writeTxn(() async {
      for (final story in stories) {
        await _deleteCharacters(story);
        await isar.cachedStorys.delete(story.id);
      }
    });
  }

  static Future<void> enforceCacheLimit(int maxStories) async {
    final count = await isar.cachedStorys.count();
    if (count <= maxStories) return;

    final overflow = count - maxStories;
    final oldest = await isar.cachedStorys
        .where()
        .sortByCachedAt()
        .limit(overflow)
        .findAll();
    if (oldest.isEmpty) return;

    await isar.writeTxn(() async {
      for (final story in oldest) {
        await _deleteCharacters(story);
        await isar.cachedStorys.delete(story.id);
      }
    });
  }

  static Future<List<CachedStory>> getCachedStories({bool favoritesOnly = false}) {
    if (favoritesOnly) {
      return isar.cachedStorys
          .filter()
          .isFavoriteEqualTo(true)
          .sortByCachedAtDesc()
          .findAll();
    }

    return isar.cachedStorys.where().sortByCachedAtDesc().findAll();
  }

  static Future<CachedStory?> findStory(String storyId) {
    return isar.cachedStorys.filter().storyIdEqualTo(storyId).findFirst();
  }

  static CachedStory _mapSavedStory(SavedStory story) {
    final primaryCharacter =
        story.characters.isNotEmpty ? story.characters.first : null;

    return CachedStory()
      ..storyId = story.id
      ..title = story.title
      ..storyText = story.storyText
      ..theme = story.theme
      ..wisdomGem = story.wisdomGem
      ..createdAt = story.createdAt
      ..cachedAt = DateTime.now()
      ..characterId = primaryCharacter?.id
      ..characterName = primaryCharacter?.name ?? 'Unknown'
      ..isFavorite = story.isFavorite;
  }

  static Future<void> _saveCharacters(
    CachedStory story,
    List<Character> characters,
  ) async {
    await story.characters.load();
    await story.characters.reset();
    if (characters.isEmpty) return;

    final cachedCharacters = characters.map(_mapCharacter).toList();
    await isar.cachedCharacters.putAll(cachedCharacters);
    story.characters.addAll(cachedCharacters);
    await story.characters.save();
  }

  static Future<void> _deleteCharacters(CachedStory story) async {
    await story.characters.load();
    if (story.characters.isEmpty) return;
    final ids = story.characters.map((c) => c.id).toList();
    await story.characters.reset();
    await story.characters.save();
    await isar.cachedCharacters.deleteAll(ids);
  }

  static CachedCharacter _mapCharacter(Character character) {
    return CachedCharacter()
      ..characterId = character.id
      ..name = character.name
      ..age = character.age
      ..gender = character.gender
      ..role = character.role
      ..hair = character.hair
      ..eyes = character.eyes
      ..skinTone = character.skinTone
      ..hairstyle = character.hairstyle
      ..currentEmotion = character.currentEmotion
      ..comfortItem = character.comfortItem;
  }
}
