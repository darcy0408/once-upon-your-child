import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:share_plus/share_plus.dart';

import 'config/environment.dart';
import 'models.dart';
import 'services/story_analytics.dart';
import 'storage_service.dart';
import 'story_result_screen.dart';

enum SortOption {
  newest,
  oldest,
  favoritesFirst,
}

class SavedStoriesScreen extends StatefulWidget {
  const SavedStoriesScreen({super.key});

  @override
  State<SavedStoriesScreen> createState() => _SavedStoriesScreenState();
}

class _SavedStoriesScreenState extends State<SavedStoriesScreen> {
  final _storage = StorageService();
  List<SavedStory> _stories = [];
  List<SavedStory> _filteredStories = [];
  bool _loading = true;
  bool _showOnlyFavorites = false;
  String _selectedThemeFilter = 'All';
  bool _showOnlyInteractive = false;
  SortOption _currentSort = SortOption.newest;
  final TextEditingController _reportController = TextEditingController();
  bool _isReporting = false;

  static const List<String> _themes = [
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

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  @override
  void dispose() {
    _reportController.dispose();
    super.dispose();
  }

  Future<void> _refresh() async {
    setState(() => _loading = true);
    final list = await _storage.loadStories();
    if (!mounted) return;
    setState(() {
      _stories = list;
      _applyFilters();
      _loading = false;
    });
    StoryAnalytics.trackStoryResultAction(
      storyId: 'saved_stories',
      action: 'pull_to_refresh',
      extra: {'count': list.length},
    );
  }

  void _applyFilters() {
    final filtered = _stories.where((story) {
      if (_showOnlyFavorites && !story.isFavorite) return false;
      if (_showOnlyInteractive && !story.isInteractive) return false;
      if (_selectedThemeFilter != 'All' && story.theme != _selectedThemeFilter) {
        return false;
      }
      return true;
    }).toList();

    filtered.sort((a, b) {
      switch (_currentSort) {
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

    _filteredStories = filtered;
  }

  Future<void> _toggleFavorite(int index) async {
    final story = _filteredStories[index];
    await _storage.toggleFavorite(story.id);
    await _refresh();
  }

  Future<void> _deleteAt(int index) async {
    await _storage.deleteStoryAt(index);
    await _refresh();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Story deleted')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final favoriteCount = _stories.where((s) => s.isFavorite).length;

    return Scaffold(
      appBar: AppBar(
        title: const Text('My Stories'),
        actions: [
          IconButton(
            icon: Icon(
              _showOnlyFavorites ? Icons.favorite : Icons.favorite_border,
              color: _showOnlyFavorites ? Colors.red : null,
            ),
            tooltip: _showOnlyFavorites ? 'Show all stories' : 'Show favorites only',
            onPressed: () {
              setState(() {
                _showOnlyFavorites = !_showOnlyFavorites;
                _applyFilters();
              });
            },
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _stories.isEmpty
              ? const Center(child: Text('No stories saved yet.'))
              : RefreshIndicator(
                  onRefresh: _refresh,
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
                                        final isSelected = _selectedThemeFilter == theme;
                                        return Padding(
                                          padding: const EdgeInsets.only(right: 8.0),
                                          child: FilterChip(
                                            label: Text(theme),
                                            selected: isSelected,
                                            onSelected: (selected) {
                                              setState(() {
                                                _selectedThemeFilter = theme;
                                                _applyFilters();
                                              });
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
                                  selected: _showOnlyFavorites,
                                  onSelected: (selected) {
                                    setState(() {
                                      _showOnlyFavorites = selected;
                                      _applyFilters();
                                    });
                                  },
                                ),
                                const SizedBox(width: 8),
                                FilterChip(
                                  label: const Text('Interactive'),
                                  selected: _showOnlyInteractive,
                                  onSelected: (selected) {
                                    setState(() {
                                      _showOnlyInteractive = selected;
                                      _applyFilters();
                                    });
                                  },
                                ),
                                const Spacer(),
                                DropdownButton<SortOption>(
                                  value: _currentSort,
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
                                    setState(() {
                                      _currentSort = value;
                                      _applyFilters();
                                    });
                                  },
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),

                      // Stats row
                      if (_stories.isNotEmpty)
                        Container(
                          padding: const EdgeInsets.all(8),
                          color: Colors.deepPurple.shade50,
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceAround,
                            children: [
                              _buildStat(Icons.book, '${_stories.length}', 'Total'),
                              _buildStat(Icons.favorite, '$favoriteCount', 'Favorites'),
                              _buildStat(Icons.visibility, '${_filteredStories.length}', 'Showing'),
                            ],
                          ),
                        ),

                      if (_filteredStories.isEmpty)
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
                                  setState(() {
                                    _showOnlyFavorites = false;
                                    _selectedThemeFilter = 'All';
                                    _applyFilters();
                                  });
                                },
                                child: const Text('Clear Filters'),
                              ),
                            ],
                          ),
                        )
                      else
                        ..._filteredStories.map((s) {
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
                              key: ValueKey(s.id),
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
                                final originalIndex = _stories.indexOf(s);
                                await _deleteAt(originalIndex);
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
                                            onPressed: () => _toggleFavorite(_filteredStories.indexOf(s)),
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
                                            onPressed: _isReporting
                                                ? null
                                                : () => _reportStory(s),
                                            icon: const Icon(Icons.flag_outlined),
                                            label: const Text('Report'),
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
                                                    storyId: s.id,
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
                                              final originalIndex = _stories.indexOf(s);
                                              _deleteAt(originalIndex);
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
    // Simple friendly date
    return '${_two(d.month)}/${_two(d.day)}/${d.year} ${_two(d.hour)}:${_two(d.minute)}';
    // You can also use intl if you prefer: DateFormat.yMMMd().add_jm().format(d)
  }

  String _two(int n) => n.toString().padLeft(2, '0');

  int _wordCount(String text) {
    return text
        .split(RegExp(r'\s+'))
        .where((word) => word.isNotEmpty)
        .length;
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

  Future<void> _shareStory(SavedStory story) async {
    final shareText = '${story.title}\n\n${story.storyText}';
    await Share.share(shareText, subject: story.title);
  }

  Future<String?> _showReportDialog(String title) async {
    _reportController.clear();
    return showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Report Issue'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Report content in "$title"'),
            const SizedBox(height: 12),
            TextField(
              controller: _reportController,
              maxLines: 3,
              decoration: const InputDecoration(
                hintText: 'Optional: describe what felt wrong',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, _reportController.text.trim()),
            child: const Text('Report'),
          ),
        ],
      ),
    );
  }

  Future<void> _reportStory(SavedStory story) async {
    final reason = await _showReportDialog(story.title);
    if (reason == null) return;
    if (_isReporting) return;
    setState(() => _isReporting = true);
    try {
      final uri = Uri.parse('${Environment.backendUrl}/report-story');
      final response = await http.post(
        uri,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'story_id': story.id,
          'title': story.title,
          'theme': story.theme,
          'reason': reason.isEmpty ? 'No reason provided' : reason,
          'is_interactive': story.isInteractive,
          'story_preview': story.storyText.length > 240
              ? '${story.storyText.substring(0, 240)}...'
              : story.storyText,
          'timestamp': DateTime.now().toIso8601String(),
        }),
      );

      if (!mounted) return;
      if (response.statusCode >= 200 && response.statusCode < 300) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Report submitted. Thank you for keeping stories safe.'),
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not submit report. Please try again.')),
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Report failed. Please try again later.')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isReporting = false);
      }
    }
  }
}
