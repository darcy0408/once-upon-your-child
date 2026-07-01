// Crisis-detection wiring for the "Make One Up" free-text + mic panel
// (BandAdaptiveImagineIt), committed via FeelingSelectionStep._handleContinue
// (MT-310 / MT-311, audit finding #5).
//
// Mirrors the existing distress_detector / crisis-sheet precedent: when the
// child commits a custom idea that contains clear self-harm / ideation
// language, the shared crisis-resources sheet is surfaced (non-blocking) before
// the wizard advances. Benign ideas advance straight through with no sheet.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:story_weaver_app/models.dart';
import 'package:story_weaver_app/screens/wizard_steps/feeling_selection_step.dart';
import 'package:story_weaver_app/theme/age_band_theme.dart';
import 'package:story_weaver_app/widgets/image_continue_button.dart';

WizardData _wizardData({required String customElements}) {
  return WizardData()
    ..characterName = 'Sam'
    ..characterAge = 7
    // 'safe_space' is the custom-idea scenario that renders the
    // BandAdaptiveImagineIt panel and makes the Continue button appear.
    ..selectedScenario = 'safe_space'
    ..customElements = customElements;
}

Widget _bootstrap({
  required WizardData wizardData,
  required VoidCallback onNext,
}) {
  return MaterialApp(
    theme: ThemeData(extensions: [explorerTheme]),
    home: Scaffold(
      body: FeelingSelectionStep(
        wizardData: wizardData,
        onNext: onNext,
      ),
    ),
  );
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  void setLargeScreen(WidgetTester tester) {
    tester.view.physicalSize = const Size(1200, 2800);
    tester.view.devicePixelRatio = 1.0;
  }

  testWidgets(
      'distress in the custom idea surfaces the crisis sheet on Continue',
      (tester) async {
    setLargeScreen(tester);
    addTearDown(tester.view.resetPhysicalSize);

    var nextCalled = false;
    final wd = _wizardData(customElements: 'sometimes i want to die');

    await tester.pumpWidget(
      _bootstrap(wizardData: wd, onNext: () => nextCalled = true),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    await tester.ensureVisible(find.byType(ImageContinueButton));
    await tester.pump();
    await tester.tap(find.byType(ImageContinueButton));
    // Let the modal bottom sheet route push + animate in.
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    // The shared crisis sheet is up (988 line is one of its rows).
    expect(find.text('988 Suicide & Crisis Lifeline'), findsOneWidget);
    // Non-blocking: onNext is not called while the sheet is still open.
    expect(nextCalled, isFalse);
  });

  testWidgets('benign custom idea advances with no crisis sheet',
      (tester) async {
    setLargeScreen(tester);
    addTearDown(tester.view.resetPhysicalSize);

    var nextCalled = false;
    final wd = _wizardData(customElements: 'a rainbow castle and a puzzle');

    await tester.pumpWidget(
      _bootstrap(wizardData: wd, onNext: () => nextCalled = true),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    await tester.ensureVisible(find.byType(ImageContinueButton));
    await tester.pump();
    await tester.tap(find.byType(ImageContinueButton));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.text('988 Suicide & Crisis Lifeline'), findsNothing);
    // Benign input flows straight through to the next wizard step.
    expect(nextCalled, isTrue);
  });
}
