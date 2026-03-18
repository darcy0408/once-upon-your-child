# Feelings Wheel Refactor Plan

**Date:** 2026-01-26
**Status:** Ready for Implementation
**Assignee:** Next Claude Instance

---

## Objective

Refactor the Feelings Wheel to use **Progressive Disclosure with Replacement** instead of concentric rings, and remove age-inappropriate emotions.

---

## Part 1: Remove Inappropriate Emotions

### Emotions to Remove from `lib/feelings_wheel_data.dart`

| Location | Emotion | Reason |
|----------|---------|--------|
| Happy → Playful → tertiary | `Aroused` | Inappropriate for children |
| Happy → Trusting → tertiary | `Intimate` | Too mature for children |
| Angry → Bitter → tertiary | `Violated` | May be triggering |
| Angry → Aggressive → tertiary | `Auctiole` | Typo/error - not a real word |

### Replacement Suggestions

| Remove | Replace With |
|--------|--------------|
| `Aroused` | `Silly` or `Giggly` |
| `Intimate` | `Close` or `Connected` |
| `Violated` | `Wronged` or `Mistreated` |
| `Auctiole` | Remove entirely (keep just `Provoked`, `Hostile`) |

### Code Changes

**File:** `lib/feelings_wheel_data.dart`

```dart
// BEFORE (line ~554):
SecondaryFeeling(
  id: 'playful',
  name: 'Playful',
  emoji: '😄',
  eyeType: 'Happy',
  mouthType: 'Twinkle',
  tertiary: ['Aroused', 'Cheeky'],  // ❌ Aroused is inappropriate
),

// AFTER:
SecondaryFeeling(
  id: 'playful',
  name: 'Playful',
  emoji: '😄',
  eyeType: 'Happy',
  mouthType: 'Twinkle',
  tertiary: ['Silly', 'Cheeky'],  // ✅ Child-appropriate
),
```

```dart
// BEFORE (line ~608):
SecondaryFeeling(
  id: 'trusting',
  name: 'Trusting',
  emoji: '😊',
  eyeType: 'Happy',
  mouthType: 'Smile',
  tertiary: ['Sensitive', 'Intimate'],  // ❌ Intimate is too mature
),

// AFTER:
SecondaryFeeling(
  id: 'trusting',
  name: 'Trusting',
  emoji: '😊',
  eyeType: 'Happy',
  mouthType: 'Smile',
  tertiary: ['Sensitive', 'Connected'],  // ✅ Child-appropriate
),
```

```dart
// BEFORE (line ~898):
SecondaryFeeling(
  id: 'bitter',
  name: 'Bitter',
  emoji: '😒',
  eyeType: 'EyeRoll',
  mouthType: 'Concerned',
  tertiary: ['Indignant', 'Violated'],  // ❌ Violated may be triggering
),

// AFTER:
SecondaryFeeling(
  id: 'bitter',
  name: 'Bitter',
  emoji: '😒',
  eyeType: 'EyeRoll',
  mouthType: 'Concerned',
  tertiary: ['Indignant', 'Wronged'],  // ✅ Less triggering
),
```

```dart
// BEFORE (line ~914):
SecondaryFeeling(
  id: 'aggressive',
  name: 'Aggressive',
  emoji: '😤',
  eyeType: 'EyeRoll',
  mouthType: 'Serious',
  tertiary: ['Provoked', 'Hostile', 'Auctiole'],  // ❌ Auctiole is a typo
),

// AFTER:
SecondaryFeeling(
  id: 'aggressive',
  name: 'Aggressive',
  emoji: '😤',
  eyeType: 'EyeRoll',
  mouthType: 'Serious',
  tertiary: ['Provoked', 'Hostile'],  // ✅ Removed typo
),
```

### Also Update Face Assets List

**File:** `lib/widgets/expanding_feelings_wheel.dart`

In the `_availableFaces` set (around line 33-62), update:
- Remove: `'aroused'`, `'intimate'`, `'violated'`, `'auctiole'`
- Add: `'silly'`, `'connected'`, `'wronged'` (if you create these face images)

---

## Part 2: Refactor Wheel UX (Progressive Replacement)

### Current Behavior (Problem)
- Shows concentric rings (core + secondary + tertiary)
- Tries to render all emotions at once → performance issues
- Complex angle calculations for nested rings

### New Behavior (Solution)
- **Step 1:** Show ONLY core emotions wheel (7 sections with faces)
- **Step 2:** When core tapped → REPLACE wheel with that core's secondary emotions
- **Step 3:** When secondary tapped → Show tertiary options in that slice OR as chips below

