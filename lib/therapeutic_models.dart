// lib/therapeutic_models.dart

import 'package:flutter/material.dart';

/// Therapeutic goals and scenarios
enum TherapeuticGoal {
  confidence,
  anxiety,
  socialSkills,
  emotionalRegulation,
  resilience,
  empathy,
  problemSolving,
  bullying,
  fears,
  transitions,
  selfEsteem,
  friendship;

  String get displayName {
    switch (this) {
      case TherapeuticGoal.confidence:
        return 'Building Confidence';
      case TherapeuticGoal.anxiety:
        return 'Managing Anxiety';
      case TherapeuticGoal.socialSkills:
        return 'Social Skills';
      case TherapeuticGoal.emotionalRegulation:
        return 'Emotional Regulation';
      case TherapeuticGoal.resilience:
        return 'Building Resilience';
      case TherapeuticGoal.empathy:
        return 'Developing Empathy';
      case TherapeuticGoal.problemSolving:
        return 'Problem Solving';
      case TherapeuticGoal.bullying:
        return 'Dealing with Bullies';
      case TherapeuticGoal.fears:
        return 'Overcoming Fears';
      case TherapeuticGoal.transitions:
        return 'Life Transitions';
      case TherapeuticGoal.selfEsteem:
        return 'Self-Esteem';
      case TherapeuticGoal.friendship:
        return 'Making Friends';
    }
  }

  String get description {
    switch (this) {
      case TherapeuticGoal.confidence:
        return 'Stories where the character succeeds through practice and perseverance';
      case TherapeuticGoal.anxiety:
        return 'Stories with calming techniques and positive coping strategies';
      case TherapeuticGoal.socialSkills:
        return 'Stories about making friends, sharing, and communication';
      case TherapeuticGoal.emotionalRegulation:
        return 'Stories about identifying and managing big feelings';
      case TherapeuticGoal.resilience:
        return 'Stories about bouncing back from setbacks';
      case TherapeuticGoal.empathy:
        return 'Stories about understanding others\' feelings';
      case TherapeuticGoal.problemSolving:
        return 'Stories where characters work through challenges creatively';
      case TherapeuticGoal.bullying:
        return 'Stories about standing up to bullies and getting help';
      case TherapeuticGoal.fears:
        return 'Stories about facing and overcoming specific fears';
      case TherapeuticGoal.transitions:
        return 'Stories about changes like moving, new school, new sibling';
      case TherapeuticGoal.selfEsteem:
        return 'Stories celebrating uniqueness and self-worth';
      case TherapeuticGoal.friendship:
        return 'Stories about being a good friend and finding kindred spirits';
    }
  }

  IconData get icon {
    switch (this) {
      case TherapeuticGoal.confidence:
        return Icons.emoji_events;
      case TherapeuticGoal.anxiety:
        return Icons.spa;
      case TherapeuticGoal.socialSkills:
        return Icons.people;
      case TherapeuticGoal.emotionalRegulation:
        return Icons.favorite;
      case TherapeuticGoal.resilience:
        return Icons.fitness_center;
      case TherapeuticGoal.empathy:
        return Icons.volunteer_activism;
      case TherapeuticGoal.problemSolving:
        return Icons.lightbulb;
      case TherapeuticGoal.bullying:
        return Icons.shield;
      case TherapeuticGoal.fears:
        return Icons.psychology;
      case TherapeuticGoal.transitions:
        return Icons.sync_alt;
      case TherapeuticGoal.selfEsteem:
        return Icons.auto_awesome;
      case TherapeuticGoal.friendship:
        return Icons.group;
    }
  }

  Color get color {
    switch (this) {
      case TherapeuticGoal.confidence:
        return Colors.orange;
      case TherapeuticGoal.anxiety:
        return Colors.blue;
      case TherapeuticGoal.socialSkills:
        return Colors.green;
      case TherapeuticGoal.emotionalRegulation:
        return Colors.red;
      case TherapeuticGoal.resilience:
        return Colors.purple;
      case TherapeuticGoal.empathy:
        return Colors.pink;
      case TherapeuticGoal.problemSolving:
        return Colors.amber;
      case TherapeuticGoal.bullying:
        return Colors.teal;
      case TherapeuticGoal.fears:
        return Colors.indigo;
      case TherapeuticGoal.transitions:
        return Colors.cyan;
      case TherapeuticGoal.selfEsteem:
        return Colors.deepOrange;
      case TherapeuticGoal.friendship:
        return Colors.lightGreen;
    }
  }
}

