// lib/screens/life_quest_screen.dart
//
// Self-contained screen for playing pre-built Life Quest scenarios.
// No AI generation, no backend calls — reads from static quest data
// and renders an interactive choose-your-own-adventure experience.

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../data/coping_techniques.dart';
import '../data/life_quest_data.dart';
import '../services/app_tts_service.dart';
import '../theme/age_band_theme.dart';
import '../widgets/coping_practice_sheet.dart';


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
  /// Sprout-only: which cloud persona the user tapped on the entry grid.
  /// Null = entry grid is showing. Non-null = filtered quest list for that cloud.
  SproutCloud? _selectedCloud;

  /// On for Sprout (3-5 can't read story prose), off otherwise (older kids
  /// can read at their own pace and may prefer silent reading).
  late bool _ttsEnabled;

  bool get _isSprout => ageBandFromAge(widget.childAge) == AgeBand.sprout;
  bool get _isExplorer => ageBandFromAge(widget.childAge) == AgeBand.explorer;

  /// Clouds that have at least one Sprout quest. Empty clouds (e.g. Sunny
  /// while no happy stories exist) are hidden from the entry grid so a
  /// 4-year-old doesn't tap the brightest-looking option and hit a dead end.
  List<SproutCloud> get _activeClouds => SproutCloud.values
      .where((cloud) => allLifeQuests.any((q) =>
          q.cloud == cloud &&
          q.recommendedBands.contains(AgeBand.sprout)))
      .toList();

  @override
  void initState() {
    super.initState();
    _ttsEnabled = _isSprout;
    if (_isSprout && _activeQuest == null) {
      // After the cloud grid is first painted, speak a welcome that names
      // each visible cloud so non-readers know what they're choosing between.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        final names = _activeClouds.map((c) => c.displayName).join(', ');
        AppTtsService.instance.speak(
          'Tap a cloud friend! $names.',
          rateScale: 0.65,
        );
      });
    }
  }

  @override
  void dispose() {
    AppTtsService.instance.stop();
    super.dispose();
  }

  // ── Fonts ─────────────────────────────────────────────────────────────────
  // Life Quest is cross-band: younger bands use Fredoka (playful, rounded);
  // mature bands (creator/adolescent/adult) use SourceSans3 to match their
  // cinematic/editorial UI chrome.
  TextStyle _chromeStyle(
    AgeBandThemeData band, {
    required double fontSize,
    Color color = Colors.white,
    FontWeight? fontWeight,
  }) {
    return band.band.isMature
        ? GoogleFonts.sourceSans3(
            color: color,
            fontSize: fontSize,
            fontWeight: fontWeight,
          )
        : GoogleFonts.fredoka(
            color: color,
            fontSize: fontSize,
            fontWeight: fontWeight,
          );
  }

  // ── Lifecycle ─────────────────────────────────────────────────────────────

  List<LifeQuestScenario> get _matchingQuests {
    final band = ageBandFromAge(widget.childAge);
    var quests = allLifeQuests
        .where((q) => q.recommendedBands.contains(band))
        .toList();
    if (widget.selectedEmotion != null) {
      quests = quests.where((q) => q.emotions.contains(widget.selectedEmotion)).toList();
    }
    // Sprout: when a cloud is selected, only show quests for that cloud.
    if (_isSprout && _selectedCloud != null) {
      quests = quests.where((q) => q.cloud == _selectedCloud).toList();
    }
    return quests;
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

  String _selectorSubtitle() {
    final band = ageBandFromAge(widget.childAge);
    switch (band) {
      case AgeBand.sprout:
      case AgeBand.explorer:
        return 'Adventures about feelings are on their way!';
      case AgeBand.adventurer:
        return 'Life throws curveballs. Practice handling them here.';
      case AgeBand.creator:
        return 'Your feelings run deep. These stories explore them.';
      case AgeBand.adolescent:
        return "Some situations don't have easy answers. Let's sit with them.";
      case AgeBand.adult:
        return 'Reflect on the moments that shape you.';
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
    // Sprout entry: cloud-character grid first. Tap a cloud → filtered quests.
    if (_isSprout && _selectedCloud == null) {
      return _buildSproutCloudGrid(band);
    }
    final quests = _matchingQuests;
    final isYoung = widget.childAge <= 8;
    final headerTitle = _isSprout
        ? _selectedCloud!.displayName
        : 'Pick Your Quest';
    return Column(
      children: [
        // Header
        Padding(
          padding: const EdgeInsets.fromLTRB(4, 8, 4, 0),
          child: Row(
            children: [
              IconButton(
                icon: Icon(
                  _isSprout
                      ? Icons.arrow_back_ios_new_rounded
                      : Icons.close,
                  color: Colors.white60,
                ),
                tooltip: _isSprout ? 'Back to clouds' : null,
                onPressed: () {
                  if (_isSprout) {
                    setState(() => _selectedCloud = null);
                  } else {
                    Navigator.of(context).pop();
                  }
                },
              ),
              Expanded(
                child: Text(
                  headerTitle,
                  textAlign: TextAlign.center,
                  style: _chromeStyle(band,
                      fontSize: 22, fontWeight: FontWeight.w600),
                ),
              ),
              const SizedBox(width: 48),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
          child: Text(
            _isSprout
                ? "Tap a story you'd like to hear!"
                : _selectorSubtitle(),
            textAlign: TextAlign.center,
            style: _chromeStyle(band, color: Colors.white60, fontSize: 14),
          ),
        ),
        // Coping Toolbox — Explorer only. Sprout has the cloud picker as its
        // entry pattern; older bands get their own coping integration in story.
        if (_isExplorer) _buildCopingToolbox(band),
        // Quest cards or empty state
        if (quests.isEmpty)
          Expanded(
            child: Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      isYoung ? '🌱' : '🚀',
                      style: const TextStyle(fontSize: 64),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'More quests coming soon!',
                      textAlign: TextAlign.center,
                      style: _chromeStyle(band,
                          color: Colors.white70,
                          fontSize: 18,
                          fontWeight: FontWeight.w500),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      // Sprout's empty state is rare now that we filter the
                      // grid to active clouds, but keep a friendly message
                      // for the edge where a story is removed at runtime.
                      _isSprout
                          ? 'More stories coming soon!'
                          : isYoung
                              ? 'Check back later for stories about big feelings.'
                              : 'New scenarios are being added.',
                      textAlign: TextAlign.center,
                      style: _chromeStyle(band,
                          color: Colors.white38, fontSize: 14),
                    ),
                  ],
                ),
              ),
            ),
          )
        else
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

  // ── Sprout Cloud Grid ─────────────────────────────────────────────────────

  /// 2×2 grid of cloud personas. Each cloud "guides" stories about one
  /// feeling family. Sunny is shown even when empty so kids see all 4 core
  /// feelings represented — tapping it just shows the "more stories soon"
  /// state.
  Widget _buildSproutCloudGrid(AgeBandThemeData band) {
    return Column(
      children: [
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
                  'Big Feelings',
                  textAlign: TextAlign.center,
                  style: _chromeStyle(band,
                      fontSize: 24, fontWeight: FontWeight.w600),
                ),
              ),
              const SizedBox(width: 48),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
          child: Text(
            'Tap a cloud friend!',
            textAlign: TextAlign.center,
            style: _chromeStyle(band, color: Colors.white70, fontSize: 16),
          ),
        ),
        const SizedBox(height: 8),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
            child: GridView.count(
              crossAxisCount: 2,
              mainAxisSpacing: 16,
              crossAxisSpacing: 16,
              children: _activeClouds
                  .map((cloud) => _buildCloudCard(cloud, band))
                  .toList(),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildCloudCard(SproutCloud cloud, AgeBandThemeData band) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: () {
          AppTtsService.instance.speak(cloud.displayName, rateScale: 0.65);
          setState(() => _selectedCloud = cloud);
        },
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                cloud.tintColor.withAlpha(60),
                cloud.tintColor.withAlpha(20),
              ],
            ),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: cloud.tintColor.withAlpha(120),
              width: 2,
            ),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Expanded(
                child: Image.asset(
                  'assets/images/feelings/sprout/${cloud.assetName}.png',
                  fit: BoxFit.contain,
                  errorBuilder: (_, __, ___) => Center(
                    child: Text(
                      cloud.fallbackEmoji,
                      style: const TextStyle(fontSize: 64),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 6),
              Text(
                cloud.displayName,
                style: _chromeStyle(band,
                    fontSize: 16, fontWeight: FontWeight.w700),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Coping Toolbox (Explorer) ─────────────────────────────────────────────
  //
  // Horizontal strip of breath/grounding techniques shown above the quest
  // list. Always available — the kid can practice when they want, not only
  // when they hit a story trigger. Each card opens an animated guided
  // practice via CopingPracticeSheet.
  Widget _buildCopingToolbox(AgeBandThemeData band) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 4, bottom: 8),
            child: Row(
              children: [
                const Text('🧰', style: TextStyle(fontSize: 16)),
                const SizedBox(width: 6),
                Text(
                  'Feeling toolbox',
                  style: _chromeStyle(band,
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.w700),
                ),
                const SizedBox(width: 8),
                Text(
                  '— tap to practice anytime',
                  style: _chromeStyle(band,
                      color: Colors.white54, fontSize: 11),
                ),
              ],
            ),
          ),
          SizedBox(
            height: 96,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 2),
              itemCount: allCopingTechniques.length,
              separatorBuilder: (_, __) => const SizedBox(width: 10),
              itemBuilder: (context, i) =>
                  _buildToolboxCard(allCopingTechniques[i], band),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildToolboxCard(CopingTechnique technique, AgeBandThemeData band) {
    final color = Color(technique.colorSeed);
    return GestureDetector(
      onTap: () => CopingPracticeSheet.show(context, technique: technique),
      child: Container(
        width: 110,
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [color.withAlpha(70), color.withAlpha(25)],
          ),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: color.withAlpha(140), width: 1.5),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(technique.emoji, style: const TextStyle(fontSize: 30)),
            const SizedBox(height: 4),
            Text(
              technique.name,
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: _chromeStyle(band,
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.w700),
            ),
          ],
        ),
      ),
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
                        style: _chromeStyle(band,
                            fontSize: 17, fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        quest.hook,
                        style: _chromeStyle(band,
                            color: Colors.white70, fontSize: 13),
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
              IconButton(
                icon: const Icon(Icons.close, color: Colors.white60),
                tooltip: 'Back to quests',
                onPressed: _resetToSelector,
              ),
              if (_segmentHistory.isNotEmpty)
                IconButton(
                  icon: const Icon(Icons.undo_rounded, color: Colors.white70),
                  tooltip: 'Try a different choice',
                  onPressed: _rewind,
                ),
              Expanded(
                child: Text(
                  _activeQuest!.title,
                  textAlign: TextAlign.center,
                  style: _chromeStyle(band,
                      fontSize: 18, fontWeight: FontWeight.w500),
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
                // Optional coping break — when the segment author wired one in,
                // surface a "Try it with {name}!" card between the prose and
                // the choices. Tapping opens the animated practice sheet; the
                // story stays paused on the same segment so the kid returns
                // to the choices when they're done.
                if (segment.copingBreakId != null) ...[
                  _buildCopingBreakCard(segment.copingBreakId!, band),
                  const SizedBox(height: 18),
                ],
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

  /// Inline "Try it with {name}!" card rendered between prose and choices
  /// when a segment has [QuestSegment.copingBreakId] set. Falls back to a
  /// SizedBox if the id can't be resolved (defensive — shouldn't happen
  /// once content authoring is in sync with the technique library).
  Widget _buildCopingBreakCard(String techniqueId, AgeBandThemeData band) {
    final technique = copingById(techniqueId);
    if (technique == null) return const SizedBox.shrink();
    final color = Color(technique.colorSeed);
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => CopingPracticeSheet.show(context, technique: technique),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [color.withAlpha(80), color.withAlpha(30)],
            ),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: color.withAlpha(160), width: 1.5),
          ),
          child: Row(
            children: [
              Text(technique.emoji, style: const TextStyle(fontSize: 36)),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Try it with ${widget.childName}!',
                      style: _chromeStyle(band,
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${technique.name} — ${technique.tagline}',
                      style: _chromeStyle(band,
                          color: Colors.white70, fontSize: 12),
                    ),
                  ],
                ),
              ),
              Icon(Icons.play_circle_fill_rounded,
                  color: color.withAlpha(220), size: 32),
            ],
          ),
        ),
      ),
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
              style: _chromeStyle(band,
                  fontSize: 15, fontWeight: FontWeight.w500),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildEndingSection(QuestSegment segment, AgeBandThemeData band) {
    final tip = _activeQuest?.grownupTip;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Grown-up tip — soft callout shown at the end of every quest that
        // has one. Marked clearly as parent-facing so kids don't mistake it
        // for story content.
        if (tip != null && tip.isNotEmpty) ...[
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.white.withAlpha(20),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: Colors.white.withAlpha(50)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Text('💬', style: TextStyle(fontSize: 16)),
                    const SizedBox(width: 6),
                    Text(
                      'For a grown-up to ask',
                      style: _chromeStyle(band,
                          color: Colors.white60,
                          fontSize: 11,
                          fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  _interpolate(tip),
                  style: GoogleFonts.merriweather(
                    color: Colors.white.withAlpha(220),
                    fontSize: 14,
                    fontStyle: FontStyle.italic,
                    height: 1.5,
                  ),
                ),
              ],
            ),
          ),
        ],
        const SizedBox(height: 24),
        // Primary action: try a different path
        if (_segmentHistory.isNotEmpty) ...[
          FilledButton.icon(
            icon: const Icon(Icons.undo_rounded, size: 18),
            label: const Text('Want to try a different path?'),
            style: FilledButton.styleFrom(
              backgroundColor: band.accent,
              foregroundColor: Colors.black87,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
            onPressed: _rewind,
          ),
          const SizedBox(height: 10),
        ],
        // Secondary actions
        OutlinedButton.icon(
          icon: Icon(_isSprout ? Icons.cloud : Icons.explore_rounded, size: 18),
          label: Text(_isSprout ? 'Pick another cloud' : 'Try another quest'),
          style: OutlinedButton.styleFrom(
            foregroundColor: Colors.white70,
            side: BorderSide(color: Colors.white.withAlpha(60)),
            padding: const EdgeInsets.symmetric(vertical: 12),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          onPressed: () {
            // Sprout: back out of the cloud's quest list AND clear the cloud
            // so they land back on the 4-cloud entry grid.
            if (_isSprout) {
              setState(() => _selectedCloud = null);
            }
            _resetToSelector();
          },
        ),
        const SizedBox(height: 8),
        TextButton(
          onPressed: () {
            AppTtsService.instance.stop();
            Navigator.of(context).pop();
          },
          child: Text(
            'Done',
            style: _chromeStyle(band, color: Colors.white54, fontSize: 14),
          ),
        ),
      ],
    );
  }
}

