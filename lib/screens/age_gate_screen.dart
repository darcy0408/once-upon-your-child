import 'package:flutter/material.dart';

import '../services/parental_consent_service.dart';
import '../theme/app_theme.dart';
import 'parental_consent_screen.dart';
import 'privacy_policy_screen.dart';
import 'terms_of_service_screen.dart';

class AgeGateScreen extends StatefulWidget {
  const AgeGateScreen({
    super.key,
    required this.consentService,
    required this.onConsentCompleted,
  });

  final ParentalConsentService consentService;
  final VoidCallback onConsentCompleted;

  @override
  State<AgeGateScreen> createState() => _AgeGateScreenState();
}

class _AgeGateScreenState extends State<AgeGateScreen> {
  int? _selectedAge;
  bool _submitting = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Card(
              margin: EdgeInsets.zero,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(24),
              ),
              elevation: 6,
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.lg),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Welcome to Story Weaver!',
                      style: Theme.of(context).textTheme.headlineMedium,
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    Text(
                      'We need your age to keep things safe and follow COPPA rules.',
                      style: Theme.of(context).textTheme.bodyLarge,
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    Text(
                      'How old are you?',
                      style: Theme.of(context)
                          .textTheme
                          .titleMedium
                          ?.copyWith(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    DropdownButtonFormField<int>(
                      initialValue: _selectedAge,
                      isExpanded: true,
                      hint: const Text('Select your age'),
                      items: List.generate(97, (index) => index + 4)
                          .map(
                            (age) => DropdownMenuItem(
                              value: age,
                              child: Text('$age years old'),
                            ),
                          )
                          .toList(),
                      onChanged: _submitting
                          ? null
                          : (age) => setState(() => _selectedAge = age),
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _submitting ? null : _handleContinue,
                        child: Text(_submitting ? 'Checking...' : 'Continue'),
                      ),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        TextButton(
                          onPressed: () {
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) => const PrivacyPolicyScreen(),
                              ),
                            );
                          },
                          child: const Text('Privacy Policy'),
                        ),
                        TextButton(
                          onPressed: () {
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) => const TermsOfServiceScreen(),
                              ),
                            );
                          },
                          child: const Text('Terms of Service'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _handleContinue() async {
    if (_selectedAge == null) {
      _showSnack('Please select your age to continue.');
      return;
    }

    setState(() => _submitting = true);
    await widget.consentService.saveDeclaredAge(_selectedAge!);

    if (_selectedAge! < 13) {
      if (!mounted) return;
      final granted = await Navigator.of(context).push<bool>(
        MaterialPageRoute(
          builder: (_) => ParentalConsentScreen(
            consentService: widget.consentService,
            declaredAge: _selectedAge!,
          ),
        ),
      );
      setState(() => _submitting = false);
      if (granted == true) {
        widget.onConsentCompleted();
      }
      return;
    }

    await _captureParentalKnowledgeConsent();
    if (mounted) {
      setState(() => _submitting = false);
      widget.onConsentCompleted();
    }
  }

  Future<void> _captureParentalKnowledgeConsent() async {
    final confirmed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('Parent/Guardian Notification'),
        content: const Text(
          'If you are under 18, please make sure a parent or guardian knows you are using this app.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('I Understand'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await widget.consentService.recordConsent(
        age: _selectedAge!,
        method: 'self_attested',
      );
      _showSnack('Thanks! Your age has been recorded.');
    }
  }

  void _showSnack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }
}
