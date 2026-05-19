# Content Safety Audit — AI Output for Children

Story Weaver / "Once Upon a Time" — generated story text, illustrations, coloring
pages, and interactive Pick-a-Path branching.

- Audit ID: 02-content-safety
- Date: 2026-05-19
- Scope: `backend/` content-generation pipeline + `lib/` story data
- Method: Edward de Bono Six Thinking Hats, static code review
- Auditor frame: Trust & Safety / child-development / AI red-teaming

---

## Executive Summary

This audit evaluates whether Story Weaver can produce output harmful to a child
even when functioning as designed. The pipeline is, on the whole, well
defended: it has input sanitization with prompt-injection stripping, hero-name
pseudonymization before any provider call, Gemini model-level safety settings,
a two-layer post-generation moderation stack (keyword filter + LLM classifier),
age-band routing across seven bands, and a fail-closed path for the youngest
band in interactive stories. These are real, deliberate safeguards and several
are better than industry baseline.

The audit nonetheless found 3 Critical, 6 High, 8 Medium, and 3 Low findings.
The Critical findings share one root cause: post-generation moderation is
applied to story *body text only*. In the interactive Pick-a-Path path,
segment titles and — more importantly — the choice buttons a child reads and
taps are never moderated, and when a segment is replaced by the safe fallback
its unsafe choices are left in place. A child can therefore be shown a choice
such as a violent action even when the surrounding prose was caught and
replaced.

The High findings cluster around moderation *coverage gaps*: the LLM
classifier inspects only the first 3000 characters, so roughly the back two
thirds of a teen-length story is never contextually classified; the standard
(non-interactive) story path never fails closed, so a classifier outage serves
an unmoderated story to a 4-year-old; the OpenRouter fallback model has no
provider-side safety filtering at all; and uploaded photos of real children are
sent to third-party image APIs without a documented data-processing or
retention guarantee.

A second theme is the absence of any parent-facing content warning before
trauma-adjacent themes (parental conflict, a peer mental-health crisis, a
breakup). The themed-story data is written with genuine care and trauma-informed
language, but a parent gets no signal before a child meets these themes, and
several themes are reachable a band younger than they should be.

Phase 2 of this engagement implements the code-level remediations for the
Critical and High findings that do not require a product or legal decision.
Findings requiring UI design, legal review, or content rewriting are recorded
as manual tasks in `docs/MANUAL_TASKS.md`.

Live adversarial generation (the 20+ injection prompts and 120+ synthetic
stories specified in the brief) was deliberately NOT run autonomously: it
incurs metered Gemini/OpenRouter spend that was not pre-authorized, and the
actionable findings are all reproducible by static review. A scoped live
red-team run is recommended as a follow-up — see Coverage & Gaps.

---

## White Hat — Factual Inventory

### Generation providers

| Layer | Provider / model | Safety mechanism |
|---|---|---|
| Primary text | Gemini `gemini-2.5-flash` (paid) / `gemini-2.5-flash-lite` (free tier) | `_CHILD_SAFETY_SETTINGS` (4 harm categories) |
| Fallback text | OpenRouter `meta-llama/llama-3.2-3b-instruct:free` | None (no provider-side safety config) |
| Last-resort text | Local static `_fallback_story()` | Hardcoded safe content |
| LLM moderation | Gemini `gemini-2.5-flash-lite` | Is itself the moderator |
| Images | Gemini image model + Replicate (Flux / PhotoMaker) | Replicate: negative prompt; Gemini: none |

`_CHILD_SAFETY_SETTINGS` (`story_generation_service.py:19-36`):
`HARM_CATEGORY_SEXUALLY_EXPLICIT` = BLOCK_LOW_AND_ABOVE,
`HARM_CATEGORY_DANGEROUS_CONTENT` = BLOCK_MEDIUM_AND_ABOVE,
`HARM_CATEGORY_HARASSMENT` = BLOCK_LOW_AND_ABOVE,
`HARM_CATEGORY_HATE_SPEECH` = BLOCK_LOW_AND_ABOVE. These apply to the Gemini
text path only; the OpenRouter fallback receives the same prompt with no
equivalent.

