# Story Weaver Adventure Upgrade - Implementation Plan

**Goal:** Transform from gentle therapeutic stories to exciting, immersive adventures that kids love.

**Date Created:** December 21, 2025
**Status:** In Progress

---

## 🎯 Overview

This plan upgrades the Story Weaver app from passive, gentle stories to **Immersive Adventure Architecture** with:
- Action-oriented character archetypes with special abilities
- Dynamic settings with built-in conflicts
- Companion special skills that solve climax challenges
- Mood-to-atmosphere integration
- Age-calibrated adventure intensity

---

## 📋 Implementation Checklist

### Phase 1: Backend Story Prompt Enhancement ✅ COMPLETED
- [x] Update story generation prompt to require sensory immersion
- [x] Add "Impossible Element" requirement (physics-defying climax)
- [x] Require active protagonist agency
- [x] Add cinematic pacing requirements
- [x] Add distinct companion voices requirement
- [x] Fix companion character details (fetch from database)

**Files Modified:**
- `backend/services/story_service.py` (lines 193-304)
- `backend/tasks/story_tasks.py` (lines 133-150, 186)

---

### Phase 2: Character Archetypes - From Passive to Active 🔄 IN PROGRESS

**Current Location:** `lib/widgets/archetype_card.dart` (lines 149-248)

#### Current Archetypes (Passive):
1. **The Adventurer** (🗺️) - "Brave, Curious, Determined"
2. **The Thinker** (💭) - "Smart, Modest, Curious"
3. **The Artist** (🎨) - "Creative, Expressive, Hint"
4. **The Helper** (🤝) - "Caring, Patient, Loyal"
5. **The Athlete** (⚡) - "Energetic, Empathy, Determined"
6. **The Shy One** (😊) - "Thoughtful, Quirks, Observant"

#### New Archetypes (Action-Oriented):
1. **The Storm Rider** (⚡) - Special Ability: "Can command wind and weather"
2. **The Ancient Riddle-Solver** (🧩) - Special Ability: "Deciphers secret maps and ancient puzzles"
3. **The Master Creator** (🎨) - Special Ability: "Magic paintbrush that brings drawings to life"
4. **The Heart Healer** (💚) - Special Ability: "Can sense emotions and heal broken spirits"
5. **The Lightning Runner** (🏃) - Special Ability: "Moves faster than sound, leaves stardust trails"
6. **The Silent Scout** (🦉) - Special Ability: "Can talk to animals and move unseen through shadows"

#### Implementation Tasks:
- [ ] Update `archetype_card.dart` with new names and abilities
- [ ] Add `specialAbility` field to archetype data structure
- [ ] Update UI to show special ability in archetype selection
- [ ] Update backend prompt to include archetype ability in story
- [ ] Update `wizard_data_mapper.dart` to pass ability to backend

**Files to Modify:**
- `lib/widgets/archetype_card.dart` (lines 149-248)
- `lib/screens/wizard_steps/hero_creator_step.dart` (line 384)
- `lib/screens/wizard_steps/wizard_data_mapper.dart` (lines 18-23)
- `backend/services/story_service.py` (add ability to prompt)

---

### Phase 3: Story Settings - Add Adventure Hooks ⏳ PENDING

**Current Location:** `lib/screens/wizard_steps/feeling_selection_step.dart` (lines 33-76)

#### Current Settings (Safe but Boring):
1. **The First Day Quest** - "A brave journey to a new place"
2. **The Dragon Inside** - "Taming the roars within"
3. **The Friendly Forest** - "Finding new companions"
4. **The Cave of Courage** - "Facing the shadows"
5. **The Cloud Castle** - "Floating in peaceful skies"
6. **The Paintbrush Kingdom** - "Coloring the world"

#### New Settings (Dynamic Conflicts):

