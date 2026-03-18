# UX Age-Appropriateness Audit — Story Weaver
**Date:** March 7, 2026  
**Scope:** All 7 age bands × 4 story modes × full UI wizard flow  
**Purpose:** Identify what feels too babyish, too grown-up, or simply mismatched for each user cohort — across story content, UI framing, wizard flow, and visual language.

---

## How to Read This Report

Issues are flagged with severity:
- 🔴 **High** — Likely causes drop-off or disgust ("this is for babies")
- 🟡 **Medium** — Friction or mild awkwardness
- 🟢 **Low** — Polish / finesse improvements

Each section covers one age band's experience across:
1. UI / Visual Theme
2. Age Gate & Onboarding
3. Wizard Flow (character, feelings, companion, review)
4. Story Modes (Regular, Rhyme Time, Learn to Read, Pick-a-Path)

---

## Age Band 1: Ages 3–4 (Sprout Theme)

### UI / Visual Theme
- 🟢 Sprout palette (warm orange/plum) is age-appropriate and distinct from the teen theme.
- 🟢 Nunito font is bubbly and readable. Touch target of 88px is solid.
- 🔴 **CinzelDecorative font on the "Welcome back!" screen is not overridden for Sprout.** The gothic/ornate heading style is confusing for pre-readers who barely recognize letters. Fredoka or Nunito should fully replace it at this age.
- 🟡 **Magic star cursor particle effect** is fun but directionally confusing for 3-year-olds who may not understand it represents their "pointer." Consider replacing with a static fairy wand or removing entirely for this band.
- 🟡 The animated crystal ball widget (`animated_crystal_ball.dart`) uses abstract geometric animation. A 3-4 year old will not connect this symbology to "story." Replace with something immediately recognizable (open book, a door, a star).
- 🔴 **Text inputs (name field) are an accessibility mismatch** for 3-4 age band. Children in this range are pre-literate or emergent. Having them type their own hero name creates dependency on a parent and friction. The name input should become either: (a) a voice input with "say your name" CTA, or (b) a name-picker grid with illustrated common names/nickname tiles.

### Wizard — Hero Creator
- 🔴 **Gender picker label is just "Girl / Boy / Other."** For a 3-year-old this creates no emotional hook. Consider replacing with: "My hero is a..." and use large illustrated icons (princess silhouette, knight silhouette, star/whatever silhouette) instead of text labels.
- 🟡 **Personality sliders** (energy, sociability, creativity, confidence, empathy, adventurousness) are conceptually adult. A 3-4 year old cannot process 6 abstract trait axes. These sliders should be hidden entirely for the Sprout band and replaced with a single "What is your hero like?" tile pick (Brave / Silly / Kind / Adventurous).
- 🟡 "Pick your hero style!" archetype cards use text-heavy descriptions. At age 3-4, only the image and 1-word label should be visible (no description text).
- 🔴 **The "Superpower" free-text field** (`heroSuperpower`) is meaningless to a 3-year-old. A parent will type it for them, making the experience feel adult-mediated. Replace with a visual icon picker: "Pick your hero's magic gift" (wings, lightning, flowers, invisibility).
- 🟡 "Quest" and "Wish" free-text fields suffer the same problem. Collapse to a single prompt with 3-4 illustrated quick-pick tiles.

### Wizard — Feelings
- 🟢 Mood Lantern selector exists — visual/tactile approach is conceptually right.
- 🔴 **Label text "How does your hero feel?"** is fine, but the "Tap to explore feelings" sub-prompt for Sprout should be changed to "Tap a lantern!" — the word "explore" implies deliberate browsing which 3-year-olds don't do.
- 🟡 The feelings wheel vocabulary (tertiary emotions like "Exasperated," "Wistful," "Apprehensive") appears at any expansion depth. Even the secondary tier has words a 4-year-old cannot read or understand. **Hard-cap the Sprout band to 6 core emotions with picture-word pairs only** (happy face, sad face, scared face, angry face, surprised face, tired face).

### Wizard — Companion
- 🟢 The "Pick a Buddy!" label for Sprout is well-calibrated.
- 🟡 Magic companions are described with short bios (e.g., "Spark who helps you be brave"). At this age, the bio text will be read by parents, not the child. Consider adding a TTS auto-read button that plays the companion's description aloud automatically when tapped.
- 🟢 Companion showcase orbs (portrait circles) are visually comprehensible for this age.

