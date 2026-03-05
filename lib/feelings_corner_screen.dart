// lib/feelings_corner_screen.dart
// Optional feelings check-in screen - non-blocking, user-initiated

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

import 'feelings_wheel_data.dart';
import 'widgets/mood_magic_picker.dart';
import 'services/feelings_analytics_service.dart';

class FeelingsCornerScreen extends StatefulWidget {
  const FeelingsCornerScreen({
    super.key,
    this.characterAge,
  });

  final int? characterAge;

  @override
  State<FeelingsCornerScreen> createState() => _FeelingsCornerScreenState();
}

class _FeelingsCornerScreenState extends State<FeelingsCornerScreen> {
  SelectedFeeling? _selectedFeeling;
  FeelingSupportInfo? _supportInfo;
  FeelingDetail? _detail;
  int _intensity = 3;
  List<Map<String, dynamic>> _recentCheckIns = [];
  bool _dailyReminderEnabled = false;

  @override
  void initState() {
    super.initState();
    FeelingsAnalyticsService.trackScreenViewed();
    _loadRecentCheckIns();
    _loadReminderPreference();
    _loadSelectedFeeling();
  }

  Future<void> _loadSelectedFeeling() async {
    final prefs = await SharedPreferences.getInstance();
    final feelingJson = prefs.getString('selected_feeling');
    if (feelingJson != null) {
      setState(() {
        _selectedFeeling = SelectedFeeling.fromJson(jsonDecode(feelingJson));
      });
    }
  }

  Future<void> _loadRecentCheckIns() async {
    final prefs = await SharedPreferences.getInstance();
    final checkInsJson = prefs.getStringList('feelings_check_ins') ?? [];

    setState(() {
      _recentCheckIns = checkInsJson
          .map((json) => jsonDecode(json) as Map<String, dynamic>)
          .take(5)
          .toList();
    });
  }

  Future<void> _loadReminderPreference() async {
    final prefs = await SharedPreferences.getInstance();
    final enabled = prefs.getBool('feelings_daily_reminder') ?? false;
    if (mounted) {
      setState(() {
        _dailyReminderEnabled = enabled;
      });
    }
  }

  Future<void> _toggleReminder(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('feelings_daily_reminder', value);
    setState(() => _dailyReminderEnabled = value);
    await FeelingsAnalyticsService.trackReminderToggled(value);
  }

  Future<void> _saveSelectedFeeling() async {
    final prefs = await SharedPreferences.getInstance();
    if (_selectedFeeling == null) {
      await prefs.remove('selected_feeling');
    } else {
      await prefs.setString(
          'selected_feeling', jsonEncode(_selectedFeeling!.toJson()));
    }
  }

