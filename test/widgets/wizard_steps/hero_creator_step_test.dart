import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:story_weaver_app/models.dart';
import 'package:story_weaver_app/screens/wizard_steps/hero_creator_step.dart';

void main() {
  void setLargeScreen(WidgetTester tester) {
    tester.view.physicalSize = const Size(1200, 2600);
    tester.view.devicePixelRatio = 1.0;
  }

  Future<void> pumpFor(WidgetTester tester, Duration total) async {
    var remainingMs = total.inMilliseconds;
    while (remainingMs > 0) {
      await tester.pump(const Duration(milliseconds: 100));
      remainingMs -= 100;
    }
  }

  Widget buildSubject({
    required WizardData wizardData,
    required VoidCallback onNext,
    List<Character> availableCharacters = const [],
  }) {
    return MaterialApp(
      home: Scaffold(
        body: HeroCreatorStep(
          wizardData: wizardData,
          onNext: onNext,
          availableCharacters: availableCharacters,
        ),
      ),
    );
  }

  testWidgets('shows continue after entering name and selecting archetype',
      (tester) async {
    setLargeScreen(tester);
    addTearDown(tester.view.resetPhysicalSize);
    final wizardData = WizardData();

    await tester.pumpWidget(
      buildSubject(
        wizardData: wizardData,
        onNext: () {},
      ),
    );
    await pumpFor(tester, const Duration(milliseconds: 500));

    await tester.enterText(find.byType(TextField).first, 'Luna');
    await tester.pump();
    await tester.tap(find.text('The Storm Rider'));
    await pumpFor(tester, const Duration(milliseconds: 300));

    expect(find.byKey(const Key('wizard_continue_hero')), findsOneWidget);
  });

  testWidgets('loads existing character and continues', (tester) async {
    setLargeScreen(tester);
    addTearDown(tester.view.resetPhysicalSize);
    final wizardData = WizardData();
    var didContinue = false;
    final characters = [
      Character(
        id: 'char-1',
        name: 'Milo',
        age: 7,
        role: 'The Storm Rider',
      ),
    ];

    await tester.pumpWidget(
      buildSubject(
        wizardData: wizardData,
        onNext: () => didContinue = true,
        availableCharacters: characters,
      ),
    );
    await pumpFor(tester, const Duration(seconds: 1));

    await tester.tap(find.text('Milo'));
    await pumpFor(tester, const Duration(milliseconds: 300));
    await tester.ensureVisible(find.byKey(const Key('wizard_continue_hero')));
    await tester.tap(find.byKey(const Key('wizard_continue_hero')));
    await pumpFor(tester, const Duration(milliseconds: 500));

    expect(didContinue, isTrue);
    expect(wizardData.characterId, 'char-1');
    expect(wizardData.characterName, 'Milo');
  });

  testWidgets('switches from existing hero selection to create new',
      (tester) async {
    setLargeScreen(tester);
    addTearDown(tester.view.resetPhysicalSize);
    final wizardData = WizardData();
    final characters = [
      Character(
        id: 'char-1',
        name: 'Nova',
        age: 8,
        role: 'The Dream Weaver',
      ),
    ];

    await tester.pumpWidget(
      buildSubject(
        wizardData: wizardData,
        onNext: () {},
        availableCharacters: characters,
      ),
    );
    await pumpFor(tester, const Duration(milliseconds: 500));

    expect(find.text('Select Your Hero'), findsOneWidget);
    await tester.tap(find.text('Create New'));
    await pumpFor(tester, const Duration(milliseconds: 300));

    expect(find.text('Create a Character'), findsOneWidget);
    expect(find.text('Hero Name'), findsOneWidget);
  });
}
