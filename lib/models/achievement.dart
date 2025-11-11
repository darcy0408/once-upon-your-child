import 'package:flutter/material.dart';

/// High level grouping used for filtering achievements in the UI.
enum AchievementCategory {
  storyCount,
  themes,
  streaks,
  time,
  characters,
  emotions,
}

extension AchievementCategoryDisplay on AchievementCategory {
  String get label {
    switch (this) {
      case AchievementCategory.storyCount:
        return 'Story Count';
      case AchievementCategory.themes:
        return 'Themes';
      case AchievementCategory.streaks:
        return 'Streaks';
      case AchievementCategory.time:
        return 'Time of Day';
      case AchievementCategory.characters:
        return 'Characters';
      case AchievementCategory.emotions:
        return 'Emotions';
    }
  }
}

/// How rare a badge is.
enum AchievementRarity { common, rare, epic, legendary }

extension AchievementRarityDisplay on AchievementRarity {
  String get label {
    switch (this) {
      case AchievementRarity.common:
        return 'Common';
      case AchievementRarity.rare:
        return 'Rare';
      case AchievementRarity.epic:
        return 'Epic';
      case AchievementRarity.legendary:
        return 'Legendary';
    }
  }

  Color get color {
    switch (this) {
      case AchievementRarity.common:
        return const Color(0xFF9E9E9E);
      case AchievementRarity.rare:
        return const Color(0xFF26C6DA);
      case AchievementRarity.epic:
        return const Color(0xFFAB47BC);
      case AchievementRarity.legendary:
        return const Color(0xFFFFB300);
    }
  }
}

/// Identifiers for each individual achievement.
enum AchievementType {
  firstStory,
  fiveStories,
  tenStories,
  twentyFiveStories,
  fiftyStories,
  hundredStories,
  adventureExplorer,
  friendshipBuilder,
  magicMaster,
  dragonTamer,
  castleGuardian,
  unicornDreamer,
  spaceAdventurer,
  oceanGuardian,
  streak3,
  streak7,
  streak30,
  earlyBird,
  nightOwl,
  characterCreator,
  characterChampion,
  emotionExplorer,
  emotionMentor,
  emotionMaster,
}

/// Static metadata describing an achievement badge.
class Achievement {
  final AchievementType type;
  final AchievementCategory category;
  final AchievementRarity rarity;
  final String name;
  final String description;
  final String criteria;
  final IconData icon;
  final Color color;
  final int targetValue;

  const Achievement({
    required this.type,
    required this.category,
    required this.rarity,
    required this.name,
    required this.description,
    required this.criteria,
    required this.icon,
    required this.color,
    required this.targetValue,
  });

  Color get rarityColor => rarity.color;
}

/// Tracks user progress toward an achievement.
class AchievementRecord {
  final AchievementType type;
  final bool isUnlocked;
  final DateTime? unlockedAt;
  final int currentValue;
  final int targetValue;
  final bool isNew;

  const AchievementRecord({
    required this.type,
    this.isUnlocked = false,
    this.unlockedAt,
    this.currentValue = 0,
    required this.targetValue,
    this.isNew = false,
  });

  double get progress {
    if (targetValue <= 0) {
      return isUnlocked ? 1.0 : 0.0;
    }
    final ratio = currentValue / targetValue;
    if (ratio.isNaN) return 0.0;
    return ratio.clamp(0.0, 1.0);
  }

  AchievementRecord copyWith({
    bool? isUnlocked,
    DateTime? unlockedAt,
    int? currentValue,
    int? targetValue,
    bool? isNew,
  }) {
    return AchievementRecord(
      type: type,
      isUnlocked: isUnlocked ?? this.isUnlocked,
      unlockedAt: unlockedAt ?? this.unlockedAt,
      currentValue: currentValue ?? this.currentValue,
      targetValue: targetValue ?? this.targetValue,
      isNew: isNew ?? this.isNew,
    );
  }

