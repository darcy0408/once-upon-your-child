// lib/offline_stories_screen.dart

import 'package:flutter/material.dart';
import 'offline_story_cache.dart';
import 'story_reader_screen.dart';

class OfflineStoriesScreen extends StatefulWidget {
  const OfflineStoriesScreen({super.key});

  @override
  State<OfflineStoriesScreen> createState() => _OfflineStoriesScreenState();
}

class _OfflineStoriesScreenState extends State<OfflineStoriesScreen> with SingleTickerProviderStateMixin {
  final _cache = OfflineStoryCache();
  List<CachedStory> _allStories = [];
  List<CachedStory> _favoriteStories = [];
  CacheStatistics? _stats;
  bool _isLoading = true;
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadStories();
  }

  Future<void> _loadStories() async {
    setState(() => _isLoading = true);

    final all = await _cache.getAllCachedStories();
    final favorites = await _cache.getFavoriteStories();
    final stats = await _cache.getCacheStatistics();

    if (mounted) {
      setState(() {
        _allStories = all;
        _favoriteStories = favorites;
        _stats = stats;
        _isLoading = false;
      });
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Offline Stories'),
        backgroundColor: Colors.deepPurple,
        bottom: TabBar(
          controller: _tabController,
          tabs: [
            Tab(
              icon: const Icon(Icons.library_books),
              text: 'All Stories (${_allStories.length})',
            ),
            Tab(
              icon: const Icon(Icons.favorite),
              text: 'Favorites (${_favoriteStories.length})',
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.info_outline),
            onPressed: _showCacheInfo,
          ),
          PopupMenuButton(
            itemBuilder: (context) => [
              PopupMenuItem(
                child: ListTile(
                  leading: const Icon(Icons.delete_sweep),
                  title: const Text('Clear Cache'),
                  onTap: () {
                    Navigator.pop(context);
                    _confirmClearCache();
                  },
                ),
              ),
            ],
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : TabBarView(
              controller: _tabController,
              children: [
                _buildStoryList(_allStories),
                _buildStoryList(_favoriteStories),
              ],
            ),
    );
  }

  Widget _buildStoryList(List<CachedStory> stories) {
    if (stories.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.cloud_off, size: 80, color: Colors.grey.shade300),
            const SizedBox(height: 16),
            Text(
              'No offline stories yet',
              style: TextStyle(fontSize: 20, color: Colors.grey.shade600),
            ),
            const SizedBox(height: 8),
            Text(
              'Stories will be automatically cached for offline reading',
              style: TextStyle(fontSize: 14, color: Colors.grey.shade500),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    // Sort by most recent first
    final sortedStories = List<CachedStory>.from(stories)
      ..sort((a, b) => b.cachedAt.compareTo(a.cachedAt));

    return ListView.builder(
      itemCount: sortedStories.length,
      padding: const EdgeInsets.all(8),
      itemBuilder: (context, index) {
        final story = sortedStories[index];
        return _buildStoryCard(story);
      },
    );
  }

  Widget _buildStoryCard(CachedStory story) {
    final daysSinceCached = DateTime.now().difference(story.cachedAt).inDays;
    final timeAgo = daysSinceCached == 0
        ? 'Today'
        : daysSinceCached == 1
            ? 'Yesterday'
            : '$daysSinceCached days ago';

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: InkWell(
        onTap: () => _readStory(story),
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      story.title,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.deepPurple,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  IconButton(
                    icon: Icon(
                      story.isFavorite ? Icons.favorite : Icons.favorite_border,
                      color: story.isFavorite ? Colors.red : Colors.grey,
                    ),
                    onPressed: () => _toggleFavorite(story.id),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  const Icon(Icons.person, size: 16, color: Colors.grey),
                  const SizedBox(width: 4),
                  Text(
                    story.characterName,
                    style: TextStyle(fontSize: 14, color: Colors.grey.shade700),
                  ),
                  const SizedBox(width: 16),
                  const Icon(Icons.category, size: 16, color: Colors.grey),
                  const SizedBox(width: 4),
                  Text(
                    story.theme,
                    style: TextStyle(fontSize: 14, color: Colors.grey.shade700),
                  ),
                ],
              ),
              if (story.companion != null) ...[
                const SizedBox(height: 4),
                Row(
                  children: [
                    const Icon(Icons.pets, size: 16, color: Colors.grey),
                    const SizedBox(width: 4),
                    Text(
                      story.companion!,
                      style: TextStyle(fontSize: 14, color: Colors.grey.shade700),
                    ),
                  ],
                ),
              ],
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Icon(Icons.access_time, size: 14, color: Colors.grey.shade600),
                      const SizedBox(width: 4),
                      Text(
                        timeAgo,
                        style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                      ),
                    ],
                  ),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.green.shade100,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: const [
                            Icon(Icons.offline_pin, size: 14, color: Colors.green),
                            SizedBox(width: 4),
                            Text(
                              'Offline',
                              style: TextStyle(fontSize: 12, color: Colors.green),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.delete_outline, color: Colors.red),
                        onPressed: () => _deleteStory(story),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _readStory(CachedStory story) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => StoryReaderScreen(
          title: story.title,
          storyText: story.storyText,
          characterName: story.characterName,
        ),
      ),
    );
  }

  Future<void> _toggleFavorite(String storyId) async {
    await _cache.toggleFavorite(storyId);
    await _loadStories();
  }

  Future<void> _deleteStory(CachedStory story) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Story?'),
        content: Text('Are you sure you want to delete "${story.title}"? This cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await _cache.deleteCachedStory(story.id);
      await _loadStories();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('"${story.title}" deleted')),
        );
      }
    }
  }

  void _showCacheInfo() {
    if (_stats == null) return;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Cache Information'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildStatRow('Total Stories', '${_stats!.totalStories}'),
            _buildStatRow('Favorites', '${_stats!.favoriteCount}'),
            _buildStatRow('Storage Used', _stats!.formattedSize),
            if (_stats!.oldestStory != null)
              _buildStatRow(
                'Oldest',
                '${_stats!.oldestStory!.day}/${_stats!.oldestStory!.month}/${_stats!.oldestStory!.year}',
              ),
            if (_stats!.newestStory != null)
              _buildStatRow(
                'Newest',
                '${_stats!.newestStory!.day}/${_stats!.newestStory!.month}/${_stats!.newestStory!.year}',
              ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Widget _buildStatRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontWeight: FontWeight.bold)),
          Text(value),
        ],
      ),
    );
  }

  Future<void> _confirmClearCache() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Clear Cache?'),
        content: const Text(
          'This will delete all cached stories except favorites. Are you sure?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Clear'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await _cache.clearCache(includeFavorites: false);
      await _loadStories();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Cache cleared (favorites preserved)')),
        );
      }
    }
  }
}
