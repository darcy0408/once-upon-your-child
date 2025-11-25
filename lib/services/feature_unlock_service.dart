import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'api_service_manager.dart';

/// Service for managing progressive feature unlocks based on user engagement
class FeatureUnlockService {
  static const String _storiesCreatedKey = 'stories_created_count';
  static const String _unlocksKey = 'feature_unlocks';

  // Unlock thresholds
  static const int characterCreationThreshold = 1;
  static const int interactiveStoriesThreshold = 2;
  static const int coloringPagesThreshold = 3;
  static const int advancedSettingsThreshold = 5;

  final ApiServiceManager _apiService = ApiServiceManager();

  /// Get current stories created count
  Future<int> getStoriesCreatedCount() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_storiesCreatedKey) ?? 0;
  }

  /// Increment stories created count and sync with backend
  Future<void> incrementStoriesCreated(String? userId) async {
    final prefs = await SharedPreferences.getInstance();
    final currentCount = prefs.getInt(_storiesCreatedKey) ?? 0;
    final newCount = currentCount + 1;

    await prefs.setInt(_storiesCreatedKey, newCount);

    // Sync with backend if user is logged in
    if (userId != null) {
      try {
        await _apiService.post('/users/$userId/story-created', {});
      } catch (e) {
        debugPrint('Failed to sync story count with backend: $e');
        // Continue locally even if backend sync fails
      }
    }
  }

  /// Get feature unlock status
  Future<FeatureUnlockStatus> getUnlockStatus(String? userId) async {
    var storiesCreated = await getStoriesCreatedCount();

    // Check backend for latest data if user is logged in
    if (userId != null) {
      try {
        final response = await _apiService.get('/users/$userId/feature-unlocks');
        final backendCount = response['stories_created_count'] ?? storiesCreated;

        // Update local count if backend has higher count
        if (backendCount > storiesCreated) {
          final prefs = await SharedPreferences.getInstance();
          await prefs.setInt(_storiesCreatedKey, backendCount);
          storiesCreated = backendCount;
        }
      } catch (e) {
        debugPrint('Failed to fetch unlock status from backend: $e');
        // Continue with local data
      }
    }

    return FeatureUnlockStatus(
      storiesCreated: storiesCreated,
      characterCreationUnlocked: storiesCreated >= characterCreationThreshold,
      interactiveStoriesUnlocked: storiesCreated >= interactiveStoriesThreshold,
      coloringPagesUnlocked: storiesCreated >= coloringPagesThreshold,
      advancedSettingsUnlocked: storiesCreated >= advancedSettingsThreshold,
    );
  }

  /// Check if a specific feature is unlocked
  Future<bool> isFeatureUnlocked(FeatureType feature, String? userId) async {
    final status = await getUnlockStatus(userId);

    switch (feature) {
      case FeatureType.characterCreation:
        return status.characterCreationUnlocked;
      case FeatureType.interactiveStories:
        return status.interactiveStoriesUnlocked;
      case FeatureType.coloringPages:
        return status.coloringPagesUnlocked;
      case FeatureType.advancedSettings:
        return status.advancedSettingsUnlocked;
    }
  }

  /// Get unlock progress for a feature
  Future<UnlockProgress> getUnlockProgress(FeatureType feature, String? userId) async {
    final storiesCreated = await getStoriesCreatedCount();

    final threshold = switch (feature) {
      FeatureType.characterCreation => characterCreationThreshold,
      FeatureType.interactiveStories => interactiveStoriesThreshold,
      FeatureType.coloringPages => coloringPagesThreshold,
      FeatureType.advancedSettings => advancedSettingsThreshold,
    };

    final unlocked = storiesCreated >= threshold;
    final progress = (storiesCreated / threshold).clamp(0.0, 1.0);
    final remaining = threshold - storiesCreated;

    return UnlockProgress(
      feature: feature,
      unlocked: unlocked,
      currentProgress: progress,
      storiesRemaining: remaining > 0 ? remaining : 0,
      threshold: threshold,
    );
  }

  /// Get all unlock progress
  Future<List<UnlockProgress>> getAllUnlockProgress(String? userId) async {
    final results = <UnlockProgress>[];

    for (final feature in FeatureType.values) {
      final progress = await getUnlockProgress(feature, userId);
      results.add(progress);
    }

    return results;
  }

  /// Check for newly unlocked features and return celebration data
  Future<List<FeatureUnlockCelebration>> checkForNewUnlocks(String? userId) async {
    final prefs = await SharedPreferences.getInstance();
    final previouslyUnlocked = prefs.getStringList(_unlocksKey) ?? [];

    final currentStatus = await getUnlockStatus(userId);
    final newlyUnlocked = <FeatureUnlockCelebration>[];

    // Check each feature
    if (currentStatus.characterCreationUnlocked &&
        !previouslyUnlocked.contains('character_creation')) {
      newlyUnlocked.add(FeatureUnlockCelebration(
        feature: FeatureType.characterCreation,
        message: '🎉 Character Creation Unlocked!',
        description: 'You can now create and customize your own story characters!',
      ));
    }

    if (currentStatus.interactiveStoriesUnlocked &&
        !previouslyUnlocked.contains('interactive_stories')) {
      newlyUnlocked.add(FeatureUnlockCelebration(
        feature: FeatureType.interactiveStories,
        message: '🎉 Interactive Stories Unlocked!',
        description: 'Choose your own adventure with branching story paths!',
      ));
    }

    if (currentStatus.coloringPagesUnlocked &&
        !previouslyUnlocked.contains('coloring_pages')) {
      newlyUnlocked.add(FeatureUnlockCelebration(
        feature: FeatureType.coloringPages,
        message: '🎉 Coloring Pages Unlocked!',
        description: 'Create and color your own story illustrations!',
      ));
    }

    if (currentStatus.advancedSettingsUnlocked &&
        !previouslyUnlocked.contains('advanced_settings')) {
      newlyUnlocked.add(FeatureUnlockCelebration(
        feature: FeatureType.advancedSettings,
        message: '🎉 Advanced Settings Unlocked!',
        description: 'Access premium customization options and features!',
      ));
    }

    // Update stored unlocks
    final updatedUnlocks = [
      if (currentStatus.characterCreationUnlocked) 'character_creation',
      if (currentStatus.interactiveStoriesUnlocked) 'interactive_stories',
      if (currentStatus.coloringPagesUnlocked) 'coloring_pages',
      if (currentStatus.advancedSettingsUnlocked) 'advanced_settings',
    ];

    await prefs.setStringList(_unlocksKey, updatedUnlocks);

    return newlyUnlocked;
  }
}

