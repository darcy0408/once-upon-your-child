# Codex 2 - Week 4 Tasks (Production Readiness & Legal)

**Assigned to**: Codex Instance 2
**Priority**: CRITICAL - Production launch blockers
**Timeline**: Week 4 (Nov 26 - Dec 3)
**Status**: Week 3 Complete ✅ (Interactive stories, BYOK, Analytics)

**Note**: Taking over remaining tasks from Gemini (session limit reached)

---

## 📊 Current Status

### ✅ Weeks 1-3 Completed
- Interactive story quality improvements (therapeutic choices)
- BYOK setup wizard (3-step, grandma-friendly)
- Analytics verification and documentation
- Grace period analytics
- Stripe initialization fix

### 📋 Week 4 Focus
Production-critical legal compliance and content safety

---

## Task C2-4.1: Privacy Policy & Terms of Service (Priority: CRITICAL)

**Blocker**: Cannot launch without these legal pages (required by app stores and COPPA).

**Objective**: Create legally compliant privacy policy and terms of service.

### Implementation Steps:

1. **Create Privacy Policy Page**
   - File: `lib/screens/privacy_policy_screen.dart` (NEW)
   - Must include:
     - Data collection practices
     - How user data is used
     - Third-party services (Gemini AI, Stripe)
     - Cookie usage (if applicable)
     - COPPA compliance (app targets children)
     - Parent/guardian consent mechanism
     - User rights (access, deletion)
     - Contact information

   ```dart
   // lib/screens/privacy_policy_screen.dart

   class PrivacyPolicyScreen extends StatelessWidget {
     @override
     Widget build(BuildContext context) {
       return Scaffold(
         appBar: AppBar(
           title: const Text('Privacy Policy'),
         ),
         body: SingleChildScrollView(
           padding: const EdgeInsets.all(16),
           child: Column(
             crossAxisAlignment: CrossAxisAlignment.start,
             children: [
               _buildSection(
                 title: 'Data We Collect',
                 content: '''
   We collect minimal data to provide our service:
   - Story preferences (character, theme choices)
   - Account information (if you create one)
   - Payment information (processed by Stripe, not stored by us)
   - Analytics (anonymous usage data to improve the app)
                 ''',
               ),

               _buildSection(
                 title: 'Children\'s Privacy (COPPA Compliance)',
                 content: '''
   Story Weaver is designed for children. We comply with COPPA:
   - We do NOT collect personal information from children under 13 without parental consent
   - Parents/guardians must approve account creation
   - We do NOT sell or share children's data
   - Parents can request deletion of their child's data at any time
                 ''',
               ),

               _buildSection(
                 title: 'Third-Party Services',
                 content: '''
   We use the following services:
   - Google Gemini AI: To generate stories (no personal data sent)
   - Stripe: For payment processing (PCI compliant)
   - Railway: For hosting (secure infrastructure)
                 ''',
               ),

               _buildSection(
                 title: 'Your Rights',
                 content: '''
   You have the right to:
   - Access your data
   - Request deletion of your data
   - Opt out of analytics
   - Withdraw consent at any time

   Contact us at: privacy@storyweaver.app
                 ''',
               ),

               _buildSection(
                 title: 'Updates to This Policy',
                 content: '''
   Last updated: ${DateTime.now().toString().split(' ')[0]}

   We may update this policy. Changes will be posted here.
                 ''',
               ),
             ],
           ),
         ),
       );
     }

     Widget _buildSection({required String title, required String content}) {
       return Column(
         crossAxisAlignment: CrossAxisAlignment.start,
         children: [
           Text(
             title,
             style: TextStyle(
               fontSize: 20,
               fontWeight: FontWeight.bold,
             ),
           ),
           SizedBox(height: 8),
           Text(
             content.trim(),
             style: TextStyle(fontSize: 16, height: 1.5),
           ),
           SizedBox(height: 24),
         ],
       );
     }
   }
   ```

