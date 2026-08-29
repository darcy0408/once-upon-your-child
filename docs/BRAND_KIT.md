# Brand Kit — Once Upon YOUR Child

*Powered by Story Weaver.* Personalized bedtime & adventure stories that help
kids build coping skills and emotional strength (ages 3–17).

This kit is extracted from the live app so marketing assets stay consistent
with what ships. Source of truth for colors is `lib/theme/app_theme.dart` and
`lib/theme/age_band_theme.dart`; the logo is `assets/images/splash_logo.webp`.

**How to use with Claude:** paste the [Copy-paste block](#copy-paste-block-for-claude)
into a new conversation, attach `assets/images/splash_logo.webp` as the
source-of-truth logo, then start every design request with *"Using our brand
guide, create…"*

---

## The feeling

Enchanted, warm, safe, personal. Radiant **gold** on **deep midnight-purple**
night skies. Storybook magic — a child stepping through a golden doorway into a
world made just for them. Never cold, never clinical, never white-and-corporate.

Keywords: *enchanted · warm & safe · personal · storybook · radiant gold on
midnight · supportive, not clinical.*

---

## Logo

A circular emblem: three children in silhouette gazing through an ornate
gold-framed portal into a crystal cave, ringed by a gold border and amethyst
gems on a starfield, with the ornate gold serif wordmark below.

| Asset | Path |
|---|---|
| Full emblem | `assets/images/splash_logo.webp` |
| App icon 512 | `web/icons/Icon-512.png` |
| App icon 192 | `web/icons/Icon-192.png` |
| Maskable icons | `web/icons/Icon-maskable-192.png`, `web/icons/Icon-maskable-512.png` |
| Favicon | `web/favicon.png` |
| iOS/macOS | `ios/Runner/Assets.xcassets/AppIcon.appiconset/`, `macos/Runner/Assets.xcassets/AppIcon.appiconset/` |

**Rules**

- Keep the gold ring and clear space around it — don't crop the circle.
- Place only on deep purple / starfield or black. **Never on white.**
- "YOUR" always reads largest — it's the whole promise.

---

## Core color (marketing)

What belongs on social posts, decks, and covers. Deep purples ground
everything; gold is the single hero accent; cream softens.

| Name | Hex | Use |
|---|---|---|
| Brand Purple | `#4A148C` | Primary brand / app `theme_color` |
| Magic Purple | `#6A1B9A` | CTAs, magical elements |
| Royal Violet | `#2E0854` | Deep backgrounds |
| Midnight | `#120226` | Darkest ground / night sky |
| Signature Gold | `#FFD54F` | Hero accent, highlights, headlines |
| Gold Glow | `#FFE082` | Shimmer, glows |
| Cream | `#FFF8E1` | Soft light text / pill buttons |
| Splash BG | `#2A1B4E` | App `background_color` |

Supporting neutrals from the theme: `#333333` text on light, `#FFFFFF` text on
dark, `#2C3E50` story ink.

---

## In-app age palettes

Inside the app the theme adapts by age band — same gold-on-dark spirit, tuned
warmer for little ones and more cinematic for teens. Use these when a graphic
targets one age group; otherwise use Core color above.

| Band | Ages | Primary | Accent | Card/Surface | UI font |
|---|---|---|---|---|---|
| **Sprout** | 3–5 | `#E65100` orange | `#FFD54F` gold | `#FFE3C2` apricot | Nunito |
| **Explorer** *(default)* | 6–8 | `#7B1FA2` purple | `#FFD54F` gold | `#EBD9F7` lilac | Quicksand |
| **Adventurer** | 9–12 | `#283593` indigo | `#80CBC4` teal | `#1B2450` cosmic | Bitter |
| **Creator** | 13–14 | `#7C4DFF` purple | `#7C4DFF` purple | `#1E1E2E` dark | Source Sans Pro |
| **Adolescent** | 15–17 | `#00838F` teal | `#00BCD4` cyan | `#121E2B` cinematic | Source Sans Pro |
| **Adult** | 18+ | `#2C5D8F` sapphire | `#C77B47` copper | `#142130` navy | Source Sans Pro |

Story text is **Merriweather** in every band.

---

## Typography

Three roles.

- **Display / logo — Cinzel Decorative** (bold, ornate serif). The wordmark and
  hero headlines only. This is the "magic" voice — use sparingly, in gold.
  *(Bundled locally at `assets/fonts/CinzelDecorative-Bold.ttf`.)*
- **UI & body — Quicksand** (rounded humanist sans). Buttons, captions,
  marketing body copy, social posts. Friendly and approachable. Per-age in-app
  variants: Nunito, Bitter, Source Sans Pro.
- **Story — Merriweather** (readable serif). Long-form story text everywhere in
  the app. Calm, book-like, generous line spacing.

All three are Google Fonts (loaded at runtime via `google_fonts`).

---

## Illustration style

- **Soft, painterly children's-book art** — luminous and dreamlike, not flat
  vector or photoreal.
- **Warm, glowing light** — gold sparkle, starlight, lantern-lit scenes.
- **The child is the hero** — centered, wonder-struck, safe.
- **Rich but gentle color** — deep skies, jewel tones, never harsh.
- Style is tuned per age band; keep it cohesive and tender across all.

---

## Voice & tone

- **Warm & encouraging**, like a parent at bedtime.
- **Personal** — always "YOUR child," never generic.
- **Emotionally honest** — big feelings are welcome and safe.
- **Magical, not saccharine** — wonder with a steady hand.
- **Reassuring, never clinical** — supportive underneath, playful on top.

---

## Copy-paste block for Claude

```
BRAND: Once Upon YOUR Child (powered by Story Weaver)
TAGLINE: Personalized stories that put your child at the heart of every tale.
WHAT IT IS: Personalized bedtime & adventure stories that help kids ages 3–17
build coping skills and emotional strength.

FEELING: Enchanted, warm, safe, personal. Radiant gold on deep midnight-purple
night skies. Storybook magic — never cold, clinical, or white.

CORE COLORS
  Brand Purple   #4A148C   (primary / theme)
  Magic Purple   #6A1B9A   (CTAs)
  Royal Violet   #2E0854   (deep backgrounds)
  Midnight       #120226   (darkest ground)
  Signature Gold #FFD54F   (hero accent — headlines & highlights)
  Gold Glow      #FFE082   (shimmer)
  Cream          #FFF8E1   (soft light text / pills)
  Splash BG      #2A1B4E   (app background)

FONTS
  Display / logo : Cinzel Decorative (bold ornate serif) — brand name & hero
  UI / body      : Quicksand (rounded sans) — everything else
  Story text     : Merriweather (serif) — long-form reading

LOGO: Circular gold-ringed emblem, gold ornate serif wordmark, children in
silhouette at a portal on a starfield. Gold on deep purple only.

RULES: Gold is the only hero accent. Deep purple/starfield grounds. Never on
white. "YOUR" is always emphasized. Warm, encouraging, personal voice.
```

---

*Kept in sync with the app: if `app_theme.dart` / `age_band_theme.dart` colors
or fonts change, update this file too.*