### Story Mode — Regular Story
- 🟢 Backend word count (200-450 words for age 3-4) is appropriate.
- 🔴 **The "Wisdom Gem" mechanic** ("simple, warm encouragement a toddler can understand") is delivered as a text card — likely read AT the child by a parent. The framing on the result screen should be parent-facing ("Share this with [name]!") not child-facing, since the child cannot read it.
- 🟡 The storybook page-flip view (`page_flip_book_view.dart`) relies on a swipe gesture. For 3-year-olds, tap-forward is more reliable than swipe. Confirm tap-anywhere-to-advance is the primary navigation method for Sprout.
- 🟡 Auto-TTS (text-to-speech) should be **on by default** for age 3-4, not a button the parent has to find. The story should begin reading itself aloud when the result screen opens.

### Story Mode — Rhyme Time
- 🟢 Rhyme Time is developmentally perfect for 3-4. Short words, rhyme patterns, and rhythm aid pre-literacy.
- 🔴 **The backend enforces 150-250 words (short) for Rhyme Time at this age**, but the prompt allows "sophisticated rhymes" wording from a later age guard — verify that the age >= 13 guard in `_build_rhyme_time_prompt` is never triggered by an edge case (age=3 with misremapped band).
- 🟡 The result screen shows the story as a text wall with no inline read-along word highlighting. For this age band, word-by-word or line-by-line TTS highlighting would dramatically increase engagement.

### Story Mode — Learn to Read
- 🟢 CVC-only vocabulary for age ≤ 5 is correct.
- 🟡 The limerick mode (`use_limericks = True`) begins at age 7. The transition at age 6 (blends/digraphs, 1-2 sentences per page) is fine, but verify the UI correctly labels this as "Learn to Read" not "Rhyme Time" — they share some UI chrome.
- 🔴 **At age 3-4, the Learn to Read mode generates 6-8 pages of single-sentence text.** In the current UI, pages are displayed sequentially with no visual illustration per page (only a single AI illustration per story). Each page at this age should have an illustration. Consider generating one per page or using a placeholder themed image per page until full illustration is available.

### Story Mode — Pick-a-Path
- 🔴 **Pick-a-Path should not be accessible to Under-5 users at all.** Reading multi-branch decision trees is cognitively impossible for a 3-4 year old. The mode should be hidden/greyed out for the Sprout band with a tooltip: "Unlock at age 5!" Consider replacing with a "Which path?" simplified 2-image choice experience instead of full branching.

---

## Age Band 2: Ages 5–7 (Explorer Theme)

### UI / Visual Theme
- 🟢 Explorer theme (magical purple, Quicksand font, sparkle intensity 1.0) is the sweet spot for this age — this is the core audience the app was designed for.
- 🟢 Sparkles, animated transitions, and particle celebrations are all on-brand and delightful.
- 🟡 **The CinzelDecorative font family** is used on headers in some hardcoded places (hero creator page 0 "Welcome back!" and archetype selection) that bypass the `AgeBandThemeData` font system. For age 5-7, Cinzel Decorative reads as "gothic" and "hard to decode" — Quicksand should be enforced everywhere.
- 🟡 The crystal formation widget on the home/magic review screen — glowing gem aesthetic — is age-appropriate but **could be mistaken for a button** by young children. Ensure a clear visual affordance (glow pulse) distinguishes tappable crystals from decorative ones.

### Wizard — Hero Creator
- 🟢 "Create Your Hero!" label is perfect.
- 🟡 Personality sliders persist for this age. Consider reducing to 3 sliders (Brave, Kind, Silly) with emoji anchors instead of 6 abstract trait labels. A 5-year-old should not encounter the word "Empathy" as a raw slider label.
- 🟡 The "Imagine It" free-text field for custom story elements is labeled with the prompt "What else should happen in your story?" — appropriate for 7-year-olds but confusing for 5-year-olds who can't write. Add a voice mic as the primary input with text as secondary for age ≤ 6.
- 🟡 Archetype cards: the description text underneath each archetype (e.g., special power description) uses vocabulary like "Signature Power" — age 5-7 should see "Special Gift" or "Magic Power" instead.

### Wizard — Feelings
- 🟢 "How does your hero feel?" framing is correct.
- 🟡 **Mood Lantern selector visual hierarchy:** at 5-7, the lanterns should show emoji faces alongside or below the lantern to make the emotion instantly readable. Emoji faces are the emotional language of this age group.
- 🟡 Secondary feelings words (e.g., "Grumpy," "Worried," "Jealous") are accessible vocabulary for 7-year-olds but may be confusing for 5-year-olds. Consider gating secondary expansion behind a "More feelings" tap instead of immediately showing all options.

