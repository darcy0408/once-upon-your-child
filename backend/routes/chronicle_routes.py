"""
Chronicle Routes
Endpoints for Living Story Chronicle: chapter summarization and arc compression.
"""

import logging

from flask import Blueprint, jsonify, request

try:
    from backend.middleware.auth import require_auth, require_parental_consent
    from backend.services.chronicle_prompt_service import ChroniclePromptService
    from backend.utils.sanitizer import (
        _sanitize_model_value,
        sanitize_for_prompt,
        sanitize_model_text,
        scrub_external_links_deep,
    )
except ImportError:
    from middleware.auth import require_auth, require_parental_consent
    from services.chronicle_prompt_service import ChroniclePromptService
    from utils.sanitizer import (
        _sanitize_model_value,
        sanitize_for_prompt,
        sanitize_model_text,
        scrub_external_links_deep,
    )

logger = logging.getLogger(__name__)

MAX_CHAPTER_TEXT = 50000
MAX_NAME = 60
MAX_LINE = 300
MAX_GENERIC = 1200


def _user_key():
    """Rate-limit per signed-in user, not per IP (families share one)."""
    user = getattr(request, "current_user", None)
    return str(user.id) if user else request.remote_addr


def _clean_lines(value) -> list:
    """A list of short model-authored lines coming back from the client."""
    return _sanitize_model_value(value if isinstance(value, list) else [], MAX_LINE)


def _clean_result(result):
    """Model output is stored by the client and replayed into later prompts,
    so it gets the same treatment as any other model-authored memory."""
    return scrub_external_links_deep(_sanitize_model_value(result, MAX_GENERIC))


def create_chronicle_blueprint(limiter) -> Blueprint:
    """Factory function matching the pattern of other blueprints in this app."""

    chronicle_bp = Blueprint("chronicle", __name__)

    @chronicle_bp.route("/chronicle/summarize-chapter", methods=["POST"])
    @require_auth
    @require_parental_consent
    @limiter.limit("20 per minute;150 per day", key_func=_user_key)
    def summarize_chapter():
        """
        Summarize a completed chapter into a compact memory packet.

        Request body:
            chapter_number: int (required)
            chapter_text: str (required) — full concatenated text of the chapter
            character_name: str (required)
            choice_made_to_start: str (optional) — the choice that began this chapter
            existing_world_facts: list[str] (optional)
            existing_unresolved_threads: list[str] (optional)

        Returns: JSON matching ChroniclePromptService.summarize_chapter() schema.
        """
        payload = request.get_json(silent=True) or {}

        chapter_number = payload.get("chapter_number")
        chapter_text = payload.get("chapter_text", "")
        character_name = payload.get("character_name", "Hero")
        choice_made_to_start = payload.get("choice_made_to_start")
        existing_world_facts = payload.get("existing_world_facts") or []
        existing_unresolved_threads = payload.get("existing_unresolved_threads") or []

        if not chapter_number or not chapter_text:
            return (
                jsonify({"error": "chapter_number and chapter_text are required"}),
                400,
            )

        if not isinstance(chapter_text, str):
            return jsonify({"error": "chapter_text must be a string"}), 400
        if len(chapter_text) > MAX_CHAPTER_TEXT:
            return jsonify({"error": "chapter_text too long (max 50000 chars)"}), 400

        # Everything below is interpolated into a prompt, so it is cleaned
        # like every other prompt input: the chapter is model-authored prose
        # round-tripping through the client; the rest are short fields.
        chapter_text = sanitize_model_text(chapter_text, MAX_CHAPTER_TEXT)
        character_name = sanitize_for_prompt(str(character_name), MAX_NAME) or "Hero"
        if choice_made_to_start is not None:
            choice_made_to_start = sanitize_for_prompt(
                str(choice_made_to_start), MAX_LINE
            )
        existing_world_facts = _clean_lines(existing_world_facts)
        existing_unresolved_threads = _clean_lines(existing_unresolved_threads)
        if not chapter_text:
            return jsonify({"error": "chapter_text is required"}), 400

        try:
            service = ChroniclePromptService(user_id=str(request.current_user.id))
            result = service.summarize_chapter(
                chapter_number=int(chapter_number),
                chapter_text=chapter_text,
                character_name=character_name,
                choice_made_to_start=choice_made_to_start,
                existing_world_facts=existing_world_facts,
                existing_unresolved_threads=existing_unresolved_threads,
            )
            return jsonify(_clean_result(result)), 200
        except Exception:
            logger.exception("Chapter summarization failed")
            return jsonify({"error": "Chapter summarization failed"}), 500

    @chronicle_bp.route("/chronicle/compress-arc", methods=["POST"])
    @require_auth
    @require_parental_consent
    @limiter.limit("10 per minute;40 per day", key_func=_user_key)
    def compress_arc():
        """
        Compress 5 chapter memories into one arc summary paragraph.

        Request body:
            arc_number: int (required)
            chapter_start: int (required) — first chapter number in the arc
            chapter_end: int (required) — last chapter number in the arc
            chapter_summaries: list[dict] (required) — list of 5 memory objects,
                each having a "summary_bullets" key (list of strings)
            character_name: str (required)

        Returns: {"arc_summary": "Arc N (Ch X-Y): ..."}
        """
        payload = request.get_json(silent=True) or {}

        arc_number = payload.get("arc_number")
        chapter_start = payload.get("chapter_start")
        chapter_end = payload.get("chapter_end")
        chapter_summaries = payload.get("chapter_summaries") or []
        character_name = payload.get("character_name", "Hero")

        if not arc_number or not chapter_start or not chapter_end:
            return (
                jsonify(
                    {"error": "arc_number, chapter_start, and chapter_end are required"}
                ),
                400,
            )

        if not isinstance(chapter_summaries, list) or len(chapter_summaries) != 5:
            return (
                jsonify({"error": "chapter_summaries must contain exactly 5 entries"}),
                400,
            )

        chapter_summaries = [
            {"summary_bullets": _clean_lines(entry.get("summary_bullets"))}
            for entry in chapter_summaries
            if isinstance(entry, dict)
        ]
        if len(chapter_summaries) != 5:
            return (
                jsonify({"error": "chapter_summaries must contain exactly 5 entries"}),
                400,
            )
        character_name = sanitize_for_prompt(str(character_name), MAX_NAME) or "Hero"

        try:
            service = ChroniclePromptService(user_id=str(request.current_user.id))
            result = service.compress_arc(
                arc_number=int(arc_number),
                chapter_start=int(chapter_start),
                chapter_end=int(chapter_end),
                chapter_summaries=chapter_summaries,
                character_name=character_name,
            )
            return jsonify(_clean_result(result)), 200
        except Exception:
            logger.exception("Arc compression failed")
            return jsonify({"error": "Arc compression failed"}), 500

    return chronicle_bp
