# Big Feelings Implementation Checklist

## Goal

This checklist maps the Big Feelings master spec onto the current codebase so implementation can happen in small, coherent phases.

## Phase 0: Alignment

- [ ] Confirm the shared schema names:
  - `feeling`
  - `trigger`
  - `body_signal`
  - `coping_tool`
  - `repair_goal`
  - `parent_hidden_context`
- [ ] Confirm V1 scope is ages 3-5 only.
- [ ] Confirm V1 feelings are:
  - `mad`
  - `sad`
  - `scared`
- [ ] Confirm V1 hidden parent contexts are:
  - sibling fights
  - trouble hearing `no`
  - bedtime worry
  - yelling when mad

## Phase 1: Data Model

### Files

- [wizard_data.dart](/C:/dev/story-weaver-app/lib/models/wizard_data.dart)
- [wizard_data_mapper.dart](/C:/dev/story-weaver-app/lib/screens/wizard_steps/wizard_data_mapper.dart)

### Tasks

- [ ] Add fields to `WizardData`:
  - `selectedFeeling`
  - `selectedTrigger`
  - `selectedBodySignal`
  - `selectedCopingTool`
  - `selectedRepairGoal`
  - `parentHiddenContext`
- [ ] Decide whether `selectedEmotionChips` stays for older paths or is normalized into the new fields.
- [ ] Map the new fields into the story payload in `wizard_data_mapper.dart`.
- [ ] Keep the existing scenario selection for `big_feelings_quest`, but enrich the payload when that scenario is selected.

### Notes

- Keep the new fields optional at first so existing story generation does not break.
- Do not remove the current feeling-chip flow until the new V1 flow is wired and verified.

## Phase 2: Ages 3-5 UI Flow

### Files

- [feeling_selection_step.dart](/C:/dev/story-weaver-app/lib/screens/wizard_steps/feeling_selection_step.dart)
- [feelings_garden_screen.dart](/C:/dev/story-weaver-app/lib/screens/feelings_garden_screen.dart)
- New screen recommended:
  - `lib/screens/big_feelings_flow_screen.dart`
  - or a focused widget subtree under `feeling_selection_step.dart`

### Tasks

- [ ] Replace the current `FeelingsQuestModal` shortcut for ages 3-5 with a dedicated V1 flow.
- [ ] Reuse the existing ages 3-5 emotion cloud model from `feelings_garden_screen.dart`.
- [ ] Build Screen 1: feeling clouds
  - mad
  - sad
  - scared
- [ ] Build Screen 2: trigger choices
  - mad: wait, no, broken
  - sad: lost, miss, left out
  - scared: dark, loud, new
- [ ] Build Screen 3: body clues
  - hot face
  - tight tummy
  - fast heart
  - tears
- [ ] Build Screen 4: helper pick
  - dragon breaths
  - ask for help
  - squeeze hug
- [ ] Make all 3-5 screens audio-first with large touch targets.
- [ ] Keep labels at 1-2 words where possible.

### Notes

- If desired, ages 3-4 can skip explicit helper choice later and let the story introduce the helper naturally. For V1, keeping the helper screen is acceptable if it remains very simple.

## Phase 3: Story Prompt Integration

### Files

- [api_service_manager.dart](/C:/dev/story-weaver-app/lib/services/api_service_manager.dart)

### Tasks

- [ ] Add a dedicated Big Feelings prompt path for `big_feelings_quest` using:
  - `feeling`
  - `trigger`
  - `body_signal`
  - `coping_tool`
  - `repair_goal`
  - `parent_hidden_context`
- [ ] Ensure linear stories open by naming the feeling and body clue in the first lines.
- [ ] Ensure the event that caused the feeling appears immediately.
- [ ] Ensure the selected helper shows up naturally in the story.
- [ ] Add repair guidance for cases like:
  - yelling
  - grabbing
  - breaking
  - scaring someone
- [ ] Ensure endings validate the feeling without treating the character as bad.

### Example Prompt Rules

- [ ] Opening should look like:
  - `Mia was so mad. Her face felt hot.`
  - `Owen felt scared. His heart went thump-thump.`
- [ ] Include at least one regulation moment.
- [ ] Include at least one repair moment when appropriate.

## Phase 4: Pick-a-Path For Big Feelings

### Files

- [api_service_manager.dart](/C:/dev/story-weaver-app/lib/services/api_service_manager.dart)
- Any interactive story flow screens that consume interactive output

### Tasks

- [ ] Add a Big Feelings-specific interactive branch strategy.
- [ ] For ages 3-5, limit V1 to:
  - 1 branch moment
  - 2 choices
  - both paths safe
  - one path includes repair
- [ ] Ensure choices are behavior-based, not moralized.

### Good Choice Examples

- [ ] `Roar and stomp`
- [ ] `Take a dragon breath`
- [ ] `Ask for help`

### Avoid

- [ ] `Choose the correct coping skill`
- [ ] `Make the good choice`

## Phase 5: Hidden Parent Layer

### Files

- [parent_controls_screen.dart](/C:/dev/story-weaver-app/lib/screens/parent_controls_screen.dart)
- [parental_consent_service.dart](/C:/dev/story-weaver-app/lib/services/parental_consent_service.dart)

### Tasks

- [ ] Add a hidden parent section for real-life struggles.
- [ ] Store a small controlled set of context flags or values.
- [ ] Keep the child flow unchanged visually when these are set.
- [ ] Feed `parent_hidden_context` into the Big Feelings prompt payload.

### V1 Parent Context Options

- [ ] sibling conflict
- [ ] trouble hearing `no`
- [ ] bedtime worry
- [ ] yelling when mad

## Phase 6: Copy And Voice Review

### Files

- [app_tts_service.dart](/C:/dev/story-weaver-app/lib/services/app_tts_service.dart)
- Big Feelings UI files added in earlier phases

### Tasks

- [ ] Make sure ages 3-5 copy stays concrete and short.
- [ ] Ensure the spoken copy matches the on-screen copy.
- [ ] Avoid therapy jargon in child-facing text.
- [ ] Confirm that repair language feels supportive, not scolding.

### Good Child Copy

- [ ] `How do they feel?`
- [ ] `What happened?`
- [ ] `What does the body say?`
- [ ] `Pick a helper`
- [ ] `What now?`
- [ ] `Make it better?`

## Phase 7: Validation

### Manual Verification

- [ ] Ages 3-5 child can complete the Big Feelings flow with audio guidance.
- [ ] Story begins by naming feeling + body clue.
- [ ] Interactive path shows two behavior choices.
- [ ] One path demonstrates repair.
- [ ] Hidden parent context changes the story shape without exposing that to the child.

### Analyzer And Regression Checks

- [ ] Run targeted `dart analyze` on all touched files.
- [ ] Verify existing non-Big-Feelings themes still work.
- [ ] Verify older age bands still fall back to existing flow until their versions are built.

## Recommended Implementation Order

1. Add model fields in `WizardData`
2. Build ages 3-5 Big Feelings UI flow
3. Map fields into payload
4. Add linear Big Feelings story prompt path
5. Add simple interactive branch path
6. Add hidden parent settings
7. Tune copy and voice
8. Test and iterate before adding ages 6-8
