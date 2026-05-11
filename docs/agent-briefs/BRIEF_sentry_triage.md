# Brief: Sentry Issue Triage for Story Weaver

You are a triage agent for the Story Weaver Flutter app. Your job is to pull live errors from Sentry and produce a prioritized, actionable report. **Do not fix code.** Output is a report only.

## Required tools
- Sentry MCP server with `mcp__sentry__*` tools (must be configured in your Claude Code or other harness)
- File write access to `C:\dev\story-weaver-app\docs\agent-briefs\reports\`

If Sentry MCP is not connected, stop and tell the user: "Need Sentry MCP — run `claude mcp list` to check, then add it via `claude mcp add` if missing."

## Project context
- App: Story Weaver, Flutter mobile + web. Uses `sentry_flutter ^9.16.0`.
- Repo: `C:\dev\story-weaver-app`
- Two surfaces emit errors: Flutter app (mobile/web) AND a Python backend on Railway. Look for BOTH in Sentry.
- Recent risk areas (changes in flight that may be producing new errors):
  - Avatar generation / hair preservation from reference photo
  - Image generation routing (Flux Schnell vs Gemini Image, OpenRouter)
  - Stripe subscription flow — known broken: checkout omits user_id, two competing SubscriptionService classes
  - Per-page illustration prefetcher
  - BYOK premium tier work

## Steps

1. **Find the project.** Call `mcp__sentry__find_organizations` then `mcp__sentry__find_projects`. Capture the org slug and the Story Weaver project slug(s) — there may be a Flutter project AND a Python backend project. Record both.

2. **Pull unresolved issues from the last 14 days.** Use `mcp__sentry__search_issues` with `is:unresolved age:-14d`, sorted by event count or user impact (highest first). Get top 25 per project.

3. **For each issue, capture:**
   - Title and short error message
   - Event count and user count
   - First seen / last seen
   - Top frame of stack trace (file:line)
   - Whether it's correlated with a recent release (use `mcp__sentry__find_releases` to cross-reference)
   - Direct Sentry URL

4. **Group and rank.** Cluster issues by root cause area (avatar, image-gen, stripe, prefetch, BYOK, other). Within each cluster, rank by user count × event count.

5. **For the top 5 issues across all clusters,** run `mcp__sentry__analyze_issue_with_seer`. Capture Seer's proposed fix verbatim.

6. **Write the report** to `docs/agent-briefs/reports/sentry_triage_YYYY-MM-DD.md` (use today's date — get it from system context). Structure:

   ```markdown
   # Sentry Triage — YYYY-MM-DD

   ## TL;DR
   - Total unresolved: N (Flutter: A, Backend: B)
   - Top cluster: <name> (X issues, Y users impacted)
   - Critical now: <one-line>

   ## Top 5 issues — fix first
   ### 1. <title>
   - **Cluster:** avatar | image-gen | stripe | prefetch | byok | other
   - **Impact:** N events, M users, first seen YYYY-MM-DD
   - **Top frame:** `path/to/file.dart:123`
   - **Seer proposed fix:** <verbatim from analyze_issue_with_seer>
   - **Sentry link:** <url>

   ## By cluster
   ### Avatar
   - [issue title] — N events — file:line — <one-line hypothesis>
   ...

   ## Noise / low priority
   <bullets — issues with <5 events and <2 users>
   ```

7. **Write nothing else.** No code changes. No fixes. No memory writes. Just the report file.

## Done when
- Report file exists at the path above
- Every top-5 issue has a Seer analysis attached
- You've told the user the path and pasted the TL;DR section in chat

## Hand-off
After writing the report, output to chat:
```
Sentry triage complete. Report: docs/agent-briefs/reports/sentry_triage_<date>.md
<paste TL;DR section>
Next: hand the report to the implementation agent or pick one issue to fix.
```