/// Custom story element that child wants to see
class StoryWish {
  final String description;
  final WishType type;
  final String? specificPerson; // e.g., "bully's name"
  final String? desiredOutcome; // e.g., "gets apologizes"

  StoryWish({
    required this.description,
    required this.type,
    this.specificPerson,
    this.desiredOutcome,
  });

  Map<String, dynamic> toJson() => {
        'description': description,
        'type': type.name,
        'specific_person': specificPerson,
        'desired_outcome': desiredOutcome,
      };

  factory StoryWish.fromJson(Map<String, dynamic> json) {
    return StoryWish(
      description: json['description'],
      type: WishType.values.firstWhere((t) => t.name == json['type']),
      specificPerson: json['specific_person'],
      desiredOutcome: json['desired_outcome'],
    );
  }
}

enum WishType {
  justice, // Bully gets consequences
  achievement, // Character wins/succeeds
  friendship, // Makes a friend
  courage, // Stands up for self/others
  healing, // Emotional healing
  adventure, // Exciting experience
  discovery, // Finds something special
  kindness, // Someone is kind to them
  other;

  String get displayName {
    switch (this) {
      case WishType.justice:
        return 'Justice/Fairness';
      case WishType.achievement:
        return 'Achievement';
      case WishType.friendship:
        return 'Friendship';
      case WishType.courage:
        return 'Courage';
      case WishType.healing:
        return 'Healing';
      case WishType.adventure:
        return 'Adventure';
      case WishType.discovery:
        return 'Discovery';
      case WishType.kindness:
        return 'Kindness';
      case WishType.other:
        return 'Other';
    }
  }
}

/// Therapeutic scenario template
class TherapeuticScenario {
  final String id;
  final String title;
  final String description;
  final TherapeuticGoal goal;
  final List<String> copingStrategies;
  final String positiveOutcome;
  final List<String> suggestedPrompts;

  const TherapeuticScenario({
    required this.id,
    required this.title,
    required this.description,
    required this.goal,
    required this.copingStrategies,
    required this.positiveOutcome,
    required this.suggestedPrompts,
  });

