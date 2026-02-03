import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';

import 'models/local/story_local.dart';
import 'providers/story_provider.dart';
import 'services/story_analytics.dart';
import 'story_result_screen.dart';
import 'widgets/story_card.dart';
import 'theme/app_theme.dart';

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
            child: CustomScrollView(
              slivers: [
                // Filter bar & Stats
                SliverToBoxAdapter(
                  child: Column(
                    children: [
                      _buildFilterBar(ref, selectedTheme, showOnlyFavorites, showOnlyInteractive, currentSort),
                      _buildStatsRow(stories.length, favoriteCount, filteredStories.length),
                    ],
                  ),
                ),

                if (filteredStories.isEmpty)
                  SliverFillRemaining(
                    child: Center(
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
                    ),
                  )
                else
                  SliverPadding(
                    padding: const EdgeInsets.all(16),
                    sliver: SliverGrid(
                      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                        maxCrossAxisExtent: 400, // Responsive cards
                        mainAxisSpacing: 16,
                        crossAxisSpacing: 16,
                        childAspectRatio: 0.85, // Taller cards for premium look
                      ),
                      delegate: SliverChildBuilderDelegate(
                        (context, index) {
                          final story = filteredStories[index];
                          return StoryCard(
                            story: story,
                            onTap: () {
                              Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (_) => StoryResultScreen(
                                    title: story.title,
                                    storyText: story.storyText,
                                    wisdomGem: story.wisdomGem ?? '',
                                    characterName: story.characters.isNotEmpty ? story.characters.first.name : null,
                                    storyId: story.identifier,
                                  ),
                                ),
                              );
                            },
                            onToggleFavorite: () => _toggleFavorite(ref, story),
                            onDelete: () => _deleteStory(context, ref, story),
                            onShare: () => _shareStory(story),
                          );
                        },
                        childCount: filteredStories.length,
                      ),
                    ),
                  ),

                // Bottom padding
                const SliverToBoxAdapter(child: SizedBox(height: 40)),
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

  Widget _buildFilterBar(
    WidgetRef ref,
    String selectedTheme,
    bool showOnlyFavorites,
    bool showOnlyInteractive,
    SortOption currentSort,
  ) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.deepPurple.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Theme Scroll
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            clipBehavior: Clip.none,
            child: Row(
              children: _themes.map((theme) {
                final isSelected = selectedTheme == theme;
                return Padding(
                  padding: const EdgeInsets.only(right: 8.0),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    child: FilterChip(
                      label: Text(
                        theme,
                        style: TextStyle(
                          color: isSelected ? Colors.white : Colors.black87,
                          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                        ),
                      ),
                      selected: isSelected,
                      checkmarkColor: Colors.white,
                      backgroundColor: Colors.grey.shade100,
                      selectedColor: AppColors.primary,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                        side: BorderSide(
                          color: isSelected ? AppColors.primary : Colors.grey.shade300,
                        ),
                      ),
                      onSelected: (_) {
                        ref.read(_selectedThemeFilterProvider.notifier).state = theme;
                      },
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: 12),
          
          // Filters & Sort
          Row(
            children: [
              FilterChip(
                avatar: Icon(
                  showOnlyFavorites ? Icons.favorite : Icons.favorite_border,
                  size: 16,
                  color: showOnlyFavorites ? Colors.white : Colors.red,
                ),
                label: const Text('Favorites'),
                selected: showOnlyFavorites,
                selectedColor: Colors.red.shade400,
                labelStyle: TextStyle(
                  color: showOnlyFavorites ? Colors.white : Colors.black87,
                ),
                checkmarkColor: Colors.white,
                onSelected: (selected) {
                  ref.read(_showOnlyFavoritesProvider.notifier).state = selected;
                },
              ),
              const SizedBox(width: 8),
              FilterChip(
                avatar: Icon(
                  Icons.touch_app,
                  size: 16,
                  color: showOnlyInteractive ? Colors.white : Colors.purple,
                ),
                label: const Text('Interactive'),
                selected: showOnlyInteractive,
                selectedColor: Colors.purple.shade400,
                labelStyle: TextStyle(
                  color: showOnlyInteractive ? Colors.white : Colors.black87,
                ),
                checkmarkColor: Colors.white,
                onSelected: (selected) {
                  ref.read(_showOnlyInteractiveProvider.notifier).state = selected;
                },
              ),
              const Spacer(),
              
              // Sort Dropdown
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.grey.shade50,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.grey.shade200),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<SortOption>(
                    value: currentSort,
                    isDense: true,
                    icon: const Icon(Icons.sort, size: 20),
                    items: const [
                      DropdownMenuItem(
                        value: SortOption.newest,
                        child: Text('Newest', style: TextStyle(fontSize: 13)),
                      ),
                      DropdownMenuItem(
                        value: SortOption.oldest,
                        child: Text('Oldest', style: TextStyle(fontSize: 13)),
                      ),
                      DropdownMenuItem(
                        value: SortOption.favoritesFirst,
                        child: Text('Favorites', style: TextStyle(fontSize: 13)),
                      ),
                    ],
                    onChanged: (value) {
                      if (value == null) return;
                      ref.read(_sortOptionProvider.notifier).state = value;
                    },
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatsRow(int total, int favorites, int showing) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.accent.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.accent.withValues(alpha: 0.2)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildStat(Icons.library_books, '$total', 'Total Stories'),
          Container(width: 1, height: 24, color: AppColors.accent.withValues(alpha: 0.2)),
          _buildStat(Icons.favorite, '$favorites', 'Favorites'),
          Container(width: 1, height: 24, color: AppColors.accent.withValues(alpha: 0.2)),
          _buildStat(Icons.visibility, '$showing', 'Showing'),
        ],
      ),
    );
  }

  Future<void> _shareStory(StoryLocal story) async {
    final shareText = '${story.title}\n\n${story.storyText}';
    await SharePlus.instance.share(shareText, subject: story.title);
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
