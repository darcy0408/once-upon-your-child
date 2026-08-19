"""
Chronicle Prompt Service
Builds and executes prompts for chapter summarization and arc compression.

Provider (MT-137 / MT-327 launch-gate): this service previously called Gemini
directly on the server key with no age/consent gate, sending a child's full
story chapter (up to 50k chars) to a vendor whose API ToS forbid under-18
apps. It now runs on the same OpenAI client/model family already used for
children's story TEXT (``services/openai_story_generator.py``) and output
moderation (``utils/content_moderator.py``), via ``OPENAI_API_KEY``.
"""

import json
import logging
import os
from typing import Any, Dict, List, Optional

logger = logging.getLogger(__name__)

# Overridable via env so a deployment can point Chronicle calls at a different
# OpenAI model without touching story-text generation or moderation.
_DEFAULT_CHRONICLE_MODEL = "gpt-5-mini"
_DEFAULT_CHRONICLE_MAX_TOKENS = 2048
_DEFAULT_CHRONICLE_REASONING_EFFORT = "low"

# Sentinels that mean "send no reasoning_effort param" (mirrors
# openai_story_generator._NO_REASONING_SENTINELS / content_moderator).
_NO_REASONING_SENTINELS = frozenset({"", "none", "off", "default"})


def _make_openai_client(api_key: str):
    """Lazily import the SDK and build a client. Patched in tests."""
    import openai  # lazy: see module docstring

    return openai.OpenAI(api_key=api_key)


