import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';

import 'models/local/story_local.dart';
import 'providers/story_provider.dart';
import 'services/story_analytics.dart';
import 'story_result_screen.dart';
import 'widgets/story_card.dart';
import 'theme/age_band_theme.dart';

enum SortOption {
  newest,
  oldest,
  favoritesFirst,
  byCharacter,
}

final _showOnlyFavoritesProvider = StateProvider<bool>((ref) => false);
final _showOnlyInteractiveProvider = StateProvider<bool>((ref) => false);
final _selectedThemeFilterProvider = StateProvider<String>((ref) => 'All');
final _sortOptionProvider = StateProvider<SortOption>((ref) => SortOption.newest);
final _compactListProvider = StateProvider<bool>((ref) => false);

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
    final band = Theme.of(context).extension<AgeBandThemeData>() ?? explorerTheme;
    final storiesAsync = ref.watch(storyListProvider);
    final showOnlyFavorites = ref.watch(_showOnlyFavoritesProvider);
    final showOnlyInteractive = ref.watch(_showOnlyInteractiveProvider);
    final selectedTheme = ref.watch(_selectedThemeFilterProvider);
    final currentSort = ref.watch(_sortOptionProvider);
    final isCompact = ref.watch(_compactListProvider);
    // Sprout always uses large cards; Creator can toggle compact list
    final showCompactToggle = band.band == AgeBand.creator || band.band == AgeBand.adventurer;
    final useCompact = showCompactToggle && isCompact;

    return Scaffold(
      backgroundColor: band.gradientStart,
      appBar: AppBar(
        backgroundColor: band.gradientStart,
        foregroundColor: Colors.white,
        elevation: 0,
        title: Text(
          band.band == AgeBand.sprout ? 'My Story Shelf' : 'My Stories',
          style: TextStyle(fontFamily: band.uiFontFamily, fontWeight: FontWeight.bold),
        ),
        actions: [
          if (showCompactToggle)
            IconButton(
              icon: Icon(isCompact ? Icons.grid_view_rounded : Icons.list_rounded),
              tooltip: isCompact ? 'Card view' : 'List view',
              onPressed: () => ref.read(_compactListProvider.notifier).state = !isCompact,
            ),
          IconButton(
            icon: Icon(
              showOnlyFavorites ? Icons.favorite : Icons.favorite_border,
              color: showOnlyFavorites ? Colors.red.shade300 : Colors.white70,
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
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(band.band == AgeBand.sprout ? '📚' : '📖',
                      style: const TextStyle(fontSize: 56)),
                  const SizedBox(height: 12),
                  Text(
                    'No stories saved yet!',
                    style: TextStyle(color: Colors.white70, fontSize: 16,
                        fontFamily: band.uiFontFamily),
                  ),
                ],
              ),
            );
          }

          return RefreshIndicator(
            onRefresh: () => _refreshStories(ref),
            child: CustomScrollView(
              slivers: [
                SliverToBoxAdapter(
                  child: Column(
                    children: [
                      _buildFilterBar(ref, selectedTheme, showOnlyFavorites,
                          showOnlyInteractive, currentSort, band),
                      _buildStatsRow(stories.length, favoriteCount,
                          filteredStories.length, band),
                    ],
                  ),
                ),

                if (filteredStories.isEmpty)
                  SliverFillRemaining(
                    child: Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.filter_alt_off, size: 64,
                              color: Colors.white38),
                          const SizedBox(height: 16),
                          Text(
                            'No stories match your filters',
                            style: TextStyle(
                                fontSize: 16, color: Colors.white70),
                          ),
                          const SizedBox(height: 8),
                          TextButton(
                            onPressed: () {
                              ref.read(_showOnlyFavoritesProvider.notifier).state = false;
                              ref.read(_selectedThemeFilterProvider.notifier).state = 'All';
                              ref.read(_showOnlyInteractiveProvider.notifier).state = false;
                              ref.read(_sortOptionProvider.notifier).state = SortOption.newest;
                            },
                            child: const Text('Clear Filters',
                                style: TextStyle(color: Colors.white70)),
                          ),
                        ],
                      ),
                    ),
                  )
                else if (useCompact)
                  // Compact list (Creator/Adventurer band or manual toggle)
                  SliverPadding(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    sliver: SliverList(
                      delegate: SliverChildBuilderDelegate(
                        (context, index) {
                          final story = filteredStories[index];
                          return _SwipeableStoryTile(
                            key: ValueKey(story.identifier),
                            story: story,
                            band: band,
                            onTap: () => _openStory(context, story),
                            onToggleFavorite: () => _toggleFavorite(ref, story),
                            onDelete: () => _deleteStory(context, ref, story),
                            onShare: () => _shareStory(story),
                          );
                        },
                        childCount: filteredStories.length,
                      ),
                    ),
                  )
                else
                  // Card grid (Sprout = 1 col wide, others = responsive)
                  SliverPadding(
                    padding: const EdgeInsets.all(16),
                    sliver: SliverGrid(
                      gridDelegate: SliverGridDelegateWithMaxCrossAxisExtent(
                        maxCrossAxisExtent: band.band == AgeBand.sprout ? 600 : 400,
                        mainAxisSpacing: 16,
                        crossAxisSpacing: 16,
                        childAspectRatio: band.band == AgeBand.sprout ? 1.1 : 0.85,
                      ),
                      delegate: SliverChildBuilderDelegate(
                        (context, index) {
                          final story = filteredStories[index];
                          return _SwipeableStoryCard(
                            key: ValueKey(story.identifier),
                            story: story,
                            onTap: () => _openStory(context, story),
                            onToggleFavorite: () => _toggleFavorite(ref, story),
                            onDelete: () => _deleteStory(context, ref, story),
                            onShare: () => _shareStory(story),
                          );
                        },
                        childCount: filteredStories.length,
                      ),
                    ),
                  ),

                const SliverToBoxAdapter(child: SizedBox(height: 40)),
              ],
            ),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stack) =>
            Center(child: Text('Error loading stories: $error')),
      ),
    );
  }

  void _openStory(BuildContext context, StoryLocal story) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => StoryResultScreen(
          title: story.title,
          storyText: story.storyText,
          characterName: story.characters.isNotEmpty
              ? story.characters.first.name
              : null,
          storyId: story.identifier,
          // Re-open the saved story with its persisted illustrations so the
          // pictures appear immediately without regenerating them.
          persistedCoverImageBase64: story.coverImageBase64,
          persistedPageIllustrationsJson: story.pageIllustrationsJson,
        ),
      ),
    );
  }

  Widget _buildStat(IconData icon, String value, String label) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: Colors.white70),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
        ),
        Text(
          label,
          style: const TextStyle(fontSize: 12, color: Colors.white60),
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
    AgeBandThemeData band,
  ) {
    final primaryColor = band.primary;
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.08),
        border: Border(bottom: BorderSide(color: Colors.white12)),
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
                          color: isSelected ? Colors.white : Colors.white70,
                          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                        ),
                      ),
                      selected: isSelected,
                      checkmarkColor: Colors.white,
                      backgroundColor: Colors.white10,
                      selectedColor: primaryColor,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                        side: BorderSide(
                          color: isSelected ? primaryColor : Colors.white24,
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
          
          // Filters & Sort - wrap to prevent overflow on narrow screens
          Wrap(
            spacing: 8,
            runSpacing: 8,
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              FilterChip(
                avatar: Icon(
                  showOnlyFavorites ? Icons.favorite : Icons.favorite_border,
                  size: 16,
                  color: showOnlyFavorites ? Colors.white : Colors.red.shade300,
                ),
                label: const Text('Favorites'),
                selected: showOnlyFavorites,
                selectedColor: Colors.red.shade400,
                labelStyle: TextStyle(
                  color: showOnlyFavorites ? Colors.white : Colors.white70,
                ),
                checkmarkColor: Colors.white,
                backgroundColor: Colors.white10,
                onSelected: (selected) {
                  ref.read(_showOnlyFavoritesProvider.notifier).state = selected;
                },
              ),
              FilterChip(
                avatar: Icon(
                  Icons.touch_app,
                  size: 16,
                  color: showOnlyInteractive ? Colors.white : Colors.purple.shade200,
                ),
                label: const Text('Interactive'),
                selected: showOnlyInteractive,
                selectedColor: Colors.purple.shade400,
                labelStyle: TextStyle(
                  color: showOnlyInteractive ? Colors.white : Colors.white70,
                ),
                checkmarkColor: Colors.white,
                backgroundColor: Colors.white10,
                onSelected: (selected) {
                  ref.read(_showOnlyInteractiveProvider.notifier).state = selected;
                },
              ),
              // Sort Dropdown
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.white10,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.white24),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<SortOption>(
                    value: currentSort,
                    isDense: true,
                    dropdownColor: band.gradientEnd,
                    style: const TextStyle(color: Colors.white, fontSize: 12),
                    icon: const Icon(Icons.sort, size: 18, color: Colors.white70),
                    items: const [
                      DropdownMenuItem(
                        value: SortOption.newest,
                        child: Text('Newest', style: TextStyle(fontSize: 12)),
                      ),
                      DropdownMenuItem(
                        value: SortOption.oldest,
                        child: Text('Oldest', style: TextStyle(fontSize: 12)),
                      ),
                      DropdownMenuItem(
                        value: SortOption.favoritesFirst,
                        child: Text('Favorites first', style: TextStyle(fontSize: 12)),
                      ),
                      DropdownMenuItem(
                        value: SortOption.byCharacter,
                        child: Text('By character', style: TextStyle(fontSize: 12)),
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

  Widget _buildStatsRow(int total, int favorites, int showing, AgeBandThemeData band) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white12),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          Flexible(child: _buildStat(Icons.library_books, '$total', 'Total')),
          Container(width: 1, height: 24, color: Colors.white12),
          Flexible(child: _buildStat(Icons.favorite, '$favorites', 'Favorites')),
          Container(width: 1, height: 24, color: Colors.white12),
          Flexible(child: _buildStat(Icons.visibility, '$showing', 'Showing')),
        ],
      ),
    );
  }

  Future<void> _shareStory(StoryLocal story) async {
    final shareText = '${story.title}\n\n${story.storyText}';
    await SharePlus.instance.share(
      ShareParams(text: shareText, subject: story.title),
    );
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
      case SortOption.byCharacter:
        final aName = a.characters.isNotEmpty ? a.characters.first.name : '';
        final bName = b.characters.isNotEmpty ? b.characters.first.name : '';
        return aName.compareTo(bName);
    }
  });

  return filtered;
}

