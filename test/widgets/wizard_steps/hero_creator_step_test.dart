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

    expect(find.text('Continue'), findsOneWidget);
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

    // Existing character row shows first initial 'M' if asset fails
    // Or we can find by type and tap the first one
    final miloThumbnail = find.ancestor(
      of: find.text('M'),
      matching: find.byType(GestureDetector),
    );
    
    // Fallback if 'M' is not found immediately due to Image.asset behavior
    if (miloThumbnail.evaluate().isEmpty) {
      await tester.tap(find.byType(ClipOval).first);
    } else {
      await tester.tap(miloThumbnail.first);
    }
    
    await pumpFor(tester, const Duration(milliseconds: 300));
    await tester.ensureVisible(find.text('Continue'));
    await tester.tap(find.text('Continue'));
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

    // It should show existing characters and the "add" button icon
    expect(find.byIcon(Icons.add), findsOneWidget);
    await tester.tap(find.byIcon(Icons.add));
    await pumpFor(tester, const Duration(milliseconds: 300));

    expect(find.text("Write your hero's name"), findsOneWidget);
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
    await tester.pump();

    expect(find.text('7'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.add_rounded));
    await tester.pump();
    expect(wizardData.characterAge, 8);
    expect(find.text('8'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.remove_rounded));
    await tester.pump();
    expect(wizardData.characterAge, 7);
    expect(find.text('7'), findsOneWidget);
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
    await tester.pump();

    await tester.tap(find.text('Hero'));
    await tester.pump();
    expect(wizardData.characterGender, 'Boy');

    await tester.tap(find.text('Heroine'));
    await tester.pump();
    expect(wizardData.characterGender, 'Girl');
  });
}
