import 'package:flutter_test/flutter_test.dart';
import 'package:story_weaver_app/models.dart';

void main() {
  final ada = Character(
    id: 'a',
    name: 'Ada',
    age: 5,
    role: 'Brave',
    gender: 'Girl',
    pets: [
      {'name': 'Biscuit', 'species': 'Dog'}
    ],
    friends: ['Mia'],
    personalitySliders: {'energy': 90, 'confidence': 10},
  );
  final ben = Character(id: 'b', name: 'Ben', age: 9, role: 'Clever');

  test('loading a different hero leaves nothing of the previous child', () {
    final data = WizardData();
    expect(data.loadHero(ada), isTrue);
    data
      ..fears = ['the dark']
      ..strengths = ['kind']
      ..comfortItem = 'blanket'
      ..adultRelatives = [
        {'name': 'Sarah', 'relation': 'mom'}
      ]
      ..parentHiddenContext = 'trouble hearing no'
      ..parentalNote = 'new baby at home'
      ..selectedFeeling = 'sad'
      ..selectedCompanions = ['owl']
      ..companionCustomNames = {'owl': 'Hooty'}
      ..heroSuperpower = 'Kindness Magic'
      ..heroPower = 'flying'
      ..heroSecret = 'a secret'
      ..customAvatarPath = '/tmp/ada.png';

    expect(data.loadHero(ben), isTrue);

    expect(data.characterId, 'b');
    expect(data.characterName, 'Ben');
    expect(data.characterAge, 9);
    expect(data.pets, isEmpty);
    expect(data.additionalCharacters, isEmpty);
    expect(data.personalitySliders, WizardData().personalitySliders);
    expect(data.fears, isEmpty);
    expect(data.strengths, isEmpty);
    expect(data.comfortItem, isNull);
    expect(data.adultRelatives, isEmpty);
    expect(data.parentHiddenContext, isNull);
    expect(data.parentalNote, isNull);
    expect(data.selectedFeeling, isNull);
    expect(data.selectedCompanions, isEmpty);
    expect(data.companionCustomNames, isEmpty);
    expect(data.heroSuperpower, isNull);
    expect(data.heroPower, isNull);
    expect(data.heroSecret, isNull);
    expect(data.customAvatarPath, isNull);
    expect(data.generatedAvatar, isNull);
  });

  test('loading the same hero again keeps the draft', () {
    final data = WizardData()..loadHero(ada);
    data
      ..fears = ['the dark']
      ..heroSuperpower = 'Kindness Magic'
      ..selectedCompanions = ['owl'];

    expect(data.loadHero(ada), isFalse);

    expect(data.fears, ['the dark']);
    expect(data.heroSuperpower, 'Kindness Magic');
    expect(data.selectedCompanions, ['owl']);
    expect(data.pets.single['name'], 'Biscuit');
  });

  test('what the story is about survives a hero switch', () {
    final data = WizardData()
      ..lifeChallenge = 'starting school'
      ..selectedScenario = 'space'
      ..selectedGenre = 'mystery'
      ..storyLength = 'epic'
      ..rhymeTimeMode = true
      ..interactiveMode = true
      ..includeIllustrations = false
      ..customElements = 'a dragon';
    data.loadHero(ada);
    data.loadHero(ben);

    expect(data.lifeChallenge, 'starting school');
    expect(data.selectedScenario, 'space');
    expect(data.selectedGenre, 'mystery');
    expect(data.storyLength, 'epic');
    expect(data.rhymeTimeMode, isTrue);
    expect(data.interactiveMode, isTrue);
    expect(data.includeIllustrations, isFalse);
    expect(data.customElements, 'a dragon');
  });

  test('a typed-in new hero is cleared when a saved hero is picked', () {
    final data = WizardData()
      ..characterName = 'Draft'
      ..pets = [
        {'name': 'Rex', 'species': 'Dog'}
      ]
      ..heroQuest = 'Making new friends';

    expect(data.loadHero(ben), isTrue);
    expect(data.pets, isEmpty);
    expect(data.heroQuest, isNull);
  });
}
