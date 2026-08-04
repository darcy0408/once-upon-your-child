"""Content-hash drift detector for the prompt registry.

`python -m backend.eval.snapshot --verify`
  Resolves each TEMPLATES entry's `anchors` — dotted symbol paths such as
  `AdvancedStoryEngine.generate_enhanced_prompt` or `SAFETY_GUARDRAILS` —
  against the current source, concatenates the resolved spans, computes
  sha256, and compares against the stored content_hash. Prints a per-template
  PASS/DRIFT report and exits 0 (all clean) or 1 (drift found).

`python -m backend.eval.snapshot --refresh`
  Recomputes every content_hash and writes the updated values back into
  prompt_registry.py.

Anchors are symbols, never line numbers. An edit *inside* a builder always
moves that builder's hash; an edit *above* it never does. Until 2026-08-03 the
registry sliced source by absolute line number, and every one of the thirteen
windows had drifted clean off its builder — twelve reported PASS against code
containing no prompt at all, and T11 reported DRIFT because unrelated code had
moved into its window. "Snapshot refreshed" was evidence of nothing (MT-392).

Resolution is static (`ast.parse` on the file) because backend/eval must not
import backend.services — see backend/eval/__init__.py.
`backend/services/prompt_versioning.py` computes the same hashes at runtime via
`inspect.getsource`; the two agree by construction, and
`backend/tests/test_prompt_snapshot_anchors.py` asserts they stay agreeing.

This is the audit's primary versioning mechanism — without it, "the prompt
that produced output X" cannot be reconstructed from git history alone
because production prompts are f-string-assembled at runtime.
"""

from __future__ import annotations

import argparse
import ast
import hashlib
import re
import sys
from pathlib import Path

from . import prompt_registry

REPO_ROOT = Path(__file__).resolve().parents[2]
REGISTRY_PATH = Path(__file__).parent / "prompt_registry.py"

_SYMBOL_NODES = (ast.FunctionDef, ast.AsyncFunctionDef, ast.ClassDef)


class AnchorError(Exception):
    """An anchor could not be resolved against the current source."""


def _child_named(node: ast.AST, name: str) -> ast.AST | None:
    """Find a direct child of `node` that defines or assigns `name`."""
    for child in ast.iter_child_nodes(node):
        if isinstance(child, _SYMBOL_NODES) and child.name == name:
            return child
        if isinstance(child, ast.Assign):
            for target in child.targets:
                if isinstance(target, ast.Name) and target.id == name:
                    return child
        elif isinstance(child, ast.AnnAssign):
            if isinstance(child.target, ast.Name) and child.target.id == name:
                return child
    return None


def _resolve(tree: ast.Module, dotted: str) -> ast.AST | None:
    """Walk a dotted path (`Class.method`, `CONSTANT`) to its AST node."""
    node: ast.AST = tree
    for part in dotted.split("."):
        found = _child_named(node, part)
        if found is None:
            return None
        node = found
    return node


def _span(node: ast.AST) -> tuple[int, int]:
    """1-indexed inclusive line span, decorators included.

    Including decorators matches `inspect.getsource`, which is what keeps this
    byte-identical to `prompt_versioning`'s runtime hashes.
    """
    start = node.lineno
    for decorator in getattr(node, "decorator_list", []):
        start = min(start, decorator.lineno)
    return start, node.end_lineno


_source_cache: dict[Path, tuple[ast.Module, list[str]]] = {}


def _load(path: Path) -> tuple[ast.Module, list[str]]:
    cached = _source_cache.get(path)
    if cached is None:
        text = path.read_text(encoding="utf-8", errors="replace")
        # splitlines() + "\n".join() normalises CRLF, so a line-ending flip in
        # the working tree can't masquerade as prompt drift (the repo is mixed).
        cached = (ast.parse(text), text.splitlines())
        _source_cache[path] = cached
    return cached


def resolve_spans(template) -> list[tuple[str, int, int]]:
    """Return `(anchor, line_start, line_end)` for each of a template's anchors.

    Raises AnchorError if the source file is gone or an anchor no longer exists
    — a renamed or deleted builder must fail loudly, not hash whatever code
    happens to sit where it used to be.
    """
    path = REPO_ROOT / template.source_file
    if not path.exists():
        raise AnchorError(f"source file not found: {template.source_file}")
    tree, _ = _load(path)
    spans = []
    for anchor in template.anchors:
        node = _resolve(tree, anchor)
        if node is None:
            raise AnchorError(f"{template.source_file}::{anchor} not found")
        start, end = _span(node)
        spans.append((anchor, start, end))
    return spans


def _slice_source(template) -> str:
    """Canonical source text for a template.

    Each span keeps its trailing newline so a single-anchor slice is *byte
    identical* to `inspect.getsource` of the same symbol. That is what makes a
    `revision_hash` persisted on a Story row directly string-comparable to this
    registry's `content_hash` — see test_prompt_snapshot_anchors.py.
    """
    path = REPO_ROOT / template.source_file
    _, lines = _load(path)
    chunks = [
        "\n".join(lines[start - 1 : end]) + "\n"
        for _, start, end in resolve_spans(template)
    ]
    return "".join(chunks)


def _compute_hash(text: str) -> str:
    return hashlib.sha256(text.encode("utf-8")).hexdigest()[:16]


def content_hash(template) -> str:
    """Current content hash for a template. Raises AnchorError if unresolvable."""
    return _compute_hash(_slice_source(template))


def _format_spans(spans: list[tuple[str, int, int]]) -> str:
    return " ".join(f"{anchor}:{start}-{end}" for anchor, start, end in spans)


def verify() -> int:
    drift = 0
    missing = 0
    print(
        f"snapshot verify @ git={prompt_registry.SNAPSHOT_GIT_SHA} "
        f"date={prompt_registry.SNAPSHOT_DATE}"
    )
    for t in prompt_registry.TEMPLATES:
        try:
            spans = resolve_spans(t)
            src = _slice_source(t)
        except AnchorError as exc:
            print(f"  MISSING  {t.template_id:24s} {exc}")
            missing += 1
            continue
        h = _compute_hash(src)
        where = _format_spans(spans)
        if not t.content_hash:
            print(
                f"  UNHASHED {t.template_id:24s} current={h}  "
                "(run --refresh to populate)"
            )
            drift += 1
        elif h != t.content_hash:
            print(
                f"  DRIFT    {t.template_id:24s} stored={t.content_hash} "
                f"current={h}  {where}"
            )
            drift += 1
        else:
            print(f"  PASS     {t.template_id:24s} {t.content_hash}  {where}")
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
        try:
            src = _slice_source(t)
        except AnchorError as exc:
            print(f"  SKIP  {t.template_id} — {exc}")
            continue
        h = _compute_hash(src)
        # Match the existing dataclass entry's content_hash field, anchored on template_id.
        pattern = re.compile(
            rf'(template_id="{re.escape(t.template_id)}",.*?content_hash=")[a-f0-9]*(")',
            re.DOTALL,
        )
        match = pattern.search(new_text)
        if match:
            new_text = pattern.sub(rf"\g<1>{h}\g<2>", new_text, count=1)
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
