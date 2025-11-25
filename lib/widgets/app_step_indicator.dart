import 'package:flutter/material.dart';

class AppStepIndicator extends StatelessWidget {
  const AppStepIndicator({
    super.key,
    required this.totalSteps,
    required this.currentStep,
    required this.labels,
  });

  final int totalSteps;
  final int currentStep;
  final List<String> labels;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: List.generate(totalSteps, (index) {
        final isActive = index + 1 == currentStep;
        final isDone = index + 1 < currentStep;
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircleAvatar(
              radius: 14,
              backgroundColor: isActive
                  ? Colors.deepPurple
                  : (isDone ? Colors.green : Colors.grey.shade300),
              child: Icon(
                isActive
                    ? Icons.radio_button_checked
                    : (isDone ? Icons.check : Icons.radio_button_unchecked),
                size: 16,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              labels[index],
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: isActive
                        ? Colors.deepPurple
                        : (isDone ? Colors.green : Colors.black54),
                  ),
            ),
          ],
        );
      }),
    );
  }
}