| Old Setting | New Adventure Setting | Conflict Hook | Sensory Palette |
|-------------|----------------------|---------------|-----------------|
| The Friendly Forest | **The Neon Jungle of Whispers** | Trees that forget their colors at night | Glowing moss, humming vines, sweet fruit scent |
| The Cloud Castle | **The Storm-Chaser's Sky Fortress** | Fortress racing through lightning storms | Thunder rumble, ozone smell, static tingles |
| The Paintbrush Kingdom | **The Land of Vanishing Colors** | Colors disappearing one by one | Shimmering air, paint smell, smooth canvas |
| The Cave of Courage | **The Crystal Cavern of Echoes** | Echoes that steal voices if you're too loud | Glittering walls, dripping water, cool stone |
| The Dragon Inside | **The Volcano of Sleeping Dragons** | Wake the kindest dragon before the mean one wakes | Rumbling ground, smoke smell, warm rock |
| The First Day Quest | **The Doorway Between Seasons** | Each door leads to different season, must find way home | Swirling leaves, changing temps, season scents |

#### Implementation Tasks:
- [ ] Update scenario data in `feeling_selection_step.dart`
- [ ] Add `conflictHook` and `sensoryPalette` fields
- [ ] Update scenario cards UI to show new descriptions
- [ ] Update backend to use conflict hook in story opening
- [ ] Add sensory palette to prompt generation

**Files to Modify:**
- `lib/screens/wizard_steps/feeling_selection_step.dart` (lines 33-76)
- `backend/services/story_service.py` (add setting conflict to prompt)

---

### Phase 4: Companion Special Skills ⏳ PENDING

**Current Location:** `lib/screens/wizard_steps/companion_selector_step.dart` (lines 75-137)

#### Current Companions (Generic):
1. **a tiny dragon** (🐉) - "I'm ready to help!"
2. **a wise owl** (🦉) - "Let's be wise together!"
3. **a playful cat** (🐱) - "Meow! I'm ready!"
4. **a loyal dog** (🐕) - "I'll be your best friend!"
5. **a magic unicorn** (🦄) - "Let's make magic!"
6. **a clever fox** (🦊) - "Ready for clever fun!"

#### New Companions (Special Skills):
1. **a tiny dragon** (🐉) - Special Skill: "Breathes rainbow fire that reveals hidden paths"
2. **a wise owl** (🦉) - Special Skill: "Can see through time to show what will happen"
3. **a shadow cat** (🐱) - Special Skill: "Walks through walls and brings things from dreams"
4. **a star dog** (🐕) - Special Skill: "Barks constellations into existence to guide the way"
5. **a magic unicorn** (🦄) - Special Skill: "Creates bridges made of starlight and moonbeams"
6. **a clever fox** (🦊) - Special Skill: "Transforms into any shape to solve impossible puzzles"

#### Implementation Tasks:
- [ ] Add `specialSkill` field to companion data structure
- [ ] Update companion cards to show special skill
- [ ] Update backend companion info dictionary with skills
- [ ] Update story prompt to REQUIRE using companion skill in climax
- [ ] Add validation: companion skill must appear in story

**Files to Modify:**
- `lib/screens/wizard_steps/companion_selector_step.dart` (lines 75-137)
- `backend/services/story_service.py` (lines 49-67, add skills to prompt)
- `backend/services/story_service.py` (lines 113-170, require skill usage)

---

### Phase 5: Mood-to-Atmosphere Mapping ⏳ PENDING

**Current Location:** `lib/screens/wizard_steps/feeling_selection_step.dart` (lines 78-87)

#### Current Moods:
1. Shining Bright (✨)
2. Brave Heart (🦁)
3. Friendly (🤝)
4. Peaceful (🌊)
5. Creative (🎨)
6. Joyful (😊)
7. Blue (😢)
8. Stormy (😠)

#### Atmosphere Mapping (for Backend):

| Mood | Atmosphere Filter | Story Arc |
|------|-------------------|-----------|
| Shining Bright | Glowing, warm, golden light everywhere | Journey to share light with others |
| Brave Heart | Dark edges but bright core, shadows to overcome | Face fear, become protector |
| Friendly | Warm colors, inviting spaces | Meet new friends through adventure |
| Peaceful | Soft blues, gentle sounds, flowing water | Find calm in chaos, help others find peace |
| Creative | Exploding colors, shapeshifting landscapes | Create something to save the day |
| Joyful | Bouncing energy, musical elements | Spread joy through a sad world |
| Blue | Rain that turns to rainbows, tears that water flowers | Transform sadness into growth |
| Stormy | Literal magical storm to journey through | Find inner strength in the storm |