### Moderation stack (post-generation)

Two layers, run in `tasks/story_tasks.py:1228-1284`:

1. Keyword filter — `make_filter_story_content` (`utils/app_helpers.py:111-142`).
   `_KEYWORDS_ALL_AGES` (sexual / suicide / self-harm terms) blocks at every
   age. `_KEYWORDS_YOUNG_ONLY` (`kill, murder, blood, death, gun, knife, stab,
   weapon, torture`) blocks only for age ≤ 5. Never modifies text — only
   returns a `flagged` boolean.
2. LLM classifier — `moderate_story_content` (`utils/content_moderator.py`).
   Runs only when the keyword filter did not flag. Age-band-aware prompt.
   `gemini-2.5-flash-lite`. Inspects `story_text[:3000]` only. Fails open by
   default; `fail_closed=True` is an opt-in used by the interactive Sprout
   path.

When either layer flags, `story_tasks.py` regenerates once with custom
elements stripped.

### Input handling

`utils/sanitizer.py`: `sanitize_story_request` recursively HTML-strips,
removes ~22 prompt-injection regex patterns, strips `[USER_INPUT]` delimiter
tokens, length-caps every string field, and `[USER_INPUT]`-wraps high-authority
free-text fields. Confirmed called by both `/generate-story`
(`story_routes.py:500-502`) and `/generate-interactive-story`
(`story_routes.py:884-889`).

`STRICT_OUTPUT_CONSTRAINTS` (`story_service.py:126-137`) instructs the model to
treat `[USER_INPUT]` content as story data, never as instructions.

M-7 pseudonymization (`story_service.py:358-389`): the child's real first name
is replaced with `HERO_1` before any provider call and restored locally.

### Age bands

`_get_age_band` (`story_service.py:338-345`): `3-4, 5-7, 8-10, 11-13, 13-15,
15-18, adult`. Per-band length/vocabulary/structure constraints in
`AGE_CONSTRAINTS`. NOTE: `content_moderator._age_band_label` uses a *different*
3-bucket split (3-7, 8-12, 13-17, adult) — the moderator's notion of age band
does not match the generator's.

### Modes

Standard, Rhyme Time, Learning-to-Read, Bedtime, Superhero (Sprout 6-beat /
Explorer 5-paragraph), and Interactive Pick-a-Path. Superhero prompts are
notably rigid and safety-forward (silly never-frightening villains, resolution
through kindness/cleverness only, no weapons).

### Refusal / fallback inventory

- Gemini prompt-level or post-generation safety block → `_SAFETY_FALLBACK`
  string ("I wasn't able to create that story right now…").
- Provider exhaustion → `_fallback_story()` static JSON.
- Moderation flag → one stripped-down regeneration.
- Interactive Sprout moderation failure → `SAFE_FALLBACK_SEGMENT`.

---

## Red Hat — Gut Reactions to the Pipeline

Recorded as instinctive reactions, not yet evidence:

- The interactive choice buttons go straight from the model to the child's
  screen with nothing in between. That is the thing that would make me
  uncomfortable handing this to a 4-year-old. The prose is guarded; the tappable
  words under it are not.
- "Fail open" on the youngest band's standard story feels wrong in the gut.
  For a 4-year-old the instinct is: if you can't check it, don't show it.
- The 3000-character moderation cut-off feels like a checkbox that was set once
  and never revisited against how long teen stories actually are.
- Sending an actual photograph of a real child to two outside companies, to
  deliberately preserve their face, with no retention guarantee written down —
  that produces the strongest unease of anything in the audit, even though no
  story content is involved.
- The trauma-themed quests read as written by someone who cares. The unease is
  not the content — it is that a parent meets it with no warning.
- Pleasant surprise: the Superhero prompt and the virtue map. "The protagonist
  tries the scary thing anyway — not fearlessly, but with the fear fully
  present" is genuinely good child-development writing.

