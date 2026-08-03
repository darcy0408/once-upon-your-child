"""Guards for the prompt drift detector (MT-392).

The detector previously pinned templates by absolute line number. Every window
drifted off its builder, and the suite happily reported PASS on code that
contained no prompt at all — so "snapshot refreshed" in a PR meant nothing.
These tests make that failure mode impossible to reintroduce silently:

* anchors are symbols and every one of them resolves;
* the stored baseline matches current source (this is the CI drift gate);
* a resolved span really does start at the symbol it names;
* an edit inside a builder moves its hash, and an edit above it does not;
* the offline registry and the live `prompt_versioning` hashes agree exactly.
"""

from __future__ import annotations

import ast
import hashlib
import inspect

import pytest

from backend.eval import prompt_registry, snapshot
from backend.services import prompt_versioning
from backend.services.prompt_service import PromptService
from backend.services.story_service import (
    AdvancedStoryEngine,
    _build_bedtime_prompt,
    _build_learning_to_read_prompt,
    _build_rhyme_time_prompt,
)

ALL_TEMPLATES = [(t.template_id, t) for t in prompt_registry.TEMPLATES]

# The builder each shared template_id resolves to at runtime. Mirrors
# prompt_versioning._REVISION_HASHES; kept explicit so a drift between the two
# registries shows up as a test failure rather than a silent skip.
RUNTIME_BUILDERS = {
    "T1_STANDARD": AdvancedStoryEngine.generate_enhanced_prompt,
    "T2_LTR_LIMERICK": _build_learning_to_read_prompt,
    "T3_LTR_SEUSSIAN": _build_learning_to_read_prompt,
    "T4_RHYME_TIME": _build_rhyme_time_prompt,
    "T5_BEDTIME": _build_bedtime_prompt,
    "T6_SUPERHERO_SPROUT": PromptService._build_superhero_prompt,
    "T7_SUPERHERO_EXPLORER": PromptService._build_superhero_prompt_explorer,
    "T8_SUPERHERO_ADVENTURER": PromptService._build_superhero_prompt_adventurer,
    "T9_SUPERHERO_CREATOR": PromptService._build_superhero_prompt_creator,
    "T10_ANTIHERO_ADOLESCENT": PromptService._build_superhero_prompt_adolescent,
}


class TestAnchorsResolve:
    @pytest.mark.parametrize("template_id,template", ALL_TEMPLATES)
    def test_every_anchor_resolves(self, template_id, template):
        spans = snapshot.resolve_spans(template)
        assert len(spans) == len(template.anchors)
        for _, start, end in spans:
            assert 0 < start <= end

    def test_no_template_pins_by_line_number(self):
        """Line-number pinning is the bug this whole module exists to prevent."""
        for template in prompt_registry.TEMPLATES:
            assert not hasattr(template, "line_start")
            assert not hasattr(template, "line_end")
            assert template.anchors, f"{template.template_id} has no anchors"

    @pytest.mark.parametrize("template_id,template", ALL_TEMPLATES)
    def test_span_starts_at_the_named_symbol(self, template_id, template):
        """A resolved span must actually begin at its symbol.

        This is the assertion the old line-number scheme could never satisfy:
        its windows pointed at whatever code had slid into place.
        """
        path = snapshot.REPO_ROOT / template.source_file
        _, lines = snapshot._load(path)
        for anchor, start, end in snapshot.resolve_spans(template):
            name = anchor.rsplit(".", 1)[-1]
            block = "\n".join(lines[start - 1 : end])
            head = block.lstrip()
            assert head.startswith(("@", "def ", "class ", name)), (
                f"{template_id}: span for {anchor} starts with "
                f"{head[:40]!r}, not a definition of {name}"
            )
            assert f"{name}" in block


class TestBaselineIsCurrent:
    def test_verify_reports_no_drift(self, capsys):
        """The CI drift gate. A failure here means either a prompt changed
        without `--refresh`, or a builder was renamed out from under an anchor.
        """
        exit_code = snapshot.verify()
        out = capsys.readouterr().out
        assert exit_code == 0, f"snapshot --verify reported drift:\n{out}"
        assert "MISSING" not in out
        assert "UNHASHED" not in out

    @pytest.mark.parametrize("template_id,template", ALL_TEMPLATES)
    def test_stored_hash_matches_source(self, template_id, template):
        assert template.content_hash, f"{template_id} has no baseline hash"
        assert snapshot.content_hash(template) == template.content_hash


