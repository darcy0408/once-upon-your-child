import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';

import 'models.dart';
import 'models/local/story_local.dart';
import 'providers/story_provider.dart';
import 'services/story_analytics.dart';
import 'story_result_screen.dart';

enum SortOption {
  newest,
  oldest,
  favoritesFirst,
}

final _showOnlyFavoritesProvider = StateProvider<bool>((ref) => false);
final _showOnlyInteractiveProvider = StateProvider<bool>((ref) => false);
final _selectedThemeFilterProvider = StateProvider<String>((ref) => 'All');
final _sortOptionProvider = StateProvider<SortOption>((ref) => SortOption.newest);

const List<String> _themes = [
  'All',
  'Adventure',
  'Friendship',
  'Magic',
  'Dragons',
  'Castles',
  'Unicorns',
  'Space',
  'Ocean',
  'Family',
  'Teamwork',
  'Courage',
];

class SavedStoriesScreen extends ConsumerWidget {
  const SavedStoriesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final storiesAsync = ref.watch(storyListProvider);
    final showOnlyFavorites = ref.watch(_showOnlyFavoritesProvider);
    final showOnlyInteractive = ref.watch(_showOnlyInteractiveProvider);
    final selectedTheme = ref.watch(_selectedThemeFilterProvider);
    final currentSort = ref.watch(_sortOptionProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('My Stories'),
        actions: [
          IconButton(
            icon: Icon(
              showOnlyFavorites ? Icons.favorite : Icons.favorite_border,
              color: showOnlyFavorites ? Colors.red : null,
            ),
            tooltip: showOnlyFavorites ? 'Show all stories' : 'Show favorites only',
            onPressed: () {
              ref.read(_showOnlyFavoritesProvider.notifier).state = !showOnlyFavorites;
            },
          ),
        ],
      ),
      body: storiesAsync.when(
        data: (stories) {
          final filteredStories = _applyFilters(
            stories,
            showOnlyFavorites: showOnlyFavorites,
            showOnlyInteractive: showOnlyInteractive,
            selectedThemeFilter: selectedTheme,
            currentSort: currentSort,
          );
          final favoriteCount = stories.where((s) => s.isFavorite).length;

          if (stories.isEmpty) {
            return const Center(child: Text('No stories saved yet.'));
          }

          return RefreshIndicator(
            onRefresh: () => _refreshStories(ref),
            child: ListView(
              padding: EdgeInsets.zero,
              children: [
                // Filter bar
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  color: Colors.grey.shade100,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Text('Theme:', style: TextStyle(fontWeight: FontWeight.w600)),
                          const SizedBox(width: 12),
                          Expanded(
                            child: SingleChildScrollView(
                              scrollDirection: Axis.horizontal,
                              child: Row(
                                children: _themes.map((theme) {
                                  final isSelected = selectedTheme == theme;
                                  return Padding(
                                    padding: const EdgeInsets.only(right: 8.0),
                                    child: FilterChip(
                                      label: Text(theme),
                                      selected: isSelected,
                                      onSelected: (_) {
                                        ref.read(_selectedThemeFilterProvider.notifier).state = theme;
                                      },
                                      selectedColor: Colors.deepPurple.shade100,
                                    ),
                                  );
                                }).toList(),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          FilterChip(
                            label: const Text('Favorites'),
                            selected: showOnlyFavorites,
                            onSelected: (selected) {
                              ref.read(_showOnlyFavoritesProvider.notifier).state = selected;
                            },
                          ),
                          const SizedBox(width: 8),
                          FilterChip(
                            label: const Text('Interactive'),
                            selected: showOnlyInteractive,
                            onSelected: (selected) {
                              ref.read(_showOnlyInteractiveProvider.notifier).state = selected;
                            },
                          ),
                          const Spacer(),
                          DropdownButton<SortOption>(
                            value: currentSort,
                            underline: const SizedBox.shrink(),
                            items: const [
                              DropdownMenuItem(
                                value: SortOption.newest,
                                child: Text('Newest'),
                              ),
                              DropdownMenuItem(
                                value: SortOption.oldest,
                                child: Text('Oldest'),
                              ),
                              DropdownMenuItem(
                                value: SortOption.favoritesFirst,
                                child: Text('Favorites first'),
                              ),
                            ],
                            onChanged: (value) {
                              if (value == null) return;
                              ref.read(_sortOptionProvider.notifier).state = value;
                            },
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                // Stats row
                Container(
                  padding: const EdgeInsets.all(8),
                  color: Colors.deepPurple.shade50,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _buildStat(Icons.book, '${stories.length}', 'Total'),
                      _buildStat(Icons.favorite, '$favoriteCount', 'Favorites'),
                      _buildStat(Icons.visibility, '${filteredStories.length}', 'Showing'),
                    ],
                  ),
                ),

                if (filteredStories.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 40),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.filter_alt_off, size: 64, color: Colors.grey.shade400),
                        const SizedBox(height: 16),
                        Text(
                          'No stories match your filters',
                          style: TextStyle(fontSize: 16, color: Colors.grey.shade600),
                        ),
                        const SizedBox(height: 8),
                        TextButton(
                          onPressed: () {
                            ref.read(_showOnlyFavoritesProvider.notifier).state = false;
                            ref.read(_selectedThemeFilterProvider.notifier).state = 'All';
                            ref.read(_showOnlyInteractiveProvider.notifier).state = false;
                            ref.read(_sortOptionProvider.notifier).state = SortOption.newest;
                          },
                          child: const Text('Clear Filters'),
                        ),
                      ],
                    ),
                  )
                else
                  ...filteredStories.map((s) {
                    final dateStr = _prettyDate(s.createdAt);
                    final childNames = s.characters.map((c) => c.name).toList();

                    final wordCount = _wordCount(s.storyText);
                    final readMinutes = (wordCount / 180).clamp(1, 30).round();
                    final qualityLabel = _qualityLabel(wordCount);
                    final qualityColor = _qualityColor(wordCount);
                    final avgAge = _averageAge(s.characters);

                    return Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      child: Dismissible(
                        key: ValueKey(s.identifier),
                        direction: DismissDirection.endToStart,
                        background: Container(
                          alignment: Alignment.centerRight,
                          padding: const EdgeInsets.symmetric(horizontal: 20),
                          decoration: BoxDecoration(
                            color: Colors.red.shade100,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(Icons.delete, color: Colors.red),
                        ),
                        confirmDismiss: (_) async {
                          await _deleteStory(context, ref, s);
                          return false; // refresh handles removal
                        },
                        child: Card(
                          elevation: 2,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                            side: s.isFavorite
                                ? BorderSide(color: Colors.red.shade200, width: 2)
                                : BorderSide.none,
                          ),
                          child: Padding(
                            padding: const EdgeInsets.all(12.0),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // Title row + actions
                                Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    if (s.isFavorite)
                                      const Padding(
                                        padding: EdgeInsets.only(right: 8.0, top: 4.0),
                                        child: Icon(Icons.favorite, color: Colors.red, size: 20),
                                      ),
                                    Expanded(
                                      child: Text(
                                        s.title,
                                        style: const TextStyle(
                                          fontSize: 18,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                    if (s.isInteractive)
                                      Padding(
                                        padding: const EdgeInsets.only(right: 8.0),
                                        child: Chip(
                                          label: const Text('Interactive', style: TextStyle(fontSize: 11)),
                                          backgroundColor: Colors.purple.shade100,
                                          padding: EdgeInsets.zero,
                                          visualDensity: VisualDensity.compact,
                                        ),
                                      ),
                                    Chip(
                                      label: Text(
                                        qualityLabel,
                                        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700),
                                      ),
                                      backgroundColor: qualityColor.withValues(alpha: 0.15),
                                      side: BorderSide(color: qualityColor.withValues(alpha: 0.4)),
                                      visualDensity: VisualDensity.compact,
                                    ),
                                    IconButton(
                                      tooltip: s.isFavorite ? 'Remove from favorites' : 'Add to favorites',
                                      icon: Icon(
                                        s.isFavorite ? Icons.favorite : Icons.favorite_border,
                                        color: s.isFavorite ? Colors.red : null,
                                      ),
                                      onPressed: () => _toggleFavorite(ref, s),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 6),

                                // Meta line
                                Wrap(
                                  spacing: 8,
                                  runSpacing: 4,
                                  children: [
                                    _metaChip(Icons.calendar_today, dateStr),
                                    _metaChip(Icons.menu_book, '$wordCount words'),
                                    _metaChip(Icons.timer, '$readMinutes min read'),
                                    _metaChip(Icons.child_care, avgAge != null ? 'Age ~$avgAge' : 'All ages'),
                                  ],
                                ),
                                const SizedBox(height: 8),

                                // Chip list of included kids
                                if (childNames.isNotEmpty)
                                  Wrap(
                                    spacing: 6,
                                    runSpacing: 6,
                                    children: childNames
                                        .map((n) => Chip(
                                              label: Text(n),
                                              avatar: const Icon(Icons.child_care, size: 16),
                                            ))
                                        .toList(),
                                  ),
                                if (childNames.isNotEmpty) const SizedBox(height: 8),

                                // Preview snippet
                                Text(
                                  s.storyText.length > 180
                                      ? '${s.storyText.substring(0, 180)}…'
                                      : s.storyText,
                                ),
                                const SizedBox(height: 10),

                                // Quick actions
                                Row(
                                  children: [
                                    TextButton.icon(
                                      onPressed: () => _shareStory(s),
                                      icon: const Icon(Icons.share),
                                      label: const Text('Share'),
                                    ),
                                    TextButton.icon(
                                      onPressed: () {
                                        Navigator.of(context).push(
                                          MaterialPageRoute(
                                            builder: (_) => StoryResultScreen(
                                              title: s.title,
                                              storyText: s.storyText,
                                              wisdomGem: s.wisdomGem ?? '',
                                              characterName: s.characters.isNotEmpty ? s.characters.first.name : null,
                                              storyId: s.identifier,
                                            ),
                                          ),
                                        );
                                      },
                                      icon: const Icon(Icons.menu_book),
                                      label: const Text('Read again'),
                                    ),
                                    const Spacer(),
                                    IconButton(
                                      tooltip: 'Delete',
                                      icon: const Icon(Icons.delete_outline),
                                      onPressed: () {
                                        _deleteStory(context, ref, s);
                                      },
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    );
                  }),
                const SizedBox(height: 12),
              ],
            ),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stack) => Center(child: Text('Error loading stories: $error')),
      ),
    );
  }

  Widget _buildStat(IconData icon, String value, String label) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: Colors.deepPurple),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        Text(
          label,
          style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
        ),
      ],
    );
  }

