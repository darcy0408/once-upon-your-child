// Pins matureSceneArtBackedIds against the files actually on disk.
//
// This exists because of a real miss: the eight creator scene tiles were
// generated and committed in #39, but the gate listing which ids have art was
// left untouched, so creator kept drawing accent-gradient placeholders over
// artwork that was already shipping in the bundle. Nothing failed — the
// fallback is deliberate (MT-269), so the only symptom was the owner opening
// the app and seeing empty tiles where "the door you're afraid to open" and
// "the storm runner citadel" should have been.
//
// Both directions matter:
//   id listed but file missing -> broken tile at runtime
//   file present but id unlisted -> gradient placeholder over unused art
//
// imagine_it ships art in every band folder but is not part of the scenario
// accordion (it is the separate ImagineItHeroCard), so it is excluded here
// rather than added to the set.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:story_weaver_app/screens/wizard_steps/hero_creator_creative_brief.dart';

const _matureBands = ['creator', 'adolescent', 'adult'];
const _notInAccordion = {'imagine_it'};

Set<String> _sceneIdsOnDisk(String band) {
  final dir = Directory('assets/images/scenarios/$band');
  if (!dir.existsSync()) return {};
  return dir
      .listSync()
      .whereType<File>()
      .map((f) => f.uri.pathSegments.last)
      .where((n) => n.endsWith('.webp'))
      .map((n) => n.substring(0, n.length - '.webp'.length))
      .toSet()
      .difference(_notInAccordion);
}

void main() {
  group('mature scene art coverage', () {
    for (final band in _matureBands) {
      test('$band has a file for every art-backed id', () {
        final onDisk = _sceneIdsOnDisk(band);
        expect(onDisk, isNotEmpty,
            reason: 'no scene art found for $band — wrong working directory?');
        final missingFiles = matureSceneArtBackedIds.difference(onDisk);
        expect(missingFiles, isEmpty,
            reason: 'listed as art-backed but no file in '
                'assets/images/scenarios/$band/: $missingFiles');
      });

      test('$band has no art the gate never asks for', () {
        final unused = _sceneIdsOnDisk(band).difference(matureSceneArtBackedIds);
        expect(unused, isEmpty,
            reason: 'art exists for $unused in $band but they are absent from '
                'matureSceneArtBackedIds, so they render as gradient '
                'placeholders — add them to the set');
      });
    }

    test('all three mature bands ship the same scene set', () {
      final sets = {for (final b in _matureBands) b: _sceneIdsOnDisk(b)};
      final creator = sets['creator']!;
      for (final b in _matureBands.skip(1)) {
        expect(sets[b], creator,
            reason: 'band art sets diverged: $b differs from creator');
      }
    });
  });
}
