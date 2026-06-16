# Age-Band UX Launch Audit — "Once Upon YOUR Child" / Story Weaver

**Date:** 2026-06-15 · **Session:** ux6b · **Status:** findings logged as MT-262 … MT-289

A pre-launch UX + imagery audit of the story-creation experience across **all six age bands**,
evaluated persona-by-persona — as a *user of that age* and (for the three children's bands) as
the *parent who actually operates the UI*. Goal: surface everything confusing, annoying, babyish,
too-mature, or broken, and propose concrete buildable delights per band.

## Scope & method

- **Bands:** Sprout (3-5), Explorer (6-8), Adventurer (9-12), Creator (13-14), Adolescent (15-17), Adult (18+).
- One persona agent per band read the actual `.dart` screens (tap counts, copy, gating) and viewed
  every band's shipped art. Two foundation scouts first mapped the flow + art inventory.
- **Verification:** every High-severity *code* claim and every claimed art defect was re-checked
  directly (image viewed or code read) before landing here. Items marked ✅ below were confirmed
  first-hand; a few cross-references (⚠️) are agent-reported and flagged "verify."
- The parent viewpoint was intentionally dropped for Creator/Adolescent/Adult (autonomous users; Adult is self).

## Architecture note (important — two wizards)

The story-creation wizard is **two different flows** depending on band:

- **Page-based "Hero Creator"** (`hero_creator_step.dart`, 6 sub-pages) → **Sprout, Explorer, Adventurer**.
  These render the scene-picker page (`hero_creator_scene_page.dart`) and the `MagicReview` orb screen.
- **`CreativeBrief` accordion** (`hero_creator_creative_brief.dart`) → **Creator, Adolescent, Adult**
  (the "mature" bands). These use a single scrolling brief and a text-leaning review.

This split is the root of several findings: content built for one flow is unreachable in the other,
and the babyish-art review leak only manifests on bands whose review actually renders scenario art.

---

## P0 — Ship-blockers (fix before launch)

### MT-262 · Review-screen baby-art leak ✅ (Explorer, Adventurer, Adolescent)
`magic_review_step.dart:207-218` `_scenarioImage` returns `scenario.illustration` (the **shared-root
babyish art**) and never calls `illustrationForAge(age)` (`scenario_data.dart:161-170`) or the scene
picker's band-dir resolver. So on the **last screen before "Start"**, a child/teen who picked cinematic
art is shown preschool art:
- Volcano Dragons → `sleeping_dragon.webp` (cuddly nap-time baby dragon) — verified image.
- Vanishing Colors → `rainbow_land.webp`; Crystal Cavern → `sparkle_cave.webp`.
- Adolescent **antihero** flow → `my_big_feelings_btn.webp` (a pastel feelings *button*).
Also the review orb glow is **hardcoded gold** (`magic_review_step.dart:2168`) on the teal Adolescent band.
**Fix:** route `_scenarioImage` through `illustrationForAge(childAge)` (thread the age in), and replace the
hardcoded orb `AppColors.gold` with `band.accent`. *Note:* Creator & Adult dodge the leak only because their
reviews render **no** scenario image — see MT-275.

### MT-263 · Defective art with baked-in watermarks / text ✅ (LEGAL exposure)
AI-generation artifacts shipped into child- and adult-facing assets:
- `feelings/adult/scared.webp` — tiled **"Freepik" stock watermark** ✅ → **licensing/legal exposure, replace immediately.**
- `scenes/sprout/friendly_ocean.webp` — a baked-in **"1:1"** aspect-ratio token in the sand ✅.
- `scenarios/adult/big_feelings_quest.webp` — **"Aspect 16:9"** prompt token ⚠️.
- `feelings/adolescent/quiz_whiz_girl.webp` — **"GIRL POWER"** mug + book titles; a **"START JOURNEY"** baked button ⚠️.
**Fix:** regenerate/replace each; add a pre-ship check for text/watermarks in generated assets.

### MT-264 · `robin` companion wears a Christian cross necklace ✅ (Sprout + Explorer)
`companions/sprout/robin.webp` ✅ (and `companions/explorer/robin.webp` ⚠️) shows a turquoise **cross
necklace** + beaded necklaces + earrings on a kids' companion — an unintended religious symbol in an
otherwise secular/inclusive product. **Fix:** regenerate without the cross (and align the over-detailed
style with the other companions).

---

## P1 — High

### MT-265 · Hard Boy/Girl gender binary across all bands ✅
`hero_creator_step.dart:2896-2949` offers exactly **Boy | Girl**, force-defaulted to **'Girl'**
(`:213-215`, `:691`), as a *gate* to advance. No neutral / "prefer not to say" / surprise option — even
though the `they/them` pronoun path already exists in code (dead for the picker) and **Adolescent's
CreativeBrief already ships a He/She/They pill selector** (`hero_creator_creative_brief.dart:322-397`)
while Creator one band down still gets Boy/Girl (`:226-307`). Most alienating for 9-17. **Fix:** add a
neutral/"They" option everywhere (port the adolescent selector); for Sprout/Explorer add a friendly
"Surprise me!" and make it skippable.

### MT-266 · Adolescent antihero — self-harm-adjacent framing (SAFETY) ⚠️
The "double life" content is mostly well-handled (the *"where do you draw the line"* moral-code prompt,
`superhero_costume_screen.dart:660-666`, is the safety valve that makes it defensible — **keep it**). But:
- Power **"Ghost — easy to vanish for real"** (`superhero_power_screen.dart:240`) paired with the secret
  chip **"That I'm not okay"** (`superhero_costume_screen.dart:646`) read, in combination, as romanticizing
  disappearance — wrong for a child-branded product.
- The Identity page is **concealment-only** (hide / give-away / line) with no counter-prompt about being known.

**Partial fix shipped (2026-06-15):** the "vanish for real" client label was changed to *"Move unseen and
unheard — the better you hide, the more alone you are."* — aligned to the backend's already-safe framing
(`superhero_matrix.py:1084`, cost = loneliness, not disappearance). The secret chip "That I'm not okay" was
**kept** (an honest disclosure, not a defect). **Still open:** confirm the story treats that secret with care;
add the 4th *"Who gets to see the real you?"* Identity prompt; clinical/second-reviewer sign-off on the tone.

### MT-267 · Sprout name entry is an impossible hard gate ✅
`hero_creator_step.dart:2952-2972`, `3017-3122`: a 3-5 cannot type, the web mic STT fails silently, and an
empty name blocks all forward motion behind a red error a pre-reader can't read. **Fix:** provide a
name-free path — a tappable name list, a "Surprise me" name, or an archetype/voice default — so the child is
never stuck on page 1.

### MT-268 · Explorer/Sprout picker serves babyish shared art ✅
`hero_creator_scene_page.dart:113-122` wires per-band picker art (`scenarios/<band>/`) **only for
Adventurer+**; Sprout/Explorer fall back to the shared `_btn` art (`rainbow_land_btn`, `dragon_friends_btn`,
`crystal_cave_btn`) and the babyish shared root scenarios. The genuinely good `scenes/explorer/` art
(enchanted_forest, ocean_depths) is effectively **orphaned**. **Fix:** wire Explorer (and a tuned Sprout set)
to age-appropriate picker art; retire `sleeping_dragon`/`rainbow_land` from the older-of-the-young bands.

### MT-269 · Creator's bespoke scene art + thematic questions are unreachable ✅
Because Creator routes to the `CreativeBrief` accordion, its `scenarios/creator/*.webp` art and the excellent
`creatorThematicQuestion` prompts ("Who are you when no one's watching?") — which only render in
`hero_creator_scene_page.dart` — are **never seen**. The live World step
(`hero_creator_creative_brief.dart:727-832`) is plain ALL-CAPS `ChoiceChip`s, no art, no question. **Fix:**
surface the editorial scene tiles + thematic question inside the mature accordion's World step.

---

## P2 — Medium

- **MT-270 · Adult feelings set incoherent + childish** ✅ — 5 clashing styles; cute Pixar **blobs** for
  grief/dread/melancholy (verified `grief.webp`), photoreal busts for sad/scared, a stick-figure, a stock
  watermark. Recommission one coherent adult-editorial set (or keep only the photoreal-bust subset).
  `assets/images/feelings/adult/*`.
- **MT-271 · Adventurer feelings are babyish mood-coins** ✅ — labeled smiley "HAPPY" sun coins, patronizing
  for 9-12. Replace with atmospheric/abstract mood art, no smileys, no stamped labels.
  `assets/images/feelings/adventurer/*`.
- **MT-272 · Sprout art-style fragmentation + tappability** ✅ — watercolor tiles vs kawaii stickers vs 3D
  renders side-by-side; low-res `forest.webp` & `magic_door.webp`; `mochi.jpg` on a pure-black bg; `space`/`ocean`
  read as sticker clip-art (not tappable). Unify the Sprout art language; make selection feedback big.
- **MT-273 · Gold accent leaks onto bands that intentionally dropped gold** ✅ — hardcoded `0xFFFFD700` on
  Creator (purple-intent: nemesis `superhero_power_screen.dart:1305`, review hero name
  `magic_review_step.dart:2198`) and Adolescent (teal-intent: progress dots `superhero_costume_screen.dart:873`,
  `superhero_power_screen.dart:757`). Replace with `band.accent`.
- **MT-274 · Nemesis picker uses childish Fredoka+gold chrome for Creator** ✅ — the best-written content in
  the app (belief-driven villains) is wrapped in bubbly Fredoka + "Surprise me!/Lock it in!"; only Adolescent
  gets the noir Source-Sans reskin (`superhero_power_screen.dart:1467-1469`). Extend the noir reskin to Creator.
- **MT-275 · Adult scenario content half-built** ✅ — no `adultDescription` field (`descriptionForAge` returns
  the teen `matureDescription` for everyone 13+, `scenario_data.dart:111-122`); most scenarios only set
  `adultTitle`; no `adultIllustration` tier (`illustrationForAge` has no adult branch, `:161-170`) so the
  commissioned `scenarios/adult/*` art is unwired. Finish the adult catalog + add the illustration tier +
  render a banner on the adult review.
- **MT-276 · Childish copy leaks into the mature/adult path** ✅ — "Uh oh! Something went wiggly." error
  (`magic_review_step.dart:871`), "✨ Your avatar is ready!" toast despite `sparkleIntensity:0.0`
  (`:343-347`), "What is your hero's name?" prompt (`hero_creator_step.dart:2962`). Band-gate the copy.
- **MT-277 · Adventurer story-type screen uses bubbly Fredoka** ⚠️ — contradicts the band's Bitter/Merriweather
  "book feel"; swap body/chip/subtitle copy to Bitter. `hero_creator_story_type_page.dart`.
- **MT-278 · Explorer "Easy Reader" mislabeled "Rhyme Time story"** ⚠️ on the review summary
  (`magic_review_step.dart:1085-1087`).
- **MT-279 · Long time-to-first-story (~10-11 taps); Explorer loses Sprout's auto-advance** ✅ — Explorer must
  hunt for "Next" on team/scene/story-type pages that auto-advance for Sprout (`hero_creator_step.dart:454,1965`).
  Add single-tap-advance for Explorer + an express "Tell Me a Story!" lane.
- **MT-280 · AI-avatar paywall surprises mid-build; illustrations silently downgrade** ✅ — the "1 free" limit
  isn't signposted (`hero_creator_step.dart:1554-1565`) and free-tier illustration loss is unexplained
  (`story_type_page.dart:468-470`). Signpost both up front.
- **MT-281 · Companion tonal drift + "Rockin' Robin" in older bands** ✅ — companions stay kawaii (flowers,
  sparkles, big eyes) next to cinematic scenes; "Rockin' Robin" (name + whimsical art) ships in Creator/
  Adolescent/Adult. Re-art the cute ones per band; drop Rockin' Robin from the mature bands.
- **MT-282 · Feelings→face mapping errors** ⚠️ — Explorer `scared.webp` reads as *happy/delighted*; Creator set
  has no `anxious` + a likely mislabel; Adolescent `happy.webp` is a mis-slotted human bust in the blob set.
  Audit the emotion→asset map.
- **MT-283 · Adult author-vs-protagonist ambiguity** ⚠️ — the band is ~70% built for "an adult authoring" but
  still calls the adult "Your Hero" and offers a selfie-of-yourself. Decide intent; build a first-class
  "author / gift a story to a child" (dual-protagonist) path.

## P3 — Low

- **MT-284** Explorer catchphrase pool leaks therapeutic-adult phrasing; give Explorer a stable decodable pool
  (`superhero_name_generator.dart`).
- **MT-285** Portrait Reveal's 6s timer reveals "Skip" but doesn't **cancel** the in-flight request (can run ~2 min);
  cancel on skip/timeout (`superhero_reveal_screen.dart:48,201-204`).
- **MT-286** Explorer Saga "Issue #N" card is shown but the `recordIssue` write path looks Creator-only; verify
  end-to-end or hide the card (`superhero_welcome_back_screen.dart:344-356` vs `magic_review_step.dart:520-523`).
- **MT-287** Art polish: Adult self-avatars all read early-20s in an identical grey tee; Creator avatar trio is
  stylistically incoherent (3D/anime/2D) + 2:1 male-skewed; `scenes/adult` skews game/anime vs the cinematic
  `scenarios/adult`; `cipher` companion's flowers skew young; `vanishing_colors` tiles are very somber.
- **MT-288** Two "Big Feelings" entry points can bounce a Sprout child out of the wizard mid-build
  (`wizard_story_screen.dart:555-571`).

---

## Per-band one-line verdicts

- **Sprout (3-5):** well-guided by TTS/auto-advance; gated hardest by impossible name-typing; 2 art ship-blockers; style fragmentation.
- **Explorer (6-8):** most at risk of feeling "babyish" — toddler-chibi gender art + babyish shared scenarios where the kid wants to feel big; good art exists but isn't wired.
- **Adventurer (9-12):** mostly cool (cinematic art, great nemesis roster) but sabotaged by the review art-leak + babyish feelings badges + Fredoka font.
- **Creator (13-14):** strong content, wrong plumbing — best content unreachable (scene art/questions) or in the younger band's toy chrome (nemesis Fredoka/gold).
- **Adolescent (15-17):** genuinely mature + safe art; the safety-tone pairing + binary gender + emoji-confetti noir are the issues; the antihero frame works *because of* the moral-line prompt.
- **Adult (18+):** best chassis (editorial accordion, minimal review, refined theme) undercut by an incoherent/watermarked feelings set, half-built adult copy, unwired adult art, and author-vs-protagonist ambiguity.

---

## Delights backlog (per band) — MT-289

Concrete, buildable, mostly reusing existing infra. Full rationale in the per-band agent reports.

**Sprout:** (1) "Say your name and watch it sparkle in" — turn the name gate into the first delight; (2) a
"Surprise Me!" sparkle-wand for the whole hero with sound; (3) Gigi sing-songs the choices back before "Make Magic!".

**Explorer:** (1) read their OWN words back (the picked wish becomes the story's opening line); (2) collectible,
remixable catchphrases stamped on the cover; (3) a visible "Issue #N" saga shelf (needs the write-path fix).

**Adventurer:** (1) the Saga as a real ongoing comic — an Issue cover per story + recurring/escalating nemesis;
(2) a sharable Hero Card (name/suit/power/catchphrase/Issue count); (3) "Choose your rival" as a featured beat
with a one-line first-encounter tease.

**Creator:** (1) un-shelve the editorial scene picker (art + thematic question) as the World step; (2) make the
Saga a serialized creative project ("Issue #N" + "Previously…" in the pitch); (3) register-matched noir nemesis
reskin + a "where's your line" stance choice.

**Adolescent:** (1) a noir "case file" review screen (replaces the gold orb); (2) the 4th "who sees the real you?"
Identity prompt (also fixes MT-266); (3) a shareable noir alias card as the artifact.

**Adult:** (1) wire the commissioned `scenarios/adult` art as a cinematic review banner; (2) a Saga "Library/Issues"
shelf — author an ongoing literary serial; (3) a first-class "gift this story to a child" / dual-protagonist path.

---

## Suggested fix sequencing

1. **P0 now** (small, verified, outsized impact): MT-262 (one-getter fix + age threading), MT-263 (asset
   replace — Freepik is legal), MT-264 (asset replace).
2. **P1** before launch: MT-265 (gender), MT-266 (safety review), MT-267 (Sprout name gate), MT-268/269 (wire the good art).
3. **P2 art recommissions in parallel** (MT-270/271/272/281/287 — asset work, no code risk) while the **copy/theme/wiring** items (MT-273-280, 282-283) go through code review.
4. **P3 + delights** (MT-284-289) as polish / post-launch fast-follow.
