# Children's App UX Audit — Adventurer Band (Age 10)
**Date:** 2026-03-30
**Method:** Live screenshot walkthrough + code review
**Persona:** 10-year-old child, independent user, likely using phone or tablet alone
**Band tested:** Adventurer (ages 9–11)
**Screenshots folder:** `docs/ux_audit_2026-03-29/` (adventurer_01–06) and `docs/usability_2026-03-29/` (adventurer_01–03)

---

## Flow Observed

| Step | Screen | Screenshot |
|------|--------|-----------|
| 1 | Age gate | (shared with other bands, not re-screenshotted) |
| 2 | Hero creator — name + gender pick | `adventurer_01_hero.png` |
| 3 | Avatar gallery dialog | `adventurer_02_avatar_gallery.png` |
| 4 | Companions | `adventurer_03_companions.png` |
| 5 | World selection | `adventurer_04_world.png` |
| 6 | Story type + genre twist | `adventurer_05_story_style.png` |
| 7 | Review / launch | `adventurer_06_review.png` |

---

## 🤍 White Hat — Facts I Observed

**Hero creator:** Header "CREATE YOUR HERO!" with "HI MAX!" personalisation. Inline editable name field showing "Sam" — child can change their name directly. Two 3D Pixar-style character portraits: Boy (unselected) / Girl (selected, gold border). Full-bleed purple background. Top navigation bar visible with tabs: Feelings · Heroes · Bedtime + a moon icon. Progress dots at the top.

**Avatar gallery (dialog):** "Choose Your Look ✕" modal overlay. 6 realistic portrait-style avatars in a 3×2 grid — diverse characters, Pixar-quality rendering. Visible gold "Create a custom avatar like you!" CTA chip at the bottom. Images appear to load correctly in this dialog.

**Companions:** "Choose your companions" header, subtitle "Tap a companion name to add them." 7 companion circles: Dragon, Wise Owl, Shadow Cat, Star Dog, Unicorn, Clever Fox, Robin — all with labels. "Find your adventure team!" section label. Below the grid: "Bring a Friend Along" panel with a name field, description field, and Add button. Tiny hint at bottom: "No bio — no companions."

**World selection:** "Choose your world" header, subtitle "Create your own world — or choose our fantasy:" Five world tiles visible: "The Land of Glowing Caves", "The Crystal Canyon (?)", "The Palace of Hanging..." (truncated), "Big Feelings!" — and a full-width "✨ Imagine it" panel at the bottom with placeholder "Describe any world you can dream up."

**Story type + genre:** "Choose your story type" header. Two main tiles: Story Quest, Rhyme Time. A third tile: Pick a Path. Below: "Add a genre twist (optional)" chip row — Mystery, Comedy, Sci-Fi, Action, Spooky. At the very bottom: "Anything special you want?" free-text field.

**Review:** "Review Your Adventure" header. Top: truncated world name "Whispers of Dazzling Ste..." Centre: character avatar circle (Sam, 3D portrait — renders correctly). Name "Sam" below. Two companion slots below: both broken (× icons / blank circles). Story length chips: Short tale / Story time / Big adventure — "Story time" appears pre-selected.

**Measured differences from Explorer band:**
- Name field is now inline-editable (not just displayed)
- Top nav bar introduces persistent Feelings / Heroes / Bedtime tabs
- Avatar gallery is a proper dialog (not a gated page) — 6 portraits
- World tiles have descriptive proper names (not just "Cave Full of Crystals")
- Genre twist chips: 5 options
- Free-text story prompt field added
- Broken companion images: 2 of 2 (same bug as Explorer)
- World name truncated on review screen

---

## 🟡 Yellow Hat — What's Working Well

### 1. Inline Name Editing Is Right for This Age
The editable name field on the hero screen — replacing the read-only "HI MAX!" display from Explorer — is the correct design call for a 10-year-old. Children this age care deeply about customisation and will want to set a unique hero name ("Stormclaw", "Nova") rather than just using their real name. Giving them the field up front says "this is YOUR creation."

### 2. Avatar Gallery Quality Is a Genuine Delight
The Adventurer avatar gallery shows six diverse, Pixar-quality portrait avatars in a clean modal. The characters are expressive and distinct. A 10-year-old will spend genuine time comparing options — which is exactly what you want. The "Create a custom avatar like you!" chip at the bottom correctly positions personalisation as a premium aspirational tier without blocking the flow.

