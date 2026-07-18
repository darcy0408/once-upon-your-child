import 'package:flutter_test/flutter_test.dart';
import 'package:story_weaver_app/services/narration_chunker.dart';

/// Word list with the same semantics as the reader's tokenizer
/// (runs of non-whitespace characters).
List<String> _wordsOf(String text) =>
    text.split(RegExp(r'\s+')).where((w) => w.isNotEmpty).toList();

String _longStory({int sentences = 120}) {
  final buffer = StringBuffer();
  for (var i = 0; i < sentences; i++) {
    buffer.write('Sentence number $i tells a small piece of the tale. ');
    if (i % 6 == 5) buffer.write('\n\n');
  }
  return buffer.toString();
}

void main() {
  group('NarrationChunker.split', () {
    test('short story stays a single chunk (pre-chunking behavior)', () {
      const text = 'Once upon a moonlit night, Luna followed a shining map.';
      final chunks = NarrationChunker.split(text);
      expect(chunks, hasLength(1));
      expect(chunks.first.wordOffset, 0);
      expect(chunks.first.wordCount, _wordsOf(text).length);
      expect(chunks.first.text, text);
    });

    test('empty text yields no chunks', () {
      expect(NarrationChunker.split('   '), isEmpty);
    });

    test('long story splits with a small opening chunk', () {
      final text = _longStory();
      final chunks = NarrationChunker.split(text);
      expect(chunks.length, greaterThan(1));
      // Opening chunk is small (fast first synthesis) — target 600 chars
      // plus at most one overshooting sentence.
      expect(chunks.first.text.length, lessThan(900));
      // Later chunks are substantially larger than the opener.
      expect(
        chunks[1].text.length,
        greaterThan(chunks.first.text.length),
      );
    });

    test('word offsets and counts tile the full story exactly', () {
      final text = _longStory();
      final fullWords = _wordsOf(text);
      final chunks = NarrationChunker.split(text);

      var expectedOffset = 0;
      for (final chunk in chunks) {
        expect(chunk.wordOffset, expectedOffset);
        final chunkWords = _wordsOf(chunk.text);
        expect(chunkWords.length, chunk.wordCount);
        // The chunk's words are exactly the corresponding slice of the
        // story's words — no word is ever split across a boundary.
        expect(
          chunkWords,
          fullWords.sublist(
            chunk.wordOffset,
            chunk.wordOffset + chunk.wordCount,
          ),
        );
        expectedOffset += chunk.wordCount;
      }
      expect(expectedOffset, fullWords.length);
    });

    test('boundaries fall at sentence ends', () {
      final text = _longStory();
      final chunks = NarrationChunker.split(text);
      for (final chunk in chunks) {
        expect(
          RegExp(r'''[.!?…]["'”’)\]]*$''').hasMatch(chunk.text.trim()),
          isTrue,
          reason: 'chunk should end at a sentence boundary: '
              '"…${chunk.text.substring(chunk.text.length - 20)}"',
        );
      }
    });

    test('a run-on text with no sentence punctuation still splits', () {
      final text = List.generate(2000, (i) => 'word$i').join(' ');
      final chunks = NarrationChunker.split(text);
      expect(chunks.length, greaterThan(1));
      final fullWords = _wordsOf(text);
      final total = chunks.fold<int>(0, (sum, c) => sum + c.wordCount);
      expect(total, fullWords.length);
    });
  });
}
