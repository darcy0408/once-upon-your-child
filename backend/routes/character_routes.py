import re

from flask import Blueprint, jsonify, request

from ..database import db
from ..middleware.auth import require_auth, require_parental_consent
from ..models.character import Character
from ..models.parent_hidden_context import ParentHiddenContext
from ..services import character_service
from ..utils.sanitizer import sanitize_for_prompt

# ── Allowlists ──────────────────────────────────────────────────────────────
# Only these exact values are accepted for structured fields.  Anything else
# is rejected at the API boundary so arbitrary text never reaches the prompt.

_ALLOWED_TRIGGERS = frozenset(
    {
        "a limit is set",
        "a sibling conflict starts",
        "a friendship bump happens",
        "nighttime feels uncertain",
        "a transition happens",
        "meltdown when stuck",
    }
)

_ALLOWED_COPING_TOOLS = frozenset(
    {
        "dragon breaths",
        "a quiet pause",
        "asking for help",
        "gentle try-again words",
    }
)

_ALLOWED_REPAIR_GOALS = frozenset(
    {
        "say sorry simply",
        "help fix what happened",
        "use gentle words",
        "try again with warmth",
    }
)

_ALLOWED_FEELINGS = frozenset(
    {
        "frustrated",
        "worried",
        "sad",
        "angry",
        "embarrassed",
    }
)

_ALLOWED_BODY_SIGNALS = frozenset(
    {
        "a hot face",
        "a tight tummy",
        "fast feet and hands",
        "a quick heartbeat",
    }
)

_ALLOWLIST_MAP: dict[str, frozenset[str]] = {
    "trigger": _ALLOWED_TRIGGERS,
    "coping_tool": _ALLOWED_COPING_TOOLS,
    "repair_goal": _ALLOWED_REPAIR_GOALS,
    "feeling": _ALLOWED_FEELINGS,
    "body_signal": _ALLOWED_BODY_SIGNALS,
}

_PARENT_CONTEXT_REQUIRED_FIELDS = ("trigger", "coping_tool", "repair_goal")
_PARENT_CONTEXT_OPTIONAL_FIELDS = ("feeling", "body_signal")


def _contains_disallowed_pii(value: str | None) -> bool:
    if not value:
        return False
    patterns = [
        r"\b[\w.+-]+@[\w.-]+\.[A-Za-z]{2,}\b",
        r"\b(?:\+?1[-.\s]?)?(?:\(?\d{3}\)?[-.\s]?){2}\d{4}\b",
        r"https?://",
    ]
    return any(re.search(pattern, value) for pattern in patterns)


def _validate_allowlisted_field(
    raw: str | None, field: str, max_length: int = 320
) -> tuple[str | None, str | None]:
    """Validate a comma-separated allowlisted field.

    Returns (cleaned_value, error).  cleaned_value is the validated,
    comma-joined string or None.  error is a message if validation fails.
    """
    allowlist = _ALLOWLIST_MAP.get(field)
    if not allowlist or not raw:
        return None, None

    text = sanitize_for_prompt(raw, max_length)
    if not text:
        return None, None

    parts = [p.strip() for p in text.split(",") if p.strip()]
    invalid = [p for p in parts if p not in allowlist]
    if invalid:
        return None, f"{field} contains unrecognised values: {', '.join(invalid[:3])}"

    return ", ".join(parts), None


def _sanitize_parent_hidden_payload(data: dict) -> tuple[dict | None, str | None]:
    sanitized = {}

    # ── Required allowlisted fields ──────────────────────────────────────
    for field in _PARENT_CONTEXT_REQUIRED_FIELDS:
        raw = data.get(field)
        if not raw or not str(raw).strip():
            return None, f"{field} is required"
        value, error = _validate_allowlisted_field(str(raw), field)
        if error:
            return None, error
        if not value:
            return None, f"{field} is required"
        if _contains_disallowed_pii(value):
            return None, f"{field} contains disallowed personal information"
        sanitized[field] = value

    # ── Optional allowlisted fields ──────────────────────────────────────
    for field in _PARENT_CONTEXT_OPTIONAL_FIELDS:
        raw = data.get(field)
        if not raw or not str(raw).strip():
            sanitized[field] = None
            continue
        value, error = _validate_allowlisted_field(str(raw), field)
        if error:
            return None, error
        if value and _contains_disallowed_pii(value):
            return None, f"{field} contains disallowed personal information"
        sanitized[field] = value

    return sanitized, None


