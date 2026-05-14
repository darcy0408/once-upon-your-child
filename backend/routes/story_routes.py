import base64
from concurrent.futures import ThreadPoolExecutor, TimeoutError as FuturesTimeoutError
import hashlib
import io
import os
import re
import requests
from celery.exceptions import TimeoutError as CeleryTimeoutError
from flask import Blueprint, jsonify, request, g
from PIL import Image

from ..celery_config import celery
from ..gemini_image_generator import GeminiImageGenerator
from ..tasks.story_tasks import generate_story_task
from ..models.user import User
from ..models import Character, ParentHiddenContext
from ..database import db
from ..middleware.auth import require_auth, require_parental_consent
from ..utils.ai_quota import check_daily_quota, increment_daily_quota
from ..utils.audit import audit_log
from ..services.interactive_adventure_service import InteractiveAdventureService
from ..services.story_service import transform_parent_context_to_story_guidance
from ..utils.validators import (
    validate_age,
    validate_num_images,
    validate_image_size,
    validate_story_modes,
    sanitize_text,
)

def _resolve_age(raw_age, default: int = 5) -> int:
    """
    Convert a raw age value from a request payload into a validated integer.

    Rules applied in order:
    1. Parse to int; fall back to *default* on failure.
    2. Clamp to the valid character-age range [2, 120].
    3. If the authenticated user is an under-13 minor (g.minor_age_cap is set),
       cap to their declared age so they cannot request adult-calibrated content
       by submitting a higher age value in the request body.
    """
    try:
        age = max(2, min(120, int(raw_age)))
    except (TypeError, ValueError):
        age = default
    cap = getattr(g, 'minor_age_cap', None)
    if cap is not None:
        age = min(age, cap)
    return age


def _looks_like_base64_image(value: str) -> bool:
    if not isinstance(value, str):
        return False
    stripped = value.strip()
    if stripped.startswith("data:image") or stripped.startswith("http"):
        return False
    if len(stripped) < 200:
        return False
    return re.fullmatch(r"[A-Za-z0-9+/=\s]+", stripped) is not None


def _clean_prompt_value(value):
    if value is None:
        return None
    cleaned = str(value).strip()
    return cleaned or None


def _normalize_feeling_label(label: str | None) -> str | None:
    if not label:
        return None
    lowered = label.strip().lower()
    if lowered in {"mad", "angry"}:
        return "mad"
    if lowered in {"sad"}:
        return "sad"
    if lowered in {"scared", "worried", "anxious"}:
        return "scared"
    if lowered in {"frustrated"}:
        return "frustrated"
    return lowered


def _is_big_feelings_request(payload: dict, theme: str | None = None) -> bool:
    theme_value = (theme or payload.get("theme") or "").strip().lower()
    if theme_value in {
        "big feelings quest",
        "reset and repair",
        "heart helper adventure",
        "after the moment",
    }:
        return True
    return any(
        payload.get(key)
        for key in (
            "current_feeling",
            "feelings_prompt",
            "feelingTrigger",
            "bodySignal",
            "copingTool",
            "repairGoal",
            "child_profile_id",
        )
    )


def _serialize_parent_hidden_context(
    context: ParentHiddenContext | dict | None,
) -> dict | None:
    if context is None:
        return None
    if isinstance(context, ParentHiddenContext):
        return context.to_dict()
    if isinstance(context, dict):
        return {
            "feeling": _clean_prompt_value(context.get("feeling")),
            "trigger": _clean_prompt_value(context.get("trigger")),
            "body_signal": _clean_prompt_value(context.get("body_signal")),
            "coping_tool": _clean_prompt_value(context.get("coping_tool")),
            "repair_goal": _clean_prompt_value(context.get("repair_goal")),
            "parent_hidden_context": _clean_prompt_value(
                context.get("parent_hidden_context")
            ),
        }
    return None


def _resolve_parent_hidden_context(user_id: str, child_profile_id: str | None):
    profile_id = _clean_prompt_value(child_profile_id)
    if not profile_id:
        return None
    return ParentHiddenContext.query.filter_by(
        user_id=user_id,
        child_profile_id=profile_id,
    ).first()


def _merge_big_feelings_context(
    payload_context: dict | None,
    saved_context: ParentHiddenContext | dict | None,
) -> dict | None:
    result = dict(payload_context) if isinstance(payload_context, dict) else {}
    serialized = _serialize_parent_hidden_context(saved_context) or {}
    for key in (
        "feeling",
        "trigger",
        "body_signal",
        "coping_tool",
        "repair_goal",
        "parent_hidden_context",
    ):
        if not _clean_prompt_value(result.get(key)):
            value = _clean_prompt_value(serialized.get(key))
            if value:
                result[key] = value
    return result or None


def _build_feelings_prompt_text(
    payload: dict,
    transformed_guidance: dict | None = None,
) -> str | None:
    current_feeling = payload.get("current_feeling")
    if not isinstance(current_feeling, dict):
        current_feeling = {}

    emotion_name = _clean_prompt_value(current_feeling.get("emotion_name"))
    emotion_description = _clean_prompt_value(current_feeling.get("emotion_description"))
    trigger = (
        _clean_prompt_value(current_feeling.get("what_happened"))
        or _clean_prompt_value(current_feeling.get("trigger"))
        or _clean_prompt_value(payload.get("feelingTrigger"))
        or _clean_prompt_value((transformed_guidance or {}).get("trigger"))
    )
    body_signal = (
        _clean_prompt_value(current_feeling.get("physical_signs"))
        or _clean_prompt_value(payload.get("bodySignal"))
        or _clean_prompt_value((transformed_guidance or {}).get("body_signal"))
    )
    coping_strategies = current_feeling.get("coping_strategies", [])
    coping_tool = _clean_prompt_value(payload.get("copingTool"))
    repair_goal = (
        _clean_prompt_value(current_feeling.get("repair_goal"))
        or _clean_prompt_value(payload.get("repairGoal"))
        or _clean_prompt_value((transformed_guidance or {}).get("repair_goal"))
    )
    story_guidance = _clean_prompt_value((transformed_guidance or {}).get("story_guidance"))
    age = payload.get("age") or payload.get("character_age") or 5

    if not emotion_name:
        emotion_name = _clean_prompt_value((transformed_guidance or {}).get("feeling"))
    if not emotion_name and story_guidance:
        emotion_name = "big feelings"
    if not emotion_name:
        return payload.get("feelings_prompt")

    coping_lines = []
    if isinstance(coping_strategies, list):
        coping_lines.extend(
            str(strategy).strip()
            for strategy in coping_strategies
            if str(strategy).strip()
        )
    if coping_tool and coping_tool not in coping_lines:
        coping_lines.insert(0, coping_tool)

    feeling_label = _normalize_feeling_label(emotion_name) or emotion_name.lower()
    opening_example = f"The hero felt so {feeling_label}."
    if trigger:
        opening_example = f"The hero felt so {feeling_label} when {trigger.lower()}."

    lines = [
        "BIG FEELINGS STORY SETUP:",
        f"- Feeling: {emotion_name}",
    ]
    if emotion_description:
        lines.append(f"- Feeling meaning: {emotion_description}")
    if trigger:
        lines.append(f"- What happened: {trigger}")
    if body_signal:
        lines.append(f"- Body clue: {body_signal}")
    if coping_lines:
        lines.append(f"- Helper to model: {', '.join(coping_lines)}")
    if repair_goal:
        lines.append(f"- Repair beat to include: {repair_goal}")
    if story_guidance:
        lines.append(f"- Parent-guided story scaffolding: {story_guidance}")

    numeric_age = _resolve_age(age)

    lines.append("")
    lines.append("STORY RULES:")

    if numeric_age >= 15:
        # Adolescent / Adult — mature emotional register
        lines.extend([
            f"1. Open with the feeling already present in the character's body or thoughts — not announced like a lesson.",
            "2. Keep the stakes life-sized — real relationships, real consequences, real ambiguity.",
            "3. Honour the feeling without rushing to resolve it; complexity and contradiction are valid.",
            "4. Show the body clue somatically and specifically — not as a diagram but as lived experience.",
            "5. The coping gesture is a starting point, not a solution; it may land imperfectly or only partially help.",
            "6. End with integration, not resolution — the feeling can still be present at the close; a character who has simply named and held something difficult is enough.",
            "7. Never moralise or summarise the emotional lesson. The story IS the lesson.",
        ])
    else:
        lines.extend([
            f"1. Open by naming the feeling in the first lines, like: \"{opening_example}\"",
            "2. Keep the problem child-sized and concrete.",
            "3. Validate the feeling without shaming it or trying to erase it.",
            "4. Show the body clue early and naturally.",
            "5. Let the helper action change what happens next.",
            "6. If the hero makes a messy choice, include a gentle repair and reconnect moment.",
        ])
        if numeric_age <= 5:
            lines.extend([
                "7. Use very simple feeling words: mad, sad, scared, frustrated.",
                "8. Use short concrete sentences and warm reassuring imagery only.",
            ])

    return "\n".join(lines)