### Wizard — Companion
- 🟢 Companion showcase (portrait orbs) and "Tap a companion below to add them" is well-calibrated.
- 🟡 The blank-name fallback in the showcase ("My Pet") for unnamed pets looks like a bug to the child. Force a pet-naming step before the pet can be added to a story.
- 🟢 "Who's coming with you?" page title is emotionally engaging for this age.

### Story Mode — Regular Story
- 🟢 Word count (450-1200 words across short/medium/long) is appropriate.
- 🟡 **The "Wisdom Gem" card** on the result screen reads in a mature Merriweather font at full size. For Explorer band, the gem should display in a larger, friendlier typeface (Quicksand or Fredoka) to maintain brand consistency and readability.
- 🔴 **The TTS "listen" button in the story result screen is not prominently placed.** For age 5-7, listening IS the story — the button to play audio should be the primary CTA (large, gold, animated), not a secondary icon button.

### Story Mode — Rhyme Time
- 🟢 This mode is a natural fit for 5-7. AABBA rhyme scheme limericks for age 7+ are delightful.
- 🔴 However, the backend note for Rhyme Time age 13+ says **"avoid babyish or condescending tones"** — this guard is fine — but the intermediate band (age 8-12) has no equivalent refinement instruction. Verify rhyme stories for age 8 don't still use "bouncy" limerick format that would annoy a 9-year-old who thinks they're beyond baby poems.

### Story Mode — Learn to Read
- 🟢 Age 5: CVC-only, 8-page medium at correct difficulty.
- 🟡 Age 6-7: Basic blends, 1-2 sentences per page, 10-12 pages. The switch to optional limericks at age 7 is clever, but verify that the UI clearly signals the format change ("Today your story is a Rhyme Adventure!") rather than silently generating limericks.
- 🟡 The **Learn to Read mode is still labeled "Learn to Read"** in the wizard — for a 7-year-old who CAN read, this label is humiliating. Rename it to "Read-Along Stories" or "Phonics Magic" at ages 6-7. Reserve "Learn to Read" only for age ≤ 5.

### Story Mode — Pick-a-Path
- 🟢 9-18 nodes for this age band is appropriate.
- 🔴 **The choice UI in the Pick-a-Path result/continuation screen likely shows choices as text buttons.** For age 5-7, choices should be accompanied by illustrations or large icons, not just text. Reading two text options under time pressure is stressful for early readers.
- 🟡 The "back" option in Pick-a-Path navigation should be removed for this age group — going backward breaks the narrative immersion and confuses the child about story state.

---

## Age Band 3: Ages 8–10 (Adventurer Theme)

### UI / Visual Theme
- 🟢 Adventurer theme (deep cosmic palette, Bitter slab-serif, cooler teal accent) is the right direction.
- 🔴 **Sparkle intensity drops to 0.3 but particles remain ON** — a subtle particle trail around the cursor may now read as "babyish" to a self-conscious 9-year-old. Consider making `showParticles: false` for Adventurer, or replacing with a subtle comet trail that feels "cool" rather than "magical pink sparkle."
- 🟡 The **"Pick your hero style first!" heading** on page 2 of the wizard uses an exclamation mark and imperative phrasing that reads as the app talking down to the user. For ages 8+, reframe as: "Choose your character type" — flat, peer-level instruction.
- 🟢 Button radius 12px and card radius 16px — sharper corners are appropriate and feel more mature.
- 🟡 The `feelingsNavLabel: 'Mood'` label is good but the bottom nav icon should shift from an emoji-style face to an abstract mood/wave icon for this band.

### Wizard — Hero Creator
- 🟡 All six personality sliders are now more appropriate — 8-10 year olds can process abstract trait concepts with simple labels. However the slider labels ("Energy," "Sociability," "Creativity") are still somewhat clinical. Consider renaming: "Energy" → "Energy Level," "Sociability" → "People Person," "Adventurousness" → "Risk Taker."
- 🟢 Archetype cards with text descriptions are age-appropriate here.
- 🟡 **"Hero Tool" label** in the prompt builder (`tool_label = "HERO TOOL"` switches to `"KEY ARTIFACT"` at age 12+). The label is internal but influences generated story vocabulary. For age 8-10, "hero tool" leaking into the prose would feel fine, but "artifact" would seem advanced. This transition at 12 is well-placed.
- 🔴 The age picker in the hero creator allows values from 3 to 99 in a **scroll picker**. For a child of 8-10 setting their own age, scrolling through ages 3-7 first feels like they're being shown baby ages. Start the scroll centered on the user's current stored age to minimize this.

