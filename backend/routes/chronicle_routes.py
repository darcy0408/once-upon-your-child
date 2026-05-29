"""
Chronicle Routes
Endpoints for Living Story Chronicle: chapter summarization and arc compression.
"""

import logging
from flask import Blueprint, jsonify, request

try:
    from backend.middleware.auth import require_auth
    from backend.services.chronicle_prompt_service import ChroniclePromptService
except ImportError:
    from middleware.auth import require_auth
    from services.chronicle_prompt_service import ChroniclePromptService

logger = logging.getLogger(__name__)


def create_chronicle_blueprint(api_key: str, limiter) -> Blueprint:
    """Factory function matching the pattern of other blueprints in this app."""

    chronicle_bp = Blueprint("chronicle", __name__)

    @chronicle_bp.route("/chronicle/summarize-chapter", methods=["POST"])
    @limiter.limit("20 per minute")
    @require_auth
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

        if len(chapter_text) > 50000:
            return jsonify({"error": "chapter_text too long (max 50000 chars)"}), 400

        try:
            service = ChroniclePromptService(gemini_api_key=api_key)
            result = service.summarize_chapter(
                chapter_number=int(chapter_number),
                chapter_text=chapter_text,
                character_name=character_name,
                choice_made_to_start=choice_made_to_start,
                existing_world_facts=existing_world_facts,
                existing_unresolved_threads=existing_unresolved_threads,
            )
            return jsonify(result), 200
        except Exception as e:
            logger.exception("Chapter summarization failed")
            return jsonify({"error": str(e)}), 500

    @chronicle_bp.route("/chronicle/compress-arc", methods=["POST"])
    @limiter.limit("10 per minute")
    @require_auth
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

        if len(chapter_summaries) != 5:
            return (
                jsonify({"error": "chapter_summaries must contain exactly 5 entries"}),
                400,
            )

        try:
            service = ChroniclePromptService(gemini_api_key=api_key)
            result = service.compress_arc(
                arc_number=int(arc_number),
                chapter_start=int(chapter_start),
                chapter_end=int(chapter_end),
                chapter_summaries=chapter_summaries,
                character_name=character_name,
            )
            return jsonify(result), 200
        except Exception as e:
            logger.exception("Arc compression failed")
            return jsonify({"error": str(e)}), 500

    return chronicle_bp