// ---------------------------------------------------------------------------
// Swipeable card for grid view — shares/deletes on horizontal drag
// ---------------------------------------------------------------------------
class _SwipeableStoryCard extends StatelessWidget {
  const _SwipeableStoryCard({
    super.key,
    required this.story,
    required this.onTap,
    required this.onToggleFavorite,
    required this.onDelete,
    required this.onShare,
  });

  final StoryLocal story;
  final VoidCallback onTap;
  final VoidCallback onToggleFavorite;
  final VoidCallback onDelete;
  final VoidCallback onShare;

  @override
  Widget build(BuildContext context) {
    return Dismissible(
      key: ValueKey('dismiss_${story.identifier}'),
      background: _SwipeBg(color: Colors.teal.shade600, icon: Icons.share, label: 'Share', alignment: Alignment.centerLeft),
      secondaryBackground: _SwipeBg(color: Colors.red.shade600, icon: Icons.delete_outline, label: 'Delete', alignment: Alignment.centerRight),
      confirmDismiss: (direction) async {
        if (direction == DismissDirection.startToEnd) {
          onShare();
          return false;
        } else {
          onDelete();
          return false;
        }
      },
      child: StoryCard(
        story: story,
        onTap: onTap,
        onToggleFavorite: onToggleFavorite,
        onDelete: onDelete,
        onShare: onShare,
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Compact list tile for Creator/Adventurer band
// ---------------------------------------------------------------------------
class _SwipeableStoryTile extends StatelessWidget {
  const _SwipeableStoryTile({
    super.key,
    required this.story,
    required this.band,
    required this.onTap,
    required this.onToggleFavorite,
    required this.onDelete,
    required this.onShare,
  });

  final StoryLocal story;
  final AgeBandThemeData band;
  final VoidCallback onTap;
  final VoidCallback onToggleFavorite;
  final VoidCallback onDelete;
  final VoidCallback onShare;

  @override
  Widget build(BuildContext context) {
    final charName = story.characters.isNotEmpty ? story.characters.first.name : null;
    return Dismissible(
      key: ValueKey('dismiss_tile_${story.identifier}'),
      background: _SwipeBg(color: Colors.teal.shade600, icon: Icons.share, label: 'Share', alignment: Alignment.centerLeft),
      secondaryBackground: _SwipeBg(color: Colors.red.shade600, icon: Icons.delete_outline, label: 'Delete', alignment: Alignment.centerRight),
      confirmDismiss: (direction) async {
        if (direction == DismissDirection.startToEnd) {
          onShare();
        } else {
          onDelete();
        }
        return false;
      },
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.white12),
        ),
        child: ListTile(
          onTap: onTap,
          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          title: Text(
            story.title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: Colors.white,
              fontFamily: band.uiFontFamily,
              fontWeight: FontWeight.w600,
              fontSize: 14,
            ),
          ),
          subtitle: charName != null
              ? Text(charName,
                  style: const TextStyle(color: Colors.white60, fontSize: 12))
              : null,
          leading: Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: band.primary.withValues(alpha: 0.3),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Center(
              child: Text(
                story.theme.isNotEmpty ? story.theme[0].toUpperCase() : '📖',
                style: const TextStyle(fontSize: 18),
              ),
            ),
          ),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (story.isFavorite)
                const Icon(Icons.favorite, color: Colors.red, size: 16),
              if (story.isInteractive)
                const Padding(
                  padding: EdgeInsets.only(left: 4),
                  child: Icon(Icons.touch_app, color: Colors.white60, size: 16),
                ),
              const SizedBox(width: 4),
              IconButton(
                icon: const Icon(Icons.more_vert, color: Colors.white60, size: 18),
                onPressed: () => _showActionsMenu(context),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showActionsMenu(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => Container(
        decoration: const BoxDecoration(
          color: Color(0xFF2D2D6A),
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: Icon(
                  story.isFavorite ? Icons.favorite : Icons.favorite_border,
                  color: story.isFavorite ? Colors.red : Colors.white70,
                ),
                title: Text(
                  story.isFavorite ? 'Remove from Favorites' : 'Add to Favorites',
                  style: const TextStyle(color: Colors.white),
                ),
                onTap: () { Navigator.pop(context); onToggleFavorite(); },
              ),
              ListTile(
                leading: const Icon(Icons.share, color: Colors.white70),
                title: const Text('Share', style: TextStyle(color: Colors.white)),
                onTap: () { Navigator.pop(context); onShare(); },
              ),
              ListTile(
                leading: const Icon(Icons.delete_outline, color: Colors.redAccent),
                title: const Text('Delete', style: TextStyle(color: Colors.redAccent)),
                onTap: () { Navigator.pop(context); onDelete(); },
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Reusable swipe action background
// ---------------------------------------------------------------------------
class _SwipeBg extends StatelessWidget {
  const _SwipeBg({
    required this.color,
    required this.icon,
    required this.label,
    required this.alignment,
  });

  final Color color;
  final IconData icon;
  final String label;
  final Alignment alignment;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(12),
      ),
      alignment: alignment,
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: Colors.white, size: 24),
          const SizedBox(height: 4),
          Text(label, style: const TextStyle(color: Colors.white, fontSize: 11)),
        ],
      ),
    );
  }
}
