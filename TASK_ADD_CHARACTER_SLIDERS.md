# Task: Add Character Customization Sliders

**Agent Assignment:** Frontend Widgets or Frontend Core Agent
**Priority:** MEDIUM
**Estimated Time:** 2-3 hours
**Goal:** Restore customization sliders to character creation flow for personalized characters

---

## Context

User wants to enable highly personalized character creation so stories can be more personalized. Customization sliders were previously removed but need to be added back to the "customize" section only.

---

## Files to Modify

Primary files (likely):
- `lib/character_creation_screen_enhanced.dart`
- `lib/widgets/character_customization_widget.dart` (if exists)
- `lib/models/character.dart` (to verify fields exist)

---

## Step-by-Step Instructions

### Step 1: Locate Character Creation Files

```bash
# Find character creation related files
find lib -name "*character*" -name "*.dart" | grep -i "creat\|custom"
```

Expected files:
- Character creation screen
- Character customization widgets
- Character model

### Step 2: Read Current Character Creation Screen

```dart
// Read the main character creation file
// Look for:
// 1. Existing customization UI
// 2. Where "customize" section/button is
// 3. What character fields exist
```

**Read these files:**
```bash
lib/character_creation_screen_enhanced.dart
lib/models/character.dart
```

### Step 3: Identify What Character Fields Need Sliders

Based on the Character model, likely fields for sliders:
- **Personality traits:**
  - Bravery (0-100)
  - Kindness (0-100)
  - Curiosity (0-100)
  - Energy level (0-100)
  - Creativity (0-100)

- **Physical attributes (if applicable):**
  - Height (relative: shorter/taller)
  - Build (thinner/stronger)

- **Story preferences:**
  - Adventure level (calm/exciting)
  - Humor level (serious/silly)
  - Magic interest (realistic/magical)

### Step 4: Create Slider Widgets

**Option A: If customize section exists, add to it**

Find the "customize" or "advanced" section in the character creation screen and add:

```dart
class CharacterCustomizationSliders extends StatefulWidget {
  final Function(Map<String, double>) onChanged;
  final Map<String, double>? initialValues;

  const CharacterCustomizationSliders({
    Key? key,
    required this.onChanged,
    this.initialValues,
  }) : super(key: key);

  @override
  State<CharacterCustomizationSliders> createState() => _CharacterCustomizationSlidersState();
}

class _CharacterCustomizationSlidersState extends State<CharacterCustomizationSliders> {
  late Map<String, double> values;

  @override
  void initState() {
    super.initState();
    values = widget.initialValues ?? {
      'bravery': 50,
      'kindness': 50,
      'curiosity': 50,
      'energy': 50,
      'creativity': 50,
    };
  }

  void _updateValue(String key, double value) {
    setState(() {
      values[key] = value;
    });
    widget.onChanged(values);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Personality Traits',
          style: Theme.of(context).textTheme.titleMedium,
        ),
        SizedBox(height: 16),

        _buildSlider(
          'Bravery',
          values['bravery']!,
          (value) => _updateValue('bravery', value),
          leftLabel: 'Cautious',
          rightLabel: 'Brave',
        ),

        _buildSlider(
          'Kindness',
          values['kindness']!,
          (value) => _updateValue('kindness', value),
          leftLabel: 'Independent',
          rightLabel: 'Caring',
        ),

        _buildSlider(
          'Curiosity',
          values['curiosity']!,
          (value) => _updateValue('curiosity', value),
          leftLabel: 'Focused',
          rightLabel: 'Curious',
        ),

        _buildSlider(
          'Energy',
          values['energy']!,
          (value) => _updateValue('energy', value),
          leftLabel: 'Calm',
          rightLabel: 'Energetic',
        ),

        _buildSlider(
          'Creativity',
          values['creativity']!,
          (value) => _updateValue('creativity', value),
          leftLabel: 'Practical',
          rightLabel: 'Creative',
        ),
      ],
    );
  }

  Widget _buildSlider(
    String label,
    double value,
    ValueChanged<double> onChanged, {
    String? leftLabel,
    String? rightLabel,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
          ),
          SizedBox(height: 8),
          Row(
            children: [
              if (leftLabel != null) ...[
                SizedBox(
                  width: 70,
                  child: Text(
                    leftLabel,
                    style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                  ),
                ),
              ],
              Expanded(
                child: Slider(
                  value: value,
                  min: 0,
                  max: 100,
                  divisions: 20,
                  label: value.round().toString(),
                  onChanged: onChanged,
                ),
              ),
              if (rightLabel != null) ...[
                SizedBox(
                  width: 70,
                  child: Text(
                    rightLabel,
                    textAlign: TextAlign.right,
                    style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}
```

### Step 5: Integrate into Character Creation Flow

**Find the "Customize" section** in character creation and add the sliders:

```dart
// In character_creation_screen_enhanced.dart
// Look for customize/advanced section, add:

if (_showCustomization) {
  CharacterCustomizationSliders(
    initialValues: _characterTraits,
    onChanged: (values) {
      setState(() {
        _characterTraits = values;
      });
    },
  ),
}
```

