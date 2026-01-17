# Pick-A-Path Adventures Test Suite

This directory contains comprehensive tests for the Pick-A-Path Adventures feature.

## Test Structure

### Test Files

1. **`helpers/pick_a_path_test_helpers.dart`**
   - Test helper utilities for creating mock data
   - Factory methods for Character, StorySegmentData, InventoryItemData, etc.
   - JSON response builders for API mocking

2. **`widgets/pick_a_path_adventure_screen_test.dart`**
   - Widget tests for the PickAPathAdventureScreen
   - Tests loading states, segment display, choices, inventory, status
   - Tests error handling and age-appropriate content

3. **`integration/wizard_pick_a_path_test.dart`**
   - Integration tests for wizard flow
   - Tests Interactive Mode toggle
   - Tests navigation from wizard to Pick-A-Path screen

## Running Tests

### Run all Pick-A-Path tests:
```bash
flutter test test/widgets/pick_a_path_adventure_screen_test.dart
flutter test test/integration/wizard_pick_a_path_test.dart
```

### Run specific test groups:
```bash
flutter test test/widgets/pick_a_path_adventure_screen_test.dart --name "Loading State"
flutter test test/widgets/pick_a_path_adventure_screen_test.dart --name "Choice Selection"
```

## Test Coverage

### Test Suite F: Wizard Integration
- ✅ F1: Access Wizard Story Creator
- ✅ F2: Complete Hero Creator (Step 1)
- ✅ F3: Select Feelings (Step 2)
- ✅ F4: Choose Companion (Step 3)
- ✅ F5: Enable Interactive Mode (Step 4)

### Test Suite G: Pick-A-Path Screen
- ✅ G1: Story Loading
- ✅ G2: Initial Segment Display
- ✅ G3: Inventory Section
- ✅ G4: Adventure Status Section
- ✅ G5: Make First Choice
- ✅ G6: Second Segment Display
- ✅ G7: Inventory Updates
- ✅ G8: Status Updates
- ✅ G9: Complete Short Story
- ✅ G10: Completion Screen
- ✅ G11: Save Story to Library
- ✅ G12: Navigate to Library

### Test Suite H: Different Configurations
- ✅ H1: Medium Story (3 choices)
- ✅ H2: Long Story (4 choices)
- ✅ H3: Age 5 Content
- ✅ H4: Age 14 Content

### Test Suite I: Error Handling
- ✅ I1: Network Error During Generation
- ✅ I2: Network Error During Choice
- ✅ I3: Minimal Data Handling

## HTTP Mocking Note

**Important:** The `InteractiveStoryService` currently doesn't support dependency injection for HTTP clients. To properly test HTTP calls, you have two options:

### Option 1: Modify InteractiveStoryService (Recommended for production)
Add an optional `http.Client?` parameter to service methods:

```dart
Future<StartStoryResponse> startInteractiveStory({
  // ... existing parameters
  http.Client? client,
}) async {
  final httpClient = client ?? http.Client();
  // Use httpClient instead of http.post
}
```

### Option 2: Use Integration Tests
Create integration tests that run against a test backend server or use `HttpOverrides` (more complex).

## Current Test Status

The test files are structured and ready, but HTTP mocking needs to be implemented based on your preferred approach. The test helpers and structure are complete and can be used once HTTP mocking is in place.

## Next Steps

1. **Implement HTTP mocking** in `InteractiveStoryService` or use integration test approach
2. **Run tests** and fix any issues
3. **Add more edge case tests** as needed
4. **Create E2E tests** using `integration_test` package for full flow testing

## Test Helpers Usage

```dart
import '../helpers/pick_a_path_test_helpers.dart';

// Create test character
final character = PickAPathTestHelpers.createTestCharacter(
  name: 'TestHero',
  age: 8,
);

// Create test segment
final segment = PickAPathTestHelpers.createTestSegment(
  segmentNumber: 1,
  content: 'Story content here',
  choices: PickAPathTestHelpers.createTestChoices(count: 2),
);

// Create API response JSON
final responseJson = PickAPathTestHelpers.createStartStoryResponseJson(
  storyId: 'story_001',
  title: 'The Adventure',
  choiceCount: 2,
);
```



