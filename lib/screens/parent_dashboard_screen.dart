import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models.dart';
import '../storage_service.dart';
import '../theme/app_theme.dart';
import 'child_profile_manager_screen.dart';

// ─── Local data model ────────────────────────────────────────────────────────

class _FeelingRecord {
  final String emoji;
  final String name;
  final int intensity;
  final DateTime timestamp;

  _FeelingRecord({
    required this.emoji,
    required this.name,
    required this.intensity,
    required this.timestamp,
  });

  factory _FeelingRecord.fromJson(Map<String, dynamic> j) => _FeelingRecord(
        emoji: j['coreEmoji'] ?? '😐',
        name: j['coreName'] ?? 'Unknown',
        intensity: (j['intensity'] as num?)?.toInt() ?? 3,
        timestamp: DateTime.tryParse(j['timestamp'] ?? '') ?? DateTime.now(),
      );
}

// ─── Screen ──────────────────────────────────────────────────────────────────

class ParentDashboardScreen extends StatefulWidget {
  const ParentDashboardScreen({super.key});

  @override
  State<ParentDashboardScreen> createState() => _ParentDashboardScreenState();
}

class _ParentDashboardScreenState extends State<ParentDashboardScreen> {
  bool _loading = true;
  List<SavedStory> _stories = [];
  List<_FeelingRecord> _feelings = [];

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final storiesFuture = StorageService().loadStories();
    final prefsFuture = SharedPreferences.getInstance();

    final results = await Future.wait([storiesFuture, prefsFuture]);
    final allStories = results[0] as List<SavedStory>;
    final prefs = results[1] as SharedPreferences;

    final cutoff30 = DateTime.now().subtract(const Duration(days: 30));
    final rawJournal = prefs.getStringList('feelings_journal') ?? [];

    final feelings = rawJournal
        .map((s) {
          try {
            return _FeelingRecord.fromJson(
                jsonDecode(s) as Map<String, dynamic>);
          } catch (_) {
            return null;
          }
        })
        .whereType<_FeelingRecord>()
        .where((f) => f.timestamp.isAfter(cutoff30))
        .toList()
      ..sort((a, b) => b.timestamp.compareTo(a.timestamp));

