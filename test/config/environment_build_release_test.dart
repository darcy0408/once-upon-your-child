import 'package:flutter_test/flutter_test.dart';
import 'package:story_weaver_app/config/environment.dart';

/// The build stamp exists so a device can name the build it is running without
/// a cable, a console, or a Sentry event: iOS Safari is not inspectable from
/// Windows, and Sentry reporting is consent-gated and off by default. If the
/// label is wrong, the one available answer to "which build is this?" is wrong.
void main() {
  group('Environment.shortenRelease', () {
    test('an unstamped build reads as local rather than blank', () {
      // A local `flutter build` supplies no --dart-define, so the constant is
      // empty. Rendering an empty stamp would look like a missing widget.
      expect(Environment.shortenRelease(''), 'local');
    });

    test('a full commit SHA is truncated to the first 7 characters', () {
      expect(
        Environment.shortenRelease('abc1234deadbeef567890'),
        'abc1234',
      );
    });

    test('a SHA of exactly 7 characters is left intact', () {
      expect(Environment.shortenRelease('abc1234'), 'abc1234');
    });

    test('a value shorter than 7 characters does not throw', () {
      // substring(0, 7) on a shorter string is a RangeError. This guards the
      // boundary rather than the happy path.
      expect(Environment.shortenRelease('abc'), 'abc');
    });
  });

  group('Environment.buildRelease', () {
    test('is empty under test, so buildLabel falls back to local', () {
      // Pins the contract the getter depends on: no --dart-define reaches
      // `flutter test`, so the constant must stay empty here.
      expect(Environment.buildRelease, isEmpty);
      expect(Environment.buildLabel, 'local');
    });
  });
}
