# Codex 2 - Week 3 Tasks (Interactive Stories & BYOK)

**Assigned to**: Codex Instance 2 (previously assigned Gemini tasks)
**Priority**: HIGH - Quality improvements for existing features
**Timeline**: Week 3 (Nov 26 - Dec 2)

---

## Current Status Summary

### ✅ Completed (Weeks 1-2)
- G1: Grace Period Integration ✅
- G3: User-Friendly Error Handling ✅
- G4: Story Generation Progress UX ✅
- G2: Illustration Controls (integrated, verified)

### 📋 Week 3 Focus
Interactive story quality + BYOK setup wizard

---

## Task C2-3.1: Interactive Story Quality Improvements (Priority: CRITICAL)

**User Pain Point**: "Interactive stories have meaningless choices (door colors). Not therapeutic."

**Objective**: Improve prompt engineering for meaningful, therapeutic choices.

### Problem Analysis:
Current interactive stories often generate:
- ❌ "Go through red/blue/green door" (meaningless)
- ❌ Choices that don't affect story outcome
- ❌ No therapeutic value in decision-making

Should generate:
- ✅ "Ask teacher for help" vs "Try on your own" vs "Work with friend"
- ✅ Choices that teach emotional skills
- ✅ Different paths based on choices

### Implementation Steps:

1. **Update Backend Prompt Engineering**
   - File: `backend/app.py` (update interactive story endpoints)
   - Enhance prompts to require meaningful choices
   - Add validation for choice quality
   - Track choice types for analytics

2. **Prompt Requirements**
```python
# backend/app.py - Enhanced interactive story prompt

INTERACTIVE_STORY_OPENING_PROMPT = """Create an opening segment for an interactive therapeutic story.

CHARACTER: {character_name}, age {age}
THEME: {theme}
COMPANION: {companion}

CRITICAL REQUIREMENTS:
1. Create 3 choices that lead to DISTINCTLY DIFFERENT story paths
2. Each choice should represent a different emotional response:
   - Seeking help/support (social connection)
   - Independent problem-solving (self-reliance)
   - Creative/collaborative solution (teamwork)
3. Choices must be AGE-APPROPRIATE and THERAPEUTIC
4. NO arbitrary choices like door colors or directions

GOOD CHOICES (examples):
- "Ask your teacher for help with the problem"
- "Try to solve it yourself step-by-step"
- "Team up with a friend to figure it out together"

BAD CHOICES (avoid):
- "Go through the red door"
- "Turn left or turn right"
- "Pick option A, B, or C"

Format response as JSON:
{{
  "text": "Story opening (2-3 paragraphs)...",
  "choices": [
    {{"id": "seek_help", "text": "Meaningful choice 1", "emotional_skill": "seeking support"}},
    {{"id": "independent", "text": "Meaningful choice 2", "emotional_skill": "self-reliance"}},
    {{"id": "collaborate", "text": "Meaningful choice 3", "emotional_skill": "teamwork"}}
  ]
}}
"""

INTERACTIVE_STORY_CONTINUATION_PROMPT = """Continue this interactive story based on the user's choice.

STORY SO FAR:
{story_text}

PREVIOUS CHOICES: {choices_made}
CURRENT CHOICE: {current_choice}
EMOTIONAL SKILL DEMONSTRATED: {emotional_skill}

CRITICAL REQUIREMENTS:
1. The story MUST reflect and build upon the choice made
2. If they sought help: Show positive outcomes of asking for support
3. If they went independent: Show growth through self-reliance
4. If they collaborated: Demonstrate benefits of teamwork
5. Maintain consistency with previous choices
6. Provide 2-3 new meaningful choices OR offer story conclusion
7. After 3-4 choice points, provide satisfying ending option

THERAPEUTIC GOAL:
Reinforce that the child's choice was valuable and led to positive growth.

Format as JSON:
{{
  "text": "Next story segment...",
  "choices": [
    {{"id": "continue_1", "text": "Meaningful choice", "emotional_skill": "..."}},
    {{"id": "continue_2", "text": "Meaningful choice", "emotional_skill": "..."}},
    {{"id": "end_story", "text": "End the story here", "emotional_skill": "closure"}}
  ],
  "can_conclude": true/false
}}
"""
```

3. **Frontend Choice Display Enhancement**
   - File: `lib/interactive_story_screen.dart`
   - Show emotional skill tags on choices (optional)
   - Improve choice button styling
   - Add "story branches" indicator

