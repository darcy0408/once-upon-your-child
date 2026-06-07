# Age-Band Review — "Choose Your Setting" (Scene Picker)

**Band evaluated:** Adventurer (9–11)
**Screen:** Hero Creator wizard, Step 3 of 4 — "My Setting" / scene picker
**Date:** 2026-06-05
**Widget:** `lib/screens/wizard_steps/hero_creator_scene_page.dart`
**Supporting:** `lib/widgets/hero_creator/scene_widgets.dart` (`SceneImageButton`, `ImagineItHeroCard`), `lib/data/scenario_data.dart` (copy), `lib/screens/wizard_story_screen.dart` (stepper + nav scaffold)
**Capture:** `localhost:53324`, Responsive 400×845, CanvasKit debug build

---

## Age-Band Check

Confirmed with founder: **Adventurer (9–11)**. The branch (`adventurer-craft-fixes`) and the runtime copy agree — this screen renders the Adventurer-specific path:

- Title resolves to `'Choose your setting'` (`hero_creator_scene_page.dart:68`), font `GoogleFonts.bitter` gold/bold.
- Subtitle resolves to `'Where will your adventure begin?'` (`:178`).
- `showDescription: isAdventurer` is **on** — each tile shows a one-line "what happens here" tease (`:225`), gated to this band only (MT-218/F-02).
- Tiles use the **standard** (not young, not mature) `title`/`description` for ages 9–11 (`scenario_data.dart:101,110`).

No grounding gap — every finding below maps to real code.

---

## Three-Lens Walkthrough

### Child lens (a 10-year-old)
- **Notices first:** the four picture tiles — the rainbow world and the dragon volcano pull the eye (warm, high-saturation art).
- **Notices second:** the big glowing gold **"✨ Imagine It"** card lower down — it pulses, so it competes hard with the presets for attention.
- **Notices third:** the purple round arrow at the bottom ("Next: Story Style").
- **What they tap:** most likely a vivid preset (Vanishing Colors / Volcano), or the glowing Imagine It card. The truncated descriptions ("paint it bac…", "Spe…", "sneezi…", "getti…") get skimmed, not read — the child decides on the picture + title alone.

### Psychologist lens
- **Reading level:** tile titles are grade ~2–4; descriptions are grade ~3–5 ("Use your magic to paint it back to life", "Riding the waves of being worried or mad without getting swept away"). Within range for 9–11, though "Life Quest" + its abstract wave-metaphor is the most demanding item and the least concrete.
- **Attention span / working memory:** 5 total choices (4 presets + Imagine It). This sits inside the 5±2 chunking limit for this band — good. Adding more presets would push it over.
- **Motor precision:** tap targets are large (half-width tiles ≈ 170px, full-width Imagine It card, ~64px arrow). No precision risk.
- **Emotional safety:** content is non-scary and pro-social (a *sleeping/kindest* dragon, *whispering* in a cave, *painting the world back*, *naming feelings*). The "Life Quest" feelings tile is framed as mastery ("be the boss of your clouds"), which is developmentally healthy for this age.

### Parent lens
- **Builds trust:** wholesome, creative, emotion-literate content; a visible parent-gate shield in the top bar; no ads, no price, no upsell, no urgency anywhere on this screen.
- **Triggers doubt:** the art reads *younger* than a 9–11 audience (the Imagine It card shows a ~5–6-year-old girl with a picture book). A parent of an 11-year-old may wonder "is this actually for my kid, or for their little sibling?" — a perceived-age mismatch, not a safety issue.

---

## Age-Appropriateness Scorecard

| Category | Score (1–10) | Evidence |
|---|---|---|
| Reading level | 8 | Titles grade 2–4, descriptions grade 3–5; fits 9–11. "Life Quest" wave-metaphor is the only abstract outlier. |
| Visual maturity fit | 5 | Soft picture-book art (cute owl, ~5–6yo girl on the Imagine It card) skews to Explorer; borderline-babyish for the 10–11 end. |
| Clarity | 6 | Title + 4 tiles + Imagine It is a clear menu, but tile descriptions truncate mid-word, so the "self-explaining" copy is cut off exactly where it matters. |
| Delight | 8 | Glowing Imagine It card, vivid worlds, haptics + press-scale on every tile. Strong "I want to make my own" pull for this band. |
| Frustration risk | 7 | Low — no precision traps. Main friction: cut-off descriptions and a top nav bar that invites mid-flow exit. |
| Parent trust | 9 | Parent-gate present, zero dark patterns/upsell, pro-social content. Only soft concern is perceived-age of art. |
| **Overall age fit** | **7** | Solidly aimed at this band on copy and interaction; the art and truncated descriptions are what hold it back from an 8–9. |

