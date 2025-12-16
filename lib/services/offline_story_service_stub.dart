// Stub implementation for web platform
import '../models/local/story_local.dart';

class OfflineStoryService {
  // Stub constructor that accepts any argument
  OfflineStoryService(dynamic _isar);

  Future<void> saveStory(StoryLocal story) async {
    // No-op on web, use API calls instead
  }

  Future<List<StoryLocal>> getAllStories() async {
    return [];
  }

  Future<List<StoryLocal>> getFavorites() async {
    return [];
  }

  Future<void> toggleFavorite(String storyId) async {
    // No-op
  }

  Future<void> deleteStory(String storyId) async {
    // No-op
  }

  Future<void> updateStory(StoryLocal story) async {
    // No-op
  }

  Future<StoryLocal?> getStory(String storyId) async {
    return null;
  }
}
