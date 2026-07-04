# SEL Framework Alignment — Once Upon YOUR Child

**Status:** Design-intent / competitive-positioning document. **Not** a clinical validation study.
**Owner action needed:** clinical advisor naming (see §5) before this doc is shown externally as
"clinically reviewed."
**Related:** [`docs/SAFETY_AUDIT_REMEDIATION.md`](SAFETY_AUDIT_REMEDIATION.md),
[`docs/CLINICAL_REVIEW_ADOLESCENT_ANTIHERO.md`](CLINICAL_REVIEW_ADOLESCENT_ANTIHERO.md),
memory `sel_credentialing_gap.md`.

## Purpose

"Once Upon YOUR Child" (technical/platform name **Story Weaver**) is positioned as the
therapeutically-grounded option in the personalized-children's-story market. A 2026-06
competitive pass found our single weakest flank versus **Slumberkins** (which publishes
CASEL/ASCA alignment documentation and names a clinician on staff) is **credentialing**: we build
real social-emotional-learning (SEL) content, but we had not documented how it maps to recognized
public frameworks.

This document closes that gap. It exists to:

1. Give parents and educators a credible, checkable answer to "what is this actually teaching my
   kid, and how do you know?"
2. Anchor marketing's "therapeutically grounded" claim to named standards rather than vibes.
3. Provide the scaffolding an eventual kidSAFE/Safe-Harbor application or clinical-advisor
   engagement would need.

## Scope and limitations (read this before citing this doc anywhere)

- This is an **alignment and design-intent** document: it maps existing product mechanics to the
  language of CASEL and ASCA and cites the general evidence base for SEL-through-narrative. It is
  **not** a claim that the app itself has been clinically trialed, that outcomes have been
  measured in users, or that any named framework organization (CASEL, ASCA) has reviewed or
  endorsed this product. CASEL and ASCA are school-system frameworks; this product is a
  consumer app, not a curriculum, so mappings are analogical, not certifications.
- Where a mapping is a stretch, this doc says so explicitly rather than force-fitting a standard
  code to a feature that doesn't really teach it. See the "coverage" columns below.
- The **boundary-setting** feature referenced throughout is **partially built**: Phase 1 (a
  parent-selectable "Setting Boundaries" therapeutic goal + two authored scenarios) shipped in PR
  #253. Phases 2–5 (ambient boundary beats woven into ordinary stories, dedicated per-band Life
  Quest content, a self/others emphasis toggle) are planned and tracked as **MT-232**, not yet
  live. Sections below mark which parts are shipped vs. planned.
- The **clinical advisory** section (§5) is a placeholder. No clinician has been named. Do not
  present this document as clinically reviewed until that section is filled in and the review it
  describes has actually happened.

---

## 1. CASEL 5 mapping

The CASEL (Collaborative for Academic, Social, and Emotional Learning) framework names five core
competencies, cultivated developmentally from early childhood through adulthood.¹ The table maps
each competency to the product mechanics that develop it, with an honest coverage rating.

