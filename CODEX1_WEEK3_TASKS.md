# Codex 1 - Week 3 Tasks (Character Creation & UX)

**Assigned to**: Codex Instance 1
**Priority**: HIGH - Building on Week 1-2 UX improvements
**Timeline**: Week 3 (Nov 26 - Dec 2)

---

## Current Status Summary

### ✅ Completed (Weeks 1-2)
- FABs with analytics tracking
- Touch targets (44dp+)
- Swipe tutorial
- Onboarding telemetry
- Pull-to-refresh
- Semantic labels
- Grace period hard-limit UI
- User-friendly error dialogs

### 📋 Week 3 Focus
Character creation UX improvements + feature discoverability

---

## Task C3.1: Character Creation Templates (Priority: HIGH)

**User Pain Point**: "Character creation with sliders/traits feels like doing taxes. Parents abandon."

**Objective**: Simplify character creation with one-tap templates.

### Implementation Steps:

1. **Create Character Template Service**
   - File: `lib/services/character_template_service.dart` (NEW)
   - Define 6 pre-made character templates:
     - The Adventurer (brave, curious, energetic)
     - The Thinker (thoughtful, analytical, curious)
     - The Artist (creative, imaginative, expressive)
     - The Helper (kind, empathetic, caring)
     - The Athlete (active, determined, competitive)
     - The Shy One (quiet, observant, thoughtful)
   - Each template includes personality values, traits, fears, strengths

2. **Update Character Creation Screen**
   - File: `lib/character_creation_screen_enhanced.dart`
   - Add toggle between "Templates" and "Custom" modes
   - Show template cards with icons, colors, descriptions
   - Allow character name customization on template selection
   - Optional: Allow tweaking template after selection

3. **Analytics Integration**
   - Track template usage: `character_template_selected`
   - Track custom vs template creation ratio
   - Monitor abandonment rate improvement

### Code Structure:

```dart
// lib/services/character_template_service.dart
class CharacterTemplate {
  final String name;
  final IconData icon;
  final Color color;
  final String description;
  final Map<String, int> personality; // energy, social, structure
  final List<String> traits;
  final List<String> fears;
  final List<String> strengths;
}

class CharacterTemplateService {
  static List<CharacterTemplate> getTemplates() { /* ... */ }
  static Character applyTemplate(CharacterTemplate template, String childName) { /* ... */ }
}
```

### Testing:
- [ ] Templates display correctly with icons and colors
- [ ] One-tap creation works (just name + template)
- [ ] Custom mode still available for advanced users
- [ ] Templates save correctly to backend
- [ ] Analytics events fire correctly

### Success Metrics:
- Character creation completion: 40% → 80%
- Average creation time: 5min → 30sec
- Template usage: >60% of new characters

---

## Task C3.2: Feature Discovery Tour (Priority: MEDIUM)

**User Pain Point**: "Users don't know about features like interactive stories, coloring pages."

**Objective**: Add optional tour highlighting key features after first story.

### Implementation Steps:

1. **Create Feature Tour Service**
   - File: `lib/services/feature_tour_service.dart` (NEW)
   - Track which tours user has seen
   - Define tour steps for each feature
   - Manage tour dismissal and completion

2. **Create Tour Overlay Widget**
   - File: `lib/widgets/feature_tour_overlay.dart` (NEW)
   - Spotlight effect on target feature
   - Clear, concise descriptions
   - "Next", "Skip tour" buttons
   - Progress indicator (1/5, 2/5, etc.)

3. **Tour Triggers**
   - After first story: Show "Library" tour
   - After second story: Show "Interactive Stories" tour
   - After third story: Show "Coloring Pages" tour
   - Settings: Show "BYOK" tour hint

### Tour Flow:
```
First Story Complete
  ↓
Show Celebration Dialog
  ↓
Offer Feature Tour (optional)
  ↓
If accepted: Show 3-step tour
  - Library tab
  - Interactive mode toggle
  - Settings (BYOK hint)
```

### Testing:
- [ ] Tour appears after first story
- [ ] User can skip tour
- [ ] Tour doesn't show twice
- [ ] Spotlight highlights correct elements
- [ ] Progress indicator works

---

## Task C3.3: Pull-to-Refresh Enhancement (Priority: LOW)

**Objective**: Extend pull-to-refresh to all list screens.

### Files to Update:
- `lib/saved_stories_screen.dart` (already done ✅)
- `lib/coloring_book_library_screen.dart` (add)
- `lib/character_edit_screen_enhanced.dart` (add to character list)

### Implementation:
```dart
RefreshIndicator(
  onRefresh: _refreshData,
  child: ListView(...),
)
```

### Testing:
- [ ] Pull-to-refresh works on all list screens
- [ ] Loading indicator shows
- [ ] Data refreshes correctly
- [ ] No crashes on rapid pulls

---

## Priority Order

1. **C3.1**: Character Templates (CRITICAL - biggest UX win)
2. **C3.2**: Feature Discovery Tour (HIGH - improves engagement)
3. **C3.3**: Pull-to-Refresh (LOW - polish/consistency)

---

## Deliverables

- [ ] Character template service created
- [ ] Template selection UI implemented
- [ ] Feature tour service created
- [ ] Tour overlay widget created
- [ ] Pull-to-refresh on remaining screens
- [ ] All analytics tracking implemented
- [ ] Manual testing completed
- [ ] Update TEAM_COORDINATION.md with completion status

---

## Notes

- Focus on **simplicity** - templates should be dead simple
- Templates should feel **magical** (one tap = complete character)
- Tour should be **optional** and easy to dismiss
- Track metrics to validate improvements
- Test with real users if possible

---

## Success Criteria

- [ ] Character creation time drops to <1 minute
- [ ] Feature discovery rate improves
- [ ] No increase in bugs or crashes
- [ ] Analytics events working
- [ ] User feedback positive
