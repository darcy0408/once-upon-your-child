import 'dart:convert';
import 'dart:math' as math;

import 'package:shared_preferences/shared_preferences.dart';

import '../emotions_learning_system.dart';
import '../models/achievement.dart';

class AchievementState {
  AchievementState({
    Map<AchievementType, AchievementRecord>? records,
    this.totalStories = 0,
    Map<String, int>? themeCounts,
    this.charactersCreated = 0,
    this.currentStreak = 0,
    this.longestStreak = 0,
    this.lastStoryDateIso,
    this.earnedEarlyBird = false,
    this.earnedNightOwl = false,
  })  : records = records ?? {},
        themeCounts = themeCounts ?? {};

  Map<AchievementType, AchievementRecord> records;
  int totalStories;
  Map<String, int> themeCounts;
  int charactersCreated;
  int currentStreak;
  int longestStreak;
  String? lastStoryDateIso;
  bool earnedEarlyBird;
  bool earnedNightOwl;

  Map<String, dynamic> toJson() => {
        'records': records.map((key, value) => MapEntry(key.name, value.toJson())),
        'totalStories': totalStories,
        'themeCounts': themeCounts,
        'charactersCreated': charactersCreated,
        'currentStreak': currentStreak,
        'longestStreak': longestStreak,
        'lastStoryDateIso': lastStoryDateIso,
        'earnedEarlyBird': earnedEarlyBird,
        'earnedNightOwl': earnedNightOwl,
      };

  factory AchievementState.fromJson(Map<String, dynamic> json) {
    final recordsJson = json['records'] as Map<String, dynamic>? ?? {};
    final records = recordsJson.map((key, value) {
      final type = AchievementType.values.byName(key);
      return MapEntry(type, AchievementRecord.fromJson(value as Map<String, dynamic>));
    });

    return AchievementState(
      records: records,
      totalStories: json['totalStories'] as int? ?? 0,
      themeCounts: (json['themeCounts'] as Map<String, dynamic>?)
              ?.map((key, value) => MapEntry(key, (value as num).toInt())) ??
          {},
      charactersCreated: json['charactersCreated'] as int? ?? 0,
      currentStreak: json['currentStreak'] as int? ?? 0,
      longestStreak: json['longestStreak'] as int? ?? 0,
      lastStoryDateIso: json['lastStoryDateIso'] as String?,
      earnedEarlyBird: json['earnedEarlyBird'] as bool? ?? false,
      earnedNightOwl: json['earnedNightOwl'] as bool? ?? false,
    );
  }
}

/// Centralised achievement tracking and persistence.
class AchievementService {
  AchievementService._internal();

  static final AchievementService _instance = AchievementService._internal();

  factory AchievementService() => _instance;

  static const String _prefsKey = 'achievement_state_v1';

  final EmotionsLearningService _emotionsService = EmotionsLearningService();

  static const Map<String, String> _themeAliases = {
    'adventure': 'Adventure',
    'friendship': 'Friendship',
    'magic': 'Magic',
    'dragons': 'Dragons',
    'dragon': 'Dragons',
    'castle': 'Castles',
    'castles': 'Castles',
    'unicorn': 'Unicorns',
    'unicorns': 'Unicorns',
    'space': 'Space',
    'ocean': 'Ocean',
    'sea': 'Ocean',
  };

