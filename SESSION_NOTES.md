# Session notes

## 2026-07-28 — Fact-checked and finalized the Amber Grant (WomensNet) application draft

**Done:** (research/writing session — no code changed)
- Verified the grant-application essay drafted in a Claude desktop conversation against the actual repo and live sources, then delivered a corrected final draft in chat (the draft itself lives in the owner's desktop conversation / grant form, not in this repo).
- Confirmed accurate: limerick learning-to-read mode (`backend/eval/prompt_registry.py`, `ltr_limerick`, ages 7–12), superhero mode, choose-your-path, cartoon avatar of the child, four age bands spanning 3–17, free monthly stories with no card, web URL `https://onceuponyourchild.app` (apex only — `www.` does not resolve, open task MT-368).
- Confirmed grant program numbers via web search: WomensNet awards three $10,000 monthly Amber Grants; monthly winners compete for three $50,000 year-end grants.
- Corrected two false/stale claims in the draft: (1) "live on the web and Android" → app is web-only today (Google Play org account approved 2026-07-11 but no Play listing exists and the Android signing keystore was never created, MT-144 open); (2) "over 1,300 commits" → main actually has 2,849 commits.
- Softened the "siblings can go on an adventure together" claim to "stories can include their siblings and friends" because MT-385 (open, verify-first) says the multi-character screen may have no working backend route while the paywall sells it.

**Decisions:**
- Grant essay wording: claim web-only launch with stores "in the pipeline" — honest and still strong; do not claim Android availability until a Play listing is live.
- Left the seven `linux/macos/windows` generated-plugin files uncommitted: `git diff` shows zero content changes, only CRLF/LF phantom noise (known mixed-line-endings repo quirk). Do not commit or "fix" them.

**Next:**
1. Owner submits the Amber Grant application (final text delivered in the 2026-07-28 chat; replace suggested dollar figures with real ones — they currently sum exactly to $10,000 and $50,000).
2. Before ever restoring the stronger "siblings in one story" wording anywhere, verify MT-385: generate a multi-character story against prod and see if `/generate-multi-character-story` (or equivalent) exists and works.
3. Android launch path remains: create the release keystore (MT-144), then Play listing; this is what makes the "Android" claim true.

**Blocked on user:** submitting the grant application itself; choosing final budget dollar amounts.

**Risks/unverified:**
- MT-385 (multi-character/sibling stories backend route) is still unverified — the premium paywall advertises a feature that may fail with a network error.
- The essay's "parental consent designed in from the first line of code" is defensible (the consent flow is built and shipped); before answering any compliance follow-up from a grant judge, check the private session memory for the current prod consent-flag status rather than assuming.
