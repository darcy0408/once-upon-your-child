import 'package:flutter/material.dart';

class FeatureTourStep {
  final String title;
  final String description;
  final IconData icon;

  const FeatureTourStep({
    required this.title,
    required this.description,
    required this.icon,
  });
}

class FeatureTourOverlay extends StatelessWidget {
  final List<FeatureTourStep> steps;
  final int currentIndex;
  final VoidCallback onNext;
  final VoidCallback onSkip;

  const FeatureTourOverlay({
    super.key,
    required this.steps,
    required this.currentIndex,
    required this.onNext,
    required this.onSkip,
  });

  @override
  Widget build(BuildContext context) {
    final step = steps[currentIndex];
    final progress = '${currentIndex + 1}/${steps.length}';
    return Positioned.fill(
      child: Container(
        color: Colors.black.withValues(alpha: 0.65),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                Align(
                  alignment: Alignment.topRight,
                  child: TextButton(
                    onPressed: onSkip,
                    child: const Text(
                      'Skip tour',
                      style: TextStyle(color: Colors.white),
                    ),
                  ),
                ),
                const Spacer(),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.2),
                        blurRadius: 16,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          CircleAvatar(
                            backgroundColor:
                                Colors.deepPurple.withValues(alpha: 0.12),
                            child: Icon(step.icon, color: Colors.deepPurple),
                          ),
                          const SizedBox(width: 12),
                          Text(
                            'Feature Tour • $progress',
                            style: const TextStyle(
                              fontWeight: FontWeight.w700,
                              color: Colors.deepPurple,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Text(
                        step.title,
                        style: Theme.of(context)
                            .textTheme
                            .titleLarge
                            ?.copyWith(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        step.description,
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                      const SizedBox(height: 16),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          TextButton(
                            onPressed: onSkip,
                            child: const Text('No thanks'),
                          ),
                          ElevatedButton.icon(
                            onPressed: onNext,
                            icon: Icon(
                              currentIndex == steps.length - 1
                                  ? Icons.check
                                  : Icons.arrow_forward,
                            ),
                            label: Text(
                              currentIndex == steps.length - 1
                                  ? 'Finish'
                                  : 'Next',
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.deepPurple,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
