// test/services/character_appearance_converter_superhero_test.dart
//
// Sub-agent 4 — superhero costume + power-signature consistency anchor.
// Verifies that createStoryIllustrationPrompt embeds the costume color,
// cape descriptor, emblem descriptor, power signature, and the
// "IDENTICAL in every illustration" anchor when superhero mode is on,
// and that non-superhero themes do NOT regress.

import 'package:flutter_test/flutter_test.dart';
import 'package:story_weaver_app/character_appearance_converter.dart';
import 'package:story_weaver_app/models.dart';

Character _hero({int age = 4}) => Character(
      id: 'test-hero',
      name: 'Mia',
      age: age,
      role: 'superhero',
      gender: 'girl',
      hair: 'brown',
      eyes: 'brown',
      skinTone: 'medium',
      hairstyle: 'curly short',
    );

void main() {
  group('createStoryIllustrationPrompt — superhero mode', () {
    test(
        'embeds costume color, cape, emblem, power signature, '
        'and the IDENTICAL-in-every-illustration anchor', () {
      final prompt = CharacterAppearanceConverter.createStoryIllustrationPrompt(
        _hero(),
        'Mia helps her friend find a lost teddy bear in the park.',
        theme: 'superhero',
        heroCostumeColor: 'purple',
        heroCapeStyle: 'rainbow',
        heroEmblem: 'star',
        heroPower: 'super_hugs',
      );

      // Costume color descriptor present
      expect(prompt, contains('royal purple'));
      // Rainbow cape descriptor present
      expect(prompt, contains('rainbow cape'));
      // Star emblem descriptor present
      expect(prompt, contains('golden star emblem'));
      // Super-hugs power-signature visual cue present
      expect(prompt, contains('open, welcoming arms'));
      // The consistency anchor — case-sensitive — must be present
      expect(prompt, contains('IDENTICAL in every illustration'));
      // Safety guardrails present
      expect(prompt, contains('No weapons'));
      expect(prompt, contains('silly'));
    });

    test('isSuperheroMode flag wins even when theme is null', () {
      final prompt = CharacterAppearanceConverter.createStoryIllustrationPrompt(
        _hero(),
        'A scene.',
        heroCostumeColor: 'red',
        heroCapeStyle: 'matching',
        heroEmblem: 'lightning',
        heroPower: 'super_speed',
        isSuperheroMode: true,
      );

      expect(prompt, contains('bright red'));
      expect(prompt, contains('matches the suit'));
      expect(prompt, contains('lightning bolt emblem'));
      expect(prompt, contains('speed streaks'));
      expect(prompt, contains('IDENTICAL in every illustration'));
    });

    test('cape style "none" omits the cape clause but keeps costume + emblem',
        () {
      final prompt = CharacterAppearanceConverter.createStoryIllustrationPrompt(
        _hero(),
        'A scene.',
        theme: 'superhero',
        heroCostumeColor: 'green',
        heroCapeStyle: 'none',
        heroEmblem: 'paw',
        heroPower: 'super_sharing',
      );

      expect(prompt, contains('bright green'));
      expect(prompt, contains('paw-print emblem'));
      expect(prompt, contains('floating tokens'));
      // No "flowing ... cape" descriptor should appear when capeStyle == 'none'.
      // (The consistency anchor sentence still mentions the word "cape" by
      // design — that is intentional and required.)
      expect(prompt, isNot(contains('flowing')));
      expect(prompt, isNot(contains('rainbow cape')));
      // Anchor still present
      expect(prompt, contains('IDENTICAL in every illustration'));
    });

    test('falls back gracefully on unknown costume color / emblem / power', () {
      final prompt = CharacterAppearanceConverter.createStoryIllustrationPrompt(
        _hero(),
        'A scene.',
        theme: 'superhero',
        heroCostumeColor: 'chartreuse', // unknown
        heroCapeStyle: 'matching',
        heroEmblem: 'banana', // unknown
        heroPower: 'super_banana', // unknown
      );

      // Falls back to bright blue (safe default)
      expect(prompt, contains('bright blue'));
      // Anchor must still be present even with bad inputs
      expect(prompt, contains('IDENTICAL in every illustration'));
      // No crash on unknown emblem/power — they simply do not appear
      expect(prompt, isNot(contains('banana')));
    });
  });

  group('createStoryIllustrationPrompt — non-superhero modes (no regression)',
      () {
    test('default theme produces no superhero language and no anchor', () {
      final prompt = CharacterAppearanceConverter.createStoryIllustrationPrompt(
        _hero(),
        'Mia plays in the meadow.',
      );

      expect(prompt, isNot(contains('IDENTICAL in every illustration')));
      expect(prompt.toLowerCase(), isNot(contains('superhero suit')));
      expect(prompt.toLowerCase(), isNot(contains('power signature')));
      expect(prompt.toLowerCase(), isNot(contains('cape')));
    });

    test('theme="adventure" does not trigger superhero injection', () {
      final prompt = CharacterAppearanceConverter.createStoryIllustrationPrompt(
        _hero(),
        'Mia climbs a small hill.',
        theme: 'adventure',
        // Even if hero fields are passed, theme != superhero should not inject.
        heroCostumeColor: 'red',
        heroEmblem: 'star',
      );

      expect(prompt, isNot(contains('IDENTICAL in every illustration')));
      expect(prompt.toLowerCase(), isNot(contains('superhero suit')));
      expect(prompt, isNot(contains('golden star emblem')));
    });

    test('isSuperheroMode=false explicitly disables injection', () {
      final prompt = CharacterAppearanceConverter.createStoryIllustrationPrompt(
        _hero(),
        'A scene.',
        theme: 'superhero',
        heroCostumeColor: 'red',
        heroEmblem: 'star',
        isSuperheroMode: false,
      );

      expect(prompt, isNot(contains('IDENTICAL in every illustration')));
      expect(prompt, isNot(contains('golden star emblem')));
    });
  });

  group('buildSuperheroPreamble — direct unit coverage', () {
    test('handles every documented power signature without crashing', () {
      const powers = [
        'super_speed',
        'flying',
        'super_strength',
        'super_hearing',
        'super_smile',
        'super_hugs',
        'super_whisper',
        'super_sharing',
      ];
      for (final p in powers) {
        final preamble = CharacterAppearanceConverter.buildSuperheroPreamble(
          heroCostumeColor: 'blue',
          heroCapeStyle: 'matching',
          heroEmblem: 'star',
          heroPower: p,
        );
        expect(preamble, contains('IDENTICAL in every illustration'),
            reason: 'anchor missing for power=$p');
        expect(preamble, contains('deep blue'),
            reason: 'color missing for power=$p');
      }
    });

    test('emits costume sentence even when all optional fields are null', () {
      final preamble = CharacterAppearanceConverter.buildSuperheroPreamble();
      // Falls back to bright blue + no cape + no emblem + no power signature,
      // but the anchor MUST always be present.
      expect(preamble, contains('bright blue'));
      expect(preamble, contains('IDENTICAL in every illustration'));
    });

    // FIX #3 — Forbid embedded text in superhero illustrations.
    // Gemini was rendering banners like "No-Share Mia!" (mashing the
    // villain name + hero name) inside the picture. For ages 3-5 who
    // can't read, any embedded text is bad UX — and wrong text is
    // actively misleading.
    test('superhero preamble forbids embedded text', () {
      final preamble = CharacterAppearanceConverter.buildSuperheroPreamble(
        heroCostumeColor: 'blue',
        heroCapeStyle: 'matching',
        heroEmblem: 'star',
        heroPower: 'super_hugs',
      );
      // Be emphatic — assert both an "ABSOLUTELY NO TEXT" and a
      // "wordless" phrasing are present (repetition is the point).
      expect(preamble, contains('NO TEXT'));
      expect(preamble.toLowerCase(), contains('wordless'));
      expect(preamble.toLowerCase(), contains('no banners'));
    });
  });

  group('FIX #3 — no-text directive in superhero illustrations', () {
    test('superhero prompt includes no-embedded-text rule in REQUIREMENTS', () {
      final prompt = CharacterAppearanceConverter.createStoryIllustrationPrompt(
        _hero(),
        'Mia helps her friend.',
        theme: 'superhero',
        heroCostumeColor: 'blue',
        heroCapeStyle: 'matching',
        heroEmblem: 'star',
        heroPower: 'super_hugs',
      );
      // The REQUIREMENTS bullet must explicitly forbid embedded text.
      expect(
        prompt,
        contains(
            '- No embedded text, banners, signs, or readable words anywhere in the image.'),
      );
    });

    test(
        'non-superhero prompt does NOT include the no-text rule '
        '(non-superhero scenes may legitimately have signage)', () {
      final prompt = CharacterAppearanceConverter.createStoryIllustrationPrompt(
        _hero(),
        'Mia visits the fantasy market.',
        theme: 'adventure',
      );
      // Non-superhero scenes might want a shop sign, a labeled book, etc.
      // We only suppress text in the superhero branch.
      expect(
        prompt,
        isNot(contains(
            '- No embedded text, banners, signs, or readable words anywhere in the image.')),
      );
      expect(prompt.toLowerCase(), isNot(contains('wordless')));
      expect(prompt, isNot(contains('ABSOLUTELY NO TEXT')));
    });
  });
}
