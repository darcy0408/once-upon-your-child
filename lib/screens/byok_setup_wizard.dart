import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

import '../config/environment.dart';
import '../services/illustration_preference_service.dart';
import '../services/secure_storage_service.dart';
import '../theme/app_theme.dart';
import '../widgets/app_button.dart';
import '../widgets/app_card.dart';
import '../widgets/app_step_indicator.dart';

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
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content:
              Text('Could not open Google AI Studio. Please open it manually.'),
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
      backgroundColor: const Color(0xFF120226),
      appBar: AppBar(
        backgroundColor: const Color(0xFF2C1B47),
        foregroundColor: const Color(0xFFFFD54F),
        elevation: 0,
        title: const Text(
          'Use Your Own API Key',
          style: TextStyle(
            color: Color(0xFFFFD54F),
            fontWeight: FontWeight.bold,
          ),
        ),
        iconTheme: const IconThemeData(color: Color(0xFFFFD54F)),
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF2C1B47), Color(0xFF120226)],
          ),
        ),
        child: SafeArea(
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
      ),
    );
  }
}

class _BenefitsStep extends StatefulWidget {
  const _BenefitsStep({required this.onNext});
  final VoidCallback onNext;

  @override
  State<_BenefitsStep> createState() => _BenefitsStepState();
}

class _BenefitsStepState extends State<_BenefitsStep> {
  static const _gold = Color(0xFFFFD54F);
  static const _goldLight = Color(0xFFFFE082);
  static const _white70 = Color(0xB3FFFFFF);

  IllustrationPreference _preference = IllustrationPreference.full;

  @override
  void initState() {
    super.initState();
    IllustrationPreferenceService.load()
        .then((p) { if (mounted) setState(() => _preference = p); });
  }

  Future<void> _setPreference(IllustrationPreference p) async {
    setState(() => _preference = p);
    await IllustrationPreferenceService.save(p);
  }

