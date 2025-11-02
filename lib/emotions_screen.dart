// lib/emotions_screen.dart

import 'package:flutter/material.dart';
import 'emotions_learning_system.dart';
import 'dart:math' as math;

class EmotionsScreen extends StatefulWidget {
  const EmotionsScreen({super.key});

  @override
  State<EmotionsScreen> createState() => _EmotionsScreenState();
}

class _EmotionsScreenState extends State<EmotionsScreen> with SingleTickerProviderStateMixin {
  final _service = EmotionsLearningService();
  List<EmotionCheckIn> _recentCheckIns = [];
  List<String> _learnedEmotions = [];
  Map<String, int> _emotionStats = {};
  bool _isLoading = true;
  TabController? _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _loadData();
  }

  @override
  void dispose() {
    _tabController?.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    final checkIns = await _service.getRecentCheckIns();
    final learned = await _service.getLearnedEmotions();
    final stats = await _service.getEmotionStats();

    setState(() {
      _recentCheckIns = checkIns;
      _learnedEmotions = learned;
      _emotionStats = stats;
      _isLoading = false;
    });
  }

  Future<void> _showCheckInDialog() async {
    Emotion? selectedEmotion;
    int intensity = 3;
    final whatHappenedController = TextEditingController();

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('How are you feeling? 💭'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Choose your emotion:', style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 16),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: _service.getAllEmotions().map((emotion) {
                    final isSelected = selectedEmotion?.id == emotion.id;
                    return GestureDetector(
                      onTap: () {
                        setDialogState(() => selectedEmotion = emotion);
                      },
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: isSelected ? emotion.color.withOpacity(0.3) : Colors.grey.shade100,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: isSelected ? emotion.color : Colors.transparent,
                            width: 2,
                          ),
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(emotion.emoji, style: const TextStyle(fontSize: 24)),
                            Text(emotion.name, style: const TextStyle(fontSize: 10)),
                          ],
                        ),
                      ),
                    );
                  }).toList(),
                ),
                if (selectedEmotion != null) ...[
                  const SizedBox(height: 24),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: selectedEmotion!.color.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${selectedEmotion!.emoji} ${selectedEmotion!.name}',
                          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 8),
                        Text(selectedEmotion!.description),
                        const SizedBox(height: 8),
                        Text(
                          'Your body might feel: ${selectedEmotion!.physicalSigns}',
                          style: const TextStyle(fontSize: 12, fontStyle: FontStyle.italic),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text('How strong is this feeling?', style: TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      const Text('Mild'),
                      Expanded(
                        child: Slider(
                          value: intensity.toDouble(),
                          min: 1,
                          max: 5,
                          divisions: 4,
                          label: intensity.toString(),
                          onChanged: (value) {
                            setDialogState(() => intensity = value.toInt());
                          },
                        ),
                      ),
                      const Text('Strong'),
                    ],
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: whatHappenedController,
                    decoration: const InputDecoration(
                      labelText: 'What happened? (optional)',
                      border: OutlineInputBorder(),
                      hintText: 'Tell us what made you feel this way...',
                    ),
                    maxLines: 2,
                  ),
                ],
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: selectedEmotion == null
                  ? null
                  : () => Navigator.pop(context, true),
              child: const Text('Save Check-In'),
            ),
          ],
        ),
      ),
    );

    if (confirmed == true && selectedEmotion != null) {
      final checkIn = EmotionCheckIn(
        emotionId: selectedEmotion!.id,
        intensity: intensity,
        whatHappened: whatHappenedController.text.trim().isEmpty
            ? null
            : whatHappenedController.text.trim(),
        timestamp: DateTime.now(),
      );

      await _service.recordCheckIn(checkIn);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('✅ Check-in saved! ${selectedEmotion!.emoji}'),
            backgroundColor: Colors.green,
          ),
        );

        // Show coping strategies
        _showCopingStrategies(selectedEmotion!);
        _loadData();
      }
    }
  }

  void _showCopingStrategies(Emotion emotion) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('${emotion.emoji} Coping Strategies'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'When you feel ${emotion.name}, here are things that can help:',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            ...emotion.copingStrategies.map((strategy) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('• ', style: TextStyle(fontSize: 18)),
                  Expanded(child: Text(strategy)),
                ],
              ),
            )),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Got it!'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(title: const Text('Feelings Helper')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Feelings Helper 💭'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(icon: Icon(Icons.favorite), text: 'Check-In'),
            Tab(icon: Icon(Icons.school), text: 'Learn'),
            Tab(icon: Icon(Icons.timeline), text: 'My Feelings'),
            Tab(icon: Icon(Icons.tips_and_updates), text: 'Coping'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildCheckInTab(),
          _buildLearnTab(),
          _buildMyFeelingsTab(),
          _buildCopingTab(),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showCheckInDialog,
        icon: const Icon(Icons.add_circle),
        label: const Text('How do I feel?'),
      ),
    );
  }

  Widget _buildCheckInTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Card(
            color: Colors.blue.shade50,
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  const Icon(Icons.favorite, size: 60, color: Colors.red),
                  const SizedBox(height: 16),
                  const Text(
                    'Welcome to your Feelings Helper!',
                    style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'All feelings are okay! This space helps you understand and work with your emotions.',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 14),
                  ),
                  const SizedBox(height: 20),
                  ElevatedButton.icon(
                    onPressed: _showCheckInDialog,
                    icon: const Icon(Icons.add),
                    label: const Text('Check In Now'),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),
          if (_recentCheckIns.isNotEmpty) ...[
            const Text(
              'Recent Check-Ins',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            ..._recentCheckIns.reversed.take(5).map((checkIn) {
              final emotion = _service.getEmotionById(checkIn.emotionId);
              if (emotion == null) return const SizedBox.shrink();

              return Card(
                child: ListTile(
                  leading: Text(emotion.emoji, style: const TextStyle(fontSize: 32)),
                  title: Text('${emotion.name} (Intensity: ${checkIn.intensity}/5)'),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(_formatDate(checkIn.timestamp)),
                      if (checkIn.whatHappened != null)
                        Text(checkIn.whatHappened!, style: const TextStyle(fontStyle: FontStyle.italic)),
                    ],
                  ),
                  trailing: IconButton(
                    icon: const Icon(Icons.lightbulb),
                    onPressed: () => _showCopingStrategies(emotion),
                    tooltip: 'See coping strategies',
                  ),
                ),
              );
            }),
          ] else ...[
            const Card(
              child: Padding(
                padding: EdgeInsets.all(20),
                child: Text(
                  'No check-ins yet! Tap the button above to record how you\'re feeling.',
                  textAlign: TextAlign.center,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildLearnTab() {
    final emotionsByCategory = <EmotionCategory, List<Emotion>>{};
    for (final category in EmotionCategory.values) {
      emotionsByCategory[category] = _service.getEmotionsByCategory(category);
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Learn About Emotions',
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          const Text(
            'Tap any emotion to learn more about it!',
            style: TextStyle(color: Colors.grey),
          ),
          const SizedBox(height: 20),
          ...emotionsByCategory.entries.map((entry) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  child: Row(
                    children: [
                      Container(
                        width: 4,
                        height: 24,
                        color: EmotionWheel.categoryColors[entry.key],
                      ),
                      const SizedBox(width: 8),
                      Text(
                        EmotionWheel.categoryNames[entry.key]!,
                        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                ),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: entry.value.map((emotion) {
                    final isLearned = _learnedEmotions.contains(emotion.id);
                    return GestureDetector(
                      onTap: () => _showEmotionDetails(emotion),
                      child: Container(
                        width: 100,
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: emotion.color.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: emotion.color,
                            width: 2,
                          ),
                        ),
                        child: Column(
                          children: [
                            Text(emotion.emoji, style: const TextStyle(fontSize: 32)),
                            const SizedBox(height: 4),
                            Text(
                              emotion.name,
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                              textAlign: TextAlign.center,
                            ),
                            if (isLearned)
                              const Icon(Icons.check_circle, size: 16, color: Colors.green),
                          ],
                        ),
                      ),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 16),
              ],
            );
          }),
        ],
      ),
    );
  }

  void _showEmotionDetails(Emotion emotion) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('${emotion.emoji} ${emotion.name}'),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildInfoSection('What it means', emotion.description),
              const SizedBox(height: 16),
              _buildInfoSection('How your body might feel', emotion.physicalSigns),
              const SizedBox(height: 16),
              const Text('What can help:', style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              ...emotion.copingStrategies.map((strategy) => Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('✓ ', style: TextStyle(color: Colors.green, fontSize: 18)),
                    Expanded(child: Text(strategy)),
                  ],
                ),
              )),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _showCheckInDialog();
            },
            child: const Text('I feel this now'),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoSection(String title, String content) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
        const SizedBox(height: 4),
        Text(content),
      ],
    );
  }

  Widget _buildMyFeelingsTab() {
    if (_emotionStats.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(20),
          child: Text(
            'Start checking in to see your emotion patterns!',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 16),
          ),
        ),
      );
    }

    final sortedStats = _emotionStats.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Your Emotion Journey',
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text(
            'You\'ve checked in ${_recentCheckIns.length} times in the last 7 days!',
            style: const TextStyle(color: Colors.grey),
          ),
          const SizedBox(height: 20),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Emotions You\'ve Experienced',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 16),
                  ...sortedStats.map((entry) {
                    final emotion = _service.getEmotionById(entry.key);
                    if (emotion == null) return const SizedBox.shrink();

                    final percentage = (entry.value / _recentCheckIns.length * 100).toStringAsFixed(0);

                    return Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text(emotion.emoji, style: const TextStyle(fontSize: 24)),
                              const SizedBox(width: 8),
                              Text(emotion.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                              const Spacer(),
                              Text('$percentage%'),
                            ],
                          ),
                          const SizedBox(height: 4),
                          LinearProgressIndicator(
                            value: entry.value / _recentCheckIns.length,
                            backgroundColor: Colors.grey.shade200,
                            color: emotion.color,
                            minHeight: 8,
                          ),
                        ],
                      ),
                    );
                  }),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),
          Text(
            'You\'ve learned about ${_learnedEmotions.length} emotions! 🎉',
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }

  Widget _buildCopingTab() {
    final emotionsByCategory = <EmotionCategory, List<Emotion>>{};
    for (final category in EmotionCategory.values) {
      emotionsByCategory[category] = _service.getEmotionsByCategory(category);
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Coping Strategies',
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          const Text(
            'Helpful tools for different emotions',
            style: TextStyle(color: Colors.grey),
          ),
          const SizedBox(height: 20),
          ...emotionsByCategory.entries.map((entry) {
            if (entry.value.isEmpty) return const SizedBox.shrink();

            return Card(
              color: EmotionWheel.categoryColors[entry.key]?.withOpacity(0.1),
              child: ExpansionTile(
                title: Text(
                  '${EmotionWheel.categoryNames[entry.key]} Emotions',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                children: entry.value.map((emotion) {
                  return Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(emotion.emoji, style: const TextStyle(fontSize: 24)),
                            const SizedBox(width: 8),
                            Text(emotion.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                          ],
                        ),
                        const SizedBox(height: 8),
                        ...emotion.copingStrategies.map((strategy) => Padding(
                          padding: const EdgeInsets.only(left: 16, bottom: 4),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Icon(Icons.check_circle, size: 16, color: Colors.green),
                              const SizedBox(width: 8),
                              Expanded(child: Text(strategy)),
                            ],
                          ),
                        )),
                        const Divider(),
                      ],
                    ),
                  );
                }).toList(),
              ),
            );
          }),
        ],
      ),
    );
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final diff = now.difference(date);

    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inHours < 1) return '${diff.inMinutes} minutes ago';
    if (diff.inDays < 1) return '${diff.inHours} hours ago';
    if (diff.inDays == 1) return 'Yesterday';
    if (diff.inDays < 7) return '${diff.inDays} days ago';

    return '${date.month}/${date.day}/${date.year}';
  }
}