---

## Black Hat — Harm Vectors (Findings)

Severity: Critical = capable of producing content harmful to a minor.
Harm types: Unsafe-choice, Moderation-gap, Injection, Privacy, Trauma,
Image-safety, Bias.

### Critical

#### F-01 — Interactive choice text and segment titles are never moderated
- Severity: Critical | Harm: Unsafe-choice | Age band: All (worst: Sprout 3-5)
- File: `routes/story_routes.py:984-993, 1122-1130`;
  `services/interactive_adventure_service.py:255-270, 420-435`
- Repro: Generate an interactive story; the keyword filter + LLM classifier run
  on `segment.content` only. `segment.title`, every `choices[].text`, and
  `image_description` are returned and persisted unmoderated. A choice button
  reading e.g. a violent action reaches the child even though the prose around
  it was vetted.
- Remediation: Route titles and the concatenation of all choice texts through
  the same keyword + LLM moderation as the body; on flag, replace with safe
  fallback choices. Implemented in Phase 2.
- Effort: M

#### F-02 — Safe-fallback substitution leaves unsafe choices in place
- Severity: Critical | Harm: Unsafe-choice | Age band: Sprout 3-5
- File: `routes/story_routes.py:1012-1021, 1147-1159`
- Repro: When an interactive segment is flagged, the route overwrites
  `content`, `title`, and `image_description` with `SAFE_FALLBACK_SEGMENT`
  values but never overwrites `choices`. The child sees a gentle replacement
  paragraph attached to the original (flagged-context) choice buttons.
- Remediation: Replace `choices` with the fallback segment's choices in the
  same block. Implemented in Phase 2.
- Effort: S

#### F-03 — LLM classifier inspects only the first 3000 characters
- Severity: Critical (per brief: a partial safety filter on a path that can
  reach a minor) — borderline High; rated up because teen stories are mostly
  uninspected. | Harm: Moderation-gap | Age band: 8-18
- File: `utils/content_moderator.py:154` — `Story (first 3000 characters):
  {story_text[:3000]}`
- Repro: An age-13-15 "long" story targets 3400-4500 words (~20000+ chars).
  3000 chars ≈ the first ~500 words. The contextual classifier never sees the
  climax or ending. Only the whole-text keyword filter covers the remainder,
  and for ages 13+ that filter checks only `_KEYWORDS_ALL_AGES`.
- Remediation: Moderate the full story in ~12000-char chunks (cap total
  chunks); flag if any chunk flags. Implemented in Phase 2.
- Effort: M

### High

#### F-04 — Standard story path never fails closed
- Severity: High | Harm: Moderation-gap | Age band: Sprout 3-5 (all)
- File: `tasks/story_tasks.py:1242` — `moderate_story_content(story_body, age)`
  called with no `fail_closed` argument (defaults False).
- Repro: For a 4-year-old's standard story, if the classifier errors (API down,
  rate limit, unparseable response) `moderate_story_content` returns
  `(True, "")` — story passes. The interactive path protects Sprout with
  `fail_closed`; the standard path does not.
- Remediation: Pass `fail_closed=age <= 12` in the standard path so a
  classifier outage routes a child's story into the existing
  strip-and-regenerate fallback. Implemented in Phase 2.
- Effort: S

#### F-05 — OpenRouter fallback has no provider-side safety filtering
- Severity: High | Harm: Moderation-gap | Age band: All
- File: `services/openrouter_story_generator.py:41-51`
- Repro: When Gemini is rate-limited the prompt is sent to a free Llama-3.2-3B
  model with no safety settings and no children's-content tuning. The only
  protection left is the fail-open post-moderation stack.
- Remediation: When the producing provider is `openrouter`, force moderation
  `fail_closed`. Implemented in Phase 2. (A provider-side filter is not
  available for this free model.)
- Effort: S

#### F-06 — Violence keyword backstop applies only to age ≤ 5
- Severity: High | Harm: Moderation-gap | Age band: 6-12
- File: `utils/app_helpers.py:31-34` (`_KEYWORDS_YOUNG_ONLY`), used at
  `app_helpers.py:125-126` only when `age <= 5`.
