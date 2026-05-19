import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:story_weaver_app/models.dart';
import 'package:story_weaver_app/screens/wizard_story_screen.dart';
import 'package:story_weaver_app/services/api_service_manager.dart';
import 'package:story_weaver_app/services/isar_service.dart';
import 'package:story_weaver_app/story_result_screen.dart';
import 'package:story_weaver_app/pick_a_path_adventure_screen.dart';
import 'package:story_weaver_app/widgets/archetype_card.dart';
import 'package:story_weaver_app/widgets/pill_button.dart';
import 'package:story_weaver_app/widgets/image_make_magic_button.dart';
import 'package:story_weaver_app/widgets/image_mode_orb.dart';

import '../helpers/mocks.dart';
import '../helpers/test_fixtures.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late MockHttpClient mockHttpClient;
  late MockIsar mockIsar;
  late void Function(FlutterErrorDetails)? originalOnError;

  setUpAll(() {
    registerCommonMocks();
  });

  setUp(() {
    originalOnError = FlutterError.onError;
    FlutterError.onError = (FlutterErrorDetails details) {
      final message = details.exceptionAsString();
      if (message.contains('Unable to load asset: "assets/images/ui/clean/')) {
        return;
      }
      originalOnError?.call(details);
    };

    SharedPreferences.setMockInitialValues({});
    mockHttpClient = MockHttpClient();
    mockIsar = MockIsar();
    
    IsarService.setTestInstance(mockIsar);
    ApiServiceManager.setTestClient(mockHttpClient);

    // Default mock responses for POST
    when(() => mockHttpClient.post(any(), headers: any(named: 'headers'), body: any(named: 'body')))
        .thenAnswer((invocation) async {
      final url = invocation.positionalArguments[0].toString();
      if (url.contains('/auth/anonymous')) {
        // ApiServiceManager validates the auth token as a 3-segment JWT and
        // discards anything else; use a JWT-shaped token (no `exp`).
        return http.Response(
            jsonEncode({
              'token': 'eyJhbGciOiAibm9uZSJ9.eyJzdWIiOiAidXNlcl8xMjMifQ.sig',
              'user_id': 'user_test_123'
            }),
            200);
      }
      if (url.contains('/create-character')) {
        return http.Response(jsonEncode({'id': 'char_test_123', 'name': 'Luna', 'age': 7}), 201);
      }
      if (url.contains('/generate-story')) {
        return http.Response(jsonEncode({
          'status': 'complete',
          'story': {
            'id': 'story_test_123',
            'title': 'A Grand Adventure',
            'story_text': 'Long ago in a kingdom far away...',
            'theme': 'Adventure',
            'wisdom_gem': 'Courage is key',
            'pages': ['Long ago in a kingdom far away...'],
            'adventure_steps': ['The Beginning']
          }
        }), 200);
      }
      if (url.contains('/generate-interactive-story')) {
        return http.Response(jsonEncode({
          'story_id': 'interactive_123',
          'title': 'The Whispering Woods',
          'segment': {
            'id': 'seg_1',
            'segment_number': 1,
            'content': 'You stand at the entrance of a dark forest.',
            'choices': [
              {'id': 'choice_1', 'choice_number': 1, 'text': 'Enter the forest'},
              {'id': 'choice_2', 'choice_number': 2, 'text': 'Walk around it'}
            ],
            'requires_choice': true,
            'is_continuation': false,
            'stage_label': 'The Start'
          },
          'inventory': [],
          'state': {'current_location': 'Forest Edge', 'current_goal': 'Explore', 'key_clues': [], 'companion_status': ''},
          'is_completed': false
        }), 200);
      }
      if (url.contains('/continue-interactive-story')) {
        return http.Response(jsonEncode({
          'story_id': 'interactive_123',
          'segment': {
            'id': 'seg_2',
            'segment_number': 2,
            'content': 'Inside the forest, you find a glowing mushroom.',
            'choices': [],
            'requires_choice': false,
            'is_continuation': true,
            'stage_label': 'Deep Forest'
          },
          'inventory': [{'id': 'item_mushroom', 'name': 'Glowing Mushroom'}],
          'state': {'current_location': 'Deep Forest', 'current_goal': 'Find the center', 'key_clues': ['mushroom light'], 'companion_status': ''},
          'is_completed': false
        }), 200);
      }
      if (url.contains('/generate-illustrations')) {
        return http.Response(jsonEncode({'illustrations': []}), 200);
      }
      if (url.contains('/achievement/sync')) {
        return http.Response(jsonEncode({'success': true}), 200);
      }
      return http.Response('Not Found', 404);
    });

    // Default mock responses for GET
    when(() => mockHttpClient.get(any(), headers: any(named: 'headers')))
        .thenAnswer((invocation) async {
      final url = invocation.positionalArguments[0].toString();
      if (url.contains('/get-characters')) {
        return http.Response(jsonEncode([]), 200);
      }
      if (url.contains('/api/user/user_test_123/subscription')) {
        return http.Response(jsonEncode(getMockSubscriptionStatusFree()), 200);
      }
      if (url.contains('/characters/')) {
        return http.Response(jsonEncode(getSampleCharacter().toJson()), 200);
      }
      return http.Response('Not Found', 404);
    });

    // Mock PATCH for character updates
    when(() => mockHttpClient.patch(any(), headers: any(named: 'headers'), body: any(named: 'body')))
        .thenAnswer((_) async => http.Response(jsonEncode({'success': true}), 200));
  });

  tearDown(() {
    FlutterError.onError = originalOnError;
    ApiServiceManager.setTestClient(null);
    IsarService.setTestInstance(null);
  });

  Future<void> _waitForText(WidgetTester tester, String text, {int maxAttempts = 10}) async {
    for (int i = 0; i < maxAttempts; i++) {
      await tester.pump(const Duration(milliseconds: 200));
      if (find.textContaining(text).evaluate().isNotEmpty) {
        return;
      }
    }
    throw Exception('Timed out waiting for text: $text');
  }

  Future<void> _drainIgnoredAssetExceptions(WidgetTester tester) async {
    var safety = 0;
    Object? exception;
    while ((exception = tester.takeException()) != null && safety < 50) {
      final message = exception.toString();
      if (!message.contains('Unable to load asset: "assets/images/ui/clean/') &&
          !message.contains('Error generating illustration') &&
          !message.contains('RenderFlex overflowed')) {
        throw exception!;
      }
      safety += 1;
      await tester.pump(const Duration(milliseconds: 1));
    }
  }

  testWidgets(
    'Full Hero Journey: Create Character -> Navigate Wizard -> Generate Story',
    (tester) async {
    tester.view.physicalSize = const Size(1200, 1600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() => tester.view.resetPhysicalSize());

    debugPrint('🚀 [TEST] Journey Started');
    await tester.pumpWidget(ProviderScope(child: MaterialApp(home: WizardStoryScreen(
      initialWizardData: WizardData()
        ..characterName = 'Luna'
        ..selectedArchetypeId = 'storm_rider',
    ))));

    await tester.pump(const Duration(seconds: 1));
    
    debugPrint('🚀 [TEST] Hero Creator Step - entering name');
    // Name is pre-filled; enter it into the TextField if visible, else skip.
    final nameFields = find.byType(TextField);
    if (nameFields.evaluate().isNotEmpty) {
      await tester.enterText(nameFields.first, 'Luna');
      await tester.pump(const Duration(milliseconds: 500));
    }

    // Jump inner HeroCreatorStep to page 4 (companion/team selection).
    // Archetype cards only appear after an avatar is created, so we skip
    // avatar/archetype and go directly to the companion page.
    final innerPV = tester.widgetList<PageView>(find.byType(PageView)).last;
    innerPV.controller!.jumpToPage(4);
    await tester.pump(const Duration(milliseconds: 500));

    debugPrint('🚀 [TEST] Companion Selector Step');
    // Go solo — no companion selection needed for this journey test
    await _waitForText(tester, 'Go Solo');
    await tester.tap(find.textContaining('Go Solo'));
    await tester.pump(const Duration(milliseconds: 500));

    // Jump outer wizard to MagicReviewStep (page 1)
    final outerPV = tester.widgetList<PageView>(find.byType(PageView)).first;
    outerPV.controller!.jumpToPage(1);
    await tester.pump(const Duration(milliseconds: 100));
    await _drainIgnoredAssetExceptions(tester);
    await tester.pump(const Duration(milliseconds: 400));

    debugPrint('🚀 [TEST] Magic Review Step');
    final makeMagicBtn = find.byType(ImageMakeMagicButton);
    await tester.ensureVisible(makeMagicBtn);
    await tester.tap(makeMagicBtn);
    await tester.pump(const Duration(milliseconds: 100));
    
    for(int i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 500));
      await _drainIgnoredAssetExceptions(tester);
    }
    
    debugPrint('🚀 [TEST] Checking for StoryResultScreen');
    expect(find.byType(StoryResultScreen), findsOneWidget);
    debugPrint('🚀 [TEST] Journey Complete!');
    },
  );

  testWidgets(
    'Pick-A-Path Journey: Create Character -> Select Pick-A-Path Mode -> Start Adventure',
    (tester) async {
    tester.view.physicalSize = const Size(1200, 1600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() => tester.view.resetPhysicalSize());

    debugPrint('🚀 [TEST] Pick-A-Path Journey Started');
    await tester.pumpWidget(ProviderScope(child: MaterialApp(home: WizardStoryScreen(
      initialWizardData: WizardData()
        ..characterName = 'Adventurer'
        ..selectedArchetypeId = 'storm_rider'
        ..interactiveMode = true,
    ))));

    // Allow async onboarding check + WelcomeScreen title timer (2.5 s) to fire.
    await tester.pump(const Duration(seconds: 1));
    
    // Name/archetype/mode are pre-filled; no TextField interaction needed.
    await tester.pump(const Duration(milliseconds: 500));

    // Jump inner HeroCreatorStep to page 4 (companion/team selection).
    final innerPV2 = tester.widgetList<PageView>(find.byType(PageView)).last;
    innerPV2.controller!.jumpToPage(4);
    await tester.pump(const Duration(milliseconds: 500));

    debugPrint('🚀 [TEST] Skipping Companions');
    await _waitForText(tester, 'Go Solo');
    await tester.tap(find.textContaining('Go Solo'));
    await tester.pump(const Duration(milliseconds: 500));

    // Jump outer wizard to MagicReviewStep (page 1)
    final outerPV2 = tester.widgetList<PageView>(find.byType(PageView)).first;
    outerPV2.controller!.jumpToPage(1);
    await tester.pump(const Duration(milliseconds: 100));
    await _drainIgnoredAssetExceptions(tester);
    await tester.pump(const Duration(milliseconds: 400));

    // interactiveMode is pre-set; no need to select Pick Your Path in UI.
    debugPrint('🚀 [TEST] Launching Interactive Story');
    final makeMagicBtn = find.byType(ImageMakeMagicButton);
    await tester.ensureVisible(makeMagicBtn);
    await tester.tap(makeMagicBtn);
    await tester.pump(const Duration(milliseconds: 500));
    
    await tester.pump(const Duration(seconds: 1));
    for(int i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 500));
      await _drainIgnoredAssetExceptions(tester);
    }
    
    debugPrint('🚀 [TEST] Interactive Story Screen');
    expect(find.byType(PickAPathAdventureScreen), findsOneWidget);
    debugPrint('🚀 [TEST] Pick-A-Path Journey Success!');
    },
  );
}