### 3. Genre Twist Chips Are Perfectly Age-Calibrated
The genre chip row (Mystery, Comedy, Sci-Fi, Action, Spooky) is arguably the strongest UX decision in the entire app for this age band. A 10-year-old has developed genre literacy — they know they like Spooky or Sci-Fi from books, TV, and games. Letting them apply a genre twist to their story type creates a combinatorial sense of creative ownership. "Story Quest + Spooky" feels like a completely different product than "Story Quest + Comedy."

### 4. "Anything Special You Want?" Free-Text Prompt
The open text field at the bottom of the story type step is a high-trust move. At age 10, kids can type with reasonable fluency and have specific, vivid ideas ("I want there to be a secret door that leads to a library full of living books"). This field says the app respects them as a capable creative, not just a button-tapper. It differentiates Adventurer meaningfully from Explorer.

### 5. "Imagine It" World Panel Is Prominent and Inviting
The full-width "✨ Imagine it" panel at the bottom of the world screen — with a real placeholder ("Describe any world you can dream up") — treats free imagination as a peer option alongside the curated world tiles. Its size and placement signal it's a first-class choice, not an afterthought. A 10-year-old who wants to set their story in "a school inside a volcano" will feel seen.

### 6. World Tiles Have Evocative Proper Names
"The Land of Glowing Caves", "The Crystal Canyon", "The Palace of Hanging..." — these are longer, more literary world names than Explorer's simpler "Cave Full of Crystals." For a 10-year-old reader, the richer phrasing triggers imagination immediately. The descriptive nouns feel like the first line of a book.

---

## 🖤 Black Hat — Problems and Risks

### CRITICAL

**BUG-C1: Companion images broken on the review screen (same bug as Explorer)**
Both companion slots on the review screen show × icons / blank circles — the same asset-path bug from the Explorer band. The bug is unchanged across bands, which suggests it's systemic (the review widget uses different paths than the companion picker). The emotional cost is identical: the payoff screen is broken at exactly the moment it should feel triumphant.

**BUG-C2: World name is truncated on the review screen**
The selected world "Whispers of Dazzling Ste..." is cut off mid-word on the review screen. A 10-year-old who specifically chose this world because of its evocative full name will notice the truncation and may feel the app didn't honour their choice. The card simply needs a smaller font or two-line overflow for long world names.

### SERIOUS

**UX-S1: "No bio — no companions" is a hidden penalty condition**
The hint at the bottom of the companion screen reads "No bio — no companions." This implies that if the child doesn't fill in the custom companion text fields, their chosen companions won't appear in the story. But the hint is in tiny text, positioned below the fold, and likely invisible to most users. A 10-year-old who taps Dragon and Wise Owl and moves on — without writing a bio — may receive a story with no companions in it and have no idea why.

If this is enforced: it needs a clear visual gate (a counter like "Dragon added ✓ | Add bio to include them"). If it's not actually enforced: remove the hint because it creates false anxiety.

**UX-S2: The persistent top nav bar is unexplained and distracting**
The Adventurer band introduces a top navigation bar with Feelings / Heroes / Bedtime tabs (plus a moon icon). This is a significant architectural addition. But it appears at the very start of the wizard flow without explanation — a 10-year-old mid-wizard will notice the "Feelings" tab and wonder "what happens if I tap that?" Tapping it during wizard setup could break the flow or lose progress. There is no "you're in wizard mode" indication that suppresses the nav or explains its context.

**UX-S3: Five genre chips with no visual differentiation**
The genre twist chips (Mystery, Comedy, Sci-Fi, Action, Spooky) are text-only pills with identical styling. For a 10-year-old who has strong genre preferences, the chips feel flat — there's no sense of what each will do to the story. A small thematic icon per chip (🔍 Mystery, 😂 Comedy, 🚀 Sci-Fi, ⚔️ Action, 👻 Spooky) would make the selection feel more like a real creative decision.