    setState(() {
      _stories =
          allStories.where((s) => s.createdAt.isAfter(cutoff30)).toList()
            ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
      _feelings = feelings;
      _loading = false;
    });
  }

  // ── helpers ────────────────────────────────────────────────────────────────

  String _topEmotion() {
    if (_feelings.isEmpty) return '–';
    final freq = <String, int>{};
    for (final f in _feelings) {
      freq[f.name] = (freq[f.name] ?? 0) + 1;
    }
    return freq.entries.reduce((a, b) => a.value >= b.value ? a : b).key;
  }

  String _relativeDate(DateTime dt) {
    final now = DateTime.now();
    final diff = now.difference(dt).inDays;
    if (diff == 0) return 'Today';
    if (diff == 1) return 'Yesterday';
    return '$diff days ago';
  }

  Color _emotionColor(String name) {
    switch (name.toLowerCase()) {
      case 'happy':
      case 'joy':
        return Colors.amber;
      case 'sad':
      case 'sadness':
        return Colors.blue;
      case 'angry':
      case 'anger':
        return Colors.red;
      case 'scared':
      case 'fear':
        return Colors.orange;
      case 'calm':
      case 'peace':
        return Colors.teal;
      default:
        return AppColors.primary;
    }
  }

  // ── build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF120226),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text(
          'Parent Dashboard',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w700,
            fontSize: 20,
          ),
        ),
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          IconButton(
            icon: const Icon(Icons.people_rounded, color: Colors.white),
            tooltip: 'Manage Profiles',
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(
                  builder: (_) => const ChildProfileManagerScreen()),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.refresh_rounded, color: Colors.white70),
            tooltip: 'Refresh dashboard',
            onPressed: () {
              setState(() => _loading = true);
              _loadData();
            },
          ),
        ],
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF120226), Color(0xFF2A0A4E)],
          ),
        ),
        child: _loading
            ? const Center(
                child: CircularProgressIndicator(color: AppColors.primary))
            : SingleChildScrollView(
                padding: const EdgeInsets.all(AppSpacing.md),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildSummaryRow(),
                    const SizedBox(height: AppSpacing.lg),
                    _buildRecentStories(),
                    const SizedBox(height: AppSpacing.lg),
                    _buildEmotionTrends(),
                    const SizedBox(height: AppSpacing.lg),
                    _buildTimeline(),
                    const SizedBox(height: AppSpacing.xl),
                  ],
                ),
              ),
      ),
    );
  }

  // ── Section 1 — Summary Row ────────────────────────────────────────────────

  Widget _buildSummaryRow() {
    return Row(
      children: [
        Expanded(child: _statChip('📚', '${_stories.length}', 'Stories')),
        const SizedBox(width: AppSpacing.sm),
        Expanded(child: _statChip('🌱', '${_feelings.length}', 'Check-ins')),
        const SizedBox(width: AppSpacing.sm),
        Expanded(child: _statChip('❤️', _topEmotion(), 'Top Feeling')),
      ],
    );
  }

  Widget _statChip(String emoji, String value, String label) {
    return Card(
      color: AppColors.primary.withValues(alpha: 0.2),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.md),
        side: BorderSide(
            color: AppColors.primary.withValues(alpha: 0.4), width: 1),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(
            vertical: AppSpacing.sm, horizontal: AppSpacing.xs),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(emoji, style: const TextStyle(fontSize: 22)),
            const SizedBox(height: 4),
            Text(
              value,
              style: const TextStyle(
                color: AppColors.gold,
                fontSize: 18,
                fontWeight: FontWeight.w700,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            Text(
              label,
              style: const TextStyle(color: Colors.white60, fontSize: 11),
            ),
          ],
        ),
      ),
    );
  }

  // ── Section 2 — Recent Stories ────────────────────────────────────────────

  Widget _buildRecentStories() {
    final recent = _stories.take(7).toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionTitle('📖 Recent Stories'),
        const SizedBox(height: AppSpacing.sm),
        if (recent.isEmpty)
          _emptyState('No stories in the last 30 days yet.')
        else
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: recent.length,
            separatorBuilder: (_, __) =>
                const SizedBox(height: AppSpacing.xs),
            itemBuilder: (_, i) => _storyCard(recent[i]),
          ),
      ],
    );
  }

  Widget _storyCard(SavedStory story) {
    final typeIcons = [
      if (story.isInteractive) '🎭',
      if (story.isRhyming) '🎵',
      if (!story.isInteractive && !story.isRhyming) '📖',
    ].join(' ');

    return Card(
      color: Colors.white.withValues(alpha: 0.07),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.md),
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.sm),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    story.title,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withValues(alpha: 0.3),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          story.theme,
                          style: const TextStyle(
                              color: Colors.white70, fontSize: 10),
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(typeIcons,
                          style: const TextStyle(fontSize: 12)),
                    ],
                  ),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  _relativeDate(story.createdAt),
                  style:
                      const TextStyle(color: Colors.white54, fontSize: 11),
                ),
                if (story.totalWords != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    '${story.totalWords} words',
                    style: const TextStyle(
                        color: AppColors.gold, fontSize: 11),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }

  // ── Section 3 — Emotion Trends ────────────────────────────────────────────

  Widget _buildEmotionTrends() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionTitle('🌈 Feelings This Month'),
        const SizedBox(height: AppSpacing.sm),
        if (_feelings.isEmpty)
          _emptyState(
              'No feelings check-ins yet.\nVisit the Feelings Garden to start!')
        else
          _buildBarChart(),
      ],
    );
  }

  Widget _buildBarChart() {
    final freq = <String, int>{};
    final emojiMap = <String, String>{};
    for (final f in _feelings) {
      freq[f.name] = (freq[f.name] ?? 0) + 1;
      emojiMap[f.name] = f.emoji;
    }

    final sorted = freq.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final top = sorted.take(6).toList();
    final maxCount = top.first.value;

    return LayoutBuilder(builder: (context, constraints) {
      final availableWidth = constraints.maxWidth;
      const labelWidth = 110.0;
      const countWidth = 30.0;
      final barMaxWidth = availableWidth - labelWidth - countWidth - 16;

      return Column(
        children: top.map((entry) {
          final barWidth = (entry.value / maxCount) * barMaxWidth;
          final color = _emotionColor(entry.key);
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 5),
            child: Row(
              children: [
                SizedBox(
                  width: labelWidth,
                  child: Text(
                    '${emojiMap[entry.key] ?? '😐'} ${entry.key}',
                    style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 13,
                        overflow: TextOverflow.ellipsis),
                    maxLines: 1,
                  ),
                ),
                Container(
                  width: barWidth.clamp(4.0, barMaxWidth),
                  height: 18,
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.75),
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  '${entry.value}',
                  style: const TextStyle(
                      color: Colors.white54,
                      fontSize: 12,
                      fontWeight: FontWeight.w600),
                ),
              ],
            ),
          );
        }).toList(),
      );
    });
  }

  // ── Section 4 — Timeline ──────────────────────────────────────────────────

  Widget _buildTimeline() {
    final cutoff14 = DateTime.now().subtract(const Duration(days: 14));

    // Merge stories and feelings into a single sorted list
    final events = <_TimelineEvent>[];
    for (final s in _stories.where((s) => s.createdAt.isAfter(cutoff14))) {
      events.add(_TimelineEvent(
        date: s.createdAt,
        label: '📚 Story: ${s.title}',
        emotionName: null,
      ));
    }
    for (final f in _feelings.where((f) => f.timestamp.isAfter(cutoff14))) {
      events.add(_TimelineEvent(
        date: f.timestamp,
        label: '🌱 Feeling: ${f.emoji} ${f.name}',
        emotionName: f.name,
      ));
    }
    events.sort((a, b) => b.date.compareTo(a.date));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionTitle('🗓 Story & Feeling Timeline'),
        const SizedBox(height: AppSpacing.sm),
        if (events.isEmpty)
          _emptyState('No activity in the last 14 days.')
        else
          ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: events.length,
            itemBuilder: (_, i) => _timelineRow(events[i]),
          ),
      ],
    );
  }

  Widget _timelineRow(_TimelineEvent event) {
    final dotColor = event.emotionName != null
        ? _emotionColor(event.emotionName!)
        : AppColors.primary;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          SizedBox(
            width: 80,
            child: Text(
              _relativeDate(event.date),
              style: const TextStyle(color: Colors.white38, fontSize: 11),
              textAlign: TextAlign.right,
            ),
          ),
          const SizedBox(width: 10),
          Container(
            width: 10,
            height: 10,
            decoration: BoxDecoration(
              color: dotColor,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              event.label,
              style: const TextStyle(color: Colors.white70, fontSize: 13),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  // ── Shared UI helpers ─────────────────────────────────────────────────────

  Widget _sectionTitle(String title) => Text(
        title,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 16,
          fontWeight: FontWeight.w700,
        ),
      );

  Widget _emptyState(String message) => Padding(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
        child: Text(
          message,
          style: const TextStyle(color: Colors.white38, fontSize: 13),
        ),
      );
}

// ─── Private helpers ──────────────────────────────────────────────────────────

class _TimelineEvent {
  final DateTime date;
  final String label;
  final String? emotionName;

  _TimelineEvent({
    required this.date,
    required this.label,
    required this.emotionName,
  });
}
