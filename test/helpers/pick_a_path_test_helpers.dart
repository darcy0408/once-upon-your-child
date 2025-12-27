import 'package:story_weaver_app/models.dart';

/// Test helper utilities for Pick-A-Path Adventure tests
class PickAPathTestHelpers {
  /// Creates a mock Character for testing
  static Character createTestCharacter({
    String id = 'test_char_001',
    String name = 'TestHero',
    int age = 8,
  }) {
    return Character(
      id: id,
      name: name,
      age: age,
      gender: 'Girl',
      role: 'Brave Adventurer',
      personalityTraits: ['brave', 'curious'],
    );
  }

  /// Creates a mock StorySegmentData for testing
  static StorySegmentData createTestSegment({
    String id = 'segment_001',
    int segmentNumber = 1,
    String? content,
    List<StoryChoiceData>? choices,
  }) {
    return StorySegmentData(
      id: id,
      segmentNumber: segmentNumber,
      content: content ??
          'You stand at the edge of the Enchanted Forest. The trees shimmer with golden leaves that dance in the gentle breeze. A mysterious path winds ahead, disappearing into the shadows.',
      choices: choices ?? createTestChoices(count: 2),
      createdAt: DateTime.now(),
    );
  }

  /// Creates mock StoryChoiceData for testing
  static List<StoryChoiceData> createTestChoices({int count = 2}) {
    final choices = <StoryChoiceData>[];
    for (int i = 1; i <= count; i++) {
      choices.add(StoryChoiceData(
        id: 'choice_$i',
        choiceNumber: i,
        text: 'Choice $i: ${_getChoiceText(i)}',
      ));
    }
    return choices;
  }

  static String _getChoiceText(int num) {
    switch (num) {
      case 1:
        return 'Follow the golden path';
      case 2:
        return 'Explore the dark forest';
      case 3:
        return 'Climb the ancient tree';
      case 4:
        return 'Search for hidden treasures';
      default:
        return 'Make a choice';
    }
  }

  /// Creates a mock InventoryItemData for testing
  static InventoryItemData createTestInventoryItem({
    String id = 'item_001',
    String name = 'Magic Compass',
    String? description,
    int acquiredAtSegment = 1,
  }) {
    return InventoryItemData(
      id: id,
      name: name,
      description: description ?? 'A compass that always points to adventure',
      acquiredAtSegment: acquiredAtSegment,
    );
  }

  /// Creates a mock StoryStateData for testing
  static StoryStateData createTestState({
    String location = 'Enchanted Forest',
    String goal = 'Find the lost treasure',
    List<String>? clues,
    String companionStatus = 'Your companion is by your side',
  }) {
    return StoryStateData(
      currentLocation: location,
      currentGoal: goal,
      keyClues: clues ?? ['The path glows at night'],
      companionStatus: companionStatus,
    );
  }

  /// Creates a complete StartStoryResponse JSON for mocking
  static Map<String, dynamic> createStartStoryResponseJson({
    String storyId = 'story_001',
    String title = 'The Enchanted Adventure',
    int segmentNumber = 1,
    String? content,
    int choiceCount = 2,
    List<Map<String, dynamic>>? inventory,
    Map<String, dynamic>? state,
  }) {
    return {
      'story_id': storyId,
      'title': title,
      'segment': {
        'id': 'segment_001',
        'segment_number': segmentNumber,
        'content': content ??
            'You stand at the edge of the Enchanted Forest. The trees shimmer with golden leaves.',
        'choices': List.generate(choiceCount, (i) => {
              'id': 'choice_${i + 1}',
              'choice_number': i + 1,
              'text': 'Choice ${i + 1}',
            }),
      },
      'inventory': inventory ?? [],
      'state': state ??
          {
            'current_location': 'Enchanted Forest',
            'current_goal': 'Begin your adventure',
            'key_clues': [],
            'companion_status': '',
          },
      'is_completed': false,
    };
  }

  /// Creates a ContinueStoryResponse JSON for mocking
  static Map<String, dynamic> createContinueStoryResponseJson({
    String storyId = 'story_001',
    int segmentNumber = 2,
    String? content,
    int choiceCount = 2,
    List<Map<String, dynamic>>? inventory,
    Map<String, dynamic>? state,
    bool isCompleted = false,
  }) {
    return {
      'story_id': storyId,
      'segment': {
        'id': 'segment_002',
        'segment_number': segmentNumber,
        'content': content ??
            'You follow the golden path deeper into the forest. Strange sounds echo around you.',
        'choices': isCompleted
            ? []
            : List.generate(choiceCount, (i) => {
                  'id': 'choice_${i + 1}',
                  'choice_number': i + 1,
                  'text': 'Choice ${i + 1}',
                }),
      },
      'inventory': inventory ?? [],
      'state': state ??
          {
            'current_location': 'Deep Forest',
            'current_goal': 'Continue your adventure',
            'key_clues': ['The path leads north'],
            'companion_status': 'Your companion is alert',
          },
      'is_completed': isCompleted,
    };
  }

  /// Creates age-appropriate content for testing
  static String createAgeAppropriateContent(int age, int segmentNumber) {
    if (age <= 5) {
      return 'You see a big tree. It is green. You can go left or right.';
    } else if (age <= 8) {
      return 'You stand at the edge of the Enchanted Forest. The trees shimmer with golden leaves that dance in the gentle breeze. A mysterious path winds ahead, disappearing into the shadows.';
    } else {
      return 'As you venture deeper into the ancient forest, the canopy above filters the sunlight into ethereal beams that illuminate the moss-covered ground. The air is thick with the scent of pine and something else—something magical. Your footsteps echo softly as you navigate the winding path, each turn revealing new mysteries waiting to be discovered.';
    }
  }
}


