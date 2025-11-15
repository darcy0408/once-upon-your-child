// lib/character_evolution_screen.dart

import 'package:flutter/material.dart';
import 'character_evolution.dart';
import 'models.dart';
import 'emotion_recognition_game.dart';
import 'empathy_building_exercises.dart';
import 'peer_interaction_stories.dart';
import 'family_relationship_stories.dart';

class CharacterEvolutionScreen extends StatefulWidget {
  final Character character;

  const CharacterEvolutionScreen({
    super.key,
    required this.character,
  });

  @override
  State<CharacterEvolutionScreen> createState() => _CharacterEvolutionScreenState();
}

class _CharacterEvolutionScreenState extends State<CharacterEvolutionScreen> {
  CharacterEvolution? _evolution;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadEvolution();
  }

  Future<void> _loadEvolution() async {
    final evolution = await widget.character.getEvolution();
    if (mounted) {
      setState(() {
        _evolution = evolution;
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('${widget.character.name}\'s Growth Journey'),
        backgroundColor: Colors.deepPurple,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _evolution == null
              ? _buildEmptyState()
              : _buildEvolutionContent(),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.child_care,
            size: 80,
            color: Colors.grey.shade400,
          ),
          const SizedBox(height: 16),
          Text(
            '${widget.character.name} hasn\'t started their growth journey yet',
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w500,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            'Create therapeutic stories to help ${widget.character.name} grow and learn!',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey.shade600,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildEvolutionContent() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Development Stage Card
          _buildDevelopmentStageCard(),

          const SizedBox(height: 24),

          // Progress Overview
          _buildProgressOverview(),

          const SizedBox(height: 24),

          // Therapeutic Goals Progress
          if (_evolution!.therapeuticProgress.isNotEmpty) ...[
            _buildTherapeuticGoalsSection(),
            const SizedBox(height: 24),
          ],

          // Emotion Mastery
          if (_evolution!.emotionMastery.isNotEmpty) ...[
            _buildEmotionMasterySection(),
            const SizedBox(height: 24),
          ],

          // Milestones
          if (_evolution!.milestones.isNotEmpty) ...[
            _buildMilestonesSection(),
            const SizedBox(height: 24),
          ],

          // Therapeutic Activities
          _buildTherapeuticActivitiesSection(),
        ],
      ),
    );
  }

  Widget _buildTherapeuticActivitiesSection() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Therapeutic Activities',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Practice emotional skills through interactive games and exercises',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey,
              ),
            ),
            const SizedBox(height: 16),
            EmotionGameLauncher(characterId: widget.character.id),
            const SizedBox(height: 16),
            EmpathyExercisesLauncher(characterId: widget.character.id),
            const SizedBox(height: 16),
            PeerInteractionStoriesLauncher(characterId: widget.character.id),
            const SizedBox(height: 16),
            FamilyRelationshipStoriesLauncher(characterId: widget.character.id),
          ],
        ),
      ),
    );
  }

  Widget _buildDevelopmentStageCard() {
    final stage = _evolution!.developmentStage;
    final score = _evolution!.overallDevelopmentScore;

    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          gradient: LinearGradient(
            colors: [stage.color.withOpacity(0.1), stage.color.withOpacity(0.05)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: stage.color,
                shape: BoxShape.circle,
              ),
              child: Text(
                '${score.round()}%',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              stage.displayName,
              style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              stage.description,
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey.shade600,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProgressOverview() {
    final traits = _evolution!.evolvedTraits;

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Growth Areas',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            if (traits.containsKey('confidence'))
              _buildTraitProgress('Confidence', traits['confidence'] as int),
            if (traits.containsKey('empathy'))
              _buildTraitProgress('Empathy', traits['empathy'] as int),
            if (traits.containsKey('emotional_intelligence'))
              _buildTraitProgress('Emotional Intelligence', traits['emotional_intelligence'] as int),
            if (traits.containsKey('coping_skills_count'))
              _buildTraitInfo('Coping Skills Learned', '${traits['coping_skills_count']} skills'),
          ],
        ),
      ),
    );
  }

  Widget _buildTraitProgress(String traitName, int progress) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                traitName,
                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
              ),
              Text(
                '$progress%',
                style: const TextStyle(fontSize: 14, color: Colors.deepPurple),
              ),
            ],
          ),
          const SizedBox(height: 4),
          LinearProgressIndicator(
            value: progress / 100,
            backgroundColor: Colors.grey.shade200,
            valueColor: const AlwaysStoppedAnimation<Color>(Colors.deepPurple),
          ),
        ],
      ),
    );
  }

  Widget _buildTraitInfo(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
          ),
          Text(
            value,
            style: const TextStyle(
              fontSize: 14,
              color: Colors.deepPurple,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTherapeuticGoalsSection() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Therapeutic Goals Progress',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            ..._evolution!.therapeuticProgress.entries.map(
              (entry) => _buildGoalProgress(entry.key, entry.value),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGoalProgress(TherapeuticGoal goal, int progress) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(goal.icon, size: 20, color: goal.color),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  goal.displayName,
                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
                ),
              ),
              Text(
                '$progress%',
                style: const TextStyle(fontSize: 14, color: Colors.deepPurple),
              ),
            ],
          ),
          const SizedBox(height: 4),
          LinearProgressIndicator(
            value: progress / 100,
            backgroundColor: Colors.grey.shade200,
            valueColor: AlwaysStoppedAnimation<Color>(goal.color),
          ),
        ],
      ),
    );
  }

  Widget _buildEmotionMasterySection() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Emotion Mastery',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _evolution!.emotionMastery.entries.map(
                (entry) => _buildEmotionChip(entry.key, entry.value),
              ).toList(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmotionChip(String emotionId, int mastery) {
    // This would need access to EmotionsLearningService to get emotion details
    // For now, just show the ID and mastery level
    return Chip(
      label: Text('$emotionId: $mastery%'),
      backgroundColor: Colors.blue.shade50,
      labelStyle: const TextStyle(fontSize: 12),
    );
  }

  Widget _buildMilestonesSection() {
    final recentMilestones = _evolution!.milestones
        .where((m) => m.achievedAt.isAfter(DateTime.now().subtract(const Duration(days: 30))))
        .toList()
      ..sort((a, b) => b.achievedAt.compareTo(a.achievedAt));

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Recent Milestones',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  '${_evolution!.milestones.length} total',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey.shade600,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            if (recentMilestones.isEmpty)
              const Text(
                'No recent milestones',
                style: TextStyle(color: Colors.grey),
              )
            else
              ...recentMilestones.take(5).map(_buildMilestoneItem),
          ],
        ),
      ),
    );
  }

  Widget _buildMilestoneItem(CharacterMilestone milestone) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.amber.shade100,
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.star,
              color: Colors.amber,
              size: 16,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  milestone.title,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  milestone.description,
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey.shade600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  _formatDate(milestone.achievedAt),
                  style: TextStyle(
                    fontSize: 10,
                    color: Colors.grey.shade500,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);

    if (difference.inDays == 0) {
      return 'Today';
    } else if (difference.inDays == 1) {
      return 'Yesterday';
    } else if (difference.inDays < 7) {
      return '${difference.inDays} days ago';
    } else {
      return '${date.month}/${date.day}/${date.year}';
    }
  }
}