### Wizard — Feelings
- 🟢 "Set the mood for your story" framing (`feelingsPrompt` for Adventurer) is age-matched.
- 🟡 Secondary emotion labels (e.g., "Apprehensive," "Exasperated") are appropriate vocabulary for age 10 but may feel unfamiliar for age 8. Consider keeping the first-expansion layer as purely illustrated/labeled pairs, with definitions on long-press.

### Story Mode — Regular Story
- 🟢 Backend writing calibration for 8-10 is strong: two-step challenge, compound sentences, vivid verbs. Word count 900-2400 words is appropriate for this age group's attention span.
- 🟡 The **story result screen page flip** — swipe navigation — is fine for this age. However, there's no visible progress indicator for how many pages remain. For a 1800-word story split across 12+ pages, the child cannot tell how far they are. The `storybook_progress_indicator.dart` widget should be clearly visible and non-intrusive.
- 🟡 The "Wisdom Gem" delivery on the result screen — a boxed quote at the end of the story — will feel preachy to a 9-year-old who has just finished an adventure. Consider replacing the static box with a "crystal reveal" animation that makes the gem feel like a reward rather than a lesson.

### Story Mode — Rhyme Time
- 🔴 **Rhyme Time for age 8-10 uses the same limerick format as age 7+** but with different word counts (400-800 words). The limerick format (`use_limericks = True`) was designed for "reluctant readers." A fully confident 9-year-old reader may find limericks patronizing. The Rhyme Time backend should offer: limericks for ages 7-8, **ballad or couplet poetry** for ages 9-10, where stanzas are 4 lines and the story has genuine tension. This requires a new prompt branch in `_build_rhyme_time_prompt`.
- 🟡 "Rhyme Time" as a product name skews young. For age 9+ consider renaming to "Story Verse" or "Rhyme Quest" in the UI.

### Story Mode — Learn to Read
- 🔴 **Learn to Read mode should not be accessible for age 9-10 at all.** The AGE_CONSTRAINTS table shows ltr config exists for 8-10 (10/12/14 pages) but a fluent 9-year-old reader would find this humiliating. **Hide the mode for ages 9+** or rename it to "Reading Challenge" with a completely different framing (e.g., "unlock this rare story format").

### Story Mode — Pick-a-Path
- 🟢 12-24 nodes for this age band is appropriate.
- 🟡 The choice presentation must offer meaningful dilemma — not just "door A vs. door B." For this age, the backend should be given explicit instruction that at least one choice must have a non-obvious consequence. Current prompt builder does not enforce this for the 8-10 band.
- 🟡 The adventure "segmentation" (current stories are split into segments) creates loading pauses between segments. For an 8-10 year old, loading pauses of >4 seconds mid-adventure will break immersion. Consider pre-generating the next segment in the background during reading of the current one.

---

## Age Band 4: Ages 11–13 (Adventurer Theme, transitioning to Creator)

This is the **most critical age band** for getting wrong. Users in this range are acutely sensitive to things that feel "for little kids." The app currently has the Adventurer theme applying to all ages 9-12, which means an almost-teen (12-year-old) sees exactly the same UI as a 9-year-old.

### UI / Visual Theme
- 🔴 **Ages 11-13 share the Adventurer theme with ages 9-10.** The Adventurer palette is a cosmic dark blue/indigo which is well-calibrated — but the `showParticles: true` and `sparkleIntensity: 0.3` still let particles through for a 12-year-old. A 12-year-old who shows this app to a friend risks ridicule if sparkle particles are visible. **Set `showParticles: false` and `sparkleIntensity: 0.0` for ages 11+** within the Adventurer band (or split into a new band).
- 🔴 **The band boundary is at age 12 (Adventurer) → 13 (Creator).** There is no mid-band split, meaning the UI jump between 12 and 13 is dramatic. A 12.5-year-old just before their birthday sees the child-skewing Adventurer theme; their sibling who turned 13 last week sees the sleek Creator theme. Consider triggering Creator theme at age 12 instead of 13 to eliminate this cliff-edge.
- 🟡 The "Create Character" label in Adventurer is fine but the wizard's interior still uses hero-focused emoji and exclamation points in some hardcoded headings. Audit every hardcoded string in `hero_creator_step.dart` for exclamation marks — they should be absent for ages 11+.
- 🟢 Slab-serif Bitter font is distinctly mature and unambiguously non-babyish. Good call.

