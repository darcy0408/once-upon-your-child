// lib/widgets/crisis_resources_panel.dart
//
// MT-159 / content-safety audit F-09 — surfaces real-world crisis
// resources to teen readers inside the peer-mental-health-crisis Life
// Quest ("Someone Needs Help"). Shown at story start AND story end so a
// reader who recognises themselves or a friend in the story always has a
// next step available.
//
// US-only for now. The visible strings live in a single private constant
// list so swapping in a locale-specific list later (when the app adds
// proper i18n via AppLocalizations) is a one-call change at the point of
// use. See TODO(i18n) below.

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';

import '../theme/age_band_theme.dart';

/// A single listed crisis resource (name, action lines, url).
class CrisisResource {
  final String name;
  final String description;
  /// Primary call-to-action — typically the phone or text number. Tapping
  /// launches the appropriate tel:/sms: intent on supported platforms.
  final String action;
  /// Optional second action (e.g. "text START to 678-678" alongside a
  /// voice line). Tapping launches an sms: intent when present.
  final String? secondaryAction;
  final String url;
  /// `tel:` or `sms:` URI for [action]. Web falls back to the http url.
  final Uri actionUri;
  /// Optional sms: URI for [secondaryAction].
  final Uri? secondaryActionUri;

  const CrisisResource({
    required this.name,
    required this.description,
    required this.action,
    required this.url,
    required this.actionUri,
    this.secondaryAction,
    this.secondaryActionUri,
  });
}

/// US crisis lines. Values are operational, not creative — do not edit
/// without checking the live numbers/urls against each provider's site.
///
// TODO(i18n): non-US locales need their own crisis lines. When the app
// gains AppLocalizations, replace this constant with a locale-aware
// lookup (e.g. crisisResourcesForLocale(Localizations.localeOf(context))).
final List<CrisisResource> _usCrisisResources = [
  CrisisResource(
    name: '988 Suicide & Crisis Lifeline',
    description: 'Call or text 988',
    action: '988',
    url: 'https://988lifeline.org',
    actionUri: Uri(scheme: 'tel', path: '988'),
  ),
  CrisisResource(
    name: 'Crisis Text Line',
    description: 'Text HOME to 741741',
    action: '741741',
    url: 'https://www.crisistextline.org',
    actionUri: Uri(
      scheme: 'sms',
      path: '741741',
      queryParameters: {'body': 'HOME'},
    ),
  ),
  CrisisResource(
    name: 'The Trevor Project (LGBTQ+ youth)',
    description: 'Call 1-866-488-7386 or text START to 678-678',
    action: '1-866-488-7386',
    secondaryAction: 'Text START to 678-678',
    url: 'https://www.thetrevorproject.org',
    actionUri: Uri(scheme: 'tel', path: '18664887386'),
    secondaryActionUri: Uri(
      scheme: 'sms',
      path: '678678',
      queryParameters: {'body': 'START'},
    ),
  ),
];

/// Calm, supportive panel listing the US crisis lines. Earthy/warm tones,
/// not red emergency styling — the placement (top + bottom of a sensitive
/// quest) does the work; the visual treatment stays in the "we care about
/// you" register rather than the "danger" one.
class CrisisResourcesPanel extends StatelessWidget {
  const CrisisResourcesPanel({super.key});

  /// Earthy warm sand/clay base. Independent of band accent so the panel
  /// reads as "support information" rather than "story content".
  static const Color _warmBase = Color(0xFFC9A678);
  static const Color _warmDeep = Color(0xFF8B6B3D);