| CASEL competency | Definition (CASEL) | Product features | How | Coverage |
|---|---|---|---|---|
| **Self-Awareness** | Identifying one's own emotions, thoughts, and values, and how they influence behavior. | `FeelingsBadgeGrid` (Adventurer band emotion-card grid — happy/sad/worried/frustrated/angry/embarrassed/excited/calm, each paired with a plain-language body/context cue, e.g. "Ready to explode"); the Sprout "Big Feelings" flow (four animal companions — Sunny Pup, Rainy Bunny, Roary Lion, Shy Mouse — each anchoring a feeling family); the boundary skill's **"uh-oh feeling"** body-cue through-line (`lib/therapeutic_models.dart`), which teaches interoceptive awareness — noticing a physical/emotional signal before it becomes a reaction. | Naming an emotion from a labeled set is the standard early step in emotion-vocabulary building; the "uh-oh feeling" cue explicitly trains noticing an internal state as a precursor to acting on it. | **Strong.** This is the best-covered competency — emotion identification is a first-class, per-band UI surface. |
| **Self-Management** | Regulating emotions, thoughts, and behaviors in different situations; managing stress; motivating oneself; setting and working toward goals. | The Coping Technique library (`lib/data/coping_techniques.dart` — timed breathing/grounding sequences, e.g. "Dragon's Breath") surfaced both as a standalone "Coping Toolbox" and in-story via `QuestSegment.copingBreakId` ("Try it with [companion]!"); the parent-selectable `TherapeuticGoal.emotionalRegulation`, `.focus`, and `.resilience` story customizations; boundary-skill Outcome **O2** ("notice the uh-oh + take a safe next move," per MT-232/`boundary_skills_feature.md`). | Practicing a concrete, physically-anchored regulation skill (paced breathing, grounding) at the point of narrative tension is the mechanism most SEL curricula use to teach self-management. | **Solid, narrow.** Coping techniques are real and evidence-informed (paced breathing, grounding), but the library is authored for ages 6–8 and reused elsewhere — goal-setting and stress-management content outside "feelings" scenarios is thinner. |
| **Social Awareness** | Understanding others' perspectives and empathizing, including across differing backgrounds. | Life Quest scenarios built around reading another person's state — `standing_tall` (noticing a peer who has been "shrunk" by unkindness and needs encouragement); the boundary skill's Outcome **O3** content, `boundary_respect_others` ("Watch faces and feelings for an 'uh-oh'," `lib/therapeutic_models.dart:568-584`); `TherapeuticGoal.empathy` and `.socialSkills` story customizations. | These scenarios require the reader to infer another character's internal state from cues and choose a response, which is the core mechanic of perspective-taking practice. | **Partial.** Empathy/perspective-taking beats exist and are well-written, but there is no explicit content today addressing perspective-taking **across difference** (culture, ability, background) — see the ASCA B-SS 10 gap noted in §2. |
| **Relationship Skills** | Communicating clearly, listening, cooperating, resisting negative social pressure, negotiating conflict, seeking/offering help. | Life Quest `brave_friend` (joining a peer group, saying hello); `standing_tall` (allyship — "standing up doesn't mean standing alone"); boundary-skill scenario `boundary_say_no` ("a real friend stays after you say no," `lib/data/scenario_data.dart`/`therapeutic_models.dart`); the post-quest **`grownupTip`** field, which hands the skill to a real caregiver conversation rather than leaving it inside the fiction. | Rehearsing a specific relational script (asking to join, asserting a limit, seeking an adult's help) in a safe fictional frame, then bridging it to a real conversation via `grownupTip`, is a standard bibliotherapy-to-practice pathway. | **Solid.** Friendship, inclusion, and help-seeking are recurring, explicitly-authored themes; group cooperation/teamwork mechanics (working *with* several peers, not just one) are not separately modeled. |
| **Responsible Decision-Making** | Making caring, constructive choices about behavior across situations, considering ethics, safety, and wellbeing of self and others. | The Life Quest branching mechanic itself: `QuestChoice → QuestSegment` consequence chains (`lib/data/life_quest_data.dart`), with an authored **`growthPrompt`** per choice for the Adolescent band (`docs/briefings/ADOLESCENT_LIFEQUEST_BACKLOG.md`) prompting reflection after the consequence plays out; the parent-facing sensitivity interstitial (`QuestSensitivity`, `sensitivityTopics`, `parentNote`) that models escalating heavy topics to a trusted adult rather than resolving them alone. | Choosing between options, seeing a consequence unfold in a bounded, safe fictional world, and then reflecting on it (`growthPrompt`) is a rehearsal loop for real decision-making — without real-world stakes. | **Partial by design.** The rehearsal is real but the "decision space" is authored, not open — a child picks among 2–4 pre-written options, not a truly free choice. That is a deliberate safety constraint (see `QuestSensitivity` gating), not an oversight, but it means this competency is trained as *guided* rather than *autonomous* decision-making. `growthPrompt` (the explicit reflection step) currently exists for the Adolescent band only; other bands rely on the consequence itself doing the teaching. |

¹ CASEL, "What Is the CASEL Framework?" — casel.org/fundamentals-of-sel/what-is-the-casel-framework.

---

## 2. ASCA Mindsets & Behaviors mapping

The American School Counselor Association's **Mindsets & Behaviors for Student Success** standards
are the K–12 counseling-profession's operationalization of SEL, and ASCA publishes its own official
crosswalk mapping every standard to the CASEL 5.² This section maps that same crosswalk against
our product features — i.e., we route through ASCA's own CASEL alignment rather than inventing a
parallel one.

Coverage key: **●** = directly, actively taught by a shipped feature · **◐** = touched, partial or
indirect · **○** = not currently targeted (named honestly rather than omitted).

### Mindsets (M1–M6)

| Code | ASCA standard | ASCA→CASEL | Coverage | Product tie |
|---|---|---|---|---|
| M 1 | Belief in development of whole self, incl. a healthy balance of mental, social/emotional, and physical well-being | Self-awareness | ● | This is the app's organizing premise — Life Quests, the Feelings flow, and the Coping Toolbox all frame emotional health as part of "whole self" development, not an add-on. |
| M 2 | Sense of acceptance, respect, support, and inclusion for self and others | Self-awareness | ◐ | `brave_friend` (joining a group), `standing_tall` (solidarity with an excluded peer); companion characters model consistent, unconditional support. No content yet specifically addresses inclusion **across difference** (see B-SS 10 below). |
| M 3 | Positive attitude toward work and learning | Self-awareness | ○ | Not targeted — this app is not an academic-effort or study-habits product. |
| M 4 | Self-confidence in ability to succeed | Self-awareness | ◐ | `standing_tall`'s inner-glow-of-courage device and the general hero's-journey structure of every generated story cast the child protagonist as capable of meeting the challenge. Not measured or reinforced outside the fiction. |
| M 5 | Belief in using abilities to the fullest to achieve high-quality outcomes | Self-awareness | ○ | Not targeted — no achievement/mastery framing in current content. |
| M 6 | Postsecondary education and lifelong learning are necessary for long-term success | Self-awareness | ○ | Out of scope — not an age- or product-appropriate goal for a 3–17-year-old storytelling app. |

*(Honest note: ASCA's own crosswalk routes all six Mindsets to CASEL Self-Awareness, which is why
this table has more "not targeted" rows than the Behaviors tables below — M3/M5/M6 are academic/
career-readiness mindsets that simply don't apply to a non-school product.)*

### Behaviors — Self-Management Skills (B-SMS)

| Code | ASCA standard | ASCA→CASEL | Coverage | Product tie |
|---|---|---|---|---|
| B-SMS 1 | Responsibility for self and actions | Self-management | ◐ | Life Quest consequence chains; boundary-skill Outcome O1 (assert own limits). |
| B-SMS 2 | Self-discipline and self-control | Self-management | ◐ | Coping Technique practice at moments of narrative tension. |
| B-SMS 3 | Independent work | Self-management | ○ | Not targeted. |
| B-SMS 4 | Delayed gratification for long-term rewards | Self-management | ○ | Not targeted. |
| B-SMS 5 | Perseverance to achieve long- and short-term goals | Self-management | ○ | Not directly authored; incidental in some quest resolutions. |
| B-SMS 6 | Ability to identify and overcome barriers | Self-management | ◐ | Every Life Quest is structurally "a barrier the protagonist works through." |
| B-SMS 7 | Effective coping skills | Self-management | **●** | Direct, best match in this category — the Coping Technique library (`coping_techniques.dart`) is exactly this standard: named, practiced, evidence-informed regulation skills (paced breathing, grounding). |
| B-SMS 8 | Balance of school, home, and community activities | Self-management | ○ | Not targeted. |
| B-SMS 9 | Personal safety skills | Self-management | ◐ | Boundary skill's "tell a trusted grown-up" step; `QuestSensitivity`-gated parent interstitial; `CrisisResourcesPanel` (988 / Crisis Text Line / Trevor Project) surfaced on heavy-topic Life Quests. |
| B-SMS 10 | Ability to manage transitions and adapt to change | Self-management | **●** | Direct match — the `change_is_coming` Life Quest is authored specifically around moving/new-school transitions ("everything is packed in boxes, and the new place feels like a mysterious planet"). |

### Behaviors — Social Skills (B-SS)

| Code | ASCA standard | ASCA→CASEL | Coverage | Product tie |
|---|---|---|---|---|
| B-SS 1 | Effective oral/written communication and listening skills | Relationship skills | ◐ | Boundary-skill scripts ("say 'stop' or 'no thank you'") rehearse a specific assertive-communication line. |
| B-SS 2 | Positive, respectful, supportive relationships with peers similar to and different from them | Relationship skills | ◐ | `brave_friend` Life Quest (joining a peer group); "different from them" half is not specifically addressed. |
| B-SS 3 | Positive relationships with adults to support success | Relationship skills | ◐ | Boundary skill's "tell a trusted grown-up"; `grownupTip` field bridges the quest to a real caregiver conversation. |
| B-SS 4 | Empathy | Social awareness | ◐ | `standing_tall` (noticing a peer's distress); `boundary_respect_others` ("watch faces and feelings for an uh-oh"). |
| B-SS 5 | Ethical decision-making and social responsibility | Responsible decision-making | ◐ | The Life Quest choice/consequence loop generally; most explicit in `standing_tall` (choosing to help vs. staying silent). |
| B-SS 6 | Effective collaboration and cooperation skills | Relationship skills | ○ | Not modeled — the product is single-protagonist narrative, not group/multiplayer mechanics. |
| B-SS 7 | Leadership and teamwork skills in diverse groups | Relationship skills | ○ | Not modeled, for the same reason. |
| B-SS 8 | Advocacy skills for self and others; ability to assert self when necessary | Relationship skills | **●** | Direct match — this is literally the boundary-setting feature's thesis: `boundary_say_no` (self-advocacy) and `standing_tall` (advocacy for a peer). |
| B-SS 9 | Social maturity and behaviors appropriate to the situation | Social awareness | ◐ | General Life Quest social scenarios; not a named, separately-tracked skill. |
| B-SS 10 | Cultural awareness, sensitivity, and responsiveness | Relationship skills | ○ | **Named gap.** No Life Quest or therapeutic-goal content is currently authored specifically around cross-cultural awareness. Flagging honestly rather than force-mapping an unrelated feature to this code. |

### Behaviors — Learning Strategies (B-LS)

Mostly **not applicable**: B-LS covers academic study/learning-strategy skills (time management,
media literacy, coursework engagement), which this product doesn't target. The one loose fit:

| Code | ASCA standard | ASCA→CASEL | Coverage | Product tie |
|---|---|---|---|---|
| B-LS 2 | Creative approach to learning, tasks, and problem solving | Responsible decision-making | ◐ | The CYOA problem-solving structure of every Life Quest. |
| B-LS 9 | Decision-making informed by gathering evidence and others' perspectives | Responsible decision-making | ◐ | Loosely — a Life Quest choice is made with in-story information, though not literally "evidence-gathering." |

**Summary count:** of ASCA's 36 published standard codes (6 Mindsets + 30 Behaviors, split
10 B-LS + 10 B-SMS + 10 B-SS), this product actively or partially touches **18**, directly/strongly
matches **4** (M 1, B-SMS 7, B-SMS 10, B-SS 8), and does not currently target **18** — most of
those are academic/career-readiness or group-collaboration standards that are out of scope for a
solo-child narrative app by design, plus one named content gap (B-SS 10, cross-cultural awareness).

² ASCA, "ASCA Student Standards Crosswalk with the CASEL Framework 5" —
schoolcounselor.org (Mindsets & Behaviors for Student Success program area).

---

## 3. Age-band developmental appropriateness

CASEL's own developmental guidance organizes SEL benchmarks by grade band (preschool, early
elementary K–3, late elementary 4–5, middle school 6–8, early/late high school), noting that the
same five competencies look different in practice at each stage — e.g., self-awareness moves from
"name the feeling" in early elementary to "track how my feelings change over time and what
triggers them" in middle school.³ Our age bands map onto that progression as follows.

### Sprout (ages 3–5)
Developmentally, this age is pre-operational (Piagetian sense): children are building emotion
*vocabulary* before emotion *regulation strategy*, and abstract metaphor lands best when made
concrete and embodied. Product design matches this: the "Big Feelings" flow uses four **animal
companion guides** (Sunny Pup = happy, Rainy Bunny = sad, Roary Lion = mad, Shy Mouse = scared)
rather than an abstract emotion-word grid, and the boundary-skill content for this band leans on
a felt body-cue ("uh-oh feeling in your tummy") rather than an abstract rule. Targeted skill:
emotion *naming* and body-cue *noticing* — the foundation self-awareness needs before
self-management is possible.

### Explorer (ages 6–8)
Early-elementary children can hold a "stop, think, act" strategy but still need concrete steps,
not principles. This is the band the Coping Technique library was authored for
(`coping_techniques.dart` notes "Authored for ages 6-8 — short cycles, simple language, concrete
imagery") — timed, literal breathing/grounding sequences rather than an instruction to "calm
down." The boundary skill's first fully-authored CYOA example ("The Cookie Toll") targets this
band. Targeted skill: concrete regulation *technique* and first rehearsed assertive scripts.

### Adventurer (ages 9–12)
Late-elementary/early-middle-school children can generate alternative solutions and predict
consequences — this is exactly the cognitive capacity the Life Quest branching mechanic exercises
(pick a path, see a consequence, understand why). The `FeelingsBadgeGrid`'s eight-emotion set
(including subtler labels like "embarrassed" and "frustrated," not just the four basic Sprout
emotions) matches the wider emotional vocabulary typical at this age. Targeted skill: consequence
*prediction* and a differentiated emotional vocabulary.

### Creator (13–14) / Adolescent (15–17) / Adult (18+)
Middle-and-high-school-age (and adult) content shifts from externally-resolved plots toward
internal, identity-level framing — consistent with adolescent development literature on identity
formation and increasing capacity for abstract self-reflection. This shows up directly in the
product's per-band story "world bibles": the same Life Quest (e.g. `standing_tall`) is a literal
shadow-monster for Sprout, a realistic school-bullying scenario with "no magical solutions" for
mature bands, and an identity-level question ("Who are you when no one's watching?") for Creator.
The Adolescent band is the only one with an authored `growthPrompt` per Life Quest choice — an
explicit metacognitive-reflection step appropriate to older-adolescent abstract-reasoning capacity.
The Adult band's content (e.g. the reframed `big_feelings_quest` — "The work is sitting on the
bank without needing it to change") deliberately drops the "conquer your feelings" framing in favor
of acceptance-oriented language, consistent with mature emotional-regulation development.
*(The Adolescent antihero content's safety design is governed separately by
`docs/CLINICAL_REVIEW_ADOLESCENT_ANTIHERO.md` — that review is a prerequisite gate, not
superseded by this document.)*

³ CASEL / district implementation guidance summarized in "Keeping SEL Developmental," CASEL
Resources — casel.org (grade-band benchmarks: preschool, K–3, 4–5, 6–8, 9–10, 11–12).

---

## 4. Evidence base

This section cites the general research support for (a) SEL efficacy and (b) narrative/
bibliotherapy as a delivery mechanism. These are field-level findings about SEL and bibliotherapy
broadly — **not** studies of this app.

- **Durlak, J. A., Weissberg, R. P., Dymnicki, A. B., Taylor, R. D., & Schellinger, K. B. (2011).**
  "The Impact of Enhancing Students' Social and Emotional Learning: A Meta-Analysis of
  School-Based Universal Interventions." *Child Development*, 82(1), 405–432.
  Meta-analysis of 213 school-based universal SEL programs, 270,034 K–12 students. Found
  significant improvements in social-emotional skills, attitudes, behavior, and academic
  performance (an 11-percentile-point achievement gain) relative to controls. This is the
  foundational large-N evidence that structured SEL instruction works.

- **Cipriano, C., Strambler, M. J., Naples, L. H., Ha, C., Kirk, M., Wood, M., Sehgal, K.,
  Zieher, A. K., Eveleigh, A., McCarthy, M., Funaro, M., Ponnock, A., Chow, J. C., & Durlak, J. A.
  (2023).** "The State of Evidence for Social and Emotional Learning: A Contemporary
  Meta-Analysis of Universal School-Based SEL Interventions." *Child Development*, 94(5),
  1181–1204. A 2023 update/replication at larger scale (424 studies, 53 countries, ~575,000
  students, 2008–2020), confirming the Durlak-era findings hold under more recent, more rigorous
  study designs. Recognized as Wiley's top-cited *Child Development* paper for 2022–2023.

- **Yuan, S., Zhou, X., Zhang, Y., Zhang, H., Pu, J., Yang, L., Liu, L., Jiang, X., & Xie, P.
  (2018).** "Comparative Efficacy and Acceptability of Bibliotherapy for Depression and Anxiety
  Disorders in Children and Adolescents: A Meta-Analysis of Randomized Clinical Trials."
  *Neuropsychiatric Disease and Treatment*, 14, 353–365.
  Meta-analysis of 8 RCTs (979 participants) finding bibliotherapy significantly more effective
  than control conditions for depression/anxiety symptoms (SMD −0.52, 95% CI −0.89 to −0.15).
  Notably found **stronger effects for depression than for anxiety** in this population — an
  honest caveat, not a blanket "bibliotherapy fixes anxiety" claim.

- **General bibliotherapy mechanism literature** (multiple sources, 2023–2025, e.g. reviews in
  *Frontiers in Psychiatry* and *Australasian Journal of Special and Inclusive Education*)
  describes the working mechanism this product leans on: a reader identifying with a character
  facing a relatable emotional situation, which supports perspective-taking, emotional
  vocabulary, and processing of difficult experiences at a safe narrative distance. This is
  consensus-level mechanism description, not a single definitive trial.

**Honest caveat on all of the above:** these citations support that (1) structured SEL
instruction generally works, and (2) narrative/bibliotherapy is a plausible, evidence-supported
delivery mechanism for SEL content. They do **not** constitute a trial of this specific app, this
specific content, or this specific delivery format (AI-generated, personalized, interactive
fiction — as opposed to a fixed, human-authored book or a classroom SEL curriculum). Personalized
and AI-generated narrative is a newer format than the literature above was designed to test.

---

## 5. Clinical advisory

**`[TO BE NAMED — see MT-266(c) / MEMORY sel_credentialing_gap.md]`**

This section is a placeholder. No clinician has been retained, named, or asked to review this
document or the product as of this writing (2026-07-02). Per the owner's constraint, no name or
credentials are invented here.

What a named clinical advisor's review should attest to, at minimum, before this section is
filled in for real:

1. **Credentials appropriate to the claim** — a licensed mental-health professional with
   child/adolescent development expertise (e.g. LCSW, LMFT, PsyD/PhD in child clinical or
   developmental psychology, or a board-certified child psychiatrist), named with license type
   and state/jurisdiction.
2. **Scope of review actually performed** — did they review the CASEL/ASCA mapping above for
   accuracy, the Life Quest content itself, the boundary-setting tone rules, the age-band
   gating logic, or some subset? Say which.
3. **A dated, specific attestation statement** — not a generic "endorsed by a clinician" badge.
   E.g.: *"[Name, credentials] reviewed the Life Quest and boundary-setting content described in
   this document on [date] and found the developmental framing and safety language consistent
   with [X]. This review does not constitute a clinical trial or outcome validation."*
4. **An explicit boundary statement** matching this app's actual positioning — this product is
   not therapy and does not replace a mental-health professional; the advisor's statement should
   say so, consistent with the existing consent-screen/Privacy Policy "not therapy" disclaimers
   and the 988/Crisis Text Line resourcing already in the antihero and Life Quest safety review
   (`docs/CLINICAL_REVIEW_ADOLESCENT_ANTIHERO.md`).

This is the same clinical-review gate already required for the Adolescent antihero band
(MT-266(c)); naming an advisor here and completing that pending review could plausibly be a single
combined engagement rather than two separate ones — an owner decision, not a build task.
