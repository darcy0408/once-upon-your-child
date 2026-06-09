// lib/screens/life_quest_screen.dart
//
// Self-contained screen for playing pre-built Life Quest scenarios.
// No AI generation, no backend calls — reads from static quest data
// and renders an interactive choose-your-own-adventure experience.

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../data/coping_techniques.dart';
import '../data/life_quest_data.dart';
import '../services/app_tts_service.dart';
import '../theme/age_band_theme.dart';
import '../widgets/coping_practice_sheet.dart';
import '../widgets/crisis_resources_panel.dart';
import '../widgets/parent_sensitivity_interstitial.dart';

/// Quest ids that surface a calm crisis-resources panel at story start and
/// story end. Originally the peer-mental-health-crisis quest (F-09 / MT-159);
/// extended for the Adventurer "Standing On Your Own" tier-4 quests (MT-199)
/// that involve an unsafe adult, so a child always has a trusted-adult / help
/// off-ramp in view.
const Set<String> _crisisQuestIds = {
  'someone_needs_help',
  'the_ride_home',
  'the_secret',
  'the_offer',
};

/// SharedPreferences key prefix for "parent has already acknowledged the
/// sensitivity interstitial for this quest id" — MT-158 / F-08. Suffixed
/// with the quest id so each sensitive quest is acknowledged independently
/// (parent who said yes once shouldn't be re-prompted on a second open).
const String _sensitivityAckPrefix = 'life_quest.sensitivity_ack.';

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
    this.grownup = 'your grown-up',
    this.selectedEmotion,
  });

  final int childAge;
  final String childName;
  final String companionName;
  final String pronoun;
  final String pronounCap;
  final String possessive;

  /// Primary caregiver label (e.g. "Mommy", "Grandma"). Defaults to
  /// "your grown-up" when no Family info has been set in Parent Controls.
  final String grownup;

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
  /// Sprout-only: which animal friend the user tapped on the entry grid.
  /// Null = entry grid is showing. Non-null = filtered quest list for that friend.
  SproutFriend? _selectedFriend;

  /// MT-158 / F-08 — a sensitive quest the user has tapped but the parent
  /// hasn't acknowledged yet. Non-null = the interstitial is shown instead
  /// of the active quest or the selector. Cleared when the parent either
  /// taps "Start the story" (and we transition to active) or "Choose a
  /// different story" (and we drop back to the selector).
  LifeQuestScenario? _pendingSensitiveQuest;

  /// On for Sprout (3-5 can't read story prose), off otherwise (older kids
  /// can read at their own pace and may prefer silent reading).
  late bool _ttsEnabled;

  bool get _isSprout => ageBandFromAge(widget.childAge) == AgeBand.sprout;
  bool get _isExplorer => ageBandFromAge(widget.childAge) == AgeBand.explorer;
  bool get _isAdventurer =>
      ageBandFromAge(widget.childAge) == AgeBand.adventurer;

  /// Friends that have at least one Sprout quest. Empty friends (e.g. Sunny Pup
  /// while no happy stories exist) are hidden from the entry grid so a
  /// 4-year-old doesn't tap the brightest-looking option and hit a dead end.
  List<SproutFriend> get _activeFriends => SproutFriend.values
      .where((friend) => allLifeQuests.any((q) =>
          q.friend == friend && q.recommendedBands.contains(AgeBand.sprout)))
      .toList();

  @override
  void initState() {
    super.initState();
    _ttsEnabled = _isSprout;
    if (_isSprout && _activeQuest == null) {
      // After the friend grid is first painted, speak a welcome that names
      // each visible friend so non-readers know what they're choosing between.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        final names = _activeFriends.map((c) => c.displayName).join(', ');
        AppTtsService.instance.speak(
          'Tap a friend! $names.',
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
    var quests =
        allLifeQuests.where((q) => q.recommendedBands.contains(band)).toList();
    if (widget.selectedEmotion != null) {
      quests = quests
          .where((q) => q.emotions.contains(widget.selectedEmotion))
          .toList();
    }
    // Sprout: when a friend is selected, only show quests for that friend.
    if (_isSprout && _selectedFriend != null) {
      quests = quests.where((q) => q.friend == _selectedFriend).toList();
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
      grownup: widget.grownup,
    );
  }

  /// Quest-card entry point. Routes through the parent sensitivity
  /// interstitial (MT-158 / F-08) when the quest has sensitivity metadata
  /// AND the parent hasn't already acknowledged this quest id. Otherwise
  /// goes straight to the player.
  Future<void> _startQuest(LifeQuestScenario quest) async {
    if (quest.sensitivityTopics.isNotEmpty) {
      final acknowledged = await _hasAcknowledgedSensitivity(quest.id);
      if (!mounted) return;
      if (!acknowledged) {
        setState(() {
          _pendingSensitiveQuest = quest;
        });
        return;
      }
    }
    _beginQuest(quest);
  }

  /// Transition into the active quest, regardless of how we got here
  /// (direct start, or parent-acknowledged interstitial).
  void _beginQuest(LifeQuestScenario quest) {
    setState(() {
      _activeQuest = quest;
      _currentSegment = quest.segments[quest.startSegmentId];
      _segmentHistory.clear();
      _pendingSensitiveQuest = null;
    });
    _maybeSpeakSegment();
  }

  /// MT-158 — has the parent already cleared the interstitial for this
  /// quest id? Keyed per quest so different sensitive quests are
  /// acknowledged independently.
  Future<bool> _hasAcknowledgedSensitivity(String questId) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool('$_sensitivityAckPrefix$questId') ?? false;
  }

  /// MT-158 — persists the parent's "Start the story" tap for this quest id
  /// so a second open doesn't re-prompt. Best-effort; a SharedPreferences
  /// failure should NOT block the quest from starting.
  Future<void> _persistSensitivityAck(String questId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('$_sensitivityAckPrefix$questId', true);
    } catch (_) {
      // Persist failure is non-fatal — worst case the parent sees the
      // interstitial again on the next open. Don't block on it.
    }
  }

  /// Parent tapped "Start the story" on the interstitial. Persist the ack
  /// and transition into the quest.
  void _onSensitivityAccepted(LifeQuestScenario quest) {
    // Fire-and-forget the persist — we still want to start the quest even
    // if SharedPreferences is unhappy.
    _persistSensitivityAck(quest.id);
    _beginQuest(quest);
  }

  /// Parent tapped "Choose a different story" on the interstitial. Drop
  /// back to the selector without persisting (so the next open re-prompts,
  /// which is the desired behaviour).
  void _onSensitivityDeclined() {
    setState(() {
      _pendingSensitiveQuest = null;
    });
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

    // MT-158 / F-08 — the parent sensitivity interstitial takes the whole
    // screen surface (above the band gradient) when a sensitive quest has
    // been tapped but not yet acknowledged. Falls through to the normal
    // selector/player branches once cleared.
    Widget body;
    if (_pendingSensitiveQuest != null) {
      body = _buildSensitivityInterstitial(_pendingSensitiveQuest!);
    } else if (_activeQuest == null) {
      body = _buildQuestSelector(band);
    } else {
      body = _buildQuestPlayer(band);
    }

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
        // The interstitial owns its own SafeArea so it can place actions
        // flush to the bottom — the selector/player branches keep theirs.
        child: _pendingSensitiveQuest != null ? body : SafeArea(child: body),
      ),
    );
  }

  /// MT-158 / F-08 — wraps [ParentSensitivityInterstitial] with the two
  /// callbacks. Always available; only mounted when a sensitive quest has
  /// been tapped and the parent hasn't acknowledged it before.
  Widget _buildSensitivityInterstitial(LifeQuestScenario quest) {
    return ParentSensitivityInterstitial(
      questTitle: quest.title,
      topics: quest.sensitivityTopics,
      // parentNote is required to be non-null when topics.isNotEmpty per the
      // model docstring; defensive fallback covers the const-string case if
      // a future quest adds topics but forgets the note.
      parentNote: quest.parentNote ??
          'This quest deals with a sensitive theme. '
              'You may want to be nearby.',
      onStart: () => _onSensitivityAccepted(quest),
      onBack: _onSensitivityDeclined,
    );
  }

  // ── Quest Selector ────────────────────────────────────────────────────────

  Widget _buildQuestSelector(AgeBandThemeData band) {
    // Sprout entry: animal-friend grid first. Tap a friend → filtered quests.
    if (_isSprout && _selectedFriend == null) {
      return _buildSproutFriendGrid(band);
    }
    final quests = _matchingQuests;
    final isYoung = widget.childAge <= 8;
    final headerTitle =
        _isSprout ? _selectedFriend!.displayName : 'Pick Your Quest';
    return Column(
      children: [
        // Header
        Padding(
          padding: const EdgeInsets.fromLTRB(4, 8, 4, 0),
          child: Row(
            children: [
              IconButton(
                icon: Icon(
                  _isSprout ? Icons.arrow_back_ios_new_rounded : Icons.close,
                  color: Colors.white60,
                ),
                tooltip: _isSprout ? 'Back to friends' : null,
                onPressed: () {
                  if (_isSprout) {
                    setState(() => _selectedFriend = null);
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
            _isSprout ? "Tap a story you'd like to hear!" : _selectorSubtitle(),
            textAlign: TextAlign.center,
            style: _chromeStyle(band, color: Colors.white60, fontSize: 14),
          ),
        ),
        // Coping Toolbox — Explorer + Adventurer. Sprout has the friend picker
        // as its entry pattern; Creator+ get reframed-language techniques in
        // a future pass (current set is too cartoony for 12+).
        if (_isExplorer || _isAdventurer) _buildCopingToolbox(band),
        // Section header — only when the toolbox is above it — so the two
        // interaction modes don't read as one undivided list: calm-down tools
        // you *practice* vs. stories you *step into*.
        if ((_isExplorer || _isAdventurer) && quests.isNotEmpty)
          _buildStoriesHeader(band),
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
                      // grid to active friends, but keep a friendly message
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

  // ── Sprout Friend Grid ────────────────────────────────────────────────────

  /// 2×2 grid of animal friends. Each friend "guides" stories about one
  /// feeling family — Sunny Pup (happy), Rainy Bunny (sad), Roary Lion (mad),
  /// Shy Mouse (scared/shy). Friends with no Sprout quests are hidden from
  /// the grid so a 4-year-old doesn't hit a dead end.
  Widget _buildSproutFriendGrid(AgeBandThemeData band) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(4, 8, 4, 0),
          child: Row(
            children: [
              IconButton(
                icon: const Icon(Icons.close, color: Colors.white60),
                tooltip: 'Close',
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
            'Tap a friend!',
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
              children: _activeFriends
                  .map((friend) => _buildFriendCard(friend, band))
                  .toList(),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildFriendCard(SproutFriend friend, AgeBandThemeData band) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: () {
          AppTtsService.instance.speak(friend.displayName, rateScale: 0.65);
          setState(() => _selectedFriend = friend);
        },
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                friend.tintColor.withAlpha(60),
                friend.tintColor.withAlpha(20),
              ],
            ),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: friend.tintColor.withAlpha(120),
              width: 2,
            ),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Expanded(
                child: Image.asset(
                  'assets/images/feelings/sprout/${friend.assetName}.webp',
                  fit: BoxFit.contain,
                  errorBuilder: (_, __, ___) => Center(
                    child: Text(
                      friend.fallbackEmoji,
                      style: const TextStyle(fontSize: 64),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 6),
              Text(
                friend.displayName,
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
                  style:
                      _chromeStyle(band, color: Colors.white54, fontSize: 11),
                ),
              ],
            ),
          ),
          // Right-edge fade so the half-visible last tile reads as "there's
          // more to scroll" — kids don't reliably discover horizontal scroll,
          // and the toolbox has 6 techniques but only ~3 fit on a phone.
          SizedBox(
            // 112 (not 96): two-line technique names ("Dragon's Breath",
            // "Hot Cocoa Breath") need the extra vertical room since F-02
            // bumped the card label to maxLines: 2.
            height: 112,
            child: ShaderMask(
              shaderCallback: (bounds) => const LinearGradient(
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
                colors: [Colors.white, Colors.white, Colors.transparent],
                stops: [0.0, 0.86, 1.0],
              ).createShader(bounds),
              blendMode: BlendMode.dstIn,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 2),
                itemCount: allCopingTechniques.length,
                separatorBuilder: (_, __) => const SizedBox(width: 10),
                itemBuilder: (context, i) =>
                    _buildToolboxCard(allCopingTechniques[i], band),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Section label that frames the quest list as a distinct mode from the
  /// coping toolbox above it. Mirrors the toolbox's label row so the two
  /// zones read as siblings: "tools to practice" then "stories to step into".
  Widget _buildStoriesHeader(AgeBandThemeData band) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 4, 16, 0),
      child: Row(
        children: [
          const Text('📖', style: TextStyle(fontSize: 16)),
          const SizedBox(width: 6),
          Text(
            'Stories to practice',
            style: _chromeStyle(band,
                color: Colors.white, fontSize: 14, fontWeight: FontWeight.w700),
          ),
          const SizedBox(width: 8),
          Text(
            '— tap one to step in',
            style: _chromeStyle(band, color: Colors.white54, fontSize: 11),
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
              technique.nameForAge(widget.childAge),
              textAlign: TextAlign.center,
              // Two lines so longer names ("Dragon's Breath") don't truncate
              // to "Dragon's Bre…" — reads as broken to a 9-year-old.
              maxLines: 2,
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
          onTap: () {
            _startQuest(quest);
          },
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
                  _ttsEnabled
                      ? Icons.volume_up_rounded
                      : Icons.volume_off_rounded,
                  color: Colors.white60,
                ),
                tooltip: _ttsEnabled ? 'Mute narration' : 'Unmute narration',
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
                // Story-start crisis resources — MT-159 / F-09. Only the
                // peer-mental-health-crisis quest, and only on its first
                // segment before any choice has been made.
                if (_crisisQuestIds.contains(_activeQuest!.id) &&
                    _segmentHistory.isEmpty &&
                    segment.id == _activeQuest!.startSegmentId) ...[
                  const CrisisResourcesPanel(),
                  const SizedBox(height: 20),
                ],
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
    // Sprouts get the active quest's animal friend as a breathing buddy.
    // Older bands keep the abstract orb (passing null here).
    final buddy = _isSprout ? _activeQuest?.friend : null;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => CopingPracticeSheet.show(
          context,
          technique: technique,
          buddy: buddy,
        ),
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
                      '${technique.nameForAge(widget.childAge)} — ${technique.tagline}',
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
              style:
                  _chromeStyle(band, fontSize: 15, fontWeight: FontWeight.w500),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildEndingSection(QuestSegment segment, AgeBandThemeData band) {
    final tip = _activeQuest?.grownupTip;
    final showCrisisResources =
        _activeQuest != null && _crisisQuestIds.contains(_activeQuest!.id);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Story-end crisis resources — MT-159 / F-09. Rendered above the
        // grown-up tip so the reader sees support options before the
        // parent-facing callout. Only on the peer-mental-health-crisis quest.
        if (showCrisisResources) ...[
          const SizedBox(height: 8),
          const CrisisResourcesPanel(),
        ],
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
                      band.band.isMature
                          ? 'To reflect on'
                          : 'For a grown-up to ask',
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
          icon: Icon(_isSprout ? Icons.pets_rounded : Icons.explore_rounded,
              size: 18),
          label: Text(_isSprout ? 'Pick another friend' : 'Try another quest'),
          style: OutlinedButton.styleFrom(
            foregroundColor: Colors.white70,
            side: BorderSide(color: Colors.white.withAlpha(60)),
            padding: const EdgeInsets.symmetric(vertical: 12),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          onPressed: () {
            // Sprout: back out of the friend's quest list AND clear the
            // selection so they land back on the 4-friend entry grid.
            if (_isSprout) {
              setState(() => _selectedFriend = null);
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

// ── Sprout Friend display metadata ──────────────────────────────────────────
//
// UI-side mapping for the SproutFriend enum. Lives here (not in life_quest_data)
// so the data layer doesn't have to import Flutter material.

extension _SproutFriendDisplay on SproutFriend {
  String get displayName {
    switch (this) {
      case SproutFriend.pup:
        return 'Sunny Pup';
      case SproutFriend.bunny:
        return 'Rainy Bunny';
      case SproutFriend.lion:
        return 'Roary Lion';
      case SproutFriend.mouse:
        return 'Shy Mouse';
    }
  }

  /// File name (no extension) under assets/images/feelings/sprout/.
  /// Maps each friend to its emotion-keyed art asset.
  String get assetName {
    switch (this) {
      case SproutFriend.pup:
        return 'happy';
      case SproutFriend.bunny:
        return 'sad';
      case SproutFriend.lion:
        return 'mad';
      case SproutFriend.mouse:
        return 'scared';
    }
  }

  /// Tint used for the friend card's gradient + border.
  Color get tintColor {
    switch (this) {
      case SproutFriend.pup:
        return const Color(0xFFFFCB47); // warm yellow
      case SproutFriend.bunny:
        return const Color(0xFF8FB8E8); // soft sky blue
      case SproutFriend.lion:
        return const Color(0xFFFFA07A); // warm coral
      case SproutFriend.mouse:
        return const Color(0xFFB39DDB); // pale lavender
    }
  }

  /// Fallback emoji shown if the asset image fails to load.
  String get fallbackEmoji {
    switch (this) {
      case SproutFriend.pup:
        return '🐶';
      case SproutFriend.bunny:
        return '🐰';
      case SproutFriend.lion:
        return '🦁';
      case SproutFriend.mouse:
        return '🐭';
    }
  }
}
