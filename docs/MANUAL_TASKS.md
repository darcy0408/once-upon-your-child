# Manual Tasks

Single global backlog of items only Darcy can resolve (production verification, browser-only tests, deletes, decisions, credential steps, restarts).

**Append-only with monotonic IDs.** Sessions add new tasks at the bottom and close existing ones in place. Never renumber.

## Status legend

- `open`     — waiting for Darcy
- `done`     — completed (note the closing session ID)
- `wontfix`  — superseded, no longer relevant, or rejected
- `blocked`  — waiting on something other than Darcy (note what)

## How sessions update this file

When closing a session:

1. **Closing existing tasks**: find each `MT-NNNN` you resolved, change `open` → `done`, append `(closed by <session-id>)` to the line.
2. **Adding new tasks**: append at the bottom under `## Open tasks`. Look at the last 10 open tasks first to avoid dupes — if your task already exists, reference its existing ID in your session record instead of adding a new one.
3. **ID generation**: take the highest existing `MT-NNNN`, add 1. Pad to 3 digits.

## Open tasks

<!-- New tasks appended below. Format: `- **MT-NNN** [open] description (created by <session-id>) — context.` -->

## Closed tasks

<!-- Sessions move tasks here when status flips to `done` or `wontfix`. Most recent at top. -->
