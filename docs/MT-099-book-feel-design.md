# MT-099 — Story Reader "Book Feel" UI Refactor

**Status:** ✅ Implemented (Direction B, measured scope) on branch `mt-099-bookfeel`, 2026-05-29. See §6.
**Author:** Claude research agent, 2026-05-28. Implementation: 2026-05-29.
**Branch context:** proposal written on `reliability-hardening`; implemented on `mt-099-bookfeel` (isolated git worktree).

## 6. What shipped (2026-05-29)

Darcy picked **Direction B (Open Book)** with per-band leather tones, plus the
reduce-motion and keep-spread scope adds. Delivered:

- **`OpenBookFrame`** (`lib/widgets/open_book_frame.dart`) — a decorative leather
  hardback rim + warm book body + stacked-leaves footer that wraps the flip
  `Stack` in `story_result_screen.dart`. `ExcludeSemantics`; passthrough
  (`enabled: false`) in high-contrast mode so the flat leaf rendering survives.
- **Per-band leather** via `BookLeatherPalette.forBand`: Sprout warm chestnut,
  Explorer classic brown, Adventurer deep walnut, dark/mature bands midnight
  leather on a walnut body.
- **De-filigree:** `StoryBookPage` gains `framed` — drops the gold border, outer
  glow, and corner ornaments (the leather supplies the border) and insets the
  spine 2px. New `AppColors.book*` tokens.
- **Reduce-motion:** the 3D drag-flip (`interactiveFlipEnabled`) and the
  `_FlipSparkles` burst now gate on `MotionPrefs.reduceMotion(context)`. Page
  turns stay instant via arrows/taps. (Closes the Q5 open question.)
- **Two-page spread** kept on wide screens — the leaves' existing gutter shadows
  remain; the frame straddles both, no center-spine overlap with the flip plane
  (sidesteps the M-risk z-order issue).

**Page-flip sound (Q3):** already implemented before this ticket —
`_handlePageFlip` plays `assets/sounds/page_turn.mp3` on every flip (respecting
mute), and the asset exists + is registered. No follow-up needed.

**Deliberately de-scoped** (the higher-risk Direction-A/B items) to avoid
cross-band contrast rework, a `_buildReaderView` regression, and page-index
surgery — filed as **MT-200** for optional later polish:
- Global purple→warm scaffold swap (kept per-band purple for app bar + title +
  the age-11+ reader layout; the leather frame already grounds the leaf).
- Title-page-leaf demotion (would require a synthetic index-0 leaf, shifting all
  page indices and the `_hasCoverIllustration` / prefetch math).

Direction C (Pop-Up) remains backlogged as **MT-199**, scoped to Sprout-only,
pending a real "young readers find the flip confusing" signal.

**Verification:** `flutter analyze` clean on touched files; visually verified in
a running CanvasKit build (web-server) via Playwright across all four band
leathers, the high-contrast passthrough, and the wide two-page spread — all
render correctly. (Reader/result + a11y widget tests were green in the original
pass; re-run before merge since this branch is rebased on newer `origin/main`.)

## 1. Current state assessment

The reader has already moved part-way toward a book aesthetic since the MT-099 ticket was written. `_buildStoryPage` (lib/story_result_screen.dart:2680) wraps every page in a `StoryBookPage` (lib/widgets/storybook_page.dart) that already paints a parchment background (`#FFF8E7`), a gold border, corner ornaments, a paper-speckle overlay, a stacked page-edge fan, a spine shadow, and an in-corner "Page N of M" label. On viewports ≥720 dp `_buildStoryPage` also renders a two-leaf spread with gutter shadows, and the title row above the book already has a gold rule line (lib/story_result_screen.dart:3896). What still undercuts the illusion: the parchment leaf still floats inside a deep-purple `band.gradientStart → gradientMid → gradientEnd` scaffold (lib/story_result_screen.dart:3689) with no book "body" behind it, the leaf has gold filigree corners that read more "diploma" than "children's storybook", the `PageFlipBuilder` flip is performed on a card-sized rectangle so the flip plane visibly stops short of the page edges, and the title + reading-level chrome above the leaf compete with the page itself for "this is the book" attention. The 3D flip animation in `PageFlipBuilder` is the strongest existing asset — directions should preserve it.

