# Story Weaver — GUI Age-Band Adaptation and Asset Generation Plan

## Document Purpose

This document serves as an execution plan for a CLI agent to audit the Story Weaver Flutter application and generate visual assets for every UI element that requires age-specific adaptation. Each asset entry includes a developmental rationale and a production-ready Nano Banana 2 image generation prompt.

## Model Configuration

**Image Engine:** Nano Banana 2
**Prompt Style:** Natural language sentences. Describe subject, style, lighting, mood, composition, and color in that order. Include negative guidance as explicit "do not include" or "avoid" directives. Always end with format and transparency instructions.
**Universal Safety Keywords:** child-safe, no violence, no frightening imagery, no darkness exceeding deep twilight, no adult themes, no photorealistic human faces
**Thematic Anchor Keywords:** magical, therapeutic, warm, inviting, empowering, wonder, personalized story

---

## Design System — Universal Constraints

These constraints apply to every asset regardless of age band.

- All interactive elements must maintain a minimum contrast ratio of 4.5:1 against their background.
- Buttons must have clearly legible labels with no ambiguity about their action.
- Decorative elements must never obstruct the active interaction zone.
- Color must never be the sole carrier of meaning; always pair with shape or label.
- No asset may feature photorealistic human or animal faces that could trigger uncanny valley responses in young children.
- All characters must use stylized, friendly proportions.

---

## Developmental Framework Summary

| Band | Age Range | Cognitive Stage | Visual Priority | Interaction Model |
|---|---|---|---|---|
| Toddlers | 2-4 | Pre-operational | Bold shapes, maximum contrast, minimal elements | Tap only, large targets |
| Early Readers | 5-7 | Early concrete | Storybook richness, clear narrative cues | Tap and simple gesture |
| Older Children | 8-12 | Concrete to early formal | Atmospheric depth, agency, detail reward | Full interaction, text entry |

---

## Age Band 1: Toddlers (2-4)

### Developmental Profile

Children aged 2-4 are in Piaget's pre-operational stage. They reason through images and direct sensory experience rather than logic. Visual processing favors high-contrast, large, isolated objects on uncluttered backgrounds. Attention spans are brief (2-5 minutes). Color carries strong emotional meaning: warm reds and oranges signal excitement and safety; soft yellows signal happiness; deep blues signal calm. Symbolic abstraction is emergent, not reliable. Faces and character expressions are the primary communication vehicle.

### Visual Theme

**Name:** Sunrise Toybox

Thick outlines, flat or very slightly raised textures resembling soft plush toys or foam blocks. Maximum 3-4 colors per asset. Characters have large round eyes and exaggerated smiles. Backgrounds are simple gradients from warm peach to soft sky blue. No gradients inside interactive elements — flat bold fills only. Typography, where present, uses ultra-rounded letterforms.

### Color Palette

- Primary: Golden Yellow `#FFD700`
- Secondary: Coral Pink `#FF6B6B`
- Accent: Sky Teal `#7ECECE`
- Background base: Warm Cream `#FFF8F0`
- Shadow: Soft Lavender `#D4C5F9`
- Text/outline: Deep Plum `#3D2C6E`

---

### Asset List and Prompts

#### Splash Screen Background

- **Element:** Full-screen background shown during app launch
- **Psychological intent:** Establish safety and delight immediately. The first image the child sees must be warm and welcoming without overwhelming.

```
Flat children's book digital illustration. A warm gradient sky background fading from soft golden peach at the bottom to pale lavender blue at the top. Centered in the composition is a large friendly glowing golden star shape with a gentle radial glow. Tiny rounded stars of soft yellow and white are scattered sparingly across the upper half. The lower edge has a gentle rolling hill silhouette in warm cream. No characters, no text, no complex detail. Maximum three colors. Full bleed portrait format. Transparent-safe edges. Do not include photorealistic textures, sharp edges, darkness, or anything frightening.
```

---

#### App Logo / Title Card

- **Element:** The Story Weaver wordmark and icon shown on the splash screen
- **Psychological intent:** Build brand recognition through a single memorable symbol. Children this age form strong associations with simple symbolic icons.

```
Flat children's book digital illustration. A wide horizontal badge design with a thick rounded plum-purple border on a warm cream background. Inside the badge, centered, is a large cartoonish open storybook with a glowing golden star bursting up from the pages. The book has thick rounded corners, a warm yellow cover, and visible illustrated stars on the open pages. The words STORY WEAVER appear in large ultra-rounded white letterforms with a gentle plum drop shadow below the book image. The overall shape is friendly and toy-like. Transparent background outside the badge border. Do not include thin lines, photorealistic elements, or multiple competing focal points.
```

---

#### Name Input Screen — Decorative Frame

- **Element:** The frame and decoration around the name text input field
- **Psychological intent:** Make the act of entering a name feel like a magical gift. The frame should signal that this space is special and personal.

```
Flat children's book digital illustration. A wide rounded rectangle frame designed to contain a text input field. The frame border is thick, bubbly, and golden yellow with a soft white inner highlight. Small sparkle star shapes are placed at each corner of the frame. The interior of the frame is a very soft translucent warm cream. The frame should feel like a gift tag or a golden ticket border. No text, no characters. Transparent background outside the frame. Do not include sharp lines, complex ornamentation, or more than three colors.
```

---

#### Age Selector Buttons — Individual Number Tiles (Ages 3-5)

- **Element:** Tappable large number tiles for the age selection screen
- **Psychological intent:** Numbers must be immediately recognizable. Each tile should feel like a toy block, giving the child tactile satisfaction from tapping.

```
Flat children's book digital illustration. A large square tile with very rounded corners resembling a soft foam toy block. The tile face is filled with a flat warm coral pink. A single large bold rounded numeral in white is centered on the face with a soft plum drop shadow. The tile has a subtle thick shadow on the bottom and right edges suggesting gentle depth, like a foam block sitting on a surface. No gradients on the face. Transparent background. One tile per prompt — generate separately for numerals 3, 4, and 5. Do not include decoration beyond the numeral, borders more than four pixels, or photorealistic textures.
```

---

#### Primary CTA Button — "MAKE MAGIC" (Normal State)

- **Element:** The main story-launch button shown on the magic review step
- **Psychological intent:** This button must generate excitement and a sense of magical possibility. The child needs to want to press it.

