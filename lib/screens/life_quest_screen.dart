// lib/screens/life_quest_screen.dart
//
// Self-contained screen for playing pre-built Life Quest scenarios.
// No AI generation, no backend calls — reads from static quest data
// and renders an interactive choose-your-own-adventure experience.

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../data/life_quest_data.dart';
import '../services/app_tts_service.dart';
import '../theme/age_band_theme.dart';


/// Launch a Life Quest: shows quest selector, then plays the quest.
class LifeQuestScreen extends StatefulWidget {
  const LifeQuestScreen({
    super.key,
    required this.childAge,
    required this.childName,
    this.companionName = '',
    this.pronoun = 'they',
    this.pronounCap = 'They',
    this.possessive = 'their',
    this.selectedEmotion,
  });

  final int childAge;
  final String childName;
  final String companionName;
  final String pronoun;
  final String pronounCap;
  final String possessive;
  /// Pre-filter quests by emotion (from the feelings badge grid).
  final String? selectedEmotion;

  @override
  State<LifeQuestScreen> createState() => _LifeQuestScreenState();
}

class _LifeQuestScreenState extends State<LifeQuestScreen> {
  // ── State ─────────────────────────────────────────────────────────────────
  LifeQuestScenario? _activeQuest;
  QuestSegment? _currentSegment;
  final List<String> _segmentHistory = []; // for rewind
  bool _ttsEnabled = false;

  // ── Lifecycle ─────────────────────────────────────────────────────────────

  List<LifeQuestScenario> get _matchingQuests {
    if (widget.selectedEmotion == null) return allLifeQuests;
    return allLifeQuests
        .where((q) => q.emotions.contains(widget.selectedEmotion))
        .toList();
  }

  String _interpolate(String text) {
    return interpolateQuest(
      text,
      name: widget.childName,
      companion: widget.companionName,
      pronoun: widget.pronoun,
      pronounCap: widget.pronounCap,
      possessive: widget.possessive,
    );
  }

  void _startQuest(LifeQuestScenario quest) {
    setState(() {
      _activeQuest = quest;
      _currentSegment = quest.segments[quest.startSegmentId];
      _segmentHistory.clear();
    });
    _maybeSpeakSegment();
  }

  void _makeChoice(QuestChoice choice) {
    _segmentHistory.add(_currentSegment!.id);
    final next = _activeQuest!.segments[choice.nextSegmentId];
    setState(() {
      _currentSegment = next;
    });
    _maybeSpeakSegment();
  }

  void _rewind() {
    if (_segmentHistory.isEmpty) return;
    final prevId = _segmentHistory.removeLast();
    setState(() {
      _currentSegment = _activeQuest!.segments[prevId];
    });
  }

  void _maybeSpeakSegment() {
    if (_ttsEnabled && _currentSegment != null) {
      AppTtsService.instance.speak(_interpolate(_currentSegment!.content));
    }
  }

