import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../models/local/story_local.dart';
import '../services/isar_service.dart';
import '../services/offline_story_service.dart';

part 'story_provider.g.dart';

@riverpod
OfflineStoryService offlineStoryService(OfflineStoryServiceRef ref) {
  return OfflineStoryService(IsarService.instance);
}

@riverpod
class StoryList extends _$StoryList {
  @override
  Future<List<StoryLocal>> build() async {
    final service = ref.watch(offlineStoryServiceProvider);
    return service.getAllStories();
  }

  Future<void> refresh() async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      final service = ref.read(offlineStoryServiceProvider);
      return service.getAllStories();
    });
  }

  Future<void> toggleFavorite(String storyId) async {
    final service = ref.read(offlineStoryServiceProvider);
    await service.toggleFavorite(storyId);
    await refresh();
  }

  Future<void> deleteStory(String storyId) async {
    final service = ref.read(offlineStoryServiceProvider);
    await service.deleteStory(storyId);
    await refresh();
  }
}

@riverpod
class FavoriteStories extends _$FavoriteStories {
  @override
  Future<List<StoryLocal>> build() async {
    final service = ref.watch(offlineStoryServiceProvider);
    return service.getFavorites();
  }
}