#### Implementation Tasks:
- [ ] Create atmosphere mapping dictionary in backend
- [ ] Update story prompt to apply atmosphere filter
- [ ] Ensure mood influences: weather, colors, sounds, overall tone
- [ ] Add mood-specific impossible element suggestions
- [ ] Test each mood produces distinct story feel

**Files to Modify:**
- `backend/services/story_service.py` (add atmosphere mapping)
- `backend/services/story_service.py` (integrate into prompt generation)

---

### Phase 6: Age Calibration for Adventure Intensity ⏳ PENDING

**Current System:** Basic age grouping (3-5, 6-8, 9-12)

#### Enhanced Age Calibration:

| Age Group | Adventure Intensity | Vocabulary | Impossible Element Examples |
|-----------|-------------------|------------|----------------------------|
| **3-5** | Gentle magic, no danger | Simple, concrete words | Ride on a friendly cloud, talk to flowers |
| **6-8** | Medium stakes, safe resolution | Age-appropriate, some metaphors | Fly on dandelion seeds, taste rainbow colors |
| **9-12** | High stakes, epic scale, suspense | Rich, poetic language | Surf on lightning bolts, rewrite gravity |

#### Implementation Tasks:
- [ ] Update age-based word count rules in prompt
- [ ] Create age-specific impossible element suggestions
- [ ] Add age-specific sensory complexity tiers
- [ ] Adjust climax intensity based on age
- [ ] Test stories across all age groups

**Files to Modify:**
- `backend/services/story_service.py` (age calibration)
- `backend/tasks/story_tasks.py` (pass age to prompt builder)

---

### Phase 7: Story Length Options ⏳ PENDING

**Current System:** Fixed length (~400-700 words)

#### New Length System:

| Length Option | Word Count | Use Case | UI Label |
|--------------|------------|----------|----------|
| **Quick Bedtime** | 300-400 words | Fast bedtime story | "Quick Adventure (5 min)" |
| **Standard** | 600-800 words | Normal storytelling | "Epic Tale (10 min)" |
| **Grand Epic** | 1000-1200 words | Weekend/long sessions | "Legendary Quest (15 min)" |

#### Implementation Tasks:
- [ ] Add length selector to UI (Quick/Standard/Epic)
- [ ] Update `WizardData` to include `storyLength` field
- [ ] Update backend to accept length parameter
- [ ] Adjust pacing based on length (Quick = 1 conflict, Epic = 3 subplots)
- [ ] Update prompt to specify target word count

**Files to Modify:**
- `lib/screens/wizard_steps/magic_review_step.dart` (add length picker)
- `lib/screens/wizard_story_screen.dart` (add to WizardData)
- `lib/screens/wizard_steps/wizard_data_mapper.dart` (pass length)
- `backend/tasks/story_tasks.py` (process length parameter)
- `backend/services/story_service.py` (adjust prompt for length)

---

### Phase 8: Free-Form Story Input ⏳ PENDING

**Goal:** Let kids type or say what they want in the story (like telling a parent)

#### Implementation Design:

**UI Components:**
- Text input field: "What do you want in your story?"
- Voice input button (speech-to-text)
- Example prompts: "I want to meet a talking tree", "I want to ride a dragon"

**Backend Processing:**
- Extract key elements from free text (characters, objects, actions)
- Integrate into story as secondary characters or plot points
- MUST elevate user input to plot-relevant (not background decoration)

#### Implementation Tasks:
- [ ] Add text input to wizard (new step or part of review)
- [ ] Add voice input capability (use Flutter speech_to_text)
- [ ] Create backend parser for free-form requests
- [ ] Update prompt to incorporate custom elements
- [ ] Add validation: ensure custom element appears in story
- [ ] Test with various inputs ("I want...", "Can there be...", etc.)

