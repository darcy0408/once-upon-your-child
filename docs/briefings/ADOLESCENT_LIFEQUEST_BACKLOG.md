# Adolescent Life Quest — Content Backlog

**Created:** 2026-04-21
**Owner:** content authoring (deferred)
**Related:** `lib/data/life_quest_data.dart`, `lib/screens/life_quest_screen.dart`

## Why

The Adolescent band (15–17) currently ships **3 Life Quests** — `someone_needs_help`, `thing_i_didnt_say`, `where_are_you_going`. A motivated teen opening the Inner Map tab exhausts the library in one sitting. The quests already authored are excellent (peer crisis, bystander guilt, future planning) but the thematic coverage is thin for a band that's supposed to be differentiated by richer emotional content.

Three more quests would double the library and plug the most glaring gaps.

## Existing quests (reference)

| ID | Emotions | Theme |
|----|----------|-------|
| `someone_needs_help` | worried, scared, sad | Witnessing a friend in crisis; peer support vs. adult intervention |
| `thing_i_didnt_say` | worried, sad, angry | Bystander guilt; frozen at the moment of injustice |
| `where_are_you_going` | worried, sad, frustrated | Post-secondary planning anxiety |

## Candidate themes (missing)

1. **Romantic rupture / rejection** — emotions: sad, angry, confused. Breakup or unrequited feelings. Choices around: contact vs. no-contact, processing vs. numbing, honesty about feelings.
2. **Social media comparison / public shame** — emotions: envious, ashamed, angry. Post that spirals; screenshot that circulates; feed-induced inadequacy. Choices around: respond vs. log off, deflect vs. own it.
3. **Family conflict (first serious)** — emotions: frustrated, hurt, resentful. Divorce, sibling dynamics, clash with parent over autonomy. Choices around: stand ground vs. compromise, listen vs. withdraw.
4. **Academic burnout** — emotions: tired, anxious, hopeless. Exam pressure, overcommitment, perfectionism. Choices around: ask for help vs. push through, drop a commitment vs. power through.
5. **Identity formation** — emotions: confused, hopeful, scared. Sexuality, gender, cultural/racial identity, being "out" vs. not. Choices around: disclose vs. hold, seek community vs. stay private. *(Sensitive — needs careful framing; validate all paths, don't moralize.)*
6. **First-job / money / independence anxiety** — emotions: anxious, excited, overwhelmed. First paycheck, boss confrontation, financial independence from parents. Choices around: speak up vs. comply, save vs. spend, ask for help vs. figure it out.

## Quest model requirements (reminder)

Each quest needs:
- `id` (snake_case)
- `title`, `emoji`, `hook` (1-line)
- `emotions: List<String>` — used for the feelings-badge filter
- `recommendedBands: [AgeBand.adolescent]`
- `startSegmentId` + map of `QuestSegment` nodes
- Each segment: `id`, `content`, either `choices: [...]` or `isEnding: true`
- Each choice: `text`, `nextSegmentId`, optional `consequence`, `growthPrompt`
- Ending segments should reflect the chosen path without moralizing

Authoring style for this band (see existing three quests for reference):
- 2nd-person narration, present tense
- Short sentences, no sugar-coating
- Validates the hard choice; doesn't reward the "correct" answer
- "Your silence looks a lot like agreement from the perspective of the person it happened to" — this kind of line is the target tone

## Priority

P1 candidate: **family conflict** (highest prevalence across the band)
P2: **romantic rupture**, **social media shame**
P3: **burnout**, **identity**, **first job**

## Not in scope for this doc

- Writing the quests (this is a content-authoring task, not code)
- UI changes (no code work needed; quest data model supports these out of the box)
- BYOK AI augmentation of quests (separate initiative)