### Wizard — Hero Creator
- 🟡 The `createCharacterLabel: 'Create Character'` label (vs. "Create Your Hero!") is a good step down. However within the wizard pages, the word "hero" still appears repeatedly as the hero label. For age 11-13, "Character" or "Protagonist" is more appropriate than "Hero."
- 🔴 **The archetype cards** — "The Brave Knight," "The Clever Inventor," etc. — have names and descriptions calibrated for the 6-10 age range. An 11-year-old will find "Brave Knight" or "Magical Healer" somewhat corny. Reframe archetypes for this age band: instead of fairy-tale archetypes, offer identity-coded ones: "The Problem Solver," "The Empath," "The Strategist," "The Maverick." These feel like personality types, not costumes.
- 🟡 The companion selection for this band still shows "magical" companions like "Sparky the Dragon." An 11-13 year old's peer group does not include fantasy mascots. Offer an optional toggle: "Magical Companions" vs. "Story Characters" — where Story Characters are archetype-based human companions (the Rival, the Mentor, the Sidekick).
- 🟡 The Pet avatar creation flow (custom pet art from a photo) is actually the most age-appropriate feature for this band because kids this age are intensely attached to their real pets. **Feature this more prominently** for ages 11+, rather than burying it behind magic companions.

### Wizard — Feelings
- 🟢 Creator/Adventurer "Set the mood for your story" is appropriately low-key.
- 🟡 The feelings garden screen (`feelings_garden_screen.dart`) — does it still use the garden/butterfly visual theme? If so, this may be too whimsical for an 11-year-old. The aesthetic of the feelings selection should shift from "magical garden" to "creative studio" or "mood board" for ages 11+.
- 🟢 Secondary and tertiary emotion vocabulary (e.g., "Apprehensive," "Exasperated," "Conflicted") is fully appropriate at this age.

### Story Mode — Regular Story
- 🟢 Word count 1300-3400 words across lengths is appropriate.
- 🔴 **The Wisdom Gem for age 11-13** is framed as "a thoughtful insight connecting the hero's growth to real life." This is exactly the kind of explicit after-school-special framing that will make an 11-year-old cringe. The Wisdom Gem mechanic itself may need to be hidden at this age, or completely reframed as an optional "Author's Note" that the user can choose to read.
- 🟡 The story result screen's magical loading animation (spinning crystal orb) — an 11-year-old has seen this and it no longer feels magical. For Creator/late-Adventurer band, replace with a typewriter-style "story composing" animation or a typing-cursor aesthetic to match the editorial brand.

### Story Mode — Rhyme Time
- 🔴 **"Rhyme Time" product name for an 11-year-old is embarrassing.** A child this age will simply refuse to use a feature with this name in front of peers. Rename to "Story Verse" or "Poetic Mode" at minimum for ages 11+.
- 🟡 Backend word count for rhyme at 11-13 (450-800 words) is fine, but the instruction to "use figurative language purposefully" is only in the age notes, not enforced as a hard constraint. Add a hard constraint that prohibits sub-10-word lines for this age (limericks feel too short and babyish).

### Story Mode — Learn to Read
- 🔴 **This mode must be completely hidden for ages 11+.** No exceptions. The ltr config exists in the backend table for 11-13 but should never be reachable. Confirm the UI gating prevents this.

### Story Mode — Pick-a-Path
- 🟢 14-26 nodes for this age band is appropriate — this creates a meaningfully complex story.
- 🔴 **"Pick-a-Path" as a mode name is for young children.** Rename to "Interactive Story" or "Choose Your Story" for ages 11+. The language shift in the UI should accompany the mode.
- 🟡 For this age, choices should occasionally involve **moral complexity** (betray a friend for a greater goal? Tell a hard truth that hurts someone?). The current prompt builder for interactive adventures does not include age-specific moral-weight guidance for segments. Add this for 11-13 band.

---

## Age Band 5: Ages 13–15 (Creator Theme)

### UI / Visual Theme
- 🟢 Creator theme (near-black, editorial, 7C4DFF purple accent, Source Sans 3) is well-calibrated.
- 🟢 `sparkleIntensity: 0.0` and `showParticles: false` are correct.
- 🟡 The app **still has a "Make Magic" button** (the primary story generation CTA). This label is perfectly fine for ages <11 but for a 14-year-old, "Make Magic" sounds like a children's toy. Rename to "Create Story" or simply "Generate" for Creator band. Check `make_magic_button.dart` for age-band variants.
- 🔴 **The app icon and branding use "Story Weaver" with a whimsical orb graphic.** For the 13+ demographic, this aesthetic implies the app is for younger children. If the app targets teens, the splash/icon should switch to the editorial/Creator aesthetic. Consider adding a "teen" brand presentation mode.
- 🟡 The bottom navigation labels — "Feelings" or "Mood" — are fine but the icon should shift to something more neutral (e.g., a compass or abstract waveform) rather than any face/emotion-based iconography.