/// Status of all feature unlocks
class FeatureUnlockStatus {
  final int storiesCreated;
  final bool characterCreationUnlocked;
  final bool interactiveStoriesUnlocked;
  final bool coloringPagesUnlocked;
  final bool advancedSettingsUnlocked;

  const FeatureUnlockStatus({
    required this.storiesCreated,
    required this.characterCreationUnlocked,
    required this.interactiveStoriesUnlocked,
    required this.coloringPagesUnlocked,
    required this.advancedSettingsUnlocked,
  });

  Map<String, dynamic> toJson() => {
        'stories_created': storiesCreated,
        'character_creation_unlocked': characterCreationUnlocked,
        'interactive_stories_unlocked': interactiveStoriesUnlocked,
        'coloring_pages_unlocked': coloringPagesUnlocked,
        'advanced_settings_unlocked': advancedSettingsUnlocked,
      };
}

/// Types of features that can be unlocked
enum FeatureType {
  characterCreation,
  interactiveStories,
  coloringPages,
  advancedSettings,
}

/// Progress toward unlocking a feature
class UnlockProgress {
  final FeatureType feature;
  final bool unlocked;
  final double currentProgress;
  final int storiesRemaining;
  final int threshold;

  const UnlockProgress({
    required this.feature,
    required this.unlocked,
    required this.currentProgress,
    required this.storiesRemaining,
    required this.threshold,
  });

  String get featureName => switch (feature) {
        FeatureType.characterCreation => 'Character Creation',
        FeatureType.interactiveStories => 'Interactive Stories',
        FeatureType.coloringPages => 'Coloring Pages',
        FeatureType.advancedSettings => 'Advanced Settings',
      };

  String get unlockRequirement => 'Create $threshold stories to unlock';
}

/// Data for celebrating a newly unlocked feature
class FeatureUnlockCelebration {
  final FeatureType feature;
  final String message;
  final String description;

  const FeatureUnlockCelebration({
    required this.feature,
    required this.message,
    required this.description,
  });
}
