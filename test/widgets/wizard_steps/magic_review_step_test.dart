import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:story_weaver_app/models.dart';
import 'package:story_weaver_app/screens/wizard_steps/magic_review_step.dart';
import 'package:story_weaver_app/theme/age_band_theme.dart';
import 'package:story_weaver_app/widgets/image_make_magic_button.dart';

void main() {
  void setLargeScreen(WidgetTester tester) {
    tester.view.physicalSize = const Size(1200, 2600);
    tester.view.devicePixelRatio = 1.0;
  }

  Widget buildSubject(
    WizardData wizardData, {
    void Function(int subStep)? onGoToSubStep,
    AgeBandThemeData? band,
  }) {
    return MaterialApp(
      theme: ThemeData(extensions: [band ?? explorerTheme]),
      home: Scaffold(
        body: MagicReviewStep(
          wizardData: wizardData,
          onGoToSubStep: onGoToSubStep,
        ),
      ),
    );
  }

  testWidgets('make magic is disabled when wizard data is incomplete',
      (tester) async {
    setLargeScreen(tester);
    addTearDown(tester.view.resetPhysicalSize);
    final wizardData = WizardData();

    await tester.pumpWidget(buildSubject(wizardData));
    await tester.pump(const Duration(milliseconds: 700));

    final button = tester.widget<ImageMakeMagicButton>(
      find.byType(ImageMakeMagicButton),
    );
    expect(button.isEnabled, isFalse);
  });

  testWidgets('displays rhyme mode label when rhyme mode is set',
      (tester) async {
    setLargeScreen(tester);
    addTearDown(tester.view.resetPhysicalSize);
    final wizardData = WizardData()
      ..characterName = 'Nova'
      ..selectedArchetypeId = 'The Storm Rider'
      ..rhymeTimeMode = true;

    await tester.pumpWidget(buildSubject(wizardData));
    await tester.pump(const Duration(milliseconds: 700));

    expect(find.text('Rhyme Time story'), findsOneWidget);
  });

  testWidgets('displays story length label', (tester) async {
    setLargeScreen(tester);
    addTearDown(tester.view.resetPhysicalSize);
    final wizardData = WizardData()
      ..characterName = 'Nova'
      ..selectedArchetypeId = 'The Storm Rider'
      ..storyLength = 'epic';

    await tester.pumpWidget(buildSubject(wizardData));
    await tester.pump(const Duration(milliseconds: 700));

    expect(find.text('Big adventure'), findsOneWidget);
  });

  testWidgets('displays custom elements in summary', (tester) async {
    setLargeScreen(tester);
    addTearDown(tester.view.resetPhysicalSize);
    final wizardData = WizardData()
      ..characterName = 'Nova'
      ..selectedArchetypeId = 'The Storm Rider'
      ..customElements = 'Include a rainbow castle and a puzzle.';

    await tester.pumpWidget(buildSubject(wizardData));
    await tester.pump(const Duration(milliseconds: 700));

    expect(
      find.text('"Include a rainbow castle and a puzzle."'),
      findsOneWidget,
    );
  });

  testWidgets('displays correct scenario label', (tester) async {
    setLargeScreen(tester);
    addTearDown(tester.view.resetPhysicalSize);
    final wizardData = WizardData()
      ..characterName = 'Nova'
      ..selectedArchetypeId = 'The Bold Adventurer'
      ..selectedScenario = 'doorway_seasons'
      // age 10 (Adventurer) skips sprout/young title overrides → standard title
      ..characterAge = 10;

    await tester.pumpWidget(buildSubject(wizardData));
    await tester.pump(const Duration(milliseconds: 700));

    expect(find.text('The Doorway Between Seasons'), findsWidgets);
  });

  testWidgets('sprout review tiles and pick-new button jump to substeps',
      (tester) async {
    setLargeScreen(tester);
    addTearDown(tester.view.resetPhysicalSize);
    final tappedSubSteps = <int>[];
    final wizardData = WizardData()
      ..characterName = 'Tester'
      ..selectedArchetypeId = 'The Bold Adventurer'
      ..selectedScenario = 'vanishing_colors'
      ..selectedCompanions = ['pebble']
      ..companionNames = ['Pebble']
      ..characterAge = 3;

    await tester.pumpWidget(
      buildSubject(
        wizardData,
        onGoToSubStep: tappedSubSteps.add,
        band: sproutTheme,
      ),
    );
    await tester.pump(const Duration(milliseconds: 700));

    await tester.tap(find.text('Tester').last);
    await tester.pump(const Duration(milliseconds: 50));
    await tester.tap(find.textContaining('Rainbow').first);
    await tester.pump(const Duration(milliseconds: 50));
    await tester.tap(find.text('Pebble'));
    await tester.pump(const Duration(milliseconds: 50));
    await tester.tap(find.text('Pick something new'));
    await tester.pump(const Duration(milliseconds: 50));

    expect(tappedSubSteps, [0, 2, 1, 1]);
  });
}