2. **Create Terms of Service Page**
   - File: `lib/screens/terms_of_service_screen.dart` (NEW)
   - Must include:
     - Subscription terms
     - Refund policy
     - Content usage rights
     - Age requirements
     - Parent/guardian consent
     - Prohibited uses
     - Disclaimer
     - Termination policy

   ```dart
   // lib/screens/terms_of_service_screen.dart

   class TermsOfServiceScreen extends StatelessWidget {
     @override
     Widget build(BuildContext context) {
       return Scaffold(
         appBar: AppBar(
           title: const Text('Terms of Service'),
         ),
         body: SingleChildScrollView(
           padding: const EdgeInsets.all(16),
           child: Column(
             crossAxisAlignment: CrossAxisAlignment.start,
             children: [
               _buildSection(
                 title: 'Acceptance of Terms',
                 content: '''
   By using Story Weaver, you agree to these terms.
   If you are under 13, a parent/guardian must accept on your behalf.
                 ''',
               ),

               _buildSection(
                 title: 'Age Requirements',
                 content: '''
   - Children under 13: Require parental consent
   - Ages 13+: Can create account with parental knowledge
   - Parents/guardians are responsible for supervising use
                 ''',
               ),

               _buildSection(
                 title: 'Subscriptions',
                 content: '''
   - Free Tier: Limited stories, grace period available
   - Premium Tier: Unlimited stories, extra features
   - Family Tier: Multiple users, premium features
   - Subscriptions renew automatically unless canceled
   - Cancel anytime in Settings
                 ''',
               ),

               _buildSection(
                 title: 'Refund Policy',
                 content: '''
   - First month: Full refund if not satisfied
   - After first month: No refunds for partial months
   - Contact support@storyweaver.app for refund requests
                 ''',
               ),

               _buildSection(
                 title: 'Content Rights',
                 content: '''
   - Stories generated are for personal use only
   - You may share stories created with Story Weaver
   - You may NOT sell or commercially use generated content
   - Story Weaver retains the right to use aggregated data to improve service
                 ''',
               ),

               _buildSection(
                 title: 'Prohibited Uses',
                 content: '''
   Do NOT use Story Weaver to:
   - Generate inappropriate content
   - Violate any laws
   - Harass or harm others
   - Attempt to hack or break the service
                 ''',
               ),

               _buildSection(
                 title: 'Disclaimer',
                 content: '''
   Story Weaver is provided "as is."
   While we use AI to generate therapeutic stories, this is NOT a replacement for professional mental health care.
   If your child needs mental health support, please consult a licensed professional.
                 ''',
               ),

               _buildSection(
                 title: 'Contact',
                 content: '''
   Questions? Contact us at:
   support@storyweaver.app

   Last updated: ${DateTime.now().toString().split(' ')[0]}
                 ''',
               ),
             ],
           ),
         ),
       );
     }

     Widget _buildSection({required String title, required String content}) {
       // Same as PrivacyPolicyScreen
     }
   }
   ```

3. **Add Links Throughout App**
   - Settings screen footer
   - Stripe checkout flow (required)
   - Account creation flow
   - About screen

   ```dart
   // Add to lib/settings_screen.dart footer

   Column(
     children: [
       TextButton(
         onPressed: () => Navigator.push(
           context,
           MaterialPageRoute(builder: (_) => PrivacyPolicyScreen()),
         ),
         child: Text('Privacy Policy'),
       ),
       TextButton(
         onPressed: () => Navigator.push(
           context,
           MaterialPageRoute(builder: (_) => TermsOfServiceScreen()),
         ),
         child: Text('Terms of Service'),
       ),
     ],
   )
   ```

### Testing:
- [ ] Privacy policy covers all required topics
- [ ] Terms of service legally sound
- [ ] Links work from all locations
- [ ] Text is readable and understandable
- [ ] COPPA compliance verified

---

## Task C2-4.2: Parental Consent Flow (Priority: CRITICAL)

**Blocker**: COPPA requires parental consent for children under 13.

**Objective**: Implement age gate and parental consent mechanism.

### Implementation Steps:

