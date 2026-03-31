# Feelings Asset Redesign — Adolescent & Adult Therapeutic Illustration System

**Date:** 2026-03-31
**Scope:** 27 images across three asset sets
**Author:** Visual Design Direction (Claude Sonnet 4.6)

---

## Table of Contents

1. [Asset Audit](#1-asset-audit)
2. [Style Exploration](#2-style-exploration)
3. [Art Direction Briefs](#3-art-direction-briefs)
4. [Color Palette](#4-color-palette)
5. [Character Representation Rules](#5-character-representation-rules)
6. [Per-Image Direction](#6-per-image-direction)
7. [Generation Prompts](#7-generation-prompts)
8. [Quality Gates](#8-quality-gates)
9. [Naming Convention](#9-naming-convention)

---

## 1. Asset Audit

### 1.1 Set 1 — Global Fallbacks (`assets/feelings_faces/`)

**7 images in scope:** anticipation, contentment, dread, envious, indignation, melancholy, restless

**Style description:** Traced outline illustration style — black or dark line contours of a cartoon face, minimal interior detail, white or lightly filled background.

**Specific failures:**

- **Clip art register.** Traced face outlines with no body language read as 1990s clipart. At therapeutic context they undermine credibility — they look like a worksheet handout, not a considered product.
- **No body language.** Emotion at thumbnail scale is carried by posture, not subtle facial micro-expression. Face-only compositions fail the 3-second test for nuanced emotions (melancholy vs. sadness, anticipation vs. excitement cannot be distinguished from face alone at 48px).
- **Emotional flattening.** Traced outlines impose a visual sameness across all feelings. Grief looks like the same weight as impatience. The style erases the emotional texture of the vocabulary.
- **No warmth signal.** Pure line on white has no temperature, no invitation. It reports an emotion rather than reflecting it back to the user.
- **Scale degradation.** Line-only faces lose legibility at small sizes. The eye must decode contour lines, which demands cognitive work the user hasn't consented to give.

---

### 1.2 Set 2 — Adolescent (`assets/images/feelings/adolescent/`)

**10 images in scope:** anticipation, contentment, dread, envious, grief, hopeful, indignation, melancholy, resentful, restless

**Style description:** Teal cinematic silhouette — dark figure against a cool teal/blue background, no facial detail, photographic or near-photographic rendering of light and shadow.

**Specific failures:**

- **Wrong emotional temperature.** Cool teal reads as clinical, hospital, institutional. Adolescents in therapeutic contexts are already anxious about being pathologized. A cool-toned style confirms their worst fears about how adults see them.
- **Zero facial legibility.** Silhouettes have no face. The 3-second test fails absolutely for any emotion that requires reading expression. melancholy, contentment, and hopeful are indistinguishable at thumbnail scale.
- **Emotional conflation.** Dark silhouettes on dark backgrounds make most difficult emotions (grief, dread, resentful) look identical. There is no visual vocabulary to distinguish them.
- **No identifiability.** Adolescents need to see themselves in these images. A featureless dark shape provides no projection surface. It is alienating rather than relatable.
- **Cinematic coldness at the wrong moment.** "Cinematic" as an aesthetic signals spectacle and distance. Therapeutic imagery requires intimacy and presence. The style is asking the user to observe emotion rather than recognize it in themselves.
- **Style mismatch with known adolescent media preferences.** Adolescents in 2024-2026 choose Webtoon, graphic novel, and stylized character art as their default aesthetic register. Teal silhouette photography has no relationship to any medium they consume by choice.

---

### 1.3 Set 3 — Adult (`assets/images/feelings/adult/`)

**10 images in scope:** anticipation, contentment, dread, envious, grief, hopeful, indignation, melancholy, resentful, restless

**Style description:** Amber-gold refined figure style — warm amber palette, photorealistic or near-photorealistic rendering of human figures, refined/polished post-processing.

**Specific failures:**

- **Photo-realism prevents projection.** When a specific person's face appears on screen, the user is forced to assess whether they identify with that person. In a therapeutic context, this creates a barrier rather than an opening. The user is asking about their own feelings; the response should invite self-recognition, not introduce a third party.
- **Amber monoculture.** Warm amber works for contentment and anticipation. It works against grief, dread, indignation, and resentful. The palette imposes a tonal warmth that trivializes heavy emotional states — grief in golden amber light reads as elegiac or even romanticized rather than compassionate.
- **Corporate polish.** "Refined" photographic style reads as a stock photo library or a wellness brand whose primary demographic is executive coaches. For adults in a vulnerable emotional moment, this aesthetic signals performance and aspiration, not safety.
- **AI photo-realism inconsistency.** When generated at scale, photo-realistic diverse human faces will show inconsistency in rendering quality, skin tone handling, and feature coherence. The set will look uneven across images, which undermines confidence in the product.
- **Scale fails.** Photorealistic face detail disappears at 48px thumbnail. The result is a blurry human face, which at small size reads as disconcerting rather than inviting.

---

## 2. Style Exploration

### 2.1 Set 1 — Global Fallbacks: Candidate Styles

The global fallback set must work across all six age bands as a universal fallback. It must feel welcoming to an 8-year-old Explorer without feeling infantilizing to a 35-year-old Adult. This constraint pushes toward higher abstraction and body-language-over-face emphasis.

| Style | Reference | Identifiability | Emotional Clarity | Warmth | Maturity | Delight | Total |
|-------|-----------|:-:|:-:|:-:|:-:|:-:|:-:|
| **A. Soft Geometric Character** | Headspace app, Calm app, Duolingo character studies | 4 | 4 | 5 | 3 | 4 | 20 |
| **B. Contemporary Flat Editorial** | Mailchimp/Stripe editorial, Olimpia Zagnoli | 3 | 4 | 3 | 4 | 4 | 18 |
| **C. Abstract Environmental Metaphor** | Oliver Jeffers, Lane Smith | 2 | 3 | 4 | 4 | 4 | DISCARD |

**Style C discarded:** identifiability score of 2 (no character to project onto) fails the minimum threshold.

**Style B concern:** warmth scores 3 — flat editorial tends toward cool, sharp geometry. Passes the threshold but does not thrive in a therapeutic context.

**Winner: Style A — Soft Geometric Character.** Highest warmth. Universally age-bridging through abstraction. Body language readable at small scale because the simplified form exaggerates posture over detail. The maturity score of 3 is the risk — mitigated by keeping the character proportions adult-adjacent (no oversized heads or round baby shapes) and using a muted, sophisticated palette rather than primary colors.

**Maturity-Delight Matrix position:** Warm and mildly playful — center-left of the target zone. Close to the "slightly-serious" border, which is exactly right for a universal fallback.

---

### 2.2 Set 2 — Adolescent: Candidate Styles

Perspective triangulation requirement: the 14-year-old test is the hardest constraint here. A style that would embarrass the user is disqualifying regardless of other scores.

| Style | Reference | Identifiability | Emotional Clarity | Warmth | Maturity | Delight | Total |
|-------|-----------|:-:|:-:|:-:|:-:|:-:|:-:|
| **A. Webtoon-Influenced Expressive Character** | Lore Olympus, Heartstopper, Webtoon aesthetics | 5 | 5 | 4 | 4 | 5 | 23 |
| **B. Procreate Editorial / Indie Illustration** | Studio Yotta, Loish, indie character illustration | 4 | 4 | 5 | 4 | 4 | 21 |
| **C. Bold Geometric Character** | Steven Universe (mature episodes), Adventure Time | 3 | 4 | 4 | 3 | 4 | 18 |

**Style C concern:** maturity score of 3 is marginal. The geometric cartoon register is too closely associated with children's animation for a 15-17 year old. Passes threshold but is excluded on the 14-year-old test.

**Winner: Style A — Webtoon-Influenced Expressive Character.** This is the aesthetic register adolescents actively choose when consuming media unprompted. It is taken seriously in their cultural context. Large, expressive eyes carry emotional nuance at small scale better than any other format. Clean digital linework reads crisply on mobile. The warm ink-fill approach avoids both the cold silhouette failure and the babyish cartoon failure.

**Key differentiation from children's illustration:** proportion choices (not chibi, not exaggerated baby-faces), color palette (saturated but not primary, with darker shadow tones), and emotional weight in the imagery (adolescent webtoon handles grief, longing, and anger with seriousness).

**Maturity-Delight Matrix position:** Warm and moderately playful — fully in the target zone, slightly toward the playful side but anchored by emotional subject matter.

---

### 2.3 Set 3 — Adult: Candidate Styles

The adult test: would an adult therapist recommend this app to a client without embarrassment? Would a client feel respected rather than managed?

| Style | Reference | Identifiability | Emotional Clarity | Warmth | Maturity | Delight | Total |
|-------|-----------|:-:|:-:|:-:|:-:|:-:|:-:|
| **A. Warm Abstract Editorial** | Olimpia Zagnoli, Marion Barraud, New Yorker spot illustration | 3 | 5 | 4 | 5 | 4 | 21 |
| **B. Gentle Folk-Art Character** | Rifle Paper Co. editorial, Tara Whittaker, Ghibli design language | 4 | 4 | 5 | 4 | 4 | 21 |
| **C. Mindful App Soft Gradient** | Calm, Insight Timer, Balance app | 3 | 3 | 5 | 4 | 3 | 18 |

**Style C concern:** emotional clarity scores 3 and delight scores 3. Soft gradient style is the dominant aesthetic in the wellness space, which means it reads as generic. It also fails to differentiate between emotional states at small scale. Excluded.

**Style A vs. Style B are tied.** Both score 21. Resolution: A hybrid. Style A provides the compositional sophistication and color economy of editorial illustration. Style B provides the warmth, posture emphasis, and organic figure quality needed for therapeutic safety. The hybrid takes A's palette restraint and compositional thinking alongside B's character warmth and body-language emphasis.

**Winner: Hybrid — "Warm Editorial Character."** Compositional discipline and sophisticated color restraint from the editorial tradition; figure warmth, posture-over-face expressiveness, and approachability from the folk-art tradition. The result is an illustration style that would be at home in a thoughtful magazine like The Sun or Emergence, not a corporate wellness platform.

**Maturity-Delight Matrix position:** Warm and slightly serious — center-right of the target zone, appropriate for adults in a reflective or vulnerable state.

---

## 3. Art Direction Briefs

### 3.1 Set 1 — Global Fallbacks: Soft Geometric Character

- **Style Name:** Soft Geometric Character
- **Visual References:** Headspace app character illustration (2018-2021 era, before the 2022 rebrand), Calm app season illustrations, early Duolingo character studies
- **Color Palette:**
  - Background: `#F5EFE6` (warm cream)
  - Character base: `#C49A6C` (medium warm mocha — default skin analog that reads as neither racially specific nor ghostly)
  - Character shadow: `#8A6245` (warm umber)
  - Per-feeling accent: see per-image direction table
- **Line Treatment:** Soft closed outlines, `1.5px` visual equivalent, warm brown rather than black (`#5C3D2E`). Lines slightly softer at edges — not crisp digital vector, closer to a fine felt-tip on warm paper.
- **Character Abstraction Level:** Round-ish simplified body with clear limb differentiation. Head proportions close to adult (not oversized). Face has minimal but legible features: two dot or almond eyes, simple mouth line, no nose detail required. No hair texture — hair is a solid shape. Think Headspace level of simplification, not blobfish level.
- **Emotional Expression Method:** 70% body language, 30% facial expression. The character's posture, limb position, and relationship to the frame carry the primary emotional signal. Facial expression confirms but does not carry the read alone.
- **Background Treatment:** Single warm neutral tone with a subtle radial gradient toward slightly cooler at edges. Optional: a single low-detail environmental element (a cup, a window frame, a plant edge) for grounding. No busy backgrounds, no complex scenes.

---

### 3.2 Set 2 — Adolescent: Webtoon-Influenced Expressive Character

- **Style Name:** Webtoon Expressive Character
- **Visual References:** Lore Olympus color palettes (Rachel Smythe), Heartstopper emotional scene composition (Alice Oseman graphic novel), the Webtoon platform's prevalent style for contemporary teen drama
- **Color Palette:**
  - Background: `#F0EBF8` (soft lavender-cream)
  - Character line: `#2C1A3A` (deep warm plum, not pure black)
  - Character fills: varied warm skin tone options rendered as flat fills with 1-2 shadow planes
  - Per-feeling accent: see per-image direction table
- **Line Treatment:** Clean digital linework, consistent weight `2px` equivalent, confidently drawn — no scratchy or uncertain lines. Slight weight variation at joints and expressive points. The line has energy and intention.
- **Character Abstraction Level:** Semi-realistic adolescent proportions with intentionally expressive eyes (larger than realistic, clear iris and highlight). Faces have enough detail to carry expression clearly — eyebrow shape matters here. Body is simplified but reads as genuinely teenage, not a child or adult. Character can be any gender presentation.
- **Emotional Expression Method:** Equal weight: 50% face (eyes and brows primary), 50% body language. In this style, the eyes are the emotional anchor. Body language provides context and prevents ambiguity between similar emotions.
- **Background Treatment:** Loose, impressionistic environment — a suggestion of location rather than a detailed scene. Two or three color shapes that establish context without demanding attention. The character is always the clear focal point. For difficult emotions (grief, dread), background color desaturates toward the edges. For positive emotions (hopeful, anticipation), background gains warmth toward the light source.

---

### 3.3 Set 3 — Adult: Warm Editorial Character

- **Style Name:** Warm Editorial Character
- **Visual References:** Olimpia Zagnoli (compositional restraint, color blocking), Marion Barraud (character warmth, intimate posture), The Sun magazine illustration sensibility (emotional depth without sentimentality)
- **Color Palette:**
  - Background: `#EDE8E3` (warm greige — slightly warmer than neutral gray, slightly cooler than cream)
  - Character: abstracted, lean toward a muted warm tone rather than specific skin representation — `#B08060` base with `#7A5030` shadow
  - Per-feeling accent: see per-image direction table — adult palette uses richer, more muted accents than adolescent
- **Line Treatment:** Optional or minimal. This style can be largely lineless — color shapes define the figure. Where lines appear, they are confident and deliberate: single-weight, warm brown or match the dominant color of the scene. Not an outline style.
- **Character Abstraction Level:** Higher abstraction than adolescent set — faces may be suggested rather than fully rendered. A figure seen from behind, or in three-quarter view with simplified features, is preferable to a frontal face with detailed rendering. The emotional content should be available to the viewer without requiring them to read someone else's specific expression. Body gesture, posture, and relationship to the environment carry the full weight.
- **Emotional Expression Method:** 80% body language and environmental relationship, 20% facial expression (when face is visible at all). The figure's position in the frame, their relationship to light, and what their body is doing with space tell the story.
- **Background Treatment:** Environmental context is more developed than the other sets — a room corner, a window with light, a table with objects. These environments are spare and graphic, not photorealistic. They give the adult character a world that feels real and lived-in. Color relationships between character and environment carry the emotional meaning.

---

## 4. Color Palette

### 4.1 Shared DNA

All three sets share:

- Warm base temperature. No image in any set should have a cool-dominant background.
- Muted, slightly desaturated mid-tones as the dominant ground color. Pure white backgrounds are excluded.
- A single deliberate accent color per image that carries the emotional signal.
- Shadow tones that are warm (brown or purple-adjacent), never cool-gray.

```
SHARED BASE COLORS
Background cream (global):     #F5EFE6
Background lavender (adolesc): #F0EBF8
Background greige (adult):     #EDE8E3

Character warm mid:            #C49A6C
Character warm shadow:         #8A6245
Character muted abstract:      #B08060  (adult set)

Shared shadow tone:            #5C3D2E  (warm dark brown — replaces black)
```

### 4.2 Per-Feeling Accent Colors

These accent colors are applied to the dominant emotional light source, clothing, or environmental detail in each image. They are the same across bands to create cross-set cohesion, but may be used at different saturations (more saturated in adolescent set, more muted in adult set).

```
FEELING ACCENT COLORS
anticipation:   #F5A623  (warm amber — forward-reaching energy)
contentment:    #A8C5A0  (sage green — settled, organic, at rest)
dread:          #7B7FA8  (muted indigo — threat without aggression)
envious:        #5FA888  (teal-green — "green with envy" without being clichéd)
grief:          #8B9CC4  (soft periwinkle — sadness that has settled into stillness)
hopeful:        #F5C842  (warm yellow — aspirational, forward light)
indignation:    #D4845A  (terracotta — heat without aggression)
melancholy:     #8FAFC4  (dusty blue — wistfulness, not despair)
resentful:      #C17C6B  (muted rose-terracotta — contained, inward heat)
restless:       #E8A87C  (warm peach — kinetic, unsettled warmth)
```

### 4.3 Per-Band Saturation Rules

```
GLOBAL FALLBACKS: Use accent colors at 70% saturation. The universality
requirement means no color should feel "too intense" for any age band.

ADOLESCENT SET: Use accent colors at 90–100% saturation. The webtoon
aesthetic welcomes vibrant color. Dark color shadows on character and
background are acceptable and expected.

ADULT SET: Use accent colors at 50–65% saturation. Richer, more muted.
The accent color should feel like it belongs to a considered palette,
not a pop-art poster.
```

---

## 5. Character Representation Rules

### 5.1 Diversity

- **Do not depict a single ethnicity across all images.** Within each set of 7–10 images, vary the implied skin tone of the character using the warm-toned fill approach. Since the style uses abstracted warm fills rather than photo-realistic rendering, this can be achieved by varying the base fill between `#E8C9A0` (light), `#C49A6C` (medium), `#8A5C38` (deep warm), and `#5C3020` (deep cool) without requiring photorealistic feature detail.
- **Do not assign genders to emotions.** Characters should not default to "girl feels sad, boy feels angry." Vary gender presentation across the set, and include androgynous and gender-neutral presentations. In the webtoon style, hairstyle and clothing silhouette carry gender signal — these can be deliberately ambiguous or explicitly varied.
- **Body diversity is secondary to emotional clarity** at thumbnail scale, but avoid a single slim adult figure archetype across all 27 images.

### 5.2 Abstraction as Ally

At the abstraction levels specified in each brief, diversity and universality are not in conflict. A figure with simplified features and a warm-toned fill reads as "a person" rather than "a specific person." The viewer projects their own identity onto the figure. This is preferable in a therapeutic context to either high realism (which forces identification with a specific face) or complete featurelessness (which provides no projection surface).

**The target abstraction level:** a character that a user can mentally inhabit as their own avatar within 2 seconds.

### 5.3 Body Language Principles

- **Closed postures** (arms in, shoulders forward, head down) signal difficult emotional states: grief, dread, resentful, melancholy.
- **Open postures** (chest open, chin up, arms available) signal positive or energized states: hopeful, anticipation, contentment, indignation (a specific form of open — upright and assertive).
- **Active postures** (mid-motion, weight shift implied) signal kinetic states: restless, excitement, anticipation.
- **Still postures** (settled, weight into ground or furniture) signal reflective states: contentment, melancholy, grief.
- **Averted gaze** signals relational discomfort: envious, resentful, indignation (when combined with upright posture).
- **Direct gaze at viewer** signals a confrontational or assertive emotional state: indignation, hurt, sometimes grief.

### 5.4 Disambiguation Rules

The following pairs are easily confused at thumbnail scale and require additional visual cues:

| Pair | Distinguishing Cue |
|------|--------------------|
| contentment vs. boredom | Contentment: active soft smile + warm even light source. Boredom: flat affect + neutral or slightly cool light. |
| melancholy vs. sadness | Melancholy: figure looking away toward diffuse light, wistful. Sadness: figure looking down, acute weight. |
| anticipation vs. excitement | Anticipation: leaning forward with slight tension, hands gathered. Excitement: open chest, raised or outward hands. |
| dread vs. fear | Dread: static, pulled inward, looking toward the threat. Fear: recoil gesture, wide eyes, slight backward lean. |
| restless vs. anxious | Restless: implied motion, about to move. Anxious: frozen in place, inward tension. |
| resentful vs. angry | Resentful: arms crossed or held, averted gaze, contained. Angry: open confrontational posture, direct gaze. |
| indignation vs. anger | Indignation: upright and composed, chin raised, controlled. Anger: outward, less controlled. |
| grief vs. sadness | Grief: collapsed or held stillness, full-body weight. Sadness: upright but heavy, tears or downward gaze. |
| hopeful vs. happy | Hopeful: forward orientation toward a light source, small contemplative smile. Happy: open and present, not directed forward. |
| envious vs. jealous | Envious: sideways attention, the object of desire is off-screen or framed through a window. Jealous: more confrontational, directed at a second character. |

---

## 6. Per-Image Direction

### 6.1 Set 1 — Global Fallbacks (7 images)

Style: Soft Geometric Character. Background: `#F5EFE6`. Abstraction: Headspace-level simplification.

| Feeling | Visual Direction | Key Accent | Body Language Note | Disambiguation |
|---------|-----------------|------------|-------------------|----------------|
| anticipation | Figure perched on the edge of a surface, weight forward on toes, hands clasped together, eyes wide and bright, warm amber glow from off-screen ahead | `#F5A623` | Weight shifted to front of seat; edge of frame catches the warm light | Forward lean + hand clasp distinguishes from excitement (which has open, out-reaching energy) |
| contentment | Figure seated in relaxed pose, eyes softly closed or half-open in quiet pleasure, slight upturned smile, a simple warm object (cup, blanket edge) within reach | `#A8C5A0` | Weight fully into the surface; shoulders dropped and wide; no active reaching | Warmth and settled stillness distinguishes from boredom (flat affect, no warmth signal) |
| dread | Figure standing or seated slightly smaller in frame than usual, shoulders raised toward ears, eyes looking toward lower-left as if tracking something unseen, color desaturates at edges | `#7B7FA8` | Pulled inward without collapsing; feet planted — frozen rather than retreating | Static quality distinguishes from fear (which shows recoil) |
| envious | Figure in three-quarter profile, gaze cut sideways toward the edge of the frame, expression tight and controlled, one hand at chin or jaw | `#5FA888` | Weight evenly placed but attention wholly diverted to off-screen subject | Sideways attention to an absent subject distinguishes from jealousy (which has a second character present) |
| indignation | Figure upright with deliberately raised chin, brow furrowed, mouth set, arms either crossed or hands at sides — not raised, not aggressive | `#D4845A` | Chest open and elevated; a posture of being right, not of being out of control | Upright composure distinguishes from anger; chin-up pride distinguishes from resentful (which has averted gaze) |
| melancholy | Figure in three-quarter view, gaze directed toward a soft diffuse light source off-screen, expression neutral-to-wistful, slight downward set of mouth | `#8FAFC4` | Neither collapsed nor upright; a middle stillness; one hand may rest near face | Reflective outward gaze distinguishes from sadness (which looks down); wistfulness distinguishes from grief (which collapses) |
| restless | Figure mid-motion or with implied multiple positions, hand on knee or arm of chair, weight shifted as if about to stand, slight motion impression in limbs | `#E8A87C` | No settled weight — kinetic and unresolved | Active energy distinguishes from anxious (which is frozen); warmth of palette distinguishes from fear |

---

### 6.2 Set 2 — Adolescent (10 images)

Style: Webtoon Expressive Character. Background: `#F0EBF8`. Lines: `2px` warm plum. Large expressive eyes.

| Feeling | Visual Direction | Key Accent | Body Language Note | Disambiguation |
|---------|-----------------|------------|-------------------|----------------|
| anticipation | Character leaning forward at edge of frame, eyes bright with slight dilation, hands pressed together, warm amber light falls from the direction they're facing | `#F5A623` | Leaning momentum, weight in toes; energy lives in the line quality of the posture itself | Forward tension and gathering gesture distinguish from excitement |
| contentment | Character in casual seated position — headphones around neck, legs loosely crossed, soft smile, warm ambient light, no urgency in any limb | `#A8C5A0` | Fully inhabited seated position; nothing reaching, nothing guarded | Casual ownership of the space distinguishes from numbness or boredom |
| dread | Character slightly smaller in frame, shoulders elevated, looking toward something off-screen at lower-left, the background color desaturates and cools at that edge | `#7B7FA8` | Frozen alert; not backing away, but not willing to move toward either | Background color shift externalizes the emotional threat |
| envious | Character with a sideways glance and closed-mouth expression, one arm pulled in slightly; a window or screen in the background shows the object of envy softly out of focus | `#5FA888` | Controlled but involuntary attention to the off-screen subject | Window/screen element externalizes the comparison without a second character |
| grief | Character seated with knees drawn up or weight forward, one hand pressed gently to chest, eyes closed, soft even light behind them — not dramatic, not performative | `#8B9CC4` | Complete stillness; the body holding something | Inward press and stillness distinguish from sadness; the absence of acute expression signals the settled quality of grief |
| hopeful | Character looking upward and slightly ahead, a small genuine smile (not a wide grin), one open hand extended or lifted at side, warm yellow light from above-and-ahead | `#F5C842` | Open chest, forward and upward orientation | Directed orientation toward the light source distinguishes from happiness (which is present-tense and open) |
| indignation | Character straight-backed with chin elevated, brow furrowed, looking directly at the viewer or slightly above — offended but composed, not explosive | `#D4845A` | Deliberate uprightness; dignity under assault | Direct gaze and composure distinguish from anger; chin elevation distinguishes from resentful |
| melancholy | Character staring out of frame toward diffuse light, an object (pen, phone) in hand but unused — present but not engaged, expression wistfully neutral | `#8FAFC4` | A pause in action; the body has stopped mid-task | Object-held-but-unused signals the interruption of engagement; outward gaze distinguishes from sadness |
| resentful | Character with averted gaze, arms crossed or one arm gripping the other, jaw set, eyes looking to the side and slightly down — holding something in | `#C17C6B` | Tension stored in the upper body; a deliberate withholding | Averted gaze and inward tension distinguish from anger (outward); closed-mouth control distinguishes from indignation |
| restless | Character seated with one leg bouncing (implied), weight on the edge of their seat, one hand in restless motion, expression of pent, directionless energy | `#E8A87C` | About to move but no destination yet; contained kinetic energy | Motion-without-destination distinguishes from excitement (which has a target) and anxiety (which is frozen) |

---

### 6.3 Set 3 — Adult (10 images)

Style: Warm Editorial Character. Background: `#EDE8E3`. Abstraction: higher — face optional, posture essential.

| Feeling | Visual Direction | Key Accent | Body Language Note | Disambiguation |
|---------|-----------------|------------|-------------------|----------------|
| anticipation | Figure at a threshold — hand on a door frame or window, leaning slightly forward, weight on the front foot, warm amber light from the space beyond | `#C8860A` | Threshold posture: committed forward but not yet through | Contained posture (not full lean) registers the adult version of anticipation — more deliberate than adolescent |
| contentment | Figure reclined with a book or cup in hand, eyes closed or looking down at the object, soft window light falling across them, domestic and dignified | `#7D9E77` | Fully at rest; no vigilance in the body | Dignity and deliberateness of the rest distinguish from collapse or numbness |
| dread | Figure at a desk or in a still interior space, shoulders carried slightly forward, looking at an unseen point; the background color shifts cooler at the source of the dread | `#6B6FA0` | Still but not relaxed — held tension | Environmental color shift externalizes the source without depicting it |
| envious | Figure partially reflected in a window, looking at something on the other side; their reflection is slightly more vivid than their environment — a subtle doubling | `#4E9078` | Attention wholly on the comparison; the body almost forgotten | Reflection device handles the envy theme with sophistication appropriate to the adult set |
| grief | Figure alone in a spare room — on the floor or a low chair, no dramatic gesture, complete held stillness; the space around them is as emotionally present as they are | `#7A87B0` | Weight into the ground; the body has nowhere to go | Empty space in the composition carries as much weight as the figure; distinguish from sadness by the quality of the stillness |
| hopeful | Figure at a window or looking upward, posture open, a small contemplative expression — the light source is the destination, and the figure is oriented toward it | `#D4A82F` | Open chest, upward orientation, grounded stance | Forward orientation to a deliberate light source distinguishes from happiness |
| indignation | Figure in profile or three-quarter view, standing, jaw set, gaze measured and direct, hands deliberate at sides — composed outrage | `#B8634A` | Upright and grounded; not moving toward, not moving away | Profile view and measured composure signal the adult register of the feeling — fully considered, not reactive |
| melancholy | Figure at a window in afternoon light, reflection partially visible, one hand resting on the glass; the palette does most of the emotional work | `#6891A8` | Stillness with contact — touching the glass rather than simply looking | Touch-the-glass gesture provides the tactile intimacy that carries melancholy over into something felt |
| resentful | Figure in profile, jaw set, hand gripping a railing or table edge slightly too firmly — the grip the only tell | `#A86655` | Deliberate stillness; the emotion expressed only in the grip | Controlled whole-body posture with a single point of physical tension is the adult signal of resentment |
| restless | Figure in a lived-in space — table with scattered objects, mid-action gesture with hand through hair, gaze unfocused and moving; energy without object | `#CC7F58` | Mid-action pause; no object worthy of the energy | Clutter of the environment externalizes the directionlessness; distinguish from anxiety by the warmth of the palette |

---

## 7. Generation Prompts

Each prompt is written for use with Gemini Imagen, DALL-E 3, or Midjourney. The prompt includes a style specification, subject direction, color note, and negative constraints.

### 7.1 Set 1 — Global Fallbacks

````
ANTICIPATION — GLOBAL FALLBACK
A soft illustrated character study in the style of Headspace app illustration —
rounded simplified human figure, warm mocha skin, clean warm-brown outlines
on a cream background (#F5EFE6). The figure sits on the edge of a simple
surface, leaning forward with weight on toes, hands clasped together, eyes wide
and open. Warm amber light (#F5A623) falls from the right edge of the frame as
if from a source just off-screen. Expression: quietly alert, slightly held breath.
PNG with transparency, square crop, thumbnail-safe composition.
Negative: no text, no logos, no photorealism, no children's cartoon style,
no cold colors, no silhouettes, no gradients as primary treatment.
````

````
CONTENTMENT — GLOBAL FALLBACK
A soft illustrated character study, Headspace-adjacent style. Simplified human
figure seated with legs loosely crossed, shoulders dropped, a faint upward curve
of the mouth, eyes half-closed. Warm sage green accent (#A8C5A0) in the
character's clothing or a nearby object (cup, blanket). Background: warm cream
(#F5EFE6). Light is even and warm with no drama. The figure occupies the space
comfortably — nothing reaching, nothing guarded.
PNG with transparency, square crop.
Negative: no wide grin, no energetic posture, no text, no photorealism,
no cool palette, no childlike proportions.
````

````
DREAD — GLOBAL FALLBACK
Soft geometric character illustration, Headspace-adjacent. Simplified figure
standing or seated, slightly smaller in the frame than usual, shoulders raised
slightly toward ears, gaze directed toward lower-left as if tracking something
unseen. Muted indigo accent (#7B7FA8) as a shadow source from that lower-left
direction. Background: warm cream (#F5EFE6), very slightly cooler at the
left edge. The figure is frozen — not retreating, just held.
PNG with transparency, square crop.
Negative: no screaming, no horror imagery, no graphic threat, no crying,
no photorealism, no pure-black shadows, no cold-blue dominance.
````

````
ENVIOUS — GLOBAL FALLBACK
Soft geometric character illustration. Simplified figure in three-quarter profile,
gaze cut sharply sideways toward the left edge of the frame, expression tight
and controlled — a small closed mouth, narrowed eyes. One hand near the chin.
Teal-green accent (#5FA888) in clothing or a reflected light element.
Background: warm cream (#F5EFE6). The object of attention is entirely off-screen.
PNG with transparency, square crop.
Negative: no green skin, no monster/cartoon envy expression, no second character,
no photorealism, no caricature, no cold palette.
````

````
INDIGNATION — GLOBAL FALLBACK
Soft geometric character illustration, Headspace-adjacent. Simplified figure
standing or seated upright with deliberately raised chin, brow furrowed,
mouth set in a controlled line. Arms at sides or crossed — not raised.
Chest open and elevated. Terracotta accent (#D4845A) in clothing.
Background: warm cream (#F5EFE6), light even.
PNG with transparency, square crop.
Negative: no aggressive gesture, no raised fist, no shouting expression,
no cartoonish exaggeration, no photorealism, no cool color dominance.
````

````
MELANCHOLY — GLOBAL FALLBACK
Soft geometric character illustration. Simplified figure in three-quarter view,
gaze directed toward a soft diffuse light source at the upper right, expression
neutral-to-wistful, slight downward set of the mouth. Dusty blue accent
(#8FAFC4) in the light source direction and in the character's shadow tones.
Background: warm cream (#F5EFE6). Neither collapsed nor upright — a middle
stillness.
PNG with transparency, square crop.
Negative: no tears, no crying, no collapsed posture, no dramatized sadness,
no cool-teal dominance, no photorealism, no childlike style.
````

````
RESTLESS — GLOBAL FALLBACK
Soft geometric character illustration. Simplified figure mid-motion or with
implied multiple positions — hand on knee about to push up, weight shifted
forward, one foot slightly raised. Warm peach accent (#E8A87C) in clothing
or a warm glow on the moving limb. Background: warm cream (#F5EFE6),
very slightly warmer at the center of motion.
PNG with transparency, square crop.
Negative: no anxious frozen posture, no panic expression, no dark palette,
no photorealism, no childlike cartoon, no cool colors.
````

---

### 7.2 Set 2 — Adolescent

````
ANTICIPATION — ADOLESCENT
Webtoon-influenced digital illustration of an adolescent character (gender-neutral,
medium warm skin tone). The character leans forward at the edge of their seat,
hands pressed together in their lap, eyes large and bright with slight dilation.
Warm amber light (#F5A623) falls from the right — the direction they're looking.
Background: soft lavender-cream (#F0EBF8) with loose impressionistic warm strokes
suggesting a space opening up. Clean digital linework, warm plum lines (#2C1A3A).
PNG with transparency, square crop, mobile thumbnail safe.
Negative: no text bubbles, no manga-style speed lines, no childish chibi proportions,
no cold palette, no photorealism, no specific branded style.
````

````
CONTENTMENT — ADOLESCENT
Webtoon-influenced illustration of an adolescent character, casual seated pose —
legs loosely crossed, headphones around neck (not on), soft smile, eyes relaxed.
Sage green accent (#A8C5A0) in clothing or ambient light. Background: soft
lavender-cream with warm ambient glow. The character fully inhabits their space
— nothing reaching or guarding. Clean digital linework.
PNG with transparency, square crop.
Negative: no wide grin, no energetic gestures, no text, no cold palette,
no photorealism, no overtly gendered character defaults.
````

````
DREAD — ADOLESCENT
Webtoon illustration of an adolescent character, slightly smaller in frame
than usual, shoulders raised, eyes tracking something off-screen at lower-left.
The background color desaturates toward muted indigo (#7B7FA8) at that corner.
The character's posture is frozen alert — not fleeing, just held. Expressive
webtoon eyes carry the emotional weight.
PNG with transparency, square crop.
Negative: no horror imagery, no supernatural threat, no screaming, no graphic
darkness, no cold-blue dominance as the only color, no photorealism.
````

````
ENVIOUS — ADOLESCENT
Webtoon illustration of an adolescent character with a sideways glance —
cut hard toward the left edge of the frame. Expression controlled, tight-mouthed.
One arm pulled slightly inward. In the background, a softly out-of-focus window
or screen suggests the object of comparison without depicting it clearly.
Teal-green accent (#5FA888) in the background light.
PNG with transparency, square crop.
Negative: no green skin tone, no monstrous expression, no overt second character
as rival, no photorealism, no childish caricature.
````

````
GRIEF — ADOLESCENT
Webtoon illustration of an adolescent character seated, knees drawn up or
weight forward, one hand pressed gently and deliberately to chest. Eyes closed.
Soft, even, slightly cool light behind them — not dramatic. Soft periwinkle
accent (#8B9CC4). The posture is complete and still, not performative.
Background: muted lavender-cream, with color deepening slightly around the
figure.
PNG with transparency, square crop.
Negative: no tears streaming, no dramatic expression, no dark dramatic lighting,
no isolation glorification, no cold-clinical atmosphere, no photorealism.
````

````
HOPEFUL — ADOLESCENT
Webtoon illustration of an adolescent character looking slightly upward and
ahead, a small genuine smile (not wide, not forced), one open hand extended
or slightly lifted. Warm yellow light (#F5C842) from above-ahead — aspirational
direction. Background: soft lavender-cream with a warm haze in the direction
they face.
PNG with transparency, square crop.
Negative: no wide performative smile, no arms raised in triumph, no photorealism,
no childlike style, no cold palette, no specific cultural/religious iconography.
````

````
INDIGNATION — ADOLESCENT
Webtoon illustration of an adolescent character standing or seated upright,
chin elevated, brow furrowed with clear intent, looking directly at the viewer
or slightly above — offended and composed. Terracotta accent (#D4845A) in
clothing. Posture controlled and assertive, not explosive.
PNG with transparency, square crop.
Negative: no raised fist, no shouting, no aggressive open-mouth expression,
no photorealism, no childlike proportions, no cold palette.
````

````
MELANCHOLY — ADOLESCENT
Webtoon illustration of an adolescent character looking out of frame toward
a soft diffuse light. An object — a pen, a phone — held in the hand but unused.
Expression neutrally wistful. Dusty blue accent (#8FAFC4) in the light source.
The character has paused mid-task and is somewhere else entirely.
PNG with transparency, square crop.
Negative: no crying, no collapsed posture, no darkness, no cold clinical palette,
no photorealism, no dramatized despair.
````

````
RESENTFUL — ADOLESCENT
Webtoon illustration of an adolescent character with arms crossed or gripping
one arm, jaw set, gaze averted to the side and slightly down. Muted rose-terracotta
accent (#C17C6B) in clothing. The body is holding something in — tension stored
in the upper body, particularly shoulders and jaw.
PNG with transparency, square crop.
Negative: no angry shouting, no confrontational direct gaze, no photorealism,
no childlike style, no cold palette, no self-harm implications.
````

````
RESTLESS — ADOLESCENT
Webtoon illustration of an adolescent character seated, one leg with implied
bounce, weight on the front edge of their seat, one hand in motion. Expression
of pent, directionless energy — not anxious, just full and unable to settle.
Warm peach accent (#E8A87C) in clothing or a warm kinetic light on the limbs
in motion.
PNG with transparency, square crop.
Negative: no panicked expression, no frozen anxious posture, no dark palette,
no photorealism, no childlike cartoon, no cold colors.
````

---

### 7.3 Set 3 — Adult

````
ANTICIPATION — ADULT
Editorial illustration in the style of Marion Barraud or Olimpia Zagnoli —
abstracted warm figure at a threshold: hand on a door frame or window edge,
weight on the front foot, leaning slightly forward. Warm deep-amber light
(#C8860A) from the space beyond. Background: warm greige (#EDE8E3). The
posture is deliberate and contained — an adult's anticipation, considered
not impulsive.
PNG, square crop, thumbnail-safe.
Negative: no text, no photorealism, no photo-reference human faces, no cold
palette, no graphic novel style, no clipart, no childlike elements.
````

````
CONTENTMENT — ADULT
Editorial illustration, warm and spare. An abstracted figure reclined with a
book or a cup — eyes closed or softly directed at the object, window light
falling across them in the afternoon. Forest sage accent (#7D9E77) in
clothing or a plant near the frame edge. Background: warm greige.
Domestic and dignified — not collapsed, not infantile.
PNG, square crop.
Negative: no corporate wellness aesthetic, no gratuitous softness, no
photorealism, no human face detail, no cold palette.
````

````
DREAD — ADULT
Editorial illustration, spare interior. An abstracted figure at a desk or
table, shoulders carried slightly forward, gaze on an unseen point. The
background color shifts from warm greige (#EDE8E3) to a cooler muted indigo
(#6B6FA0) at the edge toward which the figure looks. Tension held in the
upper body — the body knows something.
PNG, square crop.
Negative: no horror imagery, no dramatic lighting, no photorealism, no human
face detail, no self-harm implications, no cold dominance.
````

````
ENVIOUS — ADULT
Editorial illustration. An abstracted figure partially reflected in a window,
looking at something on the other side. Their reflection in the glass is
slightly more vivid or luminous than their own environment. Teal-green
accent (#4E9078) in the reflected light. Background: warm greige. The
comparison is the subject — handled with restraint.
PNG, square crop.
Negative: no green skin, no second character, no obvious wealth display
as the object of envy, no photorealism, no human face detail, no cold
palette dominance.
````

````
GRIEF — ADULT
Editorial illustration, intimate and spare. An abstracted figure alone in
a room — on the floor or a low chair. Complete held stillness. The empty
space in the composition carries as much weight as the figure. Soft periwinkle
accent (#7A87B0) in the ambient light. The room itself feels held.
PNG, square crop.
Negative: no dramatic crying pose, no darkness as the dominant mood, no
clinical or hospital atmosphere, no photorealism, no isolation glorification,
no self-harm implications.
````

````
HOPEFUL — ADULT
Editorial illustration. An abstracted figure at a window or facing upward —
posture open, a small contemplative expression, grounded stance. Warm yellow
accent (#D4A82F) as the light source in the direction of orientation.
The figure is oriented toward something, not just open to nothing.
Background: warm greige shifting toward the accent at the light source.
PNG, square crop.
Negative: no triumphant posture, no wide smile, no photorealism, no human
face detail, no cold palette, no specific cultural or religious iconography.
````

````
INDIGNATION — ADULT
Editorial illustration. An abstracted figure in profile or three-quarter view,
standing, jaw set, gaze measured and direct — composed outrage. Hands
deliberate at sides, not raised. Terracotta accent (#B8634A) in clothing.
The posture is fully considered and controlled — this emotion has been
held and examined before being worn.
PNG, square crop.
Negative: no aggressive gesture, no raised fist, no open-mouth anger,
no photorealism, no human face detail, no cold palette.
````

````
MELANCHOLY — ADULT
Editorial illustration. An abstracted figure at a window in afternoon light,
reflection partially visible in the glass, one hand resting against the pane.
Dusty blue accent (#6891A8) in the light. The palette carries most of the
emotional weight — warm greige background with the blue light creating
a contemplative temperature.
PNG, square crop.
Negative: no crying, no collapsed posture, no clinical atmosphere, no
photorealism, no human face detail, no dramatized despair.
````

````
RESENTFUL — ADULT
Editorial illustration. An abstracted figure in profile, jaw set, standing or
seated. The hand that holds a railing, cup, or table edge grips slightly too
firmly — this is the only outward tell. The rest of the body is composed.
Muted rose-terracotta accent (#A86655) in clothing.
PNG, square crop.
Negative: no confrontational direct gaze, no aggressive posture, no photorealism,
no human face detail, no self-harm implications, no cold palette.
````

````
RESTLESS — ADULT
Editorial illustration, lived-in interior. An abstracted figure at a table with
scattered objects — books open, a cup half-moved. One hand in the hair or
mid-reaching gesture, gaze unfocused. Warm peach accent (#CC7F58) in
the ambient light. Energy without destination. The environment externalizes
the directionlessness.
PNG, square crop.
Negative: no panicked expression, no frozen anxious posture, no dark dramatic
lighting, no photorealism, no human face detail, no cold palette.
````

---

## 8. Quality Gates

### 8.1 3-Second Test

Display each generated image at 48×48px on a mobile screen. Show it to a tester (or run it past two reviewers unfamiliar with the prompt) for exactly 3 seconds. They must identify the correct emotion from a list of 5 candidates. Pass threshold: 80% correct identification rate.

**Common 3-second failures:** melancholy and sadness render identically; contentment and boredom are ambiguous; grief and tired look the same when body language is not distinct enough. If a pair fails disambiguation, apply the secondary visual cue from Section 5.4 and regenerate.

### 8.2 "Would I Tap This?" Test

For every image, ask from the perspective of the target band's user:
- Global fallbacks: "Would a 12-year-old or a 35-year-old tap this without embarrassment?"
- Adolescent: "Would a 14-year-old tap this without feeling like they're doing something babyish or clinical?"
- Adult: "Would a 38-year-old tap this without feeling managed or patronized?"

**Automatic failures:** anything that looks like a worksheet, a hospital chart, a children's TV character, or a stock photo.

### 8.3 Therapeutic Safety Test

Every image must pass all four:
1. Does not trivialize or minimize the named emotion (e.g., making "grief" look cheerful because of a warm palette).
2. Does not trigger by depicting self-harm, isolation in a glamorized form, or imagery associated with crisis states.
3. Does not dismiss the emotion through humor or irony.
4. Holds the emotion as valid — neither alarming nor dismissive.

**Edge cases:** dread, grief, and resentful require particular care. The goal is to acknowledge the emotional weight while keeping the image warm enough to invite rather than repel engagement.

### 8.4 Cross-Set Consistency Check

When all 27 images are displayed as a grid:
- They must read as one visual family. Shared DNA: warm background temperatures, consistent line vocabulary, warm shadow tones, emotional accent color system.
- Band differentiation must be visible but not jarring. Global fallbacks read as the most abstracted and neutral. Adolescent reads as the most energetic and graphic. Adult reads as the most restrained and compositionally sophisticated.
- No single image should visually dominate or stand apart from the group. Outliers indicate either a palette error or a style inconsistency — regenerate.

### 8.5 Technical Requirements

- Format: PNG with alpha channel (transparency support)
- Minimum resolution: 512×512px (displayed at 48×48 but assets regenerated at 4x for Retina)
- Square crop (1:1 ratio)
- Primary subject centered and legible at 1/4 crop (48×48px simulation)
- No embedded text or watermarks
- Color profile: sRGB

---

## 9. Naming Convention

### 9.1 File Names

No changes required from the existing convention. All files use lowercase snake_case matching the feeling name:

```
anticipation.png
contentment.png
dread.png
envious.png
grief.png
hopeful.png
indignation.png
melancholy.png
resentful.png
restless.png
```

### 9.2 File Locations

```
Global fallbacks (7):
  assets/feelings_faces/{feeling_name}.png

Adolescent band (10):
  assets/images/feelings/adolescent/{feeling_name}.png

Adult band (10):
  assets/images/feelings/adult/{feeling_name}.png
```

These paths match the existing `AgeBandAssetResolver.feelingPath()` routing. No pubspec.yaml changes required — all directories are already registered.

### 9.3 Backup Convention

Before replacing any existing file, copy the current version to:
```
assets/images/feelings/{band}/backup_pre_redesign_{feeling_name}.png
```
Remove backup files after QA sign-off on the full set.

### 9.4 Batch Generation Tracking

Maintain a generation log at `scripts/feelings_generation_log.md` with columns:

| File | Prompt Version | Generator | Pass/Fail | Notes |
|------|---------------|-----------|-----------|-------|

This ensures any failed image can be traced back to its prompt for revision rather than starting from scratch.

---

*End of brief. Total scope: 27 images, 3 asset sets, 2 page sessions recommended — global fallbacks first (baseline visual language), then adolescent, then adult.*
