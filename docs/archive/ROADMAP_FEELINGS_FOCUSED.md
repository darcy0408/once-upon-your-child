# Feelings-Focused Roadmap - Q1 2025

## Vision
Build the most therapeutically effective children's story app by going **deep on emotional processing** rather than wide on gamification features.

---

## Core Principle
Every feature must answer: **"Does this help children understand and process their feelings better?"**

---

## The 5 Pillars (Priority Order)

### ✅ Pillar 1: Emotion-Adaptive Stories (DONE)
**Status:** Implemented on main branch
**What it does:**
- Pre-story feelings check-in captures current emotion
- AI generates stories that acknowledge the feeling
- Stories show physical sensations and model coping strategies
- Validates that all feelings are okay

**Metrics:**
- Story relevance rating: +15% target
- Emotion recognition: Track pre vs post-story feeling
- Parent feedback: "Story felt personalized"

**Next Enhancement:** Wire intensity slider to story pacing (Week 2)

---

### 🎯 Pillar 2: Emotion Insights & Patterns (BUILD FIRST)
**Why:** Parents and therapists need to see emotional patterns to provide support
**Timeline:** Weeks 1-2

#### 2A. Emotion Trends Dashboard (Week 1)
**Feature:**
- 7-day emotion chart showing which feelings were explored
- Simple bar chart: emotion frequency + average intensity
- "Your child explored 5 different emotions this week"
- Tap emotion to see which stories addressed it

**Free Tier:**
- Last 7 days of data
- Basic emotion frequency chart

**Premium Tier:**
- 30-day history
- Intensity trends over time
- Export to PDF for therapists

**Implementation:**
```dart
// Track in SharedPreferences alongside check-ins
class EmotionInsightsService {
  Future<Map<String, EmotionTrend>> getWeeklyTrends();
  Future<List<EmotionCheckIn>> getEmotionHistory(int days);
  Future<String> generateInsightsSummary(); // AI-powered
}
```

**UI Location:** New "Insights" tab in main navigation

**Success Metric:** 40%+ of parents view insights weekly

---

#### 2B. Post-Story Emotional Check (Week 2)
**Feature:**
- After story ends, ask: "How does [Character] feel now?"
- Show same feeling wheel as pre-story
- Compare before/after to show emotional journey
- Save delta: "Anxiety went from 4 → 2"

**Why This Matters:**
- Validates that stories help process emotions
- Teaches kids emotions can shift
- Provides data on story effectiveness

**Implementation:**
- Reuse `PreStoryFeelingsDialog` as `PostStoryFeelingsDialog`
- Store both `preStoryEmotion` and `postStoryEmotion` in saved story
- Calculate emotion shift delta

**UI:** Appears automatically after story ends (skippable)

**Success Metric:**
- 30%+ completion rate
- Average intensity drop of 1+ point for negative emotions

---

### 🗣️ Pillar 3: Parent-Child Connection Tools (Weeks 3-4)

#### 3A. Conversation Starters (Week 3)
**Feature:**
- After story, generate 3 AI-powered discussion prompts
- Tailored to the specific emotion from today's check-in
- Examples:
  - *"[Child] felt worried today. Ask: What made the worry smaller in the story?"*
  - *"[Character] used deep breathing. Try it together for 30 seconds!"*
  - *"What was the bravest thing [Character] did?"*

**Free Tier:**
- 3 basic prompts per story
- View on screen only

**Premium Tier:**
- 5 detailed prompts with therapeutic rationale
- Printable PDF with story summary
- Email to parent with additional resources

**Implementation:**
```dart
class ConversationStarterService {
  Future<List<String>> generatePrompts({
    required CurrentFeeling feeling,
    required String storyText,
    required String characterName,
  }) async {
    // Use Gemini to extract story themes + emotion work
    // Generate age-appropriate questions
  }
}
```

**UI:** New card at bottom of `StoryResultScreen`

**Success Metric:**
- 25%+ of parents use prompts
- Parent NPS +10 points

---

#### 3B. Weekly Emotion Summary Email (Week 4)
**Feature:**
- Every Sunday, email parents a gentle summary:
  - "This week [Child] explored: Worried (3x), Excited (2x), Sad (1x)"
  - "Most used coping strategy: Deep breathing"
  - "Stories created: 4"
  - "Suggested conversation: Talk about what makes worries smaller"
- Link back to app to view full insights

**Free Tier:**
- Basic summary (emotions + count)

**Premium Tier:**
- Detailed patterns
- Therapist-approved suggestions
- Printable weekly report