  static List<TherapeuticScenario> getAllScenarios() {
    return [
      const TherapeuticScenario(
        id: 'bully_overcome',
        title: 'Standing Up to a Bully',
        description: 'Character learns to handle bullying with confidence',
        goal: TherapeuticGoal.bullying,
        copingStrategies: [
          'Talk to a trusted adult',
          'Use confident body language',
          'Walk away from mean behavior',
          'Find supportive friends',
        ],
        positiveOutcome: 'The bully learns their behavior is wrong and apologizes',
        suggestedPrompts: [
          'The bully realizes being kind feels better',
          'A teacher or parent helps resolve the situation',
          'The character finds inner strength and confidence',
        ],
      ),
      const TherapeuticScenario(
        id: 'first_day_school',
        title: 'First Day Confidence',
        description: 'Character navigates first day at new school',
        goal: TherapeuticGoal.anxiety,
        copingStrategies: [
          'Take deep breaths',
          'Remember past successes',
          'Focus on one step at a time',
          'Talk to yourself kindly',
        ],
        positiveOutcome: 'Makes a new friend and feels proud',
        suggestedPrompts: [
          'Someone includes them at lunch',
          'They discover they have a special talent',
          'A kind teacher makes them feel welcome',
        ],
      ),
      const TherapeuticScenario(
        id: 'making_friends',
        title: 'Finding True Friends',
        description: 'Character learns what real friendship looks like',
        goal: TherapeuticGoal.friendship,
        copingStrategies: [
          'Be yourself',
          'Show interest in others',
          'Share and take turns',
          'Be kind even when it\'s hard',
        ],
        positiveOutcome: 'Finds friends who appreciate them for who they are',
        suggestedPrompts: [
          'Discovers someone with similar interests',
          'Helps someone and becomes friends',
          'Joins a club or group activity',
        ],
      ),
      const TherapeuticScenario(
        id: 'big_feelings',
        title: 'Managing Big Feelings',
        description: 'Character learns to handle overwhelming emotions',
        goal: TherapeuticGoal.emotionalRegulation,
        copingStrategies: [
          'Name the feeling',
          'Take calming breaths',
          'Talk to someone',
          'Use physical movement',
        ],
        positiveOutcome: 'Feels calm and in control',
        suggestedPrompts: [
          'Uses a calming technique that works',
          'An adult helps them understand their feelings',
          'Realizes feelings pass and they can cope',
        ],
      ),
      const TherapeuticScenario(
        id: 'overcoming_fear',
        title: 'Facing a Fear',
        description: 'Character gradually overcomes a specific fear',
        goal: TherapeuticGoal.fears,
        copingStrategies: [
          'Take small steps',
          'Have a support person nearby',
          'Celebrate small victories',
          'Remember you\'re brave',
        ],
        positiveOutcome: 'Conquers the fear and feels proud',
        suggestedPrompts: [
          'Discovers the thing wasn\'t as scary as imagined',
          'Gets support from a friend or family member',
          'Realizes they\'re stronger than they thought',
        ],
      ),
      const TherapeuticScenario(
        id: 'trying_again',
        title: 'Perseverance After Failure',
        description: 'Character doesn\'t give up after a setback',
        goal: TherapeuticGoal.resilience,
        copingStrategies: [
          'Remember everyone makes mistakes',
          'Learn from what didn\'t work',
          'Ask for help',
          'Keep practicing',
        ],
        positiveOutcome: 'Succeeds after trying again',
        suggestedPrompts: [
          'Gets better with practice',
          'Someone encourages them to keep going',
          'Finds a new way to approach the problem',
        ],
      ),
      const TherapeuticScenario(
        id: 'being_different',
        title: 'Celebrating Uniqueness',
        description: 'Character learns their differences are strengths',
        goal: TherapeuticGoal.selfEsteem,
        copingStrategies: [
          'Recognize your special talents',
          'Appreciate what makes you unique',
          'Surround yourself with supportive people',
          'Be proud of who you are',
        ],
        positiveOutcome: 'Realizes being different is wonderful',
        suggestedPrompts: [
          'Their unique trait helps save the day',
          'Finds others who appreciate their uniqueness',
          'Discovers their difference is actually a superpower',
        ],
      ),
      const TherapeuticScenario(
        id: 'new_sibling',
        title: 'Welcoming a New Sibling',
        description: 'Character adjusts to having a new brother or sister',
        goal: TherapeuticGoal.transitions,
        copingStrategies: [
          'Talk about feelings',
          'Find special one-on-one time',
          'Help in age-appropriate ways',
          'Remember you\'re still loved',
        ],
        positiveOutcome: 'Bonds with new sibling and feels special',
        suggestedPrompts: [
          'Becomes an amazing big sibling',
          'Parents reassure them of their love',
          'Discovers benefits of having a sibling',
        ],
      ),
    ];
  }
}

/// Therapeutic story customization
class TherapeuticStoryCustomization {
  final TherapeuticGoal? primaryGoal;
  final List<StoryWish> wishes;
  final String? specificSituation;
  final List<String> copingStrategiesToHighlight;
  final String? desiredLesson;

  TherapeuticStoryCustomization({
    this.primaryGoal,
    this.wishes = const [],
    this.specificSituation,
    this.copingStrategiesToHighlight = const [],
    this.desiredLesson,
  });

  Map<String, dynamic> toJson() => {
        'primary_goal': primaryGoal?.name,
        'wishes': wishes.map((w) => w.toJson()).toList(),
        'specific_situation': specificSituation,
        'coping_strategies': copingStrategiesToHighlight,
        'desired_lesson': desiredLesson,
      };

  String toPromptAddition() {
    final parts = <String>[];

    if (primaryGoal != null) {
      parts.add('THERAPEUTIC GOAL: ${primaryGoal!.displayName}');
    }

    if (specificSituation != null && specificSituation!.isNotEmpty) {
      parts.add('SITUATION: $specificSituation');
    }

    if (wishes.isNotEmpty) {
      parts.add('DESIRED OUTCOMES:');
      for (var wish in wishes) {
        parts.add('- ${wish.description}');
      }
    }

    if (copingStrategiesToHighlight.isNotEmpty) {
      parts.add('SHOW THESE COPING STRATEGIES: ${copingStrategiesToHighlight.join(", ")}');
    }

    if (desiredLesson != null && desiredLesson!.isNotEmpty) {
      parts.add('LESSON TO LEARN: $desiredLesson');
    }

    parts.add('\nIMPORTANT: The story should be therapeutic and supportive, validating feelings while showing positive coping strategies and a hopeful, empowering outcome.');

    return parts.join('\n');
  }
}
