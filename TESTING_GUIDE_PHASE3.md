# 🧪 Story Weaver App - Complete Testing Guide (Phase 3)

**Last Updated:** December 22, 2025
**Testing Agent:** Gemini (Browser-based)
**App Version:** Phase 3 Complete (Custom Elements Feature)

---

## 🎯 Testing Objective

Verify all features from **Phases 1, 2, and 3** work correctly together, with special focus on the new **custom story elements** feature.

---

## 📊 Test Coverage Summary

| Phase | Features | Status |
|-------|----------|--------|
| Phase 1 | Foundation (Wizard UI, Character System) | ✅ Complete - Needs Testing |
| Phase 2 | Adventure Architecture (Archetypes, Companions, Settings) | ✅ Complete - Needs Testing |
| Phase 3 | Free-Form Magic (Custom Elements Input) | ✅ Complete - Needs Testing |

---

## 🚀 Quick Start Guide

### How to Access the App

1. **Backend:** Should be running on `http://127.0.0.1:5000`
2. **Frontend:** Flutter web app (check with user for URL/port)
3. **Health Check:** `curl http://127.0.0.1:5000/health`

### Before You Start Testing

- [ ] Backend is running
- [ ] Frontend is accessible in browser
- [ ] Console is open (F12) to catch any errors
- [ ] You have this checklist ready to mark items

---

## 🧭 TEST SUITE 1: Core Wizard Flow (Phase 1)

### Test 1.1: Create New Character - Basic Path
**Expected Time:** 3 minutes

**Steps:**
1. Open the app
2. Click through the wizard from Step 1 → Step 4
3. Fill in minimum required fields:
   - Step 1: Select an archetype, enter name "TestHero", age 8
   - Step 2: Select any scenario + at least one emotion
   - Step 3: Skip (companions optional)
   - Step 4: Review and launch

**✅ Pass Criteria:**
- [ ] All 4 wizard steps are accessible
- [ ] Can navigate forward through steps
- [ ] Character name field accepts text
- [ ] Age slider works (3-12 range)
- [ ] Archetype cards are clickable
- [ ] Scenario cards are selectable
- [ ] "Make Magic" button is enabled when complete
- [ ] No console errors

**🐛 Known Issues to Verify:**
- Character PATCH endpoint may show "Failed to fetch" error (non-blocking)

---

### Test 1.2: Character Library
**Expected Time:** 2 minutes

**Steps:**
1. From any wizard step, click "My Characters" button (top right)
2. Verify saved characters appear
3. Click on a saved character
4. Verify character details load into wizard

**✅ Pass Criteria:**
- [ ] Character library screen opens
- [ ] Previously saved characters display
- [ ] Can select existing character
- [ ] Character data populates wizard fields
- [ ] Can return to wizard

---

### Test 1.3: Pet System
**Expected Time:** 2 minutes

**Steps:**
1. Create or select a character
2. In Step 3 (Companion Selector), add a pet:
   - Click "Add Pet" button
   - Enter pet name, select species (dog/cat/dragon/etc.)
   - Select personality and color
   - Click save

**✅ Pass Criteria:**
- [ ] Pet dialog opens
- [ ] Can enter pet details
- [ ] Pet appears in companions list
- [ ] Pet data saves with character
- [ ] Multiple pets can be added

---

## 🎨 TEST SUITE 2: Adventure Architecture (Phase 2)

### Test 2.1: Character Archetypes with Special Abilities
**Expected Time:** 5 minutes

**Test Each Archetype:**
1. **The Storm Rider** (⚡) - "Commands wind and weather"
2. **The Ancient Riddle-Solver** (🧩) - "Deciphers secret maps"
3. **The Master Creator** (🎨) - "Magic paintbrush brings drawings to life"
4. **The Heart Healer** (💚) - "Senses emotions and heals spirits"
5. **The Lightning Runner** (🏃) - "Moves faster than sound"
6. **The Silent Scout** (🦉) - "Talks to animals, moves unseen"

**Steps for Each:**
1. Select archetype in Step 1
2. Complete wizard and generate story
3. Read generated story

**✅ Pass Criteria:**
- [ ] All 6 archetypes are visible and selectable
- [ ] Each archetype card shows special ability description
- [ ] Generated story mentions the archetype's special ability
- [ ] Special ability is used at story climax (Three-Key Lock)

---

### Test 2.2: Magical Companions with Signature Powers
**Expected Time:** 5 minutes