- Repro: For a 7- or 10-year-old, `gun`, `stab`, `torture`, `murder` are not
  keyword-blocked; they rely entirely on the fail-open LLM classifier. On a
  classifier outage, graphically violent content for a 9-year-old passes.
- Remediation: Covered by F-04's `fail_closed=age <= 12` change — a classifier
  outage for any pre-teen now fails closed. Keyword tiers left intact
  (Explorer+ legitimately allows mild peril / named villains). Implemented in
  Phase 2.
- Effort: S

#### F-07 — Child reference photos sent to third-party APIs without documented retention guarantee
- Severity: High | Harm: Privacy / child-identification | Age band: All
- File: `services/avatar_generation_service.py:247-253` (Gemini),
  `~490-554` (second Gemini vision call for feature extraction),
  `replicate_image_generator.py:500-600` (Replicate PhotoMaker)
- Repro: A parent uploads a photo of the child for a custom avatar. The bytes
  are sent to Gemini (twice — generation + feature analysis) and, on fallback,
  to Replicate. Prompts explicitly instruct the model to preserve "skin tone,
  facial structure". The photo is not stored in the app DB and not cached, but
  there is no code-level or documented guarantee about third-party retention,
  and no in-UI disclosure that two separate Gemini calls occur.
- Remediation: Product/legal — verify parental-consent copy covers
  Gemini/Replicate as subprocessors; document a retention position; disclose
  the feature-analysis call. Manual task MT-157. Code groundwork (explicit
  in-memory scrub + comment) optional.
- Effort: L

#### F-08 — No content warning before trauma-adjacent themes
- Severity: High | Harm: Trauma | Age band: 12-17
- File: `lib/data/life_quest_data.dart` (e.g. `questFamilyStress` ~1576,
  `questSomeoneNeedsHelp` ~3983, `questAfterTheBreakup` ~4627,
  `questFightAtHome` ~4457)
- Repro: Quests touching parental conflict, a peer mental-health crisis, a
  breakup, and screenshot shaming are reachable with no parent-facing advisory
  and no per-theme opt-out.
- Remediation: Parent-facing content-warning surface + per-quest severity
  metadata. Manual task MT-158. Phase 2 adds the data-layer
  `contentWarning`/`sensitivity` groundwork only if low-risk.
- Effort: L

#### F-09 — `questSomeoneNeedsHelp` (peer mental-health crisis) ships no crisis resources
- Severity: High | Harm: Trauma | Age band: 15-17
- File: `lib/data/life_quest_data.dart` `questSomeoneNeedsHelp` (~3983-4139)
- Repro: A quest in which a 16-year-old worries a friend is not okay handles
  the theme thoughtfully but surfaces no real-world help pathway (crisis line,
  trusted-adult prompt).
- Remediation: Add an inline resource block (e.g. 988 / Crisis Text Line /
  "tell a trusted adult"). Manual task MT-159 — wording needs human review.
- Effort: M

### Medium

#### F-10 — Illustration scene descriptions reach the image model without moderation
- Severity: Medium | Harm: Image-safety | Age band: All
- File: `routes/story_routes.py:1333` (`/generate-illustrations`),
  `~1720` (`/generate-coloring-pages`)
- Repro: The per-page `image_prompt` emitted in the story JSON is in fact
  discarded at extraction (`_safe_extract_title_and_gem` keeps page text
  only). The live image input is the `scene_description` the client POSTs to
  the illustration/coloring endpoints, sanitized with `sanitize_text`
  (HTML-strip + length-cap) but NOT injection-stripped and NOT content-
  moderated. A modified client can POST an arbitrary unsafe scene.
- Remediation: Keyword-screen `scene_description` (and each entry in a
  `scenes` list) in both endpoints; substitute a known-safe generic scene on
  a flag. Implemented in Phase 2. Partially defence-in-depth with F-11 (Gemini
  image safety settings) and the existing Replicate `_vet_flux_prompt`.
