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
  friendship,
  focus,
  boundaries;

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
      case TherapeuticGoal.focus:
        return 'Focus & Listening';
      case TherapeuticGoal.boundaries:
        return 'Setting Boundaries';
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
      case TherapeuticGoal.focus:
        return 'Stories about listening, following directions, and paying attention';
      case TherapeuticGoal.boundaries:
        return 'Stories about saying no, noticing the "uh-oh" feeling, and respecting others\' limits';
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
      case TherapeuticGoal.focus:
        return Icons.hearing;
      case TherapeuticGoal.boundaries:
        return Icons.front_hand;
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
      case TherapeuticGoal.focus:
        return Colors.teal;
      case TherapeuticGoal.boundaries:
        return Colors.blueGrey;
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
      const TherapeuticScenario(
        id: 'focus_following_directions',
        title: 'Following Directions',
        description: 'Character learns to listen and follow instructions',
        goal: TherapeuticGoal.focus,
        copingStrategies: [
          'Active listening',
          'Breaking tasks into smaller steps',
          'Asking clarifying questions',
          'Repeating instructions back',
        ],
        positiveOutcome: 'Successfully completes a task by following directions',
        suggestedPrompts: [
          'A fun game requires careful listening',
          'A new recipe needs precise steps',
          'Building a complex toy requires attention to detail',
        ],
      ),
      const TherapeuticScenario(
        id: 'focus_ignoring_distractions',
        title: 'Ignoring Distractions',
        description: 'Character learns to stay focused despite interruptions',
        goal: TherapeuticGoal.focus,
        copingStrategies: [
          'Identifying distractions',
          'Using a "focus bubble"',
          'Taking short brain breaks',
          'Self-talk ("I can focus")',
        ],
        positiveOutcome: 'Finishes a project despite noisy surroundings',
        suggestedPrompts: [
          'Studying for a test while siblings play',
          'Finishing a drawing in a busy classroom',
          'Reading a book at a loud park',
        ],
      ),
      const TherapeuticScenario(
        id: 'focus_active_listening',
        title: 'Active Listening',
        description: 'Character learns to truly hear what others say',
        goal: TherapeuticGoal.focus,
        copingStrategies: [
          'Making eye contact',
          'Nodding and showing interest',
          'Waiting for the speaker to finish',
          'Summarizing what was heard',
        ],
        positiveOutcome: 'Builds a stronger friendship through listening',
        suggestedPrompts: [
          'A friend shares a secret',
          'Grandparent tells a story from the past',
          'Teacher explains a new game',
        ],
      ),
      const TherapeuticScenario(
        id: 'focus_impulse_control',
        title: 'Thinking Before Acting',
        description: 'Character learns to pause and think',
        goal: TherapeuticGoal.focus,
        copingStrategies: [
          'Stop, Think, Act',
          'Counting to ten',
          'Taking a deep breath',
          'Considering consequences',
        ],
        positiveOutcome: 'Avoids a mistake by pausing to think',
        suggestedPrompts: [
          'Wanting to interrupt a conversation',
          'Seeing a delicious treat that isn\'t theirs',
          'Feeling angry and wanting to yell',
        ],
      ),
      const TherapeuticScenario(
        id: 'focus_task_completion',
        title: 'Finishing What You Start',
        description: 'Character learns the value of perseverance',
        goal: TherapeuticGoal.focus,
        copingStrategies: [
          'Setting small goals',
          'Celebrating progress',
          'Asking for help when stuck',
          'Visualizing the finished result',
        ],
        positiveOutcome: 'Feels proud after completing a long project',
        suggestedPrompts: [
          'Building a giant lego castle',
          'Cleaning a messy room',
          'Learning a new song on an instrument',
        ],
      ),
      const TherapeuticScenario(
        id: 'focus_memory_skills',
        title: 'Remembering Important Things',
        description: 'Character learns tricks to improve memory',
        goal: TherapeuticGoal.focus,
        copingStrategies: [
          'Using mnemonics or rhymes',
          'Writing things down',
          'Visualizing information',
          'Repeating key details',
        ],
        positiveOutcome: 'Remembers everything needed for a trip',
        suggestedPrompts: [
          'Packing for a camping trip',
          'Remembering a grocery list',
          'Learning lines for a school play',
        ],
      ),
      const TherapeuticScenario(
        id: 'focus_patience',
        title: 'Practicing Patience',
        description: 'Character learns to wait calmly',
        goal: TherapeuticGoal.focus,
        copingStrategies: [
          'Finding a quiet activity while waiting',
          'Deep breathing',
          'Observing surroundings',
          'Positive self-talk',
        ],
        positiveOutcome: 'Waits patiently for a turn or event',
        suggestedPrompts: [
          'Waiting in a long line at an amusement park',
          'Waiting for a birthday surprise',
          'Waiting for a seed to sprout',
        ],
      ),
      const TherapeuticScenario(
        id: 'focus_organization',
        title: 'Being Organized',
        description: 'Character learns that organization helps focus',
        goal: TherapeuticGoal.focus,
        copingStrategies: [
          'Everything has a place',
          'Cleaning up after oneself',
          'Using a checklist',
          'Preparing for the next day',
        ],
        positiveOutcome: 'Finds a lost toy easily because of organization',
        suggestedPrompts: [
          'Cleaning a messy desk',
          'Organizing a toy collection',
          'Getting ready for school the night before',
        ],
      ),
      const TherapeuticScenario(
        id: 'focus_mindfulness',
        title: 'Being in the Moment',
        description: 'Character learns mindfulness to stay present',
        goal: TherapeuticGoal.focus,
        copingStrategies: [
          'Five senses check-in',
          'Focusing on breath',
          'Noticing small details',
          'Letting go of worries',
        ],
        positiveOutcome: 'Enjoys a special moment fully',
        suggestedPrompts: [
          'A walk in nature',
          'Eating a favorite meal slowly',
          'Watching a sunset',
        ],
      ),
      const TherapeuticScenario(
        id: 'boundary_say_no',
        title: 'It\'s Okay to Say No',
        description: 'Character learns to set a limit and trust the "uh-oh" feeling',
        goal: TherapeuticGoal.boundaries,
        copingStrategies: [
          'Notice the "uh-oh" feeling in your tummy',
          'Say "stop" or "no thank you"',
          'Walk away and tell a trusted grown-up',
          'Remember: a real friend stays after you say no',
        ],
        positiveOutcome: 'Sets a limit calmly and still feels safe and liked',
        suggestedPrompts: [
          'A friend keeps asking for something that does not feel fair',
          'Someone wants a hug when the character does not',
          'A "secret" makes the character\'s tummy feel funny',
        ],
      ),
      const TherapeuticScenario(
        id: 'boundary_respect_others',
        title: 'When Someone Says Stop',
        description: 'Character learns to respect other people\'s limits right away',
        goal: TherapeuticGoal.boundaries,
        copingStrategies: [
          'Stop the first time someone says stop',
          'Ask before touching, borrowing, or hugging',
          'Watch faces and feelings for an "uh-oh"',
          'Give friends space when they need it',
        ],
        positiveOutcome: 'Becomes the kind of friend others trust',
        suggestedPrompts: [
          'A friend does not want to play the same game',
          'Someone needs quiet time alone',
          'A companion says "please don\'t" during a game',
        ],
      ),
      const TherapeuticScenario(
        id: 'focus_asking_for_help',
        title: 'Asking for Help',
        description: 'Character learns it\'s okay to ask for clarification',
        goal: TherapeuticGoal.focus,
        copingStrategies: [
          'Raising hand',
          'Saying "I don\'t understand"',
          'Asking specific questions',
          'Finding the right person to ask',
        ],
        positiveOutcome: 'Understands a difficult concept after asking',
        suggestedPrompts: [
          'Struggling with a math problem',
          'Confused by game rules',
          'Lost in a new place',
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
