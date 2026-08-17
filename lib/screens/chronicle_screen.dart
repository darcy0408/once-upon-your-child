import 'dart:convert';

import 'package:flutter/material.dart';

import '../data/band_story_defaults.dart';
import '../models.dart';
import '../models/local/chapter_memory_local.dart';
import '../models/local/chronicle_local.dart';
import '../pick_a_path_adventure_screen.dart';
import '../services/chronicle_service.dart';
import '../theme/app_theme.dart';
import '../widgets/app_button.dart';

/// Displays one Living Story Chronicle: the chapter log and a "Start Next Chapter" button.
class ChronicleScreen extends StatefulWidget {
  const ChronicleScreen({
    super.key,
    required this.chronicle,
    required this.character,
    required this.userId,
  });

  final ChronicleLocal chronicle;
  final Character character;
  final String userId;

  @override
  State<ChronicleScreen> createState() => _ChronicleScreenState();
}

class _ChronicleScreenState extends State<ChronicleScreen> {
  late ChronicleLocal _chronicle;
  List<ChapterMemoryLocal> _memories = [];
  bool _loading = true;

  String get _screenTitle {
    final age = widget.character.age;
    if (age <= 5) return 'Our Story! 📖';
    if (age <= 7) return 'My Adventure Book';
    if (age <= 10) return 'My Chronicle';
    return _chronicle.title;
  }

  String get _chapterCountLabel {
    final count = _chronicle.chapterCount;
    final age = widget.character.age;
    if (count == 0) {
      return age <= 5 ? 'Ready to begin! ✨' : 'No chapters yet — start your first!';
    }
    return '$count chapter${count == 1 ? '' : 's'} completed';
  }

  String get _chapterCtaLabel {
    final age = widget.character.age;
    final next = _chronicle.chapterCount + 1;
    if (age <= 5) return next == 1 ? 'Start our story! 🌟' : 'Keep going! ➡️';
    if (age <= 7) return next == 1 ? 'Begin the adventure!' : 'Next chapter! 🎉';
    if (age <= 10) return next == 1 ? 'Start Chapter 1' : 'Start Chapter $next';
    return next == 1 ? 'Begin Chronicle' : 'Continue — Chapter $next';
  }

  @override
  void initState() {
    super.initState();
    _chronicle = widget.chronicle;
    _loadData();
  }

  Future<void> _loadData() async {
    final memories =
        await ChronicleService.getChapterMemories(_chronicle.chronicleId);
    final fresh =
        await ChronicleService.getChronicle(_chronicle.chronicleId);
    if (!mounted) return;
    setState(() {
      _memories = memories;
      if (fresh != null) _chronicle = fresh;
      _loading = false;
    });
  }