### UX Flow Diagram

```
┌─────────────────────────────────────────────────────────────┐
│ STEP 1: Core Emotions Wheel                                 │
│                                                             │
│              😊 Happy                                       │
│         😠          😲                                      │
│       Angry      Surprised                                  │
│         🤢          😨                                      │
│      Disgusted   Fearful                                    │
│         😞          😢                                      │
│        Bad         Sad                                      │
│                                                             │
│            [Center: "Tap a Feeling"]                        │
└─────────────────────────────────────────────────────────────┘
                            │
                            │ User taps "Happy"
                            ▼
┌─────────────────────────────────────────────────────────────┐
│ STEP 2: Secondary Emotions Wheel (REPLACES core wheel)      │
│                                                             │
│         😄 Playful     😌 Content                           │
│      🤔 Interested        😊 Proud                          │
│      🥰 Accepted          💪 Powerful                       │
│         😌 Peaceful    😊 Trusting                          │
│              🙂 Optimistic                                  │
│                                                             │
│            [Center: 😊 "Happy" + face]                      │
│            [← Back button]                                  │
└─────────────────────────────────────────────────────────────┘
                            │
                            │ User taps "Playful"
                            ▼
┌─────────────────────────────────────────────────────────────┐
│ STEP 3: Tertiary Options (appear in Playful's slice)        │
│                                                             │
│         ★ PLAYFUL ★    😌 Content                           │
│       ┌──────────┐                                          │
│       │  Silly   │  ← Tertiary chips                        │
│       │  Cheeky  │     in the slice                         │
│       └──────────┘                                          │
│                                                             │
│            [Center: 😄 "Playful" + face]                    │
│            [← Back to Happy]                                │
│                                                             │
│   OR: Show tertiary as chips BELOW the wheel                │
└─────────────────────────────────────────────────────────────┘
```

### Implementation Approach

#### Option A: Modify Existing Widget (Recommended)

**File:** `lib/widgets/expanding_feelings_wheel.dart`

1. Add state to track current "level" and "parent":
```dart
enum WheelLevel { core, secondary, tertiary }

class _ExpandingFeelingsWheelState extends State<ExpandingFeelingsWheel> {
  WheelLevel _currentLevel = WheelLevel.core;
  CoreEmotion? _selectedCore;
  SecondaryFeeling? _selectedSecondary;

  List<dynamic> get _currentEmotions {
    switch (_currentLevel) {
      case WheelLevel.core:
        return FeelingsWheelData.coreEmotions;
      case WheelLevel.secondary:
        return _selectedCore?.secondary ?? [];
      case WheelLevel.tertiary:
        return _selectedSecondary?.tertiary ?? [];
    }
  }
}
```

2. Simplify the painter to only draw ONE ring at a time:
```dart
void paint(Canvas canvas, Size size) {
  final emotions = currentEmotions;
  final sectorAngle = (2 * math.pi) / emotions.length;

  for (int i = 0; i < emotions.length; i++) {
    _drawSingleSector(canvas, center, radius, i, sectorAngle, emotions[i]);
  }

  _drawCenterHub(canvas, center, radius);
}
```

3. Update tap handling to navigate levels:
```dart
void _handleTap(TapDownDetails details, double size) {
  // ... calculate which sector was tapped ...

  if (_currentLevel == WheelLevel.core) {
    setState(() {
      _selectedCore = tappedCore;
      _currentLevel = WheelLevel.secondary;
    });
  } else if (_currentLevel == WheelLevel.secondary) {
    setState(() {
      _selectedSecondary = tappedSecondary;
      // Either show tertiary in slice OR call onFeelingSelected
    });
  }
}

void _goBack() {
  setState(() {
    if (_currentLevel == WheelLevel.tertiary) {
      _currentLevel = WheelLevel.secondary;
      _selectedSecondary = null;
    } else if (_currentLevel == WheelLevel.secondary) {
      _currentLevel = WheelLevel.core;
      _selectedCore = null;
    }
  });
}
```

4. Add animated transition between levels:
```dart
AnimatedSwitcher(
  duration: Duration(milliseconds: 300),
  child: CustomPaint(
    key: ValueKey(_currentLevel),
    painter: _WheelPainter(emotions: _currentEmotions, ...),
  ),
)
```

#### Option B: Create New Simpler Widget