---

## Band-Shift Check

| Shift | What changes (in code) | Effect on fit |
|---|---|---|
| **One younger — Explorer 6–8** | Subtitle → "Pick a world or make your own!"; titles → youngTitle ("Rainbow World", "Cave Full of Crystals", "Friendly Dragons", "Life Quest"); **descriptions hidden** (`showDescription` gated to adventurer). | Art finally *matches* the audience; reading load drops. But worlds stop self-explaining. Net: art fit ↑, clarity ↓. Confirms the art was authored for ~this age. |
| **Current — Adventurer 9–11** | Standard titles + one-line descriptions; Imagine It below the grid. | Best-balanced band for the *copy*; the *art* is the weak link. |
| **One older — Creator 12–14** | Title → "Setting"; Imagine It shown FIRST as a spotlight; mature titles ("The Fading Realm", "The Resonance Caverns", "The Dragon's Lair", "Riding the Storm") + thematic questions. | The mature titles would clash hard with the cutesy art — a 13-year-old reads the owl/young-girl card as babyish and disengages. |

**Conclusion:** copy and interaction are aimed correctly at 9–11; the **art asset set is tuned ~2 years young**. That's the single highest-leverage thing to move.

---

## Too Advanced or Too Babyish

- **Too babyish (art):** the Imagine It card protagonist (~5–6yo girl, soft pastel picture-book book scene) and the overall rainbow-pastel palette skew young. Most acute for 11-year-olds. — *Visual maturity*
- **Too babyish (one label):** "Life Quest" sitting beside three vivid place-names is both vaguer *and* visually softer; not babyish in wording, but the tile doesn't earn its place at a glance.
- **Slightly advanced (one item):** the "Life Quest" description ("Riding the waves of being worried or mad without getting swept away") is the only metaphor-dependent line; a literal-minded 9-year-old may not connect "waves" to feelings until they read the truncated tail — which is cut off.
- **Right on target:** titles, subtitle, choice count (5), tap mechanics.

---

## Confusion & Frustration

1. **Truncated descriptions defeat their own purpose.** Descriptions were added so each world self-explains (F-02/MT-218), but at 400px width with `maxLines: 2` they cut mid-word ("paint it bac…", "Spe…", "sneezi…", "getti…"). The child gets a fragment, not a hook. — `scene_widgets.dart:378-392`
2. **"Life Quest" is opaque at a glance.** It's the only tile whose title doesn't describe a place; it relies entirely on the (truncated) description to explain it's an emotions story. — `hero_creator_scene_page.dart:139-146`
3. **Title sits tight against the stepper / back-chevron.** In capture the heading top is visually clipped and shares vertical space with the floating "‹" back control; reads crowded. (Scaffold-level, `wizard_story_screen.dart`.)
4. **Mid-flow exit surface.** The top bar exposes X (close) + Life Quests + Heroes + Bedtime + voice + parent — a 10-year-old mid-creation can tap "Heroes"/"Bedtime" and lose wizard progress. — `wizard_story_screen.dart` nav row.

---

## Layout & Usability

- **Hierarchy:** the glowing/pulsing Imagine It card is the most visually dominant element on the screen, sitting *below* the four presets it competes with. For this band's love of open-ended creation that's arguably fine, but it does out-shout the presets — intentional tension, not a clear win. (`scene_widgets.dart:80-105` glow animation.)
- **Tap targets:** all comfortably above 44px. Tiles ≈170×104px; arrow ≈64px. ✔
- **Spacing:** 12px grid gaps, 20px h-padding — clean, not crowded in the grid itself. The crowding is only at the header/stepper seam.
- **Redundancy:** previously the subtitle duplicated the Imagine It CTA; that was already fixed (F-04, `:174-178`). No remaining copy duplication. ✔
- **Next action obvious:** yes — single purple arrow labeled "Next: Story Style". ✔
- **Selection feedback:** gold border + check badge on the chosen tile; clear. ✔