  Future<void> _startNextChapter() async {
    final result = await Navigator.of(context).push<String>(
      MaterialPageRoute(
        builder: (_) => PickAPathAdventureScreen(
          userId: widget.userId,
          character: widget.character,
          theme: _chronicle.genre,
          // Was hardcoded 'whimsical', so a 16-year-old's next chapter was
          // generated in the same register as a 4-year-old's.
          tone: storyToneForAge(widget.character.age),
          // 'medium' stays a deliberate chapter default: unlike the wizard
          // there is no user length choice here, and the backend already caps
          // words per band, so this reads age-appropriately without a second
          // band map.
          length: 'medium',
          chronicleId: _chronicle.chronicleId,
        ),
      ),
    );

    // Refresh after returning from the chapter
    if (mounted) {
      await _loadData();
      if (result == 'chapter_complete' && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Chapter saved to your Chronicle!'),
            duration: Duration(seconds: 3),
          ),
        );
      }
    }
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
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildHeader(),
          const SizedBox(height: 20),
          AppButton.primary(
            label: _chapterCtaLabel,
            icon: Icons.menu_book,
            onPressed: _startNextChapter,
          ),
          const SizedBox(height: 24),
          _buildChapterLog(_memories),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              _chronicle.characterName,
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              _chapterCountLabel,
              style: TextStyle(color: Colors.grey[600]),
            ),
            if (_chronicle.lastChapterEnding != null) ...[
              const SizedBox(height: 8),
              Text(
                '"${_chronicle.lastChapterEnding}"',
                style: const TextStyle(
                  fontStyle: FontStyle.italic,
                  fontSize: 14,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildChapterLog(List<ChapterMemoryLocal> memories) {
    final age = widget.character.age;
    if (age <= 5) return _buildSproutEmojiTrail(memories);
    if (age <= 7) return _buildExplorerCardLog(memories);
    return _buildFullChapterLog(memories);
  }

  Widget _buildSproutEmojiTrail(List<ChapterMemoryLocal> memories) {
    if (memories.isEmpty) {
      return const Padding(
        padding: EdgeInsets.all(24),
        child: Text(
          'Your adventure trail will appear here! 🌱',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 18, color: Colors.white70),
        ),
      );
    }

    const emojis = ['🌟', '🏰', '🐉', '🗺️', '⚔️', '🌊', '🔮', '🦋', '🌋', '🏆'];
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: memories.asMap().entries.expand((entry) {
          final idx = entry.key;
          final memory = entry.value;
          final emoji = emojis[idx % emojis.length];
          return [
            GestureDetector(
              onTap: () => _showChapterDetail(memory),
              child: Column(
                children: [
                  Container(
                    width: 72,
                    height: 72,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: const LinearGradient(
                        colors: [Color(0xFF7B2FBE), Color(0xFF9B59B6)],
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.purple.withValues(alpha: 0.4),
                          blurRadius: 8,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Center(
                      child: Text(emoji, style: const TextStyle(fontSize: 32)),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Ch. ${memory.chapterNumber}',
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
            if (idx < memories.length - 1)
              Padding(
                padding: const EdgeInsets.only(bottom: 24),
                child: Row(
                  children: List.generate(
                    4,
                    (_) => Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 3),
                      child: Container(
                        width: 6,
                        height: 6,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.white.withValues(alpha: 0.3),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
          ];
        }).toList(),
      ),
    );
  }

  Widget _buildExplorerCardLog(List<ChapterMemoryLocal> memories) {
    if (memories.isEmpty) {
      return const Padding(
        padding: EdgeInsets.all(24),
        child: Text(
          'Your chapters will appear here! ✨',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 16, color: Colors.white70),
        ),
      );
    }

    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: memories.length,
      itemBuilder: (context, idx) {
        final memory = memories[idx];
        return GestureDetector(
          onTap: () => _showChapterDetail(memory),
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.purple.withValues(alpha: 0.3)),
            ),
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    color: Color(0xFF7B2FBE),
                  ),
                  child: Center(
                    child: Text(
                      '${memory.chapterNumber}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Text(
                    memory.cliffhanger ?? 'Adventure continues...',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      height: 1.4,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const Icon(Icons.chevron_right_rounded, color: Colors.white38),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildFullChapterLog(List<ChapterMemoryLocal> memories) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Chapter Log',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        ...memories.reversed.map((mem) => _buildMemoryCard(mem)),
      ],
    );
  }

  Widget _buildMemoryCard(ChapterMemoryLocal mem) {
    final bullets = _decodeStringList(mem.summaryBulletsJson);
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ExpansionTile(
        title: Text(
          'Chapter ${mem.chapterNumber}',
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: mem.cliffhanger != null
            ? Text(
                mem.cliffhanger!,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontStyle: FontStyle.italic, fontSize: 12),
              )
            : null,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (mem.choiceMadeToStartChapter != null) ...[
                  Text(
                    'Started with: "${mem.choiceMadeToStartChapter}"',
                    style: TextStyle(
                        color: Colors.deepPurple[700], fontSize: 13),
                  ),
                  const SizedBox(height: 8),
                ],
                ...bullets.map(
                  (b) => Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('• ',
                            style: TextStyle(fontWeight: FontWeight.bold)),
                        Expanded(child: Text(b, style: const TextStyle(fontSize: 14))),
                      ],
                    ),
                  ),
                ),
                if (mem.characterGrowthNote != null) ...[
                  const SizedBox(height: 8),
                  Text(
                    'Growth: ${mem.characterGrowthNote}',
                    style: TextStyle(
                        color: Colors.green[700],
                        fontSize: 13,
                        fontStyle: FontStyle.italic),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _showChapterDetail(ChapterMemoryLocal memory) {
    final age = widget.character.age;
    final isSprout = age <= 5;
    final bullets = _decodeStringList(memory.summaryBulletsJson);

    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1E0538),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              isSprout
                  ? 'Chapter ${memory.chapterNumber} 🌟'
                  : 'Chapter ${memory.chapterNumber}',
              style: TextStyle(
                color: Colors.white,
                fontSize: isSprout ? 24 : 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            ...bullets.map(
              (b) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      isSprout ? '⭐ ' : '• ',
                      style: const TextStyle(color: Colors.amber, fontSize: 16),
                    ),
                    Expanded(
                      child: Text(
                        b,
                        style: TextStyle(
                          color: Colors.white70,
                          fontSize: isSprout ? 16 : 14,
                          height: 1.5,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            if (memory.cliffhanger != null) ...[
              const SizedBox(height: 12),
              Text(
                age <= 7 ? 'And then...' : 'Cliffhanger:',
                style: const TextStyle(
                  color: Colors.amber,
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                memory.cliffhanger!,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: isSprout ? 16 : 14,
                  fontStyle: FontStyle.italic,
                ),
              ),
            ],
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  static List<String> _decodeStringList(String? jsonStr) {
    if (jsonStr == null || jsonStr.isEmpty) return [];
    try {
      final decoded = jsonDecode(jsonStr);
      if (decoded is List) return decoded.cast<String>();
    } catch (_) {}
    return [];
  }
}
