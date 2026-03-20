// lib/screens/feelings_garden_screen.dart
//
// Feelings Garden — optional emotional literacy screen.
// Three age-adaptive zones shown based on character age / age band:
//   Zone 1 (all ages):  How Big Is My Feeling  — intensity picker
//   Zone 2 (6+):        Feelings Explorer       — drill core → secondary → tertiary
//   Zone 3 (8+):        My Feelings Journal     — recent entries list

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../feelings_wheel_data.dart';
import '../theme/age_band_theme.dart';
import '../widgets/feelings_cloud_picker.dart';

class FeelingsGardenScreen extends StatefulWidget {
  final int childAge;

  const FeelingsGardenScreen({super.key, required this.childAge});

  @override
  State<FeelingsGardenScreen> createState() => _FeelingsGardenScreenState();
}

class _FeelingsGardenScreenState extends State<FeelingsGardenScreen>
    with SingleTickerProviderStateMixin {
  // Zone 1 state
  CoreEmotion? _selectedCore;
  double _intensity = 3.0; // 1–5

  // Zone 2 state
  SecondaryFeeling? _selectedSecondary;
  String? _selectedTertiary;

  // Zone 3 state (journal)
  List<_JournalEntry> _journal = [];

  late final TabController _tabController;

  @override
  void initState() {
    super.initState();
    final tabCount = widget.childAge >= 8 ? 3 : (widget.childAge >= 6 ? 2 : 1);
    _tabController = TabController(length: tabCount, vsync: this);
    _loadJournal();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  // ── Journal persistence ──────────────────────────────────────────────────

  Future<void> _loadJournal() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getStringList('feelings_journal') ?? [];
    setState(() {
      _journal = raw
          .map((e) => _JournalEntry.fromJson(jsonDecode(e)))
          .toList()
          .reversed
          .toList();
    });
  }

  Future<void> _saveToJournal() async {
    if (_selectedCore == null) return;
    final entry = _JournalEntry(
      coreName: _selectedCore!.name,
      coreEmoji: _selectedCore!.emoji,
      secondaryName: _selectedSecondary?.name,
      tertiaryName: _selectedTertiary,
      intensity: _intensity.round(),
      timestamp: DateTime.now(),
    );
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getStringList('feelings_journal') ?? [];
    raw.add(jsonEncode(entry.toJson()));
    // keep max 60 entries
    final trimmed = raw.length > 60 ? raw.sublist(raw.length - 60) : raw;
    await prefs.setStringList('feelings_journal', trimmed);
    setState(() => _journal = [entry, ..._journal].take(60).toList());
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Feeling saved to your journal 🌱'),
          duration: Duration(seconds: 2),
        ),
      );
    }
  }

  // ── Build ────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final band = Theme.of(context).extension<AgeBandThemeData>() ?? explorerTheme;
    final tabCount = widget.childAge >= 8 ? 3 : (widget.childAge >= 6 ? 2 : 1);

    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [band.gradientStart, band.gradientMid, band.gradientEnd],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              _buildHeader(band),
              if (tabCount > 1)
                _buildTabBar(band, tabCount)
              else
                const SizedBox(height: 8),
              Expanded(
                child: tabCount > 1
                    ? TabBarView(
                        controller: _tabController,
                        children: [
                          _HowBigZone(
                            band: band,
                            childAge: widget.childAge,
                            selectedCore: _selectedCore,
                            intensity: _intensity,
                            onCoreSelected: (c) =>
                                setState(() {
                                  _selectedCore = c;
                                  _selectedSecondary = null;
                                  _selectedTertiary = null;
                                }),
                            onIntensityChanged: (v) =>
                                setState(() => _intensity = v),
                          ),
                          // Zone 2: cloud picker (replaces pill-chip explorer)
                          _GardenExplorerZone(
                            band: band,
                            childAge: widget.childAge,
                            selectedCore: _selectedCore,
                            selectedSecondary: _selectedSecondary,
                            selectedTertiary: _selectedTertiary,
                            onSelected: (sel) => setState(() {
                              _selectedCore = sel.core;
                              _selectedSecondary = sel.secondary;
                              _selectedTertiary = sel.tertiary;
                            }),
                          ),
                          if (tabCount == 3)
                            _JournalZone(
                              band: band,
                              journal: _journal,
                            ),
                        ],
                      )
                    : _HowBigZone(
                        band: band,
                        childAge: widget.childAge,
                        selectedCore: _selectedCore,
                        intensity: _intensity,
                        onCoreSelected: (c) =>
                            setState(() {
                              _selectedCore = c;
                              _selectedSecondary = null;
                              _selectedTertiary = null;
                            }),
                        onIntensityChanged: (v) =>
                            setState(() => _intensity = v),
                      ),
              ),
              if (_selectedCore != null) _buildSaveBar(band),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(AgeBandThemeData band) {
    final label = widget.childAge <= 5
        ? 'How Do You Feel?'
        : widget.childAge <= 8
            ? 'My Feelings Garden'
            : 'Feelings Garden';
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back, color: Colors.white),
            onPressed: () => Navigator.of(context).pop(),
          ),
          const Text('🌱', style: TextStyle(fontSize: 22)),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                fontFamily: band.uiFontFamily,
                fontSize: band.headingScale * 18,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _tab1Label() {
    if (widget.childAge >= 15) return 'Landscape';
    if (widget.childAge >= 12) return 'Mood';
    if (widget.childAge >= 9) return 'Mood Check';
    return 'How Big Is My Feeling';
  }

  String _tab2Label() {
    if (widget.childAge >= 15) return 'Explore';
    if (widget.childAge >= 12) return 'Explore';
    if (widget.childAge >= 9) return 'Mood Explorer';
    return 'Feelings Explorer';
  }

  String _tab3Label() {
    if (widget.childAge >= 15) return 'Reflections';
    if (widget.childAge >= 12) return 'Journal';
    if (widget.childAge >= 9) return 'My Journal';
    return 'My Feelings Journal';
  }

  Widget _buildTabBar(AgeBandThemeData band, int tabCount) {
    final labels = [_tab1Label(), _tab2Label(), _tab3Label()];
    final icons = [Icons.favorite_rounded, Icons.explore_rounded, Icons.menu_book_rounded];
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(30),
      ),
      child: TabBar(
        controller: _tabController,
        indicator: BoxDecoration(
          color: band.primary,
          borderRadius: BorderRadius.circular(30),
        ),
        indicatorSize: TabBarIndicatorSize.tab,
        labelColor: Colors.white,
        unselectedLabelColor: Colors.white.withValues(alpha: 0.6),
        labelStyle: TextStyle(
          fontFamily: band.uiFontFamily,
          fontSize: 12,
          fontWeight: FontWeight.bold,
        ),
        tabs: List.generate(tabCount, (i) => Tab(
          icon: Icon(icons[i], size: 18),
          text: labels[i],
        )),
      ),
    );
  }

  Widget _buildSaveBar(AgeBandThemeData band) {
    final feeling = _selectedTertiary ?? _selectedSecondary?.name ?? _selectedCore?.name ?? '';
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
      decoration: BoxDecoration(
        color: band.gradientEnd.withValues(alpha: 0.95),
        border: Border(top: BorderSide(color: Colors.white.withValues(alpha: 0.15))),
      ),
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            Text(
              _selectedCore!.emoji,
              style: const TextStyle(fontSize: 28),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                feeling.isNotEmpty ? 'Feeling $feeling' : 'Feeling ${_selectedCore!.name}',
                style: TextStyle(
                  color: Colors.white,
                  fontFamily: band.uiFontFamily,
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            if (widget.childAge >= 8)
              ElevatedButton.icon(
                onPressed: _saveToJournal,
                icon: const Icon(Icons.add_rounded, size: 18),
                label: const Text('Save'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: band.primary,
                  foregroundColor: Colors.white,
                  shape: const StadiumBorder(),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

// ── Zone 1: How Big Is My Feeling ───────────────────────────────────────────

class _HowBigZone extends StatelessWidget {
  final AgeBandThemeData band;
  final int childAge;
  final CoreEmotion? selectedCore;
  final double intensity;
  final ValueChanged<CoreEmotion> onCoreSelected;
  final ValueChanged<double> onIntensityChanged;

  const _HowBigZone({
    required this.band,
    required this.childAge,
    required this.selectedCore,
    required this.intensity,
    required this.onCoreSelected,
    required this.onIntensityChanged,
  });

  static const _sproutEmotions = [
    {'id': 'happy', 'emoji': '😊', 'label': 'Happy'},
    {'id': 'sad', 'emoji': '😢', 'label': 'Sad'},
    {'id': 'angry', 'emoji': '😠', 'label': 'Mad'},
    {'id': 'fearful', 'emoji': '😨', 'label': 'Scared'},
    {'id': 'surprised', 'emoji': '😲', 'label': 'Wow!'},
    {'id': 'bad', 'emoji': '🤢', 'label': 'Yucky'},
  ];

  @override
  Widget build(BuildContext context) {
    if (childAge <= 5) {
      return SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            _ZoneHeading(band: band, text: 'How are you feeling?'),
            const SizedBox(height: 20),
            Wrap(
              spacing: 16,
              runSpacing: 16,
              alignment: WrapAlignment.center,
              children: _sproutEmotions.map((e) {
                final isSelected = selectedCore?.id == e['id'];
                return GestureDetector(
                  onTap: () {
                    final core = FeelingsWheelData.coreEmotions
                        .firstWhere((c) => c.id == e['id'],
                            orElse: () => FeelingsWheelData.coreEmotions.first);
                    onCoreSelected(core);
                  },
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    width: 88,
                    height: 88,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: isSelected
                          ? Colors.amber.withValues(alpha: 0.8)
                          : Colors.white.withValues(alpha: 0.15),
                      border: Border.all(
                        color: isSelected
                            ? Colors.amber
                            : Colors.white.withValues(alpha: 0.3),
                        width: isSelected ? 3 : 1.5,
                      ),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(e['emoji'] as String,
                            style: const TextStyle(fontSize: 36)),
                        const SizedBox(height: 2),
                        Text(
                          e['label'] as String,
                          style: const TextStyle(
                              color: Colors.white,
                              fontSize: 11,
                              fontWeight: FontWeight.bold),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),
          ],
        ),
      );
    }
    final cores = FeelingsWheelData.coreEmotions;
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _ZoneHeading(band: band, text: 'What are you feeling?'),
          const SizedBox(height: 16),
          // Core emotion grid
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              mainAxisSpacing: 12,
              crossAxisSpacing: 12,
              childAspectRatio: 1.0,
            ),
            itemCount: cores.length,
            itemBuilder: (_, i) {
              final core = cores[i];
              final isSelected = selectedCore?.id == core.id;
              return GestureDetector(
                onTap: () => onCoreSelected(core),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? (core.color ?? band.primary)
                        : Colors.white.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(band.cardRadiusBase),
                    border: Border.all(
                      color: isSelected
                          ? Colors.white
                          : Colors.white.withValues(alpha: 0.3),
                      width: isSelected ? 2.5 : 1,
                    ),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(core.emoji, style: const TextStyle(fontSize: 32)),
                      const SizedBox(height: 4),
                      Text(
                        core.name,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Colors.white,
                          fontFamily: band.uiFontFamily,
                          fontSize: 12,
                          fontWeight: isSelected
                              ? FontWeight.bold
                              : FontWeight.normal,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
          if (selectedCore != null) ...[
            const SizedBox(height: 24),
            _ZoneHeading(band: band, text: 'How big is this feeling?'),
            const SizedBox(height: 8),
            _IntensitySlider(
              band: band,
              value: intensity,
              onChanged: onIntensityChanged,
            ),
          ],
        ],
      ),
    );
  }
}

class _IntensitySlider extends StatelessWidget {
  final AgeBandThemeData band;
  final double value;
  final ValueChanged<double> onChanged;

  const _IntensitySlider({
    required this.band,
    required this.value,
    required this.onChanged,
  });

  static const List<String> _labels = ['Tiny', 'Small', 'Medium', 'Big', 'Huge!'];
  static const List<String> _emojis = ['🌱', '🌿', '🌳', '🌊', '🌋'];

  @override
  Widget build(BuildContext context) {
    final idx = (value.round() - 1).clamp(0, 4);
    return Column(
      children: [
        Text(
          '${_emojis[idx]} ${_labels[idx]}',
          style: TextStyle(
            color: Colors.white,
            fontFamily: band.uiFontFamily,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        SliderTheme(
          data: SliderThemeData(
            activeTrackColor: band.primary,
            inactiveTrackColor: Colors.white.withValues(alpha: 0.25),
            thumbColor: Colors.white,
            overlayColor: band.primary.withValues(alpha: 0.25),
            valueIndicatorColor: band.primary,
          ),
          child: Slider(
            value: value,
            min: 1,
            max: 5,
            divisions: 4,
            label: _labels[idx],
            onChanged: onChanged,
          ),
        ),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: List.generate(5, (i) => Text(
            _emojis[i],
            style: const TextStyle(fontSize: 18),
          )),
        ),
      ],
    );
  }
}

// ── Zone 2: Feelings Explorer (wraps FeelingsCloudPicker) ────────────────────

class _GardenExplorerZone extends StatefulWidget {
  final AgeBandThemeData band;
  final int childAge;
  final CoreEmotion? selectedCore;
  final SecondaryFeeling? selectedSecondary;
  final String? selectedTertiary;
  final ValueChanged<FeelingSelection> onSelected;

  const _GardenExplorerZone({
    required this.band,
    required this.childAge,
    required this.selectedCore,
    required this.selectedSecondary,
    required this.selectedTertiary,
    required this.onSelected,
  });

  @override
  State<_GardenExplorerZone> createState() => _GardenExplorerZoneState();
}

class _GardenExplorerZoneState extends State<_GardenExplorerZone> {
  FeelingSelection? _lastSelection;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: FeelingsCloudPicker(
            childAge: widget.childAge,
            onSelected: (sel) {
              setState(() => _lastSelection = sel);
              widget.onSelected(sel);
            },
          ),
        ),
        if (_lastSelection != null && _lastSelection!.tertiary != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: _CopingCard(
              band: widget.band,
              childAge: widget.childAge,
              coreName: _lastSelection!.core.name,
              secondaryName: _lastSelection!.secondary?.name ?? '',
              tertiaryName: _lastSelection!.tertiary!,
            ),
          ),
      ],
    );
  }
}

class _CopingCard extends StatelessWidget {
  final AgeBandThemeData band;
  final int childAge;
  final String coreName;
  final String secondaryName;
  final String tertiaryName;

  const _CopingCard({
    required this.band,
    required this.childAge,
    required this.coreName,
    required this.secondaryName,
    required this.tertiaryName,
  });

  @override
  Widget build(BuildContext context) {
    // Look up richer coping strategies from the centralized FeelingDetails library.
    final detail = FeelingDetails.forFeeling(SelectedFeeling(
      core: coreName,
      secondary: secondaryName,
      tertiary: tertiaryName,
      emoji: '',
      eyeType: 'Happy',
      mouthType: 'Smile',
      color: Colors.transparent,
    ));

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: band.accent.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(band.cardRadiusBase),
        border: Border.all(color: band.accent.withValues(alpha: 0.5)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(detail.emoji ?? '💡', style: const TextStyle(fontSize: 24)),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Try this',
                  style: TextStyle(
                    fontFamily: band.uiFontFamily,
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 4),
                // Show the first coping strategy (or joined list if appropriate)
                Text(
                  detail.coping.first,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.9),
                    fontSize: 14,
                  ),
                ),
                if (detail.description.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text(
                    detail.description,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.6),
                      fontSize: 12,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Zone 3: My Feelings Journal ──────────────────────────────────────────────

class _JournalZone extends StatelessWidget {
  final AgeBandThemeData band;
  final List<_JournalEntry> journal;

  const _JournalZone({required this.band, required this.journal});

  @override
  Widget build(BuildContext context) {
    if (journal.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('📔', style: TextStyle(fontSize: 48)),
            const SizedBox(height: 12),
            Text(
              'No entries yet.\nExplore your feelings and save them here!',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.75),
                fontSize: 15,
              ),
            ),
          ],
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: journal.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (_, i) {
        final entry = journal[i];
        final dateStr = _formatDate(entry.timestamp);
        final feelingLabel = entry.tertiaryName ??
            entry.secondaryName ??
            entry.coreName;
        return Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(band.cardRadiusBase),
          ),
          child: Row(
            children: [
              Text(entry.coreEmoji, style: const TextStyle(fontSize: 28)),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      feelingLabel,
                      style: TextStyle(
                        color: Colors.white,
                        fontFamily: band.uiFontFamily,
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      dateStr,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.6),
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              _IntensityDots(intensity: entry.intensity),
            ],
          ),
        );
      },
    );
  }

  static String _formatDate(DateTime dt) {
    final now = DateTime.now();
    final diff = now.difference(dt);
    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inHours < 1) return '${diff.inMinutes}m ago';
    if (diff.inDays < 1) return '${diff.inHours}h ago';
    if (diff.inDays == 1) return 'Yesterday';
    return '${dt.day}/${dt.month}/${dt.year}';
  }
}