  Map<String, dynamic> toJson() => {
        'type': type.name,
        'isUnlocked': isUnlocked,
        'unlockedAt': unlockedAt?.toIso8601String(),
        'currentValue': currentValue,
        'targetValue': targetValue,
        'isNew': isNew,
      };

  factory AchievementRecord.fromJson(Map<String, dynamic> json) {
    final type = AchievementType.values.byName(json['type'] as String);
    return AchievementRecord(
      type: type,
      isUnlocked: json['isUnlocked'] as bool? ?? false,
      unlockedAt: json['unlockedAt'] != null
          ? DateTime.tryParse(json['unlockedAt'] as String)
          : null,
      currentValue: json['currentValue'] as int? ?? 0,
      targetValue: json['targetValue'] as int? ??
          AchievementCatalog.getByType(type).targetValue,
      isNew: json['isNew'] as bool? ?? false,
    );
  }

  factory AchievementRecord.initial(AchievementType type) {
    final meta = AchievementCatalog.getByType(type);
    return AchievementRecord(type: type, targetValue: meta.targetValue);
  }
}

/// Convenience wrapper combining metadata with progress.
class AchievementProgress {
  final Achievement achievement;
  final AchievementRecord record;

  const AchievementProgress({
    required this.achievement,
    required this.record,
  });

  AchievementProgress copyWithRecord(AchievementRecord record) => AchievementProgress(
        achievement: achievement,
        record: record,
      );
}

/// Lightweight summary used for quick status indicators.
class AchievementSummary {
  final int totalCount;
  final int unlockedCount;
  final int newCount;
  final double completionPercent;
  final double averageProgress;

  const AchievementSummary({
    required this.totalCount,
    required this.unlockedCount,
    required this.newCount,
    required this.completionPercent,
    required this.averageProgress,
  });
}