```
Flat children's book digital illustration. A very wide rounded rectangle button. The button face is filled with a flat warm golden yellow. A thick bubbly soft plum-purple border surrounds the button. The words MAKE MAGIC are written in large ultra-rounded bold white letters centered on the face with a gentle plum drop shadow. Three small cartoon sparkle star shapes float in the space around the letters, two to the left and one to the right. The overall impression is cheerful, safe, and exciting. Transparent background. Do not include gradients, photorealistic materials, or more than four visual elements on the face.
```

#### Primary CTA Button — "MAKE MAGIC" (Pressed State)

```
Flat children's book digital illustration. The same wide rounded-rectangle MAKE MAGIC button as the normal state, but the golden face is darkened by fifteen percent, the border becomes thinner and loses its outer glow, the sparkle stars are compressed inward toward the center, and the letters appear slightly smaller as if physically pressed down. An inner shadow replaces the outer border highlight. Transparent background.
```

---

#### Continue / Next Button

- **Element:** The forward navigation button appearing at the bottom of each wizard step
- **Psychological intent:** A right-pointing arrow is universally understood even before literacy. The button must be large enough to tap confidently.

```
Flat children's book digital illustration. A large rounded square button filled with flat sky teal. A large bold white right-pointing chevron arrow is centered on the face. The button has a thick soft plum shadow on the bottom and right edges. No text. The arrow is the only element. The entire composition is minimal and immediately readable. Transparent background. Do not include decorative elements, gradients, or secondary colors beyond teal, white, and the shadow.
```

---

#### Archetype Cards (Hero Types) — 6 Cards

Generate one card per archetype. Each card is a portrait-format rounded rectangle. The archetype list is: Brave Hero, Kind Healer, Clever Inventor, Speedy Explorer, Mighty Guardian, Gentle Dreamer.

- **Psychological intent:** Characters must be immediately identifiable by silhouette and one defining object. Children this age match imagery to known concepts; each archetype should evoke a familiar role without requiring reading.

```
[BRAVE HERO]
Flat children's book digital illustration. A portrait-format rounded rectangle card with a warm peach gradient background. Centered is a large simple cartoon character with an oversized round head, big joyful eyes, and a tiny body. The character wears a simple red cape and holds a small golden star-tipped wand. The character's pose is triumphant with arms raised. Below the character, a single bold rounded label reads BRAVE HERO in deep plum ultra-rounded text. A thick plum border surrounds the card. No background detail beyond the gradient. Transparent background outside the card border.
```

```
[KIND HEALER]
Flat children's book digital illustration. A portrait-format rounded rectangle card with a soft mint green gradient background. Centered is a large simple cartoon character with an oversized round head, soft gentle eyes, and a tiny body. The character wears a simple white tunic and holds a glowing golden heart. Small soft sparkle shapes float around the character. Below the character, a label reads KIND HEALER in deep plum ultra-rounded text. A thick plum border surrounds the card. No background detail beyond the gradient. Transparent background outside the card border.
```

```
[CLEVER INVENTOR]
Flat children's book digital illustration. A portrait-format rounded rectangle card with a warm sky blue gradient background. Centered is a large simple cartoon character with a big round head, wide curious eyes, small round glasses, and a tiny body. The character holds a large cartoonish golden gear shape. Below the character, a label reads CLEVER INVENTOR in deep plum ultra-rounded text. A thick plum border surrounds the card. No complex machinery or detailed background. Transparent background outside the card border.
```

```
[SPEEDY EXPLORER]
Flat children's book digital illustration. A portrait-format rounded rectangle card with a warm yellow gradient background. Centered is a large simple cartoon character with a big round head, bright eyes, and a tiny body in a simple green jacket and a wide-brimmed hat. The character holds a small golden compass. Below the character, a label reads SPEEDY EXPLORER in deep plum ultra-rounded text. A thick plum border surrounds the card. Transparent background outside the card border.
```

```
[MIGHTY GUARDIAN]
Flat children's book digital illustration. A portrait-format rounded rectangle card with a soft lavender gradient background. Centered is a large simple cartoon character with a big round head, strong determined eyes, and a tiny body holding a round rainbow-colored shield. The shield is flat and bold with simple concentric circles. Below the character, a label reads MIGHTY GUARDIAN in deep plum ultra-rounded text. A thick plum border surrounds the card. Transparent background outside the card border.
```

```
[GENTLE DREAMER]
Flat children's book digital illustration. A portrait-format rounded rectangle card with a soft pink-to-lavender gradient background. Centered is a large simple cartoon character with a big round head, dreamy half-closed eyes, and a tiny body holding a small glowing crescent moon. Tiny soft stars drift around the character. Below the character, a label reads GENTLE DREAMER in deep plum ultra-rounded text. A thick plum border surrounds the card. Transparent background outside the card border.
```

---

#### Feeling Selection Buttons (8 Core Emotions)

Emotions: Happy, Sad, Angry, Scared, Surprised, Calm, Excited, Confused

- **Psychological intent:** Emotion recognition is a core developmental milestone in the 2-4 range. Faces are the most reliable and appropriate vehicle. Each button must show the emotion unmistakably through the expression alone, not color alone.

```
[HAPPY]
Flat children's book digital illustration. A large circle button with a flat golden yellow background. Centered is a simple cartoon circular face with thick rounded plum eyes curved upward in a wide smile showing small rounded white teeth. Rosy pink circles on each cheek. The label HAPPY appears below the face in deep plum ultra-rounded bold text. Thick plum border around the circle. Transparent background outside the circle. Do not include body, hair, or accessories.
```

```
[SAD]
Flat children's book digital illustration. A large circle button with a flat soft blue background. Centered is a simple cartoon circular face with downward-curved plum eyebrows, closed downward-curved eyes, and a small downturned mouth. A single simplified teardrop shape rests on one cheek. The label SAD appears below the face. Thick plum border around the circle. Transparent background. Do not include frightening elements or exaggerated distress.
```

```
[ANGRY]
Flat children's book digital illustration. A large circle button with a flat warm orange background. Centered is a simple cartoon circular face with thick angled V-shaped plum eyebrows and a small tight-lipped frown. The expression reads as firmly grumpy, not threatening. The label ANGRY appears below the face. Thick plum border. Transparent background. Do not include any imagery that reads as violent or aggressive.
```

