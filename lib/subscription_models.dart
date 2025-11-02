// lib/subscription_models.dart

import 'package:flutter/material.dart';

/// Subscription tier levels
enum SubscriptionTier {
  free,
  premium,
  family;

  String get displayName {
    switch (this) {
      case SubscriptionTier.free:
        return 'Free';
      case SubscriptionTier.premium:
        return 'Premium';
      case SubscriptionTier.family:
        return 'Family';
    }
  }

  Color get color {
    switch (this) {
      case SubscriptionTier.free:
        return Colors.grey;
      case SubscriptionTier.premium:
        return Colors.deepPurple;
      case SubscriptionTier.family:
        return Colors.amber;
    }
  }

  IconData get icon {
    switch (this) {
      case SubscriptionTier.free:
        return Icons.person;
      case SubscriptionTier.premium:
        return Icons.star;
      case SubscriptionTier.family:
        return Icons.family_restroom;
    }
  }
}

/// Tier limits and features
class TierLimits {
  final int maxCharacters;
  final int maxStoriesPerDay;
  final int maxStoriesPerMonth;
  final bool unlimitedStories;
  final bool interactiveStories;
  final bool multiCharacterStories;
  final bool voiceNarration;
  final bool adventureMap;
  final bool customCharacters;
  final bool exportStories;
  final bool adFree;
  final bool prioritySupport;
  final bool earlyAccess;
  final List<String> availableThemes;
  final List<String> availableCompanions;

  const TierLimits({
    required this.maxCharacters,
    required this.maxStoriesPerDay,
    required this.maxStoriesPerMonth,
    this.unlimitedStories = false,
    this.interactiveStories = false,
    this.multiCharacterStories = false,
    this.voiceNarration = true,
    this.adventureMap = false,
    this.customCharacters = true,
    this.exportStories = false,
    this.adFree = false,
    this.prioritySupport = false,
    this.earlyAccess = false,
    this.availableThemes = const [],
    this.availableCompanions = const [],
  });

  static TierLimits forTier(SubscriptionTier tier) {
    switch (tier) {
      case SubscriptionTier.free:
        return const TierLimits(
          maxCharacters: 2,
          maxStoriesPerDay: 10, // Increased from 3
          maxStoriesPerMonth: 100, // Increased from 30
          unlimitedStories: false,
          interactiveStories: false,
          multiCharacterStories: false,
          voiceNarration: true,
          adventureMap: true, // Enable for all users
          customCharacters: true,
          exportStories: false,
          adFree: false,
          prioritySupport: false,
          earlyAccess: false,
          availableThemes: ['Adventure', 'Magic', 'Friendship'],
          availableCompanions: ['None', 'Loyal Dog', 'Mysterious Cat'],
        );

      case SubscriptionTier.premium:
        return const TierLimits(
          maxCharacters: 5,
          maxStoriesPerDay: 20,
          maxStoriesPerMonth: 300,
          unlimitedStories: false,
          interactiveStories: true,
          multiCharacterStories: true,
          voiceNarration: true,
          adventureMap: true,
          customCharacters: true,
          exportStories: true,
          adFree: true,
          prioritySupport: false,
          earlyAccess: false,
          availableThemes: [
            'Adventure',
            'Magic',
            'Ocean',
            'Space',
            'Dragons',
            'Castles',
            'Dinosaurs',
            'Robots'
          ],
          availableCompanions: [
            'None',
            'Loyal Dog',
            'Mysterious Cat',
            'Mischievous Fairy',
            'Tiny Dragon',
            'Wise Owl',
            'Gallant Horse',
            'Robot Sidekick'
          ],
        );

      case SubscriptionTier.family:
        return const TierLimits(
          maxCharacters: 20,
          maxStoriesPerDay: 0, // 0 means unlimited
          maxStoriesPerMonth: 0, // 0 means unlimited
          unlimitedStories: true,
          interactiveStories: true,
          multiCharacterStories: true,
          voiceNarration: true,
          adventureMap: true,
          customCharacters: true,
          exportStories: true,
          adFree: true,
          prioritySupport: true,
          earlyAccess: true,
          availableThemes: [
            'Adventure',
            'Magic',
            'Ocean',
            'Space',
            'Dragons',
            'Castles',
            'Dinosaurs',
            'Robots',
            'Fairy Tales',
            'Sports',
            'Science',
            'Music'
          ],
          availableCompanions: [
            'None',
            'Loyal Dog',
            'Mysterious Cat',
            'Mischievous Fairy',
            'Tiny Dragon',
            'Wise Owl',
            'Gallant Horse',
            'Robot Sidekick'
          ],
        );
    }
  }
}

/// User's subscription information
class UserSubscription {
  final SubscriptionTier tier;
  final DateTime? subscriptionStartDate;
  final DateTime? subscriptionEndDate;
  final bool isActive;
  final String? subscriptionId;

  UserSubscription({
    this.tier = SubscriptionTier.free,
    this.subscriptionStartDate,
    this.subscriptionEndDate,
    this.isActive = false,
    this.subscriptionId,
  });

  TierLimits get limits => TierLimits.forTier(tier);

  bool get isPremium => tier == SubscriptionTier.premium || tier == SubscriptionTier.family;
  bool get isFree => tier == SubscriptionTier.free;

  Map<String, dynamic> toJson() => {
        'tier': tier.name,
        'subscription_start_date': subscriptionStartDate?.toIso8601String(),
        'subscription_end_date': subscriptionEndDate?.toIso8601String(),
        'is_active': isActive,
        'subscription_id': subscriptionId,
      };