/// Central catalog of every achievement definition.
class AchievementCatalog {
  static final List<Achievement> all = [
    // Story milestones
    Achievement(
      type: AchievementType.firstStory,
      category: AchievementCategory.storyCount,
      rarity: AchievementRarity.common,
      name: 'First Tale',
      description: 'You crafted your very first story!',
      criteria: 'Create 1 story.',
      icon: Icons.bookmark_added,
      color: const Color(0xFF81C784),
      targetValue: 1,
    ),
    Achievement(
      type: AchievementType.fiveStories,
      category: AchievementCategory.storyCount,
      rarity: AchievementRarity.common,
      name: 'Story Spark',
      description: 'Five stories bring your imagination to life.',
      criteria: 'Create 5 stories.',
      icon: Icons.menu_book,
      color: const Color(0xFF66BB6A),
      targetValue: 5,
    ),
    Achievement(
      type: AchievementType.tenStories,
      category: AchievementCategory.storyCount,
      rarity: AchievementRarity.rare,
      name: 'Story Weaver',
      description: 'Ten tales woven with care and creativity.',
      criteria: 'Create 10 stories.',
      icon: Icons.library_books,
      color: const Color(0xFF4CAF50),
      targetValue: 10,
    ),
    Achievement(
      type: AchievementType.twentyFiveStories,
      category: AchievementCategory.storyCount,
      rarity: AchievementRarity.rare,
      name: 'Imagination Trailblazer',
      description: 'Your storytelling adventure is soaring.',
      criteria: 'Create 25 stories.',
      icon: Icons.local_fire_department,
      color: const Color(0xFF43A047),
      targetValue: 25,
    ),
    Achievement(
      type: AchievementType.fiftyStories,
      category: AchievementCategory.storyCount,
      rarity: AchievementRarity.epic,
      name: 'Legend Maker',
      description: 'Fifty stories! Your legends inspire others.',
      criteria: 'Create 50 stories.',
      icon: Icons.workspace_premium,
      color: const Color(0xFF2E7D32),
      targetValue: 50,
    ),
    Achievement(
      type: AchievementType.hundredStories,
      category: AchievementCategory.storyCount,
      rarity: AchievementRarity.legendary,
      name: 'Mythic Author',
      description: 'One hundred stories—an entire universe of adventures.',
      criteria: 'Create 100 stories.',
      icon: Icons.auto_awesome,
      color: const Color(0xFF1B5E20),
      targetValue: 100,
    ),

    // Theme exploration
    Achievement(
      type: AchievementType.adventureExplorer,
      category: AchievementCategory.themes,
      rarity: AchievementRarity.common,
      name: 'Adventure Seeker',
      description: 'You ventured through countless adventures.',
      criteria: 'Create 10 Adventure stories.',
      icon: Icons.explore,
      color: const Color(0xFF29B6F6),
      targetValue: 10,
    ),
    Achievement(
      type: AchievementType.friendshipBuilder,
      category: AchievementCategory.themes,
      rarity: AchievementRarity.common,
      name: 'Friend Maker',
      description: 'You celebrated the power of friendship.',
      criteria: 'Create 10 Friendship stories.',
      icon: Icons.diversity_1,
      color: const Color(0xFF8E24AA),
      targetValue: 10,
    ),
    Achievement(
      type: AchievementType.magicMaster,
      category: AchievementCategory.themes,
      rarity: AchievementRarity.rare,
      name: 'Magic Master',
      description: 'Ten magical quests filled with wonder.',
      criteria: 'Create 10 Magic stories.',
      icon: Icons.auto_fix_high,
      color: const Color(0xFF7E57C2),
      targetValue: 10,
    ),
    Achievement(
      type: AchievementType.dragonTamer,
      category: AchievementCategory.themes,
      rarity: AchievementRarity.rare,
      name: 'Dragon Tamer',
      description: 'You befriended mighty dragons again and again.',
      criteria: 'Create 10 Dragons stories.',
      icon: Icons.flag,
      color: const Color(0xFFFF7043),
      targetValue: 10,
    ),
    Achievement(
      type: AchievementType.castleGuardian,
      category: AchievementCategory.themes,
      rarity: AchievementRarity.rare,
      name: 'Castle Guardian',
      description: 'Ten tales set within towering castles.',
      criteria: 'Create 10 Castles stories.',
      icon: Icons.fort,
      color: const Color(0xFF5C6BC0),
      targetValue: 10,
    ),
    Achievement(
      type: AchievementType.unicornDreamer,
      category: AchievementCategory.themes,
      rarity: AchievementRarity.epic,
      name: 'Unicorn Dreamer',
      description: 'You galloped with unicorns through ten sparkling stories.',
      criteria: 'Create 10 Unicorns stories.',
      icon: Icons.stars,
      color: const Color(0xFFEC407A),
      targetValue: 10,
    ),
    Achievement(
      type: AchievementType.spaceAdventurer,
      category: AchievementCategory.themes,
      rarity: AchievementRarity.epic,
      name: 'Space Adventurer',
      description: 'You soared among the stars again and again.',
      criteria: 'Create 10 Space stories.',
      icon: Icons.travel_explore,
      color: const Color(0xFF26A69A),
      targetValue: 10,
    ),
    Achievement(
      type: AchievementType.oceanGuardian,
      category: AchievementCategory.themes,
      rarity: AchievementRarity.epic,
      name: 'Ocean Guardian',
      description: 'Ten underwater tales protecting the seas.',
      criteria: 'Create 10 Ocean stories.',
      icon: Icons.waves,
      color: const Color(0xFF42A5F5),
      targetValue: 10,
    ),

    // Streaks
    Achievement(
      type: AchievementType.streak3,
      category: AchievementCategory.streaks,
      rarity: AchievementRarity.common,
      name: 'Streak Spark',
      description: 'Three days in a row of storytelling!',
      criteria: 'Maintain a 3-day story streak.',
      icon: Icons.bolt,
      color: const Color(0xFFFFEE58),
      targetValue: 3,
    ),
    Achievement(
      type: AchievementType.streak7,
      category: AchievementCategory.streaks,
      rarity: AchievementRarity.rare,
      name: 'Week Warrior',
      description: 'A full week of creative dedication.',
      criteria: 'Maintain a 7-day story streak.',
      icon: Icons.flare,
      color: const Color(0xFFFFC107),
      targetValue: 7,
    ),
    Achievement(
      type: AchievementType.streak30,
      category: AchievementCategory.streaks,
      rarity: AchievementRarity.legendary,
      name: 'Month Master',
      description: 'Thirty days of continuous story crafting.',
      criteria: 'Maintain a 30-day story streak.',
      icon: Icons.local_fire_department,
      color: const Color(0xFFFF7043),
      targetValue: 30,
    ),

    // Time-based
    Achievement(
      type: AchievementType.earlyBird,
      category: AchievementCategory.time,
      rarity: AchievementRarity.rare,
      name: 'Early Bird',
      description: 'Morning creativity shines the brightest.',
      criteria: 'Create a story before 8:00 AM.',
      icon: Icons.wb_sunny_outlined,
      color: const Color(0xFFFFF176),
      targetValue: 1,
    ),
    Achievement(
      type: AchievementType.nightOwl,
      category: AchievementCategory.time,
      rarity: AchievementRarity.epic,
      name: 'Night Owl',
      description: 'Late-night stories twinkle with stars.',
      criteria: 'Create a story after 10:00 PM.',
      icon: Icons.nightlight_round,
      color: const Color(0xFF3949AB),
      targetValue: 1,
    ),

    // Character milestones
    Achievement(
      type: AchievementType.characterCreator,
      category: AchievementCategory.characters,
      rarity: AchievementRarity.common,
      name: 'Character Creator',
      description: 'You crafted a cast of unique heroes.',
      criteria: 'Create 3 characters.',
      icon: Icons.person_add,
      color: const Color(0xFF26A69A),
      targetValue: 3,
    ),
    Achievement(
      type: AchievementType.characterChampion,
      category: AchievementCategory.characters,
      rarity: AchievementRarity.epic,
      name: 'Character Collector',
      description: 'Your world is full of unforgettable friends.',
      criteria: 'Create 10 characters.',
      icon: Icons.groups,
      color: const Color(0xFF00897B),
      targetValue: 10,
    ),

    // Emotion exploration
    Achievement(
      type: AchievementType.emotionExplorer,
      category: AchievementCategory.emotions,
      rarity: AchievementRarity.common,
      name: 'Emotion Explorer',
      description: 'You explored many different feelings.',
      criteria: 'Log 5 unique feelings.',
      icon: Icons.emoji_emotions,
      color: const Color(0xFFFFB74D),
      targetValue: 5,
    ),
    Achievement(
      type: AchievementType.emotionMentor,
      category: AchievementCategory.emotions,
      rarity: AchievementRarity.rare,
      name: 'Emotion Mentor',
      description: 'Your heart understands a wide range of emotions.',
      criteria: 'Log 12 unique feelings.',
      icon: Icons.self_improvement,
      color: const Color(0xFF8D6E63),
      targetValue: 12,
    ),
    Achievement(
      type: AchievementType.emotionMaster,
      category: AchievementCategory.emotions,
      rarity: AchievementRarity.epic,
      name: 'Emotion Sage',
      description: 'You have embraced the full spectrum of feelings.',
      criteria: 'Log 20 unique feelings.',
      icon: Icons.psychology,
      color: const Color(0xFF7CB342),
      targetValue: 20,
    ),
  ];

  static final Map<AchievementType, Achievement> _byType = {
    for (final achievement in all) achievement.type: achievement,
  };

  static Achievement getByType(AchievementType type) => _byType[type]!;
}