## 2. Three layout directions

### Direction A — "Trim the Chrome" (conservative)

**Philosophy:** Keep `StoryBookPage`, `PageFlipBuilder`, and the existing spread logic. Replace only the purple void around the leaf with a warm book-body color, demote the title to a page-1 title-page, and remove the gold filigree corners that make the leaf feel like a certificate.

**Phone portrait:**
```
+-----------------------------+
| <  [hero] [♥][🔊][⚙]        |  ← bar darkens to muted brown
+-----------------------------+
|                             |
|   ┌──────────────────────┐  |
|   │ ░ Once there was…   │  |  parchment leaf
|   │   a kingdom of clouds│  |  spine shadow on left
|   │                      │  |  page edges on right
|   │                      │  |
|   │   the wind whispered │  |
|   │   her name.          │  |
|   │                  3/12 │  |  ← page no. lives in corner
|   └──────────────────────┘  |
|                             |
+-----------------------------+
   ░ = warm walnut #3A2B1F body
```

**Wide-screen (≥720 dp):**
```
+---------------------------------------------------+
| <  [hero] [♥][🔊][⚙]                              |
+---------------------------------------------------+
|        ┌───────────┐┌───────────┐                 |
|        │  page L   ││   page R  │                 |
|        │           ││           │                 |
|        │           ││           │                 |
|        │           ││           │                 |
|        │      3/12 ││ 4/12      │                 |
|        └───────────┘└───────────┘                 |
|         spine gutter ^                            |
+---------------------------------------------------+
   walnut surround, no purple
```

**Implementation notes:**
- lib/story_result_screen.dart:3686 — swap the `band.gradientStart / mid / end` gradient for a flat warm color (cream `#FAF1DE` for light bands, walnut `#2E2118` for `band.preferDarkMode`). Keep `band.gradientEnd` only for the bottom-sheet surfaces so other screens are unaffected.
- lib/story_result_screen.dart:3874 — collapse the title + gold rule + reading-level pill into the first page only (a "title page" leaf). Use the existing `_hasCoverIllustration` slot if a cover is present; otherwise insert a synthetic title leaf at index 0.
- lib/widgets/storybook_page.dart:75 — gate `effectiveShowDecorations` on a new `decorationStyle` enum so this direction can render `none` (no gold filigree) while preserving the asset for other directions.
- App-bar buttons get a `.withValues(alpha: 0.12)` walnut fill instead of white so they recede.
- No PageFlipBuilder changes.

**Risk:** S. **Effort:** S (1-1.5 days). **A11y:** Lowest impact — text scaling, high-contrast, and screen-reader paths all already exist; the only change is contrast tokens (walnut bg vs. cream page — verify ≥4.5:1 with WCAG check at all four band themes).

---

### Direction B — "Open Book" (ambitious)

**Philosophy:** Commit to the book metaphor. Render an actual book body behind the leaf with a visible spine, hardback edges, and a page-curl shadow that bleeds beyond the active leaf. On wide screens the spread becomes a true open-book hero element with depth. The flip animation now flips a leaf inside a visible book, not a floating card.

**Phone portrait:**
```
+-----------------------------+
| <  [hero]      [♥][🔊][⚙]   |
+-----------------------------+
|  ╔═══════════════════════╗  |  ← hardback cover edge
|  ║┌─────────────────────┐║  |  
|  ║│ ░ Once there was…  │║  |  active leaf
|  ║│                     │║  |
|  ║│   the wind whispered│║  |
|  ║│   her name.         │║  |
|  ║│                 3/12│║  |  ← page no. in leaf corner
|  ║└─────────────────────┘║  |
|  ║▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓ ║  |  ← stacked-leaves footer
|  ╚═══════════════════════╝  |
+-----------------------------+
  hardback = #5A3B22 leather
  body bg  = matte cream
```

