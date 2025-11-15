// lib/privacy_policy_screen.dart

import 'package:flutter/material.dart';

class PrivacyPolicyScreen extends StatelessWidget {
  const PrivacyPolicyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Privacy Policy'),
        backgroundColor: Colors.blue.shade400,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.blue.shade200),
              ),
              child: Column(
                children: [
                  Icon(
                    Icons.privacy_tip,
                    size: 48,
                    color: Colors.blue.shade700,
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Story Weaver Privacy Policy',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Colors.blue.shade700,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Effective: November 15, 2024',
                    style: TextStyle(
                      color: Colors.blue.shade600,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // Our Commitment
            _buildSection(
              'Our Commitment to Privacy',
              'Story Weaver is committed to protecting the privacy and safety of children and families who use our therapeutic storytelling platform. We believe that emotional health tools should be safe, transparent, and respectful of personal boundaries.',
              Icons.shield,
              Colors.green,
            ),

            // Information We Collect
            _buildSection(
              'Information We Collect',
              '• Account Information: Email, username, age range\n• Usage Data: Story patterns, therapeutic engagement\n• Child Safety Data: Emotional check-ins, therapeutic progress\n\nAll data collection serves therapeutic and educational purposes only.',
              Icons.info,
              Colors.blue,
            ),

            // How We Use Information
            _buildSection(
              'How We Use Information',
              '• Personalize emotional learning experiences\n• Track therapeutic progress and growth\n• Improve app functionality and safety\n• Provide appropriate content based on age and needs\n\nWe do NOT sell data or use it for advertising.',
              Icons.analytics,
              Colors.purple,
            ),

            // Data Security
            _buildSection(
              'Data Security',
              '• End-to-end encryption for sensitive data\n• Secure server infrastructure\n• Regular security audits\n• Limited data retention\n• Access controls and monitoring',
              Icons.security,
              Colors.orange,
            ),

            // Children's Privacy
            _buildSection(
              'Children\'s Privacy',
              '• Designed for ages 4-12\n• Parents have full access to child data\n• No advertising or marketing data collection\n• All features support emotional development\n• Age-appropriate content and interactions',
              Icons.child_care,
              Colors.pink,
            ),

            // Parental Rights
            _buildSection(
              'Parental Rights',
              '• Full access to child\'s data\n• Request data correction or deletion\n• Control sharing and third-party access\n• Export therapeutic progress\n• Manage account settings',
              Icons.family_restroom,
              Colors.teal,
            ),

            // Professional Disclaimer
            Container(
              padding: const EdgeInsets.all(20),
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                color: Colors.amber.shade50,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.amber.shade200),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.warning, color: Colors.amber.shade700),
                      const SizedBox(width: 8),
                      Text(
                        'Professional Support',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.amber.shade700,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'Story Weaver provides therapeutic tools and resources, but is not a substitute for professional mental health care. If your child experiences severe emotional distress, please consult a qualified mental health professional.',
                    style: TextStyle(height: 1.4),
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'Crisis Resources:\n• Emergency: 911\n• National Suicide Prevention: 988\n• Crisis Text Line: Text HOME to 741741',
                    style: TextStyle(
                      fontWeight: FontWeight.w500,
                      height: 1.4,
                    ),
                  ),
                ],
              ),
            ),

            // Contact
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.grey.shade50,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey.shade200),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Questions or Concerns?',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    '• Email: privacy@storyweaver.app\n• Support: In-app help section\n• Emergency: Contact local authorities',
                    style: TextStyle(height: 1.4),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 32),

            // Accept Button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => Navigator.of(context).pop(),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue.shade400,
                  padding: const EdgeInsets.all(16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text(
                  'I Understand',
                  style: TextStyle(fontSize: 16),
                ),
              ),
            ),

            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  Widget _buildSection(String title, String content, IconData icon, Color color) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: color.withOpacity(0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            content,
            style: const TextStyle(
              fontSize: 14,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }
}