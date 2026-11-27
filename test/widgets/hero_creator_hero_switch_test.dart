import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:story_weaver_app/models.dart';
import 'package:story_weaver_app/screens/wizard_steps/hero_creator_step.dart';
import 'package:story_weaver_app/services/avatar_generation_state.dart';

void main() {
  // 1x1 transparent PNG so Image.memory decoding won't throw.
  const pngBase64 =
      'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAwMCAO+X2ioAAAAASUVORK5CYII=';
  GeneratedAvatar avatar(String id) => GeneratedAvatar.fromJson({
        'id': id,
        'image_base64': 'data:image/png;base64,$pngBase64',
        'seed': id,
        'style': 'cartoon',
        'attributes': <String, dynamic>{},
        'generated_at': DateTime.now().toIso8601String(),
      });

  Future<void> pumpFor(WidgetTester tester, Duration total) async {
    // No pumpAndSettle: the wizard has intentional endless animations.
    var remainingMs = total.inMilliseconds;
    while (remainingMs > 0) {
      await tester.pump(const Duration(milliseconds: 100));
      remainingMs -= 100;
    }
  }

  final ada = Character(
    id: 'a',
    name: 'Ada',
    age: 7,
    role: 'Brave',
    gender: 'Girl',
    pets: [
      {'name': 'Biscuit', 'species': 'Dog'}
    ],
    friends: ['Mia'],
    personalitySliders: {'energy': 90},
  );
  final ben = Character(id: 'b', name: 'Ben', age: 7, role: 'Clever');

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    AvatarGenerationState().reset();
  });

  testWidgets('tapping a sibling\'s hero starts clean, and an avatar that '
      'finishes late is not given to the sibling', (tester) async {
    tester.view.physicalSize = const Size(1200, 2600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    final data = WizardData()..characterId = 'a';
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: HeroCreatorStep(
            wizardData: data,
            onNext: () {},
            availableCharacters: [ada, ben],
          ),
        ),
      ),
    );
    await pumpFor(tester, const Duration(seconds: 1));

    expect(data.characterId, 'a');
    expect(data.pets.single['name'], 'Biscuit');
    data.fears = ['the dark'];

    // Ada's avatar is still being drawn when Ben is tapped.
    AvatarGenerationState().startGeneration();
    await tester.tap(find.text('Ben').first);
    await pumpFor(tester, const Duration(seconds: 1));

    expect(data.characterId, 'b');
    expect(data.pets, isEmpty);
    expect(data.additionalCharacters, isEmpty);
    expect(data.fears, isEmpty);
    expect(data.personalitySliders['energy'], 50);

    // Ada's avatar arrives now. Ben must not get it.
    AvatarGenerationState().completeGeneration(avatar('for-ada'));
    await pumpFor(tester, const Duration(milliseconds: 300));
    expect(data.generatedAvatar, isNull);

    // An avatar started for Ben is accepted as usual.
    AvatarGenerationState().startGeneration();
    AvatarGenerationState().completeGeneration(avatar('for-ben'));
    await pumpFor(tester, const Duration(seconds: 4));
    expect(data.generatedAvatar?.id, 'for-ben');
  });
}