```
[SCARED]
Flat children's book digital illustration. A large circle button with a flat soft lavender background. Centered is a simple cartoon circular face with wide open circular eyes with small pupils, slightly raised eyebrows, and a small oval open mouth expressing surprise-fear. The expression should read as mild startled rather than terrified. The label SCARED appears below the face. Thick plum border. Transparent background. Do not include any horror elements, sharp shapes, or darkness.
```

```
[SURPRISED]
Flat children's book digital illustration. A large circle button with a flat sky teal background. Centered is a simple cartoon circular face with raised semicircle eyebrows and a large open circular mouth forming an O shape. Eyes are wide and circular. The label SURPRISED appears below the face. Thick plum border. Transparent background.
```

```
[CALM]
Flat children's book digital illustration. A large circle button with a flat soft mint green background. Centered is a simple cartoon circular face with gently closed or half-closed eyes, a soft relaxed slight smile, and smooth relaxed eyebrows. The face has a peaceful quality. The label CALM appears below the face. Thick plum border. Transparent background.
```

```
[EXCITED]
Flat children's book digital illustration. A large circle button with a flat coral pink background. Centered is a simple cartoon circular face with wide sparkly eyes showing small star highlights, raised eyebrows, and a very wide open smile. The entire face radiates energy. The label EXCITED appears below the face. Thick plum border. Transparent background.
```

```
[CONFUSED]
Flat children's book digital illustration. A large circle button with a flat warm yellow background. Centered is a simple cartoon circular face with one raised eyebrow and one lowered eyebrow, slightly tilted to one side, mouth in a small lopsided expression. A tiny simple question mark floats above the head. The label CONFUSED appears below the face. Thick plum border. Transparent background.
```

---

#### Progress Orb — Idle State

- **Element:** Step indicator orb shown in the wizard progress bar when a step is not yet reached
- **Psychological intent:** Must be clearly dim or passive so the child understands they have not yet reached this step. Not dark or frightening — neutral and waiting.

```
Flat children's book digital illustration. A perfect circle orb shape. The fill is a flat light lavender gray. The border is a thin soft plum outline. No glow, no shine, no sparkle. The orb reads as quiet and waiting. Transparent background. Do not include any texture, gradient, or detail.
```

#### Progress Orb — Active State

```
Flat children's book digital illustration. A perfect circle orb shape. The fill is a flat warm golden yellow. The border is a medium-weight plum outline. A single small white four-point star highlight sits in the upper-left quadrant of the orb face. The orb reads as currently active and glowing with warmth. Transparent background. Do not include complex gradients or multiple highlight points.
```

#### Progress Orb — Complete State

```
Flat children's book digital illustration. A perfect circle orb shape. The fill is a flat sky teal. A simple bold white checkmark is centered inside the orb. The border is a medium-weight plum outline. Two tiny white sparkle star shapes are placed outside the orb, one upper-right and one lower-left. Transparent background.
```

---

#### Story Page Background

- **Element:** The background texture behind story text on the reading screen
- **Psychological intent:** Must be calm and non-distracting. The story text is the foreground — the background must recede completely.

```
Flat children's book digital illustration. A full portrait-format background with a soft warm cream to pale peach gradient filling the entire frame from top to bottom. The very bottom edge has a soft rolling meadow silhouette in a slightly darker warm cream. The very top edge has three or four small simple five-pointed golden stars fading at low opacity. No characters, no complex elements, no text areas. The overall impression is a blank warm storybook page. Full bleed. Do not include patterns, textures, or anything that would compete with overlaid text.
```

---

#### Companion Character Cards — 4 Core Companions

Companions: Fluffy Dragon, Tiny Fairy, Magic Bunny, Shining Puppy

```
[FLUFFY DRAGON]
Flat children's book digital illustration. A portrait-format rounded rectangle card with a soft green gradient background. Centered is a large simple cartoon baby dragon with a round oversized head, big sweet eyes, tiny stubby wings, and a curly tail. The dragon is lavender-purple with soft green spots and a warm golden tummy. The dragon's expression is joyful and cuddly. Below the dragon, a label reads FLUFFY DRAGON in deep plum ultra-rounded text. A thick plum border surrounds the card. Transparent background outside the card.
```

```
[TINY FAIRY]
Flat children's book digital illustration. A portrait-format rounded rectangle card with a soft pink gradient background. Centered is a large simple cartoon fairy character with a big round head, huge sparkly eyes, simple rounded wings made of soft golden light, and a tiny body in a simple lavender dress. The fairy holds a small wand with a glowing star tip. Below the fairy, a label reads TINY FAIRY in deep plum ultra-rounded text. A thick plum border surrounds the card. Transparent background outside the card.
```

```
[MAGIC BUNNY]
Flat children's book digital illustration. A portrait-format rounded rectangle card with a soft sky blue gradient background. Centered is a large simple cartoon bunny with an oversized round head, enormous soft floppy ears, big gentle eyes, and a tiny round body in a simple golden vest. The bunny holds a tiny glowing crystal ball. Below the bunny, a label reads MAGIC BUNNY in deep plum ultra-rounded text. A thick plum border surrounds the card. Transparent background outside the card.
```

```
[SHINING PUPPY]
Flat children's book digital illustration. A portrait-format rounded rectangle card with a warm yellow gradient background. Centered is a large simple cartoon puppy with a big round head, floppy ears, enormous joyful eyes, and a small wagging tail. The puppy wears a simple teal bandana and has a glowing golden star on its forehead. Below the puppy, a label reads SHINING PUPPY in deep plum ultra-rounded text. A thick plum border surrounds the card. Transparent background outside the card.
```

---

#### Adventure Choice Buttons — Pick-a-Path Screen

- **Element:** The large tappable choice buttons that advance the interactive story
- **Psychological intent:** Choices must feel consequential and exciting but safe. Each button must read as an invitation, not a command.

```
Flat children's book digital illustration. A wide rounded rectangle button with a flat warm coral pink face. A simple relevant icon shape is centered on the left side of the button interior — use a small golden star icon as the placeholder. The right side of the button interior has space for text. A thick plum border surrounds the button. A soft plum shadow sits below the button suggesting it floats above the background. Transparent background. This is a template; generate the icon placeholder separately for each choice option.
```

---

## Age Band 2: Early Readers (5-7)

### Developmental Profile

