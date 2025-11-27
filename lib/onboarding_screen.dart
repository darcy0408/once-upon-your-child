import 'package:flutter/material.dart';

import 'services/onboarding_analytics.dart';

class OnboardingScreen extends StatefulWidget {
  final VoidCallback onFinished;
  final VoidCallback? onSkipConfirmed;

  const OnboardingScreen({
    super.key,
    required this.onFinished,
    this.onSkipConfirmed,
  });

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final TextEditingController _childNameController = TextEditingController();
  final List<int> _ageOptions = List<int>.generate(10, (i) => i + 3);
  final List<String> _themeOptions = const [
    'Adventure',
    'Friendship',
    'Magic',
    'Mystery',
    'Space',
    'Ocean',
  ];

  late DateTime _startedAt;
  int _currentStep = 0;
  int _childAge = 7;
  String? _selectedTheme = 'Adventure';

  @override
  void initState() {
    super.initState();
    _startedAt = DateTime.now();
    _trackStep(0);
  }

  @override
  void dispose() {
    _childNameController.dispose();
    super.dispose();
  }

  bool get _isLastStep => _currentStep == _buildSteps().length - 1;
  bool get _hasName => _childNameController.text.trim().isNotEmpty;
  bool get _hasTheme => (_selectedTheme ?? '').isNotEmpty;
  double get _progressValue =>
      (_currentStep + 1) / _buildSteps().length;

  void _trackStep(int index) {
    OnboardingAnalytics.trackFeatureViewed('quick_start_step_${index + 1}');
  }

  Future<void> _completeOnboarding({bool skipped = false}) async {
    final elapsed = DateTime.now().difference(_startedAt).inSeconds;
    await OnboardingAnalytics.trackOnboardingCompleted(
      timeSpentSeconds: elapsed,
      skippedAnyStep: skipped,
    );
    widget.onFinished();
  }

  Future<void> _confirmSkipToAdvanced() async {
    await OnboardingAnalytics.trackOnboardingSkipped(step: _currentStep + 1);
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Skip to Advanced Options?'),
        content: const Text(
          'You can jump straight into the full Story Creator with every toggle. You can revisit this quick start later from Settings.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Stay Here'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Go to Advanced'),
          ),
        ],
      ),
    );

    if (result ?? false) {
      widget.onSkipConfirmed?.call();
      await _completeOnboarding(skipped: true);
    }
  }

  void _handleContinue() {
    if (_currentStep == 0 && !_hasName) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Add your child\'s name to continue.')),
      );
      return;
    }

    if (_currentStep == 1 && !_hasTheme) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Select a theme to continue.')),
      );
      return;
    }

    if (_isLastStep) {
      _completeOnboarding();
    } else {
      setState(() {
        _currentStep += 1;
        _trackStep(_currentStep);
      });
    }
  }

  void _handleBack() {
    if (_currentStep == 0) return;
    setState(() {
      _currentStep -= 1;
    });
  }

  List<Step> _buildSteps() {
    return [
      Step(
        title: const Text('Child Info'),
        content: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: _childNameController,
              decoration: const InputDecoration(
                labelText: 'Child\'s name',
                hintText: 'E.g., Maya',
              ),
              textCapitalization: TextCapitalization.words,
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<int>(
              value: _childAge,
              decoration: const InputDecoration(
                labelText: 'Age',
                border: OutlineInputBorder(),
              ),
              items: _ageOptions
                  .map(
                    (age) => DropdownMenuItem(
                      value: age,
                      child: Text('$age years old'),
                    ),
                  )
                  .toList(),
              onChanged: (value) {
                if (value == null) return;
                setState(() => _childAge = value);
              },
            ),
          ],
        ),
        isActive: _currentStep >= 0,
        state: _currentStep > 0
            ? StepState.complete
            : (_hasName ? StepState.editing : StepState.indexed),
      ),
      Step(
        title: const Text('Choose a Theme'),
        content: Wrap(
          spacing: 8,
          runSpacing: 8,
          children: _themeOptions.map((theme) {
            final selected = _selectedTheme == theme;
            return ChoiceChip(
              label: Text(theme),
              selected: selected,
              onSelected: (_) {
                setState(() {
                  _selectedTheme = theme;
                });
              },
            );
          }).toList(),
        ),
        isActive: _currentStep >= 1,
        state: _currentStep > 1
            ? StepState.complete
            : (_hasTheme ? StepState.editing : StepState.indexed),
      ),
      Step(
        title: const Text('Ready to Create'),
        content: _buildSummaryCard(),
        isActive: _currentStep >= 2,
        state: _isLastStep ? StepState.editing : StepState.indexed,
      ),
    ];
  }

  Widget _buildSummaryCard() {
    final name =
        _childNameController.text.trim().isEmpty ? 'Your child' : _childNameController.text.trim();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '$name (Age $_childAge)',
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 8),
        Text(
          'Theme: ${_selectedTheme ?? 'Adventure'}',
          style: Theme.of(context).textTheme.bodyLarge,
        ),
        const SizedBox(height: 16),
        Text(
          'Tap "Start Creating Stories" to open the Story Creator with all features ready.',
          style: Theme.of(context).textTheme.bodyMedium,
        ),
        const SizedBox(height: 24),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: _completeOnboarding,
            child: const Text('Start Creating Stories'),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final steps = _buildSteps();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Quick Start Wizard'),
        actions: [
          TextButton(
            onPressed: _confirmSkipToAdvanced,
            child: const Text('Skip / Advanced', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  LinearProgressIndicator(
                    value: _progressValue,
                    backgroundColor: Colors.grey.shade200,
                    valueColor:
                        AlwaysStoppedAnimation<Color>(Theme.of(context).primaryColor),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Step ${_currentStep + 1} of ${steps.length}',
                        style: Theme.of(context).textTheme.labelMedium,
                      ),
                      TextButton(
                        onPressed: () async {
                          await OnboardingAnalytics.trackOnboardingSkipped(
                            step: _currentStep + 1,
                          );
                          await _completeOnboarding(skipped: true);
                        },
                        child: const Text('Skip'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: Stepper(
                currentStep: _currentStep,
                steps: steps,
                type: StepperType.vertical,
                onStepContinue: _handleContinue,
                onStepCancel: _handleBack,
                controlsBuilder: (context, details) {
                  final isFirstStep = _currentStep == 0;
                  return Row(
                    children: [
                      if (!isFirstStep)
                        TextButton(
                          onPressed: details.onStepCancel,
                          child: const Text('Back'),
                        ),
                      const SizedBox(width: 8),
                      ElevatedButton(
                        onPressed: details.onStepContinue,
                        child: Text(_isLastStep ? 'Finish' : 'Next'),
                      ),
                    ],
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