**Files to Create/Modify:**
- `lib/screens/wizard_steps/custom_elements_step.dart` (NEW)
- `lib/screens/wizard_story_screen.dart` (add custom elements to flow)
- `lib/screens/wizard_steps/wizard_data_mapper.dart` (pass custom elements)
- `backend/services/story_service.py` (parse and integrate custom elements)

---

## 🔧 Technical Implementation Order

**Recommended sequence for minimal breaking changes:**

1. ✅ **Phase 1: Backend Prompt** (DONE) - Sets foundation for all improvements
2. 🔄 **Phase 2: Archetypes** (IN PROGRESS) - Quick win, visible impact
3. **Phase 4: Companion Skills** - Builds on archetype pattern
4. **Phase 5: Mood Mapping** - Enhances existing mood selector
5. **Phase 3: Settings** - Requires UI redesign, more complex
6. **Phase 6: Age Calibration** - Refinement of existing system
7. **Phase 7: Length Options** - New UI component
8. **Phase 8: Free-Form Input** - Most complex, new feature

---

## 📊 Testing Plan

### Per-Phase Testing:
- Generate 3 stories with each new feature
- Compare before/after story quality
- Check all age groups (3-5, 6-8, 9-12)
- Verify special abilities/skills appear in stories

### Integration Testing:
- Test all combinations of archetype + setting + companion + mood
- Verify sensory immersion (3+ senses per scene)
- Verify impossible element appears at climax
- Verify protagonist agency (kid solves problem)
- Verify companion skill used in climax

### User Testing:
- Read stories to actual kids
- Measure engagement (do they ask for it again?)
- Collect parent feedback on excitement level
- Iterate based on real usage

---

## 🚨 Rollback Plan

Each phase should be feature-flagged or easily reversible:

**Backend:**
- Keep old prompt as backup in `story_service.py`
- Add feature flag: `USE_ADVENTURE_MODE = True/False`
- Can switch between old/new prompts

**Frontend:**
- Keep old archetype/setting data commented out
- New data structures extend old ones
- Can revert by uncommenting old data

---

## 📝 Progress Tracking

### Session 1 (Dec 21, 2025):
- ✅ Upgraded backend story prompt with adventure architecture
- ✅ Fixed companion character details bug (Marvin as stuffed bear)
- ✅ Created comprehensive implementation plan
- 🔄 Started Phase 2: Character Archetypes

### Next Session Tasks:
1. Complete Phase 2: Update archetype data with special abilities
2. Update UI to show abilities in archetype cards
3. Update backend to include ability in story prompt
4. Test archetype abilities appear in generated stories
5. Move to Phase 4: Companion Special Skills

---

## 📚 Reference Files

### Frontend Files:
- `lib/widgets/archetype_card.dart` - Archetype definitions
- `lib/screens/wizard_steps/feeling_selection_step.dart` - Scenarios & moods
- `lib/screens/wizard_steps/companion_selector_step.dart` - Companions
- `lib/screens/wizard_steps/magic_review_step.dart` - Final review step
- `lib/screens/wizard_story_screen.dart` - WizardData class
- `lib/screens/wizard_steps/wizard_data_mapper.dart` - Maps wizard data to API

### Backend Files:
- `backend/services/story_service.py` - Story prompt generation (MAIN FILE)
- `backend/tasks/story_tasks.py` - Story generation task orchestration
- `backend/services/story_generation_service.py` - AI API call (Gemini)
- `backend/routes/story_routes.py` - API endpoints

---

## 💡 Key Insights

1. **Frontend drives the experience** - All selections happen in Flutter UI
2. **Backend powers the magic** - Prompt engineering is critical for story quality
3. **Data flows through mapper** - `wizard_data_mapper.dart` is the bridge
4. **Gemini does the writing** - But only as good as the prompt we give it

---

## 🎯 Success Metrics

Story quality improved when:
- ✅ Every story has 3+ senses used
- ✅ Every story has an impossible element at climax
- ✅ Protagonist solves the problem themselves (not passive)
- ✅ Companion special skill is used in the climax
- ✅ Kids ask to hear the story again
- ✅ Parents report increased engagement vs old stories

---

**End of Plan**
