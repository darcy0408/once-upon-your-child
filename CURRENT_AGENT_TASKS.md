# Current Agent Tasks - Week 4 (Nov 26, 2025)

**Last Updated:** 2025-11-26 01:15 UTC
**Status:** Week 4 in progress (28% complete)

---

## 🎯 CODEX 1 - Next Task

**Current Status:** C4.1 Story Library (80% complete) ✅

**NEXT: Task C4.2 - Onboarding Improvements**

### Objective
Reduce onboarding abandonment from 70% to <30% by making it faster and more skippable.

### What to Build

1. **Add Progress Indicator to Onboarding**
   - File: `lib/onboarding_screen.dart`
   - Show "Step X of Y" at top
   - Add LinearProgressIndicator
   - Track completion rate in analytics

   ```dart
   // Add at top of onboarding screen
   Column(
     children: [
       Text('Step ${_currentStep + 1} of $_totalSteps'),
       LinearProgressIndicator(
         value: (_currentStep + 1) / _totalSteps,
       ),
     ],
   )
   ```

2. **Allow Skip with Reminder Dialog**
   - Add "Skip for now" button on each step
   - Show dialog: "You can always complete your profile later in Settings"
   - Track skip events in analytics: `OnboardingAnalytics.trackSkipped(currentStep: X)`

   ```dart
   TextButton(
     onPressed: () async {
       final skip = await showDialog<bool>(
         context: context,
         builder: (context) => AlertDialog(
           title: Text('Skip for now?'),
           content: Text('You can complete your profile later in Settings.'),
           actions: [
             TextButton(
               onPressed: () => Navigator.pop(context, false),
               child: Text('Continue'),
             ),
             TextButton(
               onPressed: () => Navigator.pop(context, true),
               child: Text('Skip'),
             ),
           ],
         ),
       );

       if (skip == true) {
         OnboardingAnalytics.trackSkipped(currentStep: _currentStep);
         Navigator.pop(context); // Exit onboarding
       }
     },
     child: Text('Skip for now'),
   )
   ```

3. **Reduce Onboarding Steps**
   - Current: 5-6 steps (too long!)
   - Target: 3 essential steps only
   - Essential steps:
     1. **Welcome** - App purpose, what it does
     2. **Character Creation** - Use templates for quick setup
     3. **First Story Preview** - Generate a sample story
   - Move to optional/settings: Feelings corner, therapeutic customization

### Testing Checklist
- [ ] Progress indicator shows correct step X of Y
- [ ] Progress bar fills accurately
- [ ] Skip dialog shows and works correctly
- [ ] Skip analytics event fires
- [ ] Can complete onboarding in <2 minutes
- [ ] Reduced steps still cover essentials

### Files to Modify
- `lib/onboarding_screen.dart` - Main changes here
- `lib/services/story_analytics.dart` - Add skip tracking

### Success Criteria
- Onboarding completion time <2 minutes (down from 5+ minutes)
- Skip option clearly visible but doesn't encourage abandonment
- Analytics track completion vs. skip rate
- User can still complete profile later from Settings

---

## 🎯 CODEX 2 - Next Task

**Current Status:** C2-4.1 Privacy Policy ✅, C2-4.2 Parental Consent ✅

**NEXT: Task C2-4.3 - Content Safety Review**

### Objective
Ensure all AI-generated content is safe and appropriate for children. Add filtering and reporting mechanisms.

### What to Build

