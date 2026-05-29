import 'package:custom_lint_builder/custom_lint_builder.dart';

import 'src/no_unguarded_repeat.dart';
import 'src/no_unlabelled_form_field.dart';
import 'src/no_unlabelled_icon_button.dart';

/// Entrypoint for the `a11y_lint` custom_lint plugin.
///
/// `custom_lint` looks for a top-level `createPlugin` function in the file
/// named after the package (`lib/a11y_lint.dart`).
PluginBase createPlugin() => _A11yLintPlugin();

/// Registers every accessibility lint rule shipped by this package.
///
/// These rules surface WCAG 2.2 AA regressions (missing accessible names on
/// interactive controls, unguarded looping animations) directly in the IDE
/// and in `dart run custom_lint`.
class _A11yLintPlugin extends PluginBase {
  @override
  List<LintRule> getLintRules(CustomLintConfigs configs) => const [
        NoUnlabelledIconButton(),
        NoUnlabelledFormField(),
        NoUnguardedRepeat(),
      ];
}
