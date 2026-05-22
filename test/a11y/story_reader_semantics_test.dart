// Accessibility semantics test — TODO STUB (Phase 0.2).
//
// Screen under test: StoryReaderScreen (lib/story_reader_screen.dart)
// Critical-journey step: welcome -> parental consent -> wizard story step 1
//                        -> [story reader] -> story result
//
// GOAL: assert that every interactive node in the story reader (play/pause
// TTS button, previous/next page IconButtons, the page-flip controls, any
// close/back affordance) exposes a non-empty accessible label and correct
// role — WCAG 2.2 AA SC 1.1.1, SC 2.2.2, SC 4.1.2.
//
// NOTE: StoryReaderScreen drives several looping animations via
// `AnimationController.repeat()` (flagged by the `no_unguarded_repeat` custom
// lint). A future a11y test here should also assert those respect the
// MotionPrefs "reduce motion" guard — but that is motion behaviour, not pure
// semantics, so it may live in a separate test.
//
// HOW TO IMPLEMENT (mirror test/a11y/app_button_semantics_test.dart):
//   1. ProviderScope-wrap and pump `StoryReaderScreen` with a sample story
//      (reuse the fixtures/fakes from test/screens/story_reader_test.dart,
//      including the no-op TTS service so playback never hits the network).
//   2. final handle = tester.ensureSemantics();
//   3. await tester.pumpAndSettle();
//   4. expectAllTappablesLabelled(tester);  // from semantics_helpers.dart
//   5. Assert the page-navigation IconButtons specifically expose a label
//      (e.g. 'Next page' / 'Previous page').
//   6. handle.dispose();
//
// Until implemented this file is intentionally a passing skip so
// `flutter test test/a11y/` stays green.

import 'package:flutter_test/flutter_test.dart';

// ignore: unused_import — kept so the helper is wired up when the TODO lands.
import 'semantics_helpers.dart';

void main() {
  testWidgets(
    'StoryReaderScreen — all interactive nodes carry a non-empty label',
    (tester) async {
      markTestSkipped(
        'TODO(a11y Phase 1): implement semantics assertions for '
        'StoryReaderScreen — see the implementation notes at the top of this '
        'file and the worked example in app_button_semantics_test.dart.',
      );
    },
    skip: true,
  );
}