4. **Quality Validation**
   - Add backend validation to reject poor choices
   - Log choice quality metrics
   - Alert if choices don't meet standards

### Testing:
- [ ] Generate 10 interactive stories and verify choice quality
- [ ] Test all 3 choice types lead to different outcomes
- [ ] Verify therapeutic value in story outcomes
- [ ] Check consistency across choice branches
- [ ] Ensure age-appropriateness maintained

### Success Metrics:
- Choice meaningfulness rating: >4/5
- Story branch diversity: 3+ distinct paths
- Therapeutic value score: >4/5
- Parent satisfaction with interactive stories: +30%

---

## Task C2-3.2: BYOK Setup Wizard (Priority: HIGH)

**User Pain Point**: "BYOK model confusing for non-technical users."

**Objective**: Create step-by-step wizard for API key setup.

### Implementation Steps:

1. **Create BYOK Setup Wizard Screen**
   - File: `lib/screens/byok_setup_wizard.dart` (NEW)
   - 3-step process:
     - Step 1: Explain benefits (unlimited stories, free illustrations, cost-effective)
     - Step 2: Guide to get API key (with direct link to Google AI Studio)
     - Step 3: Enter and verify API key

2. **Wizard Features**
   - Direct link to Google AI Studio
   - Visual step-by-step instructions
   - API key validation before saving
   - Clear security messaging
   - Benefit comparison table

3. **Update Settings Screen**
   - File: `lib/settings_screen.dart`
   - Add "Setup API Key" wizard button
   - Show current BYOK status (enabled/disabled)
   - Quick stats: stories created with BYOK

### Wizard Flow:
```
Settings > "Use Your Own API Key"
  ↓
Benefits Screen
  - Unlimited stories
  - Free illustrations
  - Cost: $0.10-0.50/month
  ↓
Get API Key Instructions
  - Link to Google AI Studio
  - Step-by-step guide
  - Screenshots (optional)
  ↓
Enter API Key
  - Text field (obscured)
  - Verify button
  - Security note
  ↓
Validation & Save
  - Test API key
  - Show success/error
  - Save if valid
```

### Testing:
- [ ] Wizard launches from settings
- [ ] Google AI Studio link works
- [ ] API key validation works (test with valid/invalid keys)
- [ ] API key saves correctly
- [ ] Stories use BYOK key after setup
- [ ] Clear error messages for invalid keys

---

## Task C2-3.3: Remaining Analytics Verification (G5 completion)

**Objective**: Verify all analytics events from G5 are firing correctly.

### Events to Verify:

1. **Feelings Corner Events**
   - `feelings_corner_viewed`
   - `feelings_check_in_logged`
   - `feelings_reminder_toggled`

2. **Story Events**
   - `story_created`
   - `story_viewed`
   - `story_shared`

3. **Grace Period Events**
   - `grace_period_banner_viewed`
   - `grace_period_soft_prompt_shown`
   - `grace_period_hard_limit_reached`
   - `upgrade_prompt_clicked`

4. **Interactive Story Events**
   - `interactive_story_started`
   - `interactive_choice_made`
   - `interactive_story_completed`

### Testing:
- [ ] Run app in debug mode
- [ ] Trigger each event
- [ ] Verify console logs show events
- [ ] Check Firebase Analytics dashboard (if configured)
- [ ] Document all events in ANALYTICS_EVENTS.md

---

## Priority Order

1. **C2-3.1**: Interactive Story Quality (CRITICAL - core feature improvement)
2. **C2-3.2**: BYOK Setup Wizard (HIGH - enables unlimited usage)
3. **C2-3.3**: Analytics Verification (MEDIUM - measurement)

---

## Deliverables

- [ ] Interactive story prompts enhanced (backend)
- [ ] Choice quality validation implemented
- [ ] BYOK setup wizard created
- [ ] API key verification working
- [ ] All analytics events verified
- [ ] ANALYTICS_EVENTS.md documentation created
- [ ] Update TEAM_COORDINATION.md with completion status

---

## Notes

- **Interactive stories**: Focus on therapeutic value over complexity
- **BYOK wizard**: Make it grandma-friendly (very simple)
- **Analytics**: Complete verification to inform Week 4 decisions
- Test with real API keys (valid/invalid) for BYOK wizard

---

## Success Criteria

- [ ] Interactive story choices feel meaningful
- [ ] Story outcomes clearly differ based on choices
- [ ] BYOK setup completion rate >70%
- [ ] All analytics events verified and documented
- [ ] No regressions in existing features
- [ ] User testing feedback positive
