/// Centralized test fixtures and mock data for Story Weaver tests
library test_fixtures;

import 'package:story_weaver_app/models/character.dart';
import 'package:story_weaver_app/models/generated_avatar.dart';
import 'package:story_weaver_app/models/story.dart';
import 'package:story_weaver_app/models/interactive_story_data.dart';

// ============================================================================
// CHARACTER FIXTURES
// ============================================================================

/// Sample character data for testing
Character getSampleCharacter() {
  return Character(
    id: 'char_test_123',
    name: 'Luna',
    age: 7,
    personality: {'brave': 8, 'curious': 9, 'kind': 7},
    interests: ['astronomy', 'reading', 'adventure'],
    avatarSeed: 'luna-seed-123',
    createdAt: DateTime(2024, 1, 1),
  );
}

/// Character with minimal data
Character getMinimalCharacter() {
  return Character(
    id: 'char_min_456',
    name: 'Sam',
    age: 5,
    createdAt: DateTime(2024, 1, 1),
  );
}

/// Character with pets
Character getCharacterWithPets() {
  return Character(
    id: 'char_pets_789',
    name: 'Mia',
    age: 10,
    personality: {'kind': 9},
    pets: [
      {'name': 'Fluffy', 'species': 'cat'},
      {'name': 'Rex', 'species': 'dog'},
    ],
    createdAt: DateTime(2024, 1, 1),
  );
}

// ============================================================================
// AVATAR FIXTURES
// ============================================================================

/// Sample generated avatar
GeneratedAvatar getSampleAvatar() {
  return GeneratedAvatar(
    imageBase64: 'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNk+M9QDwADhgGAWjR9awAAAABJRU5ErkJggg==',
    seed: 'luna-seed-123',
    prompt: 'A brave young astronomer',
  );
}

/// Avatar with asset path (curated gallery)
GeneratedAvatar getCuratedAvatar() {
  return GeneratedAvatar(
    assetPath: 'assets/avatars/midjourney/avatar_001.webp',
    seed: 'curated-001',
    prompt: 'Curated avatar from gallery',
  );
}

// ============================================================================
// STORY FIXTURES
// ============================================================================

/// Sample generated story
Story getSampleStory() {
  return Story(
    id: 'story_test_123',
    characterId: 'char_test_123',
    title: 'Luna and the Starlight Owl',
    storyText: 'Once upon a time, Luna the brave astronomer discovered a talking owl named Hoot. Together they embarked on a magical journey through the stars...',
    wisdomGem: 'True friendship knows no boundaries',
    createdAt: DateTime(2024, 1, 1),
    theme: 'Adventure',
    customElements: 'talking owl, rainbow bridge',
  );
}

/// Story with rhyme time
Story getRhymeTimeStory() {
  return Story(
    id: 'story_rhyme_456',
    characterId: 'char_test_123',
    title: 'The Dragon\'s Flight',
    storyText: 'In a land so far and wide,\nLived a dragon with great pride.\nHe loved to soar up in the sky,\nAnd watch the clouds go floating by.',
    wisdomGem: 'Confidence comes from within',
    createdAt: DateTime(2024, 1, 2),
    rhymeTime: true,
  );
}

/// Epic length story
Story getEpicStory() {
  return Story(
    id: 'story_epic_789',
    characterId: 'char_test_123',
    title: 'The Quest for the Crystal Kingdom',
    storyText: '''Chapter 1: The Beginning

Luna stood at the edge of the Enchanted Forest, her heart filled with determination. She had heard tales of the Crystal Kingdom, a place where dreams came true and magic flowed like water.

Chapter 2: The Journey

As she ventured deeper into the forest, she encountered many challenges...

[... continues for 1500+ words ...]''',
    wisdomGem: 'Great journeys require great courage',
    createdAt: DateTime(2024, 1, 3),
    storyLength: 'epic',
  );
}

// ============================================================================
// INTERACTIVE STORY FIXTURES
// ============================================================================

/// Sample interactive story data
InteractiveStoryData getSampleInteractiveStory() {
  return InteractiveStoryData(
    storyId: 'interactive_123',
    characterName: 'Luna',
    currentSegment: 'You find yourself at a crossroads. To the left, a dark forest beckons. To the right, a bright meadow awaits.',
    choices: [
      'Explore the dark forest',
      'Walk through the bright meadow',
      'Set up camp here',
    ],
    path: ['start', 'crossroads'],
    theme: 'Adventure',
  );
}

