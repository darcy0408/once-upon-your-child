import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

class PrivacyPolicyScreen extends StatelessWidget {
  const PrivacyPolicyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Privacy Policy'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSection(
              title: 'Data We Collect',
              content: '''
We collect minimal data to provide Story Weaver:
- Story preferences (characters, themes, choices)
- Account information you provide
- Payment information processed securely by Stripe (never stored by us)
- Anonymous analytics to improve the app
''',
            ),
            _buildSection(
              title: 'Children\'s Privacy (COPPA)',
              content: '''
Story Weaver is designed for users ages 3-18+. We comply with the Children's Online Privacy Protection Act (COPPA) as enforced by the FTC:
- No personal data from children under 13 without verifiable parental consent
- Parents/guardians must approve account creation for children under 13
- We do not sell or share children's data
- Parents can request deletion of their child's data at any time
- Age is collected to provide age-appropriate content and to determine COPPA applicability
''',
            ),
            _buildSection(
              title: 'How We Use Data',
              content: '''
- Personalize and generate stories
- Improve quality and safety of content
- Provide support if you contact us
- Process payments via Stripe (PCI compliant)
- Optional analytics to understand feature usage
''',
            ),
            _buildSection(
              title: 'Third-Party Services',
              content: '''
- Google Gemini AI: story and illustration generation (we do not send personal information; only fictional character details and story preferences)
- Stripe: subscription and payment processing (PCI compliant)
- Railway: secure hosting and infrastructure
- Sentry: error monitoring (no personal data is included)
''',
            ),
            _buildSection(
              title: 'Your Rights',
              content: '''
You can:
- Access and update your data
- Request deletion of your data
- Opt out of analytics where supported
- Withdraw consent at any time

To exercise these rights or to request deletion of your child's data, contact us at:

Story Weaver
2816 Orchard Ave
Grand Junction, CO 81501
Email: onceuponyourchild@gmail.com
''',
            ),
            _buildSection(
              title: 'Security',
              content: '''
- Keys and secrets are stored securely
- Payment info handled only by Stripe
- We regularly review security and content safety measures
''',
            ),
            _buildSection(
              title: 'Updates to This Policy',
              content: '''
Last updated: March 28, 2026
We may update this policy. Changes will be posted here.
''',
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSection({required String title, required String content}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            content.trim(),
            style: const TextStyle(
              fontSize: 16,
              height: 1.6,
            ),
          ),
        ],
      ),
    );
  }
}