  factory UserSubscription.fromJson(Map<String, dynamic> json) {
    return UserSubscription(
      tier: SubscriptionTier.values.firstWhere(
        (t) => t.name == json['tier'],
        orElse: () => SubscriptionTier.free,
      ),
      subscriptionStartDate: json['subscription_start_date'] != null
          ? DateTime.tryParse(json['subscription_start_date'])
          : null,
      subscriptionEndDate: json['subscription_end_date'] != null
          ? DateTime.tryParse(json['subscription_end_date'])
          : null,
      isActive: json['is_active'] ?? false,
      subscriptionId: json['subscription_id'],
    );
  }

  UserSubscription copyWith({
    SubscriptionTier? tier,
    DateTime? subscriptionStartDate,
    DateTime? subscriptionEndDate,
    bool? isActive,
    String? subscriptionId,
  }) {
    return UserSubscription(
      tier: tier ?? this.tier,
      subscriptionStartDate: subscriptionStartDate ?? this.subscriptionStartDate,
      subscriptionEndDate: subscriptionEndDate ?? this.subscriptionEndDate,
      isActive: isActive ?? this.isActive,
      subscriptionId: subscriptionId ?? this.subscriptionId,
    );
  }
}

/// Usage tracking for enforcing limits
class UsageStats {
  final int storiesCreatedToday;
  final int storiesCreatedThisMonth;
  final DateTime lastStoryDate;
  final DateTime lastResetDate;

  UsageStats({
    this.storiesCreatedToday = 0,
    this.storiesCreatedThisMonth = 0,
    DateTime? lastStoryDate,
    DateTime? lastResetDate,
  })  : lastStoryDate = lastStoryDate ?? DateTime.now(),
        lastResetDate = lastResetDate ?? DateTime.now();

  bool needsDailyReset() {
    final now = DateTime.now();
    return now.day != lastResetDate.day ||
        now.month != lastResetDate.month ||
        now.year != lastResetDate.year;
  }

  bool needsMonthlyReset() {
    final now = DateTime.now();
    return now.month != lastResetDate.month || now.year != lastResetDate.year;
  }

  UsageStats resetDaily() {
    return UsageStats(
      storiesCreatedToday: 0,
      storiesCreatedThisMonth: storiesCreatedThisMonth,
      lastStoryDate: DateTime.now(),
      lastResetDate: DateTime.now(),
    );
  }

  UsageStats resetMonthly() {
    return UsageStats(
      storiesCreatedToday: 0,
      storiesCreatedThisMonth: 0,
      lastStoryDate: DateTime.now(),
      lastResetDate: DateTime.now(),
    );
  }

  UsageStats incrementStory() {
    return UsageStats(
      storiesCreatedToday: storiesCreatedToday + 1,
      storiesCreatedThisMonth: storiesCreatedThisMonth + 1,
      lastStoryDate: DateTime.now(),
      lastResetDate: lastResetDate,
    );
  }

  Map<String, dynamic> toJson() => {
        'stories_created_today': storiesCreatedToday,
        'stories_created_this_month': storiesCreatedThisMonth,
        'last_story_date': lastStoryDate.toIso8601String(),
        'last_reset_date': lastResetDate.toIso8601String(),
      };

  factory UsageStats.fromJson(Map<String, dynamic> json) {
    return UsageStats(
      storiesCreatedToday: json['stories_created_today'] ?? 0,
      storiesCreatedThisMonth: json['stories_created_this_month'] ?? 0,
      lastStoryDate: json['last_story_date'] != null
          ? DateTime.parse(json['last_story_date'])
          : DateTime.now(),
      lastResetDate: json['last_reset_date'] != null
          ? DateTime.parse(json['last_reset_date'])
          : DateTime.now(),
    );
  }
}

/// Pricing information for tiers
class TierPricing {
  final SubscriptionTier tier;
  final double monthlyPrice;
  final double yearlyPrice;
  final double yearlySavings;
  final List<String> features;
  final String? badge;

  const TierPricing({
    required this.tier,
    required this.monthlyPrice,
    required this.yearlyPrice,
    required this.yearlySavings,
    required this.features,
    this.badge,
  });

  static const freeTier = TierPricing(
    tier: SubscriptionTier.free,
    monthlyPrice: 0,
    yearlyPrice: 0,
    yearlySavings: 0,
    features: [
      'Up to 2 characters',
      '10 stories per day',
      'Basic themes (Adventure, Magic)',
      'Voice narration',
      'Basic companions',
    ],
  );

  static const premiumTier = TierPricing(
    tier: SubscriptionTier.premium,
    monthlyPrice: 9.99,
    yearlyPrice: 79.99,
    yearlySavings: 39.89,
    badge: 'Most Popular',
    features: [
      'Up to 5 characters',
      '20 stories per day',
      'All 8 themes unlocked',
      'Interactive choose-your-own-adventure',
      'Multi-character stories',
      'Adventure map progression',
      'Export & share stories',
      'Ad-free experience',
      'All companions unlocked',
    ],
  );

  static const familyTier = TierPricing(
    tier: SubscriptionTier.family,
    monthlyPrice: 19.99,
    yearlyPrice: 159.99,
    yearlySavings: 79.89,
    badge: 'Best Value',
    features: [
      'Up to 20 characters',
      'Unlimited stories',
      'All 12 themes (including exclusive)',
      'Interactive stories',
      'Multi-character stories',
      'Adventure map progression',
      'Export & share stories',
      'Ad-free experience',
      'All companions unlocked',
      'Priority support',
      'Early access to new features',
      'Perfect for families & educators',
    ],
  );

  static List<TierPricing> allTiers = [
    freeTier,
    premiumTier,
    familyTier,
  ];
}
