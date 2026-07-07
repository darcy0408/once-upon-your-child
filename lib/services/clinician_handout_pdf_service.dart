// lib/services/clinician_handout_pdf_service.dart
//
// Printable one-sheet for the Weekly Parent Recap: a caregiver hands it to a
// therapist, counselor, or teacher as a conversation starter. Mirrors
// StoryPdfService's defensive posture — never throws, degrades to whatever
// data the week actually has — and its font strategy (base-14 Helvetica
// only; no embedding needed). Like there, text runs through a sanitizer
// because the base fonts can't render emoji: feeling names are printed,
// feeling emoji are not.
//
// The handout is generated on-device from on-device data and shared via the
// OS share sheet; nothing is uploaded.

import 'dart:typed_data';

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import 'parent_recap_service.dart';

class ClinicianHandoutPdfService {
  const ClinicianHandoutPdfService();

  static const String _brand = 'Once Upon YOUR Child';
  static const List<String> _months = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
  ];

  /// Builds the handout and returns raw PDF bytes. Never throws: an empty
  /// week still produces a valid document with per-section "none recorded"
  /// lines so the caregiver can see the recap ran, not that it failed.
  Future<Uint8List> buildHandout({
    required WeeklyRecapData recap,
    String? childLabel,
  }) async {
    final body = pw.Font.helvetica();
    final bold = pw.Font.helveticaBold();
    final doc = pw.Document();

    doc.addPage(pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.all(44),
      footer: (context) => _footer(body),
      build: (context) => [
        _header(recap, childLabel, body: body, bold: bold),
        pw.SizedBox(height: 18),
        _summaryLine(recap, body: body),
        pw.SizedBox(height: 20),
        _sectionTitle('Feelings check-ins', bold),
        ..._feelingsSection(recap, body: body, bold: bold),
        pw.SizedBox(height: 18),
        _sectionTitle('Stories created', bold),
        ..._storiesSection(recap, body: body, bold: bold),
        pw.SizedBox(height: 18),
        _sectionTitle('Life Quests completed', bold),
        ..._questsSection(recap, body: body),
        pw.SizedBox(height: 24),
        _clinicianNote(body: body, bold: bold),
      ],
    ));

    return doc.save();
  }

  // ---------------------------------------------------------------------
  // Sections
  // ---------------------------------------------------------------------

  pw.Widget _header(WeeklyRecapData recap, String? childLabel,
      {required pw.Font body, required pw.Font bold}) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(
          'Weekly Story & Feelings Recap',
          style: pw.TextStyle(font: bold, fontSize: 22),
        ),
        pw.SizedBox(height: 4),
        pw.Text(
          _sanitize(
            childLabel != null && childLabel.trim().isNotEmpty
                ? '$childLabel - ${_fmtDate(recap.weekStart)} to ${_fmtDate(recap.weekEnd)}'
                : '${_fmtDate(recap.weekStart)} to ${_fmtDate(recap.weekEnd)}',
          ),
          style: pw.TextStyle(
              font: body, fontSize: 12, color: PdfColors.grey700),
        ),
      ],
    );
  }

  pw.Widget _summaryLine(WeeklyRecapData recap, {required pw.Font body}) {
    return pw.Text(
      '${recap.stories.length} ${recap.stories.length == 1 ? 'story' : 'stories'} created  ·  '
      '${recap.checkIns.length} feeling ${recap.checkIns.length == 1 ? 'check-in' : 'check-ins'}  ·  '
      '${recap.questCompletions.length} Life ${recap.questCompletions.length == 1 ? 'Quest' : 'Quests'} completed',
      style: pw.TextStyle(font: body, fontSize: 12),
    );
  }

  pw.Widget _sectionTitle(String title, pw.Font bold) {
    return pw.Container(
      margin: const pw.EdgeInsets.only(bottom: 8),
      padding: const pw.EdgeInsets.only(bottom: 3),
      decoration: const pw.BoxDecoration(
        border: pw.Border(
          bottom: pw.BorderSide(color: PdfColors.grey400, width: 0.5),
        ),
      ),
      child: pw.Text(title, style: pw.TextStyle(font: bold, fontSize: 14)),
    );
  }

  List<pw.Widget> _feelingsSection(WeeklyRecapData recap,
      {required pw.Font body, required pw.Font bold}) {
    if (recap.topFeelings.isEmpty) {
      return [_emptyLine('No feeling check-ins were recorded this week.', body)];
    }
    return [
      pw.TableHelper.fromTextArray(
        headers: ['Feeling', 'Check-ins', 'Typical intensity (1-5)'],
        data: recap.topFeelings
            .map((f) => [
                  _sanitize(f.name),
                  '${f.count}',
                  f.avgIntensity.toStringAsFixed(1),
                ])
            .toList(),
        headerStyle: pw.TextStyle(font: bold, fontSize: 11),
        cellStyle: pw.TextStyle(font: body, fontSize: 11),
        headerDecoration: const pw.BoxDecoration(color: PdfColors.grey200),
        cellAlignments: {
          0: pw.Alignment.centerLeft,
          1: pw.Alignment.center,
          2: pw.Alignment.center,
        },
        border: pw.TableBorder.all(color: PdfColors.grey300, width: 0.5),
      ),
    ];
  }

  List<pw.Widget> _storiesSection(WeeklyRecapData recap,
      {required pw.Font body, required pw.Font bold}) {
    if (recap.stories.isEmpty) {
      return [_emptyLine('No stories were created this week.', body)];
    }
    final rows = recap.stories.map((s) {
      final practiced = s.practiced;
      final suffix = practiced != null && practiced.trim().isNotEmpty
          ? '  -  practiced: ${practiced.trim()}'
          : '';
      return _bullet(
        '${s.title.isNotEmpty ? s.title : 'Untitled story'}'
        ' (${s.theme.isNotEmpty ? s.theme : 'story'}, ${_fmtDate(s.createdAt)})'
        '$suffix',
        body,
      );
    }).toList();

    final focuses = recap.practicedFocuses;
    if (focuses.isNotEmpty) {
      rows.add(pw.Padding(
        padding: const pw.EdgeInsets.only(top: 6),
        child: pw.Text(
          _sanitize('Focus areas practiced this week: ${focuses.join(', ')}'),
          style: pw.TextStyle(font: bold, fontSize: 11),
        ),
      ));
    }
    return rows;
  }

  List<pw.Widget> _questsSection(WeeklyRecapData recap,
      {required pw.Font body}) {
    if (recap.questCompletions.isEmpty) {
      return [
        _emptyLine('No Life Quests were completed this week.', body),
      ];
    }
    return recap.questCompletions
        .map((q) => _bullet(
              '${q.title.isNotEmpty ? q.title : q.questId} (${_fmtDate(q.timestamp)})',
              body,
            ))
        .toList();
  }

  pw.Widget _clinicianNote({required pw.Font body, required pw.Font bold}) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(12),
      decoration: pw.BoxDecoration(
        color: PdfColors.grey100,
        borderRadius: pw.BorderRadius.circular(6),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text('For caregivers and clinicians',
              style: pw.TextStyle(font: bold, fontSize: 11)),
          pw.SizedBox(height: 4),
          pw.Text(
            'This summary was generated on the family\'s own device from the '
            'child\'s in-app activity. Check-ins are the feelings the child '
            'chose while making stories or exploring the Feelings Garden. It '
            'is offered as a conversation starter, not an assessment or '
            'diagnostic instrument.',
            style: pw.TextStyle(
                font: body, fontSize: 10, color: PdfColors.grey800),
          ),
        ],
      ),
    );
  }

  pw.Widget _footer(pw.Font body) {
    return pw.Row(
      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
      children: [
        pw.Text(_brand,
            style: pw.TextStyle(
                font: body, fontSize: 9, color: PdfColors.grey500)),
        pw.Text('Generated on-device - no child data is uploaded or shared.',
            style: pw.TextStyle(
                font: body, fontSize: 9, color: PdfColors.grey500)),
      ],
    );
  }

  // ---------------------------------------------------------------------
  // Helpers
  // ---------------------------------------------------------------------

  pw.Widget _bullet(String text, pw.Font body) {
    return pw.Padding(
      padding: const pw.EdgeInsets.only(bottom: 4),
      child: pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text('- ', style: pw.TextStyle(font: body, fontSize: 11)),
          pw.Expanded(
            child: pw.Text(_sanitize(text),
                style: pw.TextStyle(font: body, fontSize: 11)),
          ),
        ],
      ),
    );
  }

  pw.Widget _emptyLine(String text, pw.Font body) {
    return pw.Text(text,
        style:
            pw.TextStyle(font: body, fontSize: 11, color: PdfColors.grey600));
  }

  String _fmtDate(DateTime d) => '${_months[d.month - 1]} ${d.day}';

  /// Same normalization + strip pass as StoryPdfService._sanitizeForPdf
  /// (kept private there): smart punctuation to ASCII, then drop anything
  /// the base-14 fonts can't render (emoji included).
  String _sanitize(String input) {
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
    }
    return buffer.toString();
  }
}