  @override
  Widget build(BuildContext context) {
    const benefits = [
      (
        '🧒',
        'A cartoon portrait that\'s uniquely your child',
        'Generate a Pixar-style character that actually looks like your child — stored only on your phone and never shared with anyone.'
      ),
      (
        '🖼️',
        'Story illustrations starring your child',
        'Every adventure comes to life with beautiful scenes showing YOUR child as the hero of the story.'
      ),
      (
        '🎨',
        'Printable coloring pages from their own story',
        'Turn your child\'s story scenes into coloring pages they can print and bring to life with crayons.'
      ),
      (
        '📖',
        'Unlimited stories, whenever inspiration strikes',
        'No daily caps or waiting — your child can keep creating stories as often as they like.'
      ),
      (
        '🎭',
        'Choose-your-own-adventure mode',
        'Your child decides what happens next, making every story a unique adventure they helped write.'
      ),
    ];

    return Padding(
      padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.lg, vertical: AppSpacing.sm),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Give your child the full experience',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: _gold,
                        ),
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  const Text(
                    'Connect your free Google AI key to unlock everything below.\nMost families spend nothing at all — Google\'s free tier covers everyday use.',
                    style: TextStyle(color: _white70, fontSize: 13, height: 1.5),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.white.withAlpha(12),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                          color: _gold.withAlpha(60), width: 1),
                    ),
                    child: Column(
                      children: benefits.asMap().entries.map((entry) {
                        final i = entry.key;
                        final b = entry.value;
                        return Container(
                          decoration: BoxDecoration(
                            border: i < benefits.length - 1
                                ? Border(
                                    bottom: BorderSide(
                                        color: Colors.white.withAlpha(20)))
                                : null,
                          ),
                          padding: const EdgeInsets.symmetric(
                              horizontal: AppSpacing.md,
                              vertical: AppSpacing.sm),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(b.$1,
                                  style: const TextStyle(fontSize: 24)),
                              const SizedBox(width: AppSpacing.sm),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(b.$2,
                                        style: const TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 14,
                                            color: _goldLight)),
                                    const SizedBox(height: 2),
                                    Text(b.$3,
                                        style: const TextStyle(
                                            fontSize: 12,
                                            color: _white70,
                                            height: 1.4)),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  // ── Illustration preference picker ─────────────────────────
                  Text(
                    'Illustration settings',
                    style: TextStyle(
                      color: _gold,
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 6),
                  ...IllustrationPreference.values.map((option) {
                    final selected = _preference == option;
                    return GestureDetector(
                      onTap: () => _setPreference(option),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 180),
                        margin: const EdgeInsets.only(bottom: 8),
                        padding: const EdgeInsets.symmetric(
                            horizontal: AppSpacing.md, vertical: 10),
                        decoration: BoxDecoration(
                          color: selected
                              ? _gold.withAlpha(30)
                              : Colors.white.withAlpha(10),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: selected
                                ? _gold
                                : Colors.white.withAlpha(40),
                            width: selected ? 2 : 1,
                          ),
                        ),
                        child: Row(
                          children: [
                            Text(option.emoji,
                                style: const TextStyle(fontSize: 20)),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    option.label,
                                    style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.bold,
                                      color: selected ? _gold : _goldLight,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    option.description,
                                    style: const TextStyle(
                                        fontSize: 11,
                                        color: _white70,
                                        height: 1.3),
                                  ),
                                ],
                              ),
                            ),
                            if (selected)
                              const Icon(Icons.check_circle,
                                  color: _gold, size: 18),
                          ],
                        ),
                      ),
                    );
                  }),
                  const SizedBox(height: AppSpacing.sm),
                  Container(
                    padding: const EdgeInsets.all(AppSpacing.sm),
                    decoration: BoxDecoration(
                      color: Colors.green.withAlpha(30),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: Colors.green.withAlpha(80)),
                    ),
                    child: const Row(
                      children: [
                        Icon(Icons.lock_outline, color: Colors.greenAccent, size: 16),
                        SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Your key stays on your device. We never see it or store it.',
                            style: TextStyle(
                                fontSize: 12,
                                color: Colors.greenAccent,
                                height: 1.4),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          AppButton.primary(
            label: 'Next: Get My Free Key',
            onPressed: widget.onNext,
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
  bool _showKey = true;
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
        _status =
            'That does not look like a Google AI Studio key (should start with AIza).';
        _valid = false;
        _validating = false;
      });
      return;
    }

    try {
      final uri = Uri.parse(
          '${Environment.backendUrl}/api/user/settings/validate-api-key');
      final response = await http
          .post(
            uri,
            headers: const {'Content-Type': 'application/json'},
            body: jsonEncode({'api_key': key}),
          )
          .timeout(const Duration(seconds: 15));

      final Map<String, dynamic>? body =
          response.body.isNotEmpty ? jsonDecode(response.body) : null;
      final bool ok = body != null && body['valid'] == true;

      setState(() {
        _valid = ok;
        _status = ok
            ? 'Great! Your key looks good. Tap finish to save.'
            : 'Validation failed: ${body?['message'] ?? body?['error'] ?? 'Unknown error'}';
        _validating = false;
      });
    } on http.ClientException catch (e) {
      setState(() {
        _status =
            'Could not reach the validation service. Please check your connection and try again. (${e.message})';
        _valid = false;
        _validating = false;
      });
    } catch (_) {
      setState(() {
        _status =
            'Could not reach the validation service right now. Please try again in a moment.';
        _valid = false;
        _validating = false;
      });
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
              style: const TextStyle(
                color: Colors.white,
                fontFamily: 'monospace',
              ),
              decoration: InputDecoration(
                labelText: 'API Key',
                hintText: 'AIza...',
                prefixIcon: const Icon(Icons.key, color: Color(0xFFFFD54F)),
                labelStyle: const TextStyle(color: Color(0xB3FFFFFF)),
                hintStyle: TextStyle(color: Colors.white.withAlpha(80)),
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
                            final key = _controller.text.trim();
                            // Persist key here so it's saved regardless of
                            // which caller launched the wizard.
                            final prefs = await SharedPreferences.getInstance();
                            await prefs.setBool('use_own_api_key', true);
                            await prefs.setBool('is_premium_byok', true);
                            await SecureStorageService.saveApiKey('gemini', key);
                            if (mounted) widget.onDone(key);
                          } else if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                    _status ?? 'Key not saved — please check the error above.'),
                                backgroundColor: Colors.red.shade700,
                              ),
                            );
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
