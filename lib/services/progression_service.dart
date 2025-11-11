// lib/services/progression_service.dart

import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

/// User progress and unlock tracking
class UserProgress {
  int storiesCreated;
  int storiesRead;
  int storiesFavorited;
  int charactersCreated;
  int coloringPagesCompleted;
  Set<String> unlockedFeatures;
  DateTime createdAt;
  DateTime? lastStoryCreatedAt;

  UserProgress({
    this.storiesCreated = 0,
    this.storiesRead = 0,
    this.storiesFavorited = 0,
    this.charactersCreated = 0,
    this.coloringPagesCompleted = 0,
    Set<String>? unlockedFeatures,
    DateTime? createdAt,
    this.lastStoryCreatedAt,
  })  : unlockedFeatures = unlockedFeatures ?? {},
        createdAt = createdAt ?? DateTime.now();

  int get totalEngagement =>
      storiesCreated + storiesRead + storiesFavorited + charactersCreated;

  bool hasUnlocked(String featureKey) {
    return unlockedFeatures.contains(featureKey);
  }

  Map<String, dynamic> toJson() {
    return {
      'storiesCreated': storiesCreated,
      'storiesRead': storiesRead,
      'storiesFavorited': storiesFavorited,
      'charactersCreated': charactersCreated,
      'coloringPagesCompleted': coloringPagesCompleted,
      'unlockedFeatures': unlockedFeatures.toList(),
      'createdAt': createdAt.toIso8601String(),
      'lastStoryCreatedAt': lastStoryCreatedAt?.toIso8601String(),
    };
  }

  factory UserProgress.fromJson(Map<String, dynamic> json) {
    return UserProgress(
      storiesCreated: json['storiesCreated'] as int? ?? 0,
      storiesRead: json['storiesRead'] as int? ?? 0,
      storiesFavorited: json['storiesFavorited'] as int? ?? 0,
      charactersCreated: json['charactersCreated'] as int? ?? 0,
      coloringPagesCompleted: json['coloringPagesCompleted'] as int? ?? 0,
      unlockedFeatures: (json['unlockedFeatures'] as List<dynamic>?)
              ?.map((e) => e as String)
              .toSet() ??
          {},
      createdAt: json['createdAt'] != null
          ? DateTime.parse(json['createdAt'] as String)
          : DateTime.now(),
      lastStoryCreatedAt: json['lastStoryCreatedAt'] != null
          ? DateTime.parse(json['lastStoryCreatedAt'] as String)
          : null,
    );
  }
}

/// Feature keys for unlockable content
class UnlockableFeatures {
  static const String fantasyMode = 'fantasy_mode';
  static const String animalEarsTails = 'animal_ears_tails';
  static const String customColors = 'custom_colors';
  static const String rhymeTimeMode = 'rhyme_time_mode';
  static const String superheroMode = 'superhero_mode'; // Premium only
  static const String interactiveStories = 'interactive_stories'; // Premium only
}

/// Service to manage user progression and unlocks
class ProgressionService {
  static const String _cacheKey = 'user_progress';

  /// Get current user progress
  Future<UserProgress> getUserProgress() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonString = prefs.getString(_cacheKey);

    if (jsonString == null || jsonString.isEmpty) {
      return UserProgress();
    }