### Wizard — Hero Creator
- 🔴 **"New Character" is the label but the flow within the wizard still uses child-skewed sub-labels** in hardcoded `Text()` widgets. Audit hero_creator_step.dart Page 2 ("Pick your hero style first!"), Page 3 ("Who's coming with you?"), Page 4 ("Where does the story happen?"), Page 5 ("Make the Magic!") — all of these headings need to be either swapped via `AgeBandThemeData` labelization OR replaced with age-appropriate equivalents for Creator band.
- 🔴 Archetype cards for ages 13+ must not use titles like "The Brave Knight" or "The Magical Healer." These archetypes belong in the YA/literary framing. Consider completely replacing the archetype set for Creator band with personality/literary archetypes: "The Outcast," "The Idealist," "The Protector," "The Rebel," "The Seeker."
- 🟡 The companion system — offering magic companions (dragons, pixies, etc.) — should default to **off or hidden** for Creator band. The companion step should default to showing a "Story Characters" tab of story archetypes with the magical companions available via an opt-in toggle ("Show fantasy companions").

### Wizard — Feelings
- 🟢 "What mood fits your story?" (`feelingsPrompt` for Creator) is the right framing — it positions the feeling as a creative choice, not an emotional check-in.
- 🟡 The feelings selection widget — whether lantern, garden, or wheel — must completely shed any whimsical visual treatment for this age. Use a **color/gradient mood palette** (like a music streaming mood selector) rather than illustrated lanterns or cartoon faces.
- 🟡 The feelings list for Creator band should surface emotions from the tertiary level first (sophisticated emotions like "Melancholic," "Conflicted," "Nostalgic") rather than requiring the user to drill down from "Sad."

### Story Mode — Regular Story
- 🟢 Word count 1600-4500 is appropriate.
- 🟢 Backend notes for 13-15 are excellent: first-person POV encouraged, identity/loyalty/fear of judgment themes, bittersweet endings allowed.
- 🔴 **The story result screen still uses the "storybook" framing** (page flip book view, decorative borders, illustrated spreads). For a 14-year-old, these visual affordances belong to picture books. The story result for Creator band should display as a **clean reading app** — full-bleed text, high line height, chapter-style pagination (think Kindle or Wattpad, not a storybook).
- 🟡 The "Wisdom Gem" must be removed or made optional for this age. Under no circumstances should a 14-year-old's story end with a pop-up insight card about what the story taught them. If kept, rename to "Reflection" and display it behind an optional "Reveal" tap.

### Story Mode — Rhyme Time
- 🔴 "Rhyme Time" must be renamed. For Creator band this should be labelled "Poetry" — full stop.
- 🟡 The backend `age_instruction` for age >= 13 is: "Avoid 'babyish' or condescending tones. Use sophisticated rhymes that explore identity, resilience, or complex friendships." This is good guidance but the generated rhymes currently still use AABBA limerick structure for ages 7+ (controlled by `use_limericks`). At age 13+, the format should shift to **free verse or sonnet** — not limericks. Add a new format branch in `_build_rhyme_time_prompt`.

### Story Mode — Learn to Read
- 🔴 Absolutely hidden. Confirmed the policy; verify the UI enforces it.

### Story Mode — Pick-a-Path
- 🔴 Rename to "Interactive Story" or "My Story" for this band.
- 🟢 16-32 nodes with moral complexity targets is appropriate.
- 🟡 For this age, the choice presentation UI should not be two bright magical buttons — it should be a clean list (think text adventure or visual novel choice UI). Choices should be presented as a block of 2-3 options with minimal decoration.

---

## Age Band 6: Ages 15–18 (Creator Theme)

### UI / Visual Theme
- 🟢 Creator theme is appropriate.
- 🔴 **At age 15-18, the phrase "Story Weaver" itself may be a barrier to adoption.** Teens this age compete with Wattpad, AO3, and fanfic communities. The app should position itself differently for this cohort — either transparently as a therapeutic/creative writing tool, or use sub-brand language ("Your story, your rules").
- 🟡 Any holdover wizard chrome (sparkles, magical orb, starburst celebrate) will break trust with a 16-year-old instantly. Confirm `_triggerPageCelebration()` (which plays sparkle chime + star burst) is suppressed for Creator band — **this function does not currently check the age band before firing**.
- 🟡 The `voice_mic_button.dart` for voice input to fields is actually ideal for this age for creative dictation. Ensure it's prominently placed, not hidden.

