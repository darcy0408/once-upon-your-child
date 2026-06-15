import 'package:flutter_test/flutter_test.dart';
import 'package:story_weaver_app/data/parent_focus_keys.dart';
import 'package:story_weaver_app/models/story_notes.dart';
import 'package:story_weaver_app/theme/age_band_theme.dart';

void main() {
  group('toneForBand', () {
    test('young bands get the softest tones', () {
      expect(toneForBand(AgeBand.sprout), StoryNotesTone.relational);
      expect(toneForBand(AgeBand.explorer), StoryNotesTone.gentle);
    });

    test('adventurer is direct', () {
      expect(toneForBand(AgeBand.adventurer), StoryNotesTone.direct);
    });

    test('all mature bands are fully transparent', () {
      expect(toneForBand(AgeBand.creator), StoryNotesTone.transparent);
      expect(toneForBand(AgeBand.adolescent), StoryNotesTone.transparent);
      expect(toneForBand(AgeBand.adult), StoryNotesTone.transparent);
    });
  });

  group('buildStoryNotes — Sprout (relational)', () {
    test('never names the lesson, only the loving adult', () {
      final notes = buildStoryNotes(
        focusValue: 'a limit is set',
        band: AgeBand.sprout,
      );
      expect(notes.tone, StoryNotesTone.relational);
      // The skill phrase must NOT leak into a 3-5yo's disclosure.
      expect(notes.body.toLowerCase(), isNot(contains('hearing "no"')));
      expect(notes.body, contains('A grown-up who loves you'));
      expect(notes.coReadPrompt, isNull);
    });

    test('uses the caregiver name when provided', () {
      final notes = buildStoryNotes(
        focusValue: 'a limit is set',
        band: AgeBand.sprout,
        caregiverName: 'Mommy',
      );
      expect(notes.body, contains('Mommy'));
      expect(notes.body, isNot(contains('A grown-up who loves you')));
    });
  });

  group('buildStoryNotes — Explorer (gentle)', () {
    test('names the skill and weaves in the hero for co-read', () {
      final notes = buildStoryNotes(
        focusValue: 'a limit is set',
        band: AgeBand.explorer,
        heroName: 'Mia',
      );
      expect(notes.tone, StoryNotesTone.gentle);
      expect(notes.body, contains('hearing "no"'));
      expect(notes.coReadPrompt, isNotNull);
      expect(notes.coReadPrompt, contains('Mia'));
    });

    test('falls back to "your hero" when no name is given', () {
      final notes = buildStoryNotes(
        focusValue: 'a friendship bump happens',
        band: AgeBand.explorer,
      );
      expect(notes.coReadPrompt, contains('your hero'));
    });
  });

  group('buildStoryNotes — Adventurer (direct)', () {
    test('is direct but preserves agency', () {
      final notes = buildStoryNotes(
        focusValue: 'meltdown when stuck',
        band: AgeBand.adventurer,
      );
      expect(notes.tone, StoryNotesTone.direct);
      expect(notes.body, contains('pushing through frustration'));
      expect(notes.body, contains('choices were really yours'));
    });
  });

  group('buildStoryNotes — mature (transparent)', () {
    test('adolescent gets full, autonomy-respecting transparency', () {
      final notes = buildStoryNotes(
        focusValue: 'a transition happens',
        band: AgeBand.adolescent,
      );
      expect(notes.tone, StoryNotesTone.transparent);
      expect(notes.body, contains('Straight up'));
      expect(notes.body, contains('What you did with it was yours'));
    });
  });

  group('buildStoryNotes — multiple focuses', () {
    test('Explorer names two focuses joined with "and"', () {
      final notes = buildStoryNotes(
        focusValue: 'a limit is set, a sibling conflict starts',
        band: AgeBand.explorer,
      );
      // Multiples drop to the shorter phrasing, joined naturally.
      expect(notes.body, contains('hearing "no"'));
      expect(notes.body, contains('working things out with a sibling'));
      expect(notes.body, contains(' and '));
    });

    test('three focuses use comma + Oxford "and"', () {
      final notes = buildStoryNotes(
        focusValue:
            'a limit is set, a sibling conflict starts, a friendship bump happens',
        band: AgeBand.adventurer,
      );
      expect(notes.body, contains(', and '));
    });

    test('skips unknown focuses but keeps the known ones', () {
      final notes = buildStoryNotes(
        focusValue: 'a limit is set, not_a_real_focus',
        band: AgeBand.adventurer,
      );
      expect(notes.body, contains('hearing "no"'));
      expect(notes.body, isNot(contains('not_a_real_focus')));
    });
  });

  group('buildStoryNotes — unknown focus', () {
    test('degrades gracefully without crashing or leaking a raw key', () {
      final notes = buildStoryNotes(
        focusValue: 'some_unmapped_focus',
        band: AgeBand.explorer,
      );
      expect(notes.body, isNot(contains('some_unmapped_focus')));
      expect(notes.body, contains('something your grown-up wanted to help'));
    });
  });

  // Drift guard (MT-254, option B): the parent picker (_triggerData) and the
  // child disclosure (_focusCopy) both key off ParentFocusKeys. If a canonical
  // key gains a parent option but no disclosure copy, the focus silently
  // degrades to the generic fallback — exactly the values-regression we want
  // CI to catch. We verify through the public API so neither private map needs
  // exposing: every canonical key must produce a specific, named disclosure.
  group('ParentFocusKeys ↔ _focusCopy drift guard', () {
    // The generic fallbacks that stand in when a key has no copy. If any of
    // these appears for a canonical key, the disclosure has drifted.
    const fallbacks = [
      'something your grown-up wanted to help with', // gentle
      'something they wanted to help with', // direct
      'something they wanted to open up', // transparent
    ];

    test('every canonical focus key resolves to specific disclosure copy', () {
      expect(ParentFocusKeys.all, isNotEmpty);
      for (final key in ParentFocusKeys.all) {
        // Use a transparent band so the full skill phrase is surfaced.
        final notes = buildStoryNotes(
          focusValue: key,
          band: AgeBand.adolescent,
        );
        for (final fallback in fallbacks) {
          expect(
            notes.body,
            isNot(contains(fallback)),
            reason: 'Focus key "$key" is in ParentFocusKeys but has no entry '
                'in _focusCopy (story_notes.dart) — its disclosure fell back '
                'to generic copy. Add a _FocusCopy entry for it.',
          );
        }
      }
    });

    test('canonical keys are unique (no accidental duplicate)', () {
      expect(ParentFocusKeys.all.toSet().length, ParentFocusKeys.all.length);
    });
  });
}
