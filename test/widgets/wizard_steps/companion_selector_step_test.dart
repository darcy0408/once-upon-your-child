import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:story_weaver_app/models.dart';
import 'package:story_weaver_app/screens/wizard_steps/companion_selector_step.dart';

void main() {
  void setLargeScreen(WidgetTester tester) {
    tester.view.physicalSize = const Size(1200, 2600);
    tester.view.devicePixelRatio = 1.0;
  }

  Widget buildSubject({
    required WizardData wizardData,
    required VoidCallback onNext,
    List<Character> savedCharacters = const [],
  }) {
    return MaterialApp(
      home: Scaffold(
        body: CompanionSelectorStep(
          wizardData: wizardData,
          onNext: onNext,
          savedCharacters: savedCharacters,
        ),
      ),
    );
  }

  testWidgets('shows go solo button and continues without selections',
      (tester) async {
    setLargeScreen(tester);
    addTearDown(tester.view.resetPhysicalSize);
    final wizardData = WizardData()..characterName = 'Hero';
    var didContinue = false;

    await tester.pumpWidget(
      buildSubject(
        wizardData: wizardData,
        onNext: () => didContinue = true,
      ),
    );
    await tester.pump();

    final goSolo = find.text('Go Solo (Be Brave!)');
    expect(goSolo, findsOneWidget);
    await tester.ensureVisible(goSolo);
    await tester.tap(goSolo);
    await tester.pump();

    expect(didContinue, isTrue);
  });

  testWidgets('selecting a magical companion updates wizard data',
      (tester) async {
    setLargeScreen(tester);
    addTearDown(tester.view.resetPhysicalSize);
    final wizardData = WizardData()..characterName = 'Hero';

    await tester.pumpWidget(
      buildSubject(
        wizardData: wizardData,
        onNext: () {},
      ),
    );
    await tester.pump();

    await tester.tap(find.text('a tiny dragon'));
    await tester.pump();

    expect(find.text('Gather Party!'), findsOneWidget);
    expect(wizardData.selectedCompanions, contains('dragon'));
    expect(wizardData.companionNames, contains('a tiny dragon'));
  });

  testWidgets('shows saved friends section excluding main hero',
      (tester) async {
    setLargeScreen(tester);
    addTearDown(tester.view.resetPhysicalSize);
    final wizardData = WizardData()..characterName = 'Luna';
    final savedCharacters = [
      Character(id: '1', name: 'Luna', age: 8, role: 'Hero'),
      Character.fromJson({
        'id': '2',
        'name': 'Kai',
        'age': 9,
        'role': 'The Storm Rider',
        'generated_avatar': {
          'id': 'avatar-kai',
          'image_base64':
              'data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAwMCAO+X2ioAAAAASUVORK5CYII=',
          'seed': 'seed-kai',
          'style': 'cartoon',
          'attributes': {'hair': 'brown'},
          'generated_at': '2026-02-16T00:00:00Z',
        },
      }),
    ];

    await tester.pumpWidget(
      buildSubject(
        wizardData: wizardData,
        onNext: () {},
        savedCharacters: savedCharacters,
      ),
    );
    await tester.pump();

    expect(find.text('Your Friends'), findsOneWidget);
    expect(find.text('Kai'), findsOneWidget);
    expect(find.text('Luna'), findsNothing);
  });

  testWidgets('selecting multiple companions updates wizard data',
      (tester) async {
    setLargeScreen(tester);
    addTearDown(tester.view.resetPhysicalSize);
    final wizardData = WizardData()..characterName = 'Hero';

    await tester.pumpWidget(
      buildSubject(
        wizardData: wizardData,
        onNext: () {},
      ),
    );
    await tester.pump();

    await tester.tap(find.text('a tiny dragon'));
    await tester.pump();
    await tester.tap(find.text('a wise owl'));
    await tester.pump();

    expect(wizardData.selectedCompanions, contains('dragon'));
    expect(wizardData.selectedCompanions, contains('owl'));
    expect(wizardData.companionNames, contains('a tiny dragon'));
    expect(wizardData.companionNames, contains('a wise owl'));
  });

  testWidgets('shows custom pets from wizard data', (tester) async {
    setLargeScreen(tester);
    addTearDown(tester.view.resetPhysicalSize);
    final wizardData = WizardData()
      ..characterName = 'Hero'
      ..pets = [
        {'name': 'Sparky', 'species': 'Dog', 'personality': 'Playful'}
      ];

    await tester.pumpWidget(
      buildSubject(
        wizardData: wizardData,
        onNext: () {},
      ),
    );
    await tester.pump();

    expect(find.text('Sparky'), findsOneWidget);
    expect(find.text('Your faithful Dog companion'), findsOneWidget);

    await tester.tap(find.text('Sparky'));
    await tester.pump();

    expect(wizardData.selectedCompanions, contains('Sparky'));
    expect(wizardData.companionNames, contains('Sparky'));
  });
}
