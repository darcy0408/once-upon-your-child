import 'package:flutter_test/flutter_test.dart';
import 'package:story_weaver_app/data/scenario_data.dart';

void main() {
  group('ScenarioCard', () {
    const testScenario = ScenarioCard(
      id: 'test',
      emoji: '🧪',
      title: 'Standard Title',
      illustration: 'illustration.png',
      description: 'Standard Description',
      conflictHook: 'Standard Hook',
      sensoryPalette: 'Standard Palette',
      youngTitle: 'Young Title',
      youngDescription: 'Young Description',
      youngConflictHook: 'Young Hook',
      matureTitle: 'Mature Title',
      matureDescription: 'Mature Description',
      matureConflictHook: 'Mature Hook',
    );

    test('returns young content for age 5', () {
      expect(testScenario.titleForAge(5), 'Young Title');
      expect(testScenario.descriptionForAge(5), 'Young Description');
      expect(testScenario.conflictHookForAge(5), 'Young Hook');
    });

    test('returns standard content for age 9', () {
      // Age 9 is the Adventurer band — above the young (≤8) threshold.
      expect(testScenario.titleForAge(9), 'Standard Title');
      expect(testScenario.descriptionForAge(9), 'Standard Description');
      expect(testScenario.conflictHookForAge(9), 'Standard Hook');
    });

    test('returns mature content for age 15', () {
      expect(testScenario.titleForAge(15), 'Mature Title');
      expect(testScenario.descriptionForAge(15), 'Mature Description');
      expect(testScenario.conflictHookForAge(15), 'Mature Hook');
    });

    test('falls back to standard if specific age content is missing', () {
      const fallbackScenario = ScenarioCard(
        id: 'fallback',
        emoji: '🎈',
        title: 'Title',
        illustration: 'illus.png',
        description: 'Desc',
        conflictHook: 'Hook',
        sensoryPalette: 'Palette',
      );

      expect(fallbackScenario.titleForAge(3), 'Title');
      expect(fallbackScenario.titleForAge(17), 'Title');
    });
  });

  group('ScenarioData', () {
    test('all scenarios have required fields', () {
      for (final scenario in ScenarioData.all) {
        expect(scenario.id, isNotEmpty);
        expect(scenario.emoji, isNotEmpty);
        expect(scenario.title, isNotEmpty);
        expect(scenario.illustration, isNotEmpty);
        expect(scenario.description, isNotEmpty);
        expect(scenario.conflictHook, isNotEmpty);
        expect(scenario.sensoryPalette, isNotEmpty);
      }
    });

    test('getById returns correct scenario', () {
      final scenario = ScenarioData.getById('doorway_seasons');
      expect(scenario, isNotNull);
      expect(scenario!.id, 'doorway_seasons');
      expect(scenario.title, 'The Doorway Between Seasons');
    });

    test('getById returns null for invalid id', () {
      expect(ScenarioData.getById('non_existent'), isNull);
    });
  });
}
