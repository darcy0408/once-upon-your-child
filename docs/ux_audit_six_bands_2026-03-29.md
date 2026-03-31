# Six-Band UX Audit — Story Weaver
**Date:** 2026-03-29
**Method:** Live browser walkthrough via Playwright (headless Chromium, http://localhost:8088, Flutter dev build)
**Bands tested:** Sprout (age 4), Explorer (age 7), Adventurer (age 10), Creator (age 13), Adult (age 18+)
**Note:** Adolescent (15-17) shares the identical UI as Creator (13-14) — see Finding #5 below.

---

## Screenshots

All screenshots saved to `docs/ux_audit_2026-03-29/`.

| File | Band | Screen |
|------|------|--------|
| `s00_name_entry.png` | All | Name entry |
| `s01_age_gate.png` | All | Age gate |
| `s02_sprout_consent.png` | Sprout | COPPA consent |
| `sprout_01_hero_name.png` | Sprout | Wizard step 1 — name+gender |
| `sprout_02_hero_style.png` | Sprout | Wizard step 1 — archetypes |
| `sprout_03_avatar_dialog.png` | Sprout | Avatar method chooser |
| `sprout_04_avatar_gallery.png` | Sprout | Avatar gallery |
| `sprout_05_avatar_detail.png` | Sprout | Avatar detail / customise |
| `sprout_06_companions.png` | Sprout | Companions (missing images) |
| `sprout_07_world.png` | Sprout | World selection |
| `sprout_08_world_selected.png` | Sprout | World selected state |
| `sprout_09_story_style.png` | Sprout | Story style (2 modes) |
| `sprout_11_review.png` | Sprout | Review screen |
| `explorer_01_age_gate.png` | Explorer | Age gate (same as Sprout) |
| `explorer_02_consent.png` | Explorer | COPPA consent (age 7) |
| `explorer_03_hero_step.png` | Explorer | Wizard step 1 — hero |
| `explorer_04_companions.png` | Explorer | Companions (7, images working) |
| `explorer_05_world.png` | Explorer | World selection |
| `explorer_06_story_style.png` | Explorer | Story style (4 modes + quick-picks) |
| `explorer_07_review.png` | Explorer | Review (Dragon image 404) |
| `adventurer_01_hero.png` | Adventurer | Wizard step 1 — mature character art |
| `adventurer_02_avatar_gallery.png` | Adventurer | Avatar gallery |
| `adventurer_03_companions.png` | Adventurer | Companions (same 7 as Explorer) |
| `adventurer_04_world.png` | Adventurer | World selection (richer names) |
| `adventurer_05_story_style.png` | Adventurer | Story style (genre twists + free text) |
| `adventurer_06_review.png` | Adventurer | Review (Owl image 404) |
| `creator_01_build_story.png` | Creator | Accordion UI — character & role |
| `creator_02_personality.png` | Creator | Personality sliders |
| `creator_03_world_setting.png` | Creator | World & setting options |
| `adult_01_build_story.png` | Adult | Accordion UI — adult avatar style |

---

## Band-by-Band Summary

### Sprout (age 3–5)
**Progress labels:** My Hero! / My Buddies! / My World! / Make Magic!
**Distinctive features:**
- Voice-first name entry ("Tap to say your name!" + microphone button)
- Large Pixar-style 3D gender portraits
- Step 1 shows name field first, then gender selection triggers archetype/avatar flow
- 4 archetypes with full illustrated tiles; avatar gallery opens on archetype tap
- 4 companions: Fluffy Dragon, Magic Bunny, Shining Puppy, Robin
- 4 worlds: Rainbow World, Under the Sea!, Stomp with the Dinosaurs!, Big Feelings
- 2 story modes: Story Quest, Listen & Learn (animated orbs)
- Review: "Your Adventure Awaits!" — glowing hero portrait with world ring

### Explorer (age 6–8)
**Progress labels:** Pick Hero / Pick Team / Pick Place / Make Magic!
**Distinctive features:**
- "Create Your Hero!" with personalised "HI MAX!" greeting
- Two-step hero flow: pick look → pick archetype (guarded by "Choose a look first" gate)
- 7 companions (up from 4 for Sprout): Dragon, Wise Owl, Shadow Cat, Star Dog, Unicorn, Clever Fox, Robin
- Different world set: Rainbow World, Cave Full of Crystals, Friendly Dragons, Big Feelings
- 4 story modes: Story Quest, Rhyme Time, Pick a Path, Easy Reader + 4 quick-pick specials
- Review: story length selector (Short tale / Story time / Big adventure) visible on review card

### Adventurer (age 9–11)
**Progress labels:** My Character / My Companions / My Setting / Start Adventure!
**Distinctive features:**
- Character art shifts to game-hero style (older, gear/tech aesthetic)
- Archetype names have full descriptions: "Solves tricky puzzles and brain teasers"
- New archetype: The Quiz Whiz (replaces Animal Whisperer from Sprout)
- World names become poetic: "The Land of Vanishing Colors", "The Crystal Cavern of Echoes"
- 3 story modes + 6 genre twists (Mystery / Comedy / Sci-Fi / Action / Spooky / Romance)
- Free-text prompt field: "Anything special you want?" with voice input
- Review renamed: "Review Your Adventure" (vs "Your Adventure Awaits!" for younger)

### Creator (age 12–14) & Adolescent (age 15–17) — SHARED UI
**Progress labels:** Character / Companions / Setting / Create Story
**Distinctive features:**
- Completely different design paradigm: accordion form layout ("Build Your Story")
- All-caps section labels; flat illustrated avatar art (not 3D Pixar)
- Single-page form with expandable sections vs wizard steps
- 4 personality sliders: Energy Level, Social Style, Constructive Logic, Adventure Tolerance
- 6 archetypes using professional naming: STORM VANGUARD, LOGIC ARCHITECT, VISION ARCHITECT, HARMONY MEDIATOR, KINETIC SPECIALIST, ECOLOGICAL WHISPERER
- 13 world presets with evocative names (THE TEMPORAL THRESHOLD, THE BIOLUMINESCENT DEPTHS, etc.) + CUSTOM PREMISE
- Bottom nav: "Feelings Garden" (not just "Feelings") + "My Characters"
- No COPPA consent (correct behaviour for 13+)

### Adult (age 18+)
**Progress labels:** Pick Hero / Pick Team / Pick Place / Begin
**Distinctive features:**
- Same accordion form as Creator/Adolescent
- Avatar illustrations more realistic/adult in appearance
- Final step labeled "Begin" (vs "Create Story" for teens)
- No COPPA consent

---

## Six Hats Analysis

### 🤍 White Hat — Facts & Data

**What was observed objectively across all 5 sessions:**

| Dimension | Sprout | Explorer | Adventurer | Creator/Adolescent | Adult |
|-----------|--------|----------|------------|-------------------|-------|
| Wizard paradigm | Step-by-step | Step-by-step | Step-by-step | Accordion form | Accordion form |
| Progress steps | 4 | 4 | 4 | 4 | 4 |
| Companion count | 4 | 7 | 7 | (separate step) | (separate step) |
| Story modes | 2 | 4 + 4 quick-picks | 3 + 6 genres | (Story Options section) | (Story Options section) |
| World presets | 4 | 4 | 4 | 13 | 13 |
| Avatar style | 3D Pixar | 3D Pixar | 3D Pixar | Flat illustrated | Realistic illustrated |
| COPPA consent | Yes (child) | Yes (child) | Yes (child) | No | No |
| Free-text prompt | No | No | Yes | Yes | Yes |
| Voice input visible | Yes | Audio button | Audio button | Audio button | Audio button |
| Personality sliders | No | No | No | Yes (4) | Yes (4) |

**Errors logged by the browser during testing (all bands):**
- 45–60 console errors per session (mostly network failures: `htt/auth/anonymous`, `htt/tts/synthesize` — expected in dev with no backend connection)
- Missing asset 404s: see Bug Report section below
- RenderFlex overflow: `A RenderFlex overflowed by 44–58 pixels on the right` — triggered every time the avatar gallery or archetype customise screen opened

---

### 🟡 Yellow Hat — Strengths & What's Working

1. **Age-appropriate escalation is clearly implemented.** The shift from "My Hero! My Buddies!" (Sprout) to "CHARACTER & ROLE / CORE ARCHETYPE" (Creator) is coherent and graduated. Tone, vocabulary, and complexity all scale up meaningfully.

2. **Review screens are the strongest UX moment across all bands.** The glowing hero portrait inside the world-labelled ring, plus companion icons below, creates a delightful sense of "this is MY story" before generation begins. The story-length selector on the review card (Explorer+) is clever placement.

3. **Voice-first design for Sprout is excellent.** The giant microphone button and "Tap to say your name!" copy are appropriately primary for pre-readers. The audio read-aloud button on question headings is present on all bands.

4. **Companion pool expansion (4 → 7) for Explorer is well-executed.** The illustrated companion icons are charming and the descriptive taglines ("Quiet mind, clear sight." for Wise Owl) add personality appropriate to the age.

5. **Creator/Adult accordion form is a genuine paradigm shift**, avoiding the "this feels like a toy" aesthetic for older users. Personality sliders and professional archetype names (LOGIC ARCHITECT, ECOLOGICAL WHISPERER) signal sophisticated story control.

6. **COPPA consent implementation is thorough.** Full data disclosure, optional email, photo-consent toggle, clear third-party disclosures. Consent records the specific child age in the text ("Your child (age 7)"). The checkbox correctly stays disabled until the user scrolls and checks.

7. **Genre twist system for Adventurer+ unlocks real creative latitude.** Six genre chips (Mystery, Comedy, Sci-Fi, Action, Spooky, Romance) let kids steer tone without exposing them to text fields.

8. **Avatar gallery Shuffle button** gives Sprout/Explorer users replayability and delight.

9. **World thumbnails** (Explorer–Adventurer) are visually rich and immediately communicate setting mood — the "Cave Full of Crystals" image is a standout.

---

### 🖤 Black Hat — Risks & Problems

#### Critical Bugs

**BUG-01: Sprout companion images all 404**
- Assets: `assets/images/companions/sprout/fluffy_dragon_normal.png`, `magic_bunny_normal.png`, `shining_puppy_normal.png`, `robin_normal.png`
- Result: Companion picker shows empty grey circles with paw placeholder icons.
- Impact: **High** — Sprout is the most visually dependent band (pre-readers rely on images). Selecting a companion by its image is the entire UX.

**BUG-02: Companion images 404 on review screen (Explorer & Adventurer)**
- Assets: `assets/images/companions/dragon.jpg`, `assets/images/companions/owl.jpg`
- Result: Review screen shows a broken red-X circle next to the companion name.
- Impact: **High** — The review screen is the emotional peak before story generation. A broken image here undermines confidence.

**BUG-03: RenderFlex overflow in avatar gallery**
- All bands; overflow: 44–58px on the right edge; yellow/black engineering stripe visible to users
- Location: `lib/screens/.../custom_avatar_screen.dart:317` (Row inside gallery item)
- Impact: **Medium** — Layout glitch visible on every gallery open. Does not block flow but signals unpolished state.

**BUG-04: CORE ARCHETYPE checkboxes render blank in Creator/Adult**
- The 6 archetype checkboxes (STORM VANGUARD, etc.) have no visible text in screenshots — only blank white boxes appear
- Likely cause: Custom checkbox widget rendering issue, possibly font or color conflict in the flat-illustrated theme
- Impact: **Critical for Creator/Adult** — Users cannot see what they are choosing.

**BUG-05: Story style orbs not clickable (Sprout)**
- Playwright `locator.click` times out on story orbs: "element is not stable"
- Likely cause: CSS animation on the orbs prevents stable hit-testing
- Impact: **Medium** — Intermittent tap failures; especially problematic for Sprout users who may tap multiple times

#### UX Issues

**UX-01: Age gate cannot distinguish Creator (12-14) from Adolescent (15-17)**
- The age gate has a single "13-17" button. Both bands map to the identical UI.
- Backend has separate `creator` (11-13) and `adolescent` (15-18) band keys, but the frontend collapses them.
- Impact: Adolescent users (15-17) never get the Adolescent-specific content.

**UX-02: Consent "Give Permission" starts disabled — no scroll-progress indicator**
- Parents must scroll the entire consent form before the button enables, but there's no indicator that scrolling is required.
- Impact: Parents may tap the grey button, see nothing happen, and assume the app is broken.

**UX-03: Avatar gallery RenderFlex overflow also clips "Create a custom avatar" button**
- The bottom CTA "Create a custom avatar that looks like me!" is partially clipped by the overflow stripe on the right.
- Impact: Parents attempting the AI avatar feature may miss/misread the button.

**UX-04: Sprout step 1 flow inconsistency — gender picker triggers archetype, not explicit Next**
- Tapping "Girl"/"Boy" immediately transitions to the archetype/style screen without a clear Next action. This worked, but the semantic trigger is surprising.
- Impact: Low for Sprout (parents handle this step), but non-obvious.

**UX-05: Bedtime mode label is long on mobile**
- "Start bedtime story mode. Voice only, no screen needed. Bedtime" — the accessibility label is verbose and the button is small in the nav bar.
- Impact: Low — nav item is secondary; voice narration error in dev (TTS 404) means this cannot be tested end-to-end.

**UX-06: Explorer companion images work in picker but Dragon/Owl 404 on review**
- Different asset paths are used between the companion picker and the review screen, creating inconsistent image loading.
- Impact: Medium — the review screen is the most important moment for the user's emotional connection.

---

### 🔴 Red Hat — Emotional Response

**As a Sprout (age 4) experience:** The "Pick your buddies!" screen with empty grey circles where Fluffy Dragon should be is genuinely disappointing. A 4-year-old who chose the dragon because they love dragons will feel confused and let down. The review screen (which loads a different, working image) partially recovers — but the picker is where the choice is made.

**As an Explorer (age 7) experience:** The wizard flow feels engaging and age-right. "HI MAX!" is a lovely personalization touch. The genre quick-picks on the story screen ("🐉 Dragon helper", "🌈 Rainbow world") are fun and well-emoji'd. The review screen with the broken Dragon companion image is jarring — it happens at exactly the moment when excitement peaks.

**As an Adventurer (age 10) experience:** The shift to adventure-action character art feels earned. The genre twist system (Mystery, Comedy, Sci-Fi...) unlocks the kind of ownership a 10-year-old craves. The free text "Anything special you want?" is a genuine creative invitation. Overall: this band feels the most complete.

**As a Creator/Adolescent (age 13-17) experience:** The accordion form signals "this is serious creative work", which will resonate with older teens. However, blank CORE ARCHETYPE checkboxes (Bug-04) mean the most distinctive feature of this band is entirely non-functional. A teen seeing blank boxes will not wait — they will assume the app is broken.

**As an Adult (age 18+) experience:** The more realistic avatar portraits are appropriately grown-up. "Begin" as the final CTA feels intentional and neutral — less juvenile than "Make Magic!" without feeling cold. The accordion depth (personality sliders, 13 world presets) satisfies adults who want control. The blank archetype checkboxes problem persists here too.

---

### 🟢 Green Hat — Creative Opportunities

1. **Sprout: Add an animated companion "peek" on the picker.** While images load (or as fallback), play a short wiggle animation with the companion's name in large friendly text. This turns asset failures from disappointment into curiosity.

2. **Explorer: Make the "Pick something special!" quick-picks toggleable on the review card.** If a user picked "Dragon helper" as their theme, show a small badge on the review card — letting them feel their choice is remembered and meaningful.

3. **Adventurer: Combine genre twist + free text on the world selection step** (not a separate step 4). Selecting "The Volcano of Sleeping Dragons" could auto-suggest "Action" and "Spooky" genre chips, streamlining the flow.

4. **Creator: Replace blank checkbox grid with a visual card selection** (same pattern as younger bands' archetype tiles, but with the sophisticated UPPERCASE naming). The personality sliders are a strength — the archetype picker should match their quality.

5. **All bands: Add a "change your mind" affordance from the review screen.** Currently, the review screen shows tappable summary chips (with "Double tap to edit"). Consider making each item visually tap-target-clear with a pencil icon that's always visible, not screen-reader-only.

6. **Age gate: Split the "13-17" button into two** — "13-14" and "15-17" — to properly activate the Creator vs Adolescent bands. The difference in story content (per backend band keys) justifies this.

7. **Consent screen: Add a scroll-progress indicator.** A simple "Scroll to continue ↓" hint appearing after 3 seconds, disappearing once the user scrolls past 80%, would eliminate the disabled-button confusion.

8. **Universal: Use the review screen as a "share preview" moment.** The glowing hero portrait is already social-media-ready. A "Save preview" button that generates the review card as a PNG could drive organic sharing and word-of-mouth.

---

### 🔵 Blue Hat — Process & Priorities

**Recommended Action Plan by Priority:**

| # | Finding | Band(s) | Severity | Type | Action |
|---|---------|---------|----------|------|--------|
| 1 | BUG-01: Sprout companion images 404 | Sprout | 🔴 Critical | Bug | Add missing asset files for sprout/fluffy_dragon_normal.png, magic_bunny_normal.png, shining_puppy_normal.png, robin_normal.png |
| 2 | BUG-04: Archetype checkboxes blank | Creator, Adult | 🔴 Critical | Bug | Debug CORE ARCHETYPE checkbox widget text rendering in flat/dark theme |
| 3 | BUG-02: Companion images 404 on review | Explorer, Adventurer | 🔴 High | Bug | Align asset paths between companion picker and review screen |
| 4 | UX-01: 13-17 age gate merges Creator+Adolescent | Creator, Adolescent | 🟠 High | UX | Split "13-17" button into "13-14" and "15-17" |
| 5 | BUG-03: RenderFlex overflow in avatar gallery | All | 🟡 Medium | Bug | Wrap Row in Flexible/Expanded in gallery item widget |
| 6 | UX-02: Consent button disabled without scroll hint | All <13 | 🟡 Medium | UX | Add "Scroll to continue ↓" indicator |
| 7 | BUG-05: Story orbs not stably tappable (Sprout) | Sprout | 🟡 Medium | Bug | Reduce animation duration or add `ValueKey` for stability |
| 8 | UX-03: CTA clipped by overflow in gallery | All | 🟡 Medium | UX | Fixed as part of BUG-03 fix |
| 9 | UX-05: Bedtime button label verbose | All | 🟢 Low | UX | Shorten semantic label to "Bedtime mode" |

---

## Cross-Band Consistency Assessment

| Element | Consistent? | Notes |
|---------|-------------|-------|
| Purple/gold color scheme | ✅ Yes | All bands share base palette |
| Progress bar location | ✅ Yes | Top of screen, always 4 steps |
| Close (X) button | ✅ Yes | Top left, all bands |
| Feelings nav | ✅ Yes | Always present; label shifts ("Feelings" → "Feelings Garden") |
| Bedtime mode | ✅ Yes | All bands |
| Avatar gallery UI | ✅ Yes | Same gallery widget, same overflow bug |
| COPPA consent | ✅ Yes | Shown for ages <13, hidden for 13+ |
| Review screen | ⚠️ Partial | Younger bands: hero portrait ring. Creator+: different (not observed — wizard ends at form) |
| Archetype naming | ❌ Diverges | Sprout: "The Animal Whisperer"; Creator: "ECOLOGICAL WHISPERER" — same concept, completely different presentation |
| Voice input | ✅ Yes | Audio icon present on all bands (TTS 404 in dev is expected) |

---

## Key Metrics

- **Total screens captured:** ~30 screenshots across 5 bands
- **Unique bugs identified:** 5
- **UX issues identified:** 6
- **Bands with broken images:** 3 of 5 (Sprout, Explorer, Adventurer)
- **Bands with functional complete flow:** Adventurer is the most complete; Explorer second
- **Most polished band:** Adventurer (age 9-11) — all features visible, no critical bugs
- **Most compromised band:** Creator/Adult — critical blank archetype checkboxes + merged age bands
- **Sprout readiness:** Blocked on BUG-01 (missing companion images) — **not launch-ready as-is**
