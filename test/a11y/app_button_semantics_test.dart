// Accessibility semantics test — WORKING EXAMPLE (Phase 0.2).
//
// This is the reference pattern for the a11y semantics golden tests. It picks
// the simplest reachable interactive widget in the app — [AppButton] — and
// asserts that the interactive node it produces carries a non-empty
// accessible *label*, the thing a screen reader (TalkBack / VoiceOver / NVDA)
// actually announces.
//
// `AppButton` wraps its underlying Material button in a `Tooltip`. In the
// semantics tree this produces TWO related nodes: the tappable button node
// (whose `label` is the button's visible text), and a separate node carrying
// the Tooltip `message` in its `tooltip` field (announced on hover/long
// press). The accessible *name* of the control is therefore the button
// label, which must be non-empty.
//
// The assertion shape every other screen test should use:
//   1. enable semantics for the test (`tester.ensureSemantics()`),
//   2. pump the widget,
//   3. read the interactive node with `tester.getSemantics(finder)`,
//   4. assert via the public `containsSemantics` / `matchesSemantics` matcher
//      that it has the tap action AND a non-empty label.
//
// It uses ONLY the public `flutter_test` API (`getSemantics`,
// `containsSemantics`) — `SemanticsTester` / `includesNodeWith` are internal
// to the Flutter SDK's own test suite and are not exported.
//
// Run all a11y tests with:
//   flutter test test/a11y/
//
// The four TODO stub files alongside this one (parental_consent, wizard_story,
// story_reader, story_result) follow the SAME structure — replace their
// `markTestSkipped` body with a real pump + assertion as each screen is made
// testable.

import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:story_weaver_app/widgets/app_button.dart';

void main() {
  group('AppButton accessibility semantics', () {
    testWidgets(
        'primary button exposes a non-empty accessible label to screen readers',
        (tester) async {
      // Enable the semantics layer for the duration of the test — this is the
      // tree the platform a11y bridge (TalkBack / VoiceOver / NVDA) consumes.
      final semanticsHandle = tester.ensureSemantics();

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: Center(
              child: AppButton.primary(
                label: 'Start',
                semanticLabel: 'Start a new story',
                onPressed: _noop,
              ),
            ),
          ),
        ),
      );

      // The button must be reachable by a screen reader as a labelled,
      // tappable node — WCAG 2.2 AA SC 4.1.2 (Name, Role, Value).
      //
      // Target the tappable button node by its accessible label ('Start',
      // the visible button text). `find.byType(ElevatedButton)` reliably
      // resolves to the render object that owns the interactive semantics.
      final node = tester.getSemantics(find.byType(ElevatedButton));
      expect(
        node,
        containsSemantics(
          label: 'Start',
          hasTapAction: true,
          isButton: true,
        ),
      );
      // Core a11y requirement: the interactive node has a non-empty label.
      expect(node.label.trim(), isNotEmpty);

      // The descriptive tooltip is exposed too (announced on hover / long
      // press). `find.byTooltip` matches the Tooltip `message`, which AppButton
      // populates from `semanticLabel`.
      expect(
        find.byTooltip('Start a new story'),
        findsOneWidget,
        reason: 'AppButton.semanticLabel should surface as a Tooltip so the '
            'control has a descriptive accessible annotation.',
      );

      semanticsHandle.dispose();
    });

    testWidgets('every tappable node in the subtree carries a non-empty label',
        (tester) async {
      final semanticsHandle = tester.ensureSemantics();

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: Center(
              child: AppButton.primary(
                label: 'Continue',
                semanticLabel: 'Continue to the next step',
                onPressed: _noop,
              ),
            ),
          ),
        ),
      );

      // Generic guard reusable on any screen: walk the semantics tree and
      // assert that no node advertising a tap action does so without a label.
      final root =
          tester.binding.pipelineOwner.semanticsOwner!.rootSemanticsNode!;
      final unlabelledTappables = <SemanticsNode>[];

      void visit(SemanticsNode node) {
        final data = node.getSemanticsData();
        final isTappable =
            (data.actions & SemanticsAction.tap.index) != 0;
        if (isTappable && data.label.trim().isEmpty) {
          unlabelledTappables.add(node);
        }
        node.visitChildren((child) {
          visit(child);
          return true;
        });
      }

      visit(root);

      expect(
        unlabelledTappables,
        isEmpty,
        reason: 'Tappable semantics nodes must have a non-empty label so '
            'screen-reader users know what the control does.',
      );

      semanticsHandle.dispose();
    });
  });
}

/// A const, no-op callback so the example widgets can be `const`.
void _noop() {}
