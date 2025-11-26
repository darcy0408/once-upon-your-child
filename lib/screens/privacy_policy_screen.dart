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
Story Weaver is designed for children. We comply with COPPA:
- No personal data from children under 13 without parental consent
- Parents/guardians must approve account creation
- We do not sell or share children's data
- Parents can request deletion of their child's data at any time
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
- Google Gemini AI: story generation (we avoid sending personal data)
- Stripe: subscription and payment processing
- Railway: secure hosting and infrastructure
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

Contact: privacy@storyweaver.app
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
Last updated: ${DateTime.now().toString().split(' ').first}
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