def create_character_blueprint(limiter, logger):
    character_bp = Blueprint("character", __name__)

    @limiter.limit("20 per hour")
    @character_bp.route("/create-character", methods=["POST"])
    @require_auth
    @require_parental_consent
    def create_character_endpoint():
        logger.info("POST /create-character called")
        data = request.get_json(silent=True) or {}
        # Enforce user ownership
        data["user_id"] = request.current_user.id

        response, status_code = character_service.create_character(data)
        logger.info(f"Character creation result: {status_code}")
        return jsonify(response), status_code

    @limiter.limit("30 per hour")
    @character_bp.route("/characters/<string:char_id>", methods=["PATCH", "PUT"])
    @require_auth
    @require_parental_consent
    def update_character_endpoint(char_id: str):
        logger.info(f"PATCH/PUT /characters/{char_id} called")

        # Ownership check
        char = db.session.get(Character, char_id)
        if not char:
            return jsonify({"error": "Character not found"}), 404
        if char.user_id and str(char.user_id) != str(request.current_user.id):
            return jsonify({"error": "Unauthorized"}), 403

        data = request.get_json(silent=True) or {}
        response, status_code = character_service.update_character(char_id, data)
        logger.info(f"Character update result: {status_code}")
        return jsonify(response), status_code

    @limiter.limit("10 per hour")
    @character_bp.route("/characters/<string:char_id>", methods=["DELETE"])
    @require_auth
    def delete_character_endpoint(char_id: str):
        logger.info(f"DELETE /characters/{char_id} called")

        # Ownership check
        char = db.session.get(Character, char_id)
        if not char:
            return jsonify({"error": "Character not found"}), 404
        if char.user_id and str(char.user_id) != str(request.current_user.id):
            return jsonify({"error": "Unauthorized"}), 403

        response, status_code = character_service.delete_character(char_id)
        logger.info(f"Character deletion result: {status_code}")
        return jsonify(response), status_code

    @character_bp.route("/get-characters", methods=["GET"])
    @require_auth
    def get_characters_endpoint():
        logger.info("GET /get-characters called")

        # Filter by current user ID at the service/database level
        user_id = request.current_user.id
        response, status_code = character_service.get_characters(user_id=user_id)

        logger.info(f"Get characters result: {status_code}")
        return jsonify(response), status_code

    @character_bp.route("/characters/<string:char_id>", methods=["GET"])
    @require_auth
    def get_character_endpoint(char_id: str):
        logger.info(f"GET /characters/{char_id} called")

        # Ownership check
        char = db.session.get(Character, char_id)
        if not char:
            return jsonify({"error": "Character not found"}), 404
        if char.user_id and str(char.user_id) != str(request.current_user.id):
            return jsonify({"error": "Unauthorized"}), 403

        response, status_code = character_service.get_character(char_id)
        logger.info(f"Get character result: {status_code}")
        return jsonify(response), status_code

    @character_bp.route(
        "/child-profiles/<string:profile_id>/parent-hidden-context", methods=["GET"]
    )
    @require_auth
    def get_parent_hidden_context_endpoint(profile_id: str):
        logger.info(f"GET /child-profiles/{profile_id}/parent-hidden-context called")
        context = ParentHiddenContext.query.filter_by(
            user_id=request.current_user.id,
            child_profile_id=profile_id,
        ).first()
        return (
            jsonify({"parent_hidden_context": context.to_dict() if context else None}),
            200,
        )

    @limiter.limit("20 per hour")
    @character_bp.route(
        "/child-profiles/<string:profile_id>/parent-hidden-context", methods=["PUT"]
    )
    @require_auth
    @require_parental_consent
    def save_parent_hidden_context_endpoint(profile_id: str):
        logger.info(f"PUT /child-profiles/{profile_id}/parent-hidden-context called")
        payload = request.get_json(silent=True) or {}
        sanitized, error = _sanitize_parent_hidden_payload(payload)
        if error:
            return jsonify({"error": error}), 400

        context = ParentHiddenContext.query.filter_by(
            user_id=request.current_user.id,
            child_profile_id=profile_id,
        ).first()
        if context is None:
            context = ParentHiddenContext(
                user_id=request.current_user.id,
                child_profile_id=profile_id,
            )
            db.session.add(context)

        for key, value in sanitized.items():
            setattr(context, key, value)

        db.session.commit()
        return jsonify({"parent_hidden_context": context.to_dict()}), 200

    return character_bp