  Future<AchievementState> _loadState() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_prefsKey);
    if (raw == null || raw.isEmpty) {
      return _emptyState();
    }

    try {
      final json = jsonDecode(raw) as Map<String, dynamic>;
      final state = AchievementState.fromJson(json);
      return _ensureAllRecords(state);
    } catch (_) {
      // Corrupted cache – fall back to default
      return _emptyState();
    }
  }

  Future<void> _saveState(AchievementState state) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefsKey, jsonEncode(state.toJson()));
  }

  AchievementState _emptyState() {
    final state = AchievementState();
    for (final type in AchievementType.values) {
      state.records[type] = AchievementRecord.initial(type);
    }
    return state;
  }

  AchievementState _ensureAllRecords(AchievementState state) {
    for (final type in AchievementType.values) {
      state.records.putIfAbsent(type, () => AchievementRecord.initial(type));
    }
    return state;
  }

  /// Record that a story has been created and evaluate achievements.
  Future<List<AchievementProgress>> recordStoryCreated({
    required String theme,
    DateTime? timestamp,
  }) async {
    final state = await _loadState();
    final now = timestamp ?? DateTime.now();

    state.totalStories += 1;
    final normalizedTheme = _normalizeTheme(theme);
    if (normalizedTheme != null) {
      state.themeCounts[normalizedTheme] =
          (state.themeCounts[normalizedTheme] ?? 0) + 1;
    }

    _updateStreak(state, now);

    if (now.hour < 8) {
      state.earnedEarlyBird = true;
    }
    if (now.hour >= 22) {
      state.earnedNightOwl = true;
    }

    final newUnlocks =
        await _updateRecords(state, now: now, persist: false);

    await _saveState(state);
    return newUnlocks;
  }

  /// Record that a character was created.
  Future<List<AchievementProgress>> recordCharacterCreated() async {
    final state = await _loadState();
    state.charactersCreated += 1;
    final newUnlocks =
        await _updateRecords(state, persist: false);
    await _saveState(state);
    return newUnlocks;
  }

  /// Retrieve all achievements with current progress.
  Future<List<AchievementProgress>> getAllAchievements() async {
    final state = await _loadState();
    await _updateRecords(state, persist: true);

    return AchievementCatalog.all
        .map((achievement) => AchievementProgress(
              achievement: achievement,
              record: state.records[achievement.type]!,
            ))
        .toList();
  }

  /// Quick summary for UI badges and overviews.
  Future<AchievementSummary> getSummary() async {
    final state = await _loadState();
    await _updateRecords(state, persist: true);

    final total = AchievementCatalog.all.length;
    final unlocked =
        state.records.values.where((record) => record.isUnlocked).length;
    final newCount =
        state.records.values.where((record) => record.isNew).length;
    final averageProgress = total == 0
        ? 0.0
        : state.records.values
                .map((record) => record.progress)
                .fold<double>(0.0, (sum, item) => sum + item) /
            total;
    final completionPercent = total == 0 ? 0.0 : unlocked / total;

    return AchievementSummary(
      totalCount: total,
      unlockedCount: unlocked,
      newCount: newCount,
      completionPercent: completionPercent,
      averageProgress: averageProgress,
    );
  }

  /// Clear "new" indicators for the provided achievements.
  Future<void> markAchievementsViewed(
    Iterable<AchievementType> types,
  ) async {
    final typeList = types.toSet();
    if (typeList.isEmpty) return;

    final state = await _loadState();
    var mutated = false;

    for (final type in typeList) {
      final record = state.records[type];
      if (record != null && record.isNew) {
        state.records[type] = record.copyWith(isNew: false);
        mutated = true;
      }
    }

    if (mutated) {
      await _saveState(state);
    }
  }

  Future<List<AchievementProgress>> _updateRecords(
    AchievementState state, {
    int? uniqueEmotionCount,
    DateTime? now,
    bool persist = false,
  }) async {
    final emotionCount = uniqueEmotionCount ??
        (await _emotionsService.getLearnedEmotions()).toSet().length;
    final timestamp = now ?? DateTime.now();

    final newUnlocks = <AchievementProgress>[];
    for (final achievement in AchievementCatalog.all) {
      final existing =
          state.records[achievement.type] ?? AchievementRecord.initial(achievement.type);
      final currentValue =
          _resolveCurrentValue(achievement.type, state, emotionCount);
      final shouldUnlock = currentValue >= achievement.targetValue;
      final justUnlocked = !existing.isUnlocked && shouldUnlock;

      final updated = existing.copyWith(
        currentValue: currentValue,
        targetValue: achievement.targetValue,
        isUnlocked: existing.isUnlocked || shouldUnlock,
        unlockedAt: justUnlocked ? timestamp : existing.unlockedAt,
        isNew: existing.isNew || justUnlocked,
      );

      state.records[achievement.type] = updated;

      if (justUnlocked) {
        newUnlocks.add(
          AchievementProgress(
            achievement: achievement,
            record: updated,
          ),
        );
      }
    }

    if (persist) {
      await _saveState(state);
    }

    return newUnlocks;
  }

  int _resolveCurrentValue(
    AchievementType type,
    AchievementState state,
    int uniqueEmotionCount,
  ) {
    switch (type) {
      case AchievementType.firstStory:
      case AchievementType.fiveStories:
      case AchievementType.tenStories:
      case AchievementType.twentyFiveStories:
      case AchievementType.fiftyStories:
      case AchievementType.hundredStories:
        return state.totalStories;
      case AchievementType.adventureExplorer:
        return state.themeCounts['Adventure'] ?? 0;
      case AchievementType.friendshipBuilder:
        return state.themeCounts['Friendship'] ?? 0;
      case AchievementType.magicMaster:
        return state.themeCounts['Magic'] ?? 0;
      case AchievementType.dragonTamer:
        return state.themeCounts['Dragons'] ?? 0;
      case AchievementType.castleGuardian:
        return state.themeCounts['Castles'] ?? 0;
      case AchievementType.unicornDreamer:
        return state.themeCounts['Unicorns'] ?? 0;
      case AchievementType.spaceAdventurer:
        return state.themeCounts['Space'] ?? 0;
      case AchievementType.oceanGuardian:
        return state.themeCounts['Ocean'] ?? 0;
      case AchievementType.streak3:
      case AchievementType.streak7:
      case AchievementType.streak30:
        return state.longestStreak;
      case AchievementType.earlyBird:
        return state.earnedEarlyBird ? 1 : 0;
      case AchievementType.nightOwl:
        return state.earnedNightOwl ? 1 : 0;
      case AchievementType.characterCreator:
      case AchievementType.characterChampion:
        return state.charactersCreated;
      case AchievementType.emotionExplorer:
      case AchievementType.emotionMentor:
      case AchievementType.emotionMaster:
        return uniqueEmotionCount;
    }
  }

  void _updateStreak(AchievementState state, DateTime timestamp) {
    final today = DateTime(timestamp.year, timestamp.month, timestamp.day);
    final todayIso = today.toIso8601String();

    if (state.lastStoryDateIso == null) {
      state.currentStreak = 1;
    } else {
      final lastDate = DateTime.tryParse(state.lastStoryDateIso!);
      if (lastDate != null) {
        final diff = today.difference(lastDate).inDays;
        if (diff == 0) {
          // Same day, streak unchanged.
        } else if (diff == 1) {
          state.currentStreak += 1;
        } else if (diff > 1) {
          state.currentStreak = 1;
        } else {
          // For out-of-order timestamps, reset streak.
          state.currentStreak = 1;
        }
      } else {
        state.currentStreak = 1;
      }
    }

    state.currentStreak = math.max(1, state.currentStreak);
    state.longestStreak = math.max(state.longestStreak, state.currentStreak);
    state.lastStoryDateIso = todayIso;
  }

  String? _normalizeTheme(String theme) {
    final trimmed = theme.trim();
    if (trimmed.isEmpty) return null;
    final key = trimmed.toLowerCase();
    final alias = _themeAliases[key];
    if (alias != null) return alias;

    if (_themeAliases.containsValue(trimmed)) {
      return trimmed;
    }
    // Return capitalised version for unknown themes so we can still track stats.
    return trimmed[0].toUpperCase() + trimmed.substring(1);
  }
}
