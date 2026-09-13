import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Every release build a workflow produces must be compiled with
/// `--dart-define=FLAVOR=production`.
///
/// Without it, `FlavorConfig` falls back to the development flavor, whose
/// backend is `http://127.0.0.1:5000`. On a real phone that address is the
/// phone itself, so every server call fails — and nothing on screen says so,
/// because the DEV banner is never rendered. TestFlight build 1.0.0 (2) shipped
/// exactly that way: testers could not get past the parental-consent email
/// step, which is simply the first screen that cannot continue without the
/// server.
///
/// Lives under test/unit/ because that is a directory CI actually runs.
void main() {
  final workflows = Directory('.github/workflows')
      .listSync()
      .whereType<File>()
      .where((f) => f.path.endsWith('.yml') || f.path.endsWith('.yaml'))
      .toList();

  test('finds the workflow files, so the checks below cannot pass vacuously',
      () {
    expect(workflows, isNotEmpty);
  });

  test('sees the TestFlight upload build as a release build', () {
    final commands = _releaseBuildCommands(
      File('.github/workflows/ios-testflight.yml').readAsStringSync(),
    );
    expect(commands, hasLength(1));
  });

  test('parses a multi-line command and ignores YAML comments', () {
    const yaml = '''
      # flutter build ipa --release  (a comment, not a command)
      run: |
        flutter build ipa \\
          --release \\
          --dart-define=FLAVOR=production
''';
    final commands = _releaseBuildCommands(yaml);
    expect(commands, hasLength(1));
    expect(commands.single, contains('--dart-define=FLAVOR=production'));
  });

  for (final file in workflows) {
    final name = file.uri.pathSegments.last;
    test('every --release flutter build in $name targets production', () {
      for (final command in _releaseBuildCommands(file.readAsStringSync())) {
        expect(
          command,
          contains('--dart-define=FLAVOR=production'),
          reason: 'A release build without FLAVOR=production talks to '
              'http://127.0.0.1:5000 on the device. Offending command in '
              '$name: $command',
        );
      }
    });
  }
}

/// The `flutter build ... --release` commands in [yaml], with shell line
/// continuations joined so a multi-line command reads as one string.
List<String> _releaseBuildCommands(String yaml) {
  final withoutComments = yaml
      .split(RegExp(r'\r?\n'))
      .where((line) => !line.trimLeft().startsWith('#'))
      .join('\n');
  final joined = withoutComments.replaceAll(RegExp(r'\\\n\s*'), ' ');
  return RegExp(r'flutter build [^\n]*')
      .allMatches(joined)
      .map((m) => m.group(0)!)
      .where((command) => command.contains('--release'))
      .toList();
}
