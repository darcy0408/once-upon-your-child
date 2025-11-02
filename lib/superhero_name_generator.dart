// lib/superhero_name_generator.dart

import 'dart:math';

class SuperheroNameGenerator {
  static final Random _random = Random();

  // Prefixes for superhero names
  static const List<String> _prefixes = [
    'The Amazing',
    'The Incredible',
    'The Mighty',
    'The Fantastic',
    'The Spectacular',
    'The Marvelous',
    'The Super',
    'The Wonder',
    'The Lightning',
    'The Shadow',
    'The Golden',
    'The Silver',
    'The Cosmic',
    'The Thunder',
    'The Star',
    'Captain',
    'Professor',
    'Doctor',
    'Master',
  ];

  // Core hero names
  static const List<String> _coreNames = [
    'Reader',
    'Scholar',
    'Storyteller',
    'Wordsmith',
    'Bookworm',
    'Narrator',
    'Scribe',
    'Champion',
    'Guardian',
    'Defender',
    'Protector',
    'Hero',
    'Knight',
    'Warrior',
    'Adventurer',
  ];

  // Suffixes for names
  static const List<String> _suffixes = [
    'of Knowledge',
    'of Wisdom',
    'of Stories',
    'of Tales',
    'of Books',
    'of Adventure',
    'of Justice',
    'of Truth',
    'of Hope',
    'of Dreams',
    'the Brave',
    'the Bold',
    'the Wise',
    'the Swift',
    'the Strong',
  ];

  // Catchphrases/Mottos
  static const List<String> _mottos = [
    'With knowledge comes power!',
    'Every story makes me stronger!',
    'Reading saves the day!',
    'Words are my superpower!',
    'For truth and literacy!',
    'One story at a time!',
    'Books give me strength!',
    'Knowledge is power!',
    'Stories unite us all!',
    'Reading changes everything!',
    'Adventure awaits in every page!',
    'The power of words!',
    'Learning never stops!',
    'Imagination is my weapon!',
    'Heroes read!',
    'Literacy for all!',
    'Words can change the world!',
    'Every choice matters!',
    'Bravery through stories!',
    'Reading makes heroes!',
  ];

  // Origin story themes
  static const List<String> _originStories = [
    'Gained powers from a magical library',
    'Was struck by lightning while reading',
    'Found a mystical book that changed everything',
    'Made a wish on a falling star while reading',
    'Discovered secret powers through storytelling',
    'Born with the gift of bringing stories to life',
    'Touched an ancient scroll and transformed',
    'Chosen by the spirits of great authors',
    'Inherited powers from a legendary librarian',
    'Gained abilities from reading 1000 books',
  ];

  // Power themes
  static const List<String> _powerThemes = [
    'Speed and agility',
    'Super strength',
    'Mind reading',
    'Time manipulation',
    'Invisibility',
    'Energy projection',
    'Healing abilities',
    'Telepathy',
    'Shape-shifting',
    'Force fields',
  ];

  /// Generate a random superhero name
  static String generateName() {
    final prefix = _prefixes[_random.nextInt(_prefixes.length)];
    final core = _coreNames[_random.nextInt(_coreNames.length)];

    // 50% chance to add a suffix
    if (_random.nextBool()) {
      final suffix = _suffixes[_random.nextInt(_suffixes.length)];
      return '$prefix $core $suffix';
    }

    return '$prefix $core';
  }

  /// Generate multiple name options
  static List<String> generateNameOptions({int count = 3}) {
    final names = <String>{};
    while (names.length < count) {
      names.add(generateName());
    }
    return names.toList();
  }

  /// Generate a random motto/catchphrase
  static String generateMotto() {
    return _mottos[_random.nextInt(_mottos.length)];
  }

  /// Generate multiple motto options
  static List<String> generateMottoOptions({int count = 3}) {
    final mottos = <String>{};
    while (mottos.length < count) {
      mottos.add(generateMotto());
    }
    return mottos.toList();
  }

  /// Generate a random origin story
  static String generateOriginStory() {
    return _originStories[_random.nextInt(_originStories.length)];
  }

  /// Generate multiple origin story options
  static List<String> generateOriginStoryOptions({int count = 3}) {
    final origins = <String>{};
    while (origins.length < count) {
      origins.add(generateOriginStory());
    }
    return origins.toList();
  }

  /// Generate a random power theme
  static String generatePowerTheme() {
    return _powerThemes[_random.nextInt(_powerThemes.length)];
  }

  /// Generate a complete superhero concept
  static SuperheroIdea generateCompleteIdea() {
    return SuperheroIdea(
      name: generateName(),
      motto: generateMotto(),
      originStory: generateOriginStory(),
      powerTheme: generatePowerTheme(),
    );
  }
}

/// A complete superhero idea/concept
class SuperheroIdea {
  final String name;
  final String motto;
  final String originStory;
  final String powerTheme;

  SuperheroIdea({
    required this.name,
    required this.motto,
    required this.originStory,
    required this.powerTheme,
  });
}
