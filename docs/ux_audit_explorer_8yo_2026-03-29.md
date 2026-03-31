# Children's App UX Audit — Explorer Band (Age 8)
**Date:** 2026-03-29
**Method:** Live screenshot walkthrough via Playwright + code review
**Persona:** 8-year-old child, independent user (parent nearby but not co-operating)
**Band tested:** Explorer (ages 6–8)
**Screenshots folder:** `docs/ux_audit_2026-03-29/` (explorer_01–07) and `docs/usability_2026-03-29/` (explorer_01–08)

---

## Flow Observed

| Step | Screen | Screenshot |
|------|--------|-----------|
| 1 | Age gate — number picker | `explorer_01_age_gate.png` |
| 2 | Parental consent | `explorer_02_consent.png` |
| 3 | Hero creator — gender pick | `explorer_03_hero_step.png` |
| 4 | Hero creator — archetype pick | `usability/explorer_01_archetypes.png` |
| 5 | Companions | `explorer_04_companions.png` |
| 6 | World selection | `explorer_05_world.png` |
| 7 | Story type | `explorer_06_story_style.png` |
| 8 | Review / launch | `explorer_07_review.png` |

---

## 🤍 White Hat — Facts I Observed

**Age gate:** Large gold "How old are you?" on purple. Number buttons 2–12 + "14+". No text beyond the prompt. Tapping "8" triggers the flow.

**Parental consent:** Full-screen text wall — "Notice to Parents & Guardians ⭐". Three sections of small body text. No scroll indicator. No skip.

**Hero creator (Step 1 — gender):** Header "CREATE YOUR HERO!" with personalised "HI MAX!" sub-heading. Two illustrated 3D Pixar-style portraits: Boy (left), Girl (right). No other copy. Progress dots visible at top (4 steps).

**Hero creator (Step 2 — archetypes):** Separate screen "PICK YOUR HERO STYLE!" with prompt "Pick what your hero looks like." A "Choose Look" button appears before the archetype grid is accessible. Grid shows 4 cards: The Wave Rider, The Master Creator, The Heart Healer, The Animal Whisperer. Each card has character art + name label.

**Companions:** "PICK YOUR FRIENDS!" header. 7 companion circles in a grid: Dragon, Wise Owl, Shadow Cat, Star Dog, Unicorn, Clever Fox, Robin — each with a label. "Bring a Friend Along" section below with a name + description text field and Add button.

**World selection:** "WHERE TO ADVENTURE?" header. 4 full-bleed illustrated world tiles: Rainbow World, Cave Full of Crystals, Friendly Dragons, Big Feelings. A fifth "✨ Imagine It!" custom option is visible below. Forward arrow button.

**Story type:** "WHAT KIND OF STORY?" header. 4 story mode tiles: Story Quest, Rhyme Time, Pick a Path, Easy Reader. Below: "Pick something special!" row with 4 quick-pick chips: Magic friend (?), Dragon helper, Treasure quest, Rainbow world.

**Review:** "YOUR ADVENTURE AWAITS!" header. Centre: hero portrait inside a glowing world-label ring ("Cave Full of Crystals"). Name "MAX" below. Two companion slots below the ring — both rendered as broken circles (one blank, one shows an × icon). Story length chips at bottom: Short tale / Story time / Big adventure.

**Measured counts:**
- Total tap targets from start to review: approximately 11 (excluding text entry)
- Companion choices: 7
- World choices: 4 (+ 1 custom)
- Story mode choices: 4 + 4 quick-picks
- Story length choices: 3
- Broken images on review: 2 of 2 companion slots

---

## 🟡 Yellow Hat — What's Working Well

### 1. "HI MAX!" Personalised Greeting
The single best moment in the flow. The child's name in large text on the hero screen creates an instant "this is MINE" feeling. An 8-year-old will grin at this. It's warm, direct, and personal without being patronising.

### 2. World Tiles Are Visually Irresistible
The "Cave Full of Crystals" and "Friendly Dragons" world images are beautiful — cinematic, full-bleed, genre-clear at a glance. An 8-year-old should be able to pick a world without reading any label. The images do all the work.

### 3. Seven Companions Is the Right Amount
At age 8, choice feels like power. Seven is just enough to feel like a real selection without tipping into paralysis. The companion grid is well-proportioned and the label names are appropriately fun ("Clever Fox", "Shadow Cat").

### 4. Story Quick-Picks Feel Like Bonus Power
The "Pick something special!" row below the four main story modes is a smart layered design. An 8-year-old who picks "Story Quest" can then also grab "Dragon helper" as a secret extra ingredient — it makes them feel like they made the story more theirs.

### 5. Progress Indicator Present Throughout
The 4-dot progress bar at the top provides a clear sense of how much further to go, even before the child can read it fluently. At age 8 most children can count the dots.

