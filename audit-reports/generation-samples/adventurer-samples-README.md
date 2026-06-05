# Adventurer Story-Quality Samples (Audit 14)

Live Gemini output generated 2026-06-03 via
`backend/tests/quality/adventurer_audit_gen.py` (model `gemini-2.5-flash`,
the production default). Companion payloads faithfully reproduce what the
Flutter `WizardDataMapper` actually sends to the backend, including the
dropped power/sensory fields for companions whose ids do not match
`magicCompanions` (Atlas, Nyx, Kodiak reach the model as name + behaviorPattern
only; Rockin' Robin carries the full power payload).

| Sample | sha256 (first 12) | Inputs | Backend band | Words | Pages |
|--------|-------------------|--------|--------------|-------|-------|
| A (`sample-A-20260603-0810.txt`) | `ea8d1f076f08` | age 9, Standard, "The Crystal Cavern", companions Atlas + Nyx | 8-10 | 1347 | 12 |
| B (`sample-B-20260603-0810.txt`) | `0dfef10cd3ce` | age 11, Standard, identical inputs to A | 11-13 | 1672 | 15 |
| C (`sample-C-20260603-0810.txt`) | `4639b4e9360c` | age 10, Standard, "Last Day on Comet Street" (moving house), companion Rockin' Robin | 8-10 | 954 | 12 |

Each `.txt` is the page-by-page reading copy; the paired `.json` carries the
full prompt, metadata (themes, emotional_arc, characters_featured), and pages.
A and B are deliberately the SAME inputs at age 9 vs 11 to expose the
single-UI-band / two-backend-constraint-table straddle.

These files contain only fictional heroes (Zoe, Mateo) in safe contexts. No
real child data is present.
