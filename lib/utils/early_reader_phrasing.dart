/// Reflows one Learning-to-Read page into short, phrase-sized lines so an
/// early reader can track one idea at a time.
///
/// Extracted from `StoryResultScreen._phrasifyForEarlyReader` so it can be
/// unit-tested. Two rules that a regex-only version got wrong:
///
/// * Text that already carries line breaks (verse — Limerick Mode, Rhyme
///   Time couplets) is returned line-for-line. Those lines ARE the phrases,
///   and the sentence scanner used to drop every line that didn't end in
///   `.`, `!` or `?` — a limerick page rendered as just its last line.
/// * Prose between two matched sentences (a clause with no terminal
///   punctuation) is kept instead of silently discarded.
String phrasifyForEarlyReader(String text) {
  final source = text.trim();
  if (source.isEmpty) return text;

  if (source.contains('\n')) {
    final verseLines = source
        .split('\n')
        .map((line) => line.trim())
        .where((line) => line.isNotEmpty)
        .toList();
    return verseLines.join('\n');
  }

  final sentencePattern = RegExp(r'[^.!?\n]+[.!?]+["’”\)]*');
  final sentences = <String>[];
  var lastEnd = 0;
  for (final m in sentencePattern.allMatches(source)) {
    if (m.start > lastEnd) {
      final gap = source.substring(lastEnd, m.start).trim();
      if (gap.isNotEmpty) sentences.add(gap);
    }
    sentences.add(m.group(0)!.trim());
    lastEnd = m.end;
  }
  if (lastEnd < source.length) {
    final tail = source.substring(lastEnd).trim();
    if (tail.isNotEmpty) sentences.add(tail);
  }
  if (sentences.isEmpty) return text;

  const longSentenceThreshold = 50;
  const minPhraseLen = 15;
  final commaPattern = RegExp(r'[^,;:\n]+(?:[,;:]|$)');
  final lines = <String>[];
  for (final sentence in sentences) {
    if (sentence.length <= longSentenceThreshold) {
      lines.add(sentence);
      continue;
    }
    final parts = <String>[];
    var subEnd = 0;
    for (final m in commaPattern.allMatches(sentence)) {
      final part = sentence.substring(subEnd, m.end).trim();
      if (part.isNotEmpty) parts.add(part);
      subEnd = m.end;
    }
    if (parts.isEmpty) {
      lines.add(sentence);
      continue;
    }
    final merged = <String>[];
    for (final part in parts) {
      if (part.length < minPhraseLen && merged.isNotEmpty) {
        merged[merged.length - 1] = '${merged.last} $part';
      } else {
        merged.add(part);
      }
    }
    lines.addAll(merged);
  }

  return lines.join('\n');
}
