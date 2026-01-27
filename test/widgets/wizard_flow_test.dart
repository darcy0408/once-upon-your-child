import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mockito/mockito.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:isar/isar.dart';

import 'package:story_weaver_app/screens/wizard_story_screen.dart';
import 'package:story_weaver_app/services/api_service_manager.dart';
import 'package:story_weaver_app/services/avatar_generation_state.dart';
import 'package:story_weaver_app/theme/app_theme.dart';
import 'package:story_weaver_app/services/isar_service_io.dart';

// Mock Isar and Collection
class MockIsar extends Mock implements Isar {
  @override
  String get name => 'mock_isar';

  @override
  Future<T> writeTxn<T>(Future<T> Function() callback, {bool silent = false}) async {
    return callback();
  }

  @override
  IsarCollection<T> collection<T>() {
    return MockIsarCollection<T>();
  }
}

class MockIsarCollection<T> extends Mock implements IsarCollection<T> {
  @override
  Future<int> put(T object) async => 1;
  
  @override
  QueryBuilder<T, T, QWhere> where({bool distinct = false, Sort sort = Sort.asc}) {
     throw UnimplementedError();
  }
}

// Helper for HttpOverrides
class TestHttpOverrides extends HttpOverrides {
  final MockClient mockClient;
  TestHttpOverrides(this.mockClient);

  @override
  HttpClient createHttpClient(SecurityContext? context) {
    return super.createHttpClient(context);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late MockClient mockClient;
  late MockIsar mockIsar;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    AvatarGenerationState().reset();
    
    mockIsar = MockIsar();
    IsarService.setTestInstance(mockIsar);
    
    // Mock HTTP Client
    mockClient = MockClient((request) async {
      final url = request.url.toString();
      debugPrint('🌐 Mock HTTP Request: $url');

      if (url.contains('/get-characters')) {
        return http.Response(jsonEncode({
          'characters': []
        }), 200);
      }

      if (url.contains('/generate-story')) {
        return http.Response(jsonEncode({
          'title': 'The Magical Test Story',
          'story_text': 'Once upon a time, a test hero started an adventure... This story is definitely longer than 100 characters so that the substring check does not fail during the test execution.',
          'wisdom_gem': 'Testing is magic!',
          'pages': [
            {'content': 'Page 1 content', 'image_prompt': 'A hero'},
            {'content': 'Page 2 content', 'image_prompt': 'A dragon'}
          ],
          'adventure_steps': []
        }), 200);
      }
      
      if (url.contains('/create-character')) {
         return http.Response(jsonEncode({
          'character_id': 'char_123',
          'name': 'Test Hero'
         }), 200);
      }

      if (url.contains('/achievement/sync')) {
        return http.Response('OK', 200);
      }

      return http.Response('Not Found', 404);
    });

    ApiServiceManager.setTestClient(mockClient);
    HttpOverrides.global = TestHttpOverrides(mockClient);
  });

  tearDown(() {
    ApiServiceManager.setTestClient(null);
    AvatarGenerationState().reset();
    HttpOverrides.global = null;
  });

  testWidgets('Full Wizard Flow Integration Test', (WidgetTester tester) async {
    // Set a taller screen size to avoid scrolling issues
    tester.view.physicalSize = const Size(800, 1200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    // 1. Pump the Wizard Screen
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: const WizardStoryScreen(availableCharacters: []),
      ),
    );
    
    // Use pump(Duration) to handle infinite animations (MoonPhaseProgress)
    await tester.pump(const Duration(seconds: 1));

    // --- STEP 1: Hero Creator ---
    expect(find.text('Create a Character'), findsOneWidget);

    // Enter Name
    await tester.enterText(find.byType(TextField).first, 'Test Hero');
    await tester.pump();

    // Select Archetype (The Storm Rider)
    await tester.tap(find.text('The Storm Rider'));
    await tester.pump();

    // Ensure "Continue" button is visible and tap it
    final continueButton = find.text('Continue');
    await tester.ensureVisible(continueButton);
    await tester.tap(continueButton);
    
    // Transition animation
    await tester.pump(const Duration(milliseconds: 500)); 
    await tester.pump(const Duration(seconds: 1)); // Wait for settle

    // --- STEP 2: Feeling Selection ---
    expect(find.text('Choose Your Adventure!'), findsOneWidget);

    // Select a Scenario (The Doorway Between Seasons)
    await tester.tap(find.text('The Doorway Between Seasons'));
    await tester.pump();

    // "Start Adventure!" should appear
    final startAdventureButton = find.text('Start Adventure!');
    await tester.ensureVisible(startAdventureButton);
    await tester.tap(startAdventureButton);
    
    // Transition
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pump(const Duration(seconds: 1));

    // --- STEP 3: Companion Selector ---
    expect(find.text('Choose a Travel Buddy'), findsOneWidget);
    
    // Skip selecting a companion and just click Go Solo
    final goSoloButton = find.text('Go Solo (Be Brave!)');
    await tester.ensureVisible(goSoloButton);
    await tester.tap(goSoloButton);
    
    // Transition
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pump(const Duration(seconds: 1));

    // --- STEP 4: Magic Review ---
    expect(find.text('Ready for Magic?'), findsOneWidget);
    
    // Verify summary
    expect(find.textContaining('Test Hero'), findsOneWidget);
    
    // Tap "Make Magic!"
    final makeMagicBtn = find.textContaining('Make Magic');
    await tester.ensureVisible(makeMagicBtn);
    await tester.tap(makeMagicBtn);
    
    // Simulate generation time
    await tester.pump(const Duration(seconds: 1)); // Start loading
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    
    // Pump until navigation happens
    await tester.pump(const Duration(seconds: 1)); 
    await tester.pump(const Duration(seconds: 1)); 
    
    // --- Verify Result Screen ---
    expect(find.text('The Magical Test Story'), findsOneWidget);
    expect(find.textContaining('Once upon a time'), findsOneWidget);
  });
}
