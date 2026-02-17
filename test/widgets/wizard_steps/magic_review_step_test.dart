import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:story_weaver_app/models.dart';
import 'package:story_weaver_app/screens/wizard_steps/magic_review_step.dart';
import 'package:story_weaver_app/widgets/image_make_magic_button.dart';

void main() {
  void setLargeScreen(WidgetTester tester) {
    tester.view.physicalSize = const Size(1200, 2600);
    tester.view.devicePixelRatio = 1.0;
  }

  Widget buildSubject(WizardData wizardData) {
    return MaterialApp(
      home: Scaffold(
        body: MagicReviewStep(wizardData: wizardData),
      ),
    );
  }

  testWidgets('make magic is disabled when wizard data is incomplete',
      (tester) async {
    setLargeScreen(tester);
    addTearDown(tester.view.resetPhysicalSize);
    final wizardData = WizardData();

    await tester.pumpWidget(buildSubject(wizardData));
    await tester.pump();

    final button = tester.widget<ImageMakeMagicButton>(
      find.byType(ImageMakeMagicButton),
    );
    expect(button.isEnabled, isFalse);
  });

  testWidgets('mode toggles keep rhyme and read-along mutually exclusive',
      (tester) async {
    setLargeScreen(tester);
    addTearDown(tester.view.resetPhysicalSize);
    final wizardData = WizardData()
      ..characterName = 'Nova'
      ..selectedArchetypeId = 'The Storm Rider';

    await tester.pumpWidget(buildSubject(wizardData));
    await tester.pump();

    await tester.tap(find.text('Rhyme'));
    await tester.pump();
    expect(wizardData.rhymeTimeMode, isTrue);
    expect(wizardData.learningToReadMode, isFalse);

    await tester.tap(find.text('Read-Along'));
    await tester.pump();
    expect(wizardData.learningToReadMode, isTrue);
    expect(wizardData.rhymeTimeMode, isFalse);
  });

  testWidgets('story length selector updates wizard data', (tester) async {
    setLargeScreen(tester);
    addTearDown(tester.view.resetPhysicalSize);
    final wizardData = WizardData()
      ..characterName = 'Nova'
      ..selectedArchetypeId = 'The Storm Rider';

    await tester.pumpWidget(buildSubject(wizardData));
    await tester.pump();

    await tester.ensureVisible(find.text('Epic').first);
    await tester.tap(find.text('Epic').first);
    await tester.pump();

    expect(wizardData.storyLength, 'epic');
  });

  testWidgets('custom whisper input updates custom elements', (tester) async {
    setLargeScreen(tester);
    addTearDown(tester.view.resetPhysicalSize);
    final wizardData = WizardData()
      ..characterName = 'Nova'
      ..selectedArchetypeId = 'The Storm Rider';

    await tester.pumpWidget(buildSubject(wizardData));
    await tester.pump();

    await tester.enterText(
      find.byType(TextField).first,
      'Include a rainbow castle and a puzzle.',
    );
    await tester.pump();

    expect(wizardData.customElements, 'Include a rainbow castle and a puzzle.');
  });
}