  Future<void> _open(Uri uri) async {
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context) {
    final band = Theme.of(context).extension<AgeBandThemeData>();
    final useSerif = band == null || band.band.isMature;
    final headlineStyle = useSerif
        ? GoogleFonts.sourceSans3(
            color: Colors.white,
            fontSize: 15,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.2,
          )
        : GoogleFonts.fredoka(
            color: Colors.white,
            fontSize: 15,
            fontWeight: FontWeight.w700,
          );

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            _warmBase.withAlpha(60),
            _warmDeep.withAlpha(35),
          ],
        ),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _warmBase.withAlpha(140), width: 1.2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.favorite_rounded,
                  size: 18, color: _warmBase.withAlpha(230)),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'If you or someone you know is in crisis',
                  style: headlineStyle,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          for (final r in _usCrisisResources) ...[
            _ResourceRow(
              resource: r,
              onTapAction: () => _open(r.actionUri),
              onTapSecondary: r.secondaryActionUri == null
                  ? null
                  : () => _open(r.secondaryActionUri!),
              onTapUrl: () => _open(Uri.parse(r.url)),
              useSerif: useSerif,
            ),
            const SizedBox(height: 8),
          ],
          const SizedBox(height: 2),
          Text(
            'These services are free, confidential, available 24/7.',
            style: useSerif
                ? GoogleFonts.sourceSans3(
                    color: Colors.white.withAlpha(180),
                    fontSize: 12,
                    fontStyle: FontStyle.italic,
                  )
                : GoogleFonts.fredoka(
                    color: Colors.white.withAlpha(180),
                    fontSize: 12,
                    fontStyle: FontStyle.italic,
                  ),
          ),
        ],
      ),
    );
  }
}

/// Surfaces [CrisisResourcesPanel] in a calm, non-blocking modal sheet.
///
/// Used by free-text submit paths (see utils/distress_detector.dart) so a
/// child who types something distressing always has real resources one tap
/// away. Non-blocking by design: it never scolds and never prevents the child
/// from continuing — they can dismiss it and their story still goes through.
/// The warm dark backdrop keeps the panel in the "we care about you" register
/// rather than a red "danger" one.
Future<void> showCrisisResourcesSheet(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: const Color(0xFF2A2118), // warm dark, matches the panel
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (_) => const SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(16, 16, 16, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [CrisisResourcesPanel()],
        ),
      ),
    ),
  );
}

class _ResourceRow extends StatelessWidget {
  const _ResourceRow({
    required this.resource,
    required this.onTapAction,
    required this.onTapUrl,
    required this.useSerif,
    this.onTapSecondary,
  });

  final CrisisResource resource;
  final VoidCallback onTapAction;
  final VoidCallback onTapUrl;
  final VoidCallback? onTapSecondary;
  final bool useSerif;

  @override
  Widget build(BuildContext context) {
    final nameStyle = useSerif
        ? GoogleFonts.sourceSans3(
            color: Colors.white,
            fontSize: 13.5,
            fontWeight: FontWeight.w600,
          )
        : GoogleFonts.fredoka(
            color: Colors.white,
            fontSize: 13.5,
            fontWeight: FontWeight.w600,
          );
    final descStyle = useSerif
        ? GoogleFonts.sourceSans3(
            color: Colors.white.withAlpha(210),
            fontSize: 12.5,
            height: 1.4,
          )
        : GoogleFonts.fredoka(
            color: Colors.white.withAlpha(210),
            fontSize: 12.5,
            height: 1.4,
          );
    return Padding(
      padding: const EdgeInsets.only(top: 2),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(resource.name, style: nameStyle),
          const SizedBox(height: 2),
          // Description is tappable on its primary number; secondary
          // action (if any) is exposed via a small inline link below.
          InkWell(
            onTap: onTapAction,
            child: Text(resource.description, style: descStyle),
          ),
          if (resource.secondaryAction != null && onTapSecondary != null)
            InkWell(
              onTap: onTapSecondary,
              child: Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Text(
                  resource.secondaryAction!,
                  style: descStyle,
                ),
              ),
            ),
          InkWell(
            onTap: onTapUrl,
            child: Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Text(
                resource.url,
                style: useSerif
                    ? GoogleFonts.sourceSans3(
                        color: CrisisResourcesPanel._warmBase,
                        fontSize: 12,
                        decoration: TextDecoration.underline,
                      )
                    : GoogleFonts.fredoka(
                        color: CrisisResourcesPanel._warmBase,
                        fontSize: 12,
                        decoration: TextDecoration.underline,
                      ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
