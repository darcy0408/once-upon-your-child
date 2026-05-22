import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/error/error.dart';
import 'package:analyzer/error/listener.dart';
import 'package:custom_lint_builder/custom_lint_builder.dart';

/// Flags a `TextField` / `TextFormField` that has no accessible name.
///
/// A text input is considered labelled when EITHER:
///  * its `decoration:` argument is an `InputDecoration(...)` carrying a
///    `labelText:` (and/or `hintText:`) argument, OR
///  * it is wrapped — anywhere up its ancestor chain — in a `Semantics(...)`
///    that supplies a `label:` (or `textField: true` plus a `label:`).
///
/// An unlabelled input fails WCAG 2.2 AA SC 1.3.1 (Info and Relationships),
/// SC 3.3.2 (Labels or Instructions) and SC 4.1.2 (Name, Role, Value): a
/// screen reader announces "edit box" with no indication of what to type.
///
/// Reported at `warning` severity (see [NoUnlabelledIconButton] for rationale).
///
/// Detection is best-effort and AST-local:
///  * `decoration:` is matched structurally — it must be an
///    `InputDecoration(...)` literal with a `labelText:` argument. A
///    `decoration:` built by a helper function is NOT introspected, so such
///    fields may produce a false positive. Wrap them in `Semantics(label:)`
///    or inline the `InputDecoration` to silence the rule.
///  * The `Semantics` ancestor check walks parent AST nodes; it will not
///    follow a `Semantics` injected by a separate build method.
class NoUnlabelledFormField extends DartLintRule {
  const NoUnlabelledFormField() : super(code: _code);

  static const _code = LintCode(
    name: 'no_unlabelled_form_field',
    problemMessage:
        'TextField/TextFormField has no accessible name — no `labelText` in '
        'its decoration and no enclosing `Semantics(label:)`.',
    correctionMessage:
        'Add `decoration: InputDecoration(labelText: ...)` or wrap the field '
        'in `Semantics(label: ..., textField: true, child: ...)`.',
    errorSeverity: ErrorSeverity.WARNING,
  );

  static const _fieldTypeNames = {'TextField', 'TextFormField'};

  @override
  void run(
    CustomLintResolver resolver,
    ErrorReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addInstanceCreationExpression((node) {
      final typeName = node.constructorName.type.name2.lexeme;
      if (!_fieldTypeNames.contains(typeName)) return;

      if (_hasLabelledDecoration(node) || _hasSemanticsAncestorLabel(node)) {
        return;
      }

      reporter.reportErrorForNode(code, node.constructorName);
    });
  }

  /// True when the field has `decoration: InputDecoration(... labelText: ...)`.
  bool _hasLabelledDecoration(InstanceCreationExpression field) {
    final decoration = field.argumentList.arguments
        .whereType<NamedExpression>()
        .where((arg) => arg.name.label.name == 'decoration')
        .map((arg) => arg.expression)
        .firstOrNull;
    if (decoration is! InstanceCreationExpression) return false;

    final decorationType = decoration.constructorName.type.name2.lexeme;
    if (decorationType != 'InputDecoration') return false;

    return decoration.argumentList.arguments
        .whereType<NamedExpression>()
        .any((arg) => arg.name.label.name == 'labelText');
  }

  /// True when any ancestor `Semantics(...)` literal supplies a `label:`.
  bool _hasSemanticsAncestorLabel(AstNode node) {
    for (AstNode? current = node.parent;
        current != null;
        current = current.parent) {
      if (current is! InstanceCreationExpression) continue;
      if (current.constructorName.type.name2.lexeme != 'Semantics') continue;

      final hasLabel = current.argumentList.arguments
          .whereType<NamedExpression>()
          .any((arg) => arg.name.label.name == 'label');
      if (hasLabel) return true;
    }
    return false;
  }
}
