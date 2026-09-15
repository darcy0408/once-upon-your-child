import 'package:flutter_test/flutter_test.dart';
import 'package:story_weaver_app/models.dart';
import 'package:story_weaver_app/screens/bedtime_wizard_screen.dart';
import 'package:story_weaver_app/screens/wizard_steps/wizard_data_mapper.dart';

/// MT-434(c): what a bedtime companion pick turns into on the wire.
///
/// Before: the mapper matched "Moon Owl" to the catalogue owl and then sent
/// the catalogue's own name ("a wise owl"), so the child heard a companion
/// they had not named; picks with no catalogue match went out as a bare
/// name with no description or power.
void main() {
  /// Mirrors what _generateAndReadStory does with the pick.
  Map<String, dynamic> requestFor(String companionName) {
    final d = WizardData()
      ..characterName = 'Tessa'
      ..characterAge = 7
      ..companionNames = [companionName]
      ..customElements = 'funny story about Rainbow World'
      ..storyLength = 'standard';
    final id = bedtimeCompanionCatalogueId(companionName);
    if (id != null) {
      d.selectedCompanions = [id];
      d.companionCustomNames[id] = companionName;
    }
    return WizardDataMapper.mapToStoryRequest(d);
  }

  group('bedtimeCompanionCatalogueId', () {
    test('maps the chip names that have a catalogue creature', () {
      expect(bedtimeCompanionCatalogueId('Fluffy Dragon'), 'dragon');
      expect(bedtimeCompanionCatalogueId('Moon Owl'), 'owl');
      expect(bedtimeCompanionCatalogueId('Star Fox'), 'fox');
      expect(bedtimeCompanionCatalogueId('Shining Puppy'), 'dog');
      expect(bedtimeCompanionCatalogueId('Robin'), 'robin');
    });

    test('is null for picks with no catalogue creature', () {
      expect(bedtimeCompanionCatalogueId('Magic Bunny'), isNull);
      expect(bedtimeCompanionCatalogueId('Thunder Wolf'), isNull);
      expect(bedtimeCompanionCatalogueId('Crystal Phoenix'), isNull);
    });
  });

  group('story request', () {
    test('a catalogue pick keeps its chosen name and gains the details', () {
      final req = requestFor('Moon Owl');
      final chars = req['companion_characters'] as List;
      expect(chars, hasLength(1));
      final owl = chars.single as Map;
      expect(owl['name'], 'Moon Owl',
          reason: 'the story must use the name the child chose');
      expect(owl['signaturePower'], isNotEmpty);
      expect(owl['description'], isNotEmpty);
    });

    test('the Explorer default (Star Fox) is as rich as any chosen pick', () {
      final req = requestFor('Star Fox');
      final fox = (req['companion_characters'] as List).single as Map;
      expect(fox['name'], 'Star Fox');
      expect(fox['signaturePower'], isNotEmpty);
    });

    test('a pick with no catalogue creature still goes out by name', () {
      final req = requestFor('Thunder Wolf');
      final wolf = (req['companion_characters'] as List).single as Map;
      expect(wolf['name'], 'Thunder Wolf');
    });
  });
}