**UX-S4: Companion section has two parallel input paths with no guidance**
Identical issue to Explorer: the standard 7-companion grid sits above the custom "Bring a Friend Along" input panel with no visual separator. For a 10-year-old who wants to add a custom companion, the flow is "I need to type a name AND a description AND tap Add — but I've already tapped Dragon from the grid." The relationship between the two mechanisms is unclear.

### MINOR

**UX-M1: "Pick a Path" story mode has no description or preview**
Story Quest and Rhyme Time have at least implicit descriptive names. "Pick a Path" is a distinct format (choose-your-own-adventure branching) that requires explanation — a 10-year-old who hasn't encountered the term before may not understand what it means. A one-line subtext or brief tooltip would help ("You decide what happens next at every turn!").

**UX-M2: Genre chips allow multi-select but give no confirmation of combination**
It's unclear from the screenshots whether genre chips can be multi-selected. If they can (e.g. Sci-Fi + Spooky), there's no visible feedback showing the combined genre will be used — no "Your story: Story Quest + Sci-Fi + Spooky" confirmation on the review screen. If they can't be multi-selected, the tap behaviour should deselect the previous chip visibly.

**UX-M3: Story length chips on review screen still easy to miss**
Same issue as Explorer: "Short tale / Story time / Big adventure" chips are small and positioned below the companion image area. On Adventurer they're doubly easy to miss because the broken companion images immediately above draw the eye negatively.

**UX-M4: "Create a custom avatar like you!" CTA goes nowhere visible in the flow**
The gold upsell chip in the avatar gallery opens the BYOK (Bring Your Own Key) premium setup wizard. A 10-year-old who taps it may not understand the concept of API keys. The button label promises "an avatar like you" — if it leads to a technical setup screen, the mismatch between promise and delivery will cause frustration or distrust. A brief "Ask a grown-up to help set this up!" intermediate step would preserve the delight without the confusion.

---

## 🔴 Red Hat — How It Feels to Be 10 Years Old Here

**Typing your hero name:** This feels great. "I get to name my character whatever I want!" A 10-year-old will likely spend 30+ seconds deliberating here, trying different names. The inline field makes this feel like the start of a real creative project. ✅

**Choosing your avatar:** The gallery modal is visually striking. A 10-year-old will scroll through all six, maybe go back and forth. "Can I make one that actually looks like me?" — the CTA promises yes, which is exciting even if setup is complex. ✅

**Choosing companions:** The Dragon and Wise Owl circles are selected, but then — "No bio — no companions"? A 10-year-old who reads this at the bottom will feel anxious: "Do I have to write a whole bio? Can I just pick them?" The anxiety grows proportionally with how much they care about having companions in their story. ⚠️

**Choosing a world:** The world tiles are cinematic and rich. "The Land of Glowing Caves" hits differently than "Cave Full of Crystals" — it sounds like a real place. A 10-year-old who loves Minecraft-esque worlds or fantasy books will immediately know what they want. The "Imagine it" box at the bottom invites ambitious elaboration. ✅✅

**The genre twist moment:** This is the best screen in the flow for a 10-year-old. "Spooky story quest" — the combination feels invented by them, not the app. This is the exact feeling that makes a creative tool addictive. If only the chips had icons. ✅✅

**The review screen:** Momentum peaks, then the × companion icons land. "Why are they broken?" For a 10-year-old, this feels like being handed a present and opening it to find half the items missing. The world name truncation compounds this: "Whispers of Dazzling Ste..." doesn't sound like the world they chose. The launch CTA is there but the emotional wind is gone. ❌❌

---

## 🟢 Green Hat — Ideas and Opportunities

### Fix-adjacent improvements

1. **Companion image fallback with emoji + name pill** (same fix as Explorer): When companion images fail on review, show `🐉 Dragon` and `🦉 Wise Owl` text pills. Trivial cost, prevents the review-screen deflation.

2. **World name two-line overflow on review card**: Allow the world name label to wrap to a second line or reduce font size for strings over ~25 characters. The full evocative name is a selling point — don't truncate it.

3. **"No bio — no companions" → visible companion counter**: Replace the buried hint with a visible per-companion status: `Dragon ✓ · Wise Owl ✓ · (add a bio to include them →)`. Make it clear whether bio is required or optional.

4. **Genre chip icons**: Add one emoji per chip (🔍 🎭 🚀 ⚔️ 👻). Makes the row scannable and more expressive in 30 seconds of work.

