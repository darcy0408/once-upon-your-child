import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:story_weaver_app/offline_story_cache.dart';

CachedStory createStory(String id, {bool favorite = false}) {
  return CachedStory(
    id: id,
    title: 'Story $id',
    storyText: 'Once upon a time $id',
    characterName: 'Hero',
    theme: 'Adventure',
    cachedAt: DateTime.now(),
    isFavorite: favorite,
  );
}

void main() {
  late OfflineStoryCache cache;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    cache = OfflineStoryCache();
  });

  test('cacheStory persists and getCachedStory returns it', () async {
    final story = createStory('abc');
    await cache.cacheStory(story);

    final fetched = await cache.getCachedStory('abc');
    expect(fetched, isNotNull);
    expect(fetched!.title, story.title);
  });

  test('toggleFavorite flips favorite flag', () async {
    final story = createStory('fav');
    await cache.cacheStory(story);

    await cache.toggleFavorite('fav');
    final toggled = await cache.getCachedStory('fav');
    expect(toggled!.isFavorite, isTrue);
  });

  test('clearCache keeps favorites by default', () async {
    await cache.cacheStory(createStory('keep', favorite: true));
    await cache.cacheStory(createStory('drop'));

    await cache.clearCache();
    final favorites = await cache.getFavoriteStories();
    final leftovers = await cache.getAllCachedStories();

    expect(favorites.length, 1);
    expect(favorites.first.id, 'keep');
    expect(leftovers.length, 1);
  });
}