**Implementation:**
- Backend cron job (Sunday 8am parent's timezone)
- Pull last 7 days of emotion check-ins
- Use AI to generate insights summary
- Send via SendGrid/Mailgun

**Privacy:**
- Double opt-in required
- Unsubscribe prominent
- No child PII in email (only first name)

**Success Metric:**
- 15%+ open rate
- 5%+ click-through to app

---

### 🎨 Pillar 4: Sensory Environment Adaptation (Weeks 5-6)

#### 4A. Bedtime Fade-Out (Week 5)
**Feature:**
- Based on pre-story anxiety intensity, adjust story pacing
- High anxiety (4-5): Slower pace, gentler TTS voice, longer fade
- Low anxiety (1-2): Normal pace
- Gradual volume + speed reduction over final 2 minutes
- Optional: Soft background sounds (rain, white noise)

**Implementation:**
```dart
class BedtimeFadeService {
  Future<void> applyFadeOut({
    required int anxietyLevel,
    required AudioPlayer ttsPlayer,
  }) {
    final fadeDuration = anxietyLevel >= 4 ? 120 : 60; // seconds
    final targetVolume = 0.0;
    final targetSpeed = 0.8;

    // Gradually reduce volume and speed
  }
}
```

**UI:**
- Toggle in settings: "Bedtime Mode"
- Auto-activates if story created after 7pm + anxiety > 3

**Success Metric:**
- D7 retention +8%
- Parent feedback: "Helped bedtime routine"

---

#### 4B. Low-Stimulus Mode (Week 6)
**Feature:**
- Toggle for neurodiverse kids or high-anxiety moments
- Reduces: animations, transitions, bright colors
- Increases: white space, reading time, button size
- Audio-only story option (no visuals)
- Simple sans-serif font

**When to Suggest:**
- Post-story emotion check shows "Overwhelmed"
- Parent manually enables in settings
- Character profile notes: "Prefers calm environment"

**Implementation:**
```dart
class AccessibilityService {
  bool isLowStimEnabled();

  Widget adaptWidget(Widget child) {
    if (isLowStimEnabled()) {
      return child.withReducedAnimations()
                  .withSimpleFonts()
                  .withMutedColors();
    }
    return child;
  }
}
```

**UI:**
- New "Accessibility" section in settings
- Prominent toggle with preview

**Success Metric:**
- 8%+ of users enable
- D7 retention +5% for enabled users

---

### 🌱 Pillar 5: Reflection & Growth (Week 7-8)

#### 5A. Emotion Journey Timeline (Week 7)
**Feature:**
- Visual timeline showing emotional growth over time
- Each story = node with emotion badge
- Tap node to see: story title, emotion, intensity, what helped
- "Worry" nodes get smaller over time (visual metaphor)
- Celebrate patterns: "You felt brave 5 times this month!"

**Why This Matters:**
- Shows kids emotions are temporary
- Builds awareness of what coping strategies work
- Creates sense of accomplishment without gamification

**Free Tier:**
- Last 30 days
- Basic timeline view

**Premium Tier:**
- Unlimited history
- Export timeline as PDF for therapists
- AI-generated growth insights

**Implementation:**
```dart
class EmotionJourneyService {
  Future<List<EmotionJourneyNode>> buildTimeline({
    required String characterId,
    int days = 30,
  });

  Future<String> generateGrowthInsights(List<EmotionJourneyNode> nodes);
}
```

**UI:** New screen accessible from Insights tab

**Success Metric:**
- 20%+ weekly views
- Kids self-report: "I can see I'm getting better at handling feelings"

---

#### 5B. Coping Strategy Tracker (Week 8)
**Feature:**
- After story, highlight which coping strategy was used
- Track which strategies character tries most
- Simple visual: "Deep breathing: ⭐⭐⭐⭐⭐ (5 times)"
- Suggest trying new ones: "Try talking to a friend next time?"

**Why This Matters:**
- Builds coping repertoire
- Shows what works for this specific child
- Encourages trying different strategies

**Free Tier:**
- Track up to 5 strategies
- Basic counter

**Premium Tier:**
- Unlimited tracking
- Effectiveness ratings (did it help?)
- Therapist export

**Implementation:**
```dart
class CopingStrategyService {
  Future<void> recordStrategyUsed(String strategy, bool wasEffective);
  Future<Map<String, int>> getStrategyFrequency();
  Future<List<String>> suggestNewStrategies(List<String> alreadyTried);
}
```

**UI:** Small card on story result screen

**Success Metric:**
- Kids can name 3+ coping strategies
- Strategy variety increases over time

---

## 🚫 What We're NOT Building (And Why)

### ❌ Daily Quests / Sticker Collections
**Why not:** Turns therapy into a game. Kids chase stickers, not emotional growth.
**Alternative:** Emotion journey timeline celebrates real growth, not arbitrary tasks.

### ❌ Aura Glows / XP Systems
**Why not:** External rewards undermine intrinsic motivation to process feelings.
**Alternative:** Visual emotion timeline shows real progress authentically.

### ❌ Streak Notifications
**Why not:** Creates pressure and guilt when streaks break.
**Alternative:** Gentle weekly summary emails for parents only.

### ❌ Sibling Co-Play
**Why not:** Complex to build (4-5 weeks), serves small audience, adds sync risks.
**Alternative:** Multi-character stories already exist for siblings.

### ❌ Custom Companion Creator
**Why not:** Scope creep, moderation risks, doesn't deepen emotional processing.
**Alternative:** Existing companions are therapeutic archetypes (loyal, wise, etc).

---

## 📊 Success Metrics Framework

### Primary Metrics (North Star)
1. **D7 Retention:** 50% baseline → 60% target (+10%)
2. **Parent NPS:** 40 baseline → 55 target (+15 points)
3. **Emotion Literacy:** Kids can name 5+ emotions (self-report survey)

### Secondary Metrics
4. **Story Relevance:** "Story felt personal" rating 70%+
5. **Emotional Shift:** Average intensity drop of 1+ point
6. **Parent Engagement:** 25%+ use conversation starters
7. **Insight Views:** 40%+ of parents check weekly trends

### Therapeutic Validation
8. **Clinical Feedback:** 5+ therapists endorse app
9. **Parent Testimonials:** "Helped my child understand feelings"
10. **Academic Partnership:** Partner with 1 university for efficacy study

---

## 🧪 Experiment Suite (8 Weeks)

### Week 2: Post-Story Check Placement
**Hypothesis:** Immediate post-story check will have 30%+ completion
**Variants:**
- A: Right after story ends
- B: 5 minutes later (gives processing time)
**Metric:** Completion rate
**Success:** 30%+ complete, higher quality responses

---

### Week 3: Conversation Starter Depth
**Hypothesis:** 3 simple questions will have higher usage than 5 detailed
**Variants:**
- A: 3 questions (1 sentence each)
- B: 5 questions (with therapeutic rationale)
**Metric:** Parent usage rate
**Success:** A has 25%+ usage

---

### Week 4: Email Summary Timing
**Hypothesis:** Sunday 8am will have best open rate
**Variants:**
- A: Sunday 8am
- B: Friday 6pm (pre-weekend)
**Metric:** Open rate
**Success:** 15%+ opens, 5%+ clicks

---

### Week 5: Fade-Out Pace by Anxiety
**Hypothesis:** Longer fade for high anxiety will improve bedtime
**Variants:**
- A: 60 second fade (all anxiety levels)
- B: Dynamic (60-120s based on intensity)
**Metric:** D7 retention + parent feedback
**Success:** B shows +8% retention

---

### Week 6: Low-Stim Suggestion Trigger
**Hypothesis:** Auto-suggesting low-stim when "overwhelmed" will increase adoption
**Variants:**
- A: Manual only (in settings)
- B: Auto-suggest + option to enable
**Metric:** Adoption rate
**Success:** B has 15%+ adoption vs. A at 5%

---

### Week 7: Timeline Visual Style
**Hypothesis:** Node-based timeline will be more engaging than list
**Variants:**
- A: Scrolling timeline with nodes
- B: List view (simple)
**Metric:** Weekly views
**Success:** A has 30%+ weekly views

---

### Week 8: Coping Strategy Effectiveness Rating
**Hypothesis:** Asking "Did this help?" will improve strategy awareness
**Variants:**
- A: Just count usage
- B: Count + effectiveness thumbs up/down
**Metric:** Strategy variety over time
**Success:** B shows +20% variety

---

## 📅 8-Week Execution Plan

### **Week 1: Foundation**
- [ ] Create `EmotionInsightsService`
- [ ] Build 7-day emotion trends chart UI
- [ ] Add "Insights" tab to main navigation
- [ ] Wire up existing emotion check-in data
- [ ] **Ship:** Basic insights dashboard (free tier)

**Owner:** Flutter dev
**Dependencies:** None (uses existing data)
**Success:** 40%+ of parents view insights

---

### **Week 2: Emotional Loop**
- [ ] Clone feelings dialog for post-story use
- [ ] Wire up pre/post emotion comparison
- [ ] Calculate and display emotion shift delta
- [ ] Store both emotions in saved story model
- [ ] **Ship:** Post-story emotional check
- [ ] **Experiment:** Test placement timing

**Owner:** Flutter dev
**Dependencies:** Week 1 (insights service)
**Success:** 30%+ completion rate

---

### **Week 3: Parent Connection**
- [ ] Create `ConversationStarterService`
- [ ] Build Gemini prompt for generating questions
- [ ] Design conversation starter card UI
- [ ] Add to `StoryResultScreen`
- [ ] **Ship:** Basic conversation starters (free)
- [ ] **Experiment:** Test question depth

**Owner:** Flutter dev + AI prompt engineer
**Dependencies:** Gemini API
**Success:** 25%+ parent usage

---

### **Week 4: Parent Insights**
- [ ] Backend: Create email cron job
- [ ] Build weekly summary template
- [ ] Implement SendGrid/Mailgun integration
- [ ] Add email preferences to settings
- [ ] Double opt-in flow
- [ ] **Ship:** Weekly emotion summary emails
- [ ] **Experiment:** Test email timing

**Owner:** Backend dev
**Dependencies:** Week 1-2 (insights data)
**Success:** 15%+ open rate

---

### **Week 5: Bedtime Optimization**
- [ ] Create `BedtimeFadeService`
- [ ] Implement dynamic TTS fade-out
- [ ] Wire up anxiety intensity to fade duration
- [ ] Add background sound options (rain, white noise)
- [ ] Bedtime mode toggle in settings
- [ ] **Ship:** Emotion-adaptive bedtime fade
- [ ] **Experiment:** Test fade pacing

**Owner:** Flutter dev + Audio specialist
**Dependencies:** TTS engine
**Success:** D7 retention +8%

---

### **Week 6: Accessibility**
- [ ] Create `AccessibilityService`
- [ ] Build low-stimulus theme
- [ ] Add font size/style controls
- [ ] Audio-only story mode
- [ ] Auto-suggest when "overwhelmed" detected
- [ ] **Ship:** Low-stimulus mode
- [ ] **Experiment:** Test suggestion trigger

**Owner:** Flutter dev + UX designer
**Dependencies:** None
**Success:** 8%+ adoption, +5% retention

---

### **Week 7: Growth Visualization**
- [ ] Create `EmotionJourneyService`
- [ ] Build timeline UI with emotion nodes
- [ ] Add story detail taps
- [ ] Generate growth insights with AI
- [ ] Premium: Export timeline PDF
- [ ] **Ship:** Emotion journey timeline
- [ ] **Experiment:** Test visual styles

**Owner:** Flutter dev + Designer
**Dependencies:** Week 1-2 (historical data)
**Success:** 20%+ weekly views

---

### **Week 8: Strategy Awareness**
- [ ] Create `CopingStrategyService`
- [ ] Extract strategies from stories
- [ ] Build strategy tracker UI
- [ ] Add effectiveness rating (thumbs up/down)
- [ ] Suggest new strategies to try
- [ ] **Ship:** Coping strategy tracker
- [ ] **Experiment:** Test effectiveness rating

**Owner:** Flutter dev
**Dependencies:** Story parsing
**Success:** Kids name 3+ strategies

---

### **Week 9: Buffer & Polish**
- [ ] Address blockers from weeks 1-8
- [ ] Bug fixes and performance optimization
- [ ] Run all experiments to completion
- [ ] Prepare for next quarter roadmap
- [ ] User testing and feedback collection

---

## 💰 Monetization Strategy (Ethical)

### Free Tier (Forever)
- ✅ Unlimited emotion check-ins
- ✅ All therapeutic story features
- ✅ 1 story per day
- ✅ 7-day emotion insights
- ✅ Basic conversation starters
- ✅ All accessibility features
- ✅ Crisis resources

### Premium Tier ($9.99/month or $79.99/year)
- ⭐ Unlimited stories
- ⭐ 30-day emotion history
- ⭐ AI-generated growth insights
- ⭐ Detailed conversation starters + print
- ⭐ Weekly email summaries
- ⭐ Export reports for therapists
- ⭐ Timeline PDF exports
- ⭐ All themes and companions

### Family Pass ($14.99/month)
- 👨‍👩‍👧‍👦 Up to 5 child profiles
- 👨‍👩‍👧‍👦 All Premium features for all kids
- 👨‍👩‍👧‍👦 Multi-character stories

### Scholarship Program (Free Premium)
- 🎓 Therapists can request codes for clients
- 🎓 Schools/nonprofits get bulk access
- 🎓 BYOK users get compute features
- 🎓 Hardship applications accepted

### What We DON'T Monetize
- ❌ Core therapeutic tools (emotion wheel, check-ins)
- ❌ Crisis resources or safety features
- ❌ Basic accessibility features
- ❌ Educational content about emotions

---

## 🎯 Success Criteria (End of Q1)

### Must Have (P0)
- [ ] D7 retention: 50% → 60% (+10%)
- [ ] Parent NPS: 40 → 55 (+15 points)
- [ ] 5 pillars shipped and stable
- [ ] All experiments completed with learnings

### Should Have (P1)
- [ ] 1,000+ premium subscribers
- [ ] 5+ therapist testimonials
- [ ] Academic partnership initiated
- [ ] 40%+ parents view insights weekly

### Nice to Have (P2)
- [ ] Featured in App Store
- [ ] Press coverage (1+ major outlet)
- [ ] Case study published
- [ ] Community forum launched

---

## 🔄 Quarterly Review Questions

1. **Therapeutic Efficacy:** Are kids better at identifying and processing emotions?
2. **Parent Satisfaction:** Do parents see value and recommend to friends?
3. **Ethical Alignment:** Are we staying true to "no pay to soothe" principle?
4. **Technical Health:** Is the app stable and performant?
5. **Business Viability:** Are we on track to sustainability?

---

## 🚀 Beyond Q1 (Parking Lot)

### Q2 Candidates (Evaluate After Q1)
- Therapist portal for progress tracking
- Group therapy stories (class/school use)
- Emotion journal with drawing/writing
- Parent community forum
- Guided meditation integration

### Needs More Research
- Voice emotion detection (too complex?)
- Biometric integration (heart rate for anxiety)
- AR/VR environments (budget/accessibility concerns)
- Social features (safety/moderation risks)

---

## 📚 Resources & References

### Therapeutic Frameworks
- **CBT:** Cognitive Behavioral Therapy for children
- **ACT:** Acceptance and Commitment Therapy
- **Emotion Coaching:** Gottman's research
- **Social Stories:** Carol Gray methodology

### Design Principles
- **Ethical Design:** Center for Humane Technology guidelines
- **COPPA Compliance:** Children's Online Privacy Protection Act
- **WCAG 2.1:** Web Content Accessibility Guidelines
- **Inclusive Design:** Microsoft's inclusive toolkit

### Metrics & Analytics
- **HEART Framework:** Google's user-centered metrics
- **Amplitude:** Behavioral analytics
- **Firebase:** App performance monitoring
- **Sentry:** Error tracking and debugging

---

## 🤝 Team & Stakeholders

### Core Team
- Product Lead: Strategic direction and prioritization
- Flutter Dev: Mobile app implementation
- Backend Dev: API, data, email systems
- Content/AI: Story prompts and conversation starters
- Designer: UI/UX for accessibility and insights

### Advisors
- Child Psychologist: Clinical validation
- Privacy Attorney: COPPA compliance
- Accessibility Expert: Inclusive design review
- Parent Focus Group: User testing and feedback

### Success Metrics Owners
- D7 Retention: Product Lead
- Parent NPS: Product + Content
- Emotion Literacy: Child Psychologist advisor
- Premium Conversion: Product + Marketing

---

## 📝 Change Log

**v1.0 (Nov 2025):** Initial feelings-focused roadmap
- Consolidated 20+ features into 5 therapeutic pillars
- Removed gamification features
- Prioritized emotional processing depth
- Defined clear success metrics and experiments

---

## ❓ FAQ

### Why only 5 features?
Quality over quantity. Each feature deepens emotional processing rather than adding surface-level engagement.

### What about gamification features like auras and gems?
We intentionally removed these to avoid turning therapy into a game. Authentic emotional growth is the reward.

### Why are conversation starters free but reports premium?
Basic parent-child connection tools should be accessible. Premium adds professional-grade insights for therapists.

### How do you balance free vs. premium?
Core therapeutic value is always free. Premium adds convenience, depth, and professional tools.

### What if users want more gamification?
We'll listen to feedback, but our mission is therapeutic efficacy, not engagement metrics.

---

**Last Updated:** November 6, 2025
**Next Review:** End of Week 4 (mid-quarter check-in)
**Owner:** Product Lead
**Status:** 🟢 Active Development