---

## Delight Levers

1. **"Imagine It" as a creative dare ("Describe any world you can dream up").** 9–11 is the autonomy/competence sweet spot (industry-vs-inferiority): being trusted to invent the world, not just pick from a menu, is exactly the agency this band craves. *Keep it, and let it earn the spotlight with band-appropriate art.*
2. **One-line "what happens here" hooks under each title.** This age reads to *choose well*; a vivid premise ("Someone is erasing the world!") rewards that and makes picking feel literary, not menu-driven — **provided it isn't truncated.**
3. **Tactile press feedback (haptic + 0.93 scale).** 9–11s notice and enjoy responsive, "real-feeling" UI; the press-down dip + light haptic makes selection satisfying. (`scene_widgets.dart:276-288`)
4. **Stakes/agency in the premises.** "Wake the kindest dragon", "get your friend's voice back" — goal-directed, mild-jeopardy hooks match this band's appetite for competence and consequence over pure cuteness.
5. **(Add) a subtle "new every time" cue.** This band returns for novelty; a small "✨ surprise me" affordance on Imagine It (random evocative seed) would reward repeat visits with developmental payoff (curiosity/mastery). *Founder-decision — see fix plan.*

---

## Parent Trust (Love / Distrust)

**Love**
- Parent-gate shield reachable from the wizard without disrupting the child. (`wizard_story_screen.dart:617-632`)
- Pro-social, emotion-literate content; a dedicated feelings path framed as mastery.
- No price, no countdown, no upsell, no pre-checked anything on this screen.

**Distrust / watch**
- Art reads younger than the stated age band → "is this really for my 10–11yo?" perception gap (trust-by-fit, not safety).
- Four top-bar destinations during creation could read as "designed to keep them tapping around" if a child bounces out mid-flow. No dark pattern *intended*, but worth a confirm-on-exit so it never feels like a trap.

**No dark patterns detected:** no false urgency, no disguised upsell, no accidental-purchase traps, no pre-checked consent on this screen. ✔

---

## Simplification

- Don't add presets — 5 choices is the right ceiling for this band; keep it.
- Tighten each Adventurer description to a single punchy clause that fits two lines at 170px (≈6–9 words) so nothing truncates. Shorter *and* fully visible beats longer-and-cut.
- Consider a confirm-on-exit (or hiding Life Quests/Heroes/Bedtime) during the wizard to reduce the mid-flow surface area to: back, the choices, next.

---

## Fix Plan

### Findings

| ID | Title | Lens | Severity | Element | Issue | Recommendation | Autonomous? | Effort |
|---|---|---|---|---|---|---|---|---|
| S-01 | Tile descriptions truncate mid-word | Child / Psych | High | `SceneImageButton` description (`scene_widgets.dart:378-392`) | 2-line clamp at 170px cuts the self-explaining hook ("paint it bac…") | Allow 3 lines + nudge tile aspect taller, AND shorten Adventurer descriptions to ≤9 words | Y | M |
| S-02 | Art skews ~2 years young | Parent / Child | High | Tile art + `imagine_it_btn_pressed.webp` | Picture-book/young-child imagery reads babyish for 10–11 | Commission Adventurer-tuned art (see Imagen prompts); protagonist age-neutral/older | N (asset gen + founder taste call) | L |
| S-03 | "Life Quest" tile opaque at a glance | Child | Medium | `big_feelings_quest` tile (`hero_creator_scene_page.dart:139-146`) | Only non-place title; meaning lives in truncated description | After S-01, ensure its short description leads with "About big feelings"; consider an emotion-cue icon | Partial | S |
| S-04 | Header/stepper vertical crowding | Child / Psych | Medium | Scaffold header (`wizard_story_screen.dart`) | Title top clipped, shares row space with back "‹" | Add top spacing above `placeTitle` / verify scroll inset; ensure back control doesn't overlap heading | Y | S |
| S-05 | Mid-flow exit surface | Parent | Medium | Top nav row (`wizard_story_screen.dart`) | X + Life Quests/Heroes/Bedtime tappable mid-wizard → progress loss | Confirm-on-exit dialog, or hide section tabs during wizard | N (founder UX call) | M |
| S-06 | Imagine It out-shouts presets | Child | Low | `ImagineItHeroCard` glow (`scene_widgets.dart:80-105`) | Pulsing gold card dominates over the 4 presets | Acceptable for this band; only revisit if analytics show presets ignored | N | — |
| S-07 | Description contrast over bright art | Psych (a11y) | Low | description text over rainbow tile | White text may dip below contrast on the brightest art regions despite scrim | Strengthen bottom scrim opacity slightly on light tiles | Y | S |

