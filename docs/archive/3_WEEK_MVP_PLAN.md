# 3-Week MVP Deployment Plan

## Goal
Ship the core emotional processing loop: **Check-in → Story → Check-out → Insights → Conversation**

---

## Week 1: Emotion Insights Foundation

### Claude's Work
**Task:** Build post-story emotional check and comparison
- [ ] Create `PostStoryFeelingsDialog` (clone of pre-story)
- [ ] Add to `StoryResultScreen` after story display
- [ ] Store both `preStoryFeeling` and `postStoryFeeling` in saved story
- [ ] Calculate emotion intensity delta
- [ ] Display: "Worried went from 4 → 2" with visual indicator
- [ ] Make it skippable (dismiss button)

**Files to modify:**
- `lib/post_story_feelings_dialog.dart` (new)
- `lib/story_result_screen.dart`
- `lib/storage_service.dart` (update SavedStory model)

**Success:** 30%+ users complete post-story check

---

### Codex's Work (PARALLEL)
**Task:** Build emotion insights dashboard
- [ ] Create `lib/services/emotion_insights_service.dart`
- [ ] Method: `getWeeklyTrends()` - returns emotion frequency map
- [ ] Method: `getEmotionHistory(int days)` - returns check-ins list
- [ ] Method: `calculateIntensityTrends()` - average intensity per emotion
- [ ] Create `lib/insights_screen.dart` with:
  - Bar chart showing emotion frequency (last 7 days)
  - Simple stats: "5 emotions explored this week"
  - List of recent check-ins with story links
- [ ] Add "Insights" tab to main navigation

**Working Branch:** `codex-dev` (merge from main first)
**Dependencies:** Uses existing `EmotionCheckIn` data from `emotions_learning_system.dart`
**Success:** Dashboard loads and displays correct data

---

### Integration (End of Week 1)
- [ ] Claude reviews Codex's insights dashboard
- [ ] Merge `codex-dev` to main
- [ ] Test both features together
- [ ] Fix any integration bugs

**Deliverable:** Users can check emotions before/after story AND see weekly patterns

---

## Week 2: Parent Connection Tools

### Claude's Work
**Task:** AI-generated conversation starters
- [ ] Create `lib/services/conversation_starter_service.dart`
- [ ] Build Gemini prompt that takes:
  - Current feeling (emotion + intensity + context)
  - Story text summary
  - Character name
- [ ] Generate 3 simple questions:
  1. Question about the emotion ("What made the worry smaller?")
  2. Action prompt ("Try deep breathing together")
  3. Reflection ("What was the bravest thing?")
- [ ] Add conversation starter card to `StoryResultScreen`
- [ ] Show below story, above post-story check
- [ ] Add "Share with Parent" button (copy to clipboard)

**Files to modify:**
- `lib/services/conversation_starter_service.dart` (new)
- `lib/story_result_screen.dart`

**Success:** 25%+ parents use conversation starters

---

### Codex's Work (PARALLEL)
**Task:** Enhance insights dashboard with premium features
- [ ] Add emotion intensity trends chart (line graph over 7 days)
- [ ] Add "Emotion Details" tap → show all stories for that emotion
- [ ] Add premium gate: "Unlock 30-day history" banner
- [ ] Add export button (premium) → generate PDF report
- [ ] Polish UI: colors, spacing, empty states
- [ ] Add loading states and error handling

**Working Branch:** `codex-dev` (merge main at start of week)
**Dependencies:** Week 1 insights service
**Success:** Dashboard is polished and premium upsell is clear

---

### Integration (End of Week 2)
- [ ] Claude reviews enhanced insights
- [ ] Test conversation starters with real emotion data
- [ ] Merge `codex-dev` to main
- [ ] QA both features end-to-end

**Deliverable:** Complete emotional loop + parent tools are functional

---

## Week 3: Polish, Testing & Deployment

### Day 1-2: Bug Fixes & Edge Cases
**Both working together:**
- [ ] Handle empty states (no emotions yet, no stories yet)
- [ ] Handle offline mode (cached data only)
- [ ] Test with different age groups (3-5, 6-11, 12+)
- [ ] Test premium vs. free user flows
- [ ] Fix any crashes or UI glitches

---

### Day 3: User Testing
- [ ] Internal dogfooding with team families
- [ ] Run through entire flow 5+ times
- [ ] Collect feedback on:
  - Is post-story check too intrusive?
  - Are conversation starters helpful?
  - Is insights dashboard clear?
- [ ] Fix high-priority feedback

---

### Day 4: Performance & Analytics
- [ ] Add analytics events:
  - `post_story_check_completed`
  - `conversation_starter_viewed`
  - `conversation_starter_copied`
  - `insights_dashboard_viewed`
  - `emotion_intensity_delta_recorded`
- [ ] Test app performance (load times, memory)
- [ ] Optimize image sizes and API calls
- [ ] Test on low-end devices

---

### Day 5: Deployment Prep
**Morning:**
- [ ] Update app version number
- [ ] Write release notes
- [ ] Create marketing screenshots
- [ ] Update app store listing