def _augment_therapeutic_prompt(
    payload: dict,
    base_prompt: str,
    transformed_guidance: dict | None = None,
) -> str:
    parts = [base_prompt.strip()] if isinstance(base_prompt, str) and base_prompt.strip() else []

    current_feeling = payload.get("current_feeling")
    if isinstance(current_feeling, dict):
        emotion_name = _clean_prompt_value(current_feeling.get("emotion_name"))
        normalized = _normalize_feeling_label(emotion_name)
        if normalized == "mad":
            parts.append("Emotion focus: anger and calming without shame.")
        elif normalized == "scared":
            parts.append("Emotion focus: fear/anxiety and feeling safe enough to take one small step.")
        elif normalized == "sad":
            parts.append("Emotion focus: sadness, comfort, and connection.")
        elif normalized == "frustrated":
            parts.append("Emotion focus: frustration, trying again, and asking for help.")

    guidance_line = _clean_prompt_value((transformed_guidance or {}).get("story_guidance"))
    if guidance_line:
        parts.append(f"Parent-guided Big Feelings scaffolding: {guidance_line}")

    return " | ".join(parts)


def _run_sync_story_task_with_timeout(task_kwargs, sync_story_timeout):
    executor = ThreadPoolExecutor(max_workers=1)
    # Important: use current generate_story_task which might be mocked in tests
    future = executor.submit(generate_story_task.apply, kwargs=task_kwargs)
    try:
        eager_result = future.result(timeout=sync_story_timeout)
        return eager_result.get()
    finally:
        executor.shutdown(wait=False, cancel_futures=True)


def _celery_runs_eagerly() -> bool:
    try:
        return bool(getattr(celery.conf, "task_always_eager", False))
    except Exception:
        return False


def _cache_task_owner(cache, task_id: str, user_id: str) -> None:
    if not task_id or not user_id:
        return
    try:
        cache.set(f"task-owner:{task_id}", str(user_id), timeout=60 * 60 * 24)
    except Exception:
        logger.warning("Failed to cache task owner for %s", task_id, exc_info=True)


def _resolve_task_owner(cache, task_id: str, task) -> str | None:
    if not task_id:
        return None

    try:
        cached_owner = cache.get(f"task-owner:{task_id}")
    except Exception:
        cached_owner = None

    if cached_owner:
        return str(cached_owner)

    info = getattr(task, "info", None)
    if isinstance(info, dict) and info.get("user_id"):
        return str(info["user_id"])

    result = getattr(task, "result", None)
    if isinstance(result, dict) and result.get("user_id"):
        return str(result["user_id"])

    return None