### Priority grouping

**P1 — Must Fix**
- **S-01** Stop truncating the hooks (3 lines + taller tile + shorter copy).
- **S-02** Re-tune the art to the band (the babyish-perception fix).

**P2 — Should Improve**
- **S-03** Make "Life Quest" legible at a glance.
- **S-04** De-crowd the header/stepper seam.
- **S-05** Protect wizard progress from accidental mid-flow exit.

**P3 — Delight Polish**
- **S-06** Re-balance Imagine It vs presets only if data warrants.
- **S-07** Scrim/contrast touch-up.
- **Delight lever #5** "Surprise me" seed on Imagine It (founder-decision).

---

## Autonomous vs Founder-Decision

| Fix | Autonomous? | Files Touched | What I Need From You | Risk | Reversible? |
|---|---|---|---|---|---|
| S-01 layout (3 lines + aspect) | Yes | `scene_widgets.dart`, `hero_creator_scene_page.dart` (aspectRatio) | Nothing — purely UI clamp/sizing | Low (slightly taller tiles) | Yes |
| S-01 copy shortening | Yes* | `scenario_data.dart` (Adventurer `description` only) | Confirm I may edit tile UI copy (these are *picker* descriptions, NOT story-generation word counts in `story_service.py`, which I will not touch) | Low | Yes |
| S-02 art re-tune | No | new `.webp` assets under `assets/images/scenarios/` | Approve direction + run/approve Imagen outputs; pick final crops | Medium (brand/taste) | Yes |
| S-03 Life Quest clarity | Partial | `scenario_data.dart`, maybe tile icon | Decide whether to add an emotion icon vs copy-only | Low | Yes |
| S-04 header spacing | Yes | `hero_creator_scene_page.dart` and/or scaffold | Nothing | Low | Yes |
| S-05 confirm-on-exit / hide tabs | No | `wizard_story_screen.dart` | Choose: confirm dialog vs hide tabs during wizard | Medium (nav behavior) | Yes |
| S-07 scrim contrast | Yes | `scene_widgets.dart` | Nothing | Low | Yes |
| Delight #5 "surprise me" | No | imagine-it entry | Approve concept + seed list | Low | Yes |

\* Protected-constraint note: I will **not** alter word-count or age-routing logic in `backend/services/story_service.py`. S-01 copy edits touch only the scene-picker `description` strings in `scenario_data.dart`.

---

## Imagen Prompts

> Existing tile art is **textless** — labels are drawn by Flutter over the `.webp`. All new art must stay textless. Prompts below match the existing band system (soft-magical-realism worlds, warm rim-light, full-bleed scene art) but tuned **older** for 9–11.

**S-02a — "Imagine It" card (replace young-child framing)**
```
Create a full-bleed scene illustration for a child-facing app, age band Adventurer 9 to 11.
Subject: a wide-open imaginative dreamscape — floating islands, a doorway of light, drifting constellations and half-formed sketched worlds coming to life, hinting "you invent the world." No human face as the focal point; if a figure appears, an older child (about 10 to 11) seen small and from behind, looking outward at the possibilities.
Style: soft painterly magical-realism, consistent with existing scenario card art; cinematic depth, gentle rim-light. Mood: wonder, agency, possibility — adventurous not babyish. Colors: deep indigo and violet base with warm gold and aurora accents.
Background: full-bleed, 16:9 framing with a darker lower third for caption legibility. Aspect ratio: 360:220.
Requirements: age-appropriate, friendly, clear, high readability, app-ready.
Avoid: any text or lettering inside the image, clutter, uncanny realism, unsafe objects, mature or frightening themes, toddler/picture-book cuteness, pastel-only palettes.
```

