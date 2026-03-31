# Children's App UX Audit — Creator Band (Age 12)

**Date:** 2026-03-31
**Persona:** 12-year-old child (named "Alex")
**Band tested:** Creator (ages 11–13)
**App URL tested:** http://localhost:8088
**Tester:** Playwright-assisted walkthrough, Six Hats methodology

---

## Flow Observed

| # | Step | Screen / Action | Screenshot |
|---|------|-----------------|------------|
| 1 | Age Gate | "How old are you?" grid, ages 2–13+ visible. Tapped "12". | `creator_01_age_gate.png` |
| 1b | Profile Setup | "Set up your profile" — name entry + mic button. Typed "Alex". | *(intermediate)* |
| 2 | Parental Consent | "Parental Consent Required" / COPPA notice. Scrolled down, checked "I am a parent/guardian" checkbox, tapped "Give Permission ✓". | `creator_02_consent.png` / `creator_02_consent_scrolled.png` |
| 3 | Creator Wizard — Character | "Build Your Story" single-page Creative Brief. Character & Role section expanded. Selected "Girl" gender. | `creator_03_gender_selected.png` |
| 4 | Creator Wizard — Archetype | Scrolled to CORE ARCHETYPE chips. Tapped first chip → revealed "STORM VANGUARD". Five of six chips remained visually blank. | `creator_04_archetype.png` / `creator_04_archetype_clicked.png` |
| 5 | Creator Wizard — Companions | Tapped "2 Companions" in step nav. Step indicator changed to bold "Companions" but page content did not change. No companions selection UI is present anywhere in the Creative Brief. | `creator_05_companions.png` |
| 6 | Creator Wizard — World | Expanded "WORLD & SETTING" accordion. Tapped first setting card → revealed "THE TEMPORAL THRESHOLD". All other setting cards appeared as blank white rectangles. | `creator_06_world_selected.png` |
| 7 | Creator Wizard — Story Options | Expanded "STORY OPTIONS" accordion. Showed NARRATIVE MODE (Standard View) and TARGET DURATION (Short) dropdowns. | `creator_07_story_type.png` |
| 8 | Review Screen | Tapped "Create Story". Reached "Your Story Pitch" screen showing character summary. RenderFlex overflow error visible as clipped "ERFLOWED P" text on avatar. Setting shown as "The Door You're Afraid to Open" (different from selection). | `creator_08_review.png` |

---

## White Hat — Facts I Observed

### Screen Inventory

- **Age gate:** 4×4 grid of number buttons (ages 2–13+). One row partially off-screen at 762×484 viewport. "Parent" link in top-right.
- **Profile setup screen:** Contains a microphone button ("Tap to say your name"), a text field ("What should we call you?"), and a "Continue" button.
- **Consent screen:** Full COPPA disclosure with 5 bulleted data collection items, 3 "What We Do NOT Do" items, Third-Party Services list (Google Gemini, ElevenLabs, Stripe), optional email field, photo-avatar toggle, "I am a parent/guardian" checkbox, Privacy Policy + Terms of Service links, "Give Permission ✓" button.
- **Creative Brief wizard (Creator band):** Single scrollable page with 4 accordion sections — CHARACTER & ROLE (initially expanded), PERSONALITY, WORLD & SETTING, STORY OPTIONS — plus a sticky "Create Story" button. No separate-page flow; no Companions section.
- **Step navigation:** 4-step nav bar at top (Character → Companions → Setting → Start Writing). Clicking a step changes the bold indicator but does not change page content.
- **Review screen ("Your Story Pitch"):** Shows character name ("Alex"), archetype title ("The Storm Rider"), setting, cast (Solo), format (Illustrated story), and Short/Medium/Long duration picker with "Start Writing" button.

### Element Counts

