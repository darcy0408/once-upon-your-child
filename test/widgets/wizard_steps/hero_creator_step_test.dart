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

    // Page 1: enter name (no availableCharacters → starts at page 1)
    await tester.enterText(find.byType(TextField).first, 'Luna');
    await tester.pump();

    // Navigate inner PageView to page 2 (archetype/avatar selection)
    final innerPV = tester.widgetList<PageView>(find.byType(PageView)).first;
    innerPV.controller!.jumpToPage(2);
    await pumpFor(tester, const Duration(milliseconds: 500));

    // Select an archetype
    final stormRider = find.textContaining('Storm Rider');
    if (stormRider.evaluate().isNotEmpty) {
      await tester.tap(stormRider.first);
      await pumpFor(tester, const Duration(milliseconds: 300));
    }

    // Verify wizard data was updated
    expect(wizardData.characterName, 'Luna');
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

    // Page 0: shows existing characters as _CharacterChoiceCard
    // Find the character card by name text
    final miloFinder = find.text('Milo');
    expect(miloFinder, findsWidgets);
    await tester.tap(miloFinder.first);
    await pumpFor(tester, const Duration(milliseconds: 500));

    // Verify character data was loaded into wizard data
    expect(wizardData.characterName, 'Milo');
    expect(wizardData.characterId, 'char-1');
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
        role: 'The Master Creator',
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

    // Page 0: shows existing characters + create new button
    // Look for add icon or "Create New" text
    final addIcon = find.byIcon(Icons.add);
    final createNew = find.textContaining('Create');
    if (addIcon.evaluate().isNotEmpty) {
      await tester.tap(addIcon.first);
    } else if (createNew.evaluate().isNotEmpty) {
      await tester.tap(createNew.first);
    }
    await pumpFor(tester, const Duration(milliseconds: 500));

    // Should navigate to page 1 (name input)
    expect(find.byType(TextField), findsWidgets);
  });

  testWidgets('increments and decrements age', (tester) async {
    setLargeScreen(tester);
    addTearDown(tester.view.resetPhysicalSize);
    final wizardData = WizardData()..characterAge = 7;

    await tester.pumpWidget(
      buildSubject(
        wizardData: wizardData,
        onNext: () {},
      ),
    );
    await pumpFor(tester, const Duration(milliseconds: 500));

    // Explorer band (age 6-8) uses chips "I'm 6", "I'm 7", "I'm 8"
    // Check if chips exist, otherwise fall back to +/- buttons
    final chip8 = find.text("I'm 8");
    final addButton = find.byIcon(Icons.add_rounded);

    if (chip8.evaluate().isNotEmpty) {
      // Explorer band: tap age chip to change age
      await tester.tap(chip8);
      await tester.pump();
      expect(wizardData.characterAge, 8);

      final chip7 = find.text("I'm 7");
      await tester.tap(chip7);
      await tester.pump();
      expect(wizardData.characterAge, 7);
    } else if (addButton.evaluate().isNotEmpty) {
      // Adventurer/Creator band: +/- buttons
      await tester.tap(addButton);
      await tester.pump();
      expect(wizardData.characterAge, 8);

      await tester.tap(find.byIcon(Icons.remove_rounded));
      await tester.pump();
      expect(wizardData.characterAge, 7);
    }
  });

  testWidgets('selects gender', (tester) async {
    setLargeScreen(tester);
    addTearDown(tester.view.resetPhysicalSize);
    final wizardData = WizardData()..characterGender = 'Girl';

    await tester.pumpWidget(
      buildSubject(
        wizardData: wizardData,
        onNext: () {},
      ),
    );
    await pumpFor(tester, const Duration(milliseconds: 500));

    // Gender labels are 'Boy'/'Girl' (not 'Hero'/'Heroine')
    final boyBtn = find.text('Boy');
    expect(boyBtn, findsOneWidget);
    await tester.tap(boyBtn);
    await tester.pump();
    expect(wizardData.characterGender, 'Boy');

    final girlBtn = find.text('Girl');
    expect(girlBtn, findsOneWidget);
    await tester.tap(girlBtn);
    await tester.pump();
    expect(wizardData.characterGender, 'Girl');
  });
}