class TestDetectorActuallyDetects:
    """The regression the old scheme failed: does an edit move the hash?"""

    def _template(self):
        return prompt_registry.by_id("T6_SUPERHERO_SPROUT")

    def test_edit_inside_the_builder_changes_the_hash(self, tmp_path, monkeypatch):
        template = self._template()
        original = (snapshot.REPO_ROOT / template.source_file).read_text(
            encoding="utf-8"
        )
        _, start, end = snapshot.resolve_spans(template)[0]

        lines = original.splitlines()
        # Mutate a line inside the builder's own span.
        lines[end - 1] = lines[end - 1] + "  # tampered"
        self._assert_hash_changes(
            tmp_path, monkeypatch, template, original, "\n".join(lines), changes=True
        )

    def test_edit_above_the_builder_does_not_change_the_hash(
        self, tmp_path, monkeypatch
    ):
        template = self._template()
        original = (snapshot.REPO_ROOT / template.source_file).read_text(
            encoding="utf-8"
        )
        _, start, _end = snapshot.resolve_spans(template)[0]

        lines = original.splitlines()
        # Insert well above the builder — the exact edit that used to shift
        # every line-number window and produce meaningless hash churn.
        lines.insert(start - 5, "# unrelated line added above the builder")
        self._assert_hash_changes(
            tmp_path, monkeypatch, template, original, "\n".join(lines), changes=False
        )

    def _assert_hash_changes(
        self, tmp_path, monkeypatch, template, original, mutated, *, changes
    ):
        before = snapshot.content_hash(template)

        target = tmp_path / template.source_file
        target.parent.mkdir(parents=True, exist_ok=True)
        target.write_text(mutated, encoding="utf-8")

        monkeypatch.setattr(snapshot, "REPO_ROOT", tmp_path)
        snapshot._source_cache.clear()
        try:
            after = snapshot.content_hash(template)
        finally:
            snapshot._source_cache.clear()

        if changes:
            assert after != before, "an edit inside the builder did not move the hash"
        else:
            assert after == before, "an edit above the builder moved the hash"

    def test_renamed_builder_fails_loudly(self, tmp_path, monkeypatch):
        """A missing anchor must raise, not silently hash neighbouring code."""
        template = self._template()
        original = (snapshot.REPO_ROOT / template.source_file).read_text(
            encoding="utf-8"
        )
        mutated = original.replace(
            "def _build_superhero_prompt(", "def _build_superhero_prompt_RENAMED("
        )
        assert mutated != original

        target = tmp_path / template.source_file
        target.parent.mkdir(parents=True, exist_ok=True)
        target.write_text(mutated, encoding="utf-8")

        monkeypatch.setattr(snapshot, "REPO_ROOT", tmp_path)
        snapshot._source_cache.clear()
        try:
            with pytest.raises(snapshot.AnchorError):
                snapshot.content_hash(template)
        finally:
            snapshot._source_cache.clear()


class TestRegistriesAgree:
    """`prompt_versioning` (runtime, inspect-based) vs the offline registry.

    Both hash the same builder source, so the values must be equal — which is
    what lets a `revision_hash` persisted on a Story row be compared directly
    against a registry baseline.
    """

    @pytest.mark.parametrize("template_id", sorted(RUNTIME_BUILDERS))
    def test_offline_hash_equals_runtime_hash(self, template_id):
        template = prompt_registry.by_id(template_id)
        runtime = prompt_versioning._REVISION_HASHES[template_id]
        assert snapshot.content_hash(template) == runtime
        assert template.content_hash == runtime

    @pytest.mark.parametrize("template_id", sorted(RUNTIME_BUILDERS))
    def test_ast_slice_is_byte_identical_to_getsource(self, template_id):
        template = prompt_registry.by_id(template_id)
        expected = inspect.getsource(RUNTIME_BUILDERS[template_id])
        assert snapshot._slice_source(template) == expected

    def test_every_sendable_template_has_a_runtime_hash(self):
        """A sendable prompt with no runtime counterpart is unattributable."""
        assert set(prompt_registry.SENDABLE_TEMPLATE_IDS) == set(
            prompt_versioning._REVISION_HASHES
        )

    def test_sendable_ids_are_registered(self):
        registered = {t.template_id for t in prompt_registry.TEMPLATES}
        assert prompt_registry.SENDABLE_TEMPLATE_IDS <= registered


class TestRegistryIntegrity:
    def test_template_ids_are_unique(self):
        ids = [t.template_id for t in prompt_registry.TEMPLATES]
        assert len(ids) == len(set(ids))

    def test_source_files_parse(self):
        for template in prompt_registry.TEMPLATES:
            path = snapshot.REPO_ROOT / template.source_file
            assert path.exists(), template.source_file
            ast.parse(path.read_text(encoding="utf-8"))

    def test_hashes_are_well_formed(self):
        for template in prompt_registry.TEMPLATES:
            assert len(template.content_hash) == 16
            int(template.content_hash, 16)  # raises if not hex

    def test_hash_is_sha256_prefix(self):
        template = prompt_registry.by_id("T5_BEDTIME")
        text = snapshot._slice_source(template)
        expected = hashlib.sha256(text.encode("utf-8")).hexdigest()[:16]
        assert template.content_hash == expected