  Future<void> _saveCheckIn() async {
    if (_selectedFeeling == null) return;

    final checkIn = {
      'emotion': _selectedFeeling!.tertiary,
      'emoji': _selectedFeeling!.emoji,
      'core': _selectedFeeling!.core,
      'intensity': _intensity,
      'timestamp': DateTime.now().toIso8601String(),
    };

    final prefs = await SharedPreferences.getInstance();
    final checkInsJson = prefs.getStringList('feelings_check_ins') ?? [];
    checkInsJson.insert(0, jsonEncode(checkIn));

    // Keep only last 20 check-ins
    if (checkInsJson.length > 20) {
      checkInsJson.removeRange(20, checkInsJson.length);
    }

    await prefs.setStringList('feelings_check_ins', checkInsJson);

    await FeelingsAnalyticsService.trackCheckInLogged(
      emotion: _selectedFeeling!.tertiary,
      intensity: _intensity,
    );

    // Reload recent check-ins
    await _loadRecentCheckIns();

    // Show success message
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Feeling logged! 💜'),
          backgroundColor: Colors.purple,
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  void _onMoodSelected(MoodSelection mood) {
    final feeling = SelectedFeeling(
      core: mood.moodName,
      secondary: mood.moodName,
      tertiary: mood.moodName,
      emoji: mood.emoji,
      eyeType: 'Default',
      mouthType: 'Smile',
      color: mood.color,
    );

    setState(() {
      _selectedFeeling = feeling;
      _supportInfo = FeelingSupportLibrary.findSupport(feeling);
      _detail = FeelingDetails.forFeeling(feeling);
      _intensity = 3;
    });
    _saveSelectedFeeling();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Feelings Corner'),
        backgroundColor: Colors.purple[100],
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Welcome card
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [Colors.purple[100]!, Colors.pink[100]!],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.favorite,
                          color: Colors.purple,
                          size: 28,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Welcome to Your Feelings Corner',
                              style: Theme.of(context)
                                  .textTheme
                                  .titleLarge
                                  ?.copyWith(
                                    fontWeight: FontWeight.bold,
                                    color: Colors.purple[900],
                                  ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'A safe space to check in with your emotions',
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.purple[700],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // Lightweight Mood Magic picker
            MoodMagicPicker(
              childAge: widget.characterAge ?? 8,
              onMoodSelected: _onMoodSelected,
            ),

            // Selected emotion details
            if (_selectedFeeling != null) ...[
              const SizedBox(height: 24),
              _buildInfoPanel(context),

              const SizedBox(height: 24),

              // Save button
              ElevatedButton(
                onPressed: _saveCheckIn,
                style: ElevatedButton.styleFrom(
                  backgroundColor: _selectedFeeling!.color,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  minimumSize: const Size(double.infinity, 50),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text(
                  'Save This Feeling',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),

              const SizedBox(height: 16),

              // Story suggestion card
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.blue[50],
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.blue[200]!),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.lightbulb, color: Colors.orange, size: 24),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            'Story Suggestion',
                            style: Theme.of(context)
                                .textTheme
                                .titleMedium
                                ?.copyWith(
                                  fontWeight: FontWeight.bold,
                                  color: Colors.blue[900],
                                ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text(
                      _getStorySuggestion(
                          _selectedFeeling!.tertiary, _intensity),
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                    const SizedBox(height: 12),
                    ElevatedButton.icon(
                      onPressed: () {
                        // Navigate back to story creation with feeling data
                        Navigator.pop(context, {
                          'emotion': _selectedFeeling!.tertiary,
                          'intensity': _intensity,
                          'core_emotion': _selectedFeeling!.core,
                        });
                      },
                      icon: const Icon(Icons.auto_stories),
                      label: const Text('Create Story About This Feeling'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue,
                      ),
                    ),
                  ],
                ),
              ),
            ],

            const SizedBox(height: 32),

            // Recent check-ins section
            Text(
              'Your Recent Check-Ins',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 12),

            if (_recentCheckIns.isEmpty)
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Center(
                  child: Column(
                    children: [
                      Icon(Icons.favorite_border,
                          size: 48, color: Colors.grey[400]),
                      const SizedBox(height: 12),
                      Text(
                        'No check-ins yet',
                        style: TextStyle(
                          color: Colors.grey[600],
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Check in regularly to track your emotional journey!',
                        style: TextStyle(
                          color: Colors.grey[500],
                          fontSize: 13,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              )
            else
              ..._recentCheckIns.map((checkIn) {
                final timestamp = DateTime.parse(checkIn['timestamp']);
                final timeAgo = _getTimeAgo(timestamp);

                return Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.grey[300]!),
                  ),
                  child: Row(
                    children: [
                      Text(
                        checkIn['emoji'],
                        style: const TextStyle(fontSize: 32),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              checkIn['emotion'],
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Row(
                              children: [
                                Text(
                                  'Intensity: ${_getIntensityLabel(checkIn['intensity'])}',
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: Colors.grey[600],
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Text(
                                  timeAgo,
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: Colors.grey[500],
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              }),

            const SizedBox(height: 24),

            SwitchListTile(
              value: _dailyReminderEnabled,
              title: const Text('Daily Feelings Reminder'),
              subtitle:
                  const Text('Receive a gentle nudge to check in once per day'),
              onChanged: _toggleReminder,
            ),
          ],
        ),
      ),
    );
  }

  /// Unified info panel for the selected feeling (path, definition, coping).
  Widget _buildInfoPanel(BuildContext context) {
    final feeling = _selectedFeeling!;
    final detail = _detail ?? FeelingDetails.forFeeling(feeling);
    final support = _supportInfo;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: feeling.color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: feeling.color, width: 2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                detail.emoji ?? feeling.emoji,
                style: const TextStyle(fontSize: 40),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      feeling.tertiary,
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      '${feeling.core} → ${feeling.secondary}',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey[700],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            'What this feeling means',
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
          ),
          const SizedBox(height: 6),
          Text(
            detail.description,
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: 16),
          const Text(
            'How strong is this feeling?',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              const Text('Mild', style: TextStyle(fontSize: 12)),
              Expanded(
                child: Slider(
                  value: _intensity.toDouble(),
                  min: 1,
                  max: 5,
                  divisions: 4,
                  label: _getIntensityLabel(_intensity),
                  activeColor: feeling.color,
                  onChanged: (value) {
                    setState(() => _intensity = value.toInt());
                  },
                ),
              ),
              const Text('Very Strong', style: TextStyle(fontSize: 12)),
            ],
          ),
          Center(
            child: Text(
              _getIntensityLabel(_intensity),
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: feeling.color,
              ),
            ),
          ),
          const SizedBox(height: 12),
          if (detail.coping.isNotEmpty)
            _buildSupportSection(
              title: 'Helpful things to try',
              items: detail.coping,
              accent: feeling.color,
              icon: Icons.favorite_outline,
            ),
          if (support != null && support.bodySignals.isNotEmpty) ...[
            const SizedBox(height: 12),
            _buildSupportSection(
              title: 'How this feeling shows up in the body',
              items: support.bodySignals,
              accent: feeling.color,
              icon: Icons.self_improvement,
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildSupportSection({
    required String title,
    required List<String> items,
    required Color accent,
    required IconData icon,
  }) {
    if (items.isEmpty) return const SizedBox.shrink();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: accent.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: accent.withValues(alpha: 0.4), width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: accent),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    color: accent,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ...items.map(
            (item) => Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('• '),
                  Expanded(
                    child: Text(
                      item,
                      style: const TextStyle(fontSize: 13.5),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _getIntensityLabel(int intensity) {
    switch (intensity) {
      case 1:
        return 'A little';
      case 2:
        return 'Some';
      case 3:
        return 'Medium';
      case 4:
        return 'Strong';
      case 5:
        return 'Very strong';
      default:
        return 'Medium';
    }
  }

  String _getStorySuggestion(String emotion, int intensity) {
    final suggestions = {
      'happy': 'Let\'s create a joyful adventure story to celebrate your mood!',
      'joyful': 'Your energy is perfect for an exciting adventure!',
      'cheerful': 'Let\'s create a fun story that matches your happy feelings!',
      'sad': 'A gentle story about finding comfort might help right now.',
      'disappointed':
          'How about a story where someone learns to bounce back from setbacks?',
      'lonely':
          'Let\'s create a story about making new friends and connections.',
      'angry':
          'How about a story where someone learns to express big feelings safely?',
      'frustrated':
          'A story about solving problems with patience could be helpful.',
      'nervous': 'Let\'s create a story about bravery and trying new things.',
      'worried':
          'How about a story that helps you feel more confident and calm?',
      'anxious': 'A story about managing worries and finding peace might help.',
      'excited': 'Your energy is perfect for an action-packed adventure!',
      'curious': 'Let\'s create an exploratory mystery story!',
      'scared': 'A story about facing fears with courage could be helpful.',
      'afraid': 'How about a story where someone finds their inner strength?',
      'peaceful': 'Let\'s create a calming, beautiful nature story.',
      'calm':
          'A gentle, thoughtful story would match your current mood perfectly.',
    };

    for (final entry in suggestions.entries) {
      if (emotion.toLowerCase().contains(entry.key)) {
        return entry.value;
      }
    }

    return 'Let\'s create a story that speaks to your heart!';
  }

  String _getTimeAgo(DateTime timestamp) {
    final now = DateTime.now();
    final difference = now.difference(timestamp);

    if (difference.inDays > 7) {
      final weeks = (difference.inDays / 7).floor();
      return '$weeks ${weeks == 1 ? "week" : "weeks"} ago';
    } else if (difference.inDays > 0) {
      return '${difference.inDays} ${difference.inDays == 1 ? "day" : "days"} ago';
    } else if (difference.inHours > 0) {
      return '${difference.inHours} ${difference.inHours == 1 ? "hour" : "hours"} ago';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes} ${difference.inMinutes == 1 ? "minute" : "minutes"} ago';
    } else {
      return 'Just now';
    }
  }
}
