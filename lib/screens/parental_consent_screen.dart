import 'package:flutter/material.dart';

import '../services/parental_consent_service.dart';
import '../theme/app_theme.dart';
import 'privacy_policy_screen.dart';
import 'terms_of_service_screen.dart';

class ParentalConsentScreen extends StatefulWidget {
  const ParentalConsentScreen({
    super.key,
    required this.consentService,
    required this.declaredAge,
  });

  final ParentalConsentService consentService;
  final int declaredAge;

  @override
  State<ParentalConsentScreen> createState() => _ParentalConsentScreenState();
}

class _ParentalConsentScreenState extends State<ParentalConsentScreen> {
  String? _parentEmail;
  bool _consentGiven = false;
  bool _submitting = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Parental Consent Required'),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Hello Parent/Guardian!',
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                'Your child would like to use Story Weaver (age ${widget.declaredAge}). We need your permission because they are under 13.',
                style: Theme.of(context).textTheme.bodyLarge,
              ),
              const SizedBox(height: AppSpacing.md),
              Text(
                'What We Do:',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: AppSpacing.xs),
              const Text('• Generate personalized stories using AI'),
              const Text('• Provide therapeutic content for emotional growth'),
              const Text('• Collect minimal data (story preferences only)'),
              const Text('• Never sell or share your child\'s information'),
              const SizedBox(height: AppSpacing.md),
              TextField(
                decoration: const InputDecoration(
                  labelText: 'Your Email (optional)',
                  hintText: 'parent@example.com',
                  prefixIcon: Icon(Icons.email_outlined),
                ),
                keyboardType: TextInputType.emailAddress,
                onChanged: (value) => _parentEmail = value,
              ),
              const SizedBox(height: AppSpacing.sm),
              CheckboxListTile(
                title: const Text(
                  'I am a parent/guardian and give permission',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
                subtitle: const Text(
                  'I have read the Privacy Policy and Terms of Service',
                ),
                value: _consentGiven,
                onChanged: (value) =>
                    setState(() => _consentGiven = value ?? false),
              ),
              Row(
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
              const Spacer(),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: !_consentGiven || _submitting ? null : _submitConsent,
                  child: Text(_submitting ? 'Saving...' : 'Give Permission'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _submitConsent() async {
    setState(() => _submitting = true);
    try {
      await widget.consentService.recordConsent(
        age: widget.declaredAge,
        parentEmail: _parentEmail?.trim(),
        method: 'parent',
      );
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (_) {
      if (!mounted) return;
      setState(() => _submitting = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Could not save consent. Please try again.'),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }
}
