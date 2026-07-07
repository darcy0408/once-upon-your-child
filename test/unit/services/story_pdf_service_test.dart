import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:story_weaver_app/models.dart';
import 'package:story_weaver_app/models/local/story_local.dart';
import 'package:story_weaver_app/services/story_pdf_service.dart';

// A valid 1x1 transparent PNG, base64-encoded — small enough to embed inline
// as a fixture for the "has real art" test cases.
const _tinyPngBase64 =
    'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNk+A8AAQUBAScY42YAAAAASUVORK5CYII=';

/// Counts individual `/Type /Page` page objects in the raw PDF bytes
/// (excluding the `/Type /Pages` tree node) to assert the produced document
/// has the expected page count without needing a PDF-reading dependency.
int _countPdfPages(List<int> bytes) {
  final content = latin1.decode(bytes, allowInvalid: true);
  final matches = RegExp(r'/Type\s*/Page(?!s)').allMatches(content);
  return matches.length;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const service = StoryPdfService();

  group('StoryPdfService.buildStorybookPdf', () {
    test('builds a document from an explicit pages list without throwing',
        () async {
      final bytes = await service.buildStorybookPdf(
        title: 'The Brave Little Fox',
        storyText: 'Fallback text should not be used when pages is set.',
        pages: const [
          'Once upon a time, a little fox set out on an adventure.',
          'The fox found a river and made a new friend.',
          'They all lived happily ever after.',
        ],
        heroName: 'Ruby',
        createdAt: DateTime(2026, 1, 1),
      );

      expect(bytes, isNotEmpty);
      // Cover page + 3 story pages.
      expect(_countPdfPages(bytes), 4);
    });

    test('falls back to splitting flat storyText when pages is null',
        () async {
      final storyText = List.generate(
        40,
        (i) => 'This is sentence number $i in a long flat story.',
      ).join(' ');

      final bytes = await service.buildStorybookPdf(
        title: 'A Long Flat Story',
        storyText: storyText,
      );

      expect(bytes, isNotEmpty);
      // At least the cover plus one reflowed page.
      expect(_countPdfPages(bytes), greaterThanOrEqualTo(2));
    });

    test('produces a single-page document for an empty story', () async {
      final bytes = await service.buildStorybookPdf(
        title: '',
        storyText: '',
      );

      expect(bytes, isNotEmpty);
      // Cover page only — no pages to add when there's no text.
      expect(_countPdfPages(bytes), 1);
    });

    test('embeds valid cover and page illustrations when present', () async {
      final bytes = await service.buildStorybookPdf(
        title: 'Illustrated Story',
        storyText: 'unused',
        pages: const ['Page one text.', 'Page two text.'],
        coverImageBase64: _tinyPngBase64,
        pageIllustrationsJson: jsonEncode([_tinyPngBase64, null]),
      );

      expect(bytes, isNotEmpty);
      expect(_countPdfPages(bytes), 3);
    });

    test('skips corrupt cover/page art instead of throwing', () async {
      final bytes = await service.buildStorybookPdf(
        title: 'Corrupt Art Story',
        storyText: 'unused',
        pages: const ['Page one text.', 'Page two text.'],
        coverImageBase64: 'not-valid-base64-image-data',
        pageIllustrationsJson: jsonEncode(['also-not-valid', 12345]),
      );

      expect(bytes, isNotEmpty);
      expect(_countPdfPages(bytes), 3);
    });

    test('tolerates malformed pageIllustrationsJson without throwing',
        () async {
      final bytes = await service.buildStorybookPdf(
        title: 'Malformed JSON Story',
        storyText: 'unused',
        pages: const ['Page one text.'],
        pageIllustrationsJson: '{not valid json',
      );

      expect(bytes, isNotEmpty);
      expect(_countPdfPages(bytes), 2);
    });

    test('strips emoji and exotic glyphs instead of crashing', () async {
      final bytes = await service.buildStorybookPdf(
        title: '🦊 Foxy\'s "Big" Adventure — a tale…',
        storyText: 'unused',
        pages: const [
          'The fox said "hello!" 🎉 and felt very 😊 today — what a día!',
        ],
        heroName: '👑 Princess Zoë',
      );

      expect(bytes, isNotEmpty);
      expect(_countPdfPages(bytes), 2);
    });
  });

  group('StoryPdfService.buildFromStoryLocal', () {
    test('prefers pagesJson over storyText when both are present', () async {
      final story = StoryLocal()
        ..storyId = 'story-1'
        ..title = 'From Pages JSON'
        ..storyText = 'This flat text should be ignored in favor of pages.'
        ..theme = 'Adventure'
        ..createdAt = DateTime(2026, 2, 2)
        ..pagesJson = jsonEncode(['Page A.', 'Page B.', 'Page C.', 'Page D.'])
        ..charactersJson = jsonEncode([
          Character(id: 'c1', name: 'Milo', age: 6, role: 'Hero').toJson(),
        ]);

      final bytes = await service.buildFromStoryLocal(story);

      expect(bytes, isNotEmpty);
      // Cover page + 4 pages from pagesJson.
      expect(_countPdfPages(bytes), 5);
    });

    test('falls back to storyText split when pagesJson is absent (older save)',
        () async {
      final story = StoryLocal()
        ..storyId = 'story-2'
        ..title = 'Older Save'
        ..storyText =
            'This older story never had a pages field persisted for it.'
        ..theme = 'Adventure'
        ..createdAt = DateTime(2025, 6, 1);

      final bytes = await service.buildFromStoryLocal(story);

      expect(bytes, isNotEmpty);
      expect(_countPdfPages(bytes), greaterThanOrEqualTo(2));
    });

    test('carries persisted cover/page art from a StoryLocal fixture',
        () async {
      final story = StoryLocal()
        ..storyId = 'story-3'
        ..title = 'Illustrated Saved Story'
        ..storyText = 'unused when pagesJson is set'
        ..theme = 'Adventure'
        ..createdAt = DateTime(2026, 3, 3)
        ..pagesJson = jsonEncode(['Page one.', 'Page two.'])
        ..coverImageBase64 = _tinyPngBase64
        ..pageIllustrationsJson = jsonEncode([_tinyPngBase64, null]);

      final bytes = await service.buildFromStoryLocal(story);

      expect(bytes, isNotEmpty);
      expect(_countPdfPages(bytes), 3);
    });
  });
}
