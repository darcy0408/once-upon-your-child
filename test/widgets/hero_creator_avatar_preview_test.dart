import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:story_weaver_app/models.dart';
import 'package:story_weaver_app/screens/wizard_steps/hero_creator_step.dart';
import 'package:story_weaver_app/widgets/character_preview.dart';

void main() {
  Future<void> pumpFor(WidgetTester tester, Duration total) async {
    // Avoid pumpAndSettle due to intentional infinite animations in wizard UI.
    var remainingMs = total.inMilliseconds;
    while (remainingMs > 0) {
      await tester.pump(const Duration(milliseconds: 100));
      remainingMs -= 100;
    }
  }

  testWidgets(
      'HeroCreatorStep loads generated avatar for saved character when avatar data stored as JSON string',
      (tester) async {
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

    final previewFinder = find.byType(CharacterPreview);
    expect(previewFinder, findsOneWidget);
    final preview = tester.widget<CharacterPreview>(previewFinder);
    expect(preview.generatedAvatar, isNotNull);
    expect(preview.generatedAvatar!.id, 'avatar_1');
  });

  testWidgets('HeroCreatorStep updates preview after tapping a saved character',
      (tester) async {
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

    // Should start in "My Heroes" mode when characters exist but no characterId.
    // Tap the character label to load it.
    await tester.tap(find.text('Milo'));
    await pumpFor(tester, const Duration(milliseconds: 500));

    final preview = tester.widget<CharacterPreview>(find.byType(CharacterPreview));
    expect(preview.generatedAvatar, isNotNull);
    expect(preview.generatedAvatar!.id, 'avatar_2');
  });
}
