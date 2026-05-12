import 'package:flutter_test/flutter_test.dart';
import 'package:story_weaver_app/models/wizard_data.dart';

void main() {
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

      final restored = WizardData.fromJson(json);
      expect(restored.heroCostumeColor, isNull);
      expect(restored.heroCapeStyle, isNull);
      expect(restored.heroEmblem, isNull);
      expect(restored.heroPower, isNull);
    });
  });
}