  String _prettyDate(DateTime d) {
    return '${_two(d.month)}/${_two(d.day)}/${d.year} ${_two(d.hour)}:${_two(d.minute)}';
  }

  String _two(int n) => n.toString().padLeft(2, '0');

  int _wordCount(String text) {
    return text.split(RegExp(r'\s+')).where((word) => word.isNotEmpty).length;
  }

  String _qualityLabel(int wordCount) {
    if (wordCount >= 500) return 'Epic';
    if (wordCount >= 300) return 'Great';
    if (wordCount >= 150) return 'Good';
    return 'Short';
  }

  Color _qualityColor(int wordCount) {
    if (wordCount >= 500) return Colors.green;
    if (wordCount >= 300) return Colors.blue;
    if (wordCount >= 150) return Colors.orange;
    return Colors.grey;
  }

  int? _averageAge(List<Character> characters) {
    final ages = characters.map((c) => c.age).where((age) => age > 0).toList();
    if (ages.isEmpty) return null;
    final sum = ages.reduce((a, b) => a + b);
    return (sum / ages.length).round();
  }

  Widget _metaChip(IconData icon, String text) {
    return Chip(
      avatar: Icon(icon, size: 16),
      label: Text(text),
      visualDensity: VisualDensity.compact,
      padding: EdgeInsets.zero,
    );
  }