class ChroniclePromptService:
    """Builds and executes prompts for Living Story Chronicle operations."""

    SUMMARIZE_SYSTEM = (
        "You are a story archivist. You read a completed interactive story chapter "
        "and extract a compact memory packet in strict JSON. Be precise and concise."
    )

    COMPRESS_SYSTEM = (
        "You are a story archivist. You compress five chapter summaries into a single "
        "arc summary paragraph in strict JSON."
    )

    def __init__(self, api_key: Optional[str] = None):
        self.api_key = api_key or os.getenv("OPENAI_API_KEY")
        if not self.api_key:
            raise ValueError("OPENAI_API_KEY not set")
        self._client = _make_openai_client(self.api_key)
        self._model_name = (
            os.getenv("OPENAI_CHRONICLE_MODEL") or _DEFAULT_CHRONICLE_MODEL
        )
        self._max_tokens = self._resolve_max_tokens()
        self._reasoning_effort = self._resolve_reasoning_effort()

    @staticmethod
    def _resolve_max_tokens() -> int:
        raw = os.getenv("OPENAI_CHRONICLE_MAX_TOKENS")
        if not raw:
            return _DEFAULT_CHRONICLE_MAX_TOKENS
        try:
            value = int(raw)
            return value if value > 0 else _DEFAULT_CHRONICLE_MAX_TOKENS
        except (TypeError, ValueError):
            return _DEFAULT_CHRONICLE_MAX_TOKENS

    @staticmethod
    def _resolve_reasoning_effort() -> Optional[str]:
        raw = os.getenv("OPENAI_CHRONICLE_REASONING_EFFORT")
        if raw is None:
            return _DEFAULT_CHRONICLE_REASONING_EFFORT
        effort = raw.strip().lower()
        if effort in _NO_REASONING_SENTINELS:
            return None
        return effort

    def _generate_json(self, system_prompt: str, user_prompt: str) -> Dict[str, Any]:
        kwargs = {
            "model": self._model_name,
            "max_completion_tokens": self._max_tokens,
            "messages": [
                {"role": "system", "content": system_prompt},
                {"role": "user", "content": user_prompt},
            ],
        }
        if self._reasoning_effort is not None:
            kwargs["reasoning_effort"] = self._reasoning_effort

        response = self._client.chat.completions.create(**kwargs)
        choice = (getattr(response, "choices", None) or [None])[0]
        message = getattr(choice, "message", None)
        text = (getattr(message, "content", None) or "").strip()

        if text.startswith("```"):
            lines = text.splitlines()
            text = "\n".join(
                line for line in lines if not line.startswith("```")
            ).strip()

        # strict=False: model-authored summaries carry literal newlines.
        return json.loads(text, strict=False)

    def summarize_chapter(
        self,
        chapter_number: int,
        chapter_text: str,
        character_name: str,
        choice_made_to_start: Optional[str],
        existing_world_facts: List[str],
        existing_unresolved_threads: List[str],
        age: int = 7,
    ) -> Dict[str, Any]:
        """
        Summarize one completed chapter into a compact memory packet.

        Returns a dict matching this schema:
        {
          "summary_bullets": ["...", ...],        # 5-8 bullets
          "new_world_facts": ["..."],              # new canonical facts
          "character_growth": "...",              # single sentence
          "cliffhanger": "...",                   # how the chapter ended
          "new_unresolved_threads": ["..."],      # new open plot threads
          "resolved_threads": ["..."],            # threads closed this chapter
          "character_state_update": {
            "growth": "...",
            "items_gained": ["..."],
            "items_lost": ["..."],
            "relationships": ["..."]
          }
        }
        """
        existing_facts_str = (
            "\n".join(f"- {f}" for f in existing_world_facts)
            if existing_world_facts
            else "None yet."
        )
        existing_threads_str = (
            "\n".join(f"- {t}" for t in existing_unresolved_threads)
            if existing_unresolved_threads
            else "None yet."
        )
        choice_line = (
            f'The reader chose: "{choice_made_to_start}" to begin this chapter.'
            if choice_made_to_start
            else "This was the first chapter."
        )
        if age <= 5:
            vocab_note = (
                "\nIMPORTANT: Write ALL summary_bullets in simple words a 4-year-old understands. "
                "Short sentences. Max 2-syllable words. "
                "Use: went, found, saw, helped, ran, jumped — NOT: traversed, encountered, discovered."
            )
        elif age <= 7:
            vocab_note = (
                "\nWrite summary_bullets in clear, friendly language for a 6-year-old. "
                "Simple sentences. No abstract vocabulary."
            )
        else:
            vocab_note = ""

        prompt = f"""CHAPTER {chapter_number} TEXT FOR CHARACTER "{character_name}":
{chapter_text}

CONTEXT:
{choice_line}

EXISTING WORLD FACTS (already known — only add NEW facts):
{existing_facts_str}

EXISTING UNRESOLVED THREADS (already tracked — identify which are closed, which are new):
{existing_threads_str}
{vocab_note}

Return ONLY valid JSON matching this exact schema:
{{
  "summary_bullets": ["bullet 1", "bullet 2", "bullet 3", "bullet 4", "bullet 5"],
  "new_world_facts": ["fact 1"],
  "character_growth": "One sentence describing how {character_name} changed.",
  "cliffhanger": "The last 1-2 sentences of the chapter or a cliffhanger hook for next time.",
  "new_unresolved_threads": ["new thread 1"],
  "resolved_threads": ["closed thread 1"],
  "character_state_update": {{
    "growth": "One sentence on character growth.",
    "items_gained": ["item 1"],
    "items_lost": [],
    "relationships": ["ally: Name — description"]
  }}
}}"""

        return self._generate_json(self.SUMMARIZE_SYSTEM, prompt)

    def compress_arc(
        self,
        arc_number: int,
        chapter_start: int,
        chapter_end: int,
        chapter_summaries: List[Dict[str, Any]],
        character_name: str,
    ) -> Dict[str, str]:
        """
        Compress 5 chapter summaries into one arc summary paragraph.

        Returns:
        {
          "arc_summary": "Arc N (Ch X-Y): ..."
        }
        """
        summaries_text = ""
        for i, mem in enumerate(chapter_summaries):
            ch_num = chapter_start + i
            bullets = "\n".join(f"  - {b}" for b in (mem.get("summary_bullets") or []))
            summaries_text += f"\nChapter {ch_num}:\n{bullets}\n"

        prompt = f"""CHARACTER: {character_name}
ARC {arc_number} covers Chapters {chapter_start}–{chapter_end}.

CHAPTER SUMMARIES:
{summaries_text}

Return ONLY valid JSON:
{{
  "arc_summary": "Arc {arc_number} (Ch {chapter_start}-{chapter_end}): One paragraph (3-5 sentences) covering key events, choices made, and character growth."
}}"""

        return self._generate_json(self.COMPRESS_SYSTEM, prompt)