Children aged 5-7 are transitioning into Piaget's concrete operational stage. They can follow sequential narratives, begin to recognize written words, and are capable of sustained engagement for 10-20 minutes with compelling content. Visual processing can handle moderate complexity: layered backgrounds, mild textures, and character designs with more anatomy detail are appropriate. Emotional intelligence has expanded to include secondary emotions (pride, embarrassment, jealousy). Fantasy and magical thinking peak at this stage; children this age have the highest intrinsic motivation for immersive magical worlds. Color can carry symbolic meaning. Characters with personality and implied backstory create stronger engagement than iconographic figures.

### Visual Theme

**Name:** Enchanted Storybook

Rounded but detailed. Painted-look children's book illustration with visible soft brushwork textures. Characters have expressive anatomy with implied warmth. Backgrounds have 2-3 depth layers (sky, midground, foreground silhouette). Gradients are welcome inside buttons as long as the color relationship is harmonious and does not reduce contrast below 4.5:1. Gold and deep violet dominate the interactive element palette. Magic is visible: light rays, sparkles, soft particle effects are encouraged as long as they do not obscure labels.

### Color Palette

- Primary: Deep Royal Violet `#4A1FA8`
- Secondary: Warm Enchanted Gold `#F4C430`
- Accent: Glowing Aqua `#40E0D0`
- Background base: Deep Indigo Night `#1A0A3C`
- Mid-layer: Twilight Blue-Purple `#2D1B69`
- Highlight: Soft Starlight White `#F0EFFF`
- Text: Warm White `#FFF9EC`

---

### Asset List and Prompts

#### Splash Screen Background

```
Enchanted storybook digital painting style. A full portrait-format background. The sky is a rich deep indigo fading down to a warm deep violet at the horizon. A large luminous full moon in soft ivory sits in the upper-center of the composition casting a wide silver-gold halo of light. The lower third of the composition has a silhouette of rolling enchanted hills covered in dark rounded tree shapes. Small soft glowing fireflies and floating star-dust particles are scattered across the midground. No characters. No text areas. The mood is magical, safe, and full of possibility. Full bleed. Do not include sharp edges, darkness exceeding deep twilight, or anything frightening.
```

---

#### Name Input Frame

```
Enchanted storybook digital painting style. A wide rounded rectangle frame for a text input field. The frame border is a decorative gold vine and leaf border with small glowing berries at the four corners. The border has a gentle golden shimmer effect with a soft inner white highlight. The interior of the frame is a translucent deep violet at low opacity so underlying content is visible. Small golden star particles float inside the frame interior. The overall feel is a magical parchment scroll border. Transparent background outside the frame. Do not include text, characters, or elements that obscure the interior typing area.
```

---

#### Age Selector Buttons (Ages 5-7)

```
Enchanted storybook digital painting style. A wide rounded rectangle button with a deep violet to rich purple gradient on the face. A decorative gold border frames the button with subtle knotwork corner details. A single large numeral in warm glowing gold is centered on the face with a soft radiant glow. The button has a gentle inner light suggesting it is lit from within. Transparent background. Generate separately for numerals 5, 6, and 7.
```

---

#### Primary CTA Button — "MAKE MAGIC" (Normal State)

```
Enchanted storybook digital painting style. A wide rounded rectangle button with a deep violet to warm purple gradient face. The border is a glowing gold decorative band with a subtle inner light. The words MAKE MAGIC are written in a slightly ornate but fully readable rounded-serif font in warm glowing gold with a soft white inner glow. A small glowing golden star appears at each end of the text. Tiny gold particle sparkles drift upward from the button surface. The button face has a subtle depth suggesting it is a polished magical surface. Transparent background. Do not include imagery that obscures the text.
```

#### Primary CTA Button — "MAKE MAGIC" (Pressed State)

```
Enchanted storybook digital painting style. The same MAKE MAGIC button as normal state. The gradient darkens to a deeper indigo. The gold border glow dims. The sparkle particles drop downward as if pulled by the press. The text appears slightly denser and the inner glow is dimmer. The overall impression is of energy being gathered rather than released. Transparent background.
```

---

#### Continue Button

```
Enchanted storybook digital painting style. A wide rounded rectangle button with a warm enchanted gold gradient face with a soft shimmer. The words CONTINUE appear in deep violet bold text centered on the face. A gold glowing right-pointing arrow appears to the right of the text. The button border is a thin refined gold line. Transparent background.
```

---

#### Archetype Cards (6 Hero Types)

Each card: portrait-format rounded rectangle with decorative border. Characters have more developed anatomy than the Toddler band — visible costume detail, expressive faces, implied narrative.

```
[BRAVE HERO]
Enchanted storybook digital painting style. A portrait-format rounded rectangle card. The background is a layered painted scene: a warm gold sky in the upper half, a dark forest silhouette in the lower third. Centered is a medium-sized illustrated child hero character wearing a flowing red cape, simple tunic, and holding a glowing golden sword pointing skyward. The character has a joyful determined expression. The card has a decorative gold vine border. A name plate at the bottom reads BRAVE HERO in gold text on a deep violet ribbon. Do not include realistic weapons or threatening imagery.
```

```
[KIND HEALER]
Enchanted storybook digital painting style. A portrait-format rounded rectangle card. Background is soft glowing forest clearing with warm golden light rays filtering through dark tree silhouettes. Centered is an illustrated child character in a simple white and gold healer's robe holding a glowing green lantern that radiates soft healing light. The expression is gentle and wise. Gold vine border. Name plate reads KIND HEALER. Transparent background outside the card.
```

```
[CLEVER INVENTOR]
Enchanted storybook digital painting style. A portrait-format rounded rectangle card. Background is a cozy workshop interior with warm amber light and soft shadow, illustrated loosely. Centered is an illustrated child character wearing small round goggles pushed up on the forehead and a vest with small pockets, holding an elaborate glowing mechanical device with gold gears visible. Expression is delighted curiosity. Gold vine border. Name plate reads CLEVER INVENTOR. Transparent background outside the card.
```

```
[SPEEDY EXPLORER]
Enchanted storybook digital painting style. A portrait-format rounded rectangle card. Background is illustrated rolling hills under a wide dusky sky. Centered is a child character in a practical explorer jacket and a wide-brimmed adventurer hat, holding an ornate compass that glows with soft blue light. Expression is eager and confident. Gold vine border. Name plate reads SPEEDY EXPLORER. Transparent background outside the card.
```

```
[MIGHTY GUARDIAN]
Enchanted storybook digital painting style. A portrait-format rounded rectangle card. Background is an illustrated stone archway at twilight. Centered is a child character in simple illustrated armor holding a large round shield decorated with a glowing golden sun emblem. Expression is calm and protective. Gold vine border. Name plate reads MIGHTY GUARDIAN. Transparent background outside the card.
```