- Archetype chips: 6 total. 1 selected (readable). 5 unselected (visually blank — white background, invisible text).
- Setting cards: 13 total (8 in row 1, 5 in row 2). 1 selected (readable). 12 unselected (visually blank).
- Personality sliders: 4 (Energy Level, Social Style, Constructive Logic, Adventure Tolerance).
- Story duration options on review: 3 (Short, Medium, Long).

### UI Copy (exact)

- Age gate heading: "How old are you?"
- Age gate subtext: "Parents: please select your child's age"
- Profile setup heading: "Set up your profile"
- Wizard heading: "Build Your Story"
- Wizard subheading: "Define the parameters of your experience."
- Character desire prompt: "What does your character want more than anything?"
- Character desire placeholder: "Optional — adds depth to your story"
- Review heading: "Your Story Pitch"
- Review tagline: "Your story, your way"
- Primary CTA: "Start Writing"

### Console Errors

| Error | Source | Impact |
|-------|--------|--------|
| `HTTP 403 FORBIDDEN` on `/api/stripe/subscription-status/user_...` | Backend call at app start | Subscription check silently fails. Non-blocking. |
| `DartError: Unexpected null value` (×2) | Dart pointer handling at `dart_sdk.js:213621` — triggered by test's raw mouse event injection | Audit-tooling artefact, not caused by normal user interaction. |
| `RenderFlex overflowed by 29 pixels on the bottom` — `_HeroFallbackIdentity` Column at `magic_review_step.dart:1940:12` | Flutter layout engine on review screen render | CRITICAL: avatar widget visually clips and renders "ERFLOWED P" overflow indicator text on screen. Visible to users. |
| TTS API unavailable (console LOG, not error) | `ClientException: Failed to fetch` on `tts/synthesize` | Falls back to on-device TTS. Non-blocking. |

### Navigation Discrepancy

Selecting "THE TEMPORAL THRESHOLD" in the Creative Brief resulted in the review screen displaying **"The Door You're Afraid to Open"** as the setting. The mapping between the UI card key and the human-readable display name appears to be inconsistent.

---

## Yellow Hat — What's Working Well

1. **Age gate is clean and immediate.** The number grid is large, easy to tap, and requires no reading. A 12-year-old can self-select their age in under two seconds.

