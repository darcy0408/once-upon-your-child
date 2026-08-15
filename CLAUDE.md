# CLAUDE.md

Project rules for anyone — human or agent — working in this repo.

Everything here earned its place: each rule exists because breaking it already
cost us something, more than once. Treat them as laws, not suggestions.

**When a new mistake happens**, log it (what happened / root cause /
consequence / the rule that prevents a repeat) in the session record — see
`.claude/commands/close-session.md` for where those go. **When the same
mistake shows up a third time**, it stops being a log entry and becomes a rule
in this file.

**This repository is public.** Never commit session records, cost figures,
credentials, personal context, or security findings that describe a live
attack path. Sanitized one-liners in `TEAM_COORDINATION.md` and
`docs/MANUAL_TASKS.md` only.

---

## 1. The web Content-Security-Policy has broken production three times

The CSP lives in `web/_headers` (Cloudflare Pages copies it into `build/web/`).
Before narrowing any directive, know why each one is there:

- `https://www.gstatic.com` must be in **both** `script-src` and `connect-src`.
  `canvaskit.js` loads via script-src, then `fetch()`es `canvaskit.wasm` — and
  fetch is governed by connect-src. Pinning connect-src without gstatic served
  a **blank white app for two days** and was misdiagnosed as a platform outage.
- `media-src 'self' data: blob:` is required. Without it, `default-src 'self'`
  governs media, blocks `blob:` audio, and every narration silently falls back
  to the robotic on-device voice — while the backend TTS keeps returning 200s.
- `connect-src` needs `blob:`. `image_picker` hands back a `blob:` URL and
  `readAsBytes()` fetches it; omit this and photo upload dies with an empty
  preview.

**Rule:** when the frontend gains a new resource *type* (audio, video, worker,
frame), add its directive explicitly — the `default-src` fallback breaks
`blob:`/`data:` URLs with errors that don't look like CSP errors. **Verify by
observing behavior** — audio audibly plays, the image actually uploads. CSP
failures happen after the network layer, so HTTP status codes prove nothing.

## 2. Render UI changes at phone width before calling them fixed

A code-reading audit of 12 personas found navigation and logic defects and
**zero** layout, contrast, or truncation bugs — because nobody looked at the
running app. Three separate "shipped" fixes never reached the user, including a
text-size slider added to a screen that had no reachable entry point.

**Rule:** `flutter build web --release`, serve `build/web`, and drive it at a
360x740 viewport. Budget the ~60s build. Widget tests are weak evidence here —
they pass while the screen is unreadable. Verify the *deployed* artifact too; a
stale edge cache once made a live fix look missing.

For golden-based checks:

- `test/goldens/` is **excluded from CI on purpose** (Windows baselines can't
  match Linux), so golden failures only ever surface locally and can sit red
  for weeks masking later ones.
- If a screen branches on platform, the golden **must** inject that dependency
  and pin each branch separately. One golden was red for a month because the
  test built a real platform channel and captured the host's branch, not the
  code's. Always ask whether a diff comes from an unmocked platform dep before
  regenerating — regenerating bakes the wrong branch in permanently.
- Fredoka isn't bundled and runtime fetching is off, so screens using
  `GoogleFonts.fredoka` throw *after* the test and the run exits 1. **The PNGs
  are still written — read them.** Box glyphs are wider than real Fredoka and
  manufacture `RenderFlex overflowed` errors that don't exist on device. Never
  report an overflow without diffing against a HEAD baseline.

## 3. Multiple sessions share this checkout

Several agent sessions run against this working tree at once. They share the
index, HEAD, **and** the current branch.

- **Commit by explicit path** — `git commit -- <paths>` — never staged-mode.
  A commit meant to hold two files once pulled in a parallel session's images
  and a 48-line edit that was never `git add`-ed.
- **Run `git branch --show-current` before committing.** A parallel session
  running `git checkout -b` switches the branch under everyone. To recover,
  point main at your specific **commit hash** (`git branch -f main <hash>`) —
  never at a branch name a parallel session is still committing to.
- **`git worktree add` needs an absolute path** on Windows. `..\name` creates a
  folder literally named `..name` inside the repo.
- **Keep the shell's cwd at the repo root and use `git -C <path>` for
  worktrees.** The `git_guard.py` PreToolUse hook resolves relative to cwd, and
  it evaluates at the cwd left over from the *previous* command — so a
  self-correcting `cd root && git ...` still fails. Reset cwd in its own call
  first.
- **A `locked` worktree is not proof of a live session.** Locks persist on disk
  after an abnormal exit. Ask before removing one.
- **Fresh worktrees have no `backend/.env`** (gitignored, so it isn't carried
  over). This fails ~6 backend story-generation tests with a JWT-secret
  assertion, and the run is suspiciously fast. Copy the file in and re-run
  before calling it a regression.

## 4. Backend lint runs over the whole tree

CI runs `cd backend && black --check .` — the **entire** backend, including
files you didn't touch and **untracked files you just added**. Checking only
your modified files is how lint goes red on the first CI run.

Run flake8 **from `backend/`** so it picks up `backend/.flake8`; from the repo
root you get defaults (79-char lines, nothing ignored) and hundreds of false
E501s. Note `py_compile` passing says nothing about `black --check`.

## 5. Don't recompile `backend/requirements.txt`

The lockfile is compiled locally on Python 3.13; CI installs on **3.11**. A
bare `pip-compile` pins `audioop-lts` (and any other `requires-python>=3.13`
shim) unconditionally, which makes `pip install` fail on CI and turns the build
red.

For a single-package bump, hand-swap that package's version and `--hash` block,
or use `pip-compile --upgrade-package <pkg>` and verify the diff contains
nothing else.

## 6. The repo has mixed line endings

Checked-in blobs are mixed CRLF/LF (`text=auto`, no forced eol). `sed -i`
rewrites a whole file as LF; git then diffs **every line** — one edit produced
~5,500 phantom lines — guaranteeing review noise and merge conflicts with
parallel sessions.

Check `git ls-files --eol <file>` before bulk-editing (`i/crlf` = danger) and
prefer the Edit tool, which preserves surrounding bytes.

## 7. New Isar collections need the io/stub split

Isar's generated code contains 64-bit integer literals that can't be
represented in JavaScript, so `flutter build web` fails while native builds
pass. Any `@collection` class reachable from web-compiled code needs the
four-file pattern used by `CharacterLocal`, `StoryLocal`, and the others:

```
foo.dart       // export 'foo_stub.dart' if (dart.library.io) 'foo_io.dart';
foo_io.dart    // @collection class + part 'foo_io.g.dart'
foo_io.g.dart  // generated
foo_stub.dart  // plain Dart class, no Isar imports, no `part`
```

Today's "native only" import becomes tomorrow's shared util — be defensive.

## 8. The Flutter version is pinned deliberately

All five `flutter-action` sites pin `3.41.9`. Unpinned `stable` drifted to
3.47.0 and broke every frontend CI job for nine days. Bump the pin only
alongside a local `flutter upgrade` and a green test run — and bump all five
sites together.
