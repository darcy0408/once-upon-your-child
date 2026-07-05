# Six Hats UX Audit — Band 5: Adolescent (15–17)

**Run:** prod, fresh anon, "Rio", 15–17 pill, Girl, Ecological Whisperer, solo, own-world, Medium. 7 screens.
**Note:** the antihero "double-life" saga is correctly ABSENT (gated off pending MT-266c clinical sign-off) — not a finding.

## Developmental frame
Adult-equivalent motor + reading; near-zero tolerance for friction or condescension. Privacy-sensitive. Will abandon on the first "this is for kids" tell.

## Findings

### Age gate → attestation
- **Yellow:** The 15–17 path is exactly right: "Just so you know — since you're under 18, please make sure a parent or guardian knows you're using this app. [Got it]" — non-blocking, non-condescending, one tap. Best-practice teen gate.

### Creative Brief
- **Yellow:** Same editorial brief as Creator (correct); teal accent variant lands on the pitch screen.
- **Black:**
  1. **P2 — Boy/Girl cards nearly indistinguishable:** both render a dark cinematic figure-at-desk thumbnail; at ~80px the two cards read as duplicates (adolescent_boy 39KB vs _girl 150KB are different files, but visually converge at size). Zoom/crop the figures or brighten differentiation.
  2. P3 — archetype display-name drift again ("Ecological Whisperer" card → "The Animal Whisperer" pitch).

### Generation
- **Black:** P2 — "Your adventure is being written… / Something magical is about to happen… / Catch the sparkles! ✨" on the oldest child band. A 16-year-old wants "Drafting…" not sparkle-catching. Band-tone the whole wait screen (copy + hide the mini-game ≥15, or reskin as a subtle progress viz).
- **Yellow:** Elapsed-seconds counter + Cancel = respect.

### Reader — "The Bell Under the Blue Willows" (15 pages)
- **Yellow:** Painterly, atmospheric cover with NO gibberish AI text this run; teal action bar; Remix/Save/Share; 15 pages of substance. Title Case correct here (vs Creator's lowercase — inconsistency noted in band 4).
- **Black:** P2 — Share gating check applies here too (15–17 self-attested; sharing generated content by minors → verify what Share does).

### Cross-check
- Consent/BYOK/vendor findings from younger bands don't apply here (attestation path skips the consent screens).
- Superhero Mode absence verified — the story-type/archetype surfaces contain no double-life entry (MT-266c gate holding on prod).

## Action Plan (Adolescent)

| Priority | Screen | Issue | Change | Effort |
|---|---|---|---|---|
| P2 | Brief | Gender cards visually identical at size | Re-crop/brighten thumbnails | S |
| P2 | Generation | Young copy + sparkle game at 15–17 | Band-toned wait screen | S |
| P2 | Reader | Share gating unverified | Verify + gate | S (shared) |
| P3 | Brief/Pitch | Archetype name drift | Single display name (shared fix) | S |

**Elevate:** this band's retention lever is the (gated) antihero saga + Crux Choice — once clinically cleared, the wait screen could show noir "issue credits" (Issue #N production card) instead of sparkles; zero new mechanics, pure reskin of the existing continuity data.
