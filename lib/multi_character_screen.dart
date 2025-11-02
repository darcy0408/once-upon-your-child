import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import 'models.dart';
import 'story_result_screen.dart';

class MultiCharacterScreen extends StatefulWidget {
  const MultiCharacterScreen({super.key});

  @override
  State<MultiCharacterScreen> createState() => _MultiCharacterScreenState();
}

class _MultiCharacterScreenState extends State<MultiCharacterScreen> {
  List<Character> _all = [];
  final Set<String> _selectedIds = <String>{};
  String? _mainId;
  String _theme = 'Friendship';
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _loadCharacters();
  }

  Future<void> _loadCharacters() async {
    try {
      final url = Uri.parse('http://127.0.0.1:5000/get-characters');
      final resp = await http.get(url);
      if (resp.statusCode == 200) {
        // Your backend may return either a list or {items:[...]}
        final decoded = jsonDecode(resp.body);
        final List list = (decoded is List) ? decoded : (decoded['items'] as List);
        final chars = list.map((j) => Character.fromJson(j)).toList().cast<Character>();
        setState(() => _all = chars);
      } else {
        _snack('Could not load characters (${resp.statusCode}).');
      }
    } catch (e) {
      _snack('Network error loading characters.');
    }
  }

  void _toggleSelected(String id) {
    setState(() {
      if (_selectedIds.contains(id)) {
        _selectedIds.remove(id);
        if (_mainId == id) _mainId = _selectedIds.isEmpty ? null : _selectedIds.first;
      } else {
        _selectedIds.add(id);
        _mainId ??= id; // first selected becomes main by default
      }
    });
  }

  Future<void> _generateGroupStory() async {
    if (_selectedIds.isEmpty) {
      _snack('Pick at least one child.');
      return;
    }
    if (_mainId == null) {
      _snack('Choose a main child (tap the star on one kid).');
      return;
    }

    setState(() => _loading = true);
    try {
      final url = Uri.parse('http://127.0.0.1:5000/generate-multi-character-story');
      final body = {
        'character_ids': _selectedIds.toList(),
        'main_character_id': _mainId,
        'theme': _theme,
      };

      final resp = await http.post(
        url,
        headers: {'Content-Type': 'application/json; charset=UTF-8'},
        body: jsonEncode(body),
      );

      if (!mounted) return;

      if (resp.statusCode == 200) {
        final data = jsonDecode(resp.body) as Map<String, dynamic>;
        final storyText = (data['story'] ?? '') as String;

        // Optional: Generate a title from the kids' names
        final main = _all.firstWhere((c) => c.id == _mainId);
        final others = _all.where((c) => _selectedIds.contains(c.id) && c.id != _mainId).map((c) => c.name).toList();
        final title = others.isEmpty
            ? 'A ${_theme} Adventure with ${main.name}'
            : 'A ${_theme} Adventure with ${main.name} & ${others.join(", ")}';

        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => StoryResultScreen(
              title: title,
              storyText: storyText,
              wisdomGem: '', // multi-character endpoint returns just 'story'; you can add wisdom if you want
            ),
          ),
        );
      } else {
        _snack('Server error: ${resp.statusCode}');
      }
    } catch (e) {
      _snack('Network error creating story.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _snack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  @override
  Widget build(BuildContext context) {
    final themeOptions = const [
      'Friendship',
      'Adventure',
      'Magic',
      'Family',
      'Teamwork',
      'Courage',
    ];

    return Scaffold(
      appBar: AppBar(title: const Text('Group Story')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // Theme picker
            Row(
              children: [
                const Text('Theme:', style: TextStyle(fontWeight: FontWeight.w600)),
                const SizedBox(width: 12),
                DropdownButton<String>(
                  value: _theme,
                  items: themeOptions.map((t) => DropdownMenuItem(value: t, child: Text(t))).toList(),
                  onChanged: (v) => setState(() => _theme = v ?? _theme),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Characters grid
            Expanded(
              child: _all.isEmpty
                  ? const Center(child: Text('No saved children yet. Create some first!'))
                  : GridView.builder(
                      itemCount: _all.length,
                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 2,
                        mainAxisSpacing: 12,
                        crossAxisSpacing: 12,
                        childAspectRatio: 1.6,
                      ),
                      itemBuilder: (_, i) {
                        final c = _all[i];
                        final selected = _selectedIds.contains(c.id);
                        final isMain = _mainId == c.id;
                        return InkWell(
                          onTap: () => _toggleSelected(c.id),
                          borderRadius: BorderRadius.circular(12),
                          child: Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: selected ? Colors.deepPurple : Colors.grey.shade300,
                                width: selected ? 2 : 1,
                              ),
                            ),
                            child: Stack(
                              children: [
                                Positioned(
                                  right: 0,
                                  top: 0,
                                  child: IconButton(
                                    tooltip: isMain ? 'Main child' : 'Set as main child',
                                    icon: Icon(
                                      isMain ? Icons.star : Icons.star_border,
                                      color: isMain ? Colors.amber : Colors.grey,
                                    ),
                                    onPressed: () {
                                      setState(() {
                                        if (!_selectedIds.contains(c.id)) {
                                          _selectedIds.add(c.id);
                                        }
                                        _mainId = c.id;
                                      });
                                    },
                                  ),
                                ),
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Text(
                                      c.name,
                                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    const SizedBox(height: 6),
                                    Text('Age: ${c.age}'),
                                    if (c.role != null && c.role!.isNotEmpty)
                                      Text('Role: ${c.role}', overflow: TextOverflow.ellipsis),
                                    if ((c.magicType ?? '').isNotEmpty)
                                      Text('Magic: ${c.magicType}', overflow: TextOverflow.ellipsis),
                                    const Spacer(),
                                    Row(
                                      children: [
                                        Checkbox(
                                          value: selected,
                                          onChanged: (_) => _toggleSelected(c.id),
                                        ),
                                        const Text('Include'),
                                      ],
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
            ),

            const SizedBox(height: 12),

            // Generate button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _loading ? null : _generateGroupStory,
                icon: _loading
                    ? const SizedBox(
                        width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                    : const Icon(Icons.auto_stories),
                label: Text(_loading ? 'Creating...' : 'Create Group Story'),
                style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 14)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
