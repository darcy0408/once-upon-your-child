import 'package:flutter/material.dart';
import 'models.dart';
import 'storage_service.dart';
import 'story_result_screen.dart';

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

  @override
  void initState() {
    super.initState();
    _refresh();
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
  }

  void _applyFilters() {
    _filteredStories = _stories.where((story) {
      if (_showOnlyFavorites && !story.isFavorite) return false;
      if (_selectedThemeFilter != 'All' && story.theme != _selectedThemeFilter) return false;
      return true;
    }).toList();
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
    final themes = ['All', 'Adventure', 'Friendship', 'Magic', 'Dragons', 'Castles', 'Unicorns', 'Space', 'Ocean', 'Family', 'Teamwork', 'Courage'];
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
              : Column(
                  children: [
                    // Filter bar
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      color: Colors.grey.shade100,
                      child: Row(
                        children: [
                          const Text('Theme:', style: TextStyle(fontWeight: FontWeight.w600)),
                          const SizedBox(width: 12),
                          Expanded(
                            child: SingleChildScrollView(
                              scrollDirection: Axis.horizontal,
                              child: Row(
                                children: themes.map((theme) {
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

                    // Stories list
                    Expanded(
                      child: _filteredStories.isEmpty
                          ? Center(
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
                          : RefreshIndicator(
                              onRefresh: _refresh,
                              child: ListView.separated(
                                padding: const EdgeInsets.all(12),
                                itemCount: _filteredStories.length,
                                separatorBuilder: (_, __) => const SizedBox(height: 12),
                                itemBuilder: (context, index) {
                                              final s = _filteredStories[index];
                                  final dateStr = _prettyDate(s.createdAt);
                                  final childNames = s.characters.map((c) => c.name).toList();

                                  return Card(
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
                                              IconButton(
                                                tooltip: s.isFavorite ? 'Remove from favorites' : 'Add to favorites',
                                                icon: Icon(
                                                  s.isFavorite ? Icons.favorite : Icons.favorite_border,
                                                  color: s.isFavorite ? Colors.red : null,
                                                ),
                                                onPressed: () => _toggleFavorite(index),
                                              ),
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
                                          const SizedBox(height: 6),

                                          // Meta line
                                          Text(
                                            '$dateStr • Theme: ${s.theme}',
                                            style: TextStyle(
                                              color: Colors.grey.shade700,
                                              fontStyle: FontStyle.italic,
                                            ),
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
                                            s.storyText.length > 160
                                                ? '${s.storyText.substring(0, 160)}…'
                                                : s.storyText,
                                          ),
                                          const SizedBox(height: 10),

                                          // Open button
                                          Align(
                                            alignment: Alignment.centerRight,
                                            child: ElevatedButton.icon(
                                              icon: const Icon(Icons.open_in_new),
                                              label: const Text('Open'),
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
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  );
                                },
                              ),
                            ),
                    ),
                  ],
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
}