Create `lib/widgets/simple_feelings_wheel.dart` with cleaner architecture:
- Stateful widget with level tracking
- Single-ring painter (much simpler math)
- Back button in center when not at core level
- Animate wheel rotation/fade when transitioning

---

## Part 3: Face Assets

### Existing Faces (124 images in `assets/feelings_faces/`)

Core emotions all have faces:
- ✅ angry.png, happy.png, surprised.png, bad.png, fearful.png, sad.png, disgusted.png

Most secondary emotions have faces:
- ✅ playful.png, content.png, proud.png, excited.png, scared.png, etc.

### Faces to Create (for replacement emotions)

| Emotion | Needed? | Notes |
|---------|---------|-------|
| silly.png | Yes | Replace aroused |
| connected.png | Yes | Replace intimate |
| wronged.png | Optional | Replace violated |

**Option:** Use existing similar faces as fallback:
- `silly` → use `cheeky.png` or `playful.png`
- `connected` → use `accepted.png` or `trusting.png`
- `wronged` → use `hurt.png` or `disappointed.png`

---

## Part 4: Age-Based Filtering (Optional Enhancement)

For younger children, limit the emotional vocabulary:

```dart
List<CoreEmotion> getEmotionsForAge(int age) {
  final emotions = FeelingsWheelData.coreEmotions;

  if (age <= 5) {
    // Only show core emotions, no drilling down
    return emotions;
  } else if (age <= 8) {
    // Show core + simplified secondary (max 4 per core)
    return emotions.map((e) => e.copyWith(
      secondary: e.secondary.take(4).toList(),
    )).toList();
  } else {
    // Full vocabulary for older kids
    return emotions;
  }
}
```

---

## Testing Checklist

### After Removing Inappropriate Emotions
- [ ] App compiles without errors
- [ ] No references to 'Aroused', 'Intimate', 'Violated', 'Auctiole'
- [ ] Replacement emotions display correctly
- [ ] Face images load for new emotions (or fallback gracefully)

### After Refactoring UX
- [ ] Core wheel shows 7 emotions with faces
- [ ] Tapping core emotion shows secondary wheel (replaces, not adds)
- [ ] Back button returns to previous level
- [ ] Center shows selected emotion + face
- [ ] Tertiary selection works (either in slice or as chips)
- [ ] Final selection triggers `onFeelingSelected` callback
- [ ] Smooth animations between levels
- [ ] No performance issues (max ~9 items rendered at once)

### Age-Based Testing
- [ ] Age 4: Shows simple 6-mood MoodMagicPicker (existing behavior)
- [ ] Age 6: Shows wheel with limited vocabulary
- [ ] Age 12: Shows full wheel with all levels

---

## Files to Modify

| File | Changes |
|------|---------|
| `lib/feelings_wheel_data.dart` | Remove inappropriate emotions, add replacements |
| `lib/widgets/expanding_feelings_wheel.dart` | Refactor to replacement-based navigation |
| `lib/widgets/expanding_feelings_wheel.dart` | Update `_availableFaces` set |
| `lib/screens/wizard_steps/feeling_selection_step.dart` | No changes needed (uses same callback) |

---

## Priority Order

1. **First:** Remove inappropriate emotions (quick fix, ~15 min)
2. **Second:** Refactor wheel UX to replacement model (~2-3 hours)
3. **Third:** Add smooth animations (~30 min)
4. **Optional:** Create new face assets for replacement emotions
5. **Optional:** Add age-based vocabulary filtering

---

## Success Criteria

The feelings wheel is "done" when:
- [ ] No inappropriate emotions visible to children
- [ ] Wheel shows ONE level at a time (not concentric rings)
- [ ] Each level has max 9 items (performance-safe)
- [ ] Back navigation works smoothly
- [ ] Selected emotion shows in center with face
- [ ] Children can complete: Core → Secondary → Tertiary → Story
- [ ] Parents can't find any words they'd object to

---

## Reference Files

- Current implementation: `lib/widgets/expanding_feelings_wheel.dart`
- Data structure: `lib/feelings_wheel_data.dart`
- Face assets: `assets/feelings_faces/` (124 PNGs)
- Age-gating logic: `lib/screens/wizard_steps/feeling_selection_step.dart`
- Previous handoff docs: `FEELINGS_WHEEL_HANDOFF.md`, `FEELINGS.md`

---

**Document Version:** 1.0
**Created By:** Claude (Opus 4.5)
**For:** Next Claude Instance