```
[GENTLE DREAMER]
Enchanted storybook digital painting style. A portrait-format rounded rectangle card. Background is a soft painted night sky with a large luminous moon and scattered stars. Centered is a child character in flowing pajama-like robes sitting cross-legged and hovering slightly above the ground surrounded by glowing floating books and soft silver star particles. Expression is serene and wonder-filled. Gold vine border. Name plate reads GENTLE DREAMER. Transparent background outside the card.
```

---

#### Feeling Selection Buttons (8 Core Emotions)

At this age, facial expression is still primary but body language and symbolic color can reinforce the emotion.

```
[HAPPY]
Enchanted storybook digital painting style. A rounded rectangle button with a warm golden background. A small illustrated child face with an authentic wide smile, bright eyes, and rosy cheeks is centered on the upper half of the button. Below the face, the word HAPPY appears in deep violet rounded text. A small sun shape and two tiny star shapes float in the background. Soft painted texture on the background. Transparent background outside the button.
```

```
[SAD]
Enchanted storybook digital painting style. A rounded rectangle button with a muted cool blue background. A small illustrated child face with soft downcast eyes and a gentle frown, a single illustrated teardrop on one cheek. Below the face, the word SAD appears in deep violet text. A small illustrated rain cloud with a single drop floats in the corner. Transparent background outside the button.
```

```
[ANGRY]
Enchanted storybook digital painting style. A rounded rectangle button with a warm orange background. A small illustrated child face with clearly furrowed brows and a tight mouth expression. Below the face, the word ANGRY in deep violet text. A small illustrated flame shape in one corner, rendered as a soft warm glow rather than a fire. Transparent background outside the button.
```

```
[SCARED]
Enchanted storybook digital painting style. A rounded rectangle button with a soft lavender background. A small illustrated child face with wide eyes and a slightly open mouth in mild startled expression. Below, the word SCARED in deep violet text. A small illustrated ghost shape that is clearly friendly and round rather than frightening floats in the background. Transparent background outside the button.
```

```
[SURPRISED]
Enchanted storybook digital painting style. A rounded rectangle button with an aqua background. An illustrated child face with raised eyebrows and wide circular eyes with star highlights, open mouth in an O. Below, the word SURPRISED. Small confetti stars burst from behind the face. Transparent background outside the button.
```

```
[CALM]
Enchanted storybook digital painting style. A rounded rectangle button with a soft sage green background. An illustrated child face with gentle half-closed eyes and a soft relaxed expression. Below, the word CALM. A small illustrated crescent moon and two stars float serenely in the background. Transparent background outside the button.
```

```
[EXCITED]
Enchanted storybook digital painting style. A rounded rectangle button with a vibrant coral-to-gold gradient background. An illustrated child face with enormous sparkly eyes and a wide open triumphant smile. Below, the word EXCITED. Gold star bursts erupt from around the face. Transparent background outside the button.
```

```
[CONFUSED]
Enchanted storybook digital painting style. A rounded rectangle button with a warm yellow background. An illustrated child face with one raised brow, one lowered, slight tilt of the head. Below, the word CONFUSED. A soft illustrated question mark floats in a thought-bubble above the head. Transparent background outside the button.
```

---

#### Progress Orbs (Idle / Active / Complete)

```
[IDLE]
Enchanted storybook digital painting style. A circular orb with a dark translucent deep violet fill and a thin gold border. The interior has a faint soft glow at the very center as if a tiny ember of magic is sleeping inside. The orb reads as inactive but not dead. Transparent background.
```

```
[ACTIVE]
Enchanted storybook digital painting style. A circular orb filled with a rich violet-to-gold gradient radiating from the center outward. The border is a bright glowing gold band. Soft white particle sparkles drift outward from the orb surface. The interior has a bright luminous gold light source at the center. The orb clearly reads as active and energized. Transparent background.
```

```
[COMPLETE]
Enchanted storybook digital painting style. A circular orb filled with warm enchanted gold with a bright inner radiance. A white star checkmark symbol is centered inside the orb. The border glows softly gold. Two small gold sparkle stars are positioned outside the orb, one at the upper-right and one at the lower-left. Transparent background.
```

---

#### Story Page Background

```
Enchanted storybook digital painting style. A full portrait-format background meant to sit behind readable story text. The lower half is a warm deep parchment ivory with a very soft paper texture visible at low opacity. The upper half fades to a soft violet-indigo. The left edge has a very faint illustrated vertical vine border element that does not extend past thirty pixels in width. The right edge mirrors this. The center column, which is the text reading area, is completely clear and unobstructed. The mood is an open illuminated manuscript page. Full bleed. Do not include any pattern, character, or detail that would compete with overlaid text.
```

---

#### Companion Cards (4 Companions)

```
[STAR FOX]
Enchanted storybook digital painting style. A portrait-format rounded rectangle card. Background is a painted soft forest twilight. Centered is a sleek illustrated fox character with large expressive eyes, a soft golden coat, and a bushy tail tipped with a glowing star. The fox wears a simple travel cloak. Expression is clever and loyal. Decorative gold vine border. Name plate reads STAR FOX. Transparent background outside the card.
```

```
[MOON OWL]
Enchanted storybook digital painting style. A portrait-format card with a painted deep blue night sky background. Centered is a wise illustrated owl with large round luminous eyes, silver-white feathers with subtle blue highlights, and small glowing crescent moon shapes on the wing tips. Expression is warm and knowing. Gold vine border. Name plate reads MOON OWL. Transparent background outside the card.
```

```
[EMBER DRAGON]
Enchanted storybook digital painting style. A portrait-format card with a soft warm cave glow background. Centered is a small friendly illustrated dragon with a round head, large kind eyes, soft violet scales, and tiny wings. The dragon breathes a small puff of warm golden sparkles rather than fire. Expression is playful and loyal. Gold vine border. Name plate reads EMBER DRAGON. Transparent background outside card.
```

```
[BLOOM SPRITE]
Enchanted storybook digital painting style. A portrait-format card with a soft meadow at dawn background. Centered is a tiny illustrated sprite character, humanoid in proportion, with large transparent insect-like wings filled with soft rainbow iridescence, a flower-crown, and a small lantern of golden light. Expression is mischievous and warm. Gold vine border. Name plate reads BLOOM SPRITE. Transparent background outside card.
```

