# Competitive Product Audit — 2026-07-14

**Scope:** (1) Story-output quality graded from six LIVE generations (one per band, gpt-5-mini via OpenRouter, current `main` prompts + PR #437 openers); (2) competitor feature matrix from live listings/official sites (research pass 2026-07-14). Complements — does not repeat — `VALIDATION.md` (market/compliance), `docs/COPPA_INTERNAL_REVIEW_2026-07-13.md`, and `docs/UNFINISHED_FEATURES_AUDIT.md`.

**Caveat:** one sample per band; systemic claims below are the ones visible in *all six* samples, not single-draw noise.

---

## Part 1 — Story quality (live samples)

| Band (age) | Sample | Verdict |
|---|---|---|
| Sprout (4) | "Tink Tink the Bell Sang" | **Strong.** Opens "Once upon a time" ✓; 10 pages × 10–25 words ✓; onomatopoeia tied to action ✓; scared→brave shown in the body ("felt brave rise in her chest") |
| Explorer (7) | "The Lantern That Hummed" | **Strong.** Opener rotation ✓; real-life echo machinery visibly works — hero names the feeling ("my hands are buzzing ants") + copyable action (asking to take turns / sing together) |
| Adventurer (10) | "The Colorbox and the Sunflower Ribbon" | **Good.** Two-step problem ✓, named-cost choices ✓, internal reflection ✓. Weak spots: a few overwrought similes ("heart picked up like scissors on a rhythm"), villain motive rushed on final page |
| Creator (13) | "the blue blinked away" | **Very strong.** Genuinely literary ("the distance between them had the shape of a thrown rope"); ambivalent, earned inclusion arc. Minor: lowercase title slipped through |
| Adolescent (16) | "The Mint-Glazed Hour" | **Very strong.** Perfection-pressure theme with real social cost and no preachy moral; consistent first-person voice |
| Adult (21) | "The Pink Ribbon Across the Tram Tracks" | **Strong.** Mature, mundane-cost resilience (rent, missed meetings); one grammar slip ("any of us' particular need") |

All four 9+ samples correctly kept varied openings (FRESH OPENING respected); word counts all landed inside the configured `AGE_CONSTRAINTS` ranges. Band voice differentiation is real and large — a 4-year-old story and a 16-year-old story are unmistakably different products. **The prompt machinery (EMOTIONAL SPINE, real-life echo, named-cost constraints) demonstrably shapes output.**

### Findings

**A-1 · MEDIUM — Sensory-palette monoculture (the one systemic defect).**
`generate_enhanced_prompt` defaults `sensory_palette or 'Bright colors, soft sounds, sweet smells.'` (story_service.py). Result: **all six** stories smell of baked sweets — jam (4), toast+sugar (7), lemon oil (10), lemon+honey (13), an entire bakery/"sugar hour" story concept (16), citrus+sugar throughout (21). At 16 the default palette isn't seasoning, it's *driving the premise*. Over a subscription month this is the smell-equivalent of the same-opening problem FRESH OPENING was built to kill.
*Fix (agent-sized):* rotate a small per-band palette table (mirroring `_pick_situation` / opener-rotation pattern) or derive palette from theme; keep "sweet smells" as one option among several.

**A-2 · LOW — Cosmetic QA nits.** Lowercase title at 13; missing comma after "Once upon a time" (model-dependent); Explorer page-ending rhetorical questions turn formulaic by page 5–6. None worth prompt surgery alone; batch with A-1 if touching the prompt.

---

## Part 2 — Competitor feature matrix (live listings, fetched 2026-07-14)

### Deep pass

| Dimension | Oscar Stories | StoryBee | Moshi | Slumberkins | **Ours** |
|---|---|---|---|---|---|
| Personalization | Name, age, gender, avatar pick, interests; no photo, **no feelings input** | Photo→consistent illustrated character; static traits; **no feelings input** | Profile only; curated content, not generated | None — fixed characters | Photo→avatar, archetypes, **feelings/trigger/coping input** |
| Age range | 4+ (user-entered param) | 3–12 | 0–12 (curation) | Core 0–6 | **Six bands 3→18+** |
| SEL / clinical backing | "Reviewed by educators" — nobody named (UNVERIFIED) | None found | **CASEL claim + named expert + peer-reviewed sleep study** (IJERPH 2022) | "Connect-to-Grow", aligned to *Washington State* standards; no named advisors, no published research | Feelings taxonomy; clinically-reviewed antihero arc; CASEL map planned |
| Continuity/memory | Not offered | Character identity only | Not offered | Not offered | **Saga memory** |
| Interactivity | Linear | Linear | Passive listening | Linear | **Pick-a-Path + Life Quests** |
| Narration | Neural TTS | Neural TTS + **parent voice-cloning** | **Celebrity human** (Hawn, Stewart) | Human (Hale/Henson) | Azure neural + read-along |
| Illustrations/exports | AI + new AI video; no printables | AI + **printed physical books** | Static art | Physical retail; classroom printables | AI + **coloring-page export** |
| COPPA posture | GDPR/Austria framing; Mixpanel/Firebase/OneSignal | Reactive disclaimer, no consent mechanism, AI vendor undisclosed | **Shares child data with Google Analytics, Facebook, Adjust, Iterable** | E-commerce policy; consent on age-gated features | Verifiable consent, opt-in analytics, per-story moderation, transparency notes |
| Pricing | $4.99/mo, $39.99/yr + credits | $7/$15/$29 mo, **no free tier** | $9.99/mo, **$49.99/yr** | App delisted; $158/yr educator hub | Free 5/mo+1 illus.; $9.99/mo, $59.99/yr |
| Traction | iOS 55 ratings; Play ~2,660, 100K+ installs | Near-zero | iOS 69K ratings, Editors' Choice, **$12M Series B** | Emmy-nom TV, ~$25.3M raised; **consumer app delisted** | Pre-launch |

### Brief pass

| App | Status | Distinctive |
|---|---|---|
| StoryBud | Live, **rebranded "StarredIn"**; 16 ratings | Photo woven into illustrated art |
| HeroMe | Live (web-only) | **CBT-informed 12-chapter arcs** for anxiety/anger/routines |
| LongStories.ai | Live | 15-min animated **video** stories |
| Ozzystory | Live, pricing gated | Branching SEL for **ASD/ADHD**, therapist channel |
| StoryTime Kids | Live, 2 ratings | **EN/ES/DE read-along + offline** |

### What we have that none of the nine have (verified)
- Age bands past 12 (teen generative content + clinically-reviewed antihero arc = zero competition)
- Narrative saga memory across stories
- Parent-set feeling/trigger/coping input woven into a personalized story
- Branching + personalization combined
- Coloring-page export of the child's own characters
- Learning-to-Read phrase-per-line + Rhyme Time
- Documented per-story server-side moderation + story transparency notes

### What they have that we lack
- Published, peer-reviewed efficacy evidence (Moshi's NYU sleep study)
- Human/celebrity narration; parent voice-cloning (StoryBee, from 3 recordings)
- Physical fulfillment (printed books, plush retail); AI story video
- Price umbrella: Oscar $39.99/yr and Moshi $49.99/yr sit under our $59.99/yr *(pricing was decided 2026-07-07 — awareness, not a re-litigation)*
- B2B education channel ($158/yr curriculum hub precedent); multilingual + offline

---

## Part 3 — Ranked improvement roadmap

1. **Publish the parent-facing safety page** *(marketing artifact, no code).* Constrained generation, per-story moderation, real consent flow, no ads, opt-in analytics — vs. Moshi shipping child data to Facebook/Iterable and Oscar's unnamed "educators." Nobody in the set can publish this page; we already built everything on it.
2. **Clinical credibility sprint** *(owner + agent).* Named advisory clinician (Padron/Jones outreach in flight) + a genuine CASEL 5 map. The agent's key find: even Slumberkins — the segment's SEL brand leader — aligns to Washington State standards and names no credentialed advisor. A real CASEL map + named clinician leapfrogs the entire set. Long-term: Moshi's peer-reviewed study is the credibility ceiling to aim at.
3. **Fix A-1 sensory-palette rotation** *(agent-sized, next prompt chunk).* Quality-at-scale; pairs with extending openers to superhero/bedtime paths.
4. **Narrow the launch promise** to 1–2 high-anxiety moments (per VALIDATION.md §3) and lean the copy on the two zero-competition facts: feelings-woven stories + ages-past-12.
5. **Deepen coloring-page/printables export → Pinterest funnel** — the only feature that is also the #1 ranked acquisition channel.
6. **Candidates, not commitments:** parent voice-cloning narration (StoryBee-style; emotionally potent but voice data is sensitive under amended COPPA — needs its own privacy analysis before any build); Spanish read-along (large US parent market, StoryTime Kids precedent); physical/photo-book fulfillment (proven willingness-to-pay, heavy ops).

**Positioning language:** borrow StoryBee's screen-free/audio framing and Slumberkins' brand-level emotional mission voice; never ship Oscar's unverifiable "reviewed by educators" pattern — name the clinician or don't claim it.
