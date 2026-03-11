# Story Weaver — Age UX Implementation Plan
**Based on:** UX Age-Appropriateness Audit (March 7, 2026)
**Last Updated:** March 8, 2026
**Purpose:** Executable task list for implementing all audit fixes, ordered by priority.
**Target reader:** Any developer or LLM implementation agent.

---

## Six Thinking Hats Pre-Flight Review

**White Hat (What's already done — DO NOT re-implement):**
- `_isReaderLayout` getter (`story_result_screen.dart:165`) and `_buildReaderView()` (line 1670) are fully implemented and branched correctly at line 2430.
- Mode selector in `hero_creator_step.dart:1529` already shows `'Poetry'` for age >= 11 vs `'Rhyme Time'`.
- Pick-a-Path is already hidden for age <= 4 at `hero_creator_step.dart:1541` (`if (data.characterAge > 4)`).
- Learn-to-Read is already hidden for age >= 9 at `hero_creator_step.dart:1553` (`if (data.characterAge < 9)`).
- Wisdom Gem for age >= 14 already uses `ExpansionTile` at `story_result_screen.dart:1816`.
- Creative Brief view already renders for `band == AgeBand.creator` (ages 13+) at `hero_creator_step.dart:2564`.
- `_triggerPageCelebration()` at line 266 already calls `MotionPrefs.showParticles(context)` before firing the star burst. The **chime audio** still fires unconditionally — that is the gap.

**Red Hat (Emotional impact — prioritization guide):**
- A 12-year-old seeing a sparkle "MAKE MAGIC" button in a page-flip storybook will close the app. **Most visible embarrassment.**
- A 4-year-old facing a keyboard to type their name is completely stuck. **Biggest functional blocker for youngest users.**
- A 14-year-old getting an auto-popping sparkle "Wisdom Gem" pop-up after a story feels condescended to.

**Black Hat (Regression risks — flag for testing):**
- `ageBandFromAge()` is used everywhere. Changing the age 12 threshold cascades to every widget that checks `AgeBand.creator`. Test all wizard pages at age 12 after P1-3.
- `_archetypeDisplayName()` must NOT change the value used in selection comparison (`_selectedArchetypeId == a.name`). Only the *display text* changes, not the identifier.
- The PNG image assets in `ImageMakeMagicButton` have text baked in. Changing `label:` only affects accessibility semantics and the fallback text widget.
- `_build_rhyme_time_prompt` is called from tests. New branches must not break existing test fixtures.

**Yellow Hat (Highest impact / simplest change):**
- One-line threshold change in `ageBandFromAge()` makes age-12 users see the Creator theme (P1-3).
- Inline ternary label in `magic_review_step.dart` changes "MAKE MAGIC" per band (P0-1).
- Backend rhyme branching is isolated in one function, zero frontend impact (P0-2).

**Blue Hat (Process — ordering):**
- Do **backend** changes first (no Flutter rebuild needed).
- Do **P1-3** (age threshold) before P1-1 (archetype names) since archetype code checks `AgeBand.creator`.
- All P0 tasks are otherwise independent.
- P2 and P3 tasks are all independent of each other.

---

## Implementation Order

1. Backend: P0-2, P0-6, P2-4, CC-1 (no Flutter compile)
2. P1-3 (age band threshold — foundational)
3. P0-1, P0-3, P0-4, P0-5 (high-visibility Flutter changes)
4. P1-1, P1-2, CC-2 (copy/display polish)
5. P2-1 through P2-5 (enhancement pass)
6. P3-1 through P3-3 (stretch goals)

---

## P0 — Fix Now (Critical, Independent of Each Other)

### P0-1: "Make Magic" Button Label — Band-Aware

**File:** `lib/screens/wizard_steps/magic_review_step.dart`

**What to find:** Line ~593 — `ImageMakeMagicButton(... label: 'MAKE MAGIC')` inside the `Center(...)` widget in `build()`.

The `build()` method already has `final band = Theme.of(context).extension<AgeBandThemeData>() ?? explorerTheme;` near its top.

**Exactly what to change:**

Add this variable just before the `Center(...)` widget that contains the button:
```dart
final String _magicButtonLabel = band.band == AgeBand.creator
    ? 'CREATE STORY'
    : band.band == AgeBand.adventurer
        ? 'START ADVENTURE'
        : 'MAKE MAGIC';
```

Then replace `label: 'MAKE MAGIC'` with `label: _magicButtonLabel`.

Also find in `lib/screens/wizard_story_screen.dart:207` and `lib/screens/wizard_story_screen.dart:227`:
```dart
'Make Magic!'
'Make Magic'
```
These also need band-aware labels. Apply the same ternary logic using `band.band` in that file.

**Note on ImageMakeMagicButton:** The PNG image asset has text baked in. The `label:` parameter only changes `Semantics.label` (accessibility) and the fallback text widget. The visual button image text does NOT change from this edit alone. The accessibility fix is still worth doing.

**Test condition:**
- Age 14 → `Semantics.label` is "CREATE STORY".
- Age 9 → "START ADVENTURE".
- Age 6 → "MAKE MAGIC".
- No visual regression in any age band.

---

### P0-2: Rhyme Time Backend — Graduated Poem Forms

**File:** `backend/services/story_service.py`

**What to find:** The function `_build_rhyme_time_prompt` at line 759. The age branching block at lines 773–779:
```python
age_instruction = ""
if age <= 5:
    age_instruction = "Write a full rhyming story. Use simple, magical vocabulary..."
elif age >= 11:
    age_instruction = "Format as a sophisticated narrative poem..."
else:
    age_instruction = "Write a full rhyming story that is uplifting and fun."
```
And the line at ~828:
```
Scheme: Consistent AABB or ABCB.
```

**Exactly what to change:**

Replace the entire `age_instruction = ""` block (the three-branch if/elif/else) with:

```python
age_instruction = ""
rhyme_scheme_instruction = "Consistent AABB rhyme scheme."

if age <= 5:
    age_instruction = (
        "Write a full rhyming story. Use simple, magical vocabulary. "
        "Focus on wonder and sensory delight. Very short sentences (4-6 words per line)."
    )
    rhyme_scheme_instruction = (
        "Consistent AABB rhyme scheme. Very simple vocabulary (CVC words and sight words)."
    )
elif age <= 8:
    age_instruction = (
        "Write a fun, bouncy rhyming story. Use playful rhythm. "
        "Include a funny moment and a satisfying rhyming resolution."
    )
    rhyme_scheme_instruction = (
        "Use AABBA limerick or simple AABB couplets. "
        "Vary line lengths slightly for a bouncy feel."
    )
elif age <= 10:
    age_instruction = (
        "Write a ballad-style rhyming story with a clear narrative arc. "
        "Use ABCB (ballad) or rhyming couplets. Include vivid imagery and a twist. "
        "No sing-song bouncy limericks — aim for genuine story tension."
    )
    rhyme_scheme_instruction = (
        "Use ABCB ballad scheme or rhyming couplets (AABB). "
        "Each stanza 4 lines. Build toward a satisfying climax."
    )
elif age >= 13:
    age_instruction = (
        "Write a sophisticated poem — free verse or sonnet form. "
        "Explore identity, resilience, or complex emotion. "
        "Avoid sing-song rhymes; prefer slant rhyme or internal rhyme. "
        "Write as literary fiction poetry, not a children's rhyme."
    )
    rhyme_scheme_instruction = (
        "Free verse OR sonnet (14 lines, ABAB CDCD EFEF GG). "
        "Prioritize emotional resonance over rigid rhyme. No limericks."
    )
else:  # age 11-12
    age_instruction = (
        "Format as a narrative poem or epic ballad. Avoid babyish tones. "
        "Explore themes like identity, resilience, or complex friendships. "
        "Use vivid metaphor and internal rhyme. No limericks."
    )
    rhyme_scheme_instruction = (
        "Use ABAB or ABCB narrative ballad form. 4-8 line stanzas. "
        "Build dramatic tension and resolve it in the final stanza."
    )
```

Then in the f-string return (line ~828), replace:
```
Scheme: Consistent AABB or ABCB.
```
with:
```
Scheme: {rhyme_scheme_instruction}
```

**Test condition:**
- `_build_rhyme_time_prompt('Alex', 'Space', 4, {})` → prompt contains "CVC words".
- Age 9 → prompt contains "ballad" and does NOT contain "limerick".
- Age 14 → prompt contains "Free verse OR sonnet". No limericks.
- Age 12 → prompt contains "ABAB or ABCB narrative ballad".
- Age 7 → prompt contains "AABBA limerick".

---

### P0-3: Wisdom Gem — Four-Tier Age-Graduated Delivery

**File:** `lib/story_result_screen.dart`

**What to find:** The Wisdom Gem rendering block starting around line 1814:
```dart
if (widget.wisdomGem.isNotEmpty) ...[
  const SizedBox(height: 24),
  if (_effectiveAge >= 14)
    Container( ... ExpansionTile ... )
  else
    Container( ... static flat display ... )
```

**Exactly what to change:**

Step 1 — Replace the entire `if (widget.wisdomGem.isNotEmpty) ...[...]` block with:
```dart
if (widget.wisdomGem.isNotEmpty) ...[
  const SizedBox(height: 24),
  _buildWisdomGem(),
],
```

Step 2 — Add the following private method to `_StoryResultScreenState`. Place it after the existing `_buildEndOfStoryPage()` method:

```dart
Widget _buildWisdomGem() {
  // Ages 3-7: Large, animated, prominent — full sparkle display
  if (_effectiveAge <= 7) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
      margin: const EdgeInsets.symmetric(horizontal: 24),
      decoration: BoxDecoration(
        color: AppColors.gold.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: AppColors.gold.withValues(alpha: 0.6),
          width: 2,
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.gold.withValues(alpha: 0.25),
            blurRadius: 16,
            spreadRadius: 2,
          ),
        ],
      ),
      child: Column(
        children: [
          const Icon(Icons.auto_awesome, color: AppColors.gold, size: 40),
          const SizedBox(height: 10),
          Text(
            widget.wisdomGem,
            textAlign: TextAlign.center,
            style: GoogleFonts.quicksand(
              fontSize: 22 * _textScale,
              fontWeight: FontWeight.bold,
              fontStyle: FontStyle.italic,
              color: _highContrastMode ? Colors.white : const Color(0xFF2C3E50),
            ),
          ),
        ],
      ),
    );
  }
  // Ages 8-10: Discoverable — medium prominence, no animation, no glow
  if (_effectiveAge <= 10) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      margin: const EdgeInsets.symmetric(horizontal: 24),
      decoration: BoxDecoration(
        color: AppColors.gold.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.gold.withValues(alpha: 0.4)),
      ),
      child: Column(
        children: [
          const Icon(Icons.auto_awesome, color: AppColors.gold, size: 28),
          const SizedBox(height: 8),
          Text(
            widget.wisdomGem,
            textAlign: TextAlign.center,
            style: GoogleFonts.quicksand(
              fontSize: 18 * _textScale,
              fontWeight: FontWeight.w600,
              fontStyle: FontStyle.italic,
              color: _highContrastMode ? Colors.white : const Color(0xFF2C3E50),
            ),
          ),
        ],
      ),
    );
  }
  // Ages 11-13: Optional tap-to-reveal tile, labelled "Story Reflection"
  if (_effectiveAge <= 13) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 24),
      decoration: BoxDecoration(
        color: AppColors.gold.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.gold.withValues(alpha: 0.4)),
      ),
      child: ExpansionTile(
        leading: const Icon(Icons.auto_awesome, color: AppColors.gold),
        title: Text(
          'Story Reflection',
          style: GoogleFonts.quicksand(
            fontSize: 16 * _textScale,
            fontWeight: FontWeight.bold,
            color: _highContrastMode ? Colors.white : const Color(0xFF2C3E50),
          ),
        ),
        iconColor: AppColors.gold,
        collapsedIconColor: AppColors.gold,
        shape: const Border(),
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
            child: Text(
              widget.wisdomGem,
              textAlign: TextAlign.center,
              style: GoogleFonts.quicksand(
                fontSize: 16 * _textScale,
                fontWeight: FontWeight.w500,
                fontStyle: FontStyle.italic,
                color: _highContrastMode
                    ? Colors.white70
                    : const Color(0xFF2C3E50),
              ),
            ),
          ),
        ],
      ),
    );
  }
  // Ages 14+: Plain "Reflection" text, collapsed by default, minimal decoration
  return Container(
    margin: const EdgeInsets.symmetric(horizontal: 24),
    decoration: BoxDecoration(
      color: AppColors.gold.withValues(alpha: 0.08),
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: AppColors.gold.withValues(alpha: 0.25)),
    ),
    child: ExpansionTile(
      leading: Icon(Icons.auto_awesome,
          color: AppColors.gold.withValues(alpha: 0.6), size: 18),
      title: Text(
        'Reflection',
        style: GoogleFonts.quicksand(
          fontSize: 14 * _textScale,
          fontWeight: FontWeight.w600,
          color: _highContrastMode ? Colors.white70 : Colors.grey[600]!,
        ),
      ),
      iconColor: AppColors.gold.withValues(alpha: 0.6),
      collapsedIconColor: AppColors.gold.withValues(alpha: 0.4),
      shape: const Border(),
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
          child: Text(
            widget.wisdomGem,
            textAlign: TextAlign.center,
            style: GoogleFonts.quicksand(
              fontSize: 14 * _textScale,
              fontWeight: FontWeight.w400,
              fontStyle: FontStyle.italic,
              color: _highContrastMode ? Colors.white54 : Colors.grey[500]!,
            ),
          ),
        ),
      ],
    ),
  );
}
```

**Note:** `AppColors.gold` must be in scope. If it is not, use `const Color(0xFFFFD700)` everywhere instead.

**Test condition:**
- Age 6 → Wisdom Gem shows large prominent gold box with auto_awesome icon, no collapse.
- Age 9 → Medium gold box, no collapse, no glow.
- Age 12 → Shows "Story Reflection" expansion tile, collapsed by default.
- Age 15 → Shows plain "Reflection" collapsed tile with muted colors.

---

### P0-4: Wizard Page-Celebration Chime — Gate by Age Band

**File:** `lib/screens/wizard_steps/hero_creator_step.dart`

**What to find:** The `_triggerPageCelebration()` method at line 266:
```dart
void _triggerPageCelebration() {
  AudioAmbienceService().playSfx('sounds/magical_shimmer.mp3');
  _showStarBurst();
}
```

Note: `_showStarBurst()` at line 272 already checks `MotionPrefs.showParticles`. The gap is that `playSfx` fires unconditionally.

**Exactly what to change:**

Replace the method body:
```dart
void _triggerPageCelebration() {
  final band =
      Theme.of(context).extension<AgeBandThemeData>() ?? explorerTheme;
  // Only play the magical shimmer chime for Sprout and Explorer bands.
  // Older users find the chime childish.
  if (band.band == AgeBand.sprout || band.band == AgeBand.explorer) {
    AudioAmbienceService().playSfx('sounds/magical_shimmer.mp3');
  }
  _showStarBurst();
}
```

**Test condition:**
- Age 6 → navigating wizard pages plays shimmer chime.
- Age 10 → no shimmer chime on page advance.
- Age 14 → no shimmer chime. Particles also suppressed (existing behavior via `showParticles`).

---

### P0-5: CinzelDecorative Font Leak — Guard for Adventurer/Creator Bands

**File:** `lib/screens/wizard_steps/hero_creator_step.dart`

This covers the font showing in the hero name input for all age bands.

**Sub-fix A — "HERO'S NAME" label in `_buildNameScrollInput()` (line ~2181):**

The method already reads `band` from the theme. Find:
```dart
Text(
  "HERO'S NAME",
  style: GoogleFonts.cinzelDecorative(
    color: const Color(0xFFFFE082).withAlpha(200),
    fontSize: 11,
    letterSpacing: 2.0,
    fontWeight: FontWeight.w600,
  ),
),
```

Replace with:
```dart
Text(
  "HERO'S NAME",
  style: (band.band == AgeBand.adventurer || band.band == AgeBand.creator)
      ? GoogleFonts.sourceSans3(
          color: const Color(0xFFFFE082).withAlpha(200),
          fontSize: 11,
          letterSpacing: 2.0,
          fontWeight: FontWeight.w700,
        )
      : GoogleFonts.cinzelDecorative(
          color: const Color(0xFFFFE082).withAlpha(200),
          fontSize: 11,
          letterSpacing: 2.0,
          fontWeight: FontWeight.w600,
        ),
),
```

**Sub-fix B — `_ThemedNameInputState.build()` (lines ~4567, ~4577):**

At the top of the `build()` method of `_ThemedNameInputState`, add:
```dart
final band = Theme.of(context).extension<AgeBandThemeData>() ?? explorerTheme;
final bool useDecorative =
    band.band == AgeBand.sprout || band.band == AgeBand.explorer;
```

Then replace the `TextField`'s `style:` property:
```dart
style: useDecorative
    ? GoogleFonts.cinzelDecorative(
        fontSize: widget.fontSize,
        color: Colors.white,
        fontWeight: FontWeight.w700,
        shadows: const [Shadow(color: Color(0xFFFFD54F), blurRadius: 6)],
      )
    : GoogleFonts.sourceSans3(
        fontSize: widget.fontSize,
        color: Colors.white,
        fontWeight: FontWeight.w600,
      ),
```

Replace the `hintStyle:` property:
```dart
hintStyle: useDecorative
    ? GoogleFonts.cinzelDecorative(
        color: const Color(0xFFFFE082).withAlpha(180),
        fontSize: widget.fontSize * 0.85,
        fontWeight: FontWeight.w400,
      )
    : TextStyle(
        color: Colors.white30,
        fontSize: widget.fontSize * 0.85,
      ),
```

**Sub-fix C — `_GenderImageButton.build()` (line ~4445):**

Find in `_GenderImageButtonState.build()` a `Text` with `GoogleFonts.cinzelDecorative`. Add the same band guard as Sub-fix A:
```dart
final band = Theme.of(context).extension<AgeBandThemeData>() ?? explorerTheme;
final bool useDecorative =
    band.band == AgeBand.sprout || band.band == AgeBand.explorer;
```
Then apply the same inline ternary to the text style.

**Sub-fix D — `_CharacterChoiceCard` (line ~3098):**

Inside the character choice card (used on the "Welcome back" page 0), find a `Text(...)` using `GoogleFonts.cinzelDecorative` for the character name. Apply the same band-aware guard: use `GoogleFonts.quicksand` for sprout/explorer, `GoogleFonts.bitter` for adventurer, `GoogleFonts.sourceSans3` for creator.

**Test condition:**
- Age 5 → hero name input shows CinzelDecorative font (decorative, magical).
- Age 10 → hero name input shows SourceSans3 (clean, slab-free).
- Age 14 → SourceSans3. No CinzelDecorative visible anywhere in wizard.

---

### P0-6: Learn-to-Read Backend Guard (Age >= 9)

**File:** `backend/services/story_service.py` (or `backend/tasks/story_tasks.py` — wherever the LTR prompt dispatch occurs)

**What to find:** The block dispatching to `_build_learning_to_read_prompt`. Grep for `learning_to_read_mode` in story_service.py and tasks files.

**Exactly what to change:**

Find the block:
```python
if learning_to_read_mode:
    prompt = _build_learning_to_read_prompt(...)
```

Prepend an age guard:
```python
if learning_to_read_mode:
    # Backend safety guard: LTR mode is only meaningful for ages < 9.
    # The UI gates this, but this ensures backend safety if the UI is bypassed.
    _age_val = age if isinstance(age, int) else (int(age) if str(age).isdigit() else 5)
    if _age_val >= 9:
        learning_to_read_mode = False  # Fall through to standard story generation
    else:
        prompt = _build_learning_to_read_prompt(...)
```

The `elif rhyme_time_mode:` block that follows must NOT be moved into the else — it should remain at the same indent level and trigger when `learning_to_read_mode` becomes False.

Restructure as:
```python
if learning_to_read_mode and _age_val < 9:
    prompt = _build_learning_to_read_prompt(...)
elif rhyme_time_mode:
    prompt = _build_rhyme_time_prompt(...)
else:
    prompt = _build_story_prompt(...)
```

**Test condition:**
- POST `/generate-story` with `{"learning_to_read_mode": true, "age": 10}` → returns a standard story (not LTR format).
- Same with `age: 9` → standard story.
- With `age: 8` → LTR story (limerick format for age 7-8).

---

## P1 — Fix This Sprint

> **IMPORTANT:** Do P1-3 before P1-1, since P1-1 uses `AgeBand.creator` which changes threshold.

---

### P1-3 (FIRST): Creator Band Threshold — Age 12 Instead of 13

**File:** `lib/theme/age_band_theme.dart`

**What to find:** The `ageBandFromAge` function at line ~25:
```dart
AgeBand ageBandFromAge(int age) {
  if (age <= 5) return AgeBand.sprout;
  if (age <= 8) return AgeBand.explorer;
  if (age <= 12) return AgeBand.adventurer;
  return AgeBand.creator;
}
```

**Exactly what to change:**

Change `if (age <= 12)` to `if (age <= 11)`:
```dart
AgeBand ageBandFromAge(int age) {
  if (age <= 5) return AgeBand.sprout;
  if (age <= 8) return AgeBand.explorer;
  if (age <= 11) return AgeBand.adventurer;
  return AgeBand.creator;
}
```

Also update the doc comments on the enum values:
- `AgeBand.adventurer` doc: change `Ages 9-12` to `Ages 9-11`
- `AgeBand.creator` doc: change `Ages 13+` to `Ages 12+`

**Regression check:** After this change, age 12 sees Creator theme: dark background, Source Sans 3 font, no sparkles, Creative Brief wizard. Age 11 sees Adventurer theme. Test both boundaries manually.

**Test condition:**
- Set character age to 12 → wizard shows dark Creator theme, Creative Brief layout, no shimmer chime.
- Set age to 11 → standard wizard with Adventurer theme.
- Set age to 13 → Creator theme (unchanged from before).

---

### P1-1 (After P1-3): Archetype Card Names for Creator Band

**File:** `lib/screens/wizard_steps/hero_creator_step.dart`

**What to find:** The `_buildArchetypeCards()` method. The archetype `name` field is used in two ways:
1. As display text in the card (`a.name` in `Text(...)`)
2. As the selection identifier in `_selectedArchetypeId == a.name`

Only change the display text. Do NOT change the identifier comparisons.

**Exactly what to change:**

Add this helper method anywhere within `_HeroCreatorStepState`, after `_buildArchetypeCards()`:

```dart
/// Returns a display name for the archetype, adapted for the age band.
/// The internal `archetype.name` (used for backend/identity) is unchanged.
String _archetypeDisplayName(ArchetypeData archetype, AgeBand band) {
  if (band != AgeBand.creator) return archetype.name;
  const Map<String, String> creatorNames = {
    'The Storm Rider': 'The Strategist',
    'The Quiz Whiz': 'The Analyst',
    'The Master Creator': 'The Visionary',
    'The Heart Healer': 'The Empath',
    'The Lightning Runner': 'The Catalyst',
    'The Animal Whisperer': 'The Observer',
  };
  return creatorNames[archetype.name] ?? archetype.name;
}
```

Then find every `Text(a.name, ...)` or `Text(archetype.name, ...)` that is used as a *card display label* in the archetype selection. Replace with:
```dart
Text(_archetypeDisplayName(a, ageBand), ...)
```
or:
```dart
Text(_archetypeDisplayName(archetype, ageBand), ...)
```

For the Creative Brief's `ChoiceChip` at line ~2799:
```dart
label: Text(archetype.name.toUpperCase()),
```
Replace with:
```dart
label: Text(_archetypeDisplayName(archetype, ageBand).toUpperCase()),
```
Ensure `ageBand` is in scope — if not, add `final ageBand = ageBandFromAge(widget.wizardData.characterAge);` near the top of the enclosing method.

**Test condition:**
- Age 13 → archetype cards show "The Strategist", "The Analyst", etc.
- Age 10 → archetype cards show original names ("The Storm Rider", etc.).
- Selecting "The Strategist" at age 13 correctly stores `_selectedArchetypeId = 'The Storm Rider'` (the original name). Verify the backend receives the original name.

---

### P1-2: Hardcoded Wizard Heading — "Pick your hero style first!"

**File:** `lib/screens/wizard_steps/hero_creator_step.dart`

**What to find:** Line ~658:
```dart
return Text('Pick your hero style first!',
    style: _bandTitleStyle(band, baseFontSize: 22));
```

**Exactly what to change:**

Replace with band-aware string:
```dart
final String archetypePageTitle = band.band == AgeBand.creator
    ? 'Character archetype'
    : band.band == AgeBand.adventurer
        ? 'Choose your hero type'
        : 'Pick your hero style!';
return Text(archetypePageTitle,
    style: _bandTitleStyle(band, baseFontSize: 22));
```

Also audit the file for other hardcoded exclamation-point wizard headings for ages 11+. Grep for `'.*!'` in `Text()` widgets within `hero_creator_step.dart` and apply band-aware versions for any page title that uses an exclamation mark. Apply the same pattern: suppress `!` for Adventurer/Creator bands.

**Test condition:**
- Age 14 → page 2 shows "Character archetype" (no exclamation mark).
- Age 10 → "Choose your hero type".
- Age 6 → "Pick your hero style!".

---

## P2 — Next Sprint

### P2-1: Personality Sliders — Reduce to 3 for Explorer Band (Ages 5-7)

**File:** `lib/screens/wizard_steps/hero_creator_step.dart`

**What to find:** Grep `personalitySliders` in the file. Find the builder method that renders the personality slider widgets for the regular (non-Creative Brief) wizard path. Likely a `_buildPersonalityPage()` or similar inside the non-creator wizard path.

**Exactly what to change:**

At the point where the sliders list is built, apply:
```dart
// Explorer/Sprout bands: show only 3 sliders with emoji anchors.
final entries = widget.wizardData.personalitySliders.entries.toList();
final int sliderCount =
    (band.band == AgeBand.explorer || band.band == AgeBand.sprout)
        ? 3
        : entries.length;
final displayedEntries = entries.take(sliderCount).toList();
```

For each slider in the Explorer/Sprout band, wrap in a `Row` with emoji labels:
```dart
if (band.band == AgeBand.sprout || band.band == AgeBand.explorer)
  Row(
    children: [
      Text(_sliderStartEmoji(entry.key), style: const TextStyle(fontSize: 22)),
      Expanded(child: Slider(...existing slider...)),
      Text(_sliderEndEmoji(entry.key), style: const TextStyle(fontSize: 22)),
    ],
  )
else
  Slider(...existing slider...),
```

Add the emoji helper method:
```dart
String _sliderStartEmoji(String traitKey) {
  const map = {
    'energy': '😴',
    'sociability': '🙈',
    'creativity': '📖',
    'confidence': '🤫',
    'empathy': '🤐',
    'adventurousness': '🛋️',
  };
  return map[traitKey.toLowerCase()] ?? '😐';
}

String _sliderEndEmoji(String traitKey) {
  const map = {
    'energy': '⚡',
    'sociability': '🎉',
    'creativity': '🎨',
    'confidence': '🦁',
    'empathy': '💖',
    'adventurousness': '🚀',
  };
  return map[traitKey.toLowerCase()] ?? '😊';
}
```

**Test condition:**
- Age 6 → only 3 personality sliders appear, each with emoji at both ends.
- Age 10 → all 5-6 sliders appear, no emoji anchors.
- Age 14 → Creative Brief sliders unaffected (separate path).

---

### P2-2: Feelings Lanterns — Emoji Anchors for Ages 5-7

**File:** Locate by grepping for `MoodLanternSelector`, `FeelingsLantern`, or `FeelingSelection` in `lib/`. The feelings step is likely `lib/screens/wizard_steps/feeling_selection_step.dart` or a widget in the feelings flow.

**What to find:** The widget that builds individual lantern/mood tiles.

**Exactly what to change:**

In the build method of each lantern/mood item, after checking the band:
```dart
if (band.band == AgeBand.sprout || band.band == AgeBand.explorer)
  Padding(
    padding: const EdgeInsets.only(top: 4),
    child: Text(
      feeling.emoji,   // use the field that holds the emotion emoji
      style: const TextStyle(fontSize: 22),
      textAlign: TextAlign.center,
    ),
  ),
```

Add this inside the Column that builds each lantern tile.

**Test condition:**
- Age 6 → each feelings lantern shows a large visible emoji label below it.
- Age 10 → no emoji labels under lanterns (existing behavior).

---

### P2-3: Age Picker Scroll — Center on Stored Age

**File:** `lib/screens/wizard_steps/hero_creator_step.dart`

**What to find:** Grep `FixedExtentScrollController` in the file. The age scroll wheel controller initialization.

**Exactly what to change:**

Find the `FixedExtentScrollController(initialItem: 0)` or equivalent that starts the age picker at the minimum age. Change to:

```dart
FixedExtentScrollController(
  initialItem: (widget.wizardData.characterAge - kMinHeroAge)
      .clamp(0, kMaxHeroAge - kMinHeroAge),
)
```

Where `kMinHeroAge` is the minimum allowed age (3) and `kMaxHeroAge` is the maximum (18 or 99). If these constants don't exist, use the literal values:
```dart
FixedExtentScrollController(
  initialItem: (widget.wizardData.characterAge - 3).clamp(0, 96),
)
```

If the controller is initialized in `initState`, ensure `widget.wizardData.characterAge` is validated first (it defaults to 7 per line 116).

**Test condition:**
- User with saved age 10 opens wizard → scroll wheel is centered on 10, not scrolled to age 3.
- New user (no saved age, defaults to 7) → scroll centered on 7.

---

### P2-4: Interactive Story — Moral Complexity for Ages 11-13 (Backend)

**File:** `backend/services/interactive_adventure_prompt_builder.py`

**What to find:** The `build_opening_prompt` method (~line 250) and `build_continuation_prompt` (~line 442). Find where `TEEN_TONE_INSTRUCTION` is conditionally added (the `if age >= 15` block).

**Exactly what to change:**

Add a new class constant:
```python
MORAL_COMPLEXITY_INSTRUCTION = """
**MORAL COMPLEXITY GUIDE (Ages 11-13)**:
- Choices must NOT have an obvious right answer. Each path should have a genuine trade-off.
- Good example: Option A helps the hero's goal but disappoints a friend. Option B protects the friend but slows the mission.
- Avoid: One clearly brave choice + one clearly cowardly choice.
- Include: Social consequences, loyalty dilemmas, moments where being fair conflicts with being fast.
- The hero may feel conflicted after choosing — reflect this briefly in the narrative before the next choice.
- Minimum one line of internal monologue per scene showing the character weighing their decision.
"""
```

In both `build_opening_prompt` and `build_continuation_prompt`, find:
```python
{cls.TEEN_TONE_INSTRUCTION if age >= 15 else ""}
```
Replace with:
```python
{cls.TEEN_TONE_INSTRUCTION if age >= 15 else cls.MORAL_COMPLEXITY_INSTRUCTION if 11 <= age <= 13 else ""}
```

**Test condition:**
- Generate interactive story for age 12 → prompt includes moral complexity instruction.
- Age 10 → no moral complexity instruction.
- Age 16 → teen tone instruction (not moral complexity).

---

### P2-5: TTS Auto-Enable for Ages 3-7

**File:** `lib/story_result_screen.dart`

**What to find:** The `initState()` method of `_StoryResultScreenState`. The existing TTS control (if any) — grep for `FlutterTts` or `tts` in this file.

**Exactly what to change:**

If `FlutterTts` is not yet imported, add to imports:
```dart
import 'package:flutter_tts/flutter_tts.dart';
```

Add to `_StoryResultScreenState` fields:
```dart
FlutterTts? _tts;
bool _ttsAutoEnabled = false;
```

In `initState()`, after existing init calls, add:
```dart
if (_effectiveAge <= 7) {
  _initAutoTts();
}
```

Add the method:
```dart
Future<void> _initAutoTts() async {
  _tts = FlutterTts();
  await _tts!.setLanguage("en-US");
  await _tts!.setSpeechRate(0.45); // Slower for young listeners
  await _tts!.setPitch(1.1);
  if (mounted) setState(() => _ttsAutoEnabled = true);
}
```

In `dispose()`, add:
```dart
_tts?.stop();
```

In `_buildReaderView()` or `_buildStoryPage()`, add a TTS button (visible only when `_ttsAutoEnabled` is true):
```dart
if (_ttsAutoEnabled)
  IconButton(
    icon: const Icon(Icons.volume_up_rounded, color: AppColors.gold, size: 36),
    onPressed: () => _tts?.speak(_currentPageText),
    tooltip: 'Listen',
  ),
```

`_currentPageText` should be the text of the current story page (`_storyPages[_currentPageIndex]` or equivalent).

**Test condition:**
- Story for age 5 → speaker icon visible, tapping reads current page aloud.
- Story for age 12 → no speaker icon.
- `flutter_tts` must already be in `pubspec.yaml`. If not, add it and run `flutter pub get`.

---

## P3 — Stretch Goals

### P3-1: Magic Star Cursor — Gate by Age Band (Web Only)

**File:** `lib/screens/wizard_steps/hero_creator_step.dart`

**What to find:** Line ~2566 — `return MagicStarCursor(child: Container(...)` wrapping the wizard content.

**What to change:**

```dart
final Widget wizardContent = Container(
  decoration: ...,
  child: SafeArea(...),
);

// Only apply the magic star cursor for young age bands on web.
if (band.band == AgeBand.sprout || band.band == AgeBand.explorer) {
  return MagicStarCursor(child: wizardContent);
}
return wizardContent;
```

`MagicStarCursor` already returns its child unchanged on non-web platforms (confirmed in `magic_star_cursor.dart:70`), so this change is safe cross-platform.

**Test condition:** On Chrome, age 6 → magic star cursor. Age 10 → system cursor.

---

### P3-2: "Learn to Read" UI Label — Rename for Ages 6-7

**File:** `lib/screens/wizard_steps/hero_creator_step.dart` and `lib/screens/wizard_steps/magic_review_step.dart`

**What to find:** Grep `"Learn to Read"` across all Dart files in `lib/`.

**What to change:** For any user-visible label that says "Learn to Read" that appears for Explorer band (ages 5-7), rename to "Read-Along Stories". Reserve "Learn to Read" only for Sprout band (ages 3-4). The `_getReadingLabel()` method in `hero_creator_step.dart:1444` already returns 'Limerick Laughs' for Explorer band — verify and confirm this is the label shown in the mode selector. If "Learn to Read" is visible elsewhere for ages 6-7, update it.

**Test condition:** Age 7 user — no UI element shows "Learn to Read". Mode orb shows "Limerick Laughs" or "Read-Along Stories".

---

### P3-3: Wisdom Gem Font in Explorer Band

**Covered by P0-3.** The `_buildWisdomGem()` method added in P0-3 uses `GoogleFonts.quicksand()` in all tiers, which is the Explorer band font. No additional change needed.

---

## Cross-Cutting Tasks

### CC-1: Interactive Story — "Co-Author" Framing for Ages 15+

**File:** `backend/services/interactive_adventure_prompt_builder.py`

**What to find:** `TEEN_TONE_INSTRUCTION` constant and the `**POV**` rule in `build_opening_prompt`.

**What to change:**

Add a new constant:
```python
CO_AUTHOR_INSTRUCTION = (
    "\n**CO-AUTHOR MODE (Ages 15+)**:\n"
    "- Frame choices as narrative decisions: 'What does {name} decide?' not 'What do YOU do?'\n"
    "- The reader is a co-author shaping the protagonist's journey, not the protagonist themselves.\n"
    "- Choice text uses third-person: 'Have {name} confront the council' rather than 'Confront the council'.\n"
    "- Internal monologue is encouraged; let the protagonist reflect on the weight of each option.\n"
    "- Choices should reflect values, identity, and long-term consequences.\n"
)
```

Where `CO_AUTHOR_INSTRUCTION` is used, format with `child_name`:
```python
co_author_block = cls.CO_AUTHOR_INSTRUCTION.replace('{name}', child_name) if age >= 15 else ""
```

Update the `**POV**` rule in the prompt f-string:
```python
f"- **POV**: {'Third-person for choices. Hero is ' + child_name + '. Frame: What does ' + child_name + ' decide?' if age >= 15 else 'ALWAYS use second-person (you). The hero is ' + child_name + '.'}"
```

**Test condition:**
- Interactive story for age 16 → prompt contains "What does [name] decide?" framing.
- Age 14 → standard teen tone (not co-author mode).
- Age 9 → neither instruction.

---

### CC-2: "Your Adventure Awaits!" Header — Band-Aware Copy and Font

**File:** `lib/screens/wizard_steps/magic_review_step.dart`

**What to find:** Lines ~394–401 — a `Text("Your Adventure Awaits!", ...)` using `GoogleFonts.cinzelDecorative`.

**What to change:**

```dart
Text(
  band.band == AgeBand.creator
      ? 'Ready to create?'
      : band.band == AgeBand.adventurer
          ? 'Your Quest Awaits'
          : 'Your Adventure Awaits!',
  style: (band.band == AgeBand.creator || band.band == AgeBand.adventurer)
      ? GoogleFonts.sourceSans3(
          color: const Color(0xFFFFD700),
          fontSize: band.heading(22),
          fontWeight: FontWeight.bold,
        )
      : GoogleFonts.cinzelDecorative(
          color: const Color(0xFFFFD700),
          fontSize: band.heading(22),
          fontWeight: FontWeight.bold,
        ),
),
```

Apply the same font-guard to the character name `Text(...)` at line ~447 in the same method.

**Test condition:**
- Age 14 → header reads "Ready to create?" in SourceSans3 font.
- Age 10 → "Your Quest Awaits" in SourceSans3.
- Age 6 → "Your Adventure Awaits!" in CinzelDecorative.

---

## Verification Checklist

After implementing all tasks, run through these manual tests:

| Age | Expected |
|-----|----------|
| 4 | Sprout theme, no Pick-a-Path in mode selector, name input is text + voice mic, 6 core emotion tiles only, TTS auto-enabled, "MAKE MAGIC" button |
| 7 | Explorer theme, "Rhyme Time" label, "Limerick Laughs" for read-along, Wisdom Gem large gold prominent, TTS auto-enabled |
| 9 | Adventurer theme, no Learn-to-Read mode, "START ADVENTURE" button, Wisdom Gem medium display no glow, no shimmer chime |
| 12 | **Creator theme** (changed from 13!), Creative Brief wizard, "CREATE STORY" button, "Poetry" mode label, Wisdom Gem "Story Reflection" collapsed |
| 14 | Creator theme, Wisdom Gem "Reflection" plain collapsed, no shimmer chime, story in Reader layout (scrolling) |
| 16 | Creator theme, Branching Story (Interactive), co-author choice framing, Poetry mode, story in Reader layout |

---

*Plan generated: March 8, 2026 | Based on UX_AGE_AUDIT.md*
