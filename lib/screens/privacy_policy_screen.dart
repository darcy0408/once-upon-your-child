import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// The single in-app privacy policy. Kept substantively identical to the
/// canonical repo/web copy in `PRIVACY_POLICY.md`.
class PrivacyPolicyScreen extends StatelessWidget {
  const PrivacyPolicyScreen({super.key});

  /// Static effective date — keep in sync with PRIVACY_POLICY.md.
  static const String effectiveDate = 'May 17, 2026';

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
              title: 'Privacy Policy',
              content: '''
Once Upon a Time, powered by Story Weaver
Effective Date: $effectiveDate

Once Upon a Time is committed to protecting the privacy and safety of children and families who use our storytelling platform. We believe that tools for children should be safe, transparent, and respectful of personal boundaries.
''',
            ),
            _buildSection(
              title: 'Information We Collect',
              content: '''
- Account information: parent/guardian email, username, basic profile, age range and preferences
- Usage data: story creation patterns, activity engagement, character progress, app usage statistics
- Story & feelings data: emotional check-ins and "big feelings" a child chooses to share, story goals and themes, milestone achievements
- Character & avatar data: character names and avatar choices. If a parent enables photo-based avatars, a photo used to create the child's character avatar (off by default, parental opt-in required; not stored on our servers)
''',
            ),
            _buildSection(
              title: 'How We Use Information',
              content: '''
- Personalize and generate stories, illustrations, and narration
- Provide age-appropriate content
- Track progress and growth
- Improve app functionality, quality, and safety
- Provide support if you contact us
- Process payments via Stripe (PCI compliant)
- Optional analytics to understand feature usage

We do NOT sell your data or use it for advertising.
''',
            ),
            _buildSection(
              title: 'Children\'s Privacy (COPPA)',
              content: '''
Once Upon a Time is designed for children ages 3-17. We comply with the Children's Online Privacy Protection Act (COPPA) as enforced by the FTC:
- No personal data is collected from children under 13 without verifiable parental consent
- Parents/guardians must approve account creation for children under 13
- We do not sell or share children's data
- Parents can request deletion of their child's data at any time
- Age is collected to provide age-appropriate content and to determine COPPA applicability
''',
            ),
            _buildSection(
              title: 'Data Security',
              content: '''
- Data is encrypted in transit using TLS
- Data is stored on access-controlled servers
- Payment data and API keys are encrypted at rest
- Regular security reviews, access controls, and monitoring

We do not provide end-to-end encryption. Story content and account data are processed on our servers so the app can function.
''',
            ),
            _buildSection(
              title: 'Third-Party Services (Sub-processors)',
              content: '''
We share only the minimum data required for each service to function. Each provider's own privacy policy governs its processing.

- Google Gemini — AI story-text and illustration generation. Receives a pseudonymized hero token (a non-identifying name used in place of the child's real name), story details, themes, any "big feelings" text the child shares, and image prompts.
- OpenRouter — routes AI image-generation requests. Receives image prompts, and on the photo-avatar path the child's photo.
- Replicate — AI image and avatar generation. Receives image prompts, and on the photo-avatar path the child's photo.
- Cloudflare Workers AI — AI image and avatar generation. Receives image prompts, and on the photo-avatar path the child's photo.
- ElevenLabs — text-to-speech narration. Receives generated story text.
- Stripe — subscription and payment processing. Receives parent payment information; we never store full card details.
- Railway — cloud hosting and infrastructure (United States). Stores all app data: profiles, stories, preferences.
- Firebase / Google Analytics — app analytics. Receives anonymized usage events (consent-gated, off by default, not enabled for children under 13).
- Sentry — error monitoring. Receives crash and error diagnostics.
- Resend — sends COPPA parental-consent verification emails. Receives the parent/guardian email address.

The exact AI image provider used may vary by build and availability.

Photo avatars (optional): if you choose to create an avatar from a photo, the photo is sent to our servers and then to the active AI image provider solely to generate the cartoon avatar. It is not stored on our servers and is used for nothing else.
''',
            ),
            _buildSection(
              title: 'Data Retention',
              content: '''
- Active accounts: data retained while the account is active
- Inactive accounts: data deleted after 2 years of inactivity
- Legal requirements: some data may be retained to comply with laws
''',
            ),
            _buildSection(
              title: 'Your Rights & Parental Controls',
              content: '''
Parents and guardians have complete control over their child's data. You can:
- Access and update your data
- Request deletion of your child's data
- Request a copy of your child's data
- Opt out of analytics where supported
- Withdraw consent at any time

To delete your child's data: open the app → menu → Parent Controls → Data & Privacy → Delete All My Data. This hard-deletes your child's profiles, stories, and content from our servers and anonymizes your account.

To exercise these rights, contact us at:
onceuponyourchild@gmail.com
''',
            ),
            _buildSection(
              title: 'Professional Disclaimer',
              content: '''
Once Upon a Time provides storytelling tools and resources, but is not a substitute for professional mental health care. Always consult qualified professionals for serious emotional or mental health concerns.
''',
            ),
            _buildSection(
              title: 'Updates to This Policy',
              content: '''
Effective $effectiveDate. We may update this policy and will post changes here. We will notify users of material changes by email and in-app notification.
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