  void _resetToSelector() {
    AppTtsService.instance.stop();
    setState(() {
      _activeQuest = null;
      _currentSegment = null;
      _segmentHistory.clear();
    });
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final band = Theme.of(context).extension<AgeBandThemeData>() ??
        themeForAge(widget.childAge);

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [band.gradientStart, band.gradientMid, band.gradientEnd],
          ),
        ),
        child: SafeArea(
          child: _activeQuest == null
              ? _buildQuestSelector(band)
              : _buildQuestPlayer(band),
        ),
      ),
    );
  }

  // ── Quest Selector ────────────────────────────────────────────────────────

  Widget _buildQuestSelector(AgeBandThemeData band) {
    final quests = _matchingQuests;
    return Column(
      children: [
        // Header
        Padding(
          padding: const EdgeInsets.fromLTRB(4, 8, 4, 0),
          child: Row(
            children: [
              IconButton(
                icon: const Icon(Icons.close, color: Colors.white60),
                onPressed: () => Navigator.of(context).pop(),
              ),
              Expanded(
                child: Text(
                  'Pick Your Quest',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.fredoka(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const SizedBox(width: 48),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
          child: Text(
            'Life throws curveballs. Practice handling them here.',
            textAlign: TextAlign.center,
            style: GoogleFonts.fredoka(
              color: Colors.white60,
              fontSize: 14,
            ),
          ),
        ),
        // Quest cards
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
            itemCount: quests.length,
            itemBuilder: (context, i) => _buildQuestCard(quests[i], band),
          ),
        ),
      ],
    );
  }

  Widget _buildQuestCard(LifeQuestScenario quest, AgeBandThemeData band) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () => _startQuest(quest),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white.withAlpha(15),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.white.withAlpha(40)),
            ),
            child: Row(
              children: [
                Text(quest.emoji, style: const TextStyle(fontSize: 36)),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        quest.title,
                        style: GoogleFonts.fredoka(
                          color: Colors.white,
                          fontSize: 17,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        quest.hook,
                        style: GoogleFonts.fredoka(
                          color: Colors.white70,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
                const Icon(
                  Icons.arrow_forward_ios_rounded,
                  color: Colors.white30,
                  size: 16,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ── Quest Player ──────────────────────────────────────────────────────────

  Widget _buildQuestPlayer(AgeBandThemeData band) {
    final segment = _currentSegment!;
    final isEnding = segment.isEnding;

    return Column(
      children: [
        // Top bar
        Padding(
          padding: const EdgeInsets.fromLTRB(4, 8, 4, 0),
          child: Row(
            children: [
              if (_segmentHistory.isNotEmpty)
                IconButton(
                  icon: const Icon(Icons.undo_rounded, color: Colors.white70),
                  tooltip: 'Try a different choice',
                  onPressed: _rewind,
                )
              else
                IconButton(
                  icon: const Icon(Icons.close, color: Colors.white60),
                  onPressed: () {
                    AppTtsService.instance.stop();
                    Navigator.of(context).pop();
                  },
                ),
              Expanded(
                child: Text(
                  _activeQuest!.title,
                  textAlign: TextAlign.center,
                  style: GoogleFonts.fredoka(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w500,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              // TTS toggle
              IconButton(
                icon: Icon(
                  _ttsEnabled ? Icons.volume_up_rounded : Icons.volume_off_rounded,
                  color: Colors.white60,
                ),
                onPressed: () {
                  setState(() => _ttsEnabled = !_ttsEnabled);
                  if (_ttsEnabled) _maybeSpeakSegment();
                  if (!_ttsEnabled) AppTtsService.instance.stop();
                },
              ),
            ],
          ),
        ),
        // Story content
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Narrative text
                Text(
                  _interpolate(segment.content),
                  style: GoogleFonts.merriweather(
                    color: Colors.white.withAlpha(230),
                    fontSize: 15,
                    height: 1.7,
                  ),
                ),
                const SizedBox(height: 24),
                // Choices or ending
                if (isEnding) ...[
                  _buildEndingSection(segment, band),
                ] else ...[
                  ...segment.choices.map((c) => _buildChoiceButton(c, band)),
                ],
                const SizedBox(height: 16),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildChoiceButton(QuestChoice choice, AgeBandThemeData band) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: () => _makeChoice(choice),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
            decoration: BoxDecoration(
              color: band.accent.withAlpha(20),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: band.accent.withAlpha(80)),
            ),
            child: Text(
              _interpolate(choice.text),
              style: GoogleFonts.fredoka(
                color: Colors.white,
                fontSize: 15,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildEndingSection(QuestSegment segment, AgeBandThemeData band) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Divider
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 16),
          child: Row(
            children: [
              Expanded(child: Divider(color: Colors.white.withAlpha(40))),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Text(
                  'Quest Complete',
                  style: GoogleFonts.fredoka(
                    color: band.accent,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              Expanded(child: Divider(color: Colors.white.withAlpha(40))),
            ],
          ),
        ),
        // Reflection prompt
        if (segment.reflectionPrompt != null) ...[
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white.withAlpha(10),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: Colors.white.withAlpha(30)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Think About It',
                  style: GoogleFonts.fredoka(
                    color: band.accent,
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  _interpolate(segment.reflectionPrompt!),
                  style: GoogleFonts.fredoka(
                    color: Colors.white.withAlpha(200),
                    fontSize: 14,
                    height: 1.5,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
        ],
        // Action buttons
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                icon: const Icon(Icons.undo_rounded, size: 18),
                label: const Text('Try Different Choices'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.white70,
                  side: BorderSide(color: Colors.white.withAlpha(60)),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                onPressed: _rewind,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                icon: const Icon(Icons.explore_rounded, size: 18),
                label: const Text('Try Another Quest'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.white70,
                  side: BorderSide(color: Colors.white.withAlpha(60)),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                onPressed: _resetToSelector,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: FilledButton.icon(
                icon: const Icon(Icons.check_rounded, size: 18),
                label: const Text('Done'),
                style: FilledButton.styleFrom(
                  backgroundColor: band.accent,
                  foregroundColor: Colors.black87,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                onPressed: () {
                  AppTtsService.instance.stop();
                  Navigator.of(context).pop();
                },
              ),
            ),
          ],
        ),
      ],
    );
  }
}