### Wizard — General Flow
- 🔴 **The 6-step wizard flow (hero → archetype → companion → place → magic tool → review) feels juvenile** to a 15-17 year old. Each step is framed as a playful challenge. Consider collapsing the wizard to a single **creative brief screen** for Creator band: a card layout with expandable sections for Character, Setting, Mood, Story Focus, and optional Companion. This mirrors how actual writers organize a story concept.
- 🟡 The `onboarding_screen.dart` and `age_gate_screen.dart` — if they use child-skewed animation or framing — will cause 15-year-olds to abandon the app before reaching the wizard. Audit those screens for Creator-band presentation.

### Story Mode — Regular Story
- 🟢 Word count 2000-6000 is appropriate — this is short story / novelette territory.
- 🔴 The **storybook page-flip UI for story delivery** (page by page, illustrated spreads) is completely wrong for this age. A 17-year-old reads novels. The result screen for ages 15+ should be a long-scroll reading view with a table of "chapters" (one page per logical scene break) rather than a swipe-through picture book.
- 🟡 The TTS/audio feature — reading the story aloud in a child-focused way — may not appeal to this age. Consider framing audio as "listen while you work" (ambient/commute mode) rather than "have your story read to you."
- 🟢 The backend's prohibition of "babyish phrasing" for this age band is correct and essential.

### Story Mode — Rhyme Time / Poetry
- 🟢 Backend instruction at 15-18: "Literary rhythm — alternate fragments with long flowing sentences; prose style is part of the storytelling." This is excellent.
- 🔴 The UI mode name must be "Poetry" for this band. The word "Rhyme" implies nursery rhymes.
- 🟡 Free verse should be the default format for ages 15+. Add this as a prompt instruction.

### Story Mode — Pick-a-Path
- 🟢 18-38 nodes for this band creates genuinely complex narratives.
- 🔴 Rename to "Branching Story" or just "Interactive Story" — "Path" language is too playful.
- 🟡 At this age, the interactive story product should frame the user as **co-author, not player**. Choices should be presented as "What does [character] decide?" framing rather than "What do YOU do?" — this subtly shifts the experience from player to writer, which is more appropriate for creative development at this age.

---

## Age Band 7: Adult (Creator Theme)

### UI / Visual Theme
- 🟡 The Creator theme works for adults but the age band currently has no bespoke tuning. Adults benefit from: configurable font size, choice between dark/light mode, and an optional "minimal mode" that removes all decorative chrome.
- 🔴 **There is currently no way for an adult user to distinguish their experience from a 13-year-old's** — they share the Creator theme identically. Adults using a therapeutic story app want clinical/professional framing, not a teen creative writing app. Consider an "Adult Mode" that applies a premium editorial aesthetic.
- 🟡 The wizard flow — still structured for children with the 6-step guided experience — feels condescending for a 30-year-old using the app for personal therapeutic storytelling. Collapse to direct configuration UI.

### Story Mode — Regular Story
- 🟢 Backend word count 2000-7800 is appropriate and wide enough to cover therapeutic journaling (short) through full short story (long).
- 🔴 The **storybook page-flip UI** must not be used for adults. Long-form scroll with section headers is the correct format.
- 🟡 The "Wisdom Gem" for adults is defined as "a resonant, adult insight distilled from the story's theme." This is actually appropriate for therapeutic use, but the delivery UI (a sparkly pop-up gem animation) is not. For adults, deliver the insight as a quiet concluding section with a neutral card design.

### Story Mode — Rhyme
- 🟡 For adults, "Rhyme Time" name must absolutely not appear. Rename to "Poetry."

### Story Mode — Learn to Read
- 🔴 Must be completely hidden for adult users.

### Story Mode — Pick-a-Path
- 🟡 For adults, this feature is most valuable as a narrative exploration tool (e.g., processing a decision, exploring "what if" scenarios). The UI should acknowledge this therapeutic use case — perhaps via a brief framing prompt: "Explore different outcomes..." rather than adventure-game language.

---

## Cross-Cutting Issues

These issues apply across multiple or all age bands and represent systemic design debt.

### 1. Hardcoded Strings That Bypass the Age-Band Theme System
- 🔴 Multiple wizard pages have hardcoded `Text()` widgets using child-skewed language ("Make the Magic!", "Pick your hero style first!") that do not adapt to the age band. All user-facing copy in the wizard must be routed through `AgeBandThemeData` labels or a band-aware copy function.
- 🔴 `_triggerPageCelebration()` in `hero_creator_step.dart` fires the sparkle chime and starburst overlay regardless of age band. This **must** be gated: `if (band.showParticles) { _triggerPageCelebration(); }`.