**Test Each Companion:**
1. **Tiny Dragon** 🐉 - "Rainbow fire reveals hidden paths"
2. **Wise Owl** 🦉 - "See through time (1 minute ahead)"
3. **Shadow Cat** 🐱 - "Walk through walls, fetch from dreams"
4. **Star Dog** 🐕 - "Bark constellations into existence"
5. **Magic Unicorn** 🦄 - "Create starlight bridges"
6. **Clever Fox** 🦊 - "Transform into objects"

**Steps for Each:**
1. Select companion in Step 3
2. Generate story
3. Verify companion's signature power appears in story

**✅ Pass Criteria:**
- [ ] All 6 companions visible with descriptions
- [ ] Companion's signature power is mentioned in story
- [ ] Companion's power is used at climax (part of Three-Key Lock)

---

### Test 2.3: Scenarios with Conflict Hooks
**Expected Time:** 5 minutes

**Test Each Scenario:**
1. **The Magic Door** 🚪 - "Find the right door to return home"
2. **The Sleeping Dragon** 🐉 - "Wake dragon gently with kindness"
3. **The Glowing Forest** 🌳 - "Forest losing its glow"
4. **The Sparkle Cave** 💎 - "Speak softly to keep crystals sparkling"
5. **The Cloud Castle** ☁️ - "Castle floating away, needs anchor"
6. **The Rainbow Land** 🎨 - "Colors fading, need painting back"

**Steps for Each:**
1. Select scenario in Step 2
2. Generate story
3. Verify conflict hook appears in story opening

**✅ Pass Criteria:**
- [ ] All 6 scenarios display with simplified names
- [ ] Scenario conflict appears in story
- [ ] Sensory details (palette) are present
- [ ] Story opening establishes the conflict

---

### Test 2.4: Story Length Options
**Expected Time:** 5 minutes

**Test All Three Lengths:**

**Quick Story (⚡ 5 min):**
1. Select "Quick" in Step 4
2. Generate story
3. Count approximate words

**Standard Story (📖 10 min):**
1. Select "Standard" in Step 4
2. Generate story
3. Count approximate words

**Epic Story (🏰 15 min):**
1. Select "Epic" in Step 4
2. Generate story
3. Count approximate words

**✅ Pass Criteria:**
- [ ] Quick: ~300-400 words
- [ ] Standard: ~600-800 words
- [ ] Epic: ~1000-1200 words
- [ ] Story quality maintained across all lengths
- [ ] No timeout errors on Epic stories

---

### Test 2.5: Mood Physics Rules
**Expected Time:** 3 minutes

**Test Moods (Select emotions in Step 2):**
1. **Stormy** - "Gravity glitches when someone yells"
2. **Blue** - "Raindrops show memories instead of reflections"
3. **Creative** - "Describe object, it changes form"
4. **Peaceful** - "Time slows with deeper breathing"
5. **Brave** - "Shadows run away from eye contact"
6. **Joyful** - "Laughter makes you float"
7. **Friendly** - "Language barriers disappear"

**Steps:**
1. Select emotion chip matching mood
2. Generate story
3. Verify mood physics appears in story

**✅ Pass Criteria:**
- [ ] Mood physics mentioned in story
- [ ] World rule affects story atmosphere
- [ ] Sensory changes described

---

### Test 2.6: Spark Tools
**Expected Time:** 3 minutes

**Test Spark Tools in Step 4:**
- Test at least 3 different spark tools from dropdown
- Verify tool appears in story
- Verify tool is USED to solve problem (not just mentioned)

**✅ Pass Criteria:**
- [ ] Spark tool dropdown works
- [ ] Tool description displays when selected
- [ ] Tool appears in generated story
- [ ] Tool is used at Midpoint or Climax

---

## 💭 TEST SUITE 3: Free-Form Custom Elements (Phase 3)

### Test 3.1: Custom Elements - Basic Functionality
**Expected Time:** 5 minutes

**Test Cases:**

**Test A: Simple Custom Request**
1. In Step 4, find "Your Story Ideas" section
2. Enter: "I want to meet a talking tree"
3. Generate story
4. Verify talking tree appears as plot-relevant character

**Test B: Multiple Custom Elements**
1. Enter: "I want to ride a dragon and find a magic key"
2. Generate story
3. Verify both dragon ride AND magic key appear

**Test C: Abstract Custom Request**
1. Enter: "I want the character to discover they can fly"
2. Generate story
3. Verify flight discovery is pivotal moment

**✅ Pass Criteria:**
- [ ] Text input field is visible and editable
- [ ] Placeholder text is helpful
- [ ] Confirmation message appears when typing
- [ ] Custom elements appear in generated story
- [ ] Elements are plot-relevant (not background details)
- [ ] Elements feel magical/important

