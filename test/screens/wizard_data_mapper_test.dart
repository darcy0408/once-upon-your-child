// MT-118 regression: wizard dispatch must pin theme='superhero' on the
// sturdier `heroPower` signal, not on `selectedScenario` (which the
// post-superhero scene picker can silently rewrite to a non-superhero id).
import 'package:flutter_test/flutter_test.dart';
import 'package:story_weaver_app/models.dart';
import 'package:story_weaver_app/screens/wizard_steps/wizard_data_mapper.dart';

WizardData _baseHero({int age = 7}) {
  return WizardData()
    ..characterName = 'Maya'
    ..characterAge = age
    ..characterGender = 'Girl';
}

void main() {
  group('WizardDataMapper.mapToStoryRequest — superhero dispatch (MT-118)', () {
    test(
      'heroPower set + selectedScenario overwritten by scene pick → theme=superhero',
      () {
        final wd = _baseHero()
          ..heroPower = 'feeling_sense'
          ..heroCostumeColor = 'blue'
          ..heroCapeStyle = 'matching'
          ..heroEmblem = 'bolt'
          ..selectedScenario = 'rainbow_world';

        final payload = WizardDataMapper.mapToStoryRequest(wd);

        // Mapper emits camelCase keys; ApiServiceManager converts to
        // snake_case (`hero_power`, …) when writing the wire body.
        expect(payload['theme'], equals('superhero'));
        expect(payload['heroPower'], equals('feeling_sense'));
        expect(payload['heroCostumeColor'], equals('blue'));
        expect(payload['heroCapeStyle'], equals('matching'));
        expect(payload['heroEmblem'], equals('bolt'));
      },
    );

    test('heroPower null + selectedScenario set → maps as that scenario', () {
      final wd = _baseHero()..selectedScenario = 'rainbow_world';

      final payload = WizardDataMapper.mapToStoryRequest(wd);

      expect(payload['theme'], isNot(equals('superhero')));
      expect(payload['heroPower'], isNull);
    });

    test(
      'heroPower whitespace only → falls through to scenario (no superhero gate)',
      () {
        final wd = _baseHero()
          ..heroPower = '   '
          ..selectedScenario = 'rainbow_world';

        final payload = WizardDataMapper.mapToStoryRequest(wd);

        expect(payload['theme'], isNot(equals('superhero')));
        expect(payload['heroPower'], isNull);
      },
    );

    test(
      'heroPower set → conflictHook / worldBible NOT inherited from scene pick',
      () {
        final wd = _baseHero()
          ..heroPower = 'feeling_sense'
          ..selectedScenario = 'rainbow_world';

        final payload = WizardDataMapper.mapToStoryRequest(wd);

        // The superhero prompt chain owns these — feeding it a Rainbow
        // World world bible produces the non-canonical drift MT-121 chases.
        expect(payload['conflictHook'], equals(''));
        expect(payload['worldBible'], equals(''));
      },
    );
  });

  group('WizardDataMapper.mapToStoryRequest — character_id wiring (MT-126)', () {
    test('characterId set → emitted as character_id in payload', () {
      final wd = _baseHero()
        ..characterId = '1b320068-3937-406c-88a2-684edc9a629d';

      final payload = WizardDataMapper.mapToStoryRequest(wd);

      expect(payload['character_id'],
          equals('1b320068-3937-406c-88a2-684edc9a629d'));
    });

    test('characterId null → key absent (backend treats as no recall)', () {
      final wd = _baseHero();

      final payload = WizardDataMapper.mapToStoryRequest(wd);

      expect(payload.containsKey('character_id'), isFalse);
    });

    test('characterId whitespace only → key absent', () {
      final wd = _baseHero()..characterId = '   ';

      final payload = WizardDataMapper.mapToStoryRequest(wd);

      expect(payload.containsKey('character_id'), isFalse);
    });
  });

  group('WizardDataMapper.mapToStoryRequest — gender → pronouns', () {
    Map<String, dynamic> detailsFor(String gender) {
      final wd = _baseHero()..characterGender = gender;
      final payload = WizardDataMapper.mapToStoryRequest(wd);
      return payload['characterDetails'] as Map<String, dynamic>;
    }

    test("'Girl' → she/her", () {
      expect(detailsFor('Girl')['pronouns'], equals('she/her'));
    });

    test("'Boy' → he/him", () {
      expect(detailsFor('Boy')['pronouns'], equals('he/him'));
    });
  });
}
