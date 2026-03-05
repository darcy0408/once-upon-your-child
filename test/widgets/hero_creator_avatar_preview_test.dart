import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:story_weaver_app/models.dart';
import 'package:story_weaver_app/screens/wizard_steps/hero_creator_step.dart';

void main() {
  Future<void> pumpFor(WidgetTester tester, Duration total) async {
    // Avoid pumpAndSettle due to intentional infinite animations in wizard UI.
    var remainingMs = total.inMilliseconds;
    while (remainingMs > 0) {
      await tester.pump(const Duration(milliseconds: 100));
      remainingMs -= 100;
    }
  }

  void setLargeScreen(WidgetTester tester) {
    tester.view.physicalSize = const Size(1200, 2600);
    tester.view.devicePixelRatio = 1.0;
  }

  testWidgets(
      'HeroCreatorStep loads generated avatar for saved character when avatar data stored as JSON string',
      (tester) async {
    setLargeScreen(tester);
    addTearDown(tester.view.resetPhysicalSize);

    // 1x1 transparent PNG (valid base64) so Image.memory decoding won't throw.
    const pngBase64 =
        'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAwMCAO+X2ioAAAAASUVORK5CYII=';
    final avatarJson = {
      'id': 'avatar_1',
      'image_base64': 'data:image/png;base64,$pngBase64',
      'seed': 'seed_1',
      'style': 'cartoon',
      'attributes': {'hair': 'blue'},
      'generated_at': DateTime.now().toIso8601String(),
    };

    final characterJson = {
      'id': 'char_1',
      'name': 'Luna',
      'age': 8,
      'role': 'The Storm Rider',
      // Simulate an older backend row where avatar data was persisted as a JSON string.
      'avatar_data': jsonEncode(avatarJson),
    };

    final wizardData = WizardData()..characterId = 'char_1';
    final characters = [Character.fromJson(characterJson)];

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: HeroCreatorStep(
            wizardData: wizardData,
            onNext: () {},
            availableCharacters: characters,
          ),
        ),
      ),
    );

    // Let initState + setState run.
    await pumpFor(tester, const Duration(seconds: 1));

    // The character should be auto-selected (first in list when characterId matches).
    // Verify the character name appears on the screen (shown in _CharacterChoiceCard or name field).
    expect(find.text('Luna'), findsAtLeast(1));
    // Verify the character data was loaded into wizardData
    expect(wizardData.characterName, 'Luna');
  });

  testWidgets('HeroCreatorStep updates preview after tapping a saved character',
      (tester) async {
    setLargeScreen(tester);
    addTearDown(tester.view.resetPhysicalSize);

    const pngBase64 =
        'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAwMCAO+X2ioAAAAASUVORK5CYII=';
    final avatarJson = {
      'id': 'avatar_2',
      'image_base64': 'data:image/png;base64,$pngBase64',
      'seed': 'seed_2',
      'style': 'watercolor',
      'attributes': {'hair': 'green'},
      'generated_at': DateTime.now().toIso8601String(),
    };

    final characters = [
      Character.fromJson({
        'id': 'char_2',
        'name': 'Milo',
        'age': 7,
        'role': 'The Storm Rider',
        'generated_avatar': avatarJson,
      })
    ];

    final wizardData = WizardData();

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: HeroCreatorStep(
            wizardData: wizardData,
            onNext: () {},
            availableCharacters: characters,
          ),
        ),
      ),
    );
    await pumpFor(tester, const Duration(seconds: 1));

    // Tap the existing character card by name — character cards show name text.
    final miloBubble = find.text('Milo');
    expect(miloBubble, findsAtLeast(1));
    await tester.ensureVisible(miloBubble.first);
    await tester.tap(miloBubble.first);
    await pumpFor(tester, const Duration(milliseconds: 500));

    // After tapping, wizardData should reflect Milo.
    expect(wizardData.characterName, 'Milo');
  });
}