class _IntensityDots extends StatelessWidget {
  final int intensity;
  const _IntensityDots({required this.intensity});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(5, (i) => Container(
        width: 8,
        height: 8,
        margin: const EdgeInsets.only(left: 3),
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: i < intensity
              ? Colors.white
              : Colors.white.withValues(alpha: 0.25),
        ),
      )),
    );
  }
}

// ── Shared widgets ───────────────────────────────────────────────────────────

class _ZoneHeading extends StatelessWidget {
  final AgeBandThemeData band;
  final String text;
  const _ZoneHeading({required this.band, required this.text});

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: TextStyle(
        fontFamily: band.uiFontFamily,
        fontSize: band.headingScale * 16,
        fontWeight: FontWeight.bold,
        color: Colors.white,
      ),
    );
  }
}

// ── Data model ───────────────────────────────────────────────────────────────

class _JournalEntry {
  final String coreName;
  final String coreEmoji;
  final String? secondaryName;
  final String? tertiaryName;
  final int intensity;
  final DateTime timestamp;

  _JournalEntry({
    required this.coreName,
    required this.coreEmoji,
    this.secondaryName,
    this.tertiaryName,
    required this.intensity,
    required this.timestamp,
  });

  Map<String, dynamic> toJson() => {
        'coreName': coreName,
        'coreEmoji': coreEmoji,
        'secondaryName': secondaryName,
        'tertiaryName': tertiaryName,
        'intensity': intensity,
        'timestamp': timestamp.toIso8601String(),
      };

  factory _JournalEntry.fromJson(Map<String, dynamic> j) => _JournalEntry(
        coreName: j['coreName'] ?? '',
        coreEmoji: j['coreEmoji'] ?? '😐',
        secondaryName: j['secondaryName'],
        tertiaryName: j['tertiaryName'],
        intensity: j['intensity'] ?? 3,
        timestamp: DateTime.tryParse(j['timestamp'] ?? '') ?? DateTime.now(),
      );
}