1. **Add Age Gate on First Launch**
   ```dart
   // lib/screens/age_gate_screen.dart (NEW)

   class AgeGateScreen extends StatefulWidget {
     @override
     State<AgeGateScreen> createState() => _AgeGateScreenState();
   }

   class _AgeGateScreenState extends State<AgeGateScreen> {
     int? _userAge;

     @override
     Widget build(BuildContext context) {
       return Scaffold(
         body: Center(
           child: Card(
             margin: EdgeInsets.all(24),
             child: Padding(
               padding: EdgeInsets.all(24),
               child: Column(
                 mainAxisSize: MainAxisSize.min,
                 children: [
                   Text(
                     'Welcome to Story Weaver!',
                     style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                   ),
                   SizedBox(height: 16),
                   Text(
                     'How old are you?',
                     style: TextStyle(fontSize: 18),
                   ),
                   SizedBox(height: 16),

                   // Age selector
                   DropdownButton<int>(
                     value: _userAge,
                     hint: Text('Select your age'),
                     items: List.generate(100, (i) => i + 1).map((age) {
                       return DropdownMenuItem(
                         value: age,
                         child: Text('$age years old'),
                       );
                     }).toList(),
                     onChanged: (age) => setState(() => _userAge = age),
                   ),

                   SizedBox(height: 24),

                   ElevatedButton(
                     onPressed: _userAge == null ? null : _handleAgeSubmit,
                     child: Text('Continue'),
                   ),
                 ],
               ),
             ),
           ),
         ),
       );
     }

     void _handleAgeSubmit() {
       if (_userAge! < 13) {
         // Require parental consent
         Navigator.pushReplacement(
           context,
           MaterialPageRoute(builder: (_) => ParentalConsentScreen()),
         );
       } else {
         // Can use app with parental knowledge
         _showParentalKnowledgeDialog();
       }
     }

     void _showParentalKnowledgeDialog() {
       showDialog(
         context: context,
         barrierDismissible: false,
         builder: (context) => AlertDialog(
           title: Text('Parent/Guardian Notification'),
           content: Text(
             'If you are under 18, please make sure a parent or guardian knows you are using this app.',
           ),
           actions: [
             TextButton(
               onPressed: () {
                 Navigator.pop(context); // Close dialog
                 _proceedToApp();
               },
               child: Text('I Understand'),
             ),
           ],
         ),
       );
     }

     void _proceedToApp() {
       // Save age consent
       // Navigate to main app
     }
   }
   ```

2. **Add Parental Consent Screen (Under 13)**
   ```dart
   // lib/screens/parental_consent_screen.dart (NEW)

   class ParentalConsentScreen extends StatefulWidget {
     @override
     State<ParentalConsentScreen> createState() => _ParentalConsentScreenState();
   }

   class _ParentalConsentScreenState extends State<ParentalConsentScreen> {
     String? _parentEmail;
     bool _consentGiven = false;

     @override
     Widget build(BuildContext context) {
       return Scaffold(
         appBar: AppBar(title: Text('Parental Consent Required')),
         body: Padding(
           padding: EdgeInsets.all(24),
           child: Column(
             crossAxisAlignment: CrossAxisAlignment.start,
             children: [
               Text(
                 'Hello Parent/Guardian!',
                 style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
               ),
               SizedBox(height: 16),
               Text(
                 'Your child would like to use Story Weaver. '
                 'We need your permission because they are under 13 years old.',
                 style: TextStyle(fontSize: 16),
               ),
               SizedBox(height: 24),

               Text('What We Do:', style: TextStyle(fontWeight: FontWeight.bold)),
               Text('• Generate personalized stories using AI'),
               Text('• Provide therapeutic content for emotional growth'),
               Text('• Collect minimal data (story preferences only)'),
               Text('• Never sell or share your child\'s information'),

               SizedBox(height: 24),

               TextField(
                 decoration: InputDecoration(
                   labelText: 'Your Email (optional)',
                   hintText: 'parent@example.com',
                 ),
                 onChanged: (value) => _parentEmail = value,
               ),

               SizedBox(height: 16),

               CheckboxListTile(
                 title: Text('I am a parent/guardian and give permission'),
                 subtitle: Text('I have read the Privacy Policy and Terms of Service'),
                 value: _consentGiven,
                 onChanged: (value) => setState(() => _consentGiven = value!),
               ),

               SizedBox(height: 16),

               Row(
                 children: [
                   TextButton(
                     onPressed: () => Navigator.push(
                       context,
                       MaterialPageRoute(builder: (_) => PrivacyPolicyScreen()),
                     ),
                     child: Text('Privacy Policy'),
                   ),
                   TextButton(
                     onPressed: () => Navigator.push(
                       context,
                       MaterialPageRoute(builder: (_) => TermsOfServiceScreen()),
                     ),
                     child: Text('Terms of Service'),
                   ),
                 ],
               ),

               Spacer(),

               ElevatedButton(
                 onPressed: _consentGiven ? _submitConsent : null,
                 style: ElevatedButton.styleFrom(
                   minimumSize: Size(double.infinity, 48),
                 ),
                 child: Text('Give Permission'),
               ),
             ],
           ),
         ),
       );
     }

     void _submitConsent() {
       // Save parental consent
       // Log consent event
       // Navigate to app
     }
   }
   ```