---

#### Scene Selection Cards (Location Tiles)

Four locations: Enchanted Forest, Cloud Castle, Ocean Depths, Star Village

```
[ENCHANTED FOREST]
Enchanted storybook digital painting style. A wide landscape-format card. The scene shows an atmospheric painted forest at magical twilight with dark rounded tree silhouettes, a pathway of soft golden light leading into the depth, and fireflies. The sky between the trees is violet-blue. The card has a decorative gold vine border. A name plate at the bottom reads ENCHANTED FOREST on a deep violet ribbon. Transparent background outside the card.
```

```
[CLOUD CASTLE]
Enchanted storybook digital painting style. A wide landscape-format card. A fantastical castle illustrated in white and pale gold sits on a bank of soft luminous clouds. The sky is a warm sunrise gradient of peach to violet. The castle towers have soft glowing windows. Card has a gold vine border. Name plate reads CLOUD CASTLE. Transparent background outside the card.
```

```
[OCEAN DEPTHS]
Enchanted storybook digital painting style. A wide landscape-format card. An underwater scene with warm luminous blue-teal water, rays of gold-tinted sunlight piercing the surface from above, gentle coral shapes at the bottom, and soft glowing jellyfish drifting in the midground. The mood is warm and mysterious, not dark. Gold vine border. Name plate reads OCEAN DEPTHS. Transparent background outside card.
```

```
[STAR VILLAGE]
Enchanted storybook digital painting style. A wide landscape-format card. A floating village of round illustrated cottages sits on a small asteroid or floating island surrounded by a deep cosmic sky full of soft glowing stars. Warm golden light emanates from the cottage windows. The palette is deep violet and warm gold. Gold vine border. Name plate reads STAR VILLAGE. Transparent background outside card.
```

---

## Age Band 3: Older Children (8-12)

### Developmental Profile

Children aged 8-12 span Piaget's concrete operational and early formal operational stages. They can reason abstractly, appreciate dramatic irony, and sustain focus for 30 or more minutes when intrinsically motivated. Visual processing can handle layered complexity, dynamic composition, stylized realism, and atmospheric depth. This age group strongly values agency, competence, and identity expression. They are sensitive to content that feels babyish and will disengage immediately if the aesthetic reads as patronizing. The appropriate visual register is closer to graphic novel, animated feature film, or illustrated YA novel than picture book. Magic and fantasy remain appealing but must feel earned and consequence-bearing. Dark atmospheric elements (deep shadows, contrast, minor peril suggestion) are developmentally appropriate within child-safe limits.

### Visual Theme

**Name:** Cosmic Chronicle

Cinematic digital illustration with visible depth-of-field suggestions, strong atmospheric perspective, and richly detailed environments. Characters have full expressive anatomy and visible individual personality. Color schemes use high contrast and controlled darkness — true black is permitted in non-interactive elements only. Gold shifts to electric gold and neon accents replace flat pastels. Typography for this band may use angular or serif letterforms that convey gravity and adventure.

### Color Palette

- Primary: Electric Midnight Blue `#0D1B4F`
- Secondary: Neon Gold `#FFB800`
- Accent: Cosmic Violet `#7B2FBE`
- Accent 2: Crystal Cyan `#00E5FF`
- Background deep: True Deep Space `#060814`
- Text/interactive labels: Clean White `#F5F5FF`
- Danger-adjacent accent (use sparingly): Ember Red `#FF4444`

---

### Asset List and Prompts

#### Splash Screen Background

```
Cinematic cosmic digital illustration. A full portrait-format background. The scene is a deep space view: a rich true-black background filled with a sweeping band of star clusters and a soft luminous nebula of electric violet and teal gas clouds that dominates the upper-right quadrant. In the center-lower area, the silhouette of a lone small island or floating landmass sits against the star field with warm amber-gold lights visible in tiny windows suggesting habitation. The composition has cinematic depth and atmosphere. No characters. Full bleed. Do not include anything frightening, violent, or excessively dark in the foreground. Child-safe cosmic imagery only.
```

---

#### Name Input Frame

```
Cinematic cosmic digital illustration. A wide horizontal frame designed to contain a text input field. The frame border is a thin crystalline edge rendered in electric crystal cyan with a subtle inner neon glow. The four corners have small diamond crystal fragment accent shapes. The interior of the frame is a deep midnight blue at low transparency. A very faint star field texture is visible inside the frame at minimal opacity. The frame reads as a high-technology interface built into a cosmic setting. Transparent background outside the frame. Do not include text, characters, or heavy decoration that obscures the input area.
```

---

#### Primary CTA Button — "START ADVENTURE" (Normal State, Ages 9-11)

```
Cinematic cosmic digital illustration. A wide sleek rounded rectangle button. The face has a deep midnight blue to cosmic violet gradient. A faint nebula texture of teal and violet gas drifts across the surface at low opacity. The border is a glowing crystalline edge in electric cyan. The words START ADVENTURE are rendered in a sharp clean sans-serif font, uppercase, in bright cyan-white with a subtle violet aura and a very faint drop shadow. Small diamond crystal fragments accent the left and right ends of the button. The button reads as powerful, modern, and cinematic. Transparent background. Do not include juvenile, whimsical, or babyish elements.
```

#### Primary CTA Button — "START ADVENTURE" (Pressed State)

```
Cinematic cosmic digital illustration. The same START ADVENTURE button as normal state. The nebula texture dims. The crystal border edges intensify their glow as if energy is concentrating inward. The text brightens momentarily as if compressed. A subtle inset shadow indicates the button surface has moved inward. The overall effect reads as controlled power being activated. Transparent background.
```

#### Primary CTA Button — "CREATE STORY" (Normal State, Ages 12+)

```
Cinematic cosmic digital illustration. A wide sleek button with a clean dark charcoal to deep midnight gradient face. The border is a thin refined neon gold line. The words CREATE STORY are set in a slightly editorial angular font in clean white. A small golden quill or pen icon appears to the left of the text. The button reads as sophisticated, creative, and mature. No sparkles, no glowing particles, no fantasy decoration. Transparent background.
```

---

#### Continue / Next Button

```
Cinematic cosmic digital illustration. A sleek rounded rectangle button with a deep midnight blue face and a thin crystal cyan border. A right-pointing angular arrow icon in bright crystal cyan is centered on the face. The button reads as a directional interface control. Clean and minimal. Transparent background.
```