// ── Sprout Cloud display metadata ───────────────────────────────────────────
//
// UI-side mapping for the SproutCloud enum. Lives here (not in life_quest_data)
// so the data layer doesn't have to import Flutter material.

extension _SproutCloudDisplay on SproutCloud {
  String get displayName {
    switch (this) {
      case SproutCloud.sunny:  return 'Sunny Cloud';
      case SproutCloud.rain:   return 'Rain Cloud';
      case SproutCloud.storm:  return 'Storm Cloud';
      case SproutCloud.wobbly: return 'Wobbly Cloud';
    }
  }

  /// File name (no extension) under assets/images/feelings/sprout/.
  /// Reuses the existing per-feeling face images.
  String get assetName {
    switch (this) {
      case SproutCloud.sunny:  return 'happy';
      case SproutCloud.rain:   return 'sad';
      case SproutCloud.storm:  return 'mad';
      case SproutCloud.wobbly: return 'scared';
    }
  }

  /// Tint used for the cloud card's gradient + border.
  Color get tintColor {
    switch (this) {
      case SproutCloud.sunny:  return const Color(0xFFFFCB47); // warm yellow
      case SproutCloud.rain:   return const Color(0xFF6FA8DC); // soft blue
      case SproutCloud.storm:  return const Color(0xFFE57373); // dusty red
      case SproutCloud.wobbly: return const Color(0xFFB39DDB); // pale lavender
    }
  }

  /// Fallback emoji shown if the asset image fails to load.
  String get fallbackEmoji {
    switch (this) {
      case SproutCloud.sunny:  return '☀️';
      case SproutCloud.rain:   return '🌧️';
      case SproutCloud.storm:  return '⛈️';
      case SproutCloud.wobbly: return '🌫️';
    }
  }
}
