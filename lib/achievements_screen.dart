import 'package:flutter/material.dart';

import 'models/achievement.dart';
import 'services/achievement_service.dart';

class AchievementsScreen extends StatefulWidget {
  const AchievementsScreen({super.key});

  @override
  State<AchievementsScreen> createState() => _AchievementsScreenState();
}

class _AchievementsScreenState extends State<AchievementsScreen> {
  final AchievementService _service = AchievementService();

  bool _isLoading = true;
  String? _errorMessage;
  AchievementSummary? _summary;
  AchievementCategory? _activeFilter;
  List<AchievementProgress> _achievements = const <AchievementProgress>[];
  Set<AchievementType> _justUnlocked = const <AchievementType>{};

  @override
  void initState() {
    super.initState();
    _loadAchievements();
  }

  Future<void> _loadAchievements({bool showSpinner = true}) async {
    if (showSpinner) {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });
    }

    try {
      final achievements = await _service.getAllAchievements();
      final newTypes = achievements
          .where((item) => item.record.isNew)
          .map((item) => item.achievement.type)
          .toSet();

      final unlockedCount =
          achievements.where((item) => item.record.isUnlocked).length;
      final totalCount = achievements.length;
      final averageProgress = totalCount == 0
          ? 0.0
          : achievements
                  .map((item) => item.record.progress)
                  .fold<double>(0.0, (sum, value) => sum + value) /
              totalCount;

      final summary = AchievementSummary(
        totalCount: totalCount,
        unlockedCount: unlockedCount,
        newCount: newTypes.length,
        completionPercent: totalCount == 0 ? 0.0 : unlockedCount / totalCount,
        averageProgress: averageProgress,
      );

      if (newTypes.isNotEmpty) {
        await _service.markAchievementsViewed(newTypes);
      }

      if (!mounted) return;

      setState(() {
        _achievements = achievements
            .map(
              (item) => newTypes.contains(item.achievement.type)
                  ? item.copyWithRecord(
                      item.record.copyWith(isNew: false),
                    )
                  : item,
            )
            .toList();
        _summary = summary;
        _justUnlocked = newTypes;
        _isLoading = false;
        _errorMessage = null;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _errorMessage = 'Unable to load achievements right now.';
        _isLoading = false;
      });
    }
  }

  Future<void> _handleRefresh() async {
    await _loadAchievements(showSpinner: false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).pop(true),
        ),
        title: const Text('Achievements'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh',
            onPressed: () => _loadAchievements(),
          ),
        ],
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_errorMessage != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              _errorMessage!,
              style: const TextStyle(fontSize: 16),
            ),
            const SizedBox(height: 12),
            ElevatedButton(
              onPressed: () => _loadAchievements(),
              child: const Text('Try Again'),
            ),
          ],
        ),
      );
    }

    if (_achievements.isEmpty) {
      return const Center(
        child: Text('Start creating stories to unlock achievements!'),
      );
    }

    return RefreshIndicator(
      onRefresh: _handleRefresh,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final filtered = _filteredAchievements();
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              if (_summary != null) _buildSummaryCard(_summary!),
              _buildFilters(),
              const SizedBox(height: 16),
              _buildAchievementGrid(filtered, constraints.maxWidth),
            ],
          );
        },
      ),
    );
  }

  List<AchievementProgress> _filteredAchievements() {
    if (_activeFilter == null) return _achievements;
    return _achievements
        .where((item) => item.achievement.category == _activeFilter)
        .toList();
  }

  Widget _buildSummaryCard(AchievementSummary summary) {
    final completionPercent = (summary.completionPercent * 100).clamp(0, 100);
    final averageProgress = (summary.averageProgress * 100).clamp(0, 100);

    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      margin: const EdgeInsets.only(bottom: 18),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Theme.of(context)
                        .colorScheme
                        .primary
                        .withValues(alpha: 0.12),
                  ),
                  padding: const EdgeInsets.all(12),
                  child: Icon(
                    Icons.emoji_events,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${summary.unlockedCount}/${summary.totalCount} unlocked',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        summary.newCount > 0
                            ? '${summary.newCount} new badge(s)'
                            : 'No new badges right now',
                        style: TextStyle(
                          color: summary.newCount > 0
                              ? Colors.deepOrange
                              : Theme.of(context)
                                  .colorScheme
                                  .onSurface
                                  .withValues(alpha: 0.6),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),
            Text(
              'Overall progress',
              style: Theme.of(context)
                  .textTheme
                  .bodyMedium
                  ?.copyWith(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 6),
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: LinearProgressIndicator(
                minHeight: 10,
                value: summary.completionPercent.clamp(0.0, 1.0),
                backgroundColor: Theme.of(context)
                    .colorScheme
                    .surfaceContainerHighest
                    .withValues(alpha: 0.4),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '${completionPercent.toStringAsFixed(0)}% achievements unlocked • '
              '${averageProgress.toStringAsFixed(0)}% average progress',
              style: Theme.of(context)
                  .textTheme
                  .bodySmall
                  ?.copyWith(color: Theme.of(context).hintColor),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFilters() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          ChoiceChip(
            label: const Text('All'),
            selected: _activeFilter == null,
            onSelected: (_) => setState(() => _activeFilter = null),
          ),
          const SizedBox(width: 8),
          for (final category in AchievementCategory.values) ...[
            ChoiceChip(
              label: Text(category.label),
              selected: _activeFilter == category,
              onSelected: (_) => setState(() => _activeFilter = category),
            ),
            const SizedBox(width: 8),
          ],
        ],
      ),
    );
  }

  Widget _buildAchievementGrid(
    List<AchievementProgress> items,
    double maxWidth,
  ) {
    final crossAxisCount = maxWidth > 980
        ? 3
        : maxWidth > 640
            ? 2
            : 1;

    return GridView.builder(
      itemCount: items.length,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: crossAxisCount,
        crossAxisSpacing: 16,
        mainAxisSpacing: 16,
        childAspectRatio: 1.0,
      ),
      itemBuilder: (context, index) {
        final item = items[index];
        final highlightNew = _justUnlocked.contains(item.achievement.type);
        return _AchievementTile(
          progress: item,
          highlightNew: highlightNew,
          onTap: () => _showAchievementDetails(item, highlightNew),
        );
      },
    );
  }

  Future<void> _showAchievementDetails(
    AchievementProgress progress,
    bool highlightNew,
  ) {
    final achievement = progress.achievement;
    final record = progress.record;
    final unlocked = record.isUnlocked;
    final progressPercent = (record.progress * 100).clamp(0, 100);
    final unlockedDate = record.unlockedAt;
    final dateLabel = unlockedDate == null
        ? null
        : '${unlockedDate.month}/${unlockedDate.day}/${unlockedDate.year}';

    return showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (context) {
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: achievement.color.withValues(alpha: 0.2),
                    ),
                    padding: const EdgeInsets.all(12),
                    child: Icon(
                      achievement.icon,
                      color: achievement.color,
                      size: 32,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          achievement.name,
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          achievement.category.label,
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ],
                    ),
                  ),
                  _RarityChip(rarity: achievement.rarity),
                ],
              ),
              const SizedBox(height: 18),
              if (highlightNew)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.orangeAccent.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Text(
                    'Newly unlocked',
                    style: TextStyle(
                      color: Colors.orange,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              if (highlightNew) const SizedBox(height: 12),
              Text(
                achievement.description,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: 12),
              Text(
                'How to earn: ${achievement.criteria}',
                style: Theme.of(context)
                    .textTheme
                    .bodySmall
                    ?.copyWith(color: Theme.of(context).hintColor),
              ),
              const SizedBox(height: 20),
              if (unlocked) ...[
                Row(
                  children: [
                    const Icon(Icons.check_circle, color: Colors.green),
                    const SizedBox(width: 8),
                    Text(
                      dateLabel != null
                          ? 'Unlocked on $dateLabel'
                          : 'Unlocked',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                    ),
                  ],
                ),
              ] else ...[
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: LinearProgressIndicator(
                    value: record.progress.clamp(0.0, 1.0),
                    minHeight: 10,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Progress: ${record.currentValue}/${record.targetValue} '
                  '(${progressPercent.toStringAsFixed(0)}%)',
                  style: Theme.of(context)
                      .textTheme
                      .bodySmall
                      ?.copyWith(color: Theme.of(context).hintColor),
                ),
              ],
              const SizedBox(height: 12),
            ],
          ),
        );
      },
    );
  }
}

