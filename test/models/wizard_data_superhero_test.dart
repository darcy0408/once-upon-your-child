import 'package:flutter_test/flutter_test.dart';
import 'package:story_weaver_app/models/wizard_data.dart';

void main() {
  group('WizardData.isComplete identity gate', () {
    test('superhero (heroPower, no archetype) is complete with a name', () {
      // Regression: jumping to the Story-type page bypasses the archetype
      // page, so Superhero Mode lands on Magic Review with no archetype.
      // heroPower must satisfy the identity requirement or the generate
      // button stays silently greyed out.
      final d = WizardData()
        ..characterName = 'Mia'
        ..heroPower = 'super_hugs';

      expect(d.selectedArchetypeId, isNull);
      expect(d.isComplete, isTrue);
    });

    test('archetype path still completes (no superhero)', () {
      final d = WizardData()
        ..characterName = 'Mia'
        ..selectedArchetypeId = 'brave_hero';

      expect(d.isComplete, isTrue);
    });

    test('neither archetype nor heroPower is incomplete', () {
      final d = WizardData()..characterName = 'Mia';
      expect(d.isComplete, isFalse);
    });

    test('heroPower without a name is incomplete', () {
      final d = WizardData()..heroPower = 'super_hugs';
      expect(d.isComplete, isFalse);
    });

    test('blank heroPower does not satisfy the identity gate', () {
      final d = WizardData()
        ..characterName = 'Mia'
        ..heroPower = '   ';
      expect(d.isComplete, isFalse);
    });
  });

  group('WizardData superhero fields', () {
    test('toJson emits snake_case keys for backend payload', () {
      final d = WizardData()
        ..characterName = 'Mia'
        ..selectedScenario = 'superhero'
        ..heroCostumeColor = 'purple'
        ..heroCapeStyle = 'rainbow'
        ..heroEmblem = 'star'
        ..heroPower = 'super_hugs';

      final json = d.toJson();

      expect(json['hero_costume_color'], 'purple');
      expect(json['hero_cape_style'], 'rainbow');
      expect(json['hero_emblem'], 'star');
      expect(json['hero_power'], 'super_hugs');
    });

    test('fromJson restores all four superhero fields (snake_case)', () {
      final json = <String, dynamic>{
        'name': 'Mia',
        'scenario': 'superhero',
        'hero_costume_color': 'blue',
        'hero_cape_style': 'matching',
        'hero_emblem': 'lightning',
        'hero_power': 'super_speed',
      };

      final d = WizardData.fromJson(json);

      expect(d.heroCostumeColor, 'blue');
      expect(d.heroCapeStyle, 'matching');
      expect(d.heroEmblem, 'lightning');
      expect(d.heroPower, 'super_speed');
    });

    test('fromJson falls back to legacy camelCase keys', () {
      final json = <String, dynamic>{
        'name': 'Mia',
        'heroCostumeColor': 'green',
        'heroCapeStyle': 'none',
        'heroEmblem': 'paw',
        'heroPower': 'super_sharing',
      };

      final d = WizardData.fromJson(json);

      expect(d.heroCostumeColor, 'green');
      expect(d.heroCapeStyle, 'none');
      expect(d.heroEmblem, 'paw');
      expect(d.heroPower, 'super_sharing');
    });

    test('toJson then fromJson round-trips superhero fields', () {
      final original = WizardData()
        ..characterName = 'Mia'
        ..characterAge = 4
        ..selectedScenario = 'superhero'
        ..heroCostumeColor = 'red'
        ..heroCapeStyle = 'matching'
        ..heroEmblem = 'heart'
        ..heroPower = 'super_smile';

      final restored = WizardData.fromJson(original.toJson());

      expect(restored.heroCostumeColor, 'red');
      expect(restored.heroCapeStyle, 'matching');
      expect(restored.heroEmblem, 'heart');
      expect(restored.heroPower, 'super_smile');
      expect(restored.selectedScenario, 'superhero');
    });

    test('clone() preserves superhero fields', () {
      final original = WizardData()
        ..heroCostumeColor = 'yellow'
        ..heroCapeStyle = 'rainbow'
        ..heroEmblem = 'moon'
        ..heroPower = 'super_whisper';

      final copy = original.clone();

      expect(copy.heroCostumeColor, 'yellow');
      expect(copy.heroCapeStyle, 'rainbow');
      expect(copy.heroEmblem, 'moon');
      expect(copy.heroPower, 'super_whisper');

      // Mutating the clone should not affect the original.
      copy.heroPower = 'flying';
      expect(original.heroPower, 'super_whisper');
    });

    test('null superhero fields survive round-trip without crashing', () {
      final d = WizardData()..characterName = 'NotSuperhero';

      final json = d.toJson();
      expect(json['hero_costume_color'], isNull);
      expect(json['hero_cape_style'], isNull);
      expect(json['hero_emblem'], isNull);
      expect(json['hero_power'], isNull);
      expect(json['hero_catchphrase'], isNull);

      final restored = WizardData.fromJson(json);
      expect(restored.heroCostumeColor, isNull);
      expect(restored.heroCapeStyle, isNull);
      expect(restored.heroEmblem, isNull);
      expect(restored.heroPower, isNull);
      expect(restored.heroCatchphrase, isNull);
    });
  });

  group('WizardData heroCatchphrase (B3)', () {
    test('toJson emits snake_case hero_catchphrase', () {
      final d = WizardData()
        ..characterName = 'Maya'
        ..heroPower = 'strategist'
        ..heroCatchphrase = 'Never miss a beat!';

      expect(d.toJson()['hero_catchphrase'], 'Never miss a beat!');
    });

    test('fromJson restores hero_catchphrase (snake_case)', () {
      final d = WizardData.fromJson(<String, dynamic>{
        'name': 'Maya',
        'hero_power': 'strategist',
        'hero_catchphrase': 'Stay sharp!',
      });
      expect(d.heroCatchphrase, 'Stay sharp!');
    });

    test('fromJson falls back to legacy camelCase heroCatchphrase', () {
      final d = WizardData.fromJson(<String, dynamic>{
        'name': 'Maya',
        'heroCatchphrase': 'In through the nose, out through the cape!',
      });
      expect(d.heroCatchphrase, 'In through the nose, out through the cape!');
    });

    test('toJson then fromJson round-trips heroCatchphrase', () {
      final original = WizardData()
        ..characterName = 'Leo'
        ..heroPower = 'gadgeteer'
        ..heroCatchphrase = 'Time to improvise.';

      final restored = WizardData.fromJson(original.toJson());
      expect(restored.heroCatchphrase, 'Time to improvise.');
    });

    test('clone() preserves heroCatchphrase and is independent', () {
      final original = WizardData()..heroCatchphrase = 'Calm wins.';
      final copy = original.clone();

      expect(copy.heroCatchphrase, 'Calm wins.');

      copy.heroCatchphrase = 'Different line.';
      expect(original.heroCatchphrase, 'Calm wins.');
    });
  });

  group('WizardData heroNemesisId (C4)', () {
    test('toJson emits snake_case hero_nemesis_id', () {
      final d = WizardData()..heroNemesisId = 'gigawatt';
      expect(d.toJson()['hero_nemesis_id'], 'gigawatt');
    });

    test('fromJson restores hero_nemesis_id (snake_case)', () {
      final d = WizardData.fromJson({'hero_nemesis_id': 'booger_baron'});
      expect(d.heroNemesisId, 'booger_baron');
    });

    test('fromJson falls back to legacy camelCase heroNemesisId', () {
      final d = WizardData.fromJson({'heroNemesisId': 'count_copypaste'});
      expect(d.heroNemesisId, 'count_copypaste');
    });

    test('toJson then fromJson round-trips heroNemesisId', () {
      final original = WizardData()..heroNemesisId = 'the_gatekeeper';
      final restored = WizardData.fromJson(original.toJson());
      expect(restored.heroNemesisId, 'the_gatekeeper');
    });

    test('clone() preserves heroNemesisId and is independent', () {
      final original = WizardData()..heroNemesisId = 'doctor_detention';
      final copy = original.clone();
      expect(copy.heroNemesisId, 'doctor_detention');
      copy.heroNemesisId = 'mister_meh';
      expect(original.heroNemesisId, 'doctor_detention');
    });

    test('heroNemesisId defaults to null (server surprise-picks)', () {
      expect(WizardData().heroNemesisId, isNull);
      expect(WizardData().toJson()['hero_nemesis_id'], isNull);
    });
  });
}