1. **Add Content Filter to Backend**
   - File: `backend/app.py`
   - Filter inappropriate words from story output
   - Log filtered content for review
   - Return safe content to frontend

   ```python
   # backend/app.py

   INAPPROPRIATE_KEYWORDS = [
       'violence', 'weapon', 'death', 'kill', 'hurt', 'blood',
       'scary', 'monster', 'nightmare',
       # Add more as needed - keep it sensible for kids' stories
   ]

   def filter_story_content(story_text: str) -> tuple[str, bool]:
       """Filter inappropriate content from stories.
       Returns (filtered_text, had_issues)"""

       had_issues = False
       filtered = story_text

       # Check for problematic keywords
       lower_text = filtered.lower()
       for keyword in INAPPROPRIATE_KEYWORDS:
           if keyword in lower_text:
               had_issues = True
               logger.warning(f"Content filter triggered: {keyword} in story")
               # Log the full story for manual review
               logger.warning(f"Flagged story content: {story_text[:200]}...")

       # If issues found, you could replace words or reject entirely
       # For now, just log and allow (Gemini is already safe)

       return filtered, had_issues

   # Use in generate-story endpoint
   @app.route('/generate-story', methods=['POST'])
   def generate_story():
       # ... existing code ...
       story_text = generate_with_gemini(...)

       # Filter content
       filtered_text, had_issues = filter_story_content(story_text)
       if had_issues:
           logger.warning("Story contained flagged content - review needed")

       return jsonify({'story': filtered_text, ...})
   ```

2. **Add Report Button to Story Screens**
   - Files: `lib/story_result_screen.dart`, `lib/saved_stories_screen.dart`
   - Add "Report Issue" button/icon
   - Send report to backend with story ID and optional user comment

   ```dart
   // Add to story result screen actions
   IconButton(
     icon: Icon(Icons.flag_outlined),
     tooltip: 'Report inappropriate content',
     onPressed: () => _showReportDialog(),
   )

   void _showReportDialog() {
     showDialog(
       context: context,
       builder: (context) => AlertDialog(
         title: Text('Report Issue'),
         content: Column(
           mainAxisSize: MainAxisSize.min,
           children: [
             Text('Is there something wrong with this story?'),
             SizedBox(height: 16),
             TextField(
               decoration: InputDecoration(
                 hintText: 'Optional: Tell us what\'s wrong',
               ),
               maxLines: 3,
               onChanged: (value) => _reportReason = value,
             ),
           ],
         ),
         actions: [
           TextButton(
             onPressed: () => Navigator.pop(context),
             child: Text('Cancel'),
           ),
           TextButton(
             onPressed: () {
               _submitReport();
               Navigator.pop(context);
               ScaffoldMessenger.of(context).showSnackBar(
                 SnackBar(content: Text('Report submitted. Thank you!')),
               );
             },
             child: Text('Report'),
           ),
         ],
       ),
     );
   }

   Future<void> _submitReport() async {
     // Send to backend
     await http.post(
       Uri.parse('$apiUrl/report-story'),
       body: jsonEncode({
         'story_id': widget.story.id,
         'reason': _reportReason ?? 'No reason provided',
         'timestamp': DateTime.now().toIso8601String(),
       }),
     );
   }
   ```

3. **Add Report Endpoint to Backend**
   ```python
   # backend/app.py

   @app.route('/report-story', methods=['POST'])
   def report_story():
       """Handle user reports of inappropriate content"""
       data = request.get_json()
       story_id = data.get('story_id')
       reason = data.get('reason', 'No reason provided')

       # Log the report
       logger.warning(f"⚠️ CONTENT REPORT - Story ID: {story_id}, Reason: {reason}")

       # TODO: Store in database for review
       # For now, logging is sufficient

       return jsonify({'status': 'reported', 'message': 'Thank you for your report'})
   ```

4. **Review All AI Prompts for Safety**
   - File: `backend/app.py` (search for all Gemini prompt constructions)
   - Ensure prompts explicitly request age-appropriate content
   - Add safety instructions to system prompts
   - Test edge cases: unusual names, dark themes

   ```python
   # Example safety enhancement to prompts
   system_prompt = """
   You are a children's storyteller creating safe, age-appropriate stories.

   SAFETY RULES:
   - Use only positive, uplifting themes
   - Avoid violence, scary content, or frightening situations
   - Keep language simple and friendly
   - Focus on friendship, courage, kindness, and fun
   - Never include inappropriate content for children ages 4-12

   Create an engaging, therapeutic story that helps children explore emotions in a safe way.
   """
   ```

