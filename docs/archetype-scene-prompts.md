# Archetype Scene Cards — Adventurer Band (ages 9-11)

## Overview & Design Decision

**4 images total — one per archetype, each featuring a specific diverse character with a full illustrated face.**

The blank-oval / face-compositing approach was evaluated and rejected:
- Compositing a photo-based avatar onto a cartoon scene card produces style mismatches (realistic face on cartoon body, lighting clash, clipped hair)
- Not all users will have a generated avatar
- The existing `assets/images/archetypes/adventurer/` images prove the right approach: distinct Pixar-quality 3D characters, each representing the archetype perfectly

The app already has working images for this band. This document is a reference for regenerating or improving them.

**4 archetypes displayed in a 2×2 grid:**

| Archetype | File | Character concept |
|-----------|------|-------------------|
| The Quiz Whiz | `clever_inventor.jpg` | Tech/inventor kid, goggles, workshop |
| The Master Creator | `gentle_dreamer.jpg` | Reader/dreamer kid, floating books, library |
| The Lightning Runner | `speedy_explorer.jpg` | Explorer kid, compass + map, purple landscape |
| The Animal Whisperer | `animal_whisperer.jpg` | Nature kid, forest animals surrounding them |

Soul Mender was intentionally removed — the empathy/kindness theme is woven into every story regardless of archetype choice, and having an explicit "healer" archetype risks signalling "this is the therapy one" to kids who may then avoid it.

---

## If Regenerating Images

### What works well in the existing set
- Full expressive faces — children identify with the character concept, not their own reflection
- Pixar/Dreamworks quality 3D render style
- Each archetype is immediately recognisable by environment and props alone
- Diverse characters across the set (different skin tones, hair types)

### What to improve
- **Master Creator** (`gentle_dreamer`) shows a reader/dreamer — ideally would show an artist with a paintbrush and things being painted to life. The environment concept is good (library/magical space) but the props should be creative tools, not books.
- **Lightning Runner** (`speedy_explorer`) shows an explorer with a compass rather than a speed/running character. Could be updated to show speed trails, stardust, cosmic racetrack.
- Ensure diversity is maintained across all 4: aim for different skin tones and hair types across the set, not all the same.

### Technical specs
- **Output**: 1024 × 1024 px (square) or 1024 × 1400 px (portrait — fits card better)
- **Art style**: Stylized Pixar/Dreamworks quality 3D render, warm saturated colours
- **Character framing**: chest-up or mid-thigh up, facing viewer
- **File format**: JPEG, saved to `assets/images/archetypes/adventurer/`
- **Tone**: warm, empowering, therapeutic — child sees this and thinks "I want to be that hero"
- No weapons, no blood, no fear, no threatening darkness

### Diversity guidance
Generate each character with a distinct look. Suggested spread:
- Quiz Whiz: East Asian or South Asian features
- Master Creator: Black or mixed-race features  
- Lightning Runner: Latino or Middle Eastern features
- Animal Whisperer: can vary — currently fair-skinned with curly hair, which works

---

## File locations

```
assets/images/archetypes/adventurer/
  clever_inventor.jpg     ← Quiz Whiz (current: good)
  gentle_dreamer.jpg      ← Master Creator (current: props need updating)
  speedy_explorer.jpg     ← Lightning Runner (current: explorer theme, not speed)
  animal_whisperer.jpg    ← Animal Whisperer (current: good)
```
