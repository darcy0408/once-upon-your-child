import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';

import '../theme/app_theme.dart';
import '../widgets/app_button.dart';
import '../widgets/app_card.dart';
import '../widgets/app_step_indicator.dart';
import '../services/story_analytics.dart';

class ByokSetupWizardScreen extends StatefulWidget {
  const ByokSetupWizardScreen({super.key});

  @override
  State<ByokSetupWizardScreen> createState() => _ByokSetupWizardScreenState();
}

class _ByokSetupWizardScreenState extends State<ByokSetupWizardScreen> {
  int _step = 0;

  void _next() {
    if (_step < 2) {
      setState(() => _step++);
    } else {
      Navigator.of(context).pop(true);
    }
  }

  void _back() {
    if (_step > 0) setState(() => _step--);
  }

  Future<void> _openAiStudio() async {
    const url = 'https://aistudio.google.com/app/apikey';
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Could not open Google AI Studio. Please open it manually.'),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final steps = [
      _BenefitsStep(onNext: _next),
      _GetKeyStep(onNext: _next, onOpenLink: _openAiStudio, onBack: _back),
      _EnterKeyStep(
        onDone: (key) => Navigator.of(context).pop(key),
        onBack: _back,
      ),
    ];

    return Scaffold(
      appBar: AppBar(
        title: const Text('Use Your Own API Key'),
      ),
      body: SafeArea(
        child: Column(
          children: [
            const SizedBox(height: 12),
            AppStepIndicator(
              totalSteps: steps.length,
              currentStep: _step + 1,
              labels: const ['Benefits', 'Get Key', 'Enter Key'],
            ),
            const SizedBox(height: 12),
            Expanded(child: steps[_step]),
          ],
        ),
      ),
    );
  }
}

class _BenefitsStep extends StatelessWidget {
  const _BenefitsStep({required this.onNext});

  final VoidCallback onNext;

  @override
  Widget build(BuildContext context) {
    const benefits = [
      'Unlimited stories & illustrations',
      'No monthly subscription needed',
      'Faster generation with your own quota',
      'Data stays on your key',
      'Easy to turn on/off anytime',
    ];

    return Padding(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Why use your own key?',
            style: Theme.of(context)
                .textTheme
                .titleLarge
                ?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: AppSpacing.md),
          AppCard(
            color: AppColors.secondary.withValues(alpha: 0.1),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: benefits
                  .map(
                    (b) => Padding(
                      padding: const EdgeInsets.only(
                          bottom: AppSpacing.xs, top: AppSpacing.xs),
                      child: Row(
                        children: [
                          const Icon(Icons.check_circle, color: AppColors.secondary),
                          const SizedBox(width: AppSpacing.sm),
                          Expanded(child: Text(b)),
                        ],
                      ),
                    ),
                  )
                  .toList(),
            ),
          ),
          const Spacer(),
          AppButton.primary(
            label: 'Next: Get API Key',
            onPressed: onNext,
            icon: Icons.arrow_forward,
          ),
        ],
      ),
    );
  }
}

class _GetKeyStep extends StatelessWidget {
  const _GetKeyStep({
    required this.onNext,
    required this.onOpenLink,
    required this.onBack,
  });

