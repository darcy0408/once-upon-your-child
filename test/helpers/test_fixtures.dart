// Centralized test fixtures and mock data for Story Weaver tests.
import 'package:story_weaver_app/models.dart';

// ============================================================================
// CHARACTER FIXTURES
// ============================================================================

/// Sample character data for testing
Character getSampleCharacter() {
  return Character(
    id: 'char_test_123',
    name: 'Luna',
    age: 7,
    role: 'Hero',
    personalitySliders: {'brave': 80, 'curious': 90, 'kind': 70},
    likes: ['astronomy', 'reading', 'adventure'],
    generatedAvatar: getSampleAvatar(),
  );
}

/// Character with minimal data
Character getMinimalCharacter() {
  return Character(
    id: 'char_min_456',
    name: 'Sam',
    age: 5,
    role: 'Helper',
  );
}

/// Character with pets
Character getCharacterWithPets() {
  return Character(
    id: 'char_pets_789',
    name: 'Mia',
    age: 10,
    role: 'Hero',
    personalitySliders: {'kind': 90},
    pets: [
      {'name': 'Fluffy', 'species': 'cat'},
      {'name': 'Rex', 'species': 'dog'},
    ],
  );
}

// ============================================================================
// AVATAR FIXTURES
// ============================================================================

/// Sample generated avatar
GeneratedAvatar getSampleAvatar() {
  return GeneratedAvatar(
    id: 'avatar_test_123',
    imageBase64: 'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNk+M9QDwADhgGAWjR9awAAAABJRU5ErkJggg==',
    seed: 'luna-seed-123',
    style: 'cartoon',
    attributes: {
      'hair_style': 'curly',
      'hair_color': 'brown',
      'skin_tone': 'medium',
      'outfit': 'explorer',
      'expression': 'happy',
    },
    generatedAt: DateTime(2024, 1, 1),
  );
}

/// Avatar with asset path (curated gallery)
GeneratedAvatar getCuratedAvatar() {
  return GeneratedAvatar(
    id: 'avatar_curated_001',
    imageBase64: 'data:image/webp;base64,AA==',
    seed: 'curated-001',
    style: 'watercolor',
    attributes: {
      'hair_style': 'wavy',
      'hair_color': 'black',
      'skin_tone': 'light',
      'outfit': 'wizard',
      'expression': 'calm',
    },
    generatedAt: DateTime(2024, 1, 2),
  );
}

// ============================================================================
// STORY FIXTURES
// ============================================================================

/// Sample generated story
SavedStory getSampleStory() {
  return SavedStory(
    id: 'story_test_123',
    title: 'Luna and the Starlight Owl',
    storyText: 'Once upon a time, Luna the brave astronomer discovered a talking owl named Hoot. Together they embarked on a magical journey through the stars...',
    wisdomGem: 'True friendship knows no boundaries',
    createdAt: DateTime(2024, 1, 1),
    theme: 'Adventure',
    characters: [getSampleCharacter()],
  );
}

/// Story with rhyme time
SavedStory getRhymeTimeStory() {
  return SavedStory(
    id: 'story_rhyme_456',
    title: 'The Dragon\'s Flight',
    storyText: 'In a land so far and wide,\nLived a dragon with great pride.\nHe loved to soar up in the sky,\nAnd watch the clouds go floating by.',
    wisdomGem: 'Confidence comes from within',
    createdAt: DateTime(2024, 1, 2),
    theme: 'Adventure',
    characters: [getSampleCharacter()],
    isRhyming: true,
  );
}

/// Epic length story
SavedStory getEpicStory() {
  return SavedStory(
    id: 'story_epic_789',
    title: 'The Quest for the Crystal Kingdom',
    storyText: '''Chapter 1: The Beginning

Luna stood at the edge of the Enchanted Forest, her heart filled with determination. She had heard tales of the Crystal Kingdom, a place where dreams came true and magic flowed like water.

Chapter 2: The Journey

As she ventured deeper into the forest, she encountered many challenges...

[... continues for 1500+ words ...]''',
    wisdomGem: 'Great journeys require great courage',
    createdAt: DateTime(2024, 1, 3),
    theme: 'Adventure',
    characters: [getSampleCharacter()],
  );
}

// ============================================================================
// INTERACTIVE STORY FIXTURES
// ============================================================================

/// Sample interactive story data
InteractiveStoryData getSampleInteractiveStory() {
  return InteractiveStoryData(
    id: 'interactive_123',
    title: 'Luna at the Crossroads',
    theme: 'Adventure',
    tone: 'whimsical',
    length: 'medium',
    age: 7,
    currentSegmentNumber: 2,
    isCompleted: false,
    createdAt: DateTime(2024, 1, 1),
    inventory: [
      InventoryItemData(
        id: 'item_map',
        name: 'Star Map',
        acquiredAtSegment: 1,
      ),
    ],
    state: StoryStateData(
      currentLocation: 'Crossroads',
      currentGoal: 'Choose a path',
      keyClues: ['forest whispers', 'sunlit meadow'],
      companionStatus: 'Hoot is nearby',
    ),
  );
}

/// Interactive story at different depth
InteractiveStoryData getDeepInteractiveStory() {
  return InteractiveStoryData(
    id: 'interactive_456',
    title: 'Cave of Echoes',
    theme: 'Mystery',
    tone: 'adventurous',
    length: 'long',
    age: 8,
    currentSegmentNumber: 5,
    isCompleted: false,
    createdAt: DateTime(2024, 1, 2),
    inventory: [
      InventoryItemData(
        id: 'item_lantern',
        name: 'Lantern',
        acquiredAtSegment: 3,
      ),
      InventoryItemData(
        id: 'item_key',
        name: 'Crystal Key',
        acquiredAtSegment: 4,
      ),
    ],
    state: StoryStateData(
      currentLocation: 'Hidden Cave',
      currentGoal: 'Unlock the crystal chamber',
      keyClues: ['faint glow', 'echoing footsteps'],
      companionStatus: 'Hoot is nervous',
      timePressure: 'before sunset',
    ),
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
