// Shared helpers for the accessibility (WCAG 2.2 AA) semantics tests.
//
// These are used by the working example (app_button_semantics_test.dart) and
// are intended for reuse by the per-screen golden tests as each is filled in.

import 'package:flutter/semantics.dart';
import 'package:flutter_test/flutter_test.dart';

/// Walks the live semantics tree and returns every node that advertises a tap
/// action but has an empty (or whitespace-only) accessible label.
///
/// A non-empty result is an accessibility failure: a screen-reader user would
/// land on a tappable control that announces no name (WCAG 2.2 AA SC 4.1.2
/// Name, Role, Value).
///
/// Call only after `tester.ensureSemantics()` and a `pumpWidget`.
List<SemanticsNode> findUnlabelledTappables(WidgetTester tester) {
  final root = tester.binding.pipelineOwner.semanticsOwner?.rootSemanticsNode;
  final offenders = <SemanticsNode>[];
  if (root == null) return offenders;

  void visit(SemanticsNode node) {
    final data = node.getSemanticsData();
    final isTappable = (data.actions & SemanticsAction.tap.index) != 0;
    if (isTappable && data.label.trim().isEmpty) {
      offenders.add(node);
    }
    node.visitChildren((child) {
      visit(child);
      return true;
    });
  }

  visit(root);
  return offenders;
}

/// Asserts that no tappable node in the current semantics tree is unlabelled.
///
/// Drop this into any screen test after pumping the screen:
/// ```dart
/// final handle = tester.ensureSemantics();
/// await tester.pumpWidget(...);
/// expectAllTappablesLabelled(tester);
/// handle.dispose();
/// ```
void expectAllTappablesLabelled(WidgetTester tester) {
  final offenders = findUnlabelledTappables(tester);
  expect(
    offenders,
    isEmpty,
    reason: 'Tappable semantics nodes must carry a non-empty label so '
        'screen-reader (TalkBack / VoiceOver / NVDA) users know what each '
        'control does. Unlabelled nodes: $offenders',
  );
}