### Step 6: Update Character Model

Ensure the Character model can store these values:

```dart
// In lib/models/character.dart
// Add fields if they don't exist:

class Character {
  // ... existing fields ...

  Map<String, dynamic>? personalityTraits; // Store slider values

  Character({
    // ... existing params ...
    this.personalityTraits,
  });

  // Update toJson() and fromJson() to include traits
  Map<String, dynamic> toJson() {
    return {
      // ... existing fields ...
      'personality_traits': personalityTraits,
    };
  }

  factory Character.fromJson(Map<String, dynamic> json) {
    return Character(
      // ... existing fields ...
      personalityTraits: json['personality_traits'],
    );
  }
}
```

### Step 7: Send Traits to Backend

When creating/saving character, include the traits:

```dart
// In character creation save function:
final character = Character(
  name: _nameController.text,
  age: _selectedAge,
  // ... other fields ...
  personalityTraits: _characterTraits,
);

// API call will include traits in JSON
```

### Step 8: Update Backend (If Needed)

Check if backend Character model accepts these fields:

```python
# In backend/models/character.py
# Ensure there's a field for personality traits (likely already exists as JSON)

class Character(db.Model):
    # ... existing fields ...
    personality_traits = db.Column(db.JSON, nullable=True)
```

### Step 9: Test the Flow

1. **Open character creation**
2. **Navigate to customize section**
3. **Verify sliders appear**
4. **Move sliders and verify they update**
5. **Save character**
6. **Verify traits saved to database**
7. **Edit character - verify sliders load with saved values**
8. **Generate story - verify traits influence story** (if backend uses them)

---

## UI/UX Guidelines

### Visual Design:
- Use app's existing color scheme
- Sliders should be prominent but not overwhelming
- Labels should be clear and user-friendly
- Left/right labels help users understand the spectrum

### User Experience:
- Default all sliders to middle (50) for balanced character
- Show current value on slider handle
- Consider adding "Reset to Default" button
- Add tooltip/info icon explaining what traits do

### Mobile Considerations:
- Ensure sliders are touch-friendly (adequate tap target)
- Test on small screens - may need to stack differently
- Consider collapsible sections if space is tight

---

## Expected Outcome

After completing this task:

✅ Character creation has "Customize" section with personality sliders
✅ Users can adjust 5+ personality traits via sliders
✅ Traits are saved with character data
✅ Traits load correctly when editing character
✅ Sliders have clear labels and visual feedback
✅ Backend accepts and stores personality traits

---

## Testing Checklist

- [ ] Sliders appear in customize section
- [ ] All sliders move smoothly (0-100 range)
- [ ] Labels display correctly on both sides
- [ ] Current value shows on slider
- [ ] Changing sliders updates state
- [ ] Create new character with custom traits - saves successfully
- [ ] Edit existing character - traits load correctly
- [ ] Sliders work on mobile (touch targets adequate)
- [ ] No console errors
- [ ] UI looks polished and matches app style

---

## Potential Issues & Solutions

### Issue: Character model doesn't have personality_traits field
**Solution:** Add it as optional JSON field in both frontend and backend models

### Issue: Not sure where "customize" section is
**Solution:** Look for expandable sections, accordion widgets, or tabs in character creation screen. If none exist, create a new "Advanced Customization" expandable section.

### Issue: Sliders affect layout badly on mobile
**Solution:** Use `SingleChildScrollView` to make customization section scrollable, or use smaller slider labels

### Issue: Backend doesn't use traits in story generation
**Solution:** That's okay for now - backend can be updated later to use traits. Focus on frontend implementation first.

---

## Code Location Reference

```
lib/
├── character_creation_screen_enhanced.dart  ← Add sliders here
├── models/
│   └── character.dart                       ← Update model here
└── widgets/
    └── character_customization_widget.dart  ← Or create new widget here

backend/
└── models/
    └── character.py                         ← Verify this accepts JSON traits
```

---

## Communication

When complete, report in `TEAM_COORDINATION.md`:

```markdown
## Agent [N] - Frontend Widgets | 2025-11-29

### Completed
- ✅ Added character customization sliders to customize section
  - Files: lib/character_creation_screen_enhanced.dart
  - Features: 5 personality trait sliders (bravery, kindness, curiosity, energy, creativity)
  - Tested: Character creation, saving, editing all working

### Testing Results
- Sliders appear in customize section
- All traits save/load correctly
- UI polished and mobile-friendly

### Screenshots
[If possible, include screenshot of sliders]

### Next Steps
- Backend could use traits in story generation (future enhancement)
```

---

## Questions?

If blocked, post in TEAM_COORDINATION.md:
- ❓ Can't find customize section - where should sliders go?
- ❓ Character model doesn't support traits - should I add field?
- ❓ Need design guidance - what style should sliders use?

---

**Ready to start? Begin with Step 1: Locate the character creation files!**