### Testing Checklist
- [ ] Content filter catches inappropriate keywords
- [ ] Filtered content is logged for review
- [ ] Report button appears on story screens
- [ ] Report dialog works correctly
- [ ] Report is sent to backend and logged
- [ ] All AI prompts reviewed and include safety instructions
- [ ] Test edge cases: unusual character names, dark themes

### Files to Modify
- `backend/app.py` - Content filter and report endpoint
- `lib/story_result_screen.dart` - Add report button
- `lib/saved_stories_screen.dart` - Add report button (optional)

### Success Criteria
- Content filter active and logging any issues
- Report mechanism functional and easy to find
- All prompts include explicit safety instructions
- Zero inappropriate content in test generation (try 20+ stories)

---

## 🎯 GROK - Next Task

**Current Status:** Week 4 not started

**START: Task GR4.1 - API Rate Limiting Enhancement**

### Objective
Protect backend from abuse and excessive API costs with tier-based rate limiting.

### What to Build

1. **Enhance Rate Limiter with User Identification**
   - File: `backend/app.py`
   - Current: IP-based only
   - Add: User ID-based limiting (more accurate)

   ```python
   # backend/app.py (update existing get_user_identifier function)

   def get_user_identifier():
       """Get user ID from request or fall back to IP address"""
       # Already implemented in current code - verify it's working
       user_id = request.headers.get('X-User-ID')

       if not user_id and hasattr(g, 'user_id'):
           user_id = g.user_id

       if not user_id:
           try:
               from flask_jwt_extended import get_jwt_identity
               user_id = get_jwt_identity()
           except:
               pass

       if user_id:
           return f"user:{user_id}"
       else:
           return f"ip:{get_remote_address()}"
   ```

2. **Implement Tier-Based Rate Limits**
   - Already partially implemented in `get_tier_limits()` function
   - Add specific decorators to endpoints

   ```python
   # backend/app.py

   # Update existing limits to be more granular
   def get_tier_limits(operation='default'):
       """Get rate limits based on user tier"""
       tier = get_user_tier()

       limits = {
           'story_generation': {
               'free': "3/minute; 10/hour; 50/day",
               'premium': "10/minute; 100/hour",
               'family': "15/minute; 200/hour",
               'byok': None  # No limits
           },
           'interactive': {
               'free': "2/minute; 8/hour; 30/day",
               'premium': "8/minute; 80/hour",
               'family': "12/minute; 150/hour",
               'byok': None
           },
           'expensive': {  # Images, illustrations
               'free': "1/minute; 5/hour; 10/day",
               'premium': "3/minute; 20/hour",
               'family': "5/minute; 30/hour",
               'byok': None
           }
       }

       return limits.get(operation, limits['story_generation']).get(tier, limits['story_generation']['free'])

   # Apply to endpoints (update existing decorators)
   @app.route('/generate-story', methods=['POST'])
   @limiter.limit(lambda: get_tier_limits('story_generation') or "1000/hour")
   def generate_story():
       pass

   @app.route('/generate-interactive-choice', methods=['POST'])
   @limiter.limit(lambda: get_tier_limits('interactive') or "1000/hour")
   def generate_interactive_choice():
       pass

   @app.route('/generate-illustrations', methods=['POST'])
   @limiter.limit(lambda: get_tier_limits('expensive') or "100/hour")
   def generate_illustrations():
       pass
   ```

3. **Add Rate Limit Headers to Responses**
   - Show users their rate limit status

   ```python
   # backend/app.py

   @app.after_request
   def add_rate_limit_headers(response):
       """Add rate limit information to response headers"""
       try:
           # Flask-Limiter already adds some headers, enhance them
           # X-RateLimit-Limit: Maximum requests allowed
           # X-RateLimit-Remaining: Requests remaining
           # X-RateLimit-Reset: Time when limit resets

           # Add custom header with user's tier
           tier = get_user_tier()
           response.headers['X-User-Tier'] = tier

       except Exception as e:
           # Don't break the response if headers fail
           logger.debug(f"Failed to add rate limit headers: {e}")

       return response
   ```