### 6. "Imagine It!" World Option Respects Creative Agency
Putting a free-text "Imagine It!" option at the end of the world list acknowledges that some 8-year-olds have very specific, idiosyncratic ideas ("a world made of pizza"). Not giving this for younger bands is correct; surfacing it for Explorer shows genuine band calibration.

---

## 🖤 Black Hat — Problems and Risks

### CRITICAL

**BUG-C1: Both companion images are broken on the review screen**
The review screen shows two companion circles with broken/missing images (blank circle + × icon) despite the child having selected companions earlier. This is the highest-emotional moment of the entire flow — the payoff screen just before the story generates. Broken images here do real damage. An 8-year-old will say "it's broken" and lose confidence in the app before the story even starts.
*Root cause: review screen uses different asset paths than the companion picker (`assets/images/companions/dragon.jpg` vs the picker path).*

**BUG-C2: Archetype screen is gated behind "Choose Look" with no explanation**
When the child arrives at the archetype step, a "Choose Look" button is shown before the archetype grid is available. There is no explanation of what "Choose Look" does or why it must happen first. The error label reads "Pick your hero look first to choose archetypes." An 8-year-old who taps the archetype cards expecting to pick one will be blocked with a message they may not understand. The two-step gender-then-archetype flow creates a hidden dependency that is invisible in the UI.

### SERIOUS

**UX-S1: Parental consent screen is a wall of text the child must sit through**
The consent screen is addressed entirely to parents ("Notice to Parents & Guardians"). An 8-year-old handed the phone to "do the age thing" will see three dense paragraphs of legal-adjacent text with no visual relief. There is no progress hint that this will end. If a parent is not present, the child is stuck. If a parent is present, it's an awkward interruption of momentum.

**UX-S2: All-caps "HI MAX!" reads as shouting**
"HI MAX!" uses all-caps, which in reading conventions signals raised volume or urgency. While the intent is warm, an 8-year-old who has been told that capital letters mean shouting may subconsciously register this as aggressive. "Hi Max!" (mixed case) would feel friendlier.

**UX-S3: Archetype names skew adult**
"The Master Creator" and "The Heart Healer" are reasonable for age 8, but "The Heart Healer" in particular is an adult self-help framing that may not resonate. The Wave Rider and Animal Whisperer work better at this age because they're action/nature-anchored. The naming tier is not fully calibrated.

**UX-S4: Companion section has an unexpected "Bring Your Companion" text-entry panel**
Below the 7 standard companions, there is a "Bring a Friend Along" section with text fields for a custom companion name and description. For an 8-year-old this may be confusing: "I already picked Dragon, why is there another box?" There's no clear separation between "choose from the list" and "make your own." A divider and brief label ("...or make your own!") would clarify.

### MINOR

**UX-M1: Story Quick-picks have no images**
The main story mode tiles (Story Quest, Rhyme Time, etc.) have illustrated icons. The quick-pick chips below ("Dragon helper", "Rainbow world") are text-only. An 8-year-old reading at grade level will manage, but a small emoji or icon on each chip would make the differentiation faster and more fun.

**UX-M2: "Easy Reader" label may be self-stigmatising**
At age 8, children are acutely aware of reading level differences. A child who is a stronger reader may feel the label "Easy Reader" is beneath them; a child who needs it may not want to select it in front of a sibling or parent. "Read Along" or "Short & Simple" would be less loaded.

**UX-M3: Review screen story-length chips are very small**
"Short tale / Story time / Big adventure" are rendered as small text chips at the bottom of the review screen, below the broken companion images. They are easy to overlook, and "Story time" as the default selection may not be obviously the middle option. An 8-year-old may not notice these chips exist.

**UX-M4: Forward arrow button styling provides no feedback state**
The gold "→" circle button to advance through steps shows no loading/disabled state. If the child taps it before selecting a world (for example), they receive a brief error, but there's no pre-emptive affordance (like the button greying out until a selection is made) to signal that a selection is needed first.

---

## 🔴 Red Hat — How It Feels to Be 8 Years Old Here

**The age gate moment:** Fast, easy, satisfying. Tapping your own age number is genuinely fun. ✅

**The consent screen moment:** Sudden stop. The energy drops to zero. A child alone with the phone will probably just hand it to a parent or try tapping things randomly to make it go away. Even with a parent, this feels like homework inserted into playtime. ❌

**The "HI MAX!" moment:** Genuine delight. "It knows my name!" This is a hit. ✅

**The "Choose Look" blocker:** Confusion. "I wanted to pick the Wave Rider but it's not letting me." A patient 8-year-old reads the message and finds the Choose Look button. An impatient one taps several times before noticing. Either way, the joy deflates slightly. ⚠️

**Picking a world:** Pure joy. The images are gorgeous. Tapping "Cave Full of Crystals" feels like an adventure is starting. ✅

**The quick-pick story specials:** Discovery delight. "Oh wait, there's also Dragon helper?! I want that too." The layered system rewards exploration. ✅

