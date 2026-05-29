"""
Chronicle Prompt Service
Builds Gemini prompts for chapter summarization and arc compression.
"""

import json
import logging
import os
from typing import Dict, List, Optional, Any

from google import genai
from google.genai import types

logger = logging.getLogger(__name__)


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

    def __init__(self, gemini_api_key: Optional[str] = None):
        self.api_key = gemini_api_key or os.getenv("GEMINI_API_KEY")
        if not self.api_key:
            raise ValueError("GEMINI_API_KEY not set")
        self._client = genai.Client(api_key=self.api_key)
        self._model_name = os.getenv("GEMINI_MODEL", "gemini-2.5-flash")
        self._json_config = types.GenerateContentConfig(
            response_mime_type="application/json",
            max_output_tokens=1000,
            temperature=0.3,
        )

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
        Call Gemini to summarize one completed chapter.

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

        prompt = f"""{self.SUMMARIZE_SYSTEM}

CHAPTER {chapter_number} TEXT FOR CHARACTER "{character_name}":
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

        response = self._client.models.generate_content(
            model=self._model_name,
            contents=prompt,
            config=self._json_config,
        )
        text = response.text if hasattr(response, "text") else ""
        return json.loads(text)

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
          "arc_summary": "Arc N (Ch X-Y): One paragraph summary..."
        }
        """
        summaries_text = ""
        for i, mem in enumerate(chapter_summaries):
            ch_num = chapter_start + i
            bullets = "\n".join(f"  - {b}" for b in (mem.get("summary_bullets") or []))
            summaries_text += f"\nChapter {ch_num}:\n{bullets}\n"

        prompt = f"""{self.COMPRESS_SYSTEM}

CHARACTER: {character_name}
ARC {arc_number} covers Chapters {chapter_start}–{chapter_end}.

CHAPTER SUMMARIES:
{summaries_text}

Return ONLY valid JSON:
{{
  "arc_summary": "Arc {arc_number} (Ch {chapter_start}-{chapter_end}): One paragraph (3-5 sentences) covering key events, choices made, and character growth."
}}"""

        response = self._client.models.generate_content(
            model=self._model_name,
            contents=prompt,
            config=self._json_config,
        )
        text = response.text if hasattr(response, "text") else ""
        return json.loads(text)