def create_story_blueprint(
    limiter,
    cache,
    story_engine_instance,
    model,
    image_generator,
    api_key: str,
    gemini_model: str,
    log_error,
    filter_story_content,
    get_tier_limits,
    track_cost,
    is_production_fn,
    logger,
):
    story_bp = Blueprint("story", __name__)
    disable_gemini_image = os.getenv("DISABLE_GEMINI_IMAGE", "").strip().lower() in ("1", "true", "yes")
    sync_story_timeout = int(os.getenv("SYNC_STORY_TIMEOUT_SECONDS", "120"))

    @story_bp.route("/get-story-themes", methods=["GET"])
    @limiter.limit("60 per minute")
    @cache.cached(timeout=3600)  # Cache for 1 hour
    def get_story_themes():
        return jsonify(
            [
                "Adventure",
                "Friendship",
                "Magic",
                "Dragons",
                "Castles",
                "Unicorns",
                "Space",
                "Ocean",
            ]
        )

    @story_bp.route("/generate-story", methods=["POST"])
    @require_auth
    @require_parental_consent
    @limiter.limit(lambda: get_tier_limits() or "1000/minute")  # BYOK users get high limit
    def generate_story_endpoint():
        from ..utils.sanitizer import sanitize_story_request
        payload = request.get_json(silent=True) or {}
        payload = sanitize_story_request(payload)

        # Validate mode combinations before processing
        is_valid, mode_error = validate_story_modes(payload)
        if not is_valid:
            return jsonify(mode_error), 400

        theme = payload.get("theme") or "Adventure"
        # Enforce authenticated user ID
        user_id = request.current_user.id
        user_tier = getattr(request.current_user, 'subscription_tier', 'free') or 'free'

        # Daily AI generation quota — circuit breaker against unbounded Gemini spend.
        allowed, current_count, daily_limit = check_daily_quota(user_id, user_tier)
        if not allowed:
            audit_log('ai_quota_exceeded', user_id=user_id, data={'tier': user_tier, 'count': current_count, 'limit': daily_limit})
            return jsonify({
                "error": "Daily story limit reached",
                "code": "QUOTA_EXCEEDED",
                "limit": daily_limit,
                "used": current_count,
                "message": "You've reached your story limit for today. Come back tomorrow!",
            }), 429

        # Validate character ownership
        character_id = payload.get("character_id")
        if character_id:
            char = db.session.get(Character, character_id)
            if not char:
                return jsonify({"error": "Character not found"}), 404
            if char.user_id and str(char.user_id) != str(user_id):
                logger.warning(f"IDOR attempt: User {user_id} tried to generate story for character {character_id}")
                return jsonify({"error": "Unauthorized"}), 403

        if not character_id and not payload.get("character"):
            return jsonify({"error": "character_id or character is required"}), 400

        saved_parent_context = None
        transformed_parent_guidance = None
        if _is_big_feelings_request(payload, theme):
            saved_parent_context = _resolve_parent_hidden_context(
                user_id,
                payload.get("child_profile_id"),
            )
            transformed_parent_guidance = transform_parent_context_to_story_guidance(
                _serialize_parent_hidden_context(saved_parent_context)
            )

        # Extract current_feeling and convert to feelings_prompt if provided
        feelings_prompt_text = _build_feelings_prompt_text(
            payload,
            transformed_parent_guidance,
        )

        # Extract character_details to get additional_characters if available
        character_details = payload.get("character_details") or {}
        additional_chars = payload.get("additional_characters") or character_details.get("additionalCharacters")

        # Extract companion data (new structured format)
        companion_pets = payload.get("companion_pets", [])
        companion_characters = payload.get("companion_characters", [])

        # Accept multiple age keys for backward compatibility with older clients.
        resolved_age = payload.get("age")
        if resolved_age is None:
            resolved_age = payload.get("character_age")
        if resolved_age is None and isinstance(character_details, dict):
            resolved_age = character_details.get("age")
        if resolved_age is None:
            resolved_age = 5

        # Reject ages that are clearly out of range before any clamping.
        # Valid range: 2–120. Anything outside is a bad request, not a silent clamp.
        try:
            raw_age_int = int(resolved_age)
            if not (2 <= raw_age_int <= 120):
                return jsonify({"error": "age must be between 2 and 120"}), 400
        except (TypeError, ValueError):
            return jsonify({"error": "age must be a valid integer"}), 400

        resolved_age = _resolve_age(resolved_age)

        task_kwargs = {
            "character_id": payload.get("character_id"),
            "character": payload.get("character"),
            "character_details": character_details,
            "theme": theme,
            "user_id": user_id,
            "include_illustrations": payload.get("include_illustrations", False),
            "async_illustrations": payload.get("async_illustrations", False),
            "rhyme_time_mode": payload.get("rhyme_time_mode", False),
            "learning_to_read_mode": payload.get("learning_to_read_mode", False),
            "bedtime_mode": payload.get("bedtime_mode", False),
            "bedtime_mood": payload.get("bedtime_mood", "calming"),
            "companion": payload.get("companion") or payload.get("companion_name"),  # Legacy support
            "companion_pets": companion_pets,  # NEW: List of pet companions with species
            "companion_characters": companion_characters,  # NEW: List of character companions
            "spark_tool": payload.get("sparkTool"), # NEW: Spark Tool
            "mood_physics": payload.get("moodPhysics"), # NEW: Mood Physics
            "conflict_hook": payload.get("conflictHook"), # NEW: Plot Driver
            "sensory_palette": payload.get("sensoryPalette"), # NEW: Atmosphere
            "world_bible": payload.get("worldBible", ""), # World consistency guide
            "custom_elements": payload.get("customElements", ""), # NEW: Free-form custom story requests
            "therapeutic_prompt": _augment_therapeutic_prompt(
                payload,
                payload.get("therapeutic_prompt", ""),
                transformed_parent_guidance,
            ),
            "feelings_prompt": feelings_prompt_text or payload.get("feelings_prompt"),
            "story_length": payload.get("story_length", "standard"),
            "bedtime_duration_minutes": payload.get("bedtime_duration_minutes"),
            "age": resolved_age,
            # Superhero Mode (ages 3-5) fields — only meaningful when
            # theme == 'superhero'. Other modes ignore them.
            "hero_costume_color": payload.get("hero_costume_color"),
            "hero_cape_style": payload.get("hero_cape_style"),
            "hero_emblem": payload.get("hero_emblem"),
            "hero_power": payload.get("hero_power"),
            "recent_villains": payload.get("recent_villains") or [],
            "recent_problems": payload.get("recent_problems") or [],
        }

        # If async mode is requested, disable inline illustrations but pass the flag
        if task_kwargs.get("async_illustrations"):
            task_kwargs["include_illustrations"] = False
            logger.info("Async illustrations enabled - skipping inline generation")

        # Try synchronous execution first (to bypass polling issues on Railway)
        try:
            # Run synchronous task in a bounded worker thread so timeout is enforced.
            sync_result = _run_sync_story_task_with_timeout(task_kwargs, sync_story_timeout)

            # Debugging: Log the result type
            logger.info(f"Sync task result type: {type(sync_result)}")
            if isinstance(sync_result, str):
                logger.error(f"Sync task returned string instead of dict: {sync_result[:200]}...")
                raise Exception(f"Task returned invalid format (str): {sync_result}")

            # Extract story payload from the task result
            story_payload = (sync_result or {}).get("story", {})
            if not story_payload:
                 story_payload = (sync_result or {}).get("story_text", {})

            response_payload = {
                "status": sync_result.get("status", "complete"),
                "story": story_payload,
                "task_id": "sync_task", # No task ID needed
                "async_illustrations": payload.get("async_illustrations", False),
            }
            increment_daily_quota(user_id, user_tier)
            audit_log('story_generated', user_id=user_id, data={'tier': user_tier, 'mode': 'sync'})
            return jsonify(response_payload), 200

        except (FuturesTimeoutError, CeleryTimeoutError) as exc:
            logger.warning(
                "Synchronous story generation timed out after %ss, switching to async fallback.",
                sync_story_timeout,
            )
            logger.error(f"Full task_kwargs that timed out: {task_kwargs}")
            if _celery_runs_eagerly():
                logger.warning(
                    "Celery task_always_eager is enabled; async fallback would still block. Returning timeout response."
                )
                return (
                    jsonify(
                        {
                            "error": "STORY_TIMEOUT",
                            "message": "Story generation took too long. Please try again.",
                        }
                    ),
                    504,
                )
            try:
                task = generate_story_task.delay(**task_kwargs)
                _cache_task_owner(cache, task.id, user_id)
                return (
                    jsonify(
                        {
                            "task_id": task.id,
                            "status": "processing",
                            "message": "Story generation timed out in sync mode; switched to async processing.",
                            "poll_url": f"/task-status/{task.id}",
                        }
                    ),
                    202,
                )
            except Exception as async_exc:
                logger.exception("Async fallback after sync timeout also failed: %s", async_exc)
                return jsonify({"error": "STORY_TIMEOUT", "message": "Story generation took too long. Please try again."}), 500

        except Exception as exc:
            import traceback
            error_trace = traceback.format_exc()
            logger.exception("Synchronous story generation failed, attempting async fallback: %s", exc)

            # Write error to file for debugging
            try:
                with open("backend_last_error.log", "w") as f:
                    f.write(error_trace)
            except Exception:
                pass

            if "429" in str(exc) or "ResourceExhausted" in str(exc) or "Quota exceeded" in str(exc):
                logger.warning(f"Quota exceeded in sync generation: {exc}")
                return jsonify({"error": "QUOTA_EXCEEDED", "message": "Google Gemini API quota exceeded. Please try again later."}), 429

            logger.error(f"Full task_kwargs that failed: {task_kwargs}")
            if _celery_runs_eagerly():
                logger.warning(
                    "Celery task_always_eager is enabled; async fallback would still block. Returning error response."
                )
                return jsonify(
                    {
                        "error": "STORY_FAILED",
                        "message": "Something went wrong generating your story. Please try again.",
                    }
                ), 500
            try:
                task = generate_story_task.delay(**task_kwargs)
                _cache_task_owner(cache, task.id, user_id)
                return (
                    jsonify(
                        {
                            "task_id": task.id,
                            "status": "processing",
                            "message": "Story generation started (Async fallback)",
                            "poll_url": f"/task-status/{task.id}",
                        }
                    ),
                    202,
                )
            except Exception as async_exc:
                if "429" in str(async_exc) or "ResourceExhausted" in str(async_exc) or "Quota exceeded" in str(async_exc):
                     logger.warning(f"Quota exceeded in async generation: {async_exc}")
                     return jsonify({"error": "QUOTA_EXCEEDED", "message": "Google Gemini API quota exceeded. Please try again later."}), 429

                logger.exception("Async fallback also failed: %s", async_exc)
                # Last resort: retry synchronously before giving up entirely
                logger.warning("Retrying synchronous story generation after async failure")
                try:
                    sync_result = _run_sync_story_task_with_timeout(task_kwargs, sync_story_timeout)
                    story_payload = (sync_result or {}).get("story", {})
                    response_payload = {
                        "status": sync_result.get("status", "complete"),
                        "title": story_payload.get("title"),
                        "story": story_payload.get("story_text"),
                        "story_text": story_payload.get("story_text"),
                        "task_id": None,
                        "theme": story_payload.get("theme"),
                        "wisdom_gem": story_payload.get("wisdom_gem"),
                        "async_illustrations": payload.get("async_illustrations", False),
                    }
                    audit_log('story_generated', user_id=user_id, data={'tier': user_tier, 'mode': 'async_fallback'})
                    return jsonify(response_payload), 200
                except Exception as fallback_exc:
                    logger.exception("Synchronous retry also failed: %s", fallback_exc)
                    return jsonify({"error": "STORY_FAILED", "message": "Something went wrong generating your story. Please try again."}), 500

    @story_bp.route("/generate-story-mock", methods=["POST"])
    def generate_story_mock_endpoint():
        """
        A mock endpoint for development and UI testing.
        Returns a static story instantly without calling any AI model.
        Disabled in production.
        """
        # Gate: disable in production
        if is_production_fn():
            return jsonify({"error": "Not available in production"}), 404

        logger.info("Serving mock story for testing.")
        payload = request.get_json(silent=True) or {}
        character = payload.get("character", {})

        # Handle character being either a dict or a string
        if isinstance(character, dict):
            character_name = character.get("name", "a brave hero")
        else:
            character_name = str(character) if character else "a brave hero"

        theme = payload.get("theme", "Friendship")

        mock_story = {
            "status": "complete",
            "result": {
                "status": "complete",
                "story": {
                    "id": "mock-story-12345",
                    "title": f"The Mock Adventure of {character_name}",
                    "story_text": f"This is a sample story about {character_name} and a grand adventure about {theme.lower()}. In a land of pixels and placeholders, our hero discovered that the best treasure is a good friend. They met a friendly dragon who, instead of breathing fire, brewed the best tea in the kingdom. Together, they shared stories and laughed until the sun set, painting the sky in shades of orange and purple.",
                    "theme": theme,
                    "wisdom_gem": "A shared cup of tea is better than a lonely treasure.",
                    "include_illustrations": payload.get("include_illustrations", False),
                    "rhyme_time_mode": payload.get("rhyme_time_mode", False),
                    "learning_to_read_mode": payload.get("learning_to_read_mode", False),
                }
            }
        }
        # The frontend expects the result of the task, not the task object itself
        return jsonify(mock_story), 200


    @story_bp.route("/task-status/<task_id>", methods=["GET"])
    @require_auth
    def get_task_status(task_id):
        task = celery.AsyncResult(task_id)
        task_owner_id = _resolve_task_owner(cache, task_id, task)

        # Security: verify resource ownership
        if task_owner_id and str(task_owner_id) != str(request.current_user.id):
            logger.warning(
                "IDOR attempt: User %s tried to access task %s owned by %s",
                request.current_user.id,
                task_id,
                task_owner_id,
            )
            return jsonify({"error": "Access denied"}), 403

        if task_owner_id is None and task.state in {"PENDING", "PROCESSING"}:
            logger.warning(
                "Task %s has no owner metadata; refusing to disclose state to user %s",
                task_id,
                request.current_user.id,
            )
            return jsonify({"error": "Task not found"}), 404

        if task.state == "PENDING":
            response = {
                "status": "pending",
                "message": "Task is waiting to start",
            }
        elif task.state == "PROCESSING":
            meta = task.info or {}
            status_message = meta.get("status") if isinstance(meta, dict) else str(meta)
            response = {
                "status": "processing",
                "message": status_message or "Generating story...",
            }
        elif task.state == "SUCCESS":
            result = task.result or {}
            response = {
                "status": "complete",
                "result": result,
            }
        elif task.state == "FAILURE":
            response = {
                "status": "failed",
                "error": str(task.info),
            }
        else:
            response = {
                "status": (task.state or "unknown").lower(),
                "message": f"Task state: {task.state}",
            }

        return jsonify(response), 200

    @story_bp.route("/generate-interactive-story", methods=["POST"])
    @limiter.limit("5 per minute")  # Rate limit for interactive story start
    @require_auth
    @require_parental_consent
    def generate_interactive_story_endpoint():
        """
        Create new interactive adventure story with first segment.
        Request body:
            - character_id: str (optional)
            - theme: str (Adventure, Magic, Dragons, etc.)
            - tone: str (whimsical, mystery, sci-fi, fantasy, cozy-adventure)
            - length: str (short, medium, long)
            - age: int (optional, overrides character age)
            - interests: list[str] (optional)
            - must_include: list[str] (optional)
            - avoid: list[str] (optional)
        """
        logger.info("POST /generate-interactive-story called")
        payload = request.get_json(silent=True) or {}

        # Mark as interactive for validation
        payload["interactive"] = True

        # Validate mode combinations (interactive + rhymes = invalid)
        is_valid, mode_error = validate_story_modes(payload)
        if not is_valid:
            return jsonify(mode_error), 400

        # Enforce authenticated user ID
        user_id = request.current_user.id
        
        character_id = payload.get("character_id")

        # Validate character ownership
        if character_id:
            char = db.session.get(Character, character_id)
            if not char:
                return jsonify({"error": "Character not found"}), 404
            if char.user_id and str(char.user_id) != str(user_id):
                logger.warning(f"IDOR attempt: User {user_id} tried to generate interactive story for character {character_id}")
                return jsonify({"error": "Unauthorized"}), 403

        theme = payload.get("theme", "Adventure")
        tone = payload.get("tone", "whimsical")
        length = payload.get("length", "medium")
        age = _resolve_age(payload.get("age"))
        interests = payload.get("interests")
        must_include = payload.get("must_include")
        avoid = payload.get("avoid")
        life_challenge = payload.get("life_challenge")
        personality_sliders = payload.get("personality_sliders")
        world_bible = payload.get("worldBible", "")
        conflict_hook = payload.get("conflictHook", "")
        sensory_palette = payload.get("sensoryPalette", "")
        chronicle_context = payload.get("chronicle_context")
        big_feelings_context = payload.get("big_feelings_context")
        companions_payload = payload.get("companions") or []
        character_name = payload.get("character_name")
        if isinstance(big_feelings_context, dict):
            saved_parent_context = _resolve_parent_hidden_context(
                user_id,
                big_feelings_context.get("child_profile_id"),
            )
            big_feelings_context = _merge_big_feelings_context(
                big_feelings_context,
                saved_parent_context,
            )

        try:
            # Initialize service
            service = InteractiveAdventureService(gemini_api_key=api_key)

            # Create story
            result = service.create_story(
                user_id=user_id,
                character_id=character_id,
                theme=theme,
                tone=tone,
                length=length,
                age=age,
                interests=interests,
                must_include=must_include,
                avoid=avoid,
                life_challenge=life_challenge,
                personality_sliders=personality_sliders,
                world_bible=world_bible,
                conflict_hook=conflict_hook,
                sensory_palette=sensory_palette,
                chronicle_context=chronicle_context,
                big_feelings_context=big_feelings_context,
                companions_payload=companions_payload or None,
                character_name=character_name,
            )

            # Filter content
            segment_content = result['segment']['content']
            filtered_content, flagged = filter_story_content(segment_content, age)
            result['segment']['content'] = filtered_content

            if flagged:
                logger.warning("Interactive story opening flagged by content filter")

            logger.info(f"Interactive story created: {result['story_id']}")
            return jsonify(result), 200

        except Exception as e:
            log_error(
                error_type="interactive_story_generation_failed",
                message=str(e),
                details={
                    "user_id": user_id,
                    "character_id": character_id,
                    "theme": theme,
                    "error_class": e.__class__.__name__,
                },
            )
            logger.exception("Interactive story generation failed")
            return jsonify(
                {
                    "error": str(e),
                    "hint": "Interactive story generation failed on the backend.",
                }
            ), 500

    @story_bp.route("/continue-interactive-story", methods=["POST"])
    @limiter.limit("5 per minute")  # Rate limit for continuing interactive stories
    @require_auth
    @require_parental_consent
    def continue_interactive_story_endpoint():
        """
        Continue interactive story based on choice selection.
        Request body:
            - story_id: str (required)
            - choice_id: str (required) — use "custom" to submit free-text input
            - custom_text: str (optional) — required when choice_id is "custom"; max 200 chars
        """
        logger.info("POST /continue-interactive-story called")
        payload = request.get_json(silent=True) or {}

        story_id = payload.get("story_id")
        choice_id = payload.get("choice_id")
        custom_text = (payload.get("custom_text") or "").strip()[:200]

        # Validate required fields
        if not story_id or not choice_id:
            return jsonify({"error": "story_id and choice_id are required"}), 400

        if choice_id == "custom" and not custom_text:
            return jsonify({"error": "custom_text is required when choice_id is 'custom'"}), 400

        try:
            from backend.models import InteractiveStory
            
            # Ownership check
            story = db.session.get(InteractiveStory, story_id)
            if not story:
                return jsonify({"error": f"Story {story_id} not found"}), 404
            
            if str(story.user_id) != str(request.current_user.id):
                logger.warning(f"IDOR attempt: User {request.current_user.id} tried to continue story {story_id}")
                return jsonify({"error": "Access denied"}), 403

            # Initialize service
            service = InteractiveAdventureService(gemini_api_key=api_key)

            # Continue story — pass custom_text so the service can use it
            result = service.continue_story(
                story_id=story_id,
                choice_id=choice_id,
                custom_text=custom_text or None
            )

            # Filter content — use story's age if available, fall back to 5
            story_age = getattr(story, 'age', None) or 5
            segment_content = result['segment']['content']
            filtered_content, flagged = filter_story_content(segment_content, story_age)
            result['segment']['content'] = filtered_content

            if flagged:
                logger.warning("Interactive continuation flagged by content filter")

            logger.info(f"Story {story_id} continued to segment {result['segment']['segment_number']}")
            return jsonify(result), 200

        except ValueError as e:
            logger.warning(f"Invalid request: {e}")
            return jsonify({"error": str(e)}), 404

        except Exception as e:
            logger.exception("Continuing interactive story failed")
            log_error(
                error_type="interactive_story_continuation_failed",
                message=str(e),
                details={
                    "story_id": story_id,
                    "choice_id": choice_id,
                    "is_custom_choice": choice_id == "custom",
                    "error_class": e.__class__.__name__,
                },
            )
            return jsonify(
                {
                    "error": str(e),
                    "hint": "Continuing interactive story failed on the backend.",
                }
            ), 500

    @story_bp.route("/interactive-story/<story_id>", methods=["GET"])
    @require_auth
    def get_interactive_story(story_id):
        """
        Get full interactive story with all segments and current state.
        """
        logger.info(f"GET /interactive-story/{story_id} called")

        try:
            from backend.models import InteractiveStory
            
            # Ownership check
            story = db.session.get(InteractiveStory, story_id)
            if not story:
                return jsonify({"error": f"Story {story_id} not found"}), 404
            
            if str(story.user_id) != str(request.current_user.id):
                logger.warning(f"IDOR attempt: User {request.current_user.id} tried to read story {story_id}")
                return jsonify({"error": "Access denied"}), 403

            # Initialize service
            service = InteractiveAdventureService(gemini_api_key=api_key)

            # Get story
            result = service.get_story(story_id)

            return jsonify(result), 200

        except ValueError as e:
            logger.warning(f"Story not found: {e}")
            return jsonify({"error": str(e)}), 404

        except Exception as e:
            logger.exception("Getting interactive story failed")
            return jsonify({"error": str(e)}), 500

    @story_bp.route("/interactive-story/<story_id>/resume", methods=["GET"])
    @require_auth
    def resume_interactive_story(story_id):
        """
        Resume an in-progress story from current segment.
        Returns current segment, inventory, and state.
        """
        logger.info(f"GET /interactive-story/{story_id}/resume called")

        try:
            from backend.models import InteractiveStory

            # Load story
            story = db.session.get(InteractiveStory, story_id)
            if not story:
                return jsonify({"error": f"Story {story_id} not found"}), 404

            # Ownership check
            if str(story.user_id) != str(request.current_user.id):
                logger.warning(f"IDOR attempt: User {request.current_user.id} tried to resume story {story_id}")
                return jsonify({"error": "Access denied"}), 403

            if story.is_completed:
                return jsonify({"error": "Story is already completed"}), 400

            # Get current segment
            current_segment = story.segments.filter_by(
                id=story.current_segment_id
            ).first()

            if not current_segment:
                return jsonify({"error": "Current segment not found"}), 404

            result = {
                'story_id': story.id,
                'title': story.title,
                'current_segment_number': story.current_segment_number,
                'segment': current_segment.to_dict(),
                'inventory': [item.to_dict() for item in story.inventory.filter_by(is_active=True).all()],
                'state': story.state.to_dict() if story.state else None,
                'is_completed': story.is_completed
            }

            return jsonify(result), 200

        except Exception as e:
            logger.exception("Resuming interactive story failed")
            return jsonify({"error": str(e)}), 500

    @story_bp.route("/report-story", methods=["POST"])
    @limiter.limit("5 per hour")
    def report_story():
        """Allow users to report inappropriate content."""
        data = request.get_json(silent=True) or {}
        story_id = data.get("story_id") or data.get("id") or "unknown"
        reason = (data.get("reason") or "").strip() or "No reason provided"
        snippet = (data.get("story_preview") or "")[:200]

        logger.warning(f"⚠️ CONTENT REPORT - Story ID: {story_id}, Reason: {reason}, Preview: {snippet}")

        return jsonify({"status": "reported", "message": "Thank you for your report"}), 200

    @story_bp.route("/generate-illustrations", methods=["POST"])
    @require_auth
    @require_parental_consent
    @limiter.limit(lambda: get_tier_limits("expensive") or "100/hour")  # BYOK users get high limit
    def generate_illustrations_endpoint():
        """Generate illustrations for a story scene"""
        try:
            data = request.get_json(silent=True) or {}
            scene_description = sanitize_text(data.get("scene_description", ""), max_length=2000, allow_newlines=True)
            character_name = sanitize_text(data.get("character_name", "the hero"), max_length=100)
            style = sanitize_text(data.get("style", "children's book illustration"), max_length=200)
            num_images = validate_num_images(data.get("num_images", 1), max_allowed=4)
            try:
                age = validate_age(data.get("age", 7))
            except ValueError:
                age = 7  # Default to 7 if invalid
            therapeutic_focus = sanitize_text(data.get("therapeutic_focus", ""), max_length=500) or None
            user_api_key = data.get("user_api_key")  # BYOK support

            # MT-107: Optional power_id triggers per-power visual signature in
            # the prompt (e.g., feeling_sense → empathy halo, invisibility →
            # wisp-edged silhouette). Frontend may send either key.
            power_id = data.get("power_id") or data.get("hero_power")
            if power_id is not None:
                power_id = sanitize_text(str(power_id), max_length=64) or None

            # Get character appearance/avatar details
            character_appearance = data.get("character_appearance") or data.get("appearance")

            # Get companions (could be magical companions, pets, or friends)
            companions = data.get("companions") or data.get("companion_pets") or []

            if not scene_description.strip():
                return jsonify({"error": "Scene description is required"}), 400

            # Use user's API key if provided, otherwise use the hybrid pipeline.
            # MT-084 hybrid routing for per-page illustrations:
            #   - Sprout (age <=5):  Gemini-via-OpenRouter (preserves warm 3D Pixar style)
            #   - Ages 6+:           Flux Schnell ($0.003/img) primary, Gemini fallback
            # BYOK users always use their own Gemini key regardless of age.
            # See docs/IMAGE_GEN_AB_TEST_RESULTS.md for the visual scoring + cost math.
            generator = None
            using_user_key = False
            using_flux_schnell = False
            current_user = getattr(request, 'current_user', None)
            current_user_id = getattr(current_user, 'id', None) if current_user else None

            if user_api_key and not disable_gemini_image:
                generator = GeminiImageGenerator(api_key=user_api_key)
                using_user_key = True
            elif user_api_key and disable_gemini_image:
                logger.info("DISABLE_GEMINI_IMAGE active; ignoring user_api_key for illustrations.")

            illustrations = []
            quota_exhausted = False
            quota_used = 0
            quota_limit = 0
            if generator is not None:
                # BYOK path — direct Gemini with the user's key.
                # BYOK is not server-cost-metered (user pays Google).
                illustrations = generator.generate_story_illustration(
                    scene_description=scene_description,
                    character_name=character_name,
                    style=style,
                    num_images=num_images,
                    age=age,
                    therapeutic_focus=therapeutic_focus,
                    character_appearance=character_appearance,
                    companions=companions,
                    power_id=power_id,
                )
            else:
                # Server-key path — ages 6+ non-BYOK is metered against the
                # monthly illustration quota (Sprout remains unmetered since
                # per-page art is essential to that band's UX and the cost is
                # capped naturally by Sprout's small page counts).
                if age >= 6 and current_user_id:
                    try:
                        from ..utils.ai_quota import check_illustration_quota
                    except ImportError:
                        from utils.ai_quota import check_illustration_quota
                    user_tier = getattr(current_user, 'subscription_tier', 'free') or 'free'
                    allowed, quota_used, quota_limit = check_illustration_quota(
                        current_user_id, user_tier.lower(), num_images,
                    )
                    if not allowed:
                        quota_exhausted = True
                        logger.info(
                            "Illustration quota exhausted for user=%s tier=%s used=%d/%d",
                            current_user_id, user_tier, quota_used, quota_limit,
                        )

                if quota_exhausted:
                    return (
                        jsonify({
                            "illustrations": [],
                            "count": 0,
                            "code": "ILLUSTRATION_QUOTA_EXCEEDED",
                            "quota_used": quota_used,
                            "quota_limit": quota_limit,
                            "message": (
                                "You've used all your free illustrations this month. "
                                "Upgrade for more, or wait until next month."
                            ),
                        }),
                        200,
                    )

                # Hybrid routing by age band.
                if age >= 6 and os.getenv("FLUX_SCHNELL_DISABLED", "").lower() not in ("1", "true", "yes"):
                    try:
                        from ..replicate_image_generator import ReplicateImageGenerator
                    except ImportError:
                        from replicate_image_generator import ReplicateImageGenerator
                    flux = ReplicateImageGenerator()
                    illustrations = flux.generate_story_illustration_flux_schnell(
                        scene_description=scene_description,
                        character_name=character_name,
                        style=style,
                        num_images=num_images,
                        age=age,
                        therapeutic_focus=therapeutic_focus,
                        character_appearance=character_appearance,
                        companions=companions,
                        user_id=current_user_id,
                        power_id=power_id,
                    )
                    using_flux_schnell = bool(illustrations)
                    if not illustrations:
                        logger.info(
                            "Flux Schnell returned empty for age %d; falling back to Gemini-via-OpenRouter",
                            age,
                        )

                # Fallback (or Sprout path): Gemini via OpenRouter.
                if not illustrations:
                    if image_generator is None:
                        return (
                            jsonify(
                                {
                                    "error": "Image generation temporarily unavailable",
                                    "hint": "OpenRouter image service is currently unavailable. Please try again later.",
                                    "illustrations": [],
                                    "count": 0,
                                }
                            ),
                            200,
                        )
                    illustrations = image_generator.generate_story_illustration(
                        scene_description=scene_description,
                        character_name=character_name,
                        style=style,
                        num_images=num_images,
                        age=age,
                        therapeutic_focus=therapeutic_focus,
                        character_appearance=character_appearance,
                        companions=companions,
                        power_id=power_id,
                    )

            if not illustrations:
                logger.warning(f"No illustrations generated for scene: {scene_description[:50]}...")
                # Return success with empty illustrations instead of error
                return (
                    jsonify(
                        {
                            "illustrations": [],
                            "count": 0,
                            "used_user_key": using_user_key,
                            "message": "Illustration generation is temporarily unavailable due to API quota limits. Your story is ready, but illustrations couldn't be generated at this time.",
                            "hint": "Try again later or contact support to increase your quota.",
                        }
                    ),
                    200,
                )

            transformed_illustrations = []
            try:
                for img in illustrations:
                    new_img = img.copy()
                    image_url = img.get("image_url", "")

                    if "image_data" in img and isinstance(img.get("image_data"), str):
                        image_data = img.get("image_data", "").strip()
                        if image_data.startswith("data:image"):
                            try:
                                new_img["image_data"] = image_data.split(",", 1)[1]
                            except IndexError:
                                new_img["image_data"] = image_data
                        else:
                            new_img["image_data"] = image_data

                    # If it's a data URI, extract the raw base64 for 'image_data'
                    if not new_img.get("image_data") and image_url.startswith("data:image"):
                        try:
                            # Split 'data:image/png;base64,.....'
                            base64_part = image_url.split(",", 1)[1]
                            new_img["image_data"] = base64_part
                        except IndexError:
                            pass
                    elif not new_img.get("image_data") and image_url.startswith("http"):
                        # Download image and convert to base64
                        # Download image with size limit protection
                        try:
                            logger.info(f"Downloading illustration from {image_url[:50]}...")
                            # Stream the response to check size before loading into memory
                            img_resp = requests.get(image_url, stream=True, timeout=10)
                            img_resp.raise_for_status()

                            # Enforce 5MB limit via Content-Length header if available
                            content_length = img_resp.headers.get('Content-Length')
                            MAX_SIZE = 5 * 1024 * 1024  # 5MB
                            
                            if content_length and int(content_length) > MAX_SIZE:
                                logger.warning(f"Image too large directly from headers: {content_length}")
                                continue

                            # Stream content to enforce limit physically
                            image_bytes = bytearray()
                            for chunk in img_resp.iter_content(chunk_size=8192):
                                image_bytes.extend(chunk)
                                if len(image_bytes) > MAX_SIZE:
                                    logger.warning("Image exceeded 5MB limit during download")
                                    break
                            
                            if len(image_bytes) > MAX_SIZE:
                                continue

                            # Validate image structure
                            try:
                                validate_image_size(image_bytes)
                            except ValueError as size_err:
                                logger.warning(f"Image validation failed: {size_err}")
                                continue

                            # Resize downloaded image to max 1024x1024
                            try:
                                with Image.open(io.BytesIO(image_bytes)) as img:
                                    img.thumbnail((1024, 1024), Image.Resampling.LANCZOS)
                                    buffer = io.BytesIO()
                                    img.save(buffer, format="PNG")
                                    image_bytes = buffer.getvalue()
                            except Exception as resize_err:
                                logger.warning(f"Failed to resize downloaded image: {resize_err}")

                            b64_data = base64.b64encode(image_bytes).decode("utf-8")
                            new_img["image_data"] = b64_data
                            logger.info("Successfully converted image URL to base64 data")
                        except Exception as e:
                            logger.error(f"Error processing illustration image data: {str(e)}")
                    elif not new_img.get("image_data") and _looks_like_base64_image(image_url):
                        new_img["image_data"] = re.sub(r"\s+", "", image_url)

                    # Ensure image_id is present (frontend expects it)
                    if "id" in img:
                        new_img["image_id"] = img["id"]

                    # Ensure scene_description is present (frontend expects it)
                    if "prompt" in img:
                        new_img["scene_description"] = img["prompt"]

                    if not new_img.get("image_data"):
                        logger.warning("Illustration missing image_data after normalization; skipping entry")
                        continue

                    transformed_illustrations.append(new_img)
            except Exception as e:
                logger.error(f"Error in illustration transformation: {str(e)}")
                transformed_illustrations = illustrations  # Fallback to original

            # Increment monthly quota for ages-6+ non-BYOK only.
            # BYOK and Sprout intentionally not counted (see route comments above).
            if (
                len(transformed_illustrations) > 0
                and not using_user_key
                and age >= 6
                and current_user_id
            ):
                try:
                    from ..utils.ai_quota import increment_illustration_quota
                except ImportError:
                    from utils.ai_quota import increment_illustration_quota
                user_tier_for_increment = (
                    getattr(current_user, 'subscription_tier', 'free') or 'free'
                ).lower()
                increment_illustration_quota(
                    current_user_id, user_tier_for_increment,
                    len(transformed_illustrations),
                )

            return (
                jsonify(
                    {
                        "illustrations": transformed_illustrations,
                        "count": len(transformed_illustrations),
                        "used_user_key": using_user_key,
                        "provider": "flux_schnell" if using_flux_schnell else (
                            "gemini_byok" if using_user_key else "gemini_openrouter"
                        ),
                        "quota_used": quota_used + len(transformed_illustrations) if (not using_user_key and age >= 6) else None,
                        "quota_limit": quota_limit if (not using_user_key and age >= 6) else None,
                        "debug_info": {
                        },
                    }
                ),
                200,
            )

        except Exception as exc:
            import traceback
            error_trace = traceback.format_exc()
            logger.exception("Illustration generation failed")
            
            # Write error to file for debugging
            try:
                with open("backend_last_error.log", "w") as f:
                    f.write(error_trace)
            except Exception:
                pass

            return jsonify({"error": str(exc), "hint": "Image generation failed. Check your API key quota or try again later."}), 500

    @story_bp.route("/generate-coloring-pages", methods=["POST"])
    @require_auth
    @require_parental_consent
    @limiter.limit("10 per hour")
    def generate_coloring_pages_endpoint():
        """Generate coloring book pages for story scene(s)"""
        try:
            data = request.get_json(silent=True) or {}

            # Support both singular 'scene_description' and plural 'scenes'
            scene_description = sanitize_text(data.get("scene_description", ""), max_length=2000, allow_newlines=True)
            scenes = data.get("scenes", [])

            # If scenes list is provided, use it, otherwise fall back to scene_description
            if not scenes and scene_description:
                scenes = [{"description": scene_description}]

            if not scenes:
                return jsonify({"error": "Scene description or scenes list is required"}), 400

            character_name = sanitize_text(data.get("character_name", "the hero"), max_length=100)
            
            # Enforce single image generation for coloring pages
            num_images_per_scene = 1
            
            try:
                age = validate_age(data.get("age", 7))
            except ValueError:
                age = 7  # Default to 7 if invalid
            therapeutic_focus = sanitize_text(data.get("therapeutic_focus", ""), max_length=500) or None
            user_api_key = data.get("user_api_key")

            # Get character appearance/avatar details
            character_appearance = data.get("character_appearance") or data.get("appearance")

            # Get companions (could be magical companions, pets, or friends)
            companions = data.get("companions") or data.get("companion_pets") or []

            generator = None
            if user_api_key and not disable_gemini_image:
                try:
                    generator = GeminiImageGenerator(api_key=user_api_key)
                except Exception as e:
                    logger.exception("Failed to init user-provided image generator")
                    return (
                        jsonify({"error": "Invalid or unavailable image API key", "hint": str(e)}),
                        400,
                    )
            elif user_api_key and disable_gemini_image:
                logger.info("DISABLE_GEMINI_IMAGE active; ignoring user_api_key for coloring pages.")
            elif image_generator is not None:
                generator = image_generator
            else:
                return (
                    jsonify(
                        {
                            "coloring_pages": [],
                            "count": 0,
                            "warning": "Image generation unavailable",
                        }
                    ),
                    200,
                )

            all_coloring_pages = []
            for scene_item in scenes:
                # Handle both string and dict in scenes list
                if isinstance(scene_item, str):
                    current_desc = sanitize_text(scene_item, max_length=2000, allow_newlines=True)
                    scene_title = "Coloring Page"
                else:
                    current_desc = sanitize_text(scene_item.get("description", ""), max_length=2000, allow_newlines=True)
                    scene_title = sanitize_text(scene_item.get("title", "Coloring Page"), max_length=100)

                if not current_desc:
                    continue

                pages = generator.generate_coloring_page(
                    scene_description=current_desc,
                    character_name=character_name,
                    num_images=num_images_per_scene,
                    age=age,
                    therapeutic_focus=therapeutic_focus,
                    character_appearance=character_appearance,
                    companions=companions,
                )

                # Add metadata + normalize image_data
                for p in pages:
                    page = p.copy() if isinstance(p, dict) else {"image_url": p}
                    page["scene_title"] = scene_title

                    image_url = page.get("image_url", "")
                    if "image_data" in page and isinstance(page.get("image_data"), str):
                        image_data = page.get("image_data", "").strip()
                        if image_data.startswith("data:image"):
                            try:
                                page["image_data"] = image_data.split(",", 1)[1]
                            except IndexError:
                                page["image_data"] = image_data
                        else:
                            page["image_data"] = image_data
                    if not page.get("image_data") and isinstance(image_url, str):
                        if image_url.startswith("data:image"):
                            try:
                                page["image_data"] = image_url.split(",", 1)[1]
                            except IndexError:
                                pass
                        elif image_url.startswith("http"):
                            try:
                                logger.info(f"Downloading coloring page from {image_url[:50]}...")
                                img_resp = requests.get(image_url, stream=True, timeout=10)
                                img_resp.raise_for_status()

                                content_length = img_resp.headers.get('Content-Length')
                                MAX_SIZE = 5 * 1024 * 1024  # 5MB
                                if content_length and int(content_length) > MAX_SIZE:
                                    logger.warning(f"Coloring page too large from headers: {content_length}")
                                    continue

                                image_bytes = bytearray()
                                for chunk in img_resp.iter_content(chunk_size=8192):
                                    image_bytes.extend(chunk)
                                    if len(image_bytes) > MAX_SIZE:
                                        logger.warning("Coloring page exceeded 5MB limit during download")
                                        break
                                if len(image_bytes) > MAX_SIZE:
                                    continue

                                try:
                                    validate_image_size(image_bytes)
                                except ValueError as size_err:
                                    logger.warning(f"Coloring page validation failed: {size_err}")
                                    continue

                                # Resize to max 1024x1024 for consistency
                                try:
                                    with Image.open(io.BytesIO(image_bytes)) as img:
                                        img.thumbnail((1024, 1024), Image.Resampling.LANCZOS)
                                        buffer = io.BytesIO()
                                        img.save(buffer, format="PNG")
                                        image_bytes = buffer.getvalue()
                                except Exception as resize_err:
                                    logger.warning(f"Failed to resize coloring page: {resize_err}")

                                page["image_data"] = base64.b64encode(image_bytes).decode("utf-8")
                                logger.info("Successfully converted coloring page URL to base64 data")
                            except Exception as e:
                                logger.error(f"Error processing coloring page image data: {str(e)}")
                        elif _looks_like_base64_image(image_url):
                            page["image_data"] = re.sub(r"\s+", "", image_url)

                    if not page.get("image_data"):
                        logger.warning("Coloring page missing image_data after normalization; skipping entry")
                        continue

                    all_coloring_pages.append(page)

            return jsonify({
                "coloring_pages": all_coloring_pages, 
                "count": len(all_coloring_pages)
            }), 200

        except Exception as e:
            logger.exception("Coloring page generation failed")
            return jsonify({"error": "Failed to generate coloring pages", "hint": str(e)}), 500

    @story_bp.route("/generate-illustrations-mock", methods=["POST"])
    def generate_illustrations_mock_endpoint():
        """
        Mock illustrations endpoint for testing and development.
        Returns placeholder images instantly without calling any AI model.
        """
        import uuid
        import base64
        from datetime import datetime
        from PIL import Image, ImageDraw, ImageFont
        import io

        try:
            data = request.get_json(silent=True) or {}
            scene_description = data.get("scene_description", "A magical scene")
            character_name = data.get("character_name", "Hero")
            num_images = min(int(data.get("num_images", 1)), 4)

            logger.info(f"[MOCK] Generating {num_images} illustration(s) for: {scene_description[:50]}...")

            illustrations = []
            for i in range(num_images):
                # Create simple placeholder image
                img = Image.new('RGB', (1024, 768), color='#FFE4B5')  # Moccasin color
                draw = ImageDraw.Draw(img)

                # Try to load font
                try:
                    font_title = ImageFont.truetype("arial.ttf", 60)
                    font_desc = ImageFont.truetype("arial.ttf", 30)
                except:
                    font_title = ImageFont.load_default()
                    font_desc = font_title

                # Draw title
                title = f"Illustration {i+1}"
                bbox = draw.textbbox((0, 0), title, font=font_title)
                x = (1024 - (bbox[2] - bbox[0])) // 2
                draw.text((x, 100), title, fill='#8B4513', font=font_title)

                # Draw scene description (truncated)
                desc = scene_description[:60] + "..." if len(scene_description) > 60 else scene_description
                bbox_desc = draw.textbbox((0, 0), desc, font=font_desc)
                x_desc = (1024 - (bbox_desc[2] - bbox_desc[0])) // 2
                draw.text((x_desc, 200), desc, fill='#654321', font=font_desc)

                # Draw character name
                char_text = f"Starring: {character_name}"
                bbox_char = draw.textbbox((0, 0), char_text, font=font_desc)
                x_char = (1024 - (bbox_char[2] - bbox_char[0])) // 2
                draw.text((x_char, 300), char_text, fill='#654321', font=font_desc)

                # Draw MOCK watermark
                bbox_mock = draw.textbbox((0, 0), "MOCK ILLUSTRATION", font=font_desc)
                x_mock = (1024 - (bbox_mock[2] - bbox_mock[0])) // 2
                draw.text((x_mock, 700), "MOCK ILLUSTRATION", fill='#A0522D', font=font_desc)

                # Convert to base64
                buffer = io.BytesIO()
                img.save(buffer, format='PNG')
                img_base64 = base64.b64encode(buffer.getvalue()).decode('utf-8')

                illustrations.append({
                    'id': f"mock-illust-{uuid.uuid4()}",
                    'image_data': img_base64,
                    'format': 'png',
                    'prompt': scene_description,
                    'generated_at': datetime.now().isoformat(),
                    'is_mock': True,
                    'cost': 0.0
                })

            return jsonify({
                'illustrations': illustrations,
                'count': len(illustrations)
            }), 200

        except Exception as e:
            logger.exception(f"Error in mock illustration generation: {e}")
            return jsonify({"error": str(e)}), 500

    @story_bp.route("/generate-coloring-pages-mock", methods=["POST"])
    def generate_coloring_pages_mock_endpoint():
        """
        Mock coloring pages endpoint for testing and development.
        Returns placeholder black & white images instantly without calling any AI model.
        """
        import uuid
        import base64
        from datetime import datetime
        from PIL import Image, ImageDraw, ImageFont
        import io

        try:
            data = request.get_json(silent=True) or {}
            scene_description = data.get("scene_description", "")
            scenes = data.get("scenes", [])

            if not scenes and scene_description:
                scenes = [{"description": scene_description, "title": "Coloring Page"}]

            if not scenes:
                return jsonify({"error": "Scene description or scenes list is required"}), 400

            character_name = data.get("character_name", "Hero")
            num_images_per_scene = min(int(data.get("num_images", 1)), 3)

            logger.info(f"[MOCK] Generating {num_images_per_scene} coloring page(s) per scene, {len(scenes)} scene(s)")

            all_coloring_pages = []
            for scene_item in scenes:
                # Handle both string and dict
                if isinstance(scene_item, str):
                    current_desc = scene_item
                    scene_title = "Coloring Page"
                else:
                    current_desc = scene_item.get("description", "")
                    scene_title = scene_item.get("title", "Coloring Page")

                if not current_desc:
                    continue

                for i in range(num_images_per_scene):
                    # Create black & white coloring page style
                    img = Image.new('RGB', (1024, 1024), color='white')
                    draw = ImageDraw.Draw(img)

                    # Try to load font
                    try:
                        font_title = ImageFont.truetype("arial.ttf", 50)
                        font_small = ImageFont.truetype("arial.ttf", 30)
                    except:
                        font_title = ImageFont.load_default()
                        font_small = font_title

                    # Draw simple shapes (outlines only - coloring page style)
                    # Circle
                    draw.ellipse([200, 200, 400, 400], outline='black', width=5)
                    # Star shape (simplified)
                    draw.polygon([(512, 100), (550, 200), (650, 200), (570, 270),
                                  (600, 370), (512, 310), (424, 370), (454, 270),
                                  (374, 200), (474, 200)], outline='black', width=4)
                    # Rectangle with character name
                    draw.rectangle([100, 500, 924, 650], outline='black', width=5)

                    # Draw title
                    title = f"{scene_title} {i+1}"
                    bbox = draw.textbbox((0, 0), title, font=font_title)
                    x = (1024 - (bbox[2] - bbox[0])) // 2
                    draw.text((x, 700), title, fill='black', font=font_title)

                    # Draw character name
                    char_text = f"{character_name}"
                    bbox_char = draw.textbbox((0, 0), char_text, font=font_small)
                    x_char = (1024 - (bbox_char[2] - bbox_char[0])) // 2
                    draw.text((x_char, 560), char_text, fill='black', font=font_small)

                    # Draw MOCK label
                    draw.text((850, 20), "MOCK", fill='black', font=font_small)

                    # Convert to base64
                    buffer = io.BytesIO()
                    img.save(buffer, format='PNG')
                    img_base64 = base64.b64encode(buffer.getvalue()).decode('utf-8')

                    all_coloring_pages.append({
                        'id': f"mock-color-{uuid.uuid4()}",
                        'image_data': img_base64,
                        'format': 'png',
                        'prompt': current_desc,
                        'scene_title': scene_title,
                        'generated_at': datetime.now().isoformat(),
                        'is_mock': True,
                        'cost': 0.0
                    })

            return jsonify({
                'coloring_pages': all_coloring_pages,
                'count': len(all_coloring_pages)
            }), 200

        except Exception as e:
            logger.exception(f"Error in mock coloring page generation: {e}")
            return jsonify({"error": str(e)}), 500

    return story_bp