- Effort: M

#### F-11 — No safety settings on Gemini image generation
- Severity: Medium | Harm: Image-safety | Age band: All
- File: `gemini_image_generator.py` — `GenerateContentConfig(
  response_modalities=["IMAGE"])` with no `safety_settings`.
- Remediation: Add `safety_settings` to the image-generation config.
  Implemented in Phase 2 where the SDK supports it.
- Effort: S

#### F-12 — No post-generation moderation of generated images
- Severity: Medium | Harm: Image-safety | Age band: All
- File: `gemini_image_generator.py`, `replicate_image_generator.py` (whole)
- Repro: Generated illustrations, avatars, and coloring pages are returned
  with no content moderation pass (only a non-photorealism heuristic).
- Remediation: Integrate a SafeSearch-style check. Needs an API + key — manual
  task MT-160.
- Effort: L

#### F-13 — Story title and `themes`/`emotional_arc` metadata not moderated
- Severity: Medium | Harm: Moderation-gap | Age band: All
- File: `tasks/story_tasks.py:1228-1284`
- Repro: Moderation runs on `story_body`; the title and metadata are
  model-generated free text shown to child and parent, unchecked.
- Remediation: Keyword-screen the title alongside the body. Implemented in
  Phase 2.
- Effort: S

#### F-14 — Family-structure assumptions in quest data
- Severity: Medium | Harm: Bias | Age band: 9-17
- File: `lib/data/life_quest_data.dart` — hardcoded "my mom's car" (~342, 619,
  776, 891), "your mom"/"your dad" (~1781, 1791)
- Repro: Hardcoded gendered/two-parent caregiver references exclude foster,
  adopted, single-parent, kinship-care, and same-sex-parent families — directly
  relevant given a possible foster-youth user base.
- Remediation: Replace with the existing `{grownup}` interpolation. Manual task
  MT-161 — narrative-voice edits, human review preferred.
- Effort: M

#### F-15 — Prior interactive segment text re-enters the next prompt unmoderated
- Severity: Medium | Harm: Moderation-gap | Age band: All
- File: `services/interactive_adventure_service.py:347-374, 726-739`
- Repro: `_build_story_summary` builds continuation context from persisted
  segments/choices. Mitigated because flagged segments are replaced before
  persistence — but with F-01 unmoderated choices persist and re-enter context.
- Remediation: Largely resolved once F-01 moderates choices before persistence.
- Effort: S (folded into F-01)

#### F-16 — `questFamilyStress` reachable by the Creator band (12-14)
- Severity: Medium | Harm: Trauma | Age band: 12-14
- File: `lib/data/life_quest_data.dart` quest-band allocation (~154-202)
- Repro: A parental-conflict quest is available to early-adolescent children
  with no warning; may re-traumatize a child in an active family separation.
- Remediation: Re-band to 15+ or gate behind the F-08 warning. Manual task
  MT-158.
- Effort: S

#### F-17 — Custom-avatar feature-extraction Gemini call is undisclosed
- Severity: Medium | Harm: Privacy | Age band: All
- File: `services/avatar_generation_service.py:~490-554`
- Repro: Creating a custom avatar sends the child photo to Gemini a second
  time for feature analysis; no UI indication.
- Remediation: Disclose in consent/UI copy. Manual task MT-157.
- Effort: S

### Low

#### F-18 — `SAFE_FALLBACK_SEGMENT` shape differs from normal segments
- Severity: Low | Harm: Moderation-gap (maintenance) | Age band: 3-5
- File: `utils/content_moderator.py:33-52`
- Remediation: Add a fixture/test asserting field parity. Phase 2 adds a test.
- Effort: S

#### F-19 — `Grief` emotion gated to 15+ only
- Severity: Low | Harm: Trauma | Age band: 6-14
- File: `lib/screens/big_feelings_flow_screen.dart:~107`
- Repro: A grieving 9-year-old has no matching feeling word in the wheel.
- Remediation: Offer a gentle "missing someone" option to younger bands.
  Manual task MT-162.