class _AchievementTile extends StatelessWidget {
  const _AchievementTile({
    required this.progress,
    required this.highlightNew,
    required this.onTap,
  });

  final AchievementProgress progress;
  final bool highlightNew;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final achievement = progress.achievement;
    final record = progress.record;
    final unlocked = record.isUnlocked;
    final rarityColor = achievement.rarity.color;

    final gradientColors = unlocked
        ? [
            rarityColor.withValues(alpha: 0.32),
            rarityColor.withValues(alpha: 0.18),
          ]
        : [
            Theme.of(context).colorScheme.surface,
            Theme.of(context)
                .colorScheme
                .surfaceContainerHighest
                .withValues(alpha: 0.6),
          ];

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: gradientColors,
          ),
          border: Border.all(
            color: unlocked
                ? rarityColor.withValues(alpha: 0.7)
                : Theme.of(context)
                    .dividerColor
                    .withValues(alpha: 0.4),
            width: 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black
                  .withValues(alpha: unlocked ? 0.18 : 0.08),
              blurRadius: 16,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        padding: const EdgeInsets.all(16),
        child: Stack(
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: unlocked
                        ? rarityColor.withValues(alpha: 0.18)
                        : Theme.of(context)
                            .colorScheme
                            .surfaceContainerHighest
                            .withValues(alpha: 0.4),
                  ),
                  padding: const EdgeInsets.all(12),
                  child: Icon(
                    achievement.icon,
                    color: unlocked
                        ? rarityColor.darken(0.1)
                        : Theme.of(context).iconTheme.color,
                    size: 32,
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  achievement.name,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: unlocked
                        ? Theme.of(context).colorScheme.onSurface
                        : Theme.of(context)
                            .colorScheme
                            .onSurface
                            .withValues(alpha: 0.9),
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  achievement.description,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context)
                      .textTheme
                      .bodySmall
                      ?.copyWith(height: 1.3),
                ),
                const Spacer(),
                if (record.isUnlocked)
                  Row(
                    children: const [
                      Icon(Icons.check_circle, color: Colors.green, size: 18),
                      SizedBox(width: 6),
                      Text(
                        'Unlocked',
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          color: Colors.green,
                        ),
                      ),
                    ],
                  )
                else
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(6),
                        child: LinearProgressIndicator(
                          minHeight: 8,
                          value: record.progress.clamp(0.0, 1.0),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        '${record.currentValue}/${record.targetValue}',
                        style: Theme.of(context)
                            .textTheme
                            .bodySmall
                            ?.copyWith(
                              fontWeight: FontWeight.w600,
                              color: Theme.of(context).hintColor,
                            ),
                      ),
                    ],
                  ),
              ],
            ),
            if (highlightNew)
              Positioned(
                top: 0,
                right: 0,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.deepOrangeAccent,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.deepOrangeAccent
                            .withValues(alpha: 0.4),
                        blurRadius: 8,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: const Text(
                    'NEW',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _RarityChip extends StatelessWidget {
  const _RarityChip({required this.rarity});

  final AchievementRarity rarity;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        color: rarity.color.withValues(alpha: 0.16),
        border: Border.all(color: rarity.color.withValues(alpha: 0.4)),
      ),
      child: Text(
        rarity.label,
        style: TextStyle(
          fontWeight: FontWeight.w600,
          color: rarity.color.darken(0.05),
        ),
      ),
    );
  }
}

extension on Color {
  Color darken(double amount) {
    final hsl = HSLColor.fromColor(this);
    final adjusted = hsl.withLightness(
      (hsl.lightness - amount).clamp(0.0, 1.0),
    );
    return adjusted.toColor();
  }
}