    try {
      final json = jsonDecode(jsonString) as Map<String, dynamic>;
      return UserProgress.fromJson(json);
    } catch (e) {
      return UserProgress();
    }
  }

  /// Save user progress
  Future<void> saveUserProgress(UserProgress progress) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_cacheKey, jsonEncode(progress.toJson()));
  }

  /// Check if user has premium access (BYOK or paid)
  Future<bool> hasPremiumAccess() async {
    final prefs = await SharedPreferences.getInstance();
    final byokPremium = prefs.getBool('is_premium_byok') ?? false;
    final paidPremium = prefs.getBool('is_paid_premium') ?? false;
    return byokPremium || paidPremium;
  }

  /// Check if user has access to a specific feature
  Future<bool> hasAccessToFeature(String featureKey) async {
    // Premium features require either BYOK or paid subscription
    if (featureKey == UnlockableFeatures.superheroMode ||
        featureKey == UnlockableFeatures.interactiveStories) {
      return await hasPremiumAccess();
    }

    // Free progression features
    final progress = await getUserProgress();

    // If already unlocked, return true
    if (progress.hasUnlocked(featureKey)) {
      return true;
    }

    // Check if user meets the unlock requirement
    final requirement = getUnlockRequirement(featureKey);
    if (requirement != null && progress.storiesCreated >= requirement) {
      // Auto-unlock if requirement is met
      progress.unlockedFeatures.add(featureKey);
      await saveUserProgress(progress);
      return true;
    }

    return false;
  }

  /// Get the story count required to unlock a feature
  int? getUnlockRequirement(String featureKey) {
    switch (featureKey) {
      case UnlockableFeatures.fantasyMode:
        return 5;
      case UnlockableFeatures.animalEarsTails:
        return 10;
      case UnlockableFeatures.customColors:
        return 15;
      case UnlockableFeatures.rhymeTimeMode:
        return 0;
      case UnlockableFeatures.superheroMode:
      case UnlockableFeatures.interactiveStories:
        return null; // Premium only, no story requirement
      default:
        return null;
    }
  }

  /// Record that a story was created
  Future<List<String>> incrementStoriesCreated() async {
    final progress = await getUserProgress();
    progress.storiesCreated++;
    progress.lastStoryCreatedAt = DateTime.now();

    // Check for new unlocks
    final newUnlocks = checkForUnlocks(progress);

    await saveUserProgress(progress);

    return newUnlocks;
  }

  /// Record that a story was read
  Future<void> incrementStoriesRead() async {
    final progress = await getUserProgress();
    progress.storiesRead++;
    await saveUserProgress(progress);
  }

  /// Record that a story was favorited
  Future<void> incrementStoriesFavorited() async {
    final progress = await getUserProgress();
    progress.storiesFavorited++;
    await saveUserProgress(progress);
  }

  /// Record that a character was created
  Future<void> incrementCharactersCreated() async {
    final progress = await getUserProgress();
    progress.charactersCreated++;
    await saveUserProgress(progress);
  }

  /// Record that a coloring page was completed
  Future<void> incrementColoringPagesCompleted() async {
    final progress = await getUserProgress();
    progress.coloringPagesCompleted++;
    await saveUserProgress(progress);
  }

  /// Check if any new features should be unlocked
  List<String> checkForUnlocks(UserProgress progress) {
    final newUnlocks = <String>[];

    // Fantasy Mode at 5 stories
    if (progress.storiesCreated >= 5 &&
        !progress.hasUnlocked(UnlockableFeatures.fantasyMode)) {
      newUnlocks.add(UnlockableFeatures.fantasyMode);
      progress.unlockedFeatures.add(UnlockableFeatures.fantasyMode);
    }

    // Animal Ears & Tails at 10 stories
    if (progress.storiesCreated >= 10 &&
        !progress.hasUnlocked(UnlockableFeatures.animalEarsTails)) {
      newUnlocks.add(UnlockableFeatures.animalEarsTails);
      progress.unlockedFeatures.add(UnlockableFeatures.animalEarsTails);
    }

    // Custom Colors at 15 stories
    if (progress.storiesCreated >= 15 &&
        !progress.hasUnlocked(UnlockableFeatures.customColors)) {
      newUnlocks.add(UnlockableFeatures.customColors);
      progress.unlockedFeatures.add(UnlockableFeatures.customColors);
    }

    // Rhyme Time Mode at 0 stories (always unlocked for testing)
    if (progress.storiesCreated >= 0 &&
        !progress.hasUnlocked(UnlockableFeatures.rhymeTimeMode)) {
      newUnlocks.add(UnlockableFeatures.rhymeTimeMode);
      progress.unlockedFeatures.add(UnlockableFeatures.rhymeTimeMode);
    }

    return newUnlocks;
  }

  /// Get user-friendly name for a feature
  String getFeatureName(String featureKey) {
    switch (featureKey) {
      case UnlockableFeatures.fantasyMode:
        return 'Fantasy Mode';
      case UnlockableFeatures.animalEarsTails:
        return 'Animal Ears & Tails Pack';
      case UnlockableFeatures.customColors:
        return 'Custom Color Picker';
      case UnlockableFeatures.rhymeTimeMode:
        return 'Rhyme Time Mode';
      case UnlockableFeatures.superheroMode:
        return 'Superhero Mode';
      case UnlockableFeatures.interactiveStories:
        return 'Interactive Stories';
      default:
        return featureKey;
    }
  }

  /// Get user-friendly description for a feature
  String getFeatureDescription(String featureKey) {
    switch (featureKey) {
      case UnlockableFeatures.fantasyMode:
        return 'Unlock elf ears, fairy wings, and magical effects for your avatars!';
      case UnlockableFeatures.animalEarsTails:
        return 'Add cute animal ears and tails to your characters!';
      case UnlockableFeatures.customColors:
        return 'Choose any color you want for hair, clothes, and more!';
      case UnlockableFeatures.rhymeTimeMode:
        return 'Transform your stories into silly, rhyming adventures with playful verses!';
      case UnlockableFeatures.superheroMode:
        return 'Create superheroes with capes, masks, and special powers!';
      case UnlockableFeatures.interactiveStories:
        return 'Make choices that change how your story unfolds!';
      default:
        return '';
    }
  }

  /// Reset all progress (for testing/debugging)
  Future<void> resetProgress() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_cacheKey);
  }
}
