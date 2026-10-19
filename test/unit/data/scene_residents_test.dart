// Chunk 4 — scene residents: characters who live in a scene, are introduced
// on a first visit, and greet a returning hero as an old friend.
import 'package:flutter_test/flutter_test.dart';
import 'package:story_weaver_app/data/scenario_data.dart';
import 'package:story_weaver_app/models.dart';
import 'package:story_weaver_app/screens/wizard_steps/wizard_data_mapper.dart';

// Cards with no residents by design: "Imagine It" is a different invented
// place every time, and the superhero card only routes to its own prompt.
const _noResidentIds = {'safe_space', 'superhero'};

// One representative age per band edge: Sprout, Explorer, Adventurer,
// Creator, Adolescent, Adult.
const _ages = [3, 5, 6, 8, 9, 12, 13, 14, 15, 17, 18, 40];

void main() {
  group('ScenarioCard.residentsForAge', () {
    test('every band-reachable card has at least one resident', () {
      for (final card in ScenarioData.all) {
        if (_noResidentIds.contains(card.id)) continue;
        expect(card.residents, isNotEmpty, reason: card.id);
      }
    });

    test('Imagine It and superhero have no residents', () {
      for (final id in _noResidentIds) {
        expect(ScenarioData.getById(id)!.residents, isEmpty, reason: id);
      }
    });

    test('one resident for ages 8 and under, two from 9', () {
      for (final card in ScenarioData.all) {
        if (_noResidentIds.contains(card.id)) continue;
        for (final age in _ages) {
          final expected = age <= 8 ? 1 : 2;
          expect(card.residentsForAge(age).length, expected,
              reason: '${card.id} at age $age');
        }
      }
    });

    test('never more than the card defines', () {
      const card = ScenarioCard(
        id: 't',
        emoji: 'x',
        title: 'T',
        illustration: 'i',
        description: 'd',
        conflictHook: 'c',
        sensoryPalette: 's',
        residents: [
          SceneResident(name: 'Solo', whatTheyAre: 'w', personality: 'p'),
        ],
      );
      expect(card.residentsForAge(10).length, 1);
      expect(card.residentsForAge(4).length, 1);
    });

    test('every resident has a name, what they are and a personality at '
        'every age', () {
      for (final card in ScenarioData.all) {
        for (final age in _ages) {
          for (final r in card.residentsForAge(age)) {
            final json = r.toRequestJson(age);
            expect(json.keys, containsAll(['name', 'what', 'personality']));
            for (final v in json.values) {
              expect(v.trim(), isNotEmpty, reason: '${card.id} at $age');
            }
          }
        }
      }
    });

    test('resident text never carries craft labels that could leak into prose',
        () {
      final banned = RegExp(r'\b(resident|npc|optional|cast|character)\b',
          caseSensitive: false);
      for (final card in ScenarioData.all) {
        for (final age in _ages) {
          for (final r in card.residentsForAge(age)) {
            for (final v in r.toRequestJson(age).values) {
              expect(banned.hasMatch(v), isFalse,
                  reason: '${card.id} at $age: "$v"');
            }
          }
        }
      }
    });

    test('established prose names are kept', () {
      final colors = ScenarioData.getById('vanishing_colors')!;
      expect(colors.residentsForAge(7).single.nameForAge(7),
          'the Palette Guardian');
      final dragons = ScenarioData.getById('volcano_dragons')!;
      expect(dragons.residentsForAge(7).single.nameForAge(7),
          'the Elder Dragon');
      final change = ScenarioData.getById('change_is_coming')!;
      expect(change.residentsForAge(7).single.whatTheyAreForAge(7),
          contains('cat'));
    });

    test('Sprout volcano resident is a dinosaur (tile is "Stomp with the '
        'Dinosaurs!")', () {
      final dragons = ScenarioData.getById('volcano_dragons')!;
      expect(dragons.titleForAge(4), contains('Dinosaurs'));
      final r = dragons.residentsForAge(4).single;
      expect(r.whatTheyAreForAge(4), contains('dinosaur'));
      expect(r.whatTheyAreForAge(4), isNot(contains('dragon')));
    });
  });

  group('WizardDataMapper — scene residents on the request', () {
    WizardData hero(int age, String scenario) => WizardData()
      ..characterName = 'Maya'
      ..characterAge = age
      ..characterGender = 'Girl'
      ..selectedScenario = scenario;

    test('sends scenario_id and one resident at age 7', () {
      final payload =
          WizardDataMapper.mapToStoryRequest(hero(7, 'vanishing_colors'));
      expect(payload['scenario_id'], 'vanishing_colors');
      final residents = payload['scene_residents'] as List;
      expect(residents, hasLength(1));
      expect((residents.single as Map)['name'], 'the Palette Guardian');
    });

    test('sends two residents at age 10', () {
      final payload =
          WizardDataMapper.mapToStoryRequest(hero(10, 'crystal_cavern'));
      expect(payload['scenario_id'], 'crystal_cavern');
      expect(payload['scene_residents'] as List, hasLength(2));
    });

    test('Imagine It sends neither field, so a repeat pick is never a '
        'return visit', () {
      final payload = WizardDataMapper.mapToStoryRequest(hero(7, 'safe_space'));
      expect(payload.containsKey('scenario_id'), isFalse);
      expect(payload.containsKey('scene_residents'), isFalse);
    });

    test('superhero stories send neither field', () {
      final wd = hero(7, 'vanishing_colors')
        ..heroPower = 'feeling_sense'
        ..heroCostumeColor = 'blue'
        ..heroCapeStyle = 'matching'
        ..heroEmblem = 'bolt';
      final payload = WizardDataMapper.mapToStoryRequest(wd);
      expect(payload['theme'], 'superhero');
      expect(payload.containsKey('scenario_id'), isFalse);
      expect(payload.containsKey('scene_residents'), isFalse);
    });
  });
}