### 2. Magic/Fantasy Terminology Persists Into Teen Bands
- 🔴 The "Make Magic" button, crystal orb, "Wisdom Gem," and "spark tool / hero tool" language all persist into the Creator theme. Each of these needs a Creator-band variant name:

| Current (all ages) | Explorer/Sprout | Adventurer | Creator |
|---|---|---|---|
| "Make Magic" | "Make Magic" | "Start Adventure" | "Create Story" |
| "Hero Tool" | "Hero Tool" | "Hero Tool" | "Key Item" |
| "Wisdom Gem" | "Wisdom Gem" | "Lesson Crystal" | "Reflection" (optional) |
| "Pick a Buddy!" | "Pick a Buddy!" | "Choose Companion" | "Add a Character" |
| "Rhyme Time" | "Rhyme Time" | "Rhyme Quest" | "Poetry" |
| "Pick-a-Path" | "Pick-a-Path" | "Pick-a-Path" | "Interactive Story" |

### 3. The Story Result Screen Is One-Size-Fits-All
- 🔴 The `story_result_screen.dart` uses page-flip storybook layout universally. This is developmentally correct for ages 3-10 and deeply wrong for ages 11+. Implement two layout variants: **Storybook** (ages ≤ 10) and **Reader** (ages 11+).

### 4. Wisdom Gem Delivery
- 🔴 The Wisdom Gem (post-story insight) uses sparkle animation and a prominent floating card regardless of age. Age-band calibration:
  - **Ages 3-7:** Keep as-is (parent reads it to child, animated gem is delightful)
  - **Ages 8-10:** Keep animation but reduce prominence; treat as a discoverable bonus
  - **Ages 11-13:** Make optional with a "Tap to reveal the gem" interaction
  - **Ages 14+:** Remove animation entirely; present as plain "Reflection" text below the story, collapsed by default

### 5. TTS is Buried for Young Users, Irrelevant for Older Users
- 🔴 TTS should be **auto-enabled and prominent** for ages 3-7. For ages 11+, it should be a subtle secondary option. Currently the TTS button is similarly positioned for all ages.

### 6. Pick-a-Path Loading Interrupts
- 🟡 Segment-by-segment generation creates visible loading pauses. For all ages 8+ this breaks adventure immersion. Pre-generate the next 1-2 segments while the user reads the current one.

### 7. The Age Gate (Initial Setup) Does Not Set Up Expectations Correctly
- 🟡 The age gate collects the user's age but never explains to older users (13+) that the app will adapt to them specifically. A brief "This app adjusts to your age" message for teens during onboarding would reduce the initial "is this for kids?" impression.
- 🔴 After age gate, if the user is 13+, the first screen they see should NOT still say "Make Your Hero!" or show baby-purple sparkle magic. The age gate should immediately apply the Creator theme before any content is loaded.

---

## Summary Priority Matrix

| Priority | Issue | Age Band |
|---|---|---|
| 🔴 P0 | Storybook page-flip UI for ages 11+ | 11-Adult |
| 🔴 P0 | "Make Magic" / sparkle celebrate fires for all ages | 13-Adult |
| 🔴 P0 | Pick-a-Path accessible to 3-4 year olds | 3-4 |
| 🔴 P0 | Text name input for pre-literate 3-4 users | 3-4 |
| 🔴 P0 | "Rhyme Time" name for 11+ users | 11-Adult |
| 🔴 P0 | Learn to Read mode not hidden for 9+ | 9-Adult |
| 🔴 P0 | Wisdom Gem animated pop-up for 14+ users | 14-Adult |
| 🔴 P0 | Creator wizard flow too childlike for 15-18 | 15-Adult |
| 🔴 P1 | Archetype cards not reworded for 11+ | 11-Adult |
| 🔴 P1 | CinzelDecorative font leaks into Sprout/Explorer screens | 3-7 |
| 🟡 P2 | Personality sliders too abstract for 5-7 | 5-7 |
| 🟡 P2 | Feelings lanterns need emoji anchors for 5-7 | 5-7 |
| 🟡 P2 | Age picker scroll starts at 3 (baby ages visible) | 8-10 |
| 🟡 P2 | Rhyme Time format doesn't evolve past limericks for 9+ | 9-13 |
| 🟡 P2 | TTS default/prominence not age-calibrated | All |
| 🟢 P3 | Particle cursor replaces sprout fairy wand | 3-5 |
| 🟢 P3 | Wisdom Gem font mismatch in Explorer band | 5-7 |
| 🟢 P3 | "Learn to Read" name embarrassing for age 6-7 | 6-7 |

---

*Generated by Antigravity — March 7, 2026*
