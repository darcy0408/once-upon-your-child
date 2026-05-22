// Accessibility semantics test — TODO STUB (Phase 0.2).
//
// Screen under test: WizardStoryScreen (lib/screens/wizard_story_screen.dart)
// Critical-journey step: welcome -> parental consent -> [wizard story step 1]
//                        -> story reader -> story result
//
// GOAL: assert that every interactive node on wizard story step 1 (text
// inputs for superpower/quest, voice-input mic button, selection
// cards/chips, the Next/Continue button) exposes a non-empty accessible label
// and correct role — WCAG 2.2 AA SC 1.3.1, SC 3.3.2, SC 4.1.2. The mic button
// in particular must NOT be a bare icon (covered by the `no_unlabelled_icon
// _button` custom lint, asserted here at runtime).
//
// HOW TO IMPLEMENT (mirror test/a11y/app_button_semantics_test.dart):
//   1. ProviderScope-wrap and pump `WizardStoryScreen` at step 1. Reuse the
//      stubs from test/widgets/wizard_flow_test.dart (TTS / speech_to_text /
//      HTTP fakes) so no network or platform channels are hit.
//   2. final handle = tester.ensureSemantics();
//   3. await tester.pumpAndSettle();
//   4. expectAllTappablesLabelled(tester);  // from semantics_helpers.dart
//   5. Assert each text field is reachable as a labelled `textField` node:
//        tester.getSemantics(<field finder>)
//          -> containsSemantics(isTextField: true) with a non-empty label.
//   6. handle.dispose();
//
// Until implemented this file is intentionally a passing skip so
// `flutter test test/a11y/` stays green.

import 'package:flutter_test/flutter_test.dart';

// ignore: unused_import — kept so the helper is wired up when the TODO lands.
import 'semantics_helpers.dart';

void main() {
  testWidgets(
    'WizardStoryScreen step 1 — all interactive nodes carry a non-empty label',
    (tester) async {
      markTestSkipped(
        'TODO(a11y Phase 1): implement semantics assertions for '
        'WizardStoryScreen step 1 — see the implementation notes at the top '
        'of this file and the worked example in app_button_semantics_test.dart.',
      );
    },
    skip: true,
  );
}
