# Feelings Wheel Redesign Plan
## Professional Children's App Design (Ages 5-8)

### Layout: Traditional Three-Ring Structure
```
┌─────────────────────────────────────┐
│   Tertiary Ring (Outer): 70%-95%   │
│  ┌───────────────────────────────┐  │
│  │ Secondary Ring (Middle): 40%-70% │
│  │  ┌─────────────────────────┐  │  │
│  │  │  Core Ring (Center):    │  │  │
│  │  │     20%-40% radius      │  │  │
│  │  └─────────────────────────┘  │  │
│  └───────────────────────────────┘  │
└─────────────────────────────────────┘
```

### Interaction Model: Progressive Illumination
**State 1: Initial** - Core emotions brightly lit, secondary/tertiary dimmed (30% opacity)
  - User sees 7 core emotion segments with large faces
  - Secondary and tertiary visible but grayed out
  - Teaches full emotional hierarchy

**State 2: Core Selected** - Selected core path lights up
  - Tapped core glows with magical effect
  - That core's secondary emotions brighten to full color
  - All other secondary/tertiary stay dimmed
  - Clear visual path from core → secondary

**State 3: Secondary Selected** - Drill down to tertiary
  - Tapped secondary glows
  - That secondary's tertiary emotions brighten
  - Shows complete emotional path: core → secondary → tertiary

### Face Integration (NO WHITE BACKGROUNDS)
**Core Emotions (7 total):**
- Large faces (80-120pt size)
- Drawn directly on colored segments
- Use ColorFilter.mode with BlendMode.multiply to blend black lines with segment color
- Position: Center of each segment
- Label: Below face in bold 18pt sans-serif

**Secondary Emotions (~30-40 total):**
- Medium faces (40-60pt size)
- Same blend mode technique
- Smaller labels: 12pt

**Tertiary Emotions (~80+ total):**
- Small faces (24-32pt size) OR icon-only
- Tiny labels: 10pt
- May hide faces if segment too small, show on tap

### Color & Contrast
- Maintain existing emotion color palette (matches therapeutic standards)
- Selected segments: 100% opacity + glow effect
- Unselected segments: 30% opacity
- Text contrast ratio: Minimum 4.5:1 (WCAG AA)
- Glow color: White with 40% opacity, 20px blur

### Touch Targets
- Minimum segment touch area: 44pt radially (for small fingers)
- Core segments: Easily 60-80pt
- Outer tertiary: May need expanded tap zones

### Magical Effects
1. **Selection Animation**: 200ms scale (1.0 → 1.05) with ease-out
2. **Glow Pulse**: 1000ms breathing effect on selected (0.7 → 1.0 opacity)
3. **Color Transition**: 300ms fade when selecting/deselecting
4. **Haptic Feedback**: Light impact on tap (if mobile)

### Implementation Steps
1. Calculate segment positions for all 122 emotions
2. Draw dimmed segments for entire wheel structure
3. Implement progressive illumination state machine
4. Apply ColorFilter.mode(BlendMode.multiply) for face rendering
5. Add animations and glow effects
6. Test with target age group for usability

### Accessibility
- High contrast mode option
- Scalable text (respect system font size)
- VoiceOver/TalkBack labels for each emotion
- Reduced motion option

### Success Metrics
- Child can identify and select target emotion within 15 seconds
- 95%+ recognition of face-emotion match
- Zero confusion about interaction model after first use
- Positive emotional response ("This is fun!")
