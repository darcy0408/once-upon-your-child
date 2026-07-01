// Crisis-detection wiring for the story-generation submit path
// (MagicReviewStep._launchStoryCreation) — MT-310 / MT-311, audit finding #5.
//
// _launchStoryCreation is the single choke point every "Make Magic" submit
// funnels through, so the child's committed custom premise (customElements) is
// scanned there for clear self-harm / ideation language. On a positive signal
// the shared crisis-resources sheet is surfaced (non-blocking, mounted-guarded)
// before generation proceeds — mirroring the ImagineItScreen._save() /
// CreativeBrief "Create Story" precedent.
//
// The distress case is asserted end-to-end here: tapping Make Magic with a
// distress premise awaits the modal crisis sheet BEFORE any story-generation
// (provider / network / timer) work runs, so the assertion is deterministic.
// The benign / no-false-positive direction is covered by the shared detector's
// own tests (test/utils/distress_detector_test.dart) and the benign
// FeelingSelectionStep case — a full benign tap here would drive into live
// story generation (subscription providers + Celery request) which isn't
// unit-testable without heavy mocking.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:story_weaver_app/models.dart';
import 'package:story_weaver_app/screens/wizard_steps/magic_review_step.dart';
import 'package:story_weaver_app/theme/age_band_theme.dart';
import 'package:story_weaver_app/widgets/image_make_magic_button.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  void setLargeScreen(WidgetTester tester) {
    tester.view.physicalSize = const Size(1200, 2600);
    tester.view.devicePixelRatio = 1.0;
  }

  Widget buildSubject(WizardData wizardData) {
    return MaterialApp(
      theme: ThemeData(extensions: [explorerTheme]),
      home: Scaffold(
        body: MagicReviewStep(wizardData: wizardData),
      ),
    );
  }

  testWidgets(
      'distress in the custom premise surfaces the crisis sheet on Make Magic',
      (tester) async {
    setLargeScreen(tester);
    addTearDown(tester.view.resetPhysicalSize);

    // Name + archetype make wizardData.isComplete true → Make Magic is enabled.
    final wizardData = WizardData()
      ..characterName = 'Nova'
      ..selectedArchetypeId = 'The Storm Rider'
      ..customElements = 'i dont want to be alive anymore';

    await tester.pumpWidget(buildSubject(wizardData));
    await tester.pump(const Duration(milliseconds: 700));

    final button = tester.widget<ImageMakeMagicButton>(
      find.byType(ImageMakeMagicButton),
    );
    expect(button.isEnabled, isTrue);

    await tester.ensureVisible(find.byType(ImageMakeMagicButton));
    await tester.pump();
    await tester.tap(find.byType(ImageMakeMagicButton));
    // Let the modal crisis sheet route push + animate in. Generation is
    // suspended on the awaited sheet, so no providers/timers run.
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.text('988 Suicide & Crisis Lifeline'), findsOneWidget);
  });
}
