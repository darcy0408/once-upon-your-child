# Archetype Scene Template Cards — Adventurer Band (ages 9-11)

## Overview

8 images total: **4 archetypes × 2 gender variants (boy / girl)**. Since children pick their gender during character setup, the app serves the matching variant automatically. Each card has a blank face oval so the child's generated avatar face can be composited on top at runtime. The 4 archetypes display in a clean 2×2 grid.

The art must feel warm, therapeutic, empowering, and safe — never scary, violent, or sexualized.

---

## How to Generate

Run the prompt **twice per archetype** — once with the **[BOY VARIANT]** body spec, once with the **[GIRL VARIANT]** body spec. Everything else (pose, environment, magical effects, hat) stays identical between variants. Only the body silhouette and costume fit change.

The 4 archetypes are: **Quiz Whiz, Master Creator, Lightning Runner, Animal Whisperer**. Soul Mender was intentionally removed — the empathy/kindness theme is woven into every story regardless of archetype choice, and having an explicit "healer" archetype risks signalling "this is the therapy one" to kids who may then avoid it.

---

## Technical Configuration

- **Output**: 1024 × 1400 pixels (portrait, 3:4.1 ratio — fits a mobile card)
- **Art style**: Stylized cartoon with semi-realistic proportions, rich saturated color palette, Pixar/Dreamworks quality
- **Character framing**: occupies roughly the center 60% of the frame, from mid-thigh up
- **Blank face oval**: centered horizontally, positioned approximately 15–20% from the top of the image, approximately 200 × 260 px (width × height) at 1024px canvas width
- **Oval fill**: flat matte #D4A574 — no shading, no features, no depth. Perfectly smooth like an unfinished mannequin.
- **Background**: dynamic, atmospheric, with depth and magical elements appropriate to each archetype
- **Lighting**: warm cinematic, rim light on the character, no harsh shadows falling across the face oval area
- **No text, no logos, no UI elements**

---

## Universal Rules (apply to every image)

### Hair — CRITICAL for compositing
**The character's hat completely covers and conceals all hair. Zero hair is visible anywhere on the character.** This is non-negotiable: the compositing system will paste the child's own avatar (which already has its own hair) onto the face oval. If the scene card also shows hair, the result will have two conflicting layers of hair. The hat solves this entirely. Each archetype has a specific hat listed below.

### Face oval
- Perfectly smooth, featureless, flat matte fill in #D4A574
- Zero facial features — no suggestion of eyes, nose, mouth, brow ridge, or chin definition
- Clean hard edge where the oval meets the hat brim and collar — no blending or feathering
- A soft warm glow or halo *behind* the oval (not on it) is acceptable and looks good

### Body — gender variants
**[BOY VARIANT]**
- Broader, squarer shoulders
- Straight torso — flat chest, no chest curve whatsoever, fully covered by chest plate or thick tunic
- Slightly stockier build overall
- Costume sits flat and boxy on the torso

**[GIRL VARIANT]**
- Slightly narrower shoulders than boy variant but still athletic
- Flat chest — completely flat, no curve, no bust shape. The chest plate or thick padded tunic makes this area look identical to the boy variant.
- Costume fits closely but reads as athletic/adventurer, not fashion

Both variants: the child looking at this card should see a 10-11 year-old adventurer, not a teenager. No adult proportions.

### Hands and skin
- Hands are gloved or gauntleted — no bare skin below the neck on either variant
- Arms covered by costume sleeves

### Pose and tone
- Active but stable — the character is doing something related to their archetype power
- Facing viewer (front-facing or max 15° turn)
- Warm, empowering — the child should feel "I want to be that hero"
- No weapons, no blood, no fear, no threatening darkness

### Consistency across all 10 images
- Same art style, lighting logic, and color temperature
- Same face oval size, shape, position, and fill color
- Same body proportions (within each gender variant)
- Each archetype must be distinguishable by color scheme and environment alone at thumbnail size

---

## The 5 Archetypes

---

### Archetype 1: The Quiz Whiz
**Target filenames**: `clever_inventor_boy.jpg` / `clever_inventor_girl.jpg`

**Power**: Solves any quiz, puzzle, or brain teaser with clever thinking

**Hat**: Explorer's flat-cap with a pair of glowing tech goggles pushed up on the brim — covers all hair completely, no hair visible beneath the cap or behind the neck

**Pose**: Confident stance, one hand on hip, the other reaching out toward floating holographic puzzle pieces and glowing symbols

**Costume**: Smart explorer's vest in rich emerald green with golden geometric patterns, utility belt with small pouches (holding scrolls/tools), fingerless tech gloves with glowing circuit-line patterns

**Environment**: Ancient library meets futuristic lab — floating bookshelves, holographic star maps, warm amber lantern light mixing with cool blue puzzle-glow, stone archways with constellation carvings

**Magical effects**: Floating translucent puzzle pieces, glowing mathematical symbols and constellations orbiting the character, a soft golden "eureka" glow radiating from behind the face oval (not on it)

**Mood**: Clever, curious, confident — the smartest person in the room and they know it

---

### Archetype 2: The Master Creator
**Target filenames**: `gentle_dreamer_boy.jpg` / `gentle_dreamer_girl.jpg`