5. **"Pick a Path" one-line description**: Add a sub-label "You choose what happens at every turn!" under the tile title.

### Enhancement opportunities

6. **Genre combination confirmation on review screen**: Show the active combination as a small badge on the review card — e.g. `📖 Story Quest · 👻 Spooky`. A 10-year-old wants to see their creative assembly reflected back before they commit.

7. **Nav bar wizard-mode indicator**: While in the wizard, visually suppress the Feelings/Heroes/Bedtime tabs or show a "Back to wizard →" indicator so the child knows those tabs are for later, not now. A bottom progress strip ("Step 3 of 6") that replaces or augments the top nav would accomplish both.

8. **Custom avatar "ask a grown-up" bridge screen**: Before opening the BYOK setup flow, show a single intermediate screen: "This one needs a grown-up to set up once! Want to get them? 🧑‍💻" with Continue / Maybe Later. This preserves the delight of the promise without landing a 10-year-old on a technical API setup screen alone.

9. **Story preview chip on world tiles**: A small one-line preview beneath each world tile's image ("Full of bioluminescent fungi, ancient ruins, and glowing rivers") — visible on hover or a brief long-press — would be irresistible to a 10-year-old who wants to feel informed before choosing. Doesn't block quick tappers; rewards explorers.

10. **Saved stories home screen**: The "Heroes" tab in the top nav presumably shows past creations. A 10-year-old who makes a great story will want to come back to it, share it, or build on it. If the Heroes tab is well-designed, this is the feature that turns one-time users into habitual users for this band.

---

## 🔵 Blue Hat — Priorities and Next Steps

### Summary judgment
The Adventurer band design is meaningfully more sophisticated than Explorer — the editable name, the avatar gallery quality, the genre twist system, and the free-text world/story fields are all correctly calibrated for 10-year-old creative agency. The flow respects the child's intelligence. However, the same review-screen bug persists, a new truncation bug appears, and a hidden penalty condition (bio required for companions) undermines the companion selection with no visible warning.

### Action plan

| # | Issue | Severity | Effort | Action |
|---|-------|----------|--------|--------|
| 1 | BUG-C1: Companion images broken on review | 🔴 Critical | Low | Align asset paths between picker and review widget (same fix as Explorer) |
| 2 | BUG-C2: World name truncated on review card | 🔴 Critical | Low | Allow two-line overflow or reduce font on long strings |
| 3 | UX-S1: "No bio — no companions" invisible penalty | 🟠 High | Medium | Replace with per-companion status indicator; clarify whether bio is required or optional |
| 4 | UX-S2: Top nav bar unexplained during wizard | 🟡 Medium | Medium | Add wizard-mode indicator / suppress tabs or show step progress |
| 5 | UX-S3: Genre chips lack visual differentiation | 🟡 Medium | Low | Add one emoji icon per chip |
| 6 | UX-M1: "Pick a Path" needs one-line description | 🟢 Low | Trivial | Add sub-label text |
| 7 | UX-M4: Custom avatar CTA leads to technical screen | 🟡 Medium | Low | Add "ask a grown-up" bridge screen before BYOK setup |
| 8 | Green-6: Genre combination shown on review | 🟢 Enhancement | Low | Add genre badge to review card |
| 9 | Green-8: Story preview on world tiles | 🟢 Enhancement | Medium | Long-press preview text per world |
| 10 | Green-10: Heroes tab / saved stories | 🟢 Enhancement | High | Audit and improve the post-story saved-stories experience |

### Cross-band bugs (appear in both Explorer and Adventurer)
- **Companion images broken on review** — systemic path mismatch; one fix covers both bands
- **Story length chips undersized on review** — same issue in both bands

### Top 3 if only three fixes are possible
1. **Fix companion images on review screen** — same root cause as Explorer, one fix heals both bands
2. **Fix world name truncation on review** — unique to Adventurer; the long evocative names are a selling point for this band and should render fully
3. **Make the companion bio requirement visible** — the hidden penalty is a trust-breaker for a 10-year-old who invested in companion selection and receives a story where companions don't appear

---

*Audit conducted via screenshots captured during previous Playwright session. Adventurer band activated by tapping "10" on age gate. Persona name: SAM.*
