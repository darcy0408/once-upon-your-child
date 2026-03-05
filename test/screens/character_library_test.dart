import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:story_weaver_app/screens/character_editor_screen.dart';
import 'package:story_weaver_app/screens/character_library_screen.dart';
import 'package:story_weaver_app/screens/wizard_story_screen.dart';
import 'package:story_weaver_app/services/api_service_manager.dart';

void main() {
  late List<Map<String, dynamic>> characters;

  void setLargeScreen(WidgetTester tester) {
    tester.view.physicalSize = const Size(1200, 2200);
    tester.view.devicePixelRatio = 1.0;
  }

  Future<void> pumpFor(WidgetTester tester, Duration total) async {
    var remainingMs = total.inMilliseconds;
    while (remainingMs > 0) {
      await tester.pump(const Duration(milliseconds: 100));
      remainingMs -= 100;
    }
  }

  MockClient buildClient() {
    return MockClient((request) async {
      final path = request.url.path;
      if (path.endsWith('/auth/anonymous')) {
        return http.Response(
          jsonEncode({'token': 'test-token', 'user_id': 'user-123'}),
          200,
        );
      }

      if (path.endsWith('/get-characters')) {
        return http.Response(jsonEncode({'characters': characters}), 200);
      }

      if (request.method == 'DELETE' && path.contains('/characters/')) {
        final id = path.split('/').last;
        characters.removeWhere((c) => c['id'].toString() == id);
        return http.Response(jsonEncode({'success': true}), 200);
      }

      return http.Response('Not found', 404);
    });
  }

  Future<void> pumpScreen(WidgetTester tester) async {
    await tester.pumpWidget(
      const MaterialApp(home: CharacterLibraryScreen()),
    );
    await pumpFor(tester, const Duration(seconds: 1));
  }

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    characters = [];
    ApiServiceManager.setTestClient(buildClient());
  });

  tearDown(() {
    ApiServiceManager.setTestClient(null);
  });

  testWidgets('character list display', (tester) async {
    setLargeScreen(tester);
    addTearDown(tester.view.resetPhysicalSize);
    characters = [
      {
        'id': 'c1',
        'name': 'Luna',
        'age': 8,
        'role': 'The Storm Rider',
      }
    ];

    await pumpScreen(tester);

    expect(find.text('Luna'), findsOneWidget);
    expect(find.text('Story'), findsOneWidget);
    expect(find.byTooltip('Edit'), findsOneWidget);
  });

  testWidgets('character creation path opens wizard', (tester) async {
    setLargeScreen(tester);
    addTearDown(tester.view.resetPhysicalSize);
    await pumpScreen(tester);

    await tester.tap(find.text('Create Character'));
    await pumpFor(tester, const Duration(seconds: 1));

    expect(find.byType(WizardStoryScreen), findsOneWidget);
  });

  testWidgets('character editing opens editor screen', (tester) async {
    setLargeScreen(tester);
    addTearDown(tester.view.resetPhysicalSize);
    characters = [
      {
        'id': 'c1',
        'name': 'Kai',
        'age': 9,
        'role': 'Adventurer',
      }
    ];
    await pumpScreen(tester);

    await tester.ensureVisible(find.byTooltip('Edit'));
    await tester.tap(find.byTooltip('Edit'));
    await pumpFor(tester, const Duration(milliseconds: 800));

    expect(find.byType(CharacterEditorScreen), findsOneWidget);
    expect(find.text('Edit Character'), findsOneWidget);
  });

  testWidgets('character deletion removes item after confirmation',
      (tester) async {
    setLargeScreen(tester);
    addTearDown(tester.view.resetPhysicalSize);
    characters = [
      {
        'id': 'c1',
        'name': 'Milo',
        'age': 7,
        'role': 'The Storm Rider',
      }
    ];

    await pumpScreen(tester);

    await tester.ensureVisible(find.byTooltip('Delete'));
    await tester.tap(find.byTooltip('Delete'));
    await pumpFor(tester, const Duration(milliseconds: 800));
    await tester.tap(find.text('Delete'));
    await pumpFor(tester, const Duration(seconds: 1));

    expect(find.text('Milo deleted'), findsOneWidget);
    expect(find.text('No Characters Yet'), findsOneWidget);
  });

  testWidgets('empty state handling', (tester) async {
    setLargeScreen(tester);
    addTearDown(tester.view.resetPhysicalSize);
    await pumpScreen(tester);

    expect(find.text('No Characters Yet'), findsOneWidget);
    expect(find.text('Create your first character to get started!'),
        findsOneWidget);
    expect(find.text('Create Character'), findsOneWidget);
  });

  testWidgets('shows backend online status', (tester) async {
    setLargeScreen(tester);
    addTearDown(tester.view.resetPhysicalSize);

    await pumpScreen(tester);

    // In tests, global http.get fails by default, showing "Story service is waking up"
    expect(find.text('Story service is waking up'), findsOneWidget);
  });
}