### Testing:
- [ ] Age gate appears on first launch
- [ ] Under 13 requires parental consent
- [ ] 13+ shows parental knowledge dialog
- [ ] Consent is saved and persists
- [ ] Privacy/Terms links work

---

## Task C2-4.3: Content Safety Review (Priority: HIGH)

**Objective**: Ensure AI-generated content is always safe and appropriate.

### Implementation Steps:

1. **Add Content Filter to Backend**
   - File: `backend/app.py`
   - Check story output for inappropriate content
   - Block/sanitize problematic words
   - Log filtered content for review

   ```python
   # backend/app.py

   INAPPROPRIATE_KEYWORDS = [
       'violence', 'weapon', 'death', 'kill',
       # Add more as needed
   ]

   def filter_story_content(story_text: str) -> tuple[str, bool]:
       """Filter inappropriate content from stories.
       Returns (filtered_text, had_issues)"""

       had_issues = False
       filtered = story_text

       for keyword in INAPPROPRIATE_KEYWORDS:
           if keyword.lower() in filtered.lower():
               had_issues = True
               # Log for review
               logger.warning(f"Content filter triggered: {keyword}")

       return filtered, had_issues
   ```

2. **Add Report Mechanism**
   - File: `lib/story_result_screen.dart`
   - Add "Report Issue" button
   - Allow users to flag inappropriate content
   - Send reports to backend

3. **Review Prompts for Safety**
   - Audit all AI prompts
   - Ensure age-appropriate language
   - Test edge cases (unusual names, themes)

### Testing:
- [ ] Content filter blocks inappropriate words
- [ ] Report button works
- [ ] All prompts produce safe content
- [ ] Edge cases tested

---

## Task C2-4.4: Production Deployment Checklist (Priority: HIGH)

**Objective**: Prepare for production launch.

### Implementation Steps:

1. **Railway Environment Variables**
   - [ ] Verify all env vars set correctly
   - [ ] Stripe in test mode or live mode (decide)
   - [ ] Gemini API key rotated (if needed)
   - [ ] Database backed up

2. **Monitoring Setup**
   - [ ] Railway alerts configured
   - [ ] Uptime monitoring active (UptimeRobot)
   - [ ] Error logging verified

3. **Final Testing**
   - [ ] Test all critical flows
   - [ ] Verify Stripe subscriptions work
   - [ ] Test BYOK wizard
   - [ ] Verify analytics fire correctly

4. **Documentation**
   - [ ] Update DEPLOYMENT_STATUS.md
   - [ ] Document rollback procedure
   - [ ] Create emergency contact list

---

## Priority Order

1. **C2-4.1**: Privacy Policy & Terms (CRITICAL - legal blocker)
2. **C2-4.2**: Parental Consent (CRITICAL - COPPA compliance)
3. **C2-4.4**: Production Checklist (HIGH - launch readiness)
4. **C2-4.3**: Content Safety (HIGH - user safety)

---

## Deliverables

- [ ] Privacy policy page created and linked
- [ ] Terms of service page created and linked
- [ ] Age gate implemented
- [ ] Parental consent flow working
- [ ] Content filter active
- [ ] Report mechanism functional
- [ ] Production deployment checklist complete
- [ ] All legal compliance verified

---

## Success Criteria

- [ ] COPPA compliant (age gate + parental consent)
- [ ] Privacy policy and terms accessible
- [ ] Content safety measures active
- [ ] Ready for production launch
- [ ] No legal blockers remaining

---

## CRITICAL NOTES

⚠️ **These tasks are BLOCKERS for production launch**
⚠️ **Do NOT skip parental consent flow**
⚠️ **Content safety is non-negotiable**

All of these must be complete before any public launch or app store submission.