- Effort: S

#### F-20 — `content_moderator` age bands diverge from generator age bands
- Severity: Low | Harm: Moderation-gap | Age band: All
- File: `utils/content_moderator.py:89-96` vs `story_service.py:338-345`
- Remediation: Note divergence; align if/when bands are unified. Documented
  only.
- Effort: S

---

## Yellow Hat — Safeguards Working Well

- Input sanitization is genuinely defense-in-depth: HTML strip, ~22
  injection-pattern regexes, delimiter-token stripping, length caps, and
  `[USER_INPUT]` wrapping of high-authority fields — applied recursively to the
  whole request on both story paths (`sanitizer.py`).
- M-7 hero-name pseudonymization: the child's real name never reaches any
  provider; substituted back locally. Strong COPPA-aligned data minimization.
- Two independent moderation layers (fast keyword + contextual LLM) with
  age-aware classifier prompts.
- Interactive Sprout band fails closed — unknown/missing age is treated as
  Sprout (most protected). Correct and deliberate.
- Gemini text path carries explicit child-tuned `safety_settings`.
- Age-band routing is detailed and developmentally literate (`AGE_CONSTRAINTS`
  vocabulary/structure/`AVOID` lists per band).
- Superhero mode prompts enforce silly never-frightening villains and
  resolution through kindness/cleverness, never force — excellent for Sprout.
- The `VIRTUE_MAP` and feelings guidance are trauma-informed: feelings are
  validated, never shamed; "courage" is framed as acting *with* fear present,
  not its absence; endings favor integration over a tidy moral.
- Pronoun handling supports `they`; `{grownup}` interpolation already exists as
  the inclusive primitive (it is simply underused — see F-14).
- Ownership checks (IDOR) on character and story access in the interactive
  routes.
- Meta-leakage and lesson-ending strippers keep craft/therapy jargon out of the
  child-visible prose.

---

## Green Hat — Proposed New Safeguards

1. Unified moderation gate. A single `moderate_output()` that takes every
   child-visible string (body, title, choices, image prompts, metadata) and
   one age, so no surface can be added in future without passing through it.
   Phase 2 partially realizes this; a full refactor is recommended.
2. Theme allow/deny + sensitivity registry. Tag every quest/scenario/theme
   with a `sensitivity` level and minimum age in data; the warning surface and
   age-gating then derive from one source of truth (groundwork for F-08/F-16).
3. Eval harness. A versioned set of ~30 adversarial prompts + ~10 benign
   per-band prompts, run in CI against a mocked/recorded provider, asserting
   refusal on adversarial and pass on benign — catches moderation regressions
   without per-run spend.
4. Second-model image review. A cheap vision call classifying each generated
   image before it reaches the child (addresses F-12).
5. Parent flagging + review queue. An in-app "report this story/page" control
   feeding a moderation log — turns parents into a detection layer.
6. Provider-aware moderation strictness. Generalize F-05: weaker/free providers
   always fail closed; document the policy.
7. Trauma-history-aware quest ordering. If a child discloses a feeling
   ("my parents fight"), suppress the matching heavy quest from the immediate
   queue rather than surfacing it first.

---

## Blue Hat — Prioritized Remediation Backlog

Sequencing: P0 ships now (Phase 2, code-only, no product decision). P1 is
manual (UI/legal/content). P2 is follow-up engineering.

