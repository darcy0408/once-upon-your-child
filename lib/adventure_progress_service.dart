// lib/adventure_progress_service.dart

import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'adventure_map_models.dart';

class AdventureProgressService {
  static const String _kProgressKey = 'adventure_progress';

  /// Load the current adventure progress
  Future<AdventureProgress> loadProgress() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_kProgressKey);

    if (raw != null && raw.isNotEmpty) {
      try {
        final json = jsonDecode(raw) as Map<String, dynamic>;
        return AdventureProgress.fromJson(json);
      } catch (e) {
        // If parsing fails, return default progress
        return _createDefaultProgress();
      }
    }

    return _createDefaultProgress();
  }

  /// Save adventure progress
  Future<void> saveProgress(AdventureProgress progress) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = jsonEncode(progress.toJson());
    await prefs.setString(_kProgressKey, raw);
  }

  /// Create default progress with home unlocked
  AdventureProgress _createDefaultProgress() {
    return AdventureProgress(
      locationProgress: {
        'home': LocationProgress(
          unlocked: true,
          completed: false,
          storiesCompleted: 0,
        ),
      },
      earnedBadges: [],
      totalStars: 0,
    );
  }

  /// Complete a story at a location
  Future<CompletionResult> completeStoryAtLocation({
    required String locationId,
    required String storyId,
    String? characterId,
  }) async {
    final progress = await loadProgress();
    final location = AdventureMapData.getAllLocations()
        .firstWhere((loc) => loc.id == locationId);

    // Get or create location progress
    var locProgress = progress.locationProgress[locationId] ??
        LocationProgress(unlocked: true);

    // Add story to completed stories
    final updatedStoryIds = [...locProgress.storyIds, storyId];
    final storiesCompleted = updatedStoryIds.length;

    // Check if location is now completed
    final isCompleted = storiesCompleted >= location.requiredStories;

    // Update location progress
    locProgress = locProgress.copyWith(
      unlocked: true,
      completed: isCompleted,
      storiesCompleted: storiesCompleted,
      storyIds: updatedStoryIds,
      completedAt: isCompleted ? DateTime.now() : locProgress.completedAt,
    );

    // Update earned badges and stars
    final earnedBadges = [...progress.earnedBadges];
    var totalStars = progress.totalStars;
    MapReward? newReward;

    if (isCompleted && !progress.earnedBadges.contains(location.reward.badgeId)) {
      earnedBadges.add(location.reward.badgeId);
      totalStars += location.reward.stars;
      newReward = location.reward;
    }

    // Update location progress map
    final updatedLocationProgress = Map<String, LocationProgress>.from(progress.locationProgress);
    updatedLocationProgress[locationId] = locProgress;

    // Unlock next locations if this one is completed
    List<MapLocation> newlyUnlocked = [];
    if (isCompleted) {
      final updatedProgress = progress.copyWith(
        locationProgress: updatedLocationProgress,
        earnedBadges: earnedBadges,
        totalStars: totalStars,
      );

      newlyUnlocked = _unlockNextLocations(updatedProgress, updatedLocationProgress);
    }

    // Save updated progress
    final finalProgress = progress.copyWith(
      locationProgress: updatedLocationProgress,
      earnedBadges: earnedBadges,
      totalStars: totalStars,
      currentCharacterId: characterId ?? progress.currentCharacterId,
    );

    await saveProgress(finalProgress);

    return CompletionResult(
      locationCompleted: isCompleted,
      newReward: newReward,
      newlyUnlockedLocations: newlyUnlocked,
      totalStars: totalStars,
    );
  }

  /// Unlock next available locations
  List<MapLocation> _unlockNextLocations(
    AdventureProgress progress,
    Map<String, LocationProgress> updatedLocationProgress,
  ) {
    final allLocations = AdventureMapData.getAllLocations();
    final newlyUnlocked = <MapLocation>[];

    for (var location in allLocations) {
      // Skip if already unlocked
      if (updatedLocationProgress[location.id]?.unlocked == true) {
        continue;
      }

      // Check if can be unlocked
      if (AdventureMapData.canUnlock(location, progress)) {
        updatedLocationProgress[location.id] = LocationProgress(
          unlocked: true,
          completed: false,
        );
        newlyUnlocked.add(location);
      }
    }

    return newlyUnlocked;
  }

  /// Get completion percentage
  Future<double> getCompletionPercentage() async {
    final progress = await loadProgress();
    final allLocations = AdventureMapData.getAllLocations();
    final completed = progress.locationProgress.values
        .where((lp) => lp.completed)
        .length;

    return completed / allLocations.length;
  }

  /// Reset all progress (for testing or new character)
  Future<void> resetProgress() async {
    await saveProgress(_createDefaultProgress());
  }

  /// Get all earned badges
  Future<List<MapReward>> getEarnedBadges() async {
    final progress = await loadProgress();
    final allLocations = AdventureMapData.getAllLocations();

    return allLocations
        .where((loc) => progress.earnedBadges.contains(loc.reward.badgeId))
        .map((loc) => loc.reward)
        .toList();
  }
}

/// Result of completing a story
class CompletionResult {
  final bool locationCompleted;
  final MapReward? newReward;
  final List<MapLocation> newlyUnlockedLocations;
  final int totalStars;

  CompletionResult({
    required this.locationCompleted,
    this.newReward,
    required this.newlyUnlockedLocations,
    required this.totalStars,
  });

  bool get hasNewReward => newReward != null;
  bool get hasNewLocations => newlyUnlockedLocations.isNotEmpty;
  bool get shouldCelebrate => hasNewReward || hasNewLocations;
}
