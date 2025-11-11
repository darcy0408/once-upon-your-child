# 13-Day Master Deployment Plan
**Story Weaver App - Production Launch**
**Created:** 2025-11-10
**Target Launch:** Day 13 (2025-11-23)

---

## 🎯 Overview

This plan combines:
- ✅ **Technical debt from Gemini's audit** (critical architectural fixes)
- ✅ **Feature roadmap** (feelings wheel, age-appropriate stories, parent tools)
- ✅ **Production readiness** (deployment, testing, documentation)

**Philosophy:** Ship something working in 13 days, then iterate. Focus on **critical blockers** first, **key differentiators** second, **nice-to-haves** never (until after launch).

---

## 📊 Priority Matrix

### 🚨 CRITICAL (Blocks Production)
1. Fix Railway API key issue ⚠️ **IN PROGRESS**
2. Migrate to PostgreSQL (SQLite won't scale)
3. Implement async task queue (stories take 30-60s to generate)
4. Fix CORS and environment configuration
5. Testing framework (prevent regressions)

### 🎯 HIGH (Key Differentiators)
6. Full feelings wheel integration ✅ **DONE**
7. Age-appropriate story system ✅ **DONE**
8. Post-story emotional check-in
9. Parent conversation starters
10. Offline mode improvements

### 💡 MEDIUM (Nice-to-Have)
11. Parent dashboard web portal
12. Story streak gamification
13. Frontend state management refactor
14. Backend modularization

---

## 📅 Day-by-Day Plan

### **Day 1-2: Critical Infrastructure** 🚨
**Owner:** Claude
**Goal:** Make the app actually work in production

#### Day 1 Morning
- [x] Fix Railway API key issue (selfless-renewal vs radiant-tranquility)
- [x] Consolidate to single Railway project
- [ ] Verify all endpoints working
- [ ] Test story generation (regular, interactive, learning to read)

#### Day 1 Afternoon
- [ ] Provision PostgreSQL database on Railway
- [ ] Update backend connection string
- [ ] Create database migration script from SQLite
- [ ] Test character creation/retrieval with PostgreSQL

#### Day 2 Morning
- [ ] Implement Redis on Railway (for task queue)
- [ ] Install Celery in backend
- [ ] Refactor `/generate-story` to use Celery tasks
- [ ] Create `/task-status/<task_id>` endpoint

#### Day 2 Afternoon
- [ ] Update frontend to poll task status
- [ ] Add loading states with progress indicator
- [ ] Test async story generation end-to-end
- [ ] Deploy and verify on production

**Deliverable:** App works reliably in production with async story generation

---

### **Day 3-4: Testing & Stability** ✅
**Owner:** Claude + Codex
**Goal:** Prevent regressions, enable confident deployment

#### Day 3
- [ ] **Backend Testing** (Claude)
  - [ ] Set up Pytest framework
  - [ ] Write API endpoint tests (generate-story, create-character)
  - [ ] Write service tests (prompt generation, emotion extraction)
  - [ ] Write model tests (Character CRUD)
  - [ ] Add to CI/CD (GitHub Actions)

- [ ] **Frontend Testing** (Codex)
  - [ ] Set up Flutter test framework
  - [ ] Write widget tests (character creation form)
  - [ ] Write integration tests (create character → generate story flow)
  - [ ] Test feelings wheel selection
  - [ ] Test age-appropriate mode toggles

#### Day 4
- [ ] Fix all failing tests
- [ ] Add test coverage reporting
- [ ] Document testing procedures in README
- [ ] Run full regression test suite

**Deliverable:** Core flows have test coverage, CI/CD running

---

### **Day 5-6: Post-Story Check-In** 📊
**Owner:** Claude
**Goal:** Complete the emotional processing loop

#### Day 5
- [ ] Create `PostStoryFeelingsDialog` widget
  - [ ] Reuse feelings wheel UI
  - [ ] Ask "How do you feel now?"
  - [ ] Record post-story emotion + intensity
  - [ ] Make it dismissible (not required)

- [ ] Update `SavedStory` model
  - [ ] Add `preStoryFeeling` field
  - [ ] Add `postStoryFeeling` field
  - [ ] Migrate existing stories

- [ ] Integrate into `StoryResultScreen`
  - [ ] Show dialog after story display
  - [ ] Calculate emotion delta
  - [ ] Display: "😟 Worried: 4 → 2 ✨"

#### Day 6
- [ ] Create `EmotionInsightsService`
  - [ ] `getEmotionTrends(days)` - frequency map
  - [ ] `getIntensityChanges()` - pre/post deltas
  - [ ] `getStoryImpact()` - which emotions improved most

- [ ] Create basic `InsightsScreen`
  - [ ] Show emotion frequency (bar chart)
  - [ ] Show intensity improvements
  - [ ] List recent check-ins with story links
  - [ ] Add to main navigation

- [ ] Test end-to-end emotional loop

**Deliverable:** Users can track emotional changes through stories

---

### **Day 7-8: Parent Tools** 👨‍👩‍👧
**Owner:** Claude + Codex
**Goal:** Make the app valuable for parents

#### Day 7 (Claude)
- [ ] Create `ConversationStarterService`
  - [ ] Build Gemini prompt for 3 questions
  - [ ] Question 1: About the emotion
  - [ ] Question 2: Action to try together
  - [ ] Question 3: Reflection on the story

- [ ] Add conversation starter card to `StoryResultScreen`
  - [ ] Show after story, before post-check-in
  - [ ] "Share with Parent" button (copy to clipboard)
  - [ ] Test generation quality

#### Day 8 (Codex)
- [ ] Enhance `InsightsScreen` UI
  - [ ] Add line chart for emotion intensity over time
  - [ ] Add "Emotion Details" tap → stories for that emotion
  - [ ] Polish colors, spacing, empty states
  - [ ] Add loading/error states

- [ ] Add premium upsell gate
  - [ ] Free: 7-day history
  - [ ] Premium: 30-day history + export PDF
  - [ ] Banner: "Unlock full insights"

**Deliverable:** Parents have tools to engage with their child's emotional journey

---

### **Day 9-10: Polish & Performance** ✨
**Owner:** Codex
**Goal:** Make the app feel professional

#### Day 9
- [ ] Improve offline functionality
  - [ ] Install Isar database
  - [ ] Cache all stories locally
  - [ ] Cache character list
  - [ ] Implement offline-first loading (show cached, then sync)
  - [ ] Add sync indicator

- [ ] Performance optimizations
  - [ ] Lazy-load character gallery images
  - [ ] Compress generated images before saving
  - [ ] Cache API responses (5min TTL)
  - [ ] Profile and fix slow screens

#### Day 10
- [ ] UI/UX polish
  - [ ] Consistent loading states everywhere
  - [ ] Better error messages (user-friendly)
  - [ ] Smooth transitions between screens
  - [ ] Fix any layout issues on different screen sizes
  - [ ] Accessibility: font scaling, contrast

- [ ] Story streak feature
  - [ ] Track consecutive days with story creation
  - [ ] Show streak counter on home screen
  - [ ] Celebrate milestones (3 day, 7 day, 30 day)
  - [ ] Unlock special theme/companion at 7 days

**Deliverable:** App feels polished and professional

---

### **Day 11: Documentation & Onboarding** 📚
**Owner:** Claude
**Goal:** Make the project maintainable

- [ ] Update `README.md`
  - [ ] Project purpose and value proposition
  - [ ] Architecture diagram (frontend/backend/database/queue)
  - [ ] Local development setup
  - [ ] Environment variables list
  - [ ] Deployment instructions

- [ ] Create `CONTRIBUTING.md`
  - [ ] Code style guidelines
  - [ ] Testing requirements
  - [ ] Branch naming conventions
  - [ ] PR review process

- [ ] Create `ARCHITECTURE.md`
  - [ ] System overview diagram
  - [ ] Database schema
  - [ ] API endpoints documentation
  - [ ] Service layer responsibilities

- [ ] Code documentation
  - [ ] Add docstrings to all public methods
  - [ ] Document complex algorithms (prompt builders)
  - [ ] Explain therapeutic story approach

**Deliverable:** Project is documented and onboarding-ready

---

### **Day 12: User Acceptance Testing** 🧪
**Owner:** Claude + Real Users
**Goal:** Find and fix bugs before launch

- [ ] Internal testing
  - [ ] Test all user flows end-to-end
  - [ ] Test on multiple devices (iOS, Android, web)
  - [ ] Test with different network conditions
  - [ ] Test error scenarios (no API key, timeout, etc.)

- [ ] Beta testing
  - [ ] Recruit 5-10 beta testers (parents with kids)
  - [ ] Provide testing instructions and feedback form
  - [ ] Monitor usage patterns and errors
  - [ ] Collect qualitative feedback

- [ ] Bug bash
  - [ ] Fix all critical bugs
  - [ ] Fix high-priority bugs
  - [ ] Document known issues (for post-launch)

**Deliverable:** App is tested with real users and major bugs fixed

---

### **Day 13: Launch Day** 🚀
**Owner:** Claude
**Goal:** Deploy to production and announce

#### Morning
- [ ] Final production deployment
  - [ ] Deploy backend to Railway
  - [ ] Deploy frontend to Netlify
  - [ ] Verify all services running
  - [ ] Run smoke tests on production

- [ ] Configure production settings
  - [ ] Set up monitoring (error tracking, uptime)
  - [ ] Configure backup schedule for database
  - [ ] Set up logging/analytics
  - [ ] Enable rate limiting on API

#### Afternoon
- [ ] Create launch materials
  - [ ] App Store listing (if mobile)
  - [ ] Landing page copy
  - [ ] Social media announcement
  - [ ] Demo video/screenshots

- [ ] Soft launch
  - [ ] Share with small group first
  - [ ] Monitor for issues
  - [ ] Quick fixes if needed

- [ ] Public launch
  - [ ] Publish to app stores
  - [ ] Share on social media
  - [ ] Notify beta testers
  - [ ] Monitor usage and errors

**Deliverable:** Story Weaver App is live and publicly available! 🎉

---

## 🔧 Technical Implementation Notes

### PostgreSQL Migration
```bash
# On Railway, provision PostgreSQL addon
# Update backend/app.py
DATABASE_URL = os.getenv('DATABASE_URL')  # Railway provides this
app.config['SQLALCHEMY_DATABASE_URI'] = DATABASE_URL

# Migration script
python migrate_sqlite_to_postgres.py
```

### Celery Setup
```python
# backend/celery_config.py
from celery import Celery

celery = Celery('story_weaver', broker=os.getenv('REDIS_URL'))

@celery.task
def generate_story_task(prompt):
    response = model.generate_content(prompt)
    return response.text

# backend/app.py
@app.route('/generate-story', methods=['POST'])
def generate_story():
    task = generate_story_task.delay(prompt)
    return jsonify({'task_id': task.id}), 202

@app.route('/task-status/<task_id>')
def task_status(task_id):
    task = generate_story_task.AsyncResult(task_id)
    if task.ready():
        return jsonify({'status': 'complete', 'result': task.result})
    return jsonify({'status': 'pending'})
```

### Frontend Task Polling
```dart
Future<String> _generateStoryAsync(String prompt) async {
  // 1. Start task
  final startResponse = await http.post(url, body: prompt);
  final taskId = jsonDecode(startResponse.body)['task_id'];

  // 2. Poll for completion
  while (true) {
    await Future.delayed(Duration(seconds: 2));
    final statusResponse = await http.get('/task-status/$taskId');
    final status = jsonDecode(statusResponse.body);

    if (status['status'] == 'complete') {
      return status['result'];
    }

    // Update progress UI
    setState(() => _loadingMessage = 'Still creating your story...');
  }
}
```

---

## 🚫 Out of Scope (Post-Launch)

These are great ideas from Gemini's audit, but not critical for Day 1:

1. **Frontend state management refactor** (Riverpod/BLoC)
   - Current approach works, just not elegant
   - Refactor AFTER launch when you have real usage data

2. **Backend modularization** (models/routes/services folders)
   - Nice-to-have for maintenance
   - Do AFTER launch during code cleanup sprint

3. **Parent dashboard web portal**
   - Excellent feature for retention
   - Build as v2.0 feature with proper user research

4. **Advanced gamification**
   - Story streak is enough for v1
   - More complex gamification after analyzing user behavior

---

## ✅ Success Criteria

### By Day 13, the app must:
1. ✅ Generate stories reliably (< 5% error rate)
2. ✅ Handle 10+ concurrent users without blocking
3. ✅ Store data persistently in PostgreSQL
4. ✅ Work offline (cached stories)
5. ✅ Track emotional check-ins (pre + post story)
6. ✅ Provide parent tools (conversation starters)
7. ✅ Have test coverage on critical paths
8. ✅ Be fully documented
9. ✅ Be deployed to production
10. ✅ Have monitoring and error tracking

---

## 📈 Post-Launch Priorities (Days 14-30)

### Week 3 (Days 14-20)
- Monitor production metrics and fix bugs
- Collect user feedback
- A/B test conversation starter effectiveness
- Improve prompt quality based on user stories

### Week 4 (Days 21-30)
- Refactor frontend with Riverpod (if needed)
- Modularize backend code
- Add advanced analytics
- Start building parent dashboard v1

---

## 🆘 Emergency Contacts & Resources

**If things go wrong:**
- Railway Dashboard: https://railway.app
- Netlify Dashboard: https://app.netlify.com
- GitHub Repo: https://github.com/darcy0408/story-weaver-app
- Gemini API Status: https://status.cloud.google.com

**Key Files to Monitor:**
- `backend/app.py` - All API endpoints
- `lib/services/api_service_manager.dart` - API calls
- `lib/main_story.dart` - Main story creation flow

**Rollback Plan:**
1. Revert to last known good commit
2. Redeploy backend: `git push origin main`
3. Rebuild frontend: `flutter build web --release && netlify deploy --prod`

---

## 📝 Daily Standup Format

**What was completed yesterday?**
**What will be worked on today?**
**Any blockers or risks?**

Use this format to stay on track and adjust the plan as needed.

---

**Remember:** The goal is to ship something working in 13 days, not to build the perfect app. You can iterate after launch. Focus on the critical path: fix infrastructure, complete emotional loop, add parent value, test thoroughly, launch confidently. 🚀