/// Interactive story at different depth
InteractiveStoryData getDeepInteractiveStory() {
  return InteractiveStoryData(
    storyId: 'interactive_456',
    characterName: 'Luna',
    currentSegment: 'Deep in the forest, you discover a hidden cave...',
    choices: [
      'Enter the cave',
      'Continue exploring',
    ],
    path: ['start', 'crossroads', 'dark_forest', 'hidden_path', 'mysterious_cave'],
    theme: 'Mystery',
  );
}

// ============================================================================
// API RESPONSE FIXTURES
// ============================================================================

/// Mock story generation response (success)
Map<String, dynamic> getMockStoryGenerationResponse() {
  return {
    'story': {
      'id': 'story_new_123',
      'story_text': 'Once upon a time...',
      'title': 'A Magical Adventure',
      'wisdom_gem': 'Believe in yourself',
      'created_at': '2024-01-01T12:00:00Z',
    },
    'task_id': 'task_celery_123',
  };
}

/// Mock subscription status response (free tier)
Map<String, dynamic> getMockSubscriptionStatusFree() {
  return {
    'tier': 'free',
    'status': 'active',
    'stories_remaining': 1,
    'stories_used': 2,
    'story_limit': 3,
    'can_generate_story': true,
  };
}

/// Mock subscription status response (premium tier)
Map<String, dynamic> getMockSubscriptionStatusPremium() {
  return {
    'tier': 'premium',
    'status': 'active',
    'stories_remaining': 9999,
    'stories_used': 42,
    'story_limit': -1,  // Unlimited
    'can_generate_story': true,
    'subscription_end': '2024-12-31T23:59:59Z',
  };
}

/// Mock error response (rate limit exceeded)
Map<String, dynamic> getMockRateLimitError() {
  return {
    'error': 'Rate limit exceeded',
    'message': 'You have reached your free tier limit of 3 stories. Please upgrade to continue.',
    'code': 'RATE_LIMIT_EXCEEDED',
  };
}

/// Mock error response (validation error)
Map<String, dynamic> getMockValidationError() {
  return {
    'error': 'Validation error',
    'message': 'Invalid age: must be between 5 and 17',
    'code': 'VALIDATION_ERROR',
  };
}

// ============================================================================
// SUBSCRIPTION FIXTURES
// ============================================================================

/// Mock Stripe checkout session URL
String getMockStripeCheckoutUrl() {
  return 'https://checkout.stripe.com/pay/cs_test_mock123';
}

/// Mock Stripe success parameters
Map<String, String> getMockStripeSuccessParams() {
  return {
    'session_id': 'cs_test_success_123',
    'payment_status': 'paid',
  };
}

// ============================================================================
// VALIDATION TEST DATA
// ============================================================================

/// Valid ages for testing
List<int> getValidAges() {
  return [5, 7, 10, 13, 15, 17];
}

/// Invalid ages for testing
List<int> getInvalidAges() {
  return [-1, 0, 3, 4, 18, 20, 100];
}

/// Valid story lengths
List<String> getValidStoryLengths() {
  return ['quick', 'standard', 'epic', 'QUICK', 'Standard', 'EPIC'];
}

/// Invalid story lengths
List<String> getInvalidStoryLengths() {
  return ['', 'short', 'long', 'medium', 'extra-long'];
}

// ============================================================================
// CUSTOM ELEMENTS TEST DATA
// ============================================================================

/// Sample custom elements for story generation
List<String> getSampleCustomElements() {
  return [
    'talking owl',
    'rainbow bridge',
    'magic compass',
    'friendly dragon',
    'crystal cave',
  ];
}

/// Complex custom elements (edge cases)
List<String> getComplexCustomElements() {
  return [
    'talking owl with golden feathers',
    'rainbow bridge that sings',
    'a very special magic compass that only works at midnight',
  ];
}

// ============================================================================
// WIZARD DATA FIXTURES
// ============================================================================

/// Sample wizard data (story creation flow)
Map<String, dynamic> getSampleWizardData() {
  return {
    'character_id': 'char_test_123',
    'character_name': 'Luna',
    'age': 7,
    'scenario': 'Adventure Quest',
    'mood': 'excited',
    'custom_elements': 'talking owl, magic compass',
    'rhyme_time': false,
    'include_pictures': true,
    'story_length': 'standard',
  };
}

/// Wizard data for therapeutic story
Map<String, dynamic> getTherapeuticWizardData() {
  return {
    'character_id': 'char_test_123',
    'character_name': 'Luna',
    'age': 7,
    'scenario': 'My Safe Space',
    'mood': 'anxious',
    'companion': 'Fluffy the cat',
    'custom_elements': 'cozy blanket fort, warm tea',
    'therapeutic_mode': true,
  };
}
