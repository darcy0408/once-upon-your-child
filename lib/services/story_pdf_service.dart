// lib/services/story_pdf_service.dart
//
// Premium keepsake export: renders a saved story as a printable/shareable
// storybook PDF (cover page + one page per story page, illustration on top
// when available, text below). Designed to never throw — a corrupt/missing
// illustration is skipped rather than failing the whole export, and any
// characters the embedded fonts can't render are stripped rather than
// crashing pw.Text.
//
// Font handling: the standard 14 PDF fonts (Helvetica et al.) only cover
// WinAnsi/Latin-1 — no emoji, no fancy symbols. The app bundles exactly one
// local TTF asset (assets/fonts/CinzelDecorative-Bold.ttf, registered in
// pubspec.yaml as "Cinzel Decorative") which we embed via pw.Font.ttf for the
// cover title so the keepsake has a storybook feel; body text uses the base14
// Helvetica fonts, which need no embedding. Both paths run text through
// [_sanitizeForPdf] first, which normalizes common "smart" punctuation to
// ASCII and drops anything outside the printable-ASCII/Latin-1 range.

import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/services.dart' show rootBundle;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../models/local/story_local.dart';

class StoryPdfService {
  const StoryPdfService();

  static const String _titleFontAsset =
      'assets/fonts/CinzelDecorative-Bold.ttf';
  static const String _brandFooter = 'Once Upon YOUR Child';

  /// Builds a storybook PDF from a persisted [StoryLocal] row. Prefers the
  /// true page split in [StoryLocal.pages] (from `pagesJson`) and falls back
  /// to splitting the flat `storyText` for older saves that predate it.
  Future<Uint8List> buildFromStoryLocal(StoryLocal story) {
    return buildStorybookPdf(
      title: story.title,
      storyText: story.storyText,
      pages: story.pages,
      heroName:
          story.characters.isNotEmpty ? story.characters.first.name : null,
      coverImageBase64: story.coverImageBase64,
      pageIllustrationsJson: story.pageIllustrationsJson,
      createdAt: story.createdAt,
    );
  }

  /// Builds a storybook PDF and returns the raw bytes. Never throws: missing
  /// or corrupt art is silently skipped so export always succeeds with
  /// whatever content is actually available.
  ///
  /// [pages] is the preferred source of per-page text (the true page split
  /// the story was displayed with). When null/empty, [storyText] is split
  /// into approximate pages instead.
  ///
  /// [pageIllustrationsJson] is a JSON array of base64 strings (or null
  /// entries) indexed to line up with the resolved page list.
  Future<Uint8List> buildStorybookPdf({
    required String title,
    required String storyText,
    List<String>? pages,
    String? heroName,
    String? coverImageBase64,
    String? pageIllustrationsJson,
    DateTime? createdAt,
  }) async {
    final doc = pw.Document();

    final titleFont = await _loadTitleFont();
    final bodyFont = pw.Font.helvetica();
    final bodyBoldFont = pw.Font.helveticaBold();

    final resolvedPages = (pages != null && pages.isNotEmpty)
        ? pages
        : _splitStoryTextIntoPages(storyText);

    final illustrations =
        _decodePageIllustrations(pageIllustrationsJson, resolvedPages.length);
    final coverImage = _decodeImageSafely(coverImageBase64);

    doc.addPage(_buildCoverPage(
      title: title,
      heroName: heroName,
      coverImage: coverImage,
      titleFont: titleFont,
      bodyFont: bodyFont,
    ));

    for (var i = 0; i < resolvedPages.length; i++) {
      final pageImage = i < illustrations.length ? illustrations[i] : null;
      doc.addPage(_buildStoryPage(
        pageText: resolvedPages[i],
        pageNumber: i + 1,
        image: pageImage,
        bodyFont: bodyFont,
        bodyBoldFont: bodyBoldFont,
      ));
    }

    return doc.save();
  }

  // ---------------------------------------------------------------------
  // Page builders
  // ---------------------------------------------------------------------

