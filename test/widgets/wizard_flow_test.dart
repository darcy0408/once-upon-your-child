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
import 'package:story_weaver_app/widgets/make_magic_button.dart';
import 'package:story_weaver_app/widgets/image_make_magic_button.dart';
import 'package:story_weaver_app/widgets/magical_loading_view.dart';
import 'package:story_weaver_app/screens/wizard_steps/magic_review_step.dart';
import 'package:story_weaver_app/widgets/magic_orb.dart';

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

      if (url.contains('/auth/anonymous')) {
        return http.Response(jsonEncode({
          'token': 'mock_token',
          'user_id': 'mock_user_123'
        }), 200);
      }

      if (url.contains('/get-characters')) {
        return http.Response(jsonEncode({
          'characters': []
        }), 200);
      }

      if (url.contains('/generate-story')) {
        return http.Response(jsonEncode({
          'title': 'The Magical Test Story',
          'story_text': 'Once upon a time, a test hero started an adventure...',
          'wisdom_gem': 'Testing is magic!',
          'pages': [
            'Once upon a time, a test hero started an adventure...',
            'Page 2 content'
          ],
          'adventure_steps': ['Step 1', 'Step 2']
        }), 200);
      }
      
      if (url.contains('/create-character')) {
         return http.Response(jsonEncode({
          'character_id': 'char_123',
          'name': 'Test Hero'
         }), 200);
      }

      if (url.contains('/characters/')) {
        return http.Response(jsonEncode({
          'status': 'updated',
          'id': 'char_123'
        }), 200);
      }

      if (url.contains('/achievement/sync')) {
        return http.Response(jsonEncode({'status': 'success'}), 200);
      }

      if (url.contains('/quality/score-story')) {
        return http.Response(jsonEncode({
          'overall_score': 95,
          'quality_badge': 'Gold',
          'word_count': 150,
          'readability_score': 85
        }), 200);
      }

      debugPrint('⚠️ Unhandled Mock Request: $url');
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
    Future<void> pumpUntilFound(
      Finder finder, {
      Duration timeout = const Duration(seconds: 10),
      Duration step = const Duration(milliseconds: 100),
    }) async {
      final end = DateTime.now().add(timeout);
      while (DateTime.now().isBefore(end)) {
        await tester.pump(step);
        if (finder.evaluate().isNotEmpty) {
          return;
        }
      }
      fail('Timed out waiting for: $finder');
    }

    // Set a taller screen size to avoid scrolling issues
    tester.view.physicalSize = const Size(800, 2400); // Increased height
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
    final continueButton = find.byKey(const Key('wizard_continue_hero'));
    await tester.ensureVisible(continueButton);
    await tester.tap(continueButton);
     
    // Transition animation
    await tester.pump(const Duration(milliseconds: 500));
    await pumpUntilFound(find.text('Choose a Travel Buddy'));

    // --- STEP 3: Companion Selector ---
    expect(find.text('Choose a Travel Buddy'), findsOneWidget);

    final goSoloBtn = find.byKey(const Key('go_solo_button'));
    await tester.scrollUntilVisible(
      goSoloBtn,
      200.0,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pump(const Duration(milliseconds: 500));
    await tester.tap(goSoloBtn);
    await tester.pump(const Duration(milliseconds: 500));

    // Transition
    await tester.pump(const Duration(milliseconds: 500));
    await pumpUntilFound(find.byType(MagicOrbWidget));

    // --- STEP 4: Magic Review ---
    expect(find.byType(MagicOrbWidget), findsOneWidget);
    
    // Verify summary
    expect(find.textContaining('Test Hero'), findsOneWidget);

    print('🔘 Checking for MagicReviewStep...');
    expect(find.byType(MagicReviewStep), findsOneWidget);
    print('✅ MagicReviewStep found.');

    print('🔘 Searching for ImageMakeMagicButton...');
    final makeMagicBtn = find.byType(ImageMakeMagicButton);
    final buttonCount = makeMagicBtn.evaluate().length;
    print('🔘 Found $buttonCount make-magic buttons');

    if (buttonCount == 0) {
      print('⚠️ ImageMakeMagicButton not found! Dumping widget tree...');
      debugDumpApp();
      fail('ImageMakeMagicButton not found!');
    } else {
        await tester.ensureVisible(makeMagicBtn);
        await tester.tap(makeMagicBtn);
    }
    
    // Wait for generation and navigation (longer wait)
    // We use multiple pumps to handle animations and typewriter text
    bool foundStory = false;
    for(int i=0; i<30; i++) {
        await tester.pump(const Duration(seconds: 1));
        if (find.text('The Magical Test Story').evaluate().isNotEmpty &&
            find.textContaining('Once upon a time').evaluate().isNotEmpty) {
            foundStory = true;
            break;
        }
    }
    
    // --- Verify Result Screen ---
    expect(foundStory, isTrue, reason: 'Story result screen not found or content not visible');
    expect(find.text('The Magical Test Story'), findsOneWidget);
    expect(find.textContaining('Once upon a time'), findsOneWidget);
  });
}