**Power**: Has a magic paintbrush that brings drawings to life

**Hat**: Wide-brimmed artist's hat in warm terracotta, slightly floppy, artfully spattered with paint — covers all hair completely, no hair visible at the brim or behind the neck

**Pose**: Mid-creation — holding a large ornate paintbrush in one hand, the other hand gesturing as painted creatures materialize from colorful paint strokes in the air

**Costume**: Artist's adventurer coat in warm sunset orange/coral, splattered artfully with rainbow paint drops, tool belt with paint vials, fully gloved hands

**Environment**: Magical art studio merged with a fantasy landscape — half the background is "real" (forest, sky) and half is being actively painted into existence with visible brush strokes, easels floating in the air

**Magical effects**: Ribbons of living paint flowing from the brush in rainbow colors, small painted butterflies and birds coming to life mid-flight, paint drops floating weightlessly, golden sparkles where paint meets reality

**Mood**: Creative, joyful, limitless — anything you imagine becomes real

---

### Archetype 3: The Lightning Runner
**Target filenames**: `speedy_explorer_boy.jpg` / `speedy_explorer_girl.jpg`

**Power**: Moves faster than sound and leaves trails of stardust

**Hat**: Sleek aerodynamic speed helmet in electric purple and silver with a visor pushed up — form-fitting, covers all hair completely, no hair visible at the back or sides of the neck

**Pose**: Dynamic running stance (one foot forward, leaning hard into speed), arms swept back, motion blur and speed lines suggesting incredible velocity — but the character's upper body and face oval remain sharp and clear

**Costume**: Sleek aerodynamic suit in electric purple and silver, glowing speed-line stripes down the arms and legs, lightweight armoured boots with wing motifs, short speed-cape trailing behind, fully gloved hands

**Environment**: Cosmic racetrack — running across a bridge of solidified starlight over a galaxy-filled void, planets in the distance, aurora-like colors streaking across the sky

**Magical effects**: Trail of golden stardust and tiny stars streaming behind the character, speed lines in electric blue, ground cracking with light under each footstep, small lightning bolts at the feet

**Mood**: Fast, thrilling, unstoppable — pure speed and freedom

---

### Archetype 4: The Animal Whisperer
**Target filenames**: `animal_whisperer_boy.jpg` / `animal_whisperer_girl.jpg`

**Power**: Talks to animals and moves unseen like a shadow through nature

**Hat**: A wide forest ranger's hat in dark green with a leather band and a small feather tucked into the band — brim is wide enough to cover all hair completely, no hair visible beneath the brim or at the back of the neck

**Pose**: Crouching slightly, one hand extended gently toward a small magical fox or owl companion that has approached them. The other hand rests on a mossy rock. Posture gentle and grounded.

**Costume**: Forest ranger's outfit in deep forest green and warm brown, leaf-pattern armour pieces, a hooded cloak (hood down, resting on shoulders — hood does NOT cover the hat), nature-themed accessories, vine-wrapped gauntlets on both hands (no bare skin)

**Environment**: Deep enchanted forest with massive ancient trees, bioluminescent mushrooms and plants, a hidden woodland clearing with dappled golden sunlight filtering through the canopy, a gentle stream nearby

**Magical effects**: Soft green nature-magic glow connecting the character's hand to the animal companion, tiny glowing nature spirits (like fireflies but more magical) floating around, leaves gently swirling in a magical updraft, faint animal silhouettes deeper in the forest

**Mood**: Gentle, connected, at home in nature — the forest trusts you

---

## Error Handling

| Problem | Fix |
|---------|-----|
| Facial features appear on the oval | Regenerate with: "The face is a BLANK, FEATURELESS, SMOOTH OVAL — like an unfinished mannequin head. Absolutely no eyes, nose, mouth, or any facial feature whatsoever." |
| Hair visible below/beside the hat | Regenerate with: "The hat covers ALL hair completely. There is ZERO visible hair on this character — not at the brim, not at the neck, not anywhere. No hair exists in this image." |
| Chest reads as female on boy variant | Regenerate with: "The chest is completely flat — no curve, no bust shape. The chest plate sits flat against a flat torso." |
| Chest reads as female on girl variant | Same as above — both variants have identical flat chest |
| Body reads as adult | Regenerate with: "The character is 10-11 years old. Athletic child proportions, not teenager or adult." |
| Tone feels dark or scary | Increase warm lighting, add more golden tones, reduce shadow contrast |
| Character too small | Zoom in so the character fills 60% of the canvas from mid-thigh up |
| Oval edges blend into hair or collar | Regenerate with hard-edged oval — "The oval has a clean, sharp edge. It does not fade or blend into the surrounding costume or hat." |

---

## File Naming Convention

```
assets/images/archetypes/adventurer/
  clever_inventor_boy.jpg
  clever_inventor_girl.jpg
  gentle_dreamer_boy.jpg
  gentle_dreamer_girl.jpg
  speedy_explorer_boy.jpg
  speedy_explorer_girl.jpg
  animal_whisperer_boy.jpg
  animal_whisperer_girl.jpg
```

> **Note**: The app currently uses `clever_inventor.jpg` (no gender suffix). The code in `archetype_card.dart` will need updating to append `_boy` or `_girl` based on the child's selected gender before these new files go live.