**Afternoon:**
- [ ] Build production APK/IPA
- [ ] Test on physical devices
- [ ] Submit to App Store & Google Play
- [ ] Set up staged rollout (10% → 50% → 100%)

**Evening:**
- [ ] Deploy backend changes (if any)
- [ ] Monitor error tracking (Sentry)
- [ ] Watch analytics for first hour

---

## What Got Cut (Post-Launch)

### Week 4+ Features (Add After Validation)
- Weekly email summaries (needs backend work)
- Bedtime fade-out (needs TTS tuning)
- Low-stim mode (needs accessibility testing)
- Emotion journey timeline (needs complex UI)
- Coping strategy tracker (needs data modeling)

**Why Cut:** These are enhancements. Ship the core loop first, validate with users, then add.

---

## Success Metrics (3-Week Launch)

### Must Hit (P0)
- [ ] Post-story check: 30%+ completion rate
- [ ] Conversation starters: 25%+ viewed
- [ ] Insights dashboard: 40%+ of parents open
- [ ] Zero critical bugs in production
- [ ] App rating: 4.0+ stars

### Should Hit (P1)
- [ ] Emotion intensity drops 1+ point on average
- [ ] Parent NPS: +10 points vs. baseline
- [ ] 10+ premium conversions in first week

### Nice to Have (P2)
- [ ] Featured by app store
- [ ] 5+ therapist testimonials
- [ ] 1,000+ new users

---

## Risk Mitigation

### Risk 1: Post-Story Check Feels Intrusive
**Mitigation:**
- Make it skippable with clear "Not now" button
- Only show after 3+ seconds (gives processing time)
- A/B test: immediate vs. delayed prompt

### Risk 2: Conversation Starters Are Generic
**Mitigation:**
- Test prompts with 5+ parent volunteers
- Iterate on Gemini prompt template
- Have fallback templates if AI fails

### Risk 3: Insights Dashboard Is Confusing
**Mitigation:**
- Add onboarding tooltip on first view
- Use simple language ("5 emotions explored")
- Show examples in empty state

### Risk 4: Integration Bugs Between Features
**Mitigation:**
- Daily integration testing (not just feature testing)
- Staging environment mirrors production
- Codex and Claude sync daily

### Risk 5: App Store Rejection
**Mitigation:**
- Review guidelines before submission
- Have privacy policy updated
- Age rating set correctly (4+ with parental guidance)
- No misleading health claims

---

## Daily Standups (15 min)

### Questions to Answer:
1. What did you ship yesterday?
2. What are you shipping today?
3. Any blockers?
4. Do we need to cut scope?

### Red Flags to Watch:
- Task taking 2+ days → cut scope or ask for help
- Bugs piling up → stop new features, fix bugs
- Confusion on requirements → sync immediately

---

## Deployment Checklist

### Pre-Deployment
- [ ] All tests pass
- [ ] No console errors/warnings
- [ ] Privacy policy updated
- [ ] Terms of service reviewed
- [ ] COPPA compliance verified
- [ ] Analytics tracking works
- [ ] Error tracking (Sentry) active

### During Deployment
- [ ] Backend deployed first (if needed)
- [ ] Mobile app submitted to stores
- [ ] Staged rollout enabled (10% → 50% → 100%)
- [ ] Monitor error rates
- [ ] Monitor analytics events

### Post-Deployment
- [ ] Announce to users (in-app message)
- [ ] Social media posts
- [ ] Email to therapist partners
- [ ] Monitor app store reviews
- [ ] Plan hotfix if needed

---

## What Success Looks Like (End of Week 3)

### User Experience:
1. Kid uses app, does feelings check-in
2. Reads personalized story based on emotion
3. Post-story check shows emotion improved
4. Parent sees conversation starter, uses it
5. Parent checks insights, sees emotional patterns
6. Parent feels value, considers premium

### Team Experience:
1. MVP shipped on time
2. No major bugs or crashes
3. Clear data on what's working
4. Roadmap for next 4 features validated
5. Team is proud of what shipped

### Business Experience:
1. Parent NPS improved
2. D7 retention improved
3. Premium conversion started
4. Clear path to sustainability
5. Investor-ready story

---

## Post-Launch: Week 4 Planning

### Immediate (First 3 Days)
- Monitor crashes and fix critical bugs
- Watch analytics for unexpected behavior
- Collect user feedback (in-app survey)
- Triage feature requests

### First Week Review
- Metrics review: Did we hit targets?
- User interviews: 5+ parents
- Therapist feedback: 3+ professionals
- Decide: What's next priority?

### Next Quarter
- If metrics good: Add Week 4-8 features from original roadmap
- If metrics weak: Iterate on core loop until it works
- If surprise insights: Pivot based on learning

---

**Remember:** This is an MVP. Ship, learn, iterate. Don't let perfect be the enemy of good.

---

**Last Updated:** November 6, 2025
**Owner:** Product Lead
**Deployment Target:** November 27, 2025 (3 weeks)
**Status:** 🔴 Not Started