4. **Add Rate Limit Exceeded Error Handling**
   ```python
   # backend/app.py

   @app.errorhandler(429)
   def ratelimit_handler(e):
       """Custom handler for rate limit exceeded"""
       tier = get_user_tier()

       if tier == 'free':
           message = "You've reached your free tier limit. Upgrade to Premium for more stories!"
           upgrade_url = "/subscription"
       else:
           message = f"Rate limit exceeded for {tier} tier. Please wait a moment before trying again."
           upgrade_url = None

       return jsonify({
           'error': 'rate_limit_exceeded',
           'message': message,
           'tier': tier,
           'upgrade_url': upgrade_url,
           'retry_after': e.description  # Seconds until reset
       }), 429
   ```

### Testing Checklist
- [ ] Free tier limits enforced (3/min, 10/hour, 50/day for stories)
- [ ] Premium tier gets higher limits (10/min, 100/hour)
- [ ] BYOK users bypass all limits
- [ ] Rate limit headers present in responses
- [ ] User tier correctly identified from headers
- [ ] 429 error returns helpful message with upgrade path
- [ ] Test with multiple user IDs and IPs

### Files to Modify
- `backend/app.py` - Main changes here (enhance existing rate limiting code)

### Success Criteria
- Free users limited to prevent abuse (3/min, 10/hour, 50/day)
- Premium users have comfortable limits (10/min, 100/hour)
- BYOK users unlimited (bypasses all limits)
- Clear error messages when limits hit
- Rate limit info visible in response headers

### Load Testing (Optional but Recommended)
```bash
# Test rate limiting with curl
for i in {1..15}; do
  curl -X POST https://story-weaver-app-production.up.railway.app/generate-story \
    -H "Content-Type: application/json" \
    -H "X-User-ID: test-free-user" \
    -d '{"character":"Test","theme":"Adventure"}' \
    -w "\nStatus: %{http_code}\n"
  sleep 10  # Wait 10 seconds between requests
done

# Should see 429 errors after 3 requests within a minute
```

---

## 📊 Week 4 Progress Tracker

### CODEX 1
- ✅ C4.1: Story Library (80% complete)
- ⏳ C4.2: Onboarding (NEXT - instructions above)
- ⏳ C4.3: Settings Polish
- ⏳ C4.4: Accessibility
- ⏳ C4.5: Performance

### CODEX 2
- ✅ C2-4.1: Privacy Policy & Terms
- ✅ C2-4.2: Parental Consent
- ⏳ C2-4.3: Content Safety (NEXT - instructions above)
- ⏳ C2-4.4: Deployment Checklist

### GROK
- ⏳ GR4.1: Rate Limiting (NEXT - instructions above)
- ⏳ GR4.2: Database Optimization
- ⏳ GR4.3: Deployment Automation
- ⏳ GR4.4: Cost Monitoring
- ⏳ GR4.5: Monitoring Dashboard

**Overall:** 28% complete (4 of 14 tasks done/partial)

---

## 🚀 When You Complete Your Task

1. **Test thoroughly** using the checklist provided
2. **Update your task file** - Mark task as complete
3. **Update TEAM_COORDINATION.md** - Add completion message
4. **Commit and push** - Use clear commit message
5. **Report back** - Tell me what you completed and what's next

---

## ❓ Questions or Issues?

- Check your task file (`CODEX1_WEEK4_TASKS.md`, `CODEX2_WEEK4_TASKS.md`, `GROK_WEEK4_TASKS.md`) for more details
- Review `AGENT_INSTRUCTIONS.md` for general guidelines
- Ask in TEAM_COORDINATION.md if you need clarification

**Let's ship Week 4! 🎉**
