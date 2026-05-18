import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

class TermsOfServiceScreen extends StatelessWidget {
  const TermsOfServiceScreen({super.key});

  /// Static last-updated date — keep in sync with PRIVACY_POLICY.md.
  static const String lastUpdated = 'May 17, 2026';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Terms of Service'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSection(
              title: 'Acceptance of Terms',
              content: '''
By using Story Weaver, you agree to these terms. If you are under 13, a parent or guardian must provide consent on your behalf.
''',
            ),
            _buildSection(
              title: 'Age Requirements',
              content: '''
- Under 13: parental consent required
- Ages 13-17: parental knowledge recommended
- Parents/guardians are responsible for supervision
''',
            ),
            _buildSection(
              title: 'Subscriptions',
              content: '''
- Free tier: limited stories, grace period available
- Premium tier: unlimited stories and features
- Family tier: multiple users with premium features
- Subscriptions renew automatically until canceled
- Cancel anytime from Settings
''',
            ),
            _buildSection(
              title: 'Refund Policy',
              content: '''
- First month: full refund if not satisfied
- After first month: no refunds for partial months
- Contact onceuponyourchild@gmail.com for help
''',
            ),
            _buildSection(
              title: 'Content Rights',
              content: '''
- Generated stories are for personal use
- You may share stories you create
- Do not sell or commercially exploit generated content
- We may use aggregated, anonymized data to improve the service
''',
            ),
            _buildSection(
              title: 'Prohibited Uses',
              content: '''
Do not use Story Weaver to:
- Generate inappropriate or harmful content
- Violate laws or rights of others
- Harass, abuse, or defame anyone
- Attempt to hack or disrupt the service
''',
            ),
            _buildSection(
              title: 'Disclaimer',
              content: '''
Story Weaver is provided "as is." It is a storytelling and entertainment app, not a therapeutic, clinical, or medical product. AI-generated stories are not a substitute for professional mental health care. Seek licensed support when needed.
''',
            ),
            _buildSection(
              title: 'Termination',
              content: '''
We may suspend or terminate accounts that violate these terms or abuse the service.
''',
            ),
            _buildSection(
              title: 'Contact',
              content: '''
Questions? Contact onceuponyourchild@gmail.com
Last updated: $lastUpdated
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
