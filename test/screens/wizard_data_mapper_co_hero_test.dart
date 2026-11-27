// A saved hero (sibling, friend) added to another child's story must reach the
// backend with who they are, so the story gives them pronouns, interests and a
// real part. Before this they were sent as a bare name.
import 'package:flutter_test/flutter_test.dart';
import 'package:story_weaver_app/models.dart';
import 'package:story_weaver_app/screens/wizard_steps/wizard_data_mapper.dart';

WizardData _hero() {
  return WizardData()
    ..characterName = 'Maya'
    ..characterAge = 8
    ..characterGender = 'Girl';
}

void main() {
  group('WizardDataMapper.mapToStoryRequest — co-heroes', () {
    test('a saved hero with a profile is sent as a co-hero with details', () {
      final wd = _hero()
        ..companionNames = ['Leo']
        ..selectedCompanions = ['char-leo']
        ..coHeroProfiles = {
          'Leo': {
            'age': 5,
            'gender': 'Boy',
            'interests': ['trucks'],
            'strengths': ['funny'],
          },
        };

      final payload = WizardDataMapper.mapToStoryRequest(wd);
      final companions = payload['companion_characters'] as List;

      expect(companions, hasLength(1));
      expect(companions.single, {
        'name': 'Leo',
        'is_co_hero': true,
        'age': 5,
        'gender': 'Boy',
        'interests': ['trucks'],
        'strengths': ['funny'],
      });
    });

    test('a friend with no profile is still sent as a plain name', () {
      final wd = _hero()
        ..companionNames = ['Sam']
        ..selectedCompanions = ['char-sam'];

      final payload = WizardDataMapper.mapToStoryRequest(wd);

      expect(payload['companion_characters'], [
        {'name': 'Sam'},
      ]);
    });

    test('a profile left behind after the friend is removed is not sent', () {
      final wd = _hero()
        ..coHeroProfiles = {
          'Leo': {'age': 5},
        };

      final payload = WizardDataMapper.mapToStoryRequest(wd);

      expect(payload['companion_characters'], isEmpty);
    });

    test('profiles survive the wizard save and restore round trip', () {
      final wd = _hero()
        ..coHeroProfiles = {
          'Leo': {
            'age': 5,
            'interests': ['trucks'],
          },
        };

      final restored = WizardData.fromJson(wd.toJson());

      expect(restored.coHeroProfiles['Leo']?['age'], 5);
      expect(restored.coHeroProfiles['Leo']?['interests'], ['trucks']);
    });
  });
}
