// lib/services/narration_chunker.dart
//
// Splits a story's text into narration chunks so the reader can synthesize
// and start playing the OPENING of a story immediately while the rest is
// prefetched in the background (mirrors the per-page illustration
// prefetcher's "stay ahead of the reader" approach, applied to audio).
//
// Chunk boundaries fall only at sentence ends or newlines, never inside a
// word, so per-chunk word counts line up exactly with the reader's
// whitespace-run tokenizer and read-along highlighting stays correct across
// chunk transitions. The first chunk is deliberately small (a few seconds of
// synthesis) so time-to-first-audio is short; later chunks are larger so a
// full story stays a handful of requests.

/// One narration chunk: the text to synthesize plus its word position within
/// the full story (used to offset per-chunk word timestamps back onto the
/// reader's global token list).
class NarrationChunk {
  /// The chunk's text (edge-trimmed; interior whitespace preserved).
  final String text;

  /// Number of story words (non-whitespace runs) before this chunk.
  final int wordOffset;

  /// Number of story words in this chunk.
  final int wordCount;

  const NarrationChunk({
    required this.text,
    required this.wordOffset,
    required this.wordCount,
  });
}

class NarrationChunker {
  NarrationChunker._();

  /// Target size of the opening chunk — small enough that synthesis returns
  /// in a couple of seconds, large enough (~1.5 paragraphs) that the
  /// background prefetch comfortably stays ahead of playback.
  static const int firstChunkTargetChars = 600;

  /// Target size of every later chunk. Larger chunks keep a full story to a
  /// handful of requests (each request passes the server's quota gate).
  static const int laterChunkTargetChars = 2800;

  /// A story at or below this length is left as a single chunk — identical
  /// to the pre-chunking behavior, with no extra requests.
  static const int singleChunkMaxChars = 900;

  /// Words ending with sentence-final punctuation (optionally followed by
  /// closing quotes/brackets) are eligible chunk boundaries.
  static final RegExp _sentenceEnd = RegExp(r'''[.!?…]["'”’)\]]*$''');

  /// Split [text] into narration chunks.
  ///
  /// Word counting matches the story reader's tokenizer exactly (runs of
  /// non-whitespace characters, whitespace = `char.trim().isEmpty`), so
  /// `wordOffset`/`wordCount` index directly into the reader's word list.
  static List<NarrationChunk> split(
    String text, {
    int firstTargetChars = firstChunkTargetChars,
    int laterTargetChars = laterChunkTargetChars,
  }) {
    if (text.trim().isEmpty) return const [];
    if (text.length <= singleChunkMaxChars) {
      return [
        NarrationChunk(
          text: text.trim(),
          wordOffset: 0,
          wordCount: _countWords(text),
        ),
      ];
    }

    final tokens = _tokenize(text);
    final chunks = <NarrationChunk>[];
    final buffer = StringBuffer();
    var bufferWords = 0;
    var wordsEmitted = 0;
    String? lastWordText;

    void flush() {
      final chunkText = buffer.toString().trim();
      if (chunkText.isEmpty) {
        buffer.clear();
        bufferWords = 0;
        return;
      }
      chunks.add(NarrationChunk(
        text: chunkText,
        wordOffset: wordsEmitted,
        wordCount: bufferWords,
      ));
      wordsEmitted += bufferWords;
      buffer.clear();
      bufferWords = 0;
      lastWordText = null;
    }

    int targetFor(int chunkIndex) =>
        chunkIndex == 0 ? firstTargetChars : laterTargetChars;

    for (var i = 0; i < tokens.length; i++) {
      final token = tokens[i];
      buffer.write(token.text);
      if (!token.isWhitespace) {
        bufferWords++;
        lastWordText = token.text;
      }

      final target = targetFor(chunks.length);
      if (buffer.length < target || bufferWords == 0) continue;

      // Prefer a sentence end or a newline; past 2x target take any word
      // boundary rather than growing without bound on a run-on sentence.
      final atSentenceEnd = !token.isWhitespace &&
          lastWordText != null &&
          _sentenceEnd.hasMatch(lastWordText!);
      final atNewline = token.isWhitespace && token.text.contains('\n');
      final overshoot = buffer.length >= target * 2 && token.isWhitespace;
      if (atSentenceEnd || atNewline || overshoot) {
        flush();
      }
    }
    flush();

    // A trailing sliver (e.g. a closing one-liner) reads better glued to the
    // previous chunk than as its own request.
    if (chunks.length >= 2 && chunks.last.text.length < 120) {
      final tail = chunks.removeLast();
      final prev = chunks.removeLast();
      chunks.add(NarrationChunk(
        text: '${prev.text}\n\n${tail.text}',
        wordOffset: prev.wordOffset,
        wordCount: prev.wordCount + tail.wordCount,
      ));
    }
    return chunks;
  }

  static int _countWords(String text) =>
      _tokenize(text).where((t) => !t.isWhitespace).length;

  /// Same tokenization as `_StoryReaderScreenState._tokenize`: alternating
  /// runs of whitespace / non-whitespace characters.
  static List<_ChunkToken> _tokenize(String input) {
    final tokens = <_ChunkToken>[];
    final buffer = StringBuffer();
    bool? currentWhitespace;

    void flush() {
      if (buffer.isEmpty) return;
      tokens.add(_ChunkToken(buffer.toString(), currentWhitespace ?? false));
      buffer.clear();
    }

    for (final rune in input.runes) {
      final char = String.fromCharCode(rune);
      final isWhitespace = char.trim().isEmpty;
      if (currentWhitespace == null) {
        currentWhitespace = isWhitespace;
      } else if (isWhitespace != currentWhitespace) {
        flush();
        currentWhitespace = isWhitespace;
      }
      buffer.write(char);
    }
    flush();
    return tokens;
  }
}

class _ChunkToken {
  final String text;
  final bool isWhitespace;
  const _ChunkToken(this.text, this.isWhitespace);
}