---

### Test 3.2: Custom Elements - Edge Cases
**Expected Time:** 3 minutes

**Test Edge Cases:**

**Test A: Empty Custom Elements**
1. Leave custom elements field blank
2. Generate story
3. Verify story still generates successfully

**Test B: Very Long Custom Request**
1. Enter 200+ character custom request
2. Verify field accepts long text
3. Generate story

**Test C: Special Characters**
1. Enter: "I want emojis 🌟✨🎉 and symbols!"
2. Verify field handles special characters

**✅ Pass Criteria:**
- [ ] Empty field doesn't break story generation
- [ ] Long text is accepted (no truncation errors)
- [ ] Special characters don't cause errors
- [ ] Backend handles edge cases gracefully

---

## 🎭 TEST SUITE 4: Story Modes

### Test 4.1: Rhyme Time Mode
**Expected Time:** 3 minutes

**Steps:**
1. In Step 4, toggle "🎵 Rhyme Time Mode" ON
2. Generate story
3. Read story aloud

**✅ Pass Criteria:**
- [ ] Story has AABB rhyme scheme (couplets)
- [ ] Clear rhythm and bouncy flow
- [ ] Age-appropriate vocabulary
- [ ] Story length respects selected length option

---

### Test 4.2: Learning to Read Mode
**Expected Time:** 3 minutes

**Steps:**
1. In Step 4, toggle "📚 Learning to Read" ON
2. Generate story
3. Analyze vocabulary

**✅ Pass Criteria:**
- [ ] Very simple words (CVC + sight words)
- [ ] Short sentences
- [ ] Rhyming pattern (AABB)
- [ ] Much shorter than standard mode (~50-175 words)

---

### Test 4.3: Interactive Mode
**Expected Time:** 3 minutes

**Steps:**
1. In Step 4, toggle "🎮 Interactive Mode" ON
2. Generate story
3. Verify choice-based navigation appears

**✅ Pass Criteria:**
- [ ] Story shows multiple choice options
- [ ] Can select choices
- [ ] Story continues based on choices
- [ ] No dead ends or errors

---

## 🔗 TEST SUITE 5: Integration Tests

### Test 5.1: Full Feature Combo
**Expected Time:** 10 minutes

**The Ultimate Test:**
Create a story using ALL features together:

**Setup:**
1. **Character:** "Luna", Age 7, The Master Creator archetype
2. **Scenario:** The Glowing Forest
3. **Emotion:** Creative (for mood physics)
4. **Companion:** Shadow Cat (magical companion)
5. **Spark Tool:** Magic Compass
6. **Story Length:** Epic (1000+ words)
7. **Custom Elements:** "I want Luna to paint a portal to another world and meet a friendly robot"

**✅ Pass Criteria:**
- [ ] All features work together without conflicts
- [ ] Story includes:
  - [ ] Master Creator special ability (magic paintbrush)
  - [ ] Shadow Cat's power (walk through walls)
  - [ ] Glowing Forest conflict (forest losing glow)
  - [ ] Creative mood physics (describe = change form)
  - [ ] Magic Compass usage
  - [ ] Portal painting scene
  - [ ] Friendly robot character
- [ ] Story is ~1000+ words
- [ ] Three-Key Lock climax (ability + companion + tool)

---

### Test 5.2: Multiple Companions
**Expected Time:** 3 minutes

**Steps:**
1. Add 2 pets in Step 3
2. Add 1 existing character as companion
3. Add 1 magical companion (dragon/owl/etc.)
4. Generate story

**✅ Pass Criteria:**
- [ ] All companions appear in story
- [ ] Each companion has distinct voice/role
- [ ] Companions work together in story
- [ ] Character companions are humans (not toys/stuffed animals)

---

### Test 5.3: Age Calibration
**Expected Time:** 5 minutes

**Test Different Ages:**

**Young Child (Age 3-5):**
1. Create character age 4
2. Generate story
3. Verify gentle language, simple words

**Middle (Age 6-8):**
1. Create character age 7
2. Generate story
3. Verify moderate vocabulary

**Older (Age 9-12):**
1. Create character age 11
2. Generate story
3. Verify advanced vocabulary, complex plots

**✅ Pass Criteria:**
- [ ] Vocabulary adjusts by age
- [ ] Sentence complexity adjusts
- [ ] Story themes appropriate for age
- [ ] No scary/inappropriate content for any age

---

## 🐛 TEST SUITE 6: Error Handling & Edge Cases

### Test 6.1: Backend Connectivity
**Expected Time:** 2 minutes

