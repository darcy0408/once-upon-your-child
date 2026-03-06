import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mockito/mockito.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:isar/isar.dart';

import 'package:story_weaver_app/screens/wizard_story_screen.dart';
import 'package:story_weaver_app/story_result_screen.dart';
import 'package:story_weaver_app/services/api_service_manager.dart';
import 'package:story_weaver_app/services/avatar_generation_state.dart';
import 'package:story_weaver_app/theme/app_theme.dart';
import 'package:story_weaver_app/services/isar_service_io.dart';
import 'package:story_weaver_app/models/wizard_data.dart';
import 'package:story_weaver_app/widgets/image_make_magic_button.dart';
import 'package:story_weaver_app/screens/wizard_steps/magic_review_step.dart';
import 'package:story_weaver_app/widgets/magic_orb.dart';

// Mock Isar and Collection
class MockIsar extends Mock implements Isar {
  @override
  String get name => 'mock_isar';

  @override
  Future<T> writeTxn<T>(Future<T> Function() callback,
      {bool silent = false}) async {
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
  QueryBuilder<T, T, QWhere> where(
      {bool distinct = false, Sort sort = Sort.asc}) {
    throw UnimplementedError();
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
        return http.Response(
            jsonEncode({'token': 'mock_token', 'user_id': 'mock_user_123'}),
            200);
      }

      if (url.contains('/get-characters')) {
        return http.Response(jsonEncode({'characters': []}), 200);
      }

      if (url.contains('/generate-story')) {
        return http.Response(
            jsonEncode({
              'title': 'The Magical Test Story',
              'story_text':
                  'Once upon a time, a test hero started an adventure...',
              'wisdom_gem': 'Testing is magic!',
              'pages': [
                'Once upon a time, a test hero started an adventure...',
                'Page 2 content'
              ],
              'adventure_steps': ['Step 1', 'Step 2']
            }),
            200);
      }

      if (url.contains('/create-character')) {
        return http.Response(
            jsonEncode({'character_id': 'char_123', 'name': 'Test Hero'}), 200);
      }

      if (url.contains('/characters/')) {
        return http.Response(
            jsonEncode({'status': 'updated', 'id': 'char_123'}), 200);
      }

      if (url.contains('/achievement/sync')) {
        return http.Response(jsonEncode({'status': 'success'}), 200);
      }

      if (url.contains('/quality/score-story')) {
        return http.Response(
            jsonEncode({
              'overall_score': 95,
              'quality_badge': 'Gold',
              'word_count': 150,
              'readability_score': 85
            }),
            200);
      }

      debugPrint('⚠️ Unhandled Mock Request: $url');
      return http.Response('Not Found', 404);
    });

    ApiServiceManager.setTestClient(mockClient);
  });

  tearDown(() {
    ApiServiceManager.setTestClient(null);
    AvatarGenerationState().reset();
  });

  testWidgets('Full Wizard Flow Integration Test', (WidgetTester tester) async {
    Future<void> pumpUntilFound({
      required Finder finder,
      int maxPumps = 100,
      Duration step = const Duration(milliseconds: 100),
    }) async {
      for (var i = 0; i < maxPumps; i++) {
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
      ProviderScope(
        child: MaterialApp(
          theme: AppTheme.light(),
          home: WizardStoryScreen(
            availableCharacters: const [],
            initialWizardData: WizardData()
              ..characterName = 'Test Hero'
              ..selectedArchetypeId = 'storm_rider',
          ),
        ),
      ),
    );

    // Use pump(Duration) to handle infinite animations (MoonPhaseProgress)
    await tester.pump(const Duration(seconds: 1));

    // --- STEP 1: Hero Creator (multi-page internal flow) ---
    // Name/archetype are pre-filled; jump straight to companion page.
    final innerPageViews = find.byType(PageView);
    final innerPV = tester.widgetList<PageView>(innerPageViews).last;
    innerPV.controller!.jumpToPage(3);
    await tester.pump(const Duration(milliseconds: 500));

    await pumpUntilFound(finder: find.text('Go Solo — no companions'));

    // --- STEP 3: Companion Selector ---
    final goSoloBtn = find.text('Go Solo — no companions');
    await tester.ensureVisible(goSoloBtn);
    await tester.tap(goSoloBtn);

    await tester.pump(const Duration(milliseconds: 500));
    // Force transition to the outer wizard's review step (MagicReviewStep)
    final outerPV2 = tester.widgetList<PageView>(find.byType(PageView)).first;
    outerPV2.controller!.jumpToPage(1);
    await tester.pump(const Duration(milliseconds: 500));

    // --- STEP 4: Magic Review ---
    expect(find.byType(MagicOrbWidget), findsOneWidget);

    // Verify summary
    expect(find.textContaining('Test Hero'), findsOneWidget);

    expect(find.byType(MagicReviewStep), findsOneWidget);

    final makeMagicBtn = find.byType(ImageMakeMagicButton);
    expect(makeMagicBtn, findsOneWidget);
    await tester.ensureVisible(makeMagicBtn);
    await tester.tap(makeMagicBtn);

    // Wait for generation and navigation.
    await pumpUntilFound(
      finder: find.byType(StoryResultScreen),
      maxPumps: 60,
      step: const Duration(milliseconds: 500),
    );

    // --- Verify Result Screen ---
    expect(find.byType(StoryResultScreen), findsOneWidget);
    expect(find.text('The Magical Test Story'), findsOneWidget);
    expect(find.textContaining('Testing is magic!'), findsOneWidget);
  });
}
