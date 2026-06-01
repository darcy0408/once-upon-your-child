#!/usr/bin/env python3
"""PreToolUse/Bash guard for parallel Claude Code sessions.

This repo is frequently worked by multiple Claude sessions sharing ONE
checkout. The git index and the stash stack are global to the repo, so a
handful of git commands silently clobber or consume another session's
uncommitted work:

  - git stash (any subcommand)  -> pops/drops a peer session's stash
  - git reset --hard            -> wipes everyone's uncommitted edits
  - git checkout -- <path>      -> discards working-tree changes by path
  - git checkout HEAD -- <path> -> same, from HEAD
  - git clean -f / -d           -> deletes untracked files

The hook reads the PreToolUse JSON on stdin and, when the command matches,
prints a permissionDecision=deny object so the call never runs. Anything
else produces no output (no decision -> command proceeds normally).

To avoid false positives, the scanned text first has heredoc bodies and
quoted strings removed, so a dangerous token that appears only inside a
commit message (`git commit -F - <<'EOF' ... git stash ... EOF`) or a
quoted argument (`-m "git stash"`) is NOT matched. Matches are also anchored
to command boundaries (start / ; / && / || / | / newline / subshell) so the
token must be an actual command, not prose.

A human can always override by running the command themselves via the `! `
input-box prefix; this guard only governs tool calls.

Pure stdlib (no jq) so it works in the Git-Bash environment where jq is
absent.
"""
import json
import re
import sys


def _strip_heredocs(text: str) -> str:
    """Drop heredoc bodies so their content isn't scanned as commands.

    Keeps the line carrying the `<<TAG` operator (that's the real command),
    then skips every line up to and including the closing TAG line.
    """
    lines = text.split("\n")
    out = []
    i = 0
    n = len(lines)
    while i < n:
        line = lines[i]
        out.append(line)
        m = re.search(r"<<-?\s*['\"]?([A-Za-z_][A-Za-z0-9_]*)['\"]?", line)
        if m:
            tag = m.group(1)
            i += 1
            while i < n and lines[i].strip() != tag:
                i += 1
            # i now points at the closing tag line (or past EOF); skip it.
        i += 1
    return "\n".join(out)


def _strip_quotes(text: str) -> str:
    """Blank out single- and double-quoted spans so dangerous tokens inside
    string arguments (e.g. -m "git stash") aren't matched."""
    text = re.sub(r"'[^']*'", " ", text)
    text = re.sub(r'"[^"]*"', " ", text)
    return text


# A command boundary: start of string, newline, or a shell separator
# (; & | and the doubled forms, plus subshell paren). The token must follow
# one of these to count as an actual command rather than prose.
_B = r"(?:^|[\n;&|(])[ \t]*"

_RULES = [
    (re.compile(_B + r"git[ \t]+stash\b"), "git stash"),
    (re.compile(_B + r"git[ \t]+reset[ \t]+--hard\b"), "git reset --hard"),
    (
        re.compile(_B + r"git[ \t]+checkout[ \t]+HEAD[ \t]+--(?:[ \t]|$)"),
        "git checkout HEAD -- <path>",
    ),
    (
        re.compile(_B + r"git[ \t]+checkout[ \t]+--(?:[ \t]|$)"),
        "git checkout -- <path>",
    ),
    # git clean with a SHORT force/recurse flag (-f, -d, -fd, -df, -xfd, ...).
    # (?<!-) means a single leading hyphen only, so --dry-run / -n stay allowed.
    (
        re.compile(_B + r"git[ \t]+clean\b[^|;&\n]*(?<!-)-[a-z]*[fd]"),
        "git clean -f/-d",
    ),
]


def main() -> int:
    try:
        payload = json.load(sys.stdin)
    except Exception:
        return 0  # malformed/empty stdin -> fail open, don't block

    cmd = (payload.get("tool_input") or {}).get("command") or ""
    scan = _strip_quotes(_strip_heredocs(cmd))

    matched = None
    for rx, label in _RULES:
        if rx.search(scan):
            matched = label
            break

    if matched is None:
        return 0

    reason = (
        f"Blocked: this repo is shared by parallel Claude sessions, so the git "
        f"index + stash stack are global. '{matched}' corrupts other sessions' "
        f"uncommitted work. Instead: commit only your paths "
        f"(git add <path> && git commit), branch from origin/main, or use a git "
        f"worktree. To override, run it yourself in the input box with the ! prefix."
    )
    print(
        json.dumps(
            {
                "hookSpecificOutput": {
                    "hookEventName": "PreToolUse",
                    "permissionDecision": "deny",
                    "permissionDecisionReason": reason,
                }
            }
        )
    )
    return 0


if __name__ == "__main__":
    sys.exit(main())