**Steps:**
1. Stop backend (simulate outage)
2. Try to generate story
3. Verify error message appears
4. Restart backend
5. Verify app recovers

**✅ Pass Criteria:**
- [ ] User-friendly error message shown
- [ ] No app crash
- [ ] App recovers when backend restarts

---

### Test 6.2: Incomplete Wizard Data
**Expected Time:** 2 minutes

**Steps:**
1. Skip required fields (no archetype, no name)
2. Try to proceed to next step
3. Verify validation prevents proceeding

**✅ Pass Criteria:**
- [ ] Cannot proceed without required fields
- [ ] Clear indication of what's missing
- [ ] "Make Magic" button disabled when incomplete

---

### Test 6.3: Special Characters in Input
**Expected Time:** 2 minutes

**Steps:**
1. Enter special characters in name: "Te$t-Hero_2024!"
2. Enter emojis in custom elements: "🌟✨🎉"
3. Generate story

**✅ Pass Criteria:**
- [ ] App handles special characters gracefully
- [ ] No encoding errors
- [ ] Story generates successfully

---

## 📊 RESULTS TEMPLATE

Use this template to report findings:

```markdown
## Test Results Summary

**Date:** [Date]
**Tester:** Gemini
**Test Duration:** [X] minutes

### Overall Status
- [ ] All Critical Tests Passed
- [ ] Some Non-Critical Issues Found
- [ ] Critical Bugs Found

### Test Suite Results

| Suite | Tests Run | Passed | Failed | Notes |
|-------|-----------|--------|--------|-------|
| Suite 1: Core Wizard | 3 | X | X | [Notes] |
| Suite 2: Adventure Architecture | 6 | X | X | [Notes] |
| Suite 3: Custom Elements | 2 | X | X | [Notes] |
| Suite 4: Story Modes | 3 | X | X | [Notes] |
| Suite 5: Integration | 3 | X | X | [Notes] |
| Suite 6: Error Handling | 3 | X | X | [Notes] |

### Bugs Found

#### Critical (Blocks Launch) 🔴
1. [Bug description]
   - **Steps to Reproduce:** [...]
   - **Expected:** [...]
   - **Actual:** [...]

#### Medium (Should Fix) 🟡
1. [Bug description]

#### Low (Nice to Fix) 🟢
1. [Bug description]

### Feature Feedback

**What Works Great:**
- [Feature that impressed you]

**What Could Be Better:**
- [Suggestions for improvement]

### Recommendation
- [ ] ✅ **READY FOR LAUNCH** - All critical tests passed
- [ ] ⚠️ **NEEDS FIXES** - Fix critical bugs first
- [ ] ❌ **NOT READY** - Major issues found
```

---

## 🎯 Priority Testing Order

If time is limited, test in this order:

### HIGH PRIORITY (Must Test)
1. Test 1.1 - Basic wizard flow
2. Test 3.1 - Custom elements feature
3. Test 2.1 - Archetypes with abilities
4. Test 2.4 - Story length options
5. Test 5.1 - Full feature combo

### MEDIUM PRIORITY
6. Test 2.2 - Magical companions
7. Test 2.3 - Scenarios
8. Test 5.3 - Age calibration
9. Test 6.1 - Error handling

### LOW PRIORITY (Nice to Have)
10. Test 1.2 - Character library
11. Test 1.3 - Pet system
12. Test 4.1-4.3 - Story modes
13. Test 6.2-6.3 - Edge cases

---

## 📝 Known Issues (Non-Blocking)

These issues are known and don't block launch:

1. **Character PATCH Endpoint Error**
   - **Issue:** Frontend shows "Failed to fetch" when updating characters
   - **Impact:** Non-blocking - stories still generate successfully
   - **Status:** Low priority fix

2. **Font Warnings**
   - **Issue:** Missing Noto fonts for some Unicode characters
   - **Impact:** Cosmetic only
   - **Status:** Won't fix

---

## 🚀 Post-Testing Actions

After completing tests:

1. **Document Results** - Use the results template above
2. **Report Bugs** - List all bugs with reproduction steps
3. **Provide Feedback** - Share impressions and suggestions
4. **Deployment Decision** - Recommend launch readiness

---

## 📞 Support

If you encounter issues or have questions:

- Check `CURRENT_SESSION_HANDOFF.md` for recent changes
- Check `MASTER_LAUNCH_PLAN.md` for feature details
- Review backend logs for error details
- Test `/health` endpoint for backend status

---

**Happy Testing! 🧪✨**

---

**Document Version:** 1.0
**Last Updated:** December 22, 2025
**Created By:** Claude Code Agent