  final VoidCallback onNext;
  final VoidCallback onOpenLink;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Get your free API key',
            style: Theme.of(context)
                .textTheme
                .titleLarge
                ?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: AppSpacing.md),
          AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: const [
                _StepRow(number: 1, text: 'Open Google AI Studio'),
                _StepRow(number: 2, text: 'Click "Get API key"'),
                _StepRow(number: 3, text: 'Copy your new key'),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          AppButton.primary(
            label: 'Open Google AI Studio',
            onPressed: onOpenLink,
            icon: Icons.open_in_new,
          ),
          const Spacer(),
          Row(
            children: [
              Expanded(
                child: AppButton.secondary(
                  label: 'Back',
                  onPressed: onBack,
                  icon: Icons.arrow_back,
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: AppButton.primary(
                  label: 'Next: Enter Key',
                  onPressed: onNext,
                  icon: Icons.arrow_forward,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _EnterKeyStep extends StatefulWidget {
  const _EnterKeyStep({required this.onDone, required this.onBack});

  final ValueChanged<String> onDone;
  final VoidCallback onBack;

  @override
  State<_EnterKeyStep> createState() => _EnterKeyStepState();
}

class _EnterKeyStepState extends State<_EnterKeyStep> {
  final _controller = TextEditingController();
  bool _validating = false;
  String? _status;
  bool _valid = false;
  bool _showKey = false;
  int _attempts = 0;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _validate() async {
    final key = _controller.text.trim();
    if (key.isEmpty) {
      setState(() {
        _status = 'Please paste your key to continue.';
        _valid = false;
      });
      return;
    }

    setState(() {
      _validating = true;
      _status = null;
      _attempts++;
    });

    // Lightweight validation: check prefix and ping Google models endpoint.
    if (!key.startsWith('AIza')) {
      setState(() {
        _status = 'That does not look like a Google AI Studio key (should start with AIza).';
        _valid = false;
        _validating = false;
      });
      unawaited(
        StoryAnalytics.trackByokSubmission(
          success: false,
          errorMessage: 'invalid_prefix',
        ),
      );
      return;
    }

    try {
      final uri = Uri.parse(
          'https://generativelanguage.googleapis.com/v1beta/models?key=$key');
      final response = await http.get(uri).timeout(const Duration(seconds: 10));
      if (response.statusCode == 200) {
        setState(() {
          _valid = true;
          _status = 'Great! Your key looks good. Tap finish to save.';
          _validating = false;
        });
        unawaited(StoryAnalytics.trackByokSubmission(success: true));
      } else {
        final Map<String, dynamic>? body =
            response.body.isNotEmpty ? jsonDecode(response.body) : null;
        setState(() {
          _status = 'Validation failed: ${body?['error']?['message'] ?? 'Unknown error'}';
          _valid = false;
          _validating = false;
        });
        unawaited(
          StoryAnalytics.trackByokSubmission(
            success: false,
            errorMessage: body?['error']?['message'],
          ),
        );
      }
    } catch (_) {
      setState(() {
        _status = 'We could not validate right now. Please try again.';
        _valid = false;
        _validating = false;
      });
      unawaited(
        StoryAnalytics.trackByokSubmission(
          success: false,
          errorMessage: 'network_or_timeout',
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Enter and verify your key',
            style: Theme.of(context)
                .textTheme
                .titleLarge
                ?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: AppSpacing.md),
          AppCard(
            child: TextField(
              controller: _controller,
              decoration: const InputDecoration(
                labelText: 'API Key',
                hintText: 'AIza...',
                prefixIcon: Icon(Icons.key),
              ),
              obscureText: !_showKey,
              maxLines: 1,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Row(
            children: [
              Checkbox(
                value: _showKey,
                onChanged: (v) => setState(() => _showKey = v ?? false),
              ),
              const Text('Show key (keep private)'),
            ],
          ),
          if (_status != null) ...[
            const SizedBox(height: AppSpacing.sm),
            Text(
              _status!,
              style: TextStyle(
                color: _valid ? Colors.green : Colors.red,
                fontWeight: FontWeight.w600,
              ),
            ),
            if (!_valid && _attempts >= 2)
              Padding(
                padding: const EdgeInsets.only(top: AppSpacing.xs),
                child: Text(
                  'Double-check that you copied the full key and that it starts with AIza.',
                  style: TextStyle(
                    color: Colors.red.shade700,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
          ],
          const SizedBox(height: AppSpacing.md),
          Row(
            children: [
              Expanded(
                child: AppButton.secondary(
                  label: 'Back',
                  onPressed: widget.onBack,
                  icon: Icons.arrow_back,
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: AppButton.primary(
                  label: _validating ? 'Validating...' : 'Finish',
                  onPressed: _validating
                      ? null
                      : () async {
                          await _validate();
                          if (_valid) {
                            widget.onDone(_controller.text.trim());
                          }
                        },
                  icon: Icons.check,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _StepRow extends StatelessWidget {
  const _StepRow({required this.number, required this.text});

  final int number;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
      child: Row(
        children: [
          CircleAvatar(
            radius: 16,
            backgroundColor: AppColors.primary.withValues(alpha: 0.12),
            child: Text(
              '$number',
              style: const TextStyle(color: AppColors.primary),
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(child: Text(text)),
        ],
      ),
    );
  }
}
