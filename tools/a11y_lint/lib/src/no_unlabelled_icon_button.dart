import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/error/error.dart';
import 'package:analyzer/error/listener.dart';
import 'package:custom_lint_builder/custom_lint_builder.dart';

/// Flags an `IconButton(...)` constructor invocation that has no `tooltip:`
/// argument.
///
/// A bare [IconButton] renders only a glyph. Without a `tooltip:` the control
/// exposes no accessible name to TalkBack / VoiceOver / NVDA, so a screen
/// reader user hears nothing actionable. Supplying `tooltip:` both shows a
/// hover/long-press label AND populates the semantics label (WCAG 2.2 AA
/// SC 4.1.2 Name, Role, Value; SC 1.1.1 Non-text Content).
///
/// Reported at `warning` severity: it is a real defect, but is downgraded from
/// `error` so it never blocks `flutter analyze` while the existing backlog of
/// violations is worked through.
class NoUnlabelledIconButton extends DartLintRule {
  const NoUnlabelledIconButton() : super(code: _code);

  static const _code = LintCode(
    name: 'no_unlabelled_icon_button',
    problemMessage:
        'IconButton has no `tooltip:` — it exposes no accessible name to '
        'screen readers.',
    correctionMessage:
        'Add a `tooltip:` argument describing the action, e.g. '
        "tooltip: 'Close'.",
    errorSeverity: ErrorSeverity.WARNING,
  );

  @override
  void run(
    CustomLintResolver resolver,
    ErrorReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addInstanceCreationExpression((node) {
      // Match `IconButton(...)` and named constructors like
      // `IconButton.filled(...)` / `IconButton.outlined(...)`.
      final typeName = node.constructorName.type.name2.lexeme;
      if (typeName != 'IconButton') return;

      final hasTooltip = node.argumentList.arguments
          .whereType<NamedExpression>()
          .any((arg) => arg.name.label.name == 'tooltip');

      if (!hasTooltip) {
        reporter.reportErrorForNode(code, node.constructorName);
      }
    });
  }
}
