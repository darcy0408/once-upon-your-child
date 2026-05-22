// Accessibility semantics test — TODO STUB (Phase 0.2).
//
// Screen under test: ParentalConsentScreen (lib/screens/parental_consent_screen.dart)
// Critical-journey step: welcome -> [parental consent] -> wizard story step 1
//                        -> story reader -> story result
//
// GOAL: assert that every interactive node on the parental-consent screen
// (the math gate inputs, the consent checkbox(es), the "I agree" / submit
// button, and any policy links) exposes a non-empty accessible label and the
// correct role — WCAG 2.2 AA SC 1.3.1, SC 3.3.2, SC 4.1.2.
//
// HOW TO IMPLEMENT (mirror test/a11y/app_button_semantics_test.dart):
//   1. ProviderScope-wrap and pump `ParentalConsentScreen` with a fake
//      `ParentalConsentService` (see test/screens/welcome_screen_age_gate_test.dart
//      for the existing fakes/HTTP-stub pattern) and `declaredAge: 6`.
//   2. final handle = tester.ensureSemantics();
//   3. await tester.pumpAndSettle();
//   4. expectAllTappablesLabelled(tester);  // from semantics_helpers.dart
//   5. Additionally assert the submit control:
//        tester.getSemantics(find.byType(ElevatedButton))
//          -> containsSemantics(hasTapAction: true, isButton: true)
//        and that its label is non-empty.
//   6. handle.dispose();
//
// Until implemented this file is intentionally a passing skip so
// `flutter test test/a11y/` stays green.

import 'package:flutter_test/flutter_test.dart';

// ignore: unused_import — kept so the helper is wired up when the TODO lands.
import 'semantics_helpers.dart';

void main() {
  testWidgets(
    'ParentalConsentScreen — all interactive nodes carry a non-empty label',
    (tester) async {
      markTestSkipped(
        'TODO(a11y Phase 1): implement semantics assertions for '
        'ParentalConsentScreen — see the implementation notes at the top of '
        'this file and the worked example in app_button_semantics_test.dart.',
      );
    },
    skip: true,
  );
}
