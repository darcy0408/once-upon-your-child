# Session Records

One Markdown file per work session. Filename format:

```
YYYY-MM-DD-HHMM-<id>.md
```

Where `<id>` is a 4-character hex tag (e.g. `a7f3`) chosen at session-close time so each session has a globally unique handle. The ID is also referenced from the Recent Sessions table in `../../TEAM_COORDINATION.md` and from manual-task entries in `../MANUAL_TASKS.md`.

## File structure

Each session file follows this template (see `.claude/commands/session-close.md` for the canonical version):

```markdown
# SESSION CLOSE — YYYY-MM-DD HH:MM [id] — Branch: <branch> — <topic>

## Accomplished
- ...

## Still Pending / Deferred
- ...

## Blockers
- ... (or "None")

## Files touched
- path/to/file1.dart
- path/to/file2.py

## Manual tasks
- Created: MT-042, MT-043
- Closed:  MT-018, MT-024

## Next session: start here
> 1–2 sentences
```

## Why one file per session

Multiple Claude Code instances run in parallel. A shared file (the old `TEAM_COORDINATION.md`-prepend pattern) hits write races. One file per session means zero contention — every session writes its own path.

## Discoverability

`TEAM_COORDINATION.md` keeps a "Recent Sessions" index table at the top with date/time/id/branch/topic columns. `start-session` reads that table, filters by current branch, and opens the relevant session files.