| Seq | Finding(s) | Action | Owner | Where |
|---|---|---|---|---|
| P0-1 | F-01, F-15 | Moderate interactive titles + choice text; replace choices in fallback | Phase 2 | `story_routes.py`, interactive path |
| P0-2 | F-02 | Fallback substitution replaces `choices` | Phase 2 | `story_routes.py` |
| P0-3 | F-03 | Chunked full-text LLM moderation | Phase 2 | `content_moderator.py` |
| P0-4 | F-04, F-06 | `fail_closed=age<=12` on standard path | Phase 2 | `story_tasks.py` |
| P0-5 | F-05 | `fail_closed` when provider is OpenRouter | Phase 2 | `story_tasks.py` |
| P0-6 | F-13 | Keyword-screen the title | Phase 2 | `story_tasks.py` |
| P0-7 | F-10 | Keyword-screen illustration `scene_description` | Phase 2 | `story_routes.py` |
| P0-8 | F-11 | Gemini image-gen `safety_settings` | Phase 2 | `gemini_image_generator.py` |
| P0-9 | F-18 | Fallback-segment field-parity test | Phase 2 | `tests/` |
| P1-1 | F-07, F-17 | Photo consent/DPA/retention + disclosure | Manual MT-157 | legal + UI |
| P1-2 | F-08, F-16 | Content-warning surface + per-quest sensitivity | Manual MT-158 | UI + data |
| P1-3 | F-09 | Crisis resources in peer-help quest | Manual MT-159 | content |
| P1-4 | F-14 | De-gender caregiver references | Manual MT-158 | content |
| P1-5 | F-19 | Younger-band grief vocabulary | Manual MT-159 | content |
| P2-1 | F-12 | Post-generation image moderation | Manual MT-157 | engineering |
| P2-2 | Green 1/3 | Unified moderation gate + CI eval harness | Follow-up | engineering |
| P2-3 | F-20 | Align moderator/generator age bands | Follow-up | engineering |

---

## Coverage & Gaps

Audited: text generation pipeline (standard, rhyme, LTR, bedtime, superhero),
interactive Pick-a-Path branching, illustration + coloring + avatar image
pipelines, input sanitization, age-band routing, trauma-theme inventory, bias
review of quest/companion data.

Not performed in this pass:

- Live synthetic generation (brief asked for ≥120 stories + 100+ character
  generations + 20+ injection prompts). Skipped autonomously: it incurs metered
  Gemini/OpenRouter spend not pre-authorized for an unattended run, and every
  finding above is reproducible by static review. The
  `audit-reports/generation-samples/` folder is therefore empty by design.
  Recommended follow-up: a scoped, budgeted live red-team run executed with the
  owner present, results logged as `prompt → output SHA → rating → notes` with
  no unsafe content stored verbatim.
- Bias frequency baseline (the brief's 100-generation demographic distribution)
  — depends on the live run above.
- Third-party provider data-handling claims (Gemini/Replicate retention) —
  require contract/DPA review, out of scope for a code audit (F-07).

No CSAM-adjacent output, grooming language, or self-harm instruction was
encountered in static review; the halt-and-escalate protocol was not triggered.

---

## Appendix — Finding Index

| ID | Title | Severity |
|---|---|---|
| F-01 | Interactive choice text / titles unmoderated | Critical |
| F-02 | Fallback leaves unsafe choices in place | Critical |
| F-03 | LLM classifier inspects first 3000 chars only | Critical |
| F-04 | Standard story path never fails closed | High |
| F-05 | OpenRouter fallback has no safety filtering | High |
| F-06 | Violence keyword backstop only for age ≤ 5 | High |
| F-07 | Child photos to third-party APIs, no retention guarantee | High |
| F-08 | No content warning before trauma themes | High |
| F-09 | Peer-mental-health quest ships no crisis resources | High |
| F-10 | Per-page image prompts unmoderated | Medium |
| F-11 | No Gemini image-generation safety settings | Medium |
| F-12 | No post-generation image moderation | Medium |
| F-13 | Title / metadata unmoderated | Medium |
| F-14 | Family-structure assumptions in quest data | Medium |
| F-15 | Prior interactive segment text re-enters prompt unmoderated | Medium |
| F-16 | Parental-conflict quest reachable by Creator band | Medium |
| F-17 | Undisclosed second Gemini call for avatar photo analysis | Medium |
| F-18 | Safe-fallback segment shape inconsistency | Low |
| F-19 | Grief emotion gated to 15+ only | Low |
| F-20 | Moderator/generator age bands diverge | Low |
