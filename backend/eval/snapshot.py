"""Content-hash drift detector for the prompt registry.

`python -m backend.eval.snapshot --verify`
  Reads each TEMPLATES entry, slices the source file at line_start..line_end,
  computes sha256, and compares against the stored content_hash. Prints a
  per-template PASS/DRIFT report and exits 0 (all clean) or 1 (drift found).

`python -m backend.eval.snapshot --refresh`
  Recomputes every content_hash and writes the updated values back into
  prompt_registry.py.

This is the audit's primary versioning mechanism — without it, "the prompt
that produced output X" cannot be reconstructed from git history alone
because production prompts are f-string-assembled at runtime.
"""

from __future__ import annotations

import argparse
import hashlib
import re
import sys
from pathlib import Path

from . import prompt_registry

REPO_ROOT = Path(__file__).resolve().parents[2]
REGISTRY_PATH = Path(__file__).parent / "prompt_registry.py"


def _slice_source(template) -> str | None:
    path = REPO_ROOT / template.source_file
    if not path.exists():
        return None
    text = path.read_text(encoding="utf-8", errors="replace").splitlines()
    if template.line_end > len(text):
        return None
    chunk = "\n".join(text[template.line_start - 1 : template.line_end])
    return chunk


def _compute_hash(text: str) -> str:
    return hashlib.sha256(text.encode("utf-8")).hexdigest()[:16]


def verify() -> int:
    drift = 0
    missing = 0
    print(
        f"snapshot verify @ git={prompt_registry.SNAPSHOT_GIT_SHA} "
        f"date={prompt_registry.SNAPSHOT_DATE}"
    )
    for t in prompt_registry.TEMPLATES:
        src = _slice_source(t)
        if src is None:
            print(
                f"  MISSING  {t.template_id:24s} {t.source_file}:{t.line_start}-{t.line_end}"
            )
            missing += 1
            continue
        h = _compute_hash(src)
        if not t.content_hash:
            print(
                f"  UNHASHED {t.template_id:24s} current={h}  "
                "(run --refresh to populate)"
            )
            drift += 1
        elif h != t.content_hash:
            print(f"  DRIFT    {t.template_id:24s} stored={t.content_hash} current={h}")
            drift += 1
        else:
            print(f"  PASS     {t.template_id:24s} {t.content_hash}")
    print(
        f"\nresult: {len(prompt_registry.TEMPLATES) - drift - missing} clean, "
        f"{drift} drifted/unhashed, {missing} missing"
    )
    return 1 if (drift or missing) else 0


def refresh() -> int:
    text = REGISTRY_PATH.read_text(encoding="utf-8")
    new_text = text
    updates = 0
    for t in prompt_registry.TEMPLATES:
        src = _slice_source(t)
        if src is None:
            print(f"  SKIP  {t.template_id} — source not found")
            continue
        h = _compute_hash(src)
        # Match the existing dataclass entry's content_hash field, anchored on template_id.
        pattern = re.compile(
            rf'(template_id="{re.escape(t.template_id)}",.*?content_hash=")[a-f0-9]*(")',
            re.DOTALL,
        )
        match = pattern.search(new_text)
        if match:
            new_text = pattern.sub(rf"\g<1>{h}\g<2>", new_text)
            updates += 1
            print(f"  UPDATE {t.template_id} -> {h}")
        else:
            # Entry lacks an explicit content_hash="..." — inject one after template_id="...".
            inject_pattern = re.compile(
                rf'(template_id="{re.escape(t.template_id)}",)',
            )
            replacement = rf'\1\n        content_hash="{h}",'
            new_new = inject_pattern.sub(replacement, new_text, count=1)
            if new_new != new_text:
                new_text = new_new
                updates += 1
                print(f"  INSERT {t.template_id} -> {h}")
            else:
                print(f"  SKIP  {t.template_id} — could not locate dataclass entry")
    REGISTRY_PATH.write_text(new_text, encoding="utf-8")
    print(f"\nrefreshed {updates} entries in {REGISTRY_PATH.name}")
    return 0


def main(argv: list[str] | None = None) -> int:
    p = argparse.ArgumentParser()
    g = p.add_mutually_exclusive_group(required=True)
    g.add_argument("--verify", action="store_true")
    g.add_argument("--refresh", action="store_true")
    args = p.parse_args(argv if argv is not None else sys.argv[1:])
    if args.verify:
        return verify()
    return refresh()


if __name__ == "__main__":
    raise SystemExit(main())
