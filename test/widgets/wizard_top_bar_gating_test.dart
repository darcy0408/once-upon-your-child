// First-run declutter: the Heroes / Stories / Life Quests top-bar buttons stay
// hidden until the user has a saved hero or has created a story. Bedtime and
// Parent stay.
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:story_weaver_app/models.dart';
import 'package:story_weaver_app/models/wizard_data.dart';
import 'package:story_weaver_app/screens/wizard_story_screen.dart';
import 'package:story_weaver_app/services/api_service_manager.dart';
import 'package:story_weaver_app/services/avatar_generation_state.dart';
import 'package:story_weaver_app/services/progression_service.dart';
import 'package:story_weaver_app/theme/app_theme.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  void mockBackend(List<Map<String, dynamic>> characters) {
    ApiServiceManager.setTestClient(MockClient((request) async {
      if (request.url.toString().contains('/get-characters')) {
        return http.Response(jsonEncode({'characters': characters}), 200);
      }
      return http.Response('Not Found', 404);
    }));
  }

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    AvatarGenerationState().reset();
    mockBackend(const []);
  });

  tearDown(() {
    ApiServiceManager.setTestClient(null);
    AvatarGenerationState().reset();
  });

  Future<void> pumpWizard(
    WidgetTester tester, {
    List<Character> characters = const [],
  }) async {
    tester.view.physicalSize = const Size(360, 740);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          theme: AppTheme.light(),
          home: WizardStoryScreen(
            availableCharacters: characters,
            initialWizardData: WizardData()..characterName = 'Test Hero',
            clock: () => DateTime(2026, 7, 18, 10, 0),
          ),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 800));
  }

  testWidgets('zero heroes and zero stories: only Bedtime + Parent',
      (tester) async {
    await pumpWizard(tester);
    expect(find.text('Heroes'), findsNothing);
    expect(find.text('Life Quests'), findsNothing);
    expect(find.text('Stories'), findsNothing);
    expect(find.text('My Books'), findsNothing);
    expect(find.text('Bedtime'), findsOneWidget);
    expect(find.byTooltip('Parent'), findsOneWidget);
  });

  testWidgets('one saved hero shows Heroes, Stories and Life Quests',
      (tester) async {
    mockBackend([
      {'id': 'c1', 'name': 'Milo', 'age': 7, 'role': 'The Storm Rider'},
    ]);
    await pumpWizard(
      tester,
      characters: [
        Character.fromJson(
            {'id': 'c1', 'name': 'Milo', 'age': 7, 'role': 'The Storm Rider'}),
      ],
    );
    expect(find.text('Heroes'), findsOneWidget);
    expect(find.text('Life Quests'), findsOneWidget);
    expect(find.text('Stories'), findsOneWidget);
    expect(find.text('Bedtime'), findsOneWidget);
  });

  testWidgets('a created story (no saved hero) also reveals the buttons',
      (tester) async {
    SharedPreferences.setMockInitialValues({
      'user_progress': jsonEncode(UserProgress(storiesCreated: 1).toJson()),
    });
    await pumpWizard(tester);
    expect(find.text('Heroes'), findsOneWidget);
    expect(find.text('Life Quests'), findsOneWidget);
    expect(find.text('Stories'), findsOneWidget);
  });
}
