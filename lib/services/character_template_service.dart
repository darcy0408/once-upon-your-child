import 'package:flutter/material.dart';

class CharacterTemplate {
  final String key;
  final String name;
  final IconData icon;
  final Color color;
  final String description;
  final int suggestedAge;
  final String characterStyle;
  final String characterType;
  final String? suggestedOutfit;
  final String? comfortItem;
  final Map<String, int> personality; // keyed by slider key, 0-100
  final List<String> likes;
  final List<String> dislikes;
  final List<String> strengths;
  final List<String> fears;

  const CharacterTemplate({
    required this.key,
    required this.name,
    required this.icon,
    required this.color,
    required this.description,
    required this.suggestedAge,
    required this.characterStyle,
    required this.characterType,
    required this.personality,
    this.suggestedOutfit,
    this.comfortItem,
    this.likes = const [],
    this.dislikes = const [],
    this.strengths = const [],
    this.fears = const [],
  });
}

class CharacterTemplateService {
  CharacterTemplateService._();

  static List<CharacterTemplate> getTemplates() {
    return [
      CharacterTemplate(
        key: 'adventurer',
        name: 'The Bold Adventurer',
        icon: Icons.explore,
        color: Colors.orange,
        description: 'Brave explorer who chases mysteries and never backs down from a quest.',
        suggestedAge: 7,
        characterStyle: 'Explorer',
        characterType: 'Explorer',
        suggestedOutfit: 'Adventure vest and boots',
        personality: {
          'adventure': 85,
          'sociability': 70,
          'organization_planning': 55,
          'assertiveness': 70,
          'expressiveness': 75,
          'feelings_sharing': 60,
          'problem_solving': 65,
          'play_preference': 60,
        },
        likes: ['maps', 'puzzles', 'animals'],
        strengths: ['Brave', 'Curious', 'Determined'],
        fears: ['Dark caves'],
      ),
      CharacterTemplate(
        key: 'thinker',
        name: 'The Logic Luminary',
        icon: Icons.psychology,
        color: Colors.blue,
        description: 'Brilliant thinker who solves puzzles with facts and scientific wonder.',
        suggestedAge: 9,
        characterStyle: 'Young Scientist',
        characterType: 'Explorer',
        suggestedOutfit: 'Lab coat and notebook',
        personality: {
          'adventure': 45,
          'sociability': 50,
          'organization_planning': 80,
          'assertiveness': 55,
          'expressiveness': 40,
          'feelings_sharing': 50,
          'problem_solving': 80,
          'play_preference': 55,
        },
        likes: ['science', 'quizzes', 'brain teasers'],
        strengths: ['Smart', 'Patient', 'Curious'],
        fears: ['Being wrong in public'],
      ),
      CharacterTemplate(
        key: 'artist',
        name: 'The Creative Catalyst',
        icon: Icons.brush,
        color: Colors.purple,
        description: 'Imaginative soul who paints the world with vibrant dreams and stories.',
        suggestedAge: 8,
        characterStyle: 'Creative Artist',
        characterType: 'Everyday Kid',
        suggestedOutfit: 'Paint-splatter hoodie',
        personality: {
          'adventure': 60,
          'sociability': 55,
          'organization_planning': 40,
          'assertiveness': 50,
          'expressiveness': 85,
          'feelings_sharing': 70,
          'problem_solving': 70,
          'play_preference': 50,
        },
        likes: ['painting', 'music', 'stories'],
        strengths: ['Creative', 'Expressive', 'Kind'],
        fears: ['Messy accidents'],
      ),
      CharacterTemplate(
        key: 'helper',
        name: 'The Heart Hero',
        icon: Icons.volunteer_activism,
        color: Colors.teal,
        description: 'Kind protector who leads with empathy and always supports a friend in need.',
        suggestedAge: 6,
        characterStyle: 'Regular Kid',
        characterType: 'Everyday Kid',
        comfortItem: 'Cozy blanket',
        personality: {
          'adventure': 45,
          'sociability': 65,
          'organization_planning': 50,
          'assertiveness': 45,
          'expressiveness': 60,
          'feelings_sharing': 80,
          'problem_solving': 55,
          'play_preference': 65,
        },
        likes: ['helping', 'gardening', 'animals'],
        strengths: ['Caring', 'Patient', 'Loyal'],
        fears: ['Friends feeling sad'],
      ),
      CharacterTemplate(
        key: 'athlete',
        name: 'The Energy Engine',
        icon: Icons.sports_soccer,
        color: Colors.redAccent,
        description: 'High-energy champion who loves teamwork and the thrill of the game.',
        suggestedAge: 10,
        characterStyle: 'Sporty Kid',
        characterType: 'Explorer',
        suggestedOutfit: 'Team jersey',
        personality: {
          'adventure': 75,
          'sociability': 75,
          'organization_planning': 55,
          'assertiveness': 70,
          'expressiveness': 65,
          'feelings_sharing': 55,
          'problem_solving': 60,
          'play_preference': 70,
        },
        likes: ['soccer', 'races', 'outdoors'],
        strengths: ['Energetic', 'Determined', 'Teamwork'],
        fears: ['Letting the team down'],
      ),
      CharacterTemplate(
        key: 'shy_one',
        name: 'The Quiet Observer',
        icon: Icons.self_improvement,
        color: Colors.indigo,
        description: 'Gentle soul who notices the tiny details and treasures quiet moments.',
        suggestedAge: 7,
        characterStyle: 'Regular Kid',
        characterType: 'Everyday Kid',
        comfortItem: 'Favorite plushie',
        personality: {
          'adventure': 35,
          'sociability': 30,
          'organization_planning': 60,
          'assertiveness': 30,
          'expressiveness': 30,
          'feelings_sharing': 35,
          'problem_solving': 55,
          'play_preference': 45,
        },
        likes: ['reading', 'quiet nooks', 'drawing'],
        strengths: ['Thoughtful', 'Gentle', 'Observant'],
        fears: ['Crowded rooms'],
      ),
    ];
  }
}