**The review screen (with broken companion images):** Crushing. The setup — glowing hero in a world ring, name displayed, your choices reflected back — is designed to be an emotional peak. The broken companion circles land like a cold shower. "My dragon is broken." An 8-year-old who chose Dragon because they love dragons is specifically let down by the one companion image that's missing. This is the most damaging UX failure in the flow. ❌❌

---

## 🟢 Green Hat — Ideas and Opportunities

### Fix-adjacent improvements (easy wins)

1. **Companion image fallback with character name in large text:** When the companion image fails to load, show the companion's emoji + name in a friendly pill (e.g. "🐉 Dragon") instead of a grey circle or ×. Costs nothing, prevents deflation.

2. **"Choose Look" → inline gender picker on the archetype step:** Collapse the two-step gender-pick + archetype into a single screen. At the top: two small portrait thumbnails (Boy / Girl) as a toggle. Below: the archetype grid, which activates immediately on selection. No separate screen, no gate message.

3. **"HI Max!" in mixed case:** One-character change. Removes the "shouting" association. Bigger warmth impact than it sounds.

4. **Rename "Easy Reader" → "Read Along":** Removes the self-stigma risk with zero loss of clarity.

5. **Quick-pick chips with emoji icons:** Add one emoji per chip (🐉 Dragon helper, 🌈 Rainbow world, 💎 Treasure quest, ✨ Magic friend). Two minutes of work, substantially more scannable.

### Enhancement opportunities

6. **Companion preview tap:** Let the child tap a companion icon to hear a short sound or TTS description ("Dragon: breathes fire and loves adventure!") before selecting. Explorer-band children are old enough to read labels but the audio layer adds delight and reduces "wrong choice" anxiety.

7. **Review screen "edit" affordance:** On the review card, make each choice chip (world name, companion, story type) visibly tappable with a small ✏️ icon. "Oh wait I want Friendly Dragons instead of Cave Full of Crystals" — an 8-year-old should be able to go back without losing everything else.

8. **Story length on the hero step, not the review step:** Move "Short tale / Story time / Big adventure" earlier (perhaps on the story type step). By the time a child reaches the review, they are ready to LAUNCH — asking for another decision here adds friction at exactly the wrong moment.

9. **Consent screen: parallel child-facing version:** While the parent reads the consent form, show the child a simple waiting screen: "Asking a grown-up for permission... 🔐" with a fun animation (star spinning, etc.). This keeps the child engaged and clearly signals who the consent form is for.

10. **"Imagination It!" prompt placeholder:** The Imagine It world text field currently has no placeholder text. Adding "Tell me your world... 🌍" as a hint makes the blank field feel inviting rather than blank.

---

## 🔵 Blue Hat — Priorities and Next Steps

### Summary judgment
The Explorer band flow is fundamentally sound. The concept, the escalation from Sprout, the personalization, and the world/story variety are all age-appropriate and well-executed. Two failures — the broken companion images and the archetype gate confusion — prevent a child from experiencing the flow as intended.

### Action plan

| # | Issue | Severity | Effort | Action |
|---|-------|----------|--------|--------|
| 1 | BUG-C1: Companion images broken on review screen | 🔴 Critical | Low | Align asset paths between companion picker and review widget; or use same asset source in both |
| 2 | BUG-C2: "Choose Look" gate blocks archetypes | 🔴 Critical | Medium | Merge gender picker + archetype grid into single step; remove gate message |
| 3 | UX-S1: Consent screen interrupts child momentum | 🟠 High | Medium | Add child-facing waiting screen alongside parent consent form |
| 4 | UX-S2: ALL-CAPS greeting reads as shouting | 🟡 Medium | Trivial | Change "HI MAX!" → "Hi Max!" |
| 5 | UX-S4: Custom companion section confuses layout | 🟡 Medium | Low | Add visible "...or create your own!" divider between standard grid and custom entry |
| 6 | UX-M1: Quick-pick chips are text-only | 🟢 Low | Low | Add emoji per chip |
| 7 | UX-M2: "Easy Reader" self-stigma risk | 🟢 Low | Trivial | Rename to "Read Along" |
| 8 | UX-M3: Story length chips easy to miss | 🟢 Low | Low | Enlarge chips or move length choice to story type step |
| 9 | Green-6: Companion preview audio | 🟢 Enhancement | Medium | TTS description on companion tap |
| 10 | Green-7: Review "edit" affordance | 🟢 Enhancement | Medium | Add ✏️ icon on each review chip |

### Top 3 if only three fixes are possible
1. **Fix companion images on review screen** (BUG-C1) — this is the emotional peak of the product; breaking it breaks trust.
2. **Merge gender + archetype into one step** (BUG-C2) — removes the most common confusion point in the wizard.
3. **Add child waiting screen during consent** (UX-S1) — keeps momentum alive during the only mandatory pause in the flow.

---

*Audit conducted by reviewing live screenshots of the running app (Flutter web dev build). Explorer band activated by tapping "8" on the age gate. Persona name: MAX.*