  pw.Page _buildCoverPage({
    required String title,
    required String? heroName,
    required pw.MemoryImage? coverImage,
    required pw.Font? titleFont,
    required pw.Font bodyFont,
  }) {
    // Cinzel Decorative is already a bold display face; fall back to the
    // base14 bold font (never null) when the TTF asset failed to load.
    final resolvedTitleFont = titleFont ?? pw.Font.helveticaBold();
    return pw.Page(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.all(40),
      build: (context) {
        return pw.Column(
          mainAxisAlignment: pw.MainAxisAlignment.center,
          crossAxisAlignment: pw.CrossAxisAlignment.center,
          children: [
            if (coverImage != null)
              pw.Container(
                width: double.infinity,
                height: 320,
                margin: const pw.EdgeInsets.only(bottom: 28),
                decoration: pw.BoxDecoration(
                  borderRadius: pw.BorderRadius.circular(12),
                ),
                child: pw.ClipRRect(
                  horizontalRadius: 12,
                  verticalRadius: 12,
                  child: pw.Image(coverImage, fit: pw.BoxFit.cover),
                ),
              ),
            pw.Text(
              _sanitizeForPdf(title.isNotEmpty ? title : 'My Story'),
              textAlign: pw.TextAlign.center,
              style: pw.TextStyle(
                font: resolvedTitleFont,
                fontFallback: [bodyFont],
                fontSize: 30,
                fontWeight: pw.FontWeight.bold,
              ),
            ),
            if (heroName != null && heroName.trim().isNotEmpty) ...[
              pw.SizedBox(height: 12),
              pw.Text(
                'Starring ${_sanitizeForPdf(heroName)}',
                textAlign: pw.TextAlign.center,
                style: pw.TextStyle(
                  font: bodyFont,
                  fontSize: 16,
                  color: PdfColors.grey700,
                ),
              ),
            ],
            pw.Spacer(),
            pw.Text(
              _brandFooter,
              style: pw.TextStyle(
                font: bodyFont,
                fontSize: 11,
                color: PdfColors.grey500,
              ),
            ),
          ],
        );
      },
    );
  }

