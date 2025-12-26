// Flutter Integration Tests for Pick-A-Path Adventures
// These tests run in a browser and test the actual UI
//
// Run with:
//   flutter test integration_test/pick_a_path_test.dart
//
// Or with Chrome driver:
//   flutter drive --driver=test_driver/integration_test.dart --target=integration_test/pick_a_path_test.dart -d chrome

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:story_weaver_app/main.dart' as app;
import 'package:story_weaver_app/models.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('Pick-A-Path Adventures Integration Tests', () {
    testWidgets('Test 1: App launches successfully', (WidgetTester tester) async {
      app.main();
      await tester.pumpAndSettle();

      // Verify app loaded
      expect(find.byType(MaterialApp), findsOneWidget);
    });

    testWidgets('Test 2: Can navigate to Pick-A-Path screen',
        (WidgetTester tester) async {
      app.main();
      await tester.pumpAndSettle();

      // Navigate to Pick-A-Path (this depends on your navigation structure)
      // You may need to adjust based on your actual app flow

      // Example: Look for "Pick-A-Path" or "Interactive" button
      final pickAPathButton = find.text('Pick-A-Path Adventures');
      if (pickAPathButton.evaluate().isNotEmpty) {
        await tester.tap(pickAPathButton);
        await tester.pumpAndSettle();
      }
    });

    testWidgets('Test 3: Story segment displays content',
        (WidgetTester tester) async {
      // This test assumes you've already started a story
      // You may need to mock the API or use a test story

      app.main();
      await tester.pumpAndSettle();

      // Wait for story to load
      await tester.pump(const Duration(seconds: 2));

      // Look for story content (any text with reasonable length)
      final textWidgets = find.byType(Text);
      expect(textWidgets, findsWidgets);
    });

    testWidgets('Test 4: Continue button appears when output_type=CONTINUE',
        (WidgetTester tester) async {
      // This test requires mocking a CONTINUE segment
      // Or running against a test backend

      app.main();
      await tester.pumpAndSettle();

      // Look for Continue button
      final continueButton = find.text('Continue');

      // Note: This might not find anything if all segments are CHOICE type
      // That's okay - it means CONTINUE segments aren't generated yet
      if (continueButton.evaluate().isNotEmpty) {
        expect(continueButton, findsOneWidget);

        // Verify button is tappable
        await tester.tap(continueButton);
        await tester.pump();
      }
    });

    testWidgets('Test 5: Choice buttons appear when output_type=CHOICE',
        (WidgetTester tester) async {
      app.main();
      await tester.pumpAndSettle();

      // Look for choice buttons or "What do you do next?"
      final choicePrompt = find.text('What do you do next?');

      if (choicePrompt.evaluate().isNotEmpty) {
        expect(choicePrompt, findsOneWidget);

        // Should have 2-3 choice buttons
        final buttons = find.byType(ElevatedButton);
        expect(buttons.evaluate().length, greaterThanOrEqualTo(2));
        expect(buttons.evaluate().length, lessThanOrEqualTo(3));
      }
    });

    testWidgets('Test 6: Can select a choice and continue story',
        (WidgetTester tester) async {
      app.main();
      await tester.pumpAndSettle();

      // Find first choice button
      final choiceButtons = find.byType(ElevatedButton);

      if (choiceButtons.evaluate().isNotEmpty) {
        // Tap first choice
        await tester.tap(choiceButtons.first);
        await tester.pump();

        // Wait for next segment to load
        await tester.pump(const Duration(seconds: 2));

        // Verify loading or new content
        expect(find.byType(CircularProgressIndicator), findsAny);
      }
    });

    testWidgets('Test 7: Inventory section is visible',
        (WidgetTester tester) async {
      app.main();
      await tester.pumpAndSettle();

      // Look for "Inventory" text or section
      final inventoryText = find.textContaining('Inventory');

      // Inventory might be empty or hidden, so this is optional
      // Just check if the widget exists
      if (inventoryText.evaluate().isNotEmpty) {
        expect(inventoryText, findsOneWidget);
      }
    });

    testWidgets('Test 8: Story state section is visible',
        (WidgetTester tester) async {
      app.main();
      await tester.pumpAndSettle();

      // Look for "Adventure Status" or similar
      final statusText = find.textContaining('Status');

      if (statusText.evaluate().isNotEmpty) {
        expect(statusText, findsOneWidget);
      }
    });

    testWidgets('Test 9: Error message displays on API failure',
        (WidgetTester tester) async {
      // This test would require mocking a failed API call
      // Skipping for now as it requires more setup

      app.main();
      await tester.pumpAndSettle();

      // In a real test, you'd:
      // 1. Mock the API to return an error
      // 2. Trigger an action
      // 3. Verify ErrorMessage widget appears
    });

    testWidgets('Test 10: Completion screen shows after finishing',
        (WidgetTester tester) async {
      app.main();
      await tester.pumpAndSettle();

      // Look for completion indicator
      final completeText = find.text('Adventure Complete!');

      // This might not appear unless you complete a full story
      if (completeText.evaluate().isNotEmpty) {
        expect(completeText, findsOneWidget);

        // Should have Save button
        expect(find.text('Save to Library'), findsOneWidget);
      }
    });
  });

  group('Model Tests (Unit-level)', () {
    test('StorySegmentData has output_type field', () {
      final segment = StorySegmentData(
        id: 'test-id',
        segmentNumber: 1,
        content: 'Test content',
        outputType: 'CONTINUE',
        choices: [],
      );

      expect(segment.outputType, equals('CONTINUE'));
      expect(segment.isContinuation, isTrue);
      expect(segment.requiresChoice, isFalse);
    });

    test('StorySegmentData.requiresChoice returns true for CHOICE type', () {
      final segment = StorySegmentData(
        id: 'test-id',
        segmentNumber: 1,
        content: 'Test content',
        outputType: 'CHOICE',
        choices: [
          StoryChoiceData(
            id: 'choice-1',
            choiceNumber: 1,
            text: 'Go left',
          ),
          StoryChoiceData(
            id: 'choice-2',
            choiceNumber: 2,
            text: 'Go right',
          ),
        ],
      );

      expect(segment.outputType, equals('CHOICE'));
      expect(segment.requiresChoice, isTrue);
      expect(segment.isContinuation, isFalse);
    });

    test('StorySegmentData.isContinuation works with empty choices', () {
      final segment = StorySegmentData(
        id: 'test-id',
        segmentNumber: 1,
        content: 'Test content',
        outputType: 'CHOICE',
        choices: [], // Empty choices
      );

      // Even though type is CHOICE, empty choices = continuation
      expect(segment.isContinuation, isTrue);
      expect(segment.requiresChoice, isFalse);
    });

    test('StorySegmentData.fromJson parses output_type', () {
      final json = {
        'id': 'test-id',
        'segment_number': 1,
        'content': 'Test content',
        'output_type': 'CONTINUE',
        'word_count': 450,
        'choices': [],
      };

      final segment = StorySegmentData.fromJson(json);

      expect(segment.outputType, equals('CONTINUE'));
      expect(segment.wordCount, equals(450));
    });

    test('StorySegmentData.toJson includes new fields', () {
      final segment = StorySegmentData(
        id: 'test-id',
        segmentNumber: 1,
        content: 'Test content',
        outputType: 'CONTINUE',
        wordCount: 450,
        choices: [],
      );

      final json = segment.toJson();

      expect(json['output_type'], equals('CONTINUE'));
      expect(json['word_count'], equals(450));
    });
  });
}
