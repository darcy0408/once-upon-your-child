import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/error/error.dart';
import 'package:analyzer/error/listener.dart';
import 'package:custom_lint_builder/custom_lint_builder.dart';

/// Flags a call to `.repeat(...)` on what is presumed to be an
/// `AnimationController`.
///
/// `AnimationController.repeat()` starts an animation that loops forever.
/// WCAG 2.2 AA SC 2.2.2 (Pause, Stop, Hide) requires that any motion which
/// auto-starts and lasts more than 5 seconds can be paused, stopped, or
/// hidden by the user. In this app the agreed mechanism is the `MotionPrefs`
/// "reduce motion" guard: a looping controller must only call `.repeat()`
/// when motion is allowed.
///
/// ## Why this rule is `info`, not `warning`/`error`
///
/// Reliably proving — purely from a single Dart file's AST — that a given
/// `.repeat()` call IS or IS NOT wrapped in a `MotionPrefs` check is not
/// feasible:
///
///  * The guard is frequently a field/provider read several frames away
///    (e.g. set once in `initState`, or gated by a `ref.watch` in a parent).
///  * `.repeat()` is also a valid method name on `String`, `List`, `Iterable`
///    and other unrelated types, so without full type resolution every match
///    risks a false positive.
///  * The controller may be guarded indirectly (the whole animated subtree is
///    conditionally built).
///
/// Rather than emit confident-but-wrong `warning`s, this rule deliberately
/// flags EVERY `.repeat(` invocation at `info` severity. The intent is a
/// human-review checklist item, not a hard failure: a reviewer confirms each
/// looping animation is behind the `MotionPrefs` guard. This trades precision
/// for recall on purpose — a missed unguarded animation is a real WCAG
/// failure, whereas an `info` on a correctly-guarded call is cheap noise.
///
/// A lightweight heuristic still applies: if a `MotionPrefs` /
/// `reduceMotion` / `prefersReducedMotion` reference appears anywhere in the
/// enclosing method body, the call is assumed reviewed and is NOT flagged.
class NoUnguardedRepeat extends DartLintRule {
  const NoUnguardedRepeat() : super(code: _code);

  static const _code = LintCode(
    name: 'no_unguarded_repeat',
    problemMessage:
        'Looping `.repeat()` call — confirm it is behind the MotionPrefs '
        '"reduce motion" guard (WCAG 2.2 AA SC 2.2.2 Pause, Stop, Hide).',
    correctionMessage:
        'Only call `.repeat()` when motion is enabled, e.g. guard it with a '
        'MotionPrefs / reduceMotion check.',
    errorSeverity: ErrorSeverity.INFO,
  );

  /// Identifiers that, if present in the enclosing method, indicate the
  /// motion guard was at least considered — used to suppress the lint.
  static const _guardHints = {
    'MotionPrefs',
    'reduceMotion',
    'reducedMotion',
    'prefersReducedMotion',
    'disableAnimations',
  };

  @override
  void run(
    CustomLintResolver resolver,
    ErrorReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addMethodInvocation((node) {
      if (node.methodName.name != 'repeat') return;

      // `.repeat()` must be called on a target (e.g. `_controller.repeat()`).
      // A bare `repeat()` is almost never an AnimationController.
      if (node.target == null) return;

      if (_enclosingMethodMentionsGuard(node)) return;

      reporter.reportErrorForNode(code, node.methodName);
    });
  }

  /// Best-effort: true when the nearest enclosing function/method body's
  /// source text references a known motion-guard identifier.
  bool _enclosingMethodMentionsGuard(AstNode node) {
    for (AstNode? current = node.parent;
        current != null;
        current = current.parent) {
      if (current is MethodDeclaration ||
          current is FunctionDeclaration ||
          current is FunctionExpression) {
        final source = current.toSource();
        return _guardHints.any(source.contains);
      }
    }
    return false;
  }
}
