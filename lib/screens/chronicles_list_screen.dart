import 'package:flutter/material.dart';

import '../models.dart';
import '../models/local/chronicle_local.dart';
import '../services/chronicle_service.dart';
import '../theme/app_theme.dart';
import '../widgets/app_button.dart';
import 'chronicle_screen.dart';

/// Lists all Living Story Chronicles for the current character and lets the
/// user create a new one or continue an existing one.
class ChroniclesListScreen extends StatefulWidget {
  const ChroniclesListScreen({
    super.key,
    required this.character,
    required this.userId,
  });

  final Character character;
  final String userId;

  @override
  State<ChroniclesListScreen> createState() => _ChroniclesListScreenState();
}

class _ChroniclesListScreenState extends State<ChroniclesListScreen> {
  List<ChronicleLocal> _chronicles = [];
  bool _loading = true;

  String get _screenTitle {
    final age = widget.character.age;
    if (age <= 5) return 'Our Stories 📚';
    if (age <= 7) return 'My Adventure Books';
    if (age <= 10) return 'My Chronicles';
    return 'Chronicles';
  }

  String get _emptyState {
    final age = widget.character.age;
    if (age <= 5) return 'No stories yet!\nStart a new one! 🌟';
    if (age <= 7) return 'No adventures yet!\nStart your first chapter!';
    if (age <= 10) return 'No chronicles yet. Start your first!';
    return 'No chronicles yet.';
  }

  String get _newLabel {
    final age = widget.character.age;
    if (age <= 5) return 'Start a new story! ✨';
    if (age <= 7) return 'New adventure!';
    return 'New Chronicle';
  }

  @override
  void initState() {
    super.initState();
    _loadChronicles();
  }

  Future<void> _loadChronicles() async {
    final list = await ChronicleService.getChroniclesForCharacter(
        widget.character.id);
    if (!mounted) return;
    setState(() {
      _chronicles = list;
      _loading = false;
    });
  }

  Future<void> _createNewChronicle() async {
    // Ask user for a chronicle title and genre
    final result = await showDialog<Map<String, String>>(
      context: context,
      builder: (ctx) => _NewChronicleDialog(
          characterName: widget.character.name),
    );
    if (result == null) return;

    final chronicle = await ChronicleService.createChronicle(
      characterId: widget.character.id,
      characterName: widget.character.name,
      characterAge: widget.character.age,
      title: result['title']!,
      genre: result['genre']!,
    );

    if (!mounted) return;
    await _navigateToChronicle(chronicle);
  }

  Future<void> _navigateToChronicle(ChronicleLocal chronicle) async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ChronicleScreen(
          chronicle: chronicle,
          character: widget.character,
          userId: widget.userId,
        ),
      ),
    );
    if (mounted) await _loadChronicles();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_screenTitle),
        backgroundColor: Colors.deepPurple,
        foregroundColor: Colors.white,
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: AppGradients.magicalBackground,
        ),
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : _buildBody(),
      ),
    );
  }

  Widget _buildBody() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AppButton.primary(
            label: _newLabel,
            icon: Icons.add,
            onPressed: _createNewChronicle,
          ),
          const SizedBox(height: 24),
          if (_chronicles.isEmpty)
            Center(
              child: Text(
                _emptyState,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 16, color: Colors.white70),
              ),
            )
          else
            Expanded(
              child: ListView.builder(
                itemCount: _chronicles.length,
                itemBuilder: (ctx, i) {
                  final c = _chronicles[i];
                  final isOneChapter = c.chapterCount == 1;
                  return Card(
                    margin: const EdgeInsets.only(bottom: 12),
                    child: ListTile(
                      leading: const Icon(Icons.menu_book,
                          color: Colors.deepPurple),
                      title: Text(c.title,
                          style: const TextStyle(fontWeight: FontWeight.bold)),
                      subtitle: Text(
                        '${c.chapterCount} chapter${c.chapterCount == 1 ? '' : 's'} • ${c.genre}',
                      ),
                      trailing: isOneChapter
                          ? Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 10, vertical: 5),
                              decoration: BoxDecoration(
                                color: Colors.deepPurple.withAlpha(25),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                    color: Colors.deepPurple.withAlpha(80)),
                              ),
                              child: const Text(
                                'Start Chapter 2! ✨',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.deepPurple,
                                ),
                              ),
                            )
                          : const Icon(Icons.arrow_forward_ios, size: 16),
                      onTap: () => _navigateToChronicle(c),
                    ),
                  );
                },
              ),
            ),
        ],
      ),
    );
  }
}

/// Simple dialog to collect chronicle title and genre.
class _NewChronicleDialog extends StatefulWidget {
  const _NewChronicleDialog({required this.characterName});
  final String characterName;

  @override
  State<_NewChronicleDialog> createState() => _NewChronicleDialogState();
}

class _NewChronicleDialogState extends State<_NewChronicleDialog> {
  final _titleController = TextEditingController();
  String _genre = 'Fantasy';

  static const _genres = [
    'Fantasy',
    'Sci-Fi',
    'Mystery',
    'Adventure',
    'Magic',
  ];

  @override
  void initState() {
    super.initState();
    _titleController.text = '${widget.characterName}\'s Chronicle';
  }

  @override
  void dispose() {
    _titleController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('New Chronicle'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _titleController,
            decoration: const InputDecoration(labelText: 'Title'),
            maxLength: 60,
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            initialValue: _genre,
            decoration: const InputDecoration(labelText: 'Genre'),
            items: _genres
                .map((g) =>
                    DropdownMenuItem(value: g, child: Text(g)))
                .toList(),
            onChanged: (v) => setState(() => _genre = v ?? 'Fantasy'),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: () {
            final title = _titleController.text.trim();
            if (title.isEmpty) return;
            Navigator.of(context).pop({'title': title, 'genre': _genre});
          },
          child: const Text('Create'),
        ),
      ],
    );
  }
}