  Future<void> _toggleFavorite(WidgetRef ref, StoryLocal story) async {
    await ref.read(storyListProvider.notifier).toggleFavorite(story.identifier);
  }

  Future<void> _deleteStory(BuildContext context, WidgetRef ref, StoryLocal story) async {
    await ref.read(storyListProvider.notifier).deleteStory(story.identifier);
    await _refreshStories(ref);
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Story deleted')),
    );
  }

  Future<void> _refreshStories(WidgetRef ref) async {
    await ref.read(storyListProvider.notifier).refresh();
    final refreshed = ref.read(storyListProvider).valueOrNull;
    if (refreshed != null) {
      StoryAnalytics.trackStoryResultAction(
        storyId: 'saved_stories',
        action: 'pull_to_refresh',
        extra: {'count': refreshed.length},
      );
    }
  }

  Future<void> _shareStory(StoryLocal story) async {
    final shareText = '${story.title}\n\n${story.storyText}';
    await Share.share(shareText, subject: story.title);
  }
}

List<StoryLocal> _applyFilters(
  List<StoryLocal> stories, {
  required bool showOnlyFavorites,
  required bool showOnlyInteractive,
  required String selectedThemeFilter,
  required SortOption currentSort,
}) {
  final filtered = stories.where((story) {
    if (showOnlyFavorites && !story.isFavorite) return false;
    if (showOnlyInteractive && !story.isInteractive) return false;
    if (selectedThemeFilter != 'All' && story.theme != selectedThemeFilter) {
      return false;
    }
    return true;
  }).toList();

  filtered.sort((a, b) {
    switch (currentSort) {
      case SortOption.newest:
        return b.createdAt.compareTo(a.createdAt);
      case SortOption.oldest:
        return a.createdAt.compareTo(b.createdAt);
      case SortOption.favoritesFirst:
        if (a.isFavorite == b.isFavorite) {
          return b.createdAt.compareTo(a.createdAt);
        }
        return b.isFavorite ? 1 : -1;
    }
  });

  return filtered;
}