---

#### Archetype Cards (6 Hero Types)

Full-figure character illustrations with environmental context. Characters have adult-proportioned posture of confident young adults but clearly read as older children or adolescents.

```
[BRAVE HERO]
Cinematic cosmic digital illustration. A portrait-format card. Background shows a dramatic cliffside at sunset with a rich orange-violet sky and a city silhouette in the deep background. The hero character stands in a three-quarter pose facing slightly left with a confident gaze, wearing a sleek styled jacket with a subtle glowing emblem, one hand holding a glowing energy sword pointing forward. The figure reads as powerful but fundamentally good. Dynamic lighting from the energy sword illuminates the face from below-right. Name plate at the bottom reads BRAVE HERO in neon gold on a dark band. No gore, no violence, child-safe heroic imagery.
```

```
[KIND HEALER]
Cinematic cosmic digital illustration. A portrait-format card. Background shows a softly lit medical grove with bioluminescent plants and warm golden mist. The healer character has a calm authoritative stance, wearing flowing robes with light-emitting rune stitching, hands open and emitting a visible warm golden healing aura. The face reads as compassionate and focused. Name plate reads KIND HEALER in neon gold. Transparent background outside card.
```

```
[CLEVER INVENTOR]
Cinematic cosmic digital illustration. A portrait-format card. Background is an atmospheric workshop filled with holographic projections and floating mechanical components. The inventor character leans forward with sharp curious eyes and a half-smile, wearing a detailed utility vest and goggles pushed up on the forehead. One hand holds a glowing holographic tool. Name plate reads CLEVER INVENTOR in neon gold. Transparent background outside card.
```

```
[SPEEDY EXPLORER]
Cinematic cosmic digital illustration. A portrait-format card. Background shows a vast alien landscape at dusk with multiple moons visible on the horizon. The explorer character stands mid-stride, wearing practical detailed gear with visible equipment, a map case over one shoulder, and a compass glowing with soft blue light in hand. The expression is confident and curious. Name plate reads SPEEDY EXPLORER in neon gold. Transparent background outside card.
```

```
[MIGHTY GUARDIAN]
Cinematic cosmic digital illustration. A portrait-format card. Background is a stone fortress entrance at night with torchlight. The guardian character stands in a wide protective stance in sleek detailed armor with a glowing shield emblem at the chest. Expression is calm and resolute. The armor has neon cyan edge lighting. Name plate reads MIGHTY GUARDIAN in neon gold. Transparent background outside card.
```

```
[GENTLE DREAMER]
Cinematic cosmic digital illustration. A portrait-format card. Background is a deep space library — floating bookshelves and open books with glowing pages drifting in zero gravity around the character. The dreamer character is seated cross-legged in mid-air, surrounded by orbiting books and soft silver light particles, wearing simple flowing clothes. Expression is serene and inwardly focused. Name plate reads GENTLE DREAMER in neon gold. Transparent background outside card.
```

---

#### Feeling Selection (Older Children Interface)

At this age, abstract visual metaphors can carry emotional weight alongside facial expressions.

```
[HAPPY]
Cinematic cosmic digital illustration. A rounded rectangle button with a warm amber-gold gradient. A stylized sun icon with a smiling face rendered in a clean graphic style dominates the upper half. Below, the word HAPPY in clean white sans-serif text. The sun has dynamic radiating lines suggesting energy. Transparent background outside the button.
```

```
[SAD]
Cinematic cosmic digital illustration. A rounded rectangle button with a muted cool indigo gradient. A stylized crescent moon with downcast eyes and a single architectural teardrop occupies the upper half. Below, the word SAD in clean white text. The atmosphere is contemplative, not distressing. Transparent background outside the button.
```

```
[ANGRY]
Cinematic cosmic digital illustration. A rounded rectangle button with a controlled ember-red to dark orange gradient. A stylized lightning bolt icon with a furrowed-brow face suggests contained energy. Below, the word ANGRY in clean white text. The imagery reads as power under control, not destructive. Transparent background outside button.
```

```
[SCARED]
Cinematic cosmic digital illustration. A rounded rectangle button with a dark violet to blue gradient. A stylized wide-eye icon with sharp geometric pupils on a slightly shadowed face. Below, the word SCARED in clean white text. The image reads as alert and heightened, not horror. Transparent background outside button.
```

```
[SURPRISED]
Cinematic cosmic digital illustration. A rounded rectangle button with a bright teal gradient. A stylized face icon with wide geometric eyes and an open mouth, surrounded by small starburst shapes. Below, SURPRISED in clean white text. Transparent background outside button.
```

```
[CALM]
Cinematic cosmic digital illustration. A rounded rectangle button with a deep ocean-teal gradient. A stylized face icon with closed eyes and a smooth relaxed expression, surrounded by soft concentric ripple lines like calm water. Below, the word CALM in clean white text. Transparent background outside button.
```

```
[EXCITED]
Cinematic cosmic digital illustration. A rounded rectangle button with a vibrant neon-gold to orange gradient. A stylized face icon with sharp dynamic eyes and an energized open expression, surrounded by radiating energy lines. Below, EXCITED in clean white text. Transparent background outside button.
```

```
[CONFUSED]
Cinematic cosmic digital illustration. A rounded rectangle button with a soft gray-blue gradient. A stylized face icon with asymmetrical brows and a question mark integrated into the composition as a design element. Below, the word CONFUSED in clean white text. Transparent background outside button.
```

---

#### Progress Orbs (Idle / Active / Complete)

```
[IDLE]
Cinematic cosmic digital illustration. A circular orb with a dark deep-space navy fill and a thin muted crystal cyan border. The interior shows a very faint central glow at minimal brightness. The orb reads as dormant but present. Transparent background.
```

```
[ACTIVE]
Cinematic cosmic digital illustration. A circular orb with a deep midnight blue to electric violet gradient radiating from the center. The border is a bright neon crystal cyan ring with a visible outer glow. Particle energy lines radiate from the surface. The orb reads as actively charged with power. Transparent background.
```

```
[COMPLETE]
Cinematic cosmic digital illustration. A circular orb with a rich neon gold fill and a strong inner luminous radiance. A sharp geometric checkmark in clean white is centered. The border is a bright gold ring. Small crystal shard fragments float around the outside of the orb. Transparent background.
```

---

#### Story Page Background

