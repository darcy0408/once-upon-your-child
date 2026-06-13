// Saga Record — a noir "ledger of the saga" for the Adolescent antihero band.
//
// Reached from the welcome-back recap ("View your record →"). Where the recap
// card shows only the LAST Issue, this screen lays out the whole run: the
// hero's current standing, who knows them, and a most-recent-first ledger of
// every Issue (its cost, the choice that bought it, the nemesis it turned on).
//
// Adolescent-facing — cinematic dark, electric-teal accent, SourceSans3, direct
// language. Reuses the band theme (themeForBand) and the welcome-back screen's
// public [SuperheroWelcomeBackScreen.humanizeNemesisStatus] mapping so the
// nemesis-status vocabulary stays single-sourced.
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../models/hero_saga.dart';
import '../theme/age_band_theme.dart';
import 'wizard_steps/superhero_welcome_back_screen.dart';

class SagaRecordScreen extends StatelessWidget {
  final HeroSaga saga;
  final String? heroAlias;
  final AgeBand band;

  const SagaRecordScreen({
    super.key,
    required this.saga,
    this.heroAlias,
    required this.band,
  });

  @override
  Widget build(BuildContext context) {
    final theme = themeForBand(band);
    final accent = theme.accent;
    final alias = (heroAlias?.trim().isNotEmpty == true)
        ? heroAlias!.trim()
        : 'Your hero';

    return Scaffold(
      extendBodyBehindAppBar: true,
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        title: Text(
          'Your Record',
          style: GoogleFonts.sourceSans3(
            color: accent,
            fontSize: 20,
            fontWeight: FontWeight.bold,
            letterSpacing: 0.5,
          ),
        ),
      ),
      body: Container(
        decoration: BoxDecoration(gradient: theme.backgroundGradient),
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 36),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _header(alias, accent),
                if (saga.allies.isNotEmpty) ...[
                  const SizedBox(height: 20),
                  _castRow(accent),
                ],
                const SizedBox(height: 24),
                if (saga.chapters.isEmpty)
                  _emptyState(accent)
                else
                  ..._ledger(accent),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // --- Header --------------------------------------------------------------

  Widget _header(String alias, Color accent) {
    final nemesis = saga.nemesis?.trim();
    final hasStanding = nemesis != null && nemesis.isNotEmpty;
    final status = SuperheroWelcomeBackScreen.humanizeNemesisStatus(
      saga.nemesisStatus,
    );

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 18),
      decoration: BoxDecoration(
        color: Colors.black.withAlpha(64),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: accent.withAlpha(110), width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            alias,
            style: GoogleFonts.sourceSans3(
              color: Colors.white,
              fontSize: 26,
              fontWeight: FontWeight.bold,
              height: 1.1,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'ISSUE #${saga.issueNumber}',
            style: GoogleFonts.sourceSans3(
              color: accent.withAlpha(210),
              fontSize: 13,
              fontWeight: FontWeight.bold,
              letterSpacing: 1.5,
            ),
          ),
          if (hasStanding) ...[
            const SizedBox(height: 14),
            Divider(color: accent.withAlpha(70), height: 1),
            const SizedBox(height: 14),
            Text(
              'CURRENT STANDING',
              style: GoogleFonts.sourceSans3(
                color: Colors.white.withAlpha(140),
                fontSize: 11,
                fontWeight: FontWeight.bold,
                letterSpacing: 1.5,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              status.isEmpty ? nemesis : '$nemesis $status.',
              style: GoogleFonts.sourceSans3(
                color: Colors.white.withAlpha(235),
                fontSize: 16,
                fontWeight: FontWeight.w600,
                height: 1.3,
              ),
            ),
          ],
        ],
      ),
    );
  }

  // --- Cast row ------------------------------------------------------------

  Widget _castRow(Color accent) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'WHO KNOWS',
          style: GoogleFonts.sourceSans3(
            color: accent.withAlpha(210),
            fontSize: 11,
            fontWeight: FontWeight.bold,
            letterSpacing: 1.5,
          ),
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final ally in saga.allies)
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.black.withAlpha(80),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: accent.withAlpha(90), width: 1),
                ),
                child: Text(
                  ally,
                  style: GoogleFonts.sourceSans3(
                    color: Colors.white.withAlpha(225),
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
          ],
        ),
      ],
    );
  }

  // --- Ledger --------------------------------------------------------------

  List<Widget> _ledger(Color accent) {
    // Most-recent-first: sort a copy by issueNumber descending so the list
    // reads like flipping back through the run, newest on top.
    final chapters = List<HeroSagaChapter>.from(saga.chapters)
      ..sort((a, b) => b.issueNumber.compareTo(a.issueNumber));

    return [
      Text(
        'THE LEDGER',
        style: GoogleFonts.sourceSans3(
          color: accent.withAlpha(210),
          fontSize: 11,
          fontWeight: FontWeight.bold,
          letterSpacing: 1.5,
        ),
      ),
      const SizedBox(height: 12),
      for (final c in chapters) ...[
        _chapterCard(c, accent),
        const SizedBox(height: 12),
      ],
    ];
  }

  Widget _chapterCard(HeroSagaChapter c, Color accent) {
    final title = c.title?.trim();
    final cost = c.cost?.trim();
    final choice = c.choice?.trim();
    final nemesis = c.nemesis?.trim();
    final status = SuperheroWelcomeBackScreen.humanizeNemesisStatus(
      c.nemesisStatus,
    );

    final footnote = (nemesis != null && nemesis.isNotEmpty)
        ? (status.isEmpty ? nemesis : '$nemesis — $status')
        : null;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: Colors.black.withAlpha(56),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: accent.withAlpha(70), width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'ISSUE #${c.issueNumber}',
            style: GoogleFonts.sourceSans3(
              color: accent.withAlpha(220),
              fontSize: 12,
              fontWeight: FontWeight.bold,
              letterSpacing: 1.2,
            ),
          ),
          if (title != null && title.isNotEmpty) ...[
            const SizedBox(height: 3),
            Text(
              title,
              style: GoogleFonts.sourceSans3(
                color: Colors.white,
                fontSize: 17,
                fontWeight: FontWeight.bold,
                height: 1.2,
              ),
            ),
          ],
          if (cost != null && cost.isNotEmpty) ...[
            const SizedBox(height: 12),
            _ledgerLine('The cost:', cost, accent),
          ],
          if (choice != null && choice.isNotEmpty) ...[
            const SizedBox(height: 10),
            _ledgerLine('You chose:', choice, accent),
          ],
          if (footnote != null) ...[
            const SizedBox(height: 12),
            Divider(color: accent.withAlpha(50), height: 1),
            const SizedBox(height: 8),
            Text(
              footnote,
              style: GoogleFonts.sourceSans3(
                color: Colors.white.withAlpha(150),
                fontSize: 12,
                fontStyle: FontStyle.italic,
                height: 1.3,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _ledgerLine(String label, String value, Color accent) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: GoogleFonts.sourceSans3(
            color: accent.withAlpha(220),
            fontSize: 11,
            fontWeight: FontWeight.bold,
            letterSpacing: 1.0,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: GoogleFonts.sourceSans3(
            color: Colors.white.withAlpha(235),
            fontSize: 15,
            fontWeight: FontWeight.w600,
            height: 1.3,
          ),
        ),
      ],
    );
  }

  // --- Empty state ---------------------------------------------------------

  Widget _emptyState(Color accent) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 32),
      decoration: BoxDecoration(
        color: Colors.black.withAlpha(40),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: accent.withAlpha(60), width: 1),
      ),
      child: Text(
        'Your saga starts with your first chapter.',
        textAlign: TextAlign.center,
        style: GoogleFonts.sourceSans3(
          color: Colors.white.withAlpha(190),
          fontSize: 16,
          fontStyle: FontStyle.italic,
          height: 1.4,
        ),
      ),
    );
  }
}