2. **COPPA consent is thorough and honest.** The three-column disclosure (What We Collect, What We Don't Do, Third-Party Services) is unusually transparent for a children's app. A 12-year-old is old enough to appreciate the directness rather than being patronised.

3. **Gender selection uses illustrated portrait cards.** The illustrated thumbnail images for Boy/Girl are engaging and much more appealing than a radio button or dropdown. The golden glow on the selected state provides satisfying, clear feedback.

4. **"STORM VANGUARD" → "The Storm Rider" is a good content decision.** The archetype name displayed to the user in the review is evocative and story-ready, even if the internal chip label is more mechanical. When it works, it shows thoughtful content design.

5. **Personality sliders are a genuinely mature feature.** Offering nuanced character customisation (Energy Level, Social Style, Analytical/Intuitive, Adventure Tolerance) treats a 12-year-old as a capable author rather than a passive reader. The slider ranges have readable pole labels.

6. **Single-page Creative Brief is conceptually smart for this age.** Teens who understand story structure will appreciate seeing all parameters at once rather than being drip-fed through a child-paced wizard. The accordion sections keep it organised.

7. **Review screen pitch card is elegantly compact.** "Alex / The Storm Rider / Setting: ... / Cast: Solo / Format: Illustrated story" is a legitimate story pitch format that a 12-year-old writer would recognise as professional.

8. **"Your story, your way" tagline is well-judged.** It communicates creative ownership without overselling.

---

## Black Hat — Problems and Risks

### CRITICAL

**C-1: Archetype chips are unreadable when unselected.**
All 6 archetype chips appear as plain white rectangles. The chip text is invisible because the Flutter Material 3 `ChipThemeData` override in `_buildBriefIdentityInputs()` (hero_creator_step.dart ~3428–3465) is not taking effect — the global light ThemeData is winning and rendering the chips with white backgrounds. A 12-year-old sees a row of blank white boxes and has no idea what they represent. Only one chip (the first tapped) reveals its label. The same issue affects ALL 13 setting cards in WORLD & SETTING, and the same fix pattern was attempted there too.

Root cause: `ChipThemeData.backgroundColor` is being overridden by Material 3's chip color scheme. The intended `Color(0xFF1A0A2E)` dark background is not rendering.

**C-2: `_HeroFallbackIdentity` overflow renders visible error pattern on review screen.**
At `magic_review_step.dart:1940:12`, a `Column` inside a 48×48 constrained box (Icon 24px + SizedBox 2px + Text ~14-18px + internal padding) overflows by 29px. Flutter renders this as a yellow-and-black striped pattern inside the avatar circle on the "Your Story Pitch" screen, plus the text "ERFLOWED P" (truncated "OVERFLOWED") is visible. A 12-year-old would likely be confused or amused by this, and it undermines the polished feel of the app at the critical last step before launch.

### SERIOUS

**S-1: Companions selection is absent from the Creator band flow.**
The Creative Brief has no Companions section. The step nav shows "Companions" as step 2, and all 3 steps before "Start Writing" show checkmarks on the review screen — implying companions were "completed." But the user was never given the option to add any. The review screen correctly shows "Cast: Solo." A 12-year-old who wanted to write a story featuring a friend, pet, or sidekick has no way to do so in this band. This either reflects a deliberate decision (Creator band defaults to solo) that is not explained to the user, or a missing feature. Either way, the misleading step nav indicator ("Companions" showing as a step with a checkmark) is dishonest UX.

**S-2: Clicking step nav tabs has no effect on page content.**
Tapping "2 Companions" in the step nav changes the bold text indicator to "Companions" but the page content remains on "Character." The step nav gives the visual impression of being interactive navigation but is actually non-functional in the Creator flow. A 12-year-old exploring the UI will be confused about why tapping the step labels does nothing.

**S-3: Setting selection result is inconsistent with what was chosen.**
The user selected a card that revealed as "THE TEMPORAL THRESHOLD" when clicked. The review screen displayed "The Door You're Afraid to Open" as the setting. Either two different settings have the same first-card position, or the selection binding is off-by-one. A 12-year-old author who carefully chose a setting would find their choice has been changed without explanation.

**S-4: "RESTORE PREVIOUS CHARACTER" section absent after consent flow.**
On the first run in the earlier browser session (before clearing localStorage), the Character step showed a "RESTORE PREVIOUS CHARACTER" accordion. After clearing and starting fresh through consent, this section disappeared entirely, even though the Character & Role accordion was still open. If returning users sometimes see restore and sometimes don't (based on session state timing), that inconsistency can cause confusion.

### MINOR

**M-1: Profile setup screen between age gate and consent is unexpected.**
After tapping "12," the user sees a voice/name entry screen ("Set up your profile") before the COPPA consent screen. Collecting the child's name before parental consent has been given is a potential COPPA edge case — the name is submitted to the backend before consent is established. This should be reviewed with legal counsel.

**M-2: Age gate "14" is not visible at 762×484 viewport.**
The grid shows ages 2–13 but the scroll hint for age 14+ is cut off. If the content requires scrolling that isn't obviously indicated, older teens may miss their age band.

**M-3: Archetype display name and internal key are inconsistent.**
The chip shows "STORM VANGUARD" (uppercase internal name) but the review shows "The Storm Rider" (human display name). If the chip label and display name always differ this much, the chip label itself is not user-meaningful.

**M-4: "Standard View" narrative mode label is opaque.**
What does "Standard View" mean to a 12-year-old author? The setting offers no tooltip or explanation. Other narrative modes (if available) would face the same problem.

**M-5: TTS silently unavailable.**
Backend TTS fails silently on startup and falls back to on-device synthesis. A 12-year-old who chose Story Weaver partly for its narration will get degraded audio quality with no explanation.

---

## Red Hat — How It Feels to Be 12 Years Old Here

**Age gate:** Quick win. Tapping my own age from a grid of numbers feels correct and easy. No friction. I don't read the subtext about parents — I just tap 12.

**Profile setup:** "Tap to say your name" is cool — I might try the microphone. Typing my name feels fine but also slightly mundane, like a school form.

**Parental consent:** Oh. I have to wait for a grown-up. That's slightly deflating — I thought I was going to start creating. The consent screen is long. I probably scroll past it quickly. The items about "we never sell your data" feel reassuring but not exciting.

**Gender screen / Character setup:** This feels like an actual game character creator! The illustrated portraits are nice — significantly better than a dropdown. The golden glow when I select Girl is satisfying.

**Archetype chips:** What are these? Six white boxes in a row. I'll tap one to see what happens. Oh — "STORM VANGUARD." That's cool. But what are the other five? They're just blank. I feel like something's broken. I can't browse my options. I'm stuck choosing blind or tapping each one in turn.

**Personality sliders:** This is actually kind of interesting. It makes me feel like a game designer tuning a character stat sheet. "Analytical vs. Intuitive" — I get that. I feel respected as someone who knows what those words mean.

**World & Setting:** Same blank-cards problem as archetypes, but worse — 13 blank white rectangles. I tap one and see "THE TEMPORAL THRESHOLD." That sounds intriguing! But I can't browse the list. I feel frustrated that I can't see my options.

**Story Options:** "Standard View" and "Short" defaults. I accept these without thinking much. The labels don't inspire me to explore.

**"Create Story" button:** I'm excited. This is the moment. Big yellow button, can't miss it.

**Review screen:** "Your Story Pitch" — oh, I like the pitch-card framing. But there's a weird glitch in the avatar circle (the overflow stripes/text). That's a bit embarrassing. And the setting says "The Door You're Afraid to Open" — I didn't pick that, I picked "THE TEMPORAL THRESHOLD." Did the app ignore my choice? I feel a small loss of ownership. But "Start Writing" is right there and I'm still excited to see what happens.

**Overall emotional arc:** Curiosity → brief gate frustration → good momentum through character setup → mounting confusion and frustration at invisible option cards → recovered excitement at Create Story → mild unease at the review glitch → cautious excitement to proceed.

---

## Green Hat — Ideas and Opportunities

1. **Show archetype chip labels at rest — use a two-line chip design.** The fix is simple: ensure chip text is always visible by using a contrasting dark background and light text regardless of selection state. Consider a compact two-line chip: archetype name on top, one-word trait tag below. This turns the selection grid into a browsable catalogue, not a guessing game.

2. **Bring Companions back to the Creator brief — or be explicit about Solo.**
   Add a brief "Adventure Team" subsection (collapsed by default) in the Creative Brief. Even a single line — "Solo story / Add a companion..." — gives the user meaningful control. If solo is intentional for Creator, add a short explanation: "Creator stories focus on your protagonist's solo journey. Add companions in your character library." Either way, remove "Companions" from the step nav or make it reflect reality.

3. **Fix step-nav taps to jump-scroll to the corresponding accordion section.**
   The step nav is already interactive-looking. Wire each tap to scroll the page to and expand the matching accordion. This would turn a confusing dead-click into a genuine navigation shortcut that empowers the user to edit any section at any time.

4. **Add a "hover preview" on setting cards before selection.**
   On web (or with a long-press on mobile), show a 1–2 sentence preview of the setting. A 12-year-old choosing between 13 settings needs enough information to make a meaningful choice. Even showing the card name in a tooltip before tapping would be a significant improvement over the current blank-card behaviour.

5. **Fix the review avatar overflow — add `clipBehavior: Clip.hardEdge` to `_GradientSphereFallback`.**
   The fix is a one-line change in `magic_review_step.dart`. The `_HeroFallbackIdentity` Column should either have its children simplified (remove the SizedBox spacer, reduce icon size to 20, reduce text fontSize to 11) or the container should use `ClipRect`/`ClipRRect` to prevent the overflow rendering artifact.

6. **Rename "Standard View" to something meaningful for a 12-year-old.**
   Options: "Illustrated Story," "Reading Mode," "Classic Story." Or use the existing `_getReadingLabel()` function's output as the dropdown label. Add a one-sentence description below the dropdown: "Illustrated chapters with character artwork."

7. **Move the name-entry step to after parental consent.**
   Currently the profile setup screen appears before COPPA consent is given. Collecting the child's first name before consent is an unnecessary legal risk. The sequence should be: age → consent → name → wizard.

8. **Show the selected setting name in the archetype chip before submission.**
   When a setting chip is selected (showing a checkmark), display its name in large text directly below the chip grid: "Selected: The Temporal Threshold." This eliminates the "what did I actually select?" ambiguity and the inconsistency between chip display and review screen display.

---

## Blue Hat — Priorities and Next Steps

### Action Table

| # | Issue | Severity | Effort | Recommended Owner |
|---|-------|----------|--------|-------------------|
| 1 | Archetype + Setting chips visually blank (white-on-white) | CRITICAL | Low (CSS/theme fix) | Frontend |
| 2 | `_HeroFallbackIdentity` overflow on review avatar | CRITICAL | Low (clip + size fix, 1 line in `magic_review_step.dart:1940`) | Frontend |
| 3 | Setting selected ≠ setting displayed on review | SERIOUS | Medium (data binding audit) | Frontend |
| 4 | No Companions in Creator flow — step nav shows Companions checkmark | SERIOUS | Medium (add section or remove from nav) | Product + Frontend |
| 5 | Step nav tabs non-functional (no scroll/expand on tap) | SERIOUS | Medium | Frontend |
| 6 | Name collected before parental consent | MINOR-LEGAL | Low (reorder screens) | Frontend + Legal |
| 7 | "Standard View" label opaque | MINOR | Low | Content/UX |
| 8 | Age 14+ off-screen at small viewport | MINOR | Low | Frontend |

### Top 3 Fixes If Only 3 Are Possible

**Fix 1 — Chip visibility (CRITICAL, Low effort):**
In `hero_creator_step.dart` `_buildBriefIdentityInputs()`, the `ChipThemeData` override isn't applying reliably under Material 3. Switch to explicit `FilterChip` style parameters (`backgroundColor`, `color`, `labelStyle`) set directly on each chip instance rather than relying on `Theme.of(context).copyWith`. The same fix applies to the Setting card rendering in `_buildBriefWorldInputs()`.

**Fix 2 — Review avatar overflow (CRITICAL, Low effort):**
In `magic_review_step.dart`, wrap `_HeroFallbackIdentity` in a `ClipRect` or add `overflow: TextOverflow.clip` to the text, and reduce the Icon size from 24 to 18 and Text fontSize from 14 to 11 inside `_HeroFallbackIdentity.build()`. This ensures the content fits within the 48×48 container constraint.

**Fix 3 — Companions in step nav (SERIOUS, Medium effort):**
Either (a) remove "Companions" from the 4-step nav for Creator band and replace with "Brief" (showing the single-page brief metaphor), or (b) add a minimal Companions accordion section to `_buildCreativeBrief()` between Personality and World & Setting, using the existing `_buildAdventureTeamPage()` content in compact form.

---

*Audit conducted via automated Playwright walkthrough. Screenshots saved to `docs/ux_audit_creator_12yo_2026-03-31/`. All findings should be verified on native mobile (iOS/Android) as some rendering behaviours (especially chip theming) may differ from the Flutter web renderer.*