```
Cinematic cosmic digital illustration. A full portrait-format background for story reading. The background is a deep rich midnight blue that becomes gradually lighter toward the center to a softer deep navy in the reading zone. A subtle star field pattern is visible at very low opacity in the outermost margins only. The left and right margins at ten percent width each have a faint stylized vertical border suggesting aged parchment or stone engraving. The central eighty percent is entirely clear. Full bleed. Do not include any element that would compete with overlaid text at standard contrast.
```

---

#### Adventure Choice Buttons — Pick-a-Path Screen

```
Cinematic cosmic digital illustration. A wide rounded rectangle button with a deep midnight blue face and a thin crystal cyan border. On the left of the interior is a small diamond icon in neon gold. The right interior area is reserved for text content. The button has a subtle glossy surface treatment suggesting depth. A faint hover glow effect in cyan surrounds the border. Transparent background. The icon should be a generic placeholder diamond shape; the text content will be set programmatically.
```

---

#### Companion Cards (4 Companions)

```
[SHADOW LYNX]
Cinematic cosmic digital illustration. A portrait-format card with a deep forest at night background rendered with strong atmospheric depth. A sleek illustrated lynx character with luminous violet eyes and dark-tipped electric blue fur markings stands in a alert but non-threatening pose. The character has visible intelligence in the expression. Name plate reads SHADOW LYNX in neon gold. Transparent background outside card.
```

```
[IRON GOLEM]
Cinematic cosmic digital illustration. A portrait-format card with an industrial cavern background. A compact friendly golem character constructed of smooth stone and crystal with warm amber eyes glowing from within and soft gold light visible at the joints. The golem's posture is protective and solid. Expression reads as loyal and dependable. Name plate reads IRON GOLEM in neon gold. Transparent background outside card.
```

```
[STORM HAWK]
Cinematic cosmic digital illustration. A portrait-format card with a wide sky at storm-break background, dramatic light through cloud break. A large illustrated hawk with metallic blue-silver feathers, sharp intelligent eyes, and wingtips that crackle with very faint electrical energy markings. The hawk perches in a commanding pose. Name plate reads STORM HAWK in neon gold. Transparent background outside card.
```

```
[VOID SPRITE]
Cinematic cosmic digital illustration. A portrait-format card with a deep space background. A small ethereal humanoid figure made of cosmic material — soft translucent body containing visible star-maps under the skin, large dark eyes filled with stars, small pointed iridescent wings. The sprite floats and gestures toward the viewer in welcome. Name plate reads VOID SPRITE in neon gold. Transparent background outside card.
```

---

#### Scene Selection Cards (Location Tiles)

```
[RUINED CITADEL]
Cinematic cosmic digital illustration. A wide landscape card. A crumbling but magnificent ancient citadel stands against a dramatic twilight sky. Vines and bioluminescent moss grow across the stone. Warm amber light glows from inside archways suggesting habitation or mystery. The composition has strong cinematic depth. Name plate reads RUINED CITADEL in neon gold. No horror elements. Transparent background outside card.
```

```
[ORBITAL STATION]
Cinematic cosmic digital illustration. A wide landscape card. A sleek space station in low orbit with a planet visible below in warm blues and greens. Stars fill the background. Interior corridors visible through a glass window suggest activity and life. Name plate reads ORBITAL STATION in neon gold. Transparent background outside card.
```

```
[DEEP ARCHIVE]
Cinematic cosmic digital illustration. A wide landscape card. An impossibly large underground library with vaulted ceilings disappearing into darkness above, stacked with illuminated bookshelves, floating glowing manuscripts, and a central reading table with a warm light source. The atmosphere is awe-inspiring and quiet. Name plate reads DEEP ARCHIVE in neon gold. Transparent background outside card.
```

```
[TIDAL SHRINE]
Cinematic cosmic digital illustration. A wide landscape card. An ancient shrine built on a sea stack surrounded by dramatic ocean with waves breaking at the base. The shrine glows with warm internal light. A bioluminescent ocean with soft coral light and moonlight provides atmospheric depth. Name plate reads TIDAL SHRINE in neon gold. Transparent background outside card.
```

---

## Cross-Band Universal Assets

Some elements maintain a consistent design across all age bands with only minor tonal variation. These should be generated once and used globally.

### Loading Indicator — Story Generation

```
Flat to semi-illustrated animation frame set. A circular progress indicator designed as a glowing golden constellation ring. Twelve equally spaced small star points sit on the ring, which fills clockwise as loading progresses. The inner space of the ring shows the Story Weaver logomark as a small storybook icon in gold. The background is transparent. Generate as a single frame showing the full ring at approximately sixty percent fill for use as a static preview asset. The design must read clearly at 80x80 pixels. Transparent background.
```

### Voice / Audio Active Indicator

```
Flat digital illustration. A small square icon tile. The tile face shows three smooth vertical bars of increasing height, center-aligned, in glowing gold against a deep violet background. The bars represent audio waveform activity. The icon reads immediately as audio or voice is active. No text. Transparent background outside the tile. Design must be readable at 24x24 pixels.
```

### Microphone / Voice Input Button

```
Flat digital illustration. A circular icon button. The face shows a simple bold microphone silhouette in clean white centered on a golden yellow circle background. The microphone shape has a thick stem and a rounded top with visible vertical grille lines. The icon must be immediately recognizable as a voice input control. Transparent background outside the circle. Readable at 48x48 pixels minimum.
```

---

## Execution Checklist

An automated CLI agent executing this plan should process assets in the following order:

1. Generate all Splash Screen backgrounds for all three bands.
2. Generate all CTA buttons (normal and pressed states) for all three bands.
3. Generate all Continue and navigation buttons for all three bands.
4. Generate all Progress Orbs (Idle, Active, Complete) for all three bands.
5. Generate all 6 Archetype Cards for each band (18 card images total).
6. Generate all 8 Feeling Selection Buttons for each band (24 button images total).
7. Generate all 4 Companion Cards for each band (12 card images total).
8. Generate all 4 Scene Selection Cards for each band (12 card images total).
9. Generate Story Page Backgrounds for all three bands.
10. Generate Name Input Frames for all three bands.
11. Generate Age Selector Buttons for each band's specific age range.
12. Generate all Cross-Band Universal Assets once.
13. Verify all outputs against contrast ratio requirements.
14. Verify no asset contains photorealistic faces, violence, or content inappropriate for its assigned age band.

**Total unique asset prompts in this document: 127**
