// Limerick Mode: an explicit, named Explorer-band story type that rides the
// Learning-to-Read pipeline and adds a `limerickMode` flag the backend uses
// to force the AABBA limerick builder regardless of the age default.
import 'package:flutter_test/flutter_test.dart';
import 'package:story_weaver_app/models/wizard_data.dart';
import 'package:story_weaver_app/screens/wizard_steps/wizard_data_mapper.dart';

void main() {
  group('WizardData.limerickMode', () {
    test('defaults off', () {
      expect(WizardData().limerickMode, isFalse);
    });

    test('survives toJson → fromJson', () {
      final d = WizardData()
        ..characterName = 'Max'
        ..characterAge = 8
        ..learningToReadMode = true
        ..limerickMode = true;

      final restored = WizardData.fromJson(d.toJson());

      expect(restored.limerickMode, isTrue);
      expect(restored.learningToReadMode, isTrue);
    });

    test('fromJson tolerates a payload saved before the flag existed', () {
      final json = WizardData().toJson()..remove('limerickMode');
      expect(WizardData.fromJson(json).limerickMode, isFalse);
    });

    test('clone() carries the flag', () {
      final d = WizardData()..limerickMode = true;
      expect(d.clone().limerickMode, isTrue);
    });
  });

  group('WizardDataMapper.mapToStoryRequest — limerickMode', () {
    test('emits limerickMode alongside learningToReadMode', () {
      final wd = WizardData()
        ..characterName = 'Max'
        ..characterAge = 8
        ..characterGender = 'Boy'
        ..learningToReadMode = true
        ..limerickMode = true;

      final payload = WizardDataMapper.mapToStoryRequest(wd);

      expect(payload['learningToReadMode'], isTrue);
      expect(payload['limerickMode'], isTrue);
    });

    test('plain Easy Reader does not set limerickMode', () {
      final wd = WizardData()
        ..characterName = 'Max'
        ..characterAge = 8
        ..characterGender = 'Boy'
        ..learningToReadMode = true;

      final payload = WizardDataMapper.mapToStoryRequest(wd);

      expect(payload['learningToReadMode'], isTrue);
      expect(payload['limerickMode'], isFalse);
    });
  });
}