**Wide-screen (≥720 dp) — true open book:**
```
+---------------------------------------------------+
|  <   [hero]            [♥][🔊][⚙]                 |
+---------------------------------------------------+
|     ╔══════════════════╦══════════════════╗       |
|     ║┌───────────────┐ ║ ┌───────────────┐║       |
|     ║│  L page text  │ ║ │  R page text  │║       |
|     ║│               │▓║▓│               │║       |
|     ║│               │▓║▓│               │║       |
|     ║│  ── Story ──  │▓║▓│               │║       |
|     ║│           3/12│ ║ │ 4/12          │║       |
|     ║└───────────────┘ ║ └───────────────┘║       |
|     ╠══════════════════╩══════════════════╣       |
|     ║▓ stacked leaf cross-section          ▓║     |
|     ╚═════════════════════════════════════╝       |
+---------------------------------------------------+
                deep gutter ^
```

**Implementation notes:**
- New widget: `lib/widgets/open_book_frame.dart` — paints hardback cover edge (8 px rounded leather), spine gutter, and a horizontal "stacked-leaves" cross-section below the active leaf using a paper-tone gradient with three horizontal hairlines (similar idea to `_PageEdgeStackPainter` rotated 90°).
- lib/story_result_screen.dart:3845-end-of-page-area — wrap the existing `PageFlipBuilder` Stack in `OpenBookFrame(child: ...)`. The frame is purely decorative — no layout shift, no flip-builder changes.
- lib/widgets/storybook_page.dart — drop the per-leaf gold border + corner ornaments (now handled by the frame). Keep the spine shadow but inset it 2 px because the frame contributes its own gutter.
- On wide screens, the wide-screen spread case in `_buildStoryPage` already returns a Row of two leaves; `OpenBookFrame` straddles both.
- New AppColors tokens: `bookCoverLeather` (#5A3B22), `bookCoverLeatherLight` (#7A5538), `bookBodyCream` (#FAF1DE). Theme via `band.preferDarkMode` to a midnight-leather palette for `creator`/`adolescent`/`adult` bands.
- Brand check: Sprout/Explorer = warm reds + tan; Adventurer = deeper walnut; matches "Once Upon YOUR Child" picture-book intent.

**Risk:** M (frame can clip flip shadows if z-order is wrong; spread gutter overlap with `PageFlipBuilder` transform plane needs a flip test on wide screens). **Effort:** M (3-4 days incl. goldens + spread regression). **A11y:** Frame is `ExcludeSemantics` — invisible to screen readers, who continue to traverse leaf content unchanged. High-contrast mode bypasses the frame and falls back to Direction A's flat rendering so the textured leather doesn't break reading.

---

### Direction C — "Pop-Up Picture Book" (unconventional)

**Philosophy:** Stories for Sprout/Explorer don't need a serif "this is a leather tome" frame — they need a picture-book feel. Drop `PageFlipBuilder` for Sprout (3-5) and instead use a paper-cut "pop-up" reveal: per-page illustration animates in as the foreground, page text as a label below it on a tilted card, advancing is a tap that triggers a spring-out / slide-in. Adventurer (9-12) keeps `PageFlipBuilder` but with Direction A chrome. Effectively two readers in one, picked by `band`.

**Phone portrait (Sprout/Explorer pop-up mode):**
```
+-----------------------------+
| <  [hero]     [♥][🔊][⚙]    |
+-----------------------------+
|       ▒▒▒▒▒▒▒▒▒▒▒▒▒         |   ← cut-paper illustration
|     ▒▒  illustration  ▒▒    |     pops up on page change
|       ▒▒▒▒▒▒▒▒▒▒▒▒▒         |
|         \\\▓///             |   ← shadow under "popped" art
|                             |
|   ╔═══════════════════╗     |   ← tilted text card
|   ║ The wind whispered║     |
|   ║ her name.         ║     |
|   ║              3/12 ║     |
|   ╚═══════════════════╝     |
|                             |
|       ◀  tap to flip  ▶     |
+-----------------------------+
  bg: paper-collage gradient
```

**Wide-screen (Sprout pop-up mode):**
```
+---------------------------------------------------+
|  <  [hero]                [♥][🔊][⚙]              |
+---------------------------------------------------+
|        ▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒                          |
|      ▒▒▒    illustration   ▒▒▒                    |
|        ▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒                          |
|            \\\▓▓▓///                              |
|                                                   |
|    ╔════════════════════════════════════╗         |
|    ║ "The wind whispered her name."     ║         |
|    ║                              3/12  ║         |
|    ╚════════════════════════════════════╝         |
|                                                   |
|         tap art or card to turn page              |
+---------------------------------------------------+
  (no two-page spread — youngest readers don't track L/R)
```

**Implementation notes:**
- New file: `lib/widgets/popup_storybook_page.dart` — replaces `StoryBookPage` for Sprout/Explorer bands. Uses `AnimatedSwitcher` + `Hero` + `SlideTransition` + `RotationTransition` (~2 deg tilt) for entrance; flip controlled by `_goToNextStoryPage`.
- lib/story_result_screen.dart:2680 — branch in `_buildStoryPage`: `if (band.band == AgeBand.sprout || band.band == AgeBand.explorer) return _buildPopupPage(index)`. Adventurer keeps existing `StoryBookPage` + `PageFlipBuilder`.
- lib/story_result_screen.dart:3978 — wrap `PageFlipBuilder` in an `if (!isPopupMode)`. In popup mode, the Stack renders the new `PopupStoryBookPage` directly with `AnimatedSwitcher`. The pointer/flip listeners are bypassed.
- Reuses `_buildPerPageIllustration(textIndex)` as the "popped" foreground.
- Title page becomes the cover illustration full-bleed with title typeset over it (similar to existing `_buildCoverPage`).

**Risk:** L (two reader paths to maintain; behavioral test coverage for the new path; haptics/audio cues to design; risk that Explorer (6-8) parents feel "infantilized" — possibly limit popup to Sprout only). **Effort:** L (1-2 weeks for polished animation + per-band logic + tests). **A11y:** Highest risk surface — `AnimatedSwitcher` can confuse screen readers if `Semantics(liveRegion: true)` isn't on the text card. Tilt rotation must respect `MediaQuery.disableAnimations`. Pop animation must be skippable for vestibular-disorder users via the existing reduce-motion flag (currently absent — would need to be added).

---

## 3. Comparison matrix

| Direction | Effort | Sprout 3-5 | Explorer 6-8 | Adventurer 9-12 | Web | Tablet/landscape | Phone portrait | A11y impact | Deviation from current UX |
|---|---|---|---|---|---|---|---|---|---|
| A — Trim the Chrome | S | Good | Good | Good | Good | Good (keeps spread) | Good | Low | Small (color swap, decorations toned) |
| B — Open Book | M | Best | Best | Best | Good (verify flip z-order) | Excellent (true open book hero) | Strong | Low-medium (frame is decorative) | Medium (new framing widget, theme tokens) |
| C — Pop-Up | L | Magical for Sprout | Mixed (may feel infantilizing) | Bypasses (keeps Direction A) | OK (no spread) | OK (no spread) | Strong for Sprout | Medium-high (animation pathway + screen-reader semantics) | Large (forks reader behavior per band) |

## 4. Recommendation

**Pick Direction B (Open Book).** Direction A's purple → walnut swap and de-filigree-ing should ship regardless — it's a strict win and falls inside B's scope. What B adds beyond A is the surrounding hardback frame and stacked-leaves footer that finally place the parchment leaf inside a visible book rather than against a void, which is the specific complaint MT-099 was raised to fix. C is an interesting future direction once we have user research saying Sprout finds the flip metaphor confusing — we don't have that signal yet, so it's premature.

## 5. Open questions for Darcy

- Is two-page spread on wide screens an MT-099 must-have, or OK to defer behind a `kEnableSpread` flag if it complicates the open-book frame z-order?
- Cream parchment (`#FFF8E7` — current) vs. slightly warmer paper-texture (`#FAF1DE`) for the leaf — preference, or test both with a screenshot pair?
- The MT-099 brief mentions a page-flip sound effect — in scope for this refactor, or a separate ticket? (Note: app already has `AudioAmbienceService` muted by default per "this is a reading app" comment.)
- For Direction B's leather palette, OK to derive per-band leather tones from existing `band.accent` so Sprout/Explorer/Adventurer each get a subtly different cover, or use one palette across all bands?
- Reduce-motion: do you want this refactor to also wire `MediaQuery.disableAnimations` into `PageFlipBuilder` (currently flips unconditionally), or is that a separate a11y ticket?
