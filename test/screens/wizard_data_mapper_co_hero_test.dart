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

const _leoCoHero = {
  'name': 'Leo',
  'is_co_hero': true,
  'age': 5,
  'gender': 'Boy',
  'interests': ['trucks'],
  'strengths': ['funny'],
};

Map<String, dynamic> _leoProfile() => {
      'name': 'Leo',
      'age': 5,
      'gender': 'Boy',
      'interests': ['trucks'],
      'strengths': ['funny'],
    };

void main() {
  group('WizardDataMapper.mapToStoryRequest — co-heroes', () {
    test('a saved hero with a profile is sent as a co-hero with details', () {
      final wd = _hero()
        ..companionNames = ['Leo']
        ..selectedCompanions = ['char-leo']
        ..coHeroProfiles = {'char-leo': _leoProfile()};

      final payload = WizardDataMapper.mapToStoryRequest(wd);
      final companions = payload['companion_characters'] as List;

      expect(companions, hasLength(1));
      expect(companions.single, _leoCoHero);
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
      final wd = _hero()..coHeroProfiles = {'char-leo': _leoProfile()};

      final payload = WizardDataMapper.mapToStoryRequest(wd);

      expect(payload['companion_characters'], isEmpty);
    });

    test('a co-hero who shares a name with a pet is still sent as a child',
        () {
      final wd = _hero()
        ..pets = [
          {'name': 'Leo', 'type': 'Cat'},
        ]
        ..companionNames = ['Leo']
        ..selectedCompanions = ['char-leo']
        ..coHeroProfiles = {'char-leo': _leoProfile()};

      final payload = WizardDataMapper.mapToStoryRequest(wd);

      expect(payload['companion_characters'], [_leoCoHero]);
    });

    test('the profile is found by name when the id list is out of step', () {
      final wd = _hero()
        ..companionNames = ['Leo', 'Sam']
        ..selectedCompanions = ['char-leo']
        ..coHeroProfiles = {'char-leo': _leoProfile()};

      final payload = WizardDataMapper.mapToStoryRequest(wd);
      final companions = payload['companion_characters'] as List;

      expect(companions.first, _leoCoHero);
      expect(companions.last, {'name': 'Sam'});
    });

    test('profiles survive the wizard save and restore round trip', () {
      final wd = _hero()..coHeroProfiles = {'char-leo': _leoProfile()};

      final restored = WizardData.fromJson(wd.toJson());

      expect(restored.coHeroProfiles['char-leo']?['age'], 5);
      expect(restored.coHeroProfiles['char-leo']?['interests'], ['trucks']);
    });
  });
}