  pw.Page _buildStoryPage({
    required String pageText,
    required int pageNumber,
    required pw.MemoryImage? image,
    required pw.Font bodyFont,
    required pw.Font bodyBoldFont,
  }) {
    return pw.Page(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.all(36),
      build: (context) {
        return pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            if (image != null)
              pw.Container(
                width: double.infinity,
                height: 260,
                margin: const pw.EdgeInsets.only(bottom: 18),
                alignment: pw.Alignment.center,
                decoration: pw.BoxDecoration(
                  borderRadius: pw.BorderRadius.circular(10),
                  color: PdfColors.grey200,
                ),
                child: pw.ClipRRect(
                  horizontalRadius: 10,
                  verticalRadius: 10,
                  child: pw.Image(image, fit: pw.BoxFit.contain),
                ),
              ),
            pw.Expanded(
              child: pw.Text(
                _sanitizeForPdf(pageText),
                style: pw.TextStyle(
                  font: bodyFont,
                  fontSize: 14,
                  lineSpacing: 4,
                ),
              ),
            ),
            pw.Align(
              alignment: pw.Alignment.bottomRight,
              child: pw.Text(
                '$pageNumber',
                style: pw.TextStyle(
                  font: bodyFont,
                  fontSize: 10,
                  color: PdfColors.grey500,
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  // ---------------------------------------------------------------------
  // Font / text helpers
  // ---------------------------------------------------------------------

  Future<pw.Font?> _loadTitleFont() async {
    try {
      final data = await rootBundle.load(_titleFontAsset);
      return pw.Font.ttf(data);
    } catch (_) {
      // Missing asset (e.g. isolated test bundle) or malformed font data —
      // fall back to the base14 bold font for the title instead of crashing.
      return null;
    }
  }

  /// Normalizes common "smart" punctuation to ASCII, then strips any
  /// character outside printable-ASCII/Latin-1 (the range the base PDF fonts
  /// and the bundled TTF can reliably render). This is what keeps emoji and
  /// other fancy glyphs in story text from throwing during PDF rendering.
  String _sanitizeForPdf(String input) {
    final normalized = input
        .replaceAll('‘', "'")
        .replaceAll('’', "'")
        .replaceAll('“', '"')
        .replaceAll('”', '"')
        .replaceAll('–', '-')
        .replaceAll('—', '-')
        .replaceAll('…', '...');

    final buffer = StringBuffer();
    for (final rune in normalized.runes) {
      final isFormatting = rune == 0x09 || rune == 0x0A || rune == 0x0D;
      final isPrintableAscii = rune >= 0x20 && rune <= 0x7E;
      final isLatin1Supplement = rune >= 0xA0 && rune <= 0xFF;
      if (isFormatting || isPrintableAscii || isLatin1Supplement) {
        buffer.writeCharCode(rune);
      }
      // Else: drop it (emoji, symbols, and anything else the base fonts
      // can't render) rather than letting pw.Text throw.
    }
    return buffer.toString();
  }

  // ---------------------------------------------------------------------
  // Page-splitting / image-decoding helpers
  // ---------------------------------------------------------------------

  /// Best-effort pagination for older saves that only have flat `storyText`
  /// (no persisted `pages`). Mirrors the word-count-based pagination
  /// StoryResultScreen falls back to for a flat story (~120 words/page) so
  /// the resulting page count stays close to what any already-persisted
  /// `pageIllustrationsJson` was indexed against.
  List<String> _splitStoryTextIntoPages(String text, {int wordsPerPage = 120}) {
    final trimmed = text.trim();
    if (trimmed.isEmpty) return const [];

    final paragraphs = trimmed
        .split(RegExp(r'\n+'))
        .map((p) => p.trim())
        .where((p) => p.isNotEmpty)
        .toList();
    final source = paragraphs.isNotEmpty ? paragraphs : [trimmed];

    final pages = <String>[];
    final buffer = StringBuffer();
    var wordCount = 0;
    for (final paragraph in source) {
      final paragraphWordCount =
          paragraph.split(RegExp(r'\s+')).where((w) => w.isNotEmpty).length;
      if (wordCount > 0 && wordCount + paragraphWordCount > wordsPerPage) {
        pages.add(buffer.toString().trim());
        buffer.clear();
        wordCount = 0;
      }
      buffer.writeln(paragraph);
      buffer.writeln();
      wordCount += paragraphWordCount;
    }
    if (buffer.toString().trim().isNotEmpty) {
      pages.add(buffer.toString().trim());
    }
    return pages.isEmpty ? [trimmed] : pages;
  }

  /// Decodes a `pageIllustrationsJson` payload into a list of nullable
  /// images, padded/truncated to [expectedLength] so callers can index it
  /// safely. Never throws: a malformed payload or a corrupt individual
  /// entry simply yields no image for that slot.
  List<pw.MemoryImage?> _decodePageIllustrations(
      String? pageIllustrationsJson, int expectedLength) {
    if (pageIllustrationsJson == null || pageIllustrationsJson.isEmpty) {
      return List<pw.MemoryImage?>.filled(expectedLength, null);
    }
    List<dynamic> raw;
    try {
      final decoded = jsonDecode(pageIllustrationsJson);
      if (decoded is! List) {
        return List<pw.MemoryImage?>.filled(expectedLength, null);
      }
      raw = decoded;
    } catch (_) {
      return List<pw.MemoryImage?>.filled(expectedLength, null);
    }

    final result = <pw.MemoryImage?>[];
    for (var i = 0; i < expectedLength; i++) {
      if (i >= raw.length) {
        result.add(null);
        continue;
      }
      final entry = raw[i];
      result.add(entry is String ? _decodeImageSafely(entry) : null);
    }
    return result;
  }

  /// Decodes a base64-encoded image (optionally with a `data:image/...;base64,`
  /// prefix) into a [pw.MemoryImage]. Returns null — never throws — for
  /// missing, empty, or corrupt input so one bad illustration can't break the
  /// whole export.
  pw.MemoryImage? _decodeImageSafely(String? base64String) {
    if (base64String == null || base64String.isEmpty) return null;
    try {
      final commaIndex = base64String.indexOf(',');
      final cleaned = base64String.startsWith('data:') && commaIndex != -1
          ? base64String.substring(commaIndex + 1)
          : base64String;
      final bytes = base64Decode(cleaned);
      if (bytes.isEmpty) return null;
      return pw.MemoryImage(bytes);
    } catch (_) {
      return null;
    }
  }
}