**S-02b — "Life Quest" (feelings) tile, Adventurer-tuned**
```
Create a full-bleed scene illustration for a child-facing app, age band Adventurer 9 to 11.
Subject: a calm, brave moment of emotional mastery — a lone older child (about 10) standing steady on a small rock as gentle storm-clouds and rolling waves pass around them, a break of warm sunlight appearing; conveys "you can ride your feelings, not be swept away." Hopeful, in-control, never distressed.
Style: soft painterly magical-realism matching existing scenario cards; cinematic, gentle rim-light. Mood: steady, hopeful, quietly heroic. Colors: teal and slate-blue clouds with warm amber sunbreak accents.
Background: full-bleed, darker lower third for caption legibility. Aspect ratio: 360:220.
Requirements: age-appropriate, friendly, clear, high readability, app-ready.
Avoid: any text or lettering inside the image, clutter, uncanny realism, scary or threatening storm imagery, tears or visible distress, toddler cuteness, mature themes.
```

**S-03 (optional) — small emotion cue icon for the Life Quest tile**
```
Create a small transparent-PNG icon for a child-facing app, age band Adventurer 9 to 11.
Subject: a simple, friendly emblem for an emotions/feelings quest — a stylized wave curling into a calm sun, or a heart-with-compass motif; symbolic, not a face.
Style: clean flat-with-soft-gradient, consistent with existing app iconography; single clear silhouette. Mood: calm, encouraging. Colors: gold and teal on transparent.
Background: transparent PNG with alpha. Aspect ratio: 1:1.
Requirements: age-appropriate, friendly, clear, high readability at small size, app-ready.
Avoid: any text or lettering inside the image, clutter, uncanny realism, mature or frightening themes, busy detail that fails at 24px.
```

---

## Final Checklist

Do these first, in order:

1. **S-01** — Bump tile description to 3 lines + slightly taller tile aspect, and shorten each Adventurer scene `description` to ≤9 words so no hook truncates. *(Autonomous; ~30 min.)*
2. **S-04** — Add top spacing / verify scroll inset so "Choose your setting" isn't clipped against the stepper. *(Autonomous; ~10 min.)*
3. **S-07** — Nudge the bottom scrim on bright tiles for description contrast. *(Autonomous; ~10 min.)*
4. **S-03** — Lead the Life Quest description with its purpose ("About big feelings…"); decide on an emotion icon. *(Founder input on icon.)*
5. **S-02** — Approve art direction and generate the two Adventurer-tuned scene images (Imagine It + Life Quest). *(Founder taste call.)*
6. **S-05** — Decide confirm-on-exit vs hide section tabs during the wizard. *(Founder UX call.)*

---

## Verdict (≤300 words)

**Per-lens delight:** Child **8/10** · Psychologist **7/10** · Parent **8/10**.

This is a well-aimed screen for 9–11 on the dimensions you control in code: the choice count (5) respects working-memory limits, the copy lands at the right reading level, tap targets and tactile feedback are excellent, and "Imagine It" hits this band's craving for creative agency dead-on. There are zero dark patterns — no price, urgency, or upsell — and the parent-gate is present, so trust is high.

Two things hold it back from great, and both are the same story: the screen *says* 9–11 but *looks* 6–8. First, the one-line world hooks — the feature added specifically so a 9-year-old can choose well — truncate mid-word ("paint it bac…"), so the payoff is cut off exactly where it matters. Second, the art (especially the young-child Imagine It card) reads babyish for this band, and the band-shift check confirms it: the imagery genuinely fits Explorer, not Adventurer. An 11-year-old, and the parent of one, will feel that mismatch.

**Top three highest-impact fixes:**
1. **Stop truncating the hooks** — 3 lines + taller tiles + tighter ≤9-word copy (autonomous, today).
2. **Re-tune the art older** — replace the picture-book Imagine It/Life Quest imagery with the Adventurer-tuned Imagen scenes above (founder taste call).
3. **De-crowd the header + protect wizard progress** — fix the clipped title and add a confirm-on-exit so the top tabs aren't a mid-flow trap.

Land #1 and #2 and this screen moves from a 7 to a confident 9 for the band.

*Frame: these are levers toward a more delightful, age-true experience — the foundation here is already strong.*
