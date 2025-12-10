import 'package:flutter/material.dart';

class StoryGenerationProgress extends StatelessWidget {
  final int currentPhase;
  final int totalPhases;
  final String funFact;

  const StoryGenerationProgress({
    super.key,
    required this.currentPhase,
    required this.totalPhases,
    required this.funFact,
  });

  String getPhaseTitle(int phase) {
    switch (phase) {
      case 0:
        return 'Crafting the perfect prompt...';
      case 1:
        return 'Awakening the story engine...';
      case 2:
        return 'Polishing the story...';
      default:
        return 'Generating...';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          getPhaseTitle(currentPhase),
          style: Theme.of(context).textTheme.titleLarge,
        ),
        const SizedBox(height: 20),
        LinearProgressIndicator(
          value: (currentPhase + 1) / totalPhases,
        ),
        const SizedBox(height: 20),
        Text(
          'Estimated time remaining: ${totalPhases - currentPhase - 1} seconds',
          style: Theme.of(context).textTheme.titleMedium,
        ),
      ],
    );
  }
}
