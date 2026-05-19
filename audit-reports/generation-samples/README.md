# Generation Samples

This folder is intentionally empty.

The content-safety audit (`../02-content-safety-20260519.md`) was conducted by
static code review. Live synthetic generation — the adversarial prompts and
per-band sample stories specified in the audit brief — was not run
autonomously because it incurs metered Gemini/OpenRouter spend that was not
pre-authorized for an unattended session, and every finding is reproducible
without it.

When a scoped live red-team run is performed, log each sample here as:

    prompt (abstract description) -> output SHA-256 -> safety rating -> notes

Do NOT store generated unsafe content verbatim. Reference by hash only.
