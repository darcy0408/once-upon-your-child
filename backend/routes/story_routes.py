import base64
import io
import logging
import os
import re
import uuid
from concurrent.futures import ThreadPoolExecutor
from concurrent.futures import TimeoutError as FuturesTimeoutError

import requests
from celery.exceptions import TimeoutError as CeleryTimeoutError
from flask import Blueprint, g, jsonify, request
from PIL import Image
from sqlalchemy.exc import SQLAlchemyError

from ..celery_config import celery
from ..database import db
from ..gemini_image_generator import GeminiImageGenerator
from ..middleware.auth import require_auth, require_parental_consent
from ..models import Character, ParentHiddenContext
from ..models.story import Story
from ..routes.subscription_routes import require_premium
from ..services.interactive_adventure_service import InteractiveAdventureService
from ..services.story_service import transform_parent_context_to_story_guidance
from ..tasks.story_tasks import (
    AntiheroGenerationError,
    generate_story_task,
    run_antihero_part1,
    run_antihero_part2,
)
from ..utils.ai_quota import check_daily_quota, increment_daily_quota
from ..utils.audit import audit_log
from ..utils.validators import (
    sanitize_text,
    validate_age,
    validate_image_size,
    validate_num_images,
    validate_story_modes,
)

logger = logging.getLogger(__name__)


def _resolve_age(raw_age, default: int = 5, verified_age=None) -> int:
    """
    Convert a raw age value from a request payload into a validated integer.

    Rules applied in order:
    1. Parse to int; fall back to *default* on failure.
    2. Clamp to the valid character-age range [2, 120].
    3. If the authenticated user is an under-13 minor (g.minor_age_cap is set),
       cap to their declared age so they cannot request adult-calibrated content
       by submitting a higher age value in the request body.
    4. M-6: if a *verified_age* anchor is supplied (the authenticated account's
       verified onboarding age, or the age stored on an owned Character record),
       cap the resolved age to it. The content age band therefore cannot be
       inflated above what the account/character is actually known to be — only
       a DOWNWARD override is honoured (a parent may request a younger band).
    """
    try:
        age = max(2, min(120, int(raw_age)))
    except (TypeError, ValueError):
        age = default
    cap = getattr(g, "minor_age_cap", None)
    if cap is not None:
        age = min(age, cap)
    # M-6: clamp upward to the verified anchor — client-declared age may only
    # move the band DOWN, never up above the verified/owned-character age.
    if verified_age is not None:
        try:
            age = min(age, max(2, min(120, int(verified_age))))
        except (TypeError, ValueError):
            pass
    return age


def _verified_age_anchor(character=None) -> int | None:
    """Return the verified upper-bound age for content-band calibration (M-6).

    Preference order:
    1. The age on the authenticated user's owned Character record (ownership is
       checked by the caller before this is invoked) — the most specific
       verified value for the child the story is about.
    2. The authenticated account's declared onboarding age.

    Returns None when neither is available, in which case _resolve_age applies
    only the existing under-13 minor cap.
    """
    if character is not None:
        char_age = getattr(character, "age", None)
        if char_age is not None:
            return char_age
    current_user = getattr(request, "current_user", None)
    if current_user is not None:
        return getattr(current_user, "declared_age", None)
    return None


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
    emotion_description = _clean_prompt_value(
        current_feeling.get("emotion_description")
    )
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
    story_guidance = _clean_prompt_value(
        (transformed_guidance or {}).get("story_guidance")
    )
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
        lines.extend(
            [
                f"1. Open with the feeling already present in the character's body or thoughts — not announced like a lesson.",
                "2. Keep the stakes life-sized — real relationships, real consequences, real ambiguity.",
                "3. Honour the feeling without rushing to resolve it; complexity and contradiction are valid.",
                "4. Show the body clue somatically and specifically — not as a diagram but as lived experience.",
                "5. The coping gesture is a starting point, not a solution; it may land imperfectly or only partially help.",
                "6. End with integration, not resolution — the feeling can still be present at the close; a character who has simply named and held something difficult is enough.",
                "7. Never moralise or summarise the emotional lesson. The story IS the lesson.",
            ]
        )
    else:
        lines.extend(
            [
                f'1. Open by naming the feeling in the first lines, like: "{opening_example}"',
                "2. Keep the problem child-sized and concrete.",
                "3. Validate the feeling without shaming it or trying to erase it.",
                "4. Show the body clue early and naturally.",
                "5. Let the helper action change what happens next.",
                "6. If the hero makes a messy choice, include a gentle repair and reconnect moment.",
            ]
        )
        if numeric_age <= 5:
            lines.extend(
                [
                    "7. Use very simple feeling words: mad, sad, scared, frustrated.",
                    "8. Use short concrete sentences and warm reassuring imagery only.",
                ]
            )

    return "\n".join(lines)


def _augment_therapeutic_prompt(
    payload: dict,
    base_prompt: str,
    transformed_guidance: dict | None = None,
) -> str:
    parts = (
        [base_prompt.strip()]
        if isinstance(base_prompt, str) and base_prompt.strip()
        else []
    )

    current_feeling = payload.get("current_feeling")
    if isinstance(current_feeling, dict):
        emotion_name = _clean_prompt_value(current_feeling.get("emotion_name"))
        normalized = _normalize_feeling_label(emotion_name)
        if normalized == "mad":
            parts.append("Emotion focus: anger and calming without shame.")
        elif normalized == "scared":
            parts.append(
                "Emotion focus: fear/anxiety and feeling safe enough to take one small step."
            )
        elif normalized == "sad":
            parts.append("Emotion focus: sadness, comfort, and connection.")
        elif normalized == "frustrated":
            parts.append(
                "Emotion focus: frustration, trying again, and asking for help."
            )

    guidance_line = _clean_prompt_value(
        (transformed_guidance or {}).get("story_guidance")
    )
    if guidance_line:
        parts.append(f"Parent-guided Big Feelings scaffolding: {guidance_line}")

    return " | ".join(parts)


def _run_sync_story_task_with_timeout(task_kwargs, sync_story_timeout, task_id):
    """Run story generation in a bounded worker thread under an explicit task id.

    The generation runs as an eager Celery task with `task_id` so that, if it
    overruns `sync_story_timeout`, the still-running thread is NOT abandoned: it
    keeps running to completion and persists its Story row keyed by `task_id`.
    The caller returns that id for polling and /task-status recovers the
    finished story from the DB (R2). This replaces the previous behaviour where
    a timed-out sync run was orphaned with no handle AND a second async task
    was dispatched — producing two full generations and duplicate Story rows
    (A3).
    """
    executor = ThreadPoolExecutor(max_workers=1)
    # Important: use current generate_story_task which might be mocked in tests
    future = executor.submit(
        generate_story_task.apply, kwargs=task_kwargs, task_id=task_id
    )
    try:
        eager_result = future.result(timeout=sync_story_timeout)
        return eager_result.get()
    finally:
        # wait=False lets a timed-out generation finish in the background so
        # its Story row is persisted for /task-status DB recovery. Do NOT pass
        # cancel_futures — the in-flight generation must be allowed to complete.
        executor.shutdown(wait=False)


def _recover_story_from_db(task_id: str, current_user_id) -> tuple[dict, int] | None:
    """R2: reconstruct a completed-task response from the persisted Story row.

    `generate_story_task` persists the full story payload to the Story row
    keyed by `task_id`. When the Celery result has expired (result_expires=1h)
    this lets /task-status still return the finished story. Returns:
      - (complete-response, 200) when the owning user's finished story is found
      - ({"error": "Access denied"}, 403) when the row belongs to another user
      - None when no Story row exists for this task_id (task genuinely pending)
    """
    if not task_id:
        return None
    try:
        story = Story.query.filter_by(task_id=task_id).first()
    except SQLAlchemyError:
        db.session.rollback()
        logger.warning(
            "DB story-recovery lookup failed for task %s", task_id, exc_info=True
        )
        return None
    if story is None or not story.content:
        return None
    if str(story.user_id) != str(current_user_id):
        logger.warning(
            "IDOR attempt: user %s tried task %s owned by %s (DB recovery)",
            current_user_id,
            task_id,
            story.user_id,
        )
        return {"error": "Access denied"}, 403
    return {
        "status": "complete",
        "result": {
            "status": "complete",
            "story": story.content,
            "user_id": str(story.user_id),
        },
    }, 200


def _companion_count(task_kwargs: dict) -> int:
    """Count the companions (pets + characters) carried by this request.

    Companion names are appended to the mandatory-name validation set in
    generate_story_task; each additional name raises the chance a generation
    attempt fails the name check and triggers a full re-generation. More
    companions therefore means more sequential AI calls and a longer wall
    time — see _sync_timeout_for below.
    """
    pets = task_kwargs.get("companion_pets") or []
    chars = task_kwargs.get("companion_characters") or []
    legacy = task_kwargs.get("companion")
    count = 0
    if isinstance(pets, (list, tuple)):
        count += len(pets)
    if isinstance(chars, (list, tuple)):
        count += len(chars)
    if legacy:
        count += 1
    return count


def _sync_timeout_for(task_kwargs: dict, base_timeout: int) -> int:
    """Companion-aware sync-generation timeout.

    The base SYNC_STORY_TIMEOUT_SECONDS is tuned for a plain single-character
    story (one or two AI calls). Companion-heavy requests enlarge the prompt
    AND add mandatory validation names, which routinely forces an extra
    full-story regeneration — pushing wall time past the base budget. When
    that happens the route abandons the sync attempt and restarts generation
    from scratch on the async worker, and the client (which polls on a fixed
    budget) often gives up and shows a canned scaffold story instead.

    Granting extra head-room per companion keeps a legitimate multi-companion
    generation completing in the sync path. The grant is capped so a request
    with many companions cannot hold a worker indefinitely. This widens a
    timeout only — it never gates or rejects a request.
    """
    companions = _companion_count(task_kwargs)
    if companions <= 0:
        return base_timeout
    per_companion = int(os.getenv("SYNC_STORY_TIMEOUT_PER_COMPANION_SECONDS", "30"))
    max_extra = int(os.getenv("SYNC_STORY_TIMEOUT_MAX_EXTRA_SECONDS", "120"))
    extra = min(companions * per_companion, max_extra)
    return base_timeout + extra


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


def _read_partial_story(task_id: str | None) -> str | None:
    """PERF-01 slice 3: read accumulated streamed story text from Redis.

    Returns the partial text the Gemini stream consumer wrote (see
    `_emit_partial_story` in story_tasks.py), or None if nothing is
    available. Best-effort: any Redis hiccup returns None so /task-status
    degrades to the same response shape it had pre-PERF-01.
    """
    if not task_id:
        return None
    redis_url = os.getenv("REDIS_URL") or os.getenv("REDIS_PRIVATE_URL")
    if not redis_url:
        return None
    try:
        import redis as redis_lib

        client = redis_lib.from_url(redis_url, socket_connect_timeout=1)
        value = client.get(f"partial_story:{task_id}")
        if value is None:
            return None
        if isinstance(value, bytes):
            value = value.decode("utf-8", errors="replace")
        return value or None
    except Exception:
        return None


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


def _flux_disabled(env_var: str) -> bool:
    """True when [env_var] is set to a truthy kill-switch value."""
    return os.getenv(env_var, "").lower() in ("1", "true", "yes")


def _generate_flux_illustration(**kwargs) -> list:
    """Per-page Flux Schnell illustration with provider fallback (MT-131).

    Tries Cloudflare Workers AI first — it runs the same flux-1-schnell model
    under a free daily allocation that covers current scale at $0 — then falls
    back to Replicate Flux Schnell (~$0.003/img) so a Cloudflare outage or
    quota exhaustion doesn't regress illustrations. ``CLOUDFLARE_FLUX_DISABLED``
    and ``FLUX_SCHNELL_DISABLED`` independently kill each provider. Returns []
    if both are disabled or both fail, so the caller's Gemini fallback runs.

    [kwargs] are passed through unchanged to both generators — they share the
    ``scene_description, character_name, style, num_images, age,
    therapeutic_focus, character_appearance, companions, user_id, power_id``
    signature.
    """
    images: list = []
    if not _flux_disabled("CLOUDFLARE_FLUX_DISABLED"):
        try:
            from ..cloudflare_image_generator import CloudflareImageGenerator
        except ImportError:
            from cloudflare_image_generator import CloudflareImageGenerator
        images = CloudflareImageGenerator().generate_story_illustration_flux(**kwargs)
    if not images and not _flux_disabled("FLUX_SCHNELL_DISABLED"):
        try:
            from ..replicate_image_generator import ReplicateImageGenerator
        except ImportError:
            from replicate_image_generator import ReplicateImageGenerator
        images = ReplicateImageGenerator().generate_story_illustration_flux_schnell(
            **kwargs
        )
    return images


# ===========================================================================
# "The Crux Choice" — shared kwargs for the two-phase Adolescent antihero routes.
#
# DECISION: this is a NEW helper used ONLY by /generate-antihero-crux and
# /generate-antihero-resolution. It does NOT extract shared lines out of
# generate_story_endpoint, so that endpoint's output stays byte-for-byte
# identical (its existing tests in test_story_routes_async.py remain a
# regression guard). It assembles the same hero_*/prior_saga/character kwargs
# the existing endpoint builds for the adolescent superhero case.
# ===========================================================================
def _build_antihero_task_kwargs(payload: dict, user, resolved_age: int) -> dict:
    """Assemble the brief inputs the part1/part2 builders need from a request.

    Mirrors the adolescent superhero subset of generate_story_endpoint's
    ``task_kwargs``: identity fields (hero_secret/tell/line), the Edge fields
    (power/costume/emblem/catchphrase), the returnable ``prior_saga``, the
    character reference and resolved age, plus custom_elements. ``user`` is the
    authenticated ``request.current_user``.
    """
    user_tier = getattr(user, "subscription_tier", "free") or "free"
    return {
        "user_id": user.id,
        "user_tier": user_tier,
        "character_id": payload.get("character_id"),
        "character": payload.get("character"),
        "age": resolved_age,
        "hero_costume_color": payload.get("hero_costume_color"),
        "hero_emblem": payload.get("hero_emblem"),
        "hero_power": payload.get("hero_power"),
        "hero_mode": payload.get("hero_mode"),
        "hero_catchphrase": payload.get("hero_catchphrase"),
        "hero_secret": payload.get("hero_secret"),
        "hero_tell": payload.get("hero_tell"),
        "hero_line": payload.get("hero_line"),
        "hero_seen_by": payload.get("hero_seen_by"),
        "custom_elements": payload.get("customElements", "")
        or payload.get("custom_elements", "")
        or "",
        # The returnable saga (returning hero); absent on chapter 1.
        "prior_saga": payload.get("prior_saga") or payload.get("saga_state"),
    }


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
    disable_gemini_image = os.getenv("DISABLE_GEMINI_IMAGE", "").strip().lower() in (
        "1",
        "true",
        "yes",
    )
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
    @limiter.limit(
        lambda: get_tier_limits() or "1000/minute"
    )  # BYOK users get high limit
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
        user_tier = getattr(request.current_user, "subscription_tier", "free") or "free"

        # Daily AI generation quota — circuit breaker against unbounded Gemini spend.
        allowed, current_count, daily_limit = check_daily_quota(user_id, user_tier)
        if not allowed:
            audit_log(
                "ai_quota_exceeded",
                user_id=user_id,
                data={"tier": user_tier, "count": current_count, "limit": daily_limit},
            )
            return (
                jsonify(
                    {
                        "error": "Daily story limit reached",
                        "code": "QUOTA_EXCEEDED",
                        "limit": daily_limit,
                        "used": current_count,
                        "message": "You've reached your story limit for today. Come back tomorrow!",
                    }
                ),
                429,
            )

        # Validate character ownership
        character_id = payload.get("character_id")
        owned_character = None
        if character_id:
            char = db.session.get(Character, character_id)
            if not char:
                return jsonify({"error": "Character not found"}), 404
            if char.user_id and str(char.user_id) != str(user_id):
                logger.warning(
                    f"IDOR attempt: User {user_id} tried to generate story for character {character_id}"
                )
                return jsonify({"error": "Unauthorized"}), 403
            owned_character = char

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

        # Extract character_details to get additional_characters if available.
        # The Flutter client sends `additional_characters` at the top level of
        # the request body (see lib/services/api_service_manager.dart). The
        # wizard fallback path nests them under `character_details` as
        # `additionalCharacters`. Both spellings are preserved here and threaded
        # into `task_kwargs` so the downstream prompt builders (bedtime, rhyme,
        # learning-to-read, standard) actually receive the guest cast.
        character_details = payload.get("character_details") or {}
        additional_chars = payload.get(
            "additional_characters"
        ) or character_details.get("additionalCharacters")

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

        # M-6: derive the content age band from the verified account age /
        # owned Character record. The client-declared `age` may only move the
        # band DOWN (a parent requesting a gentler story) — it can never push
        # content calibration above the verified/owned-character age.
        resolved_age = _resolve_age(
            resolved_age,
            verified_age=_verified_age_anchor(owned_character),
        )

        # Story Notes (MT-254): the focus(es) this story is guided toward,
        # echoed back to the client so it can offer the age-gated "Why this
        # story? 💛" disclosure. The prompt weaves in EVERY configured trigger
        # (comma-joined), so we echo them all — the client names them naturally
        # (capped at 3). None for non-Big-Feelings requests → no button.
        practiced_focus = None
        if transformed_parent_guidance:
            _trigger = transformed_parent_guidance.get("trigger")
            if _trigger and _trigger.strip():
                practiced_focus = _trigger.strip()

        task_kwargs = {
            "character_id": payload.get("character_id"),
            "character": payload.get("character"),
            "character_details": character_details,
            "theme": theme,
            "practiced_focus": practiced_focus,
            "user_id": user_id,
            "user_tier": user_tier,  # Drives tier-aware text-model selection
            "include_illustrations": payload.get("include_illustrations", False),
            "async_illustrations": payload.get("async_illustrations", False),
            "rhyme_time_mode": payload.get("rhyme_time_mode", False),
            "learning_to_read_mode": payload.get("learning_to_read_mode", False),
            "bedtime_mode": payload.get("bedtime_mode", False),
            "bedtime_mood": payload.get("bedtime_mood", "calming"),
            "companion": payload.get("companion")
            or payload.get("companion_name"),  # Legacy support
            "companion_pets": companion_pets,  # NEW: List of pet companions with species
            "companion_characters": companion_characters,  # NEW: List of character companions
            # MT-194: thread `additional_characters` (guest cast) through to the
            # prompt builder. Without this, the downstream `kwargs.get(
            # "additional_characters")` returns None and the guest cast only
            # appears if the client nested it under `character_details`.
            "additional_characters": additional_chars,
            "spark_tool": payload.get("sparkTool"),  # NEW: Spark Tool
            "mood_physics": payload.get("moodPhysics"),  # NEW: Mood Physics
            "conflict_hook": payload.get("conflictHook"),  # NEW: Plot Driver
            "sensory_palette": payload.get("sensoryPalette"),  # NEW: Atmosphere
            "world_bible": payload.get("worldBible", ""),  # World consistency guide
            "custom_elements": payload.get(
                "customElements", ""
            ),  # NEW: Free-form custom story requests
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
            "hero_mode": payload.get("hero_mode"),
            "hero_catchphrase": payload.get("hero_catchphrase"),
            # MT-305: the Creator-band child's typed hero codename. Threaded
            # through to build_story_prompt so the Creator prompt names the hero
            # after the chosen codename instead of the power.
            "hero_alias": payload.get("hero_alias"),
            # Adolescent (15-17) antihero "identity" fields — only meaningful
            # for the T10 double-life prompt; other bands ignore them.
            "hero_secret": payload.get("hero_secret"),
            "hero_tell": payload.get("hero_tell"),
            "hero_line": payload.get("hero_line"),
            "hero_seen_by": payload.get("hero_seen_by"),
            "hero_nemesis_id": payload.get("hero_nemesis_id"),
            "recent_villains": payload.get("recent_villains") or [],
            "recent_problems": payload.get("recent_problems") or [],
        }

        # If async mode is requested, disable inline illustrations but pass the flag
        if task_kwargs.get("async_illustrations"):
            task_kwargs["include_illustrations"] = False
            logger.info("Async illustrations enabled - skipping inline generation")

        # Companion-heavy requests get extra sync head-room: companions enlarge
        # the prompt and add mandatory validation names that often force an
        # extra regeneration. Without the bump these legitimately-slower
        # requests time out, restart on the async worker from scratch, and the
        # client falls back to a canned scaffold story.
        effective_sync_timeout = _sync_timeout_for(task_kwargs, sync_story_timeout)

        # A3: pre-allocate the id the sync generation runs under so a
        # generation that overruns the timeout stays pollable instead of being
        # orphaned. See the timeout handler below and /task-status (R2).
        recovery_task_id = str(uuid.uuid4())

        # Try synchronous execution first (to bypass polling issues on Railway)
        try:
            # Run synchronous task in a bounded worker thread so timeout is enforced.
            sync_result = _run_sync_story_task_with_timeout(
                task_kwargs, effective_sync_timeout, recovery_task_id
            )

            # Debugging: Log the result type
            logger.info(f"Sync task result type: {type(sync_result)}")
            if isinstance(sync_result, str):
                logger.error(
                    f"Sync task returned string instead of dict: {sync_result[:200]}..."
                )
                raise Exception(f"Task returned invalid format (str): {sync_result}")

            # Extract story payload from the task result
            story_payload = (sync_result or {}).get("story", {})
            if not story_payload:
                story_payload = (sync_result or {}).get("story_text", {})

            response_payload = {
                "status": sync_result.get("status", "complete"),
                "story": story_payload,
                "task_id": "sync_task",  # No task ID needed
                "async_illustrations": payload.get("async_illustrations", False),
            }
            increment_daily_quota(user_id, user_tier)
            audit_log(
                "story_generated",
                user_id=user_id,
                data={"tier": user_tier, "mode": "sync"},
            )
            return jsonify(response_payload), 200

        except (FuturesTimeoutError, CeleryTimeoutError):
            # A3: the synchronous generation overran the timeout. Its worker
            # thread is NOT abandoned — it keeps running in the background and
            # will persist a Story row keyed by `recovery_task_id`. Return that
            # id for polling; /task-status recovers the finished story from the
            # DB (R2). We deliberately do NOT dispatch a second task here: the
            # previous code left the sync thread orphaned AND queued an async
            # task, producing two full generations and duplicate Story rows.
            logger.warning(
                "Synchronous story generation exceeded %ss; returning poll id %s "
                "for the in-flight generation.",
                effective_sync_timeout,
                recovery_task_id,
            )
            _cache_task_owner(cache, recovery_task_id, user_id)
            return (
                jsonify(
                    {
                        "task_id": recovery_task_id,
                        "status": "processing",
                        "message": "Story generation is taking a little longer — poll for the result.",
                        "poll_url": f"/task-status/{recovery_task_id}",
                    }
                ),
                202,
            )

        except Exception as exc:
            logger.exception(
                "Synchronous story generation failed, attempting async fallback: %s",
                exc,
            )

            if (
                "429" in str(exc)
                or "ResourceExhausted" in str(exc)
                or "Quota exceeded" in str(exc)
            ):
                logger.warning(f"Quota exceeded in sync generation: {exc}")
                return (
                    jsonify(
                        {
                            "error": "QUOTA_EXCEEDED",
                            "message": "Google Gemini API quota exceeded. Please try again later.",
                        }
                    ),
                    429,
                )

            if _celery_runs_eagerly():
                logger.warning(
                    "Celery task_always_eager is enabled; async fallback would still block. Returning error response."
                )
                return (
                    jsonify(
                        {
                            "error": "STORY_FAILED",
                            "message": "Something went wrong generating your story. Please try again.",
                        }
                    ),
                    500,
                )
            # X2: exactly one async retry. The sync attempt above already
            # failed without producing a story, so this is the second (and
            # final) generation attempt. The previous code kept an additional
            # "last resort" synchronous retry after this, so a single failed
            # request could trigger up to three full generations.
            try:
                task = generate_story_task.delay(**task_kwargs)
                _cache_task_owner(cache, task.id, user_id)
                return (
                    jsonify(
                        {
                            "task_id": task.id,
                            "status": "processing",
                            "message": "Story generation started (async fallback)",
                            "poll_url": f"/task-status/{task.id}",
                        }
                    ),
                    202,
                )
            except Exception as async_exc:
                if (
                    "429" in str(async_exc)
                    or "ResourceExhausted" in str(async_exc)
                    or "Quota exceeded" in str(async_exc)
                ):
                    logger.warning(f"Quota exceeded in async generation: {async_exc}")
                    return (
                        jsonify(
                            {
                                "error": "QUOTA_EXCEEDED",
                                "message": "Google Gemini API quota exceeded. Please try again later.",
                            }
                        ),
                        429,
                    )
                logger.exception("Async fallback also failed: %s", async_exc)
                return (
                    jsonify(
                        {
                            "error": "STORY_FAILED",
                            "message": "Something went wrong generating your story. Please try again.",
                        }
                    ),
                    500,
                )

    # =====================================================================
    # "The Crux Choice" — two-phase Adolescent antihero routes (Phase 2).
    #
    # /generate-antihero-crux        — runs part 1 (Beats 1-4 + the choice),
    #     charges the daily quota ONCE here, caches a minimal continuation
    #     context under a uuid token (~30-min TTL), returns awaiting_choice.
    # /generate-antihero-resolution  — runs part 2 (Beats 5-7) conditioned on
    #     the chosen option, assembles the full 7-beat story, lifts saga_state
    #     onto superhero_meta, PERSISTS the Story row, consumes the token, and
    #     returns the complete story. Does NOT charge quota again.
    #
    # Fully additive: generate_story_endpoint / generate_story_task are untouched.
    # =====================================================================
    _ANTIHERO_CONTINUATION_TTL = 1800  # 30 minutes (design: ~30-min TTL)

    @story_bp.route("/generate-antihero-crux", methods=["POST"])
    @require_auth
    @require_parental_consent
    @limiter.limit(lambda: get_tier_limits() or "1000/minute")
    def generate_antihero_crux_endpoint():
        """Part 1 of the interactive crux: setup + the two-sided choice.

        Full preamble (auth, quota CHECK, IDOR/owned-character, age resolve),
        then run_antihero_part1. Charges the daily quota ONCE here, caches the
        continuation context under a uuid token, and returns
        ``200 {status:"awaiting_choice", continuation_token, story:{...}}``.
        """
        from ..utils.sanitizer import sanitize_story_request

        payload = request.get_json(silent=True) or {}
        payload = sanitize_story_request(payload)

        user_id = request.current_user.id
        user_tier = getattr(request.current_user, "subscription_tier", "free") or "free"

        # Daily AI generation quota — circuit breaker (same as /generate-story).
        allowed, current_count, daily_limit = check_daily_quota(user_id, user_tier)
        if not allowed:
            audit_log(
                "ai_quota_exceeded",
                user_id=user_id,
                data={"tier": user_tier, "count": current_count, "limit": daily_limit},
            )
            return (
                jsonify(
                    {
                        "error": "Daily story limit reached",
                        "code": "QUOTA_EXCEEDED",
                        "limit": daily_limit,
                        "used": current_count,
                        "message": "You've reached your story limit for today. Come back tomorrow!",
                    }
                ),
                429,
            )

        # Validate character ownership (IDOR guard, same as /generate-story).
        character_id = payload.get("character_id")
        owned_character = None
        if character_id:
            char = db.session.get(Character, character_id)
            if not char:
                return jsonify({"error": "Character not found"}), 404
            if char.user_id and str(char.user_id) != str(user_id):
                logger.warning(
                    f"IDOR attempt: User {user_id} tried to generate antihero "
                    f"story for character {character_id}"
                )
                return jsonify({"error": "Unauthorized"}), 403
            owned_character = char

        if not character_id and not payload.get("character"):
            return jsonify({"error": "character_id or character is required"}), 400

        resolved_age = _resolve_age(
            payload.get("age") or payload.get("character_age") or 16,
            default=16,
            verified_age=_verified_age_anchor(owned_character),
        )

        kw = _build_antihero_task_kwargs(payload, request.current_user, resolved_age)
        # Resolve the character display name for the prompt (owned char wins).
        character_name = (
            owned_character.name
            if owned_character is not None
            else (kw.get("character") or "the hero")
        )
        if isinstance(character_name, dict):
            character_name = character_name.get("name", "the hero")

        try:
            part1 = run_antihero_part1(
                character=character_name,
                age=resolved_age,
                user_tier=user_tier,
                hero_power=kw.get("hero_power"),
                hero_costume_color=kw.get("hero_costume_color"),
                hero_emblem=kw.get("hero_emblem"),
                hero_catchphrase=kw.get("hero_catchphrase"),
                hero_secret=kw.get("hero_secret"),
                hero_tell=kw.get("hero_tell"),
                hero_line=kw.get("hero_line"),
                hero_seen_by=kw.get("hero_seen_by"),
                custom_elements=kw.get("custom_elements", ""),
                prior_saga=kw.get("prior_saga"),
            )
        except AntiheroGenerationError as exc:
            logger.error("antihero crux part-1 failed: %s", exc)
            return (
                jsonify(
                    {
                        "error": "STORY_FAILED",
                        "message": "Something went wrong starting your chapter. Please try again.",
                    }
                ),
                502,
            )
        except Exception as exc:  # noqa: BLE001
            logger.exception("antihero crux part-1 unexpected error: %s", exc)
            return (
                jsonify(
                    {
                        "error": "STORY_FAILED",
                        "message": "Something went wrong starting your chapter. Please try again.",
                    }
                ),
                500,
            )

        # Charge the daily quota ONCE, here in part 1 (design: quota-once).
        increment_daily_quota(user_id, user_tier)

        # Cache a MINIMAL, json-serializable continuation context for part 2.
        continuation_token = str(uuid.uuid4())
        continuation_context = {
            "user_id": str(user_id),
            "user_tier": user_tier,
            "character_id": character_id,
            "character": character_name,
            "age": resolved_age,
            "hero_power": kw.get("hero_power"),
            "hero_costume_color": kw.get("hero_costume_color"),
            "hero_emblem": kw.get("hero_emblem"),
            "hero_catchphrase": kw.get("hero_catchphrase"),
            "hero_secret": kw.get("hero_secret"),
            "hero_tell": kw.get("hero_tell"),
            "hero_line": kw.get("hero_line"),
            "hero_seen_by": kw.get("hero_seen_by"),
            "custom_elements": kw.get("custom_elements", ""),
            "prior_saga": kw.get("prior_saga"),
            "villain_id": part1["villain_id"],
            "problem_id": part1["problem_id"],
            "part1_pages": part1["pages"],
            "choices": part1["choices"],
            "title": part1["title"],
        }
        try:
            cache.set(
                f"antihero-crux:{continuation_token}",
                continuation_context,
                timeout=_ANTIHERO_CONTINUATION_TTL,
            )
        except Exception:
            logger.warning(
                "Failed to cache antihero continuation context for token %s",
                continuation_token,
                exc_info=True,
            )
            return (
                jsonify(
                    {
                        "error": "STORY_FAILED",
                        "message": "Something went wrong starting your chapter. Please try again.",
                    }
                ),
                500,
            )

        audit_log(
            "antihero_crux_started",
            user_id=user_id,
            data={"tier": user_tier},
        )
        return (
            jsonify(
                {
                    "status": "awaiting_choice",
                    "continuation_token": continuation_token,
                    "story": {
                        "title": part1["title"],
                        "pages": part1["pages"],
                        "crux": part1["crux"],
                        "choices": part1["choices"],
                    },
                }
            ),
            200,
        )

    @story_bp.route("/generate-antihero-resolution", methods=["POST"])
    @require_auth
    @require_parental_consent
    @limiter.limit(lambda: get_tier_limits() or "1000/minute")
    def generate_antihero_resolution_endpoint():
        """Part 2 of the interactive crux: resolve the reader's chosen path.

        Body: ``{continuation_token, choice_id}``. Rehydrates the cached part-1
        context (404 if missing/expired), validates ``choice_id``, runs
        run_antihero_part2, assembles the full 7-beat story, lifts saga_state
        onto superhero_meta, persists the Story row, consumes the token, and
        returns ``200 {status:"complete", story:{...}}``. Does NOT re-charge
        quota.
        """
        payload = request.get_json(silent=True) or {}
        user_id = request.current_user.id

        continuation_token = payload.get("continuation_token")
        choice_id = payload.get("choice_id")
        if not continuation_token or not choice_id:
            return (
                jsonify({"error": "continuation_token and choice_id are required"}),
                400,
            )

        cache_key = f"antihero-crux:{continuation_token}"
        ctx = None
        try:
            ctx = cache.get(cache_key)
        except Exception:
            logger.warning(
                "Failed to read antihero continuation context for token %s",
                continuation_token,
                exc_info=True,
            )
        if not ctx:
            # Missing or expired (TTL elapsed) — 410 Gone is the precise signal.
            return (
                jsonify(
                    {
                        "error": "continuation token not found or expired",
                        "code": "TOKEN_EXPIRED",
                    }
                ),
                410,
            )

        # Same-user check: a token may only be resolved by its owner.
        if str(ctx.get("user_id")) != str(user_id):
            logger.warning(
                "IDOR attempt: user %s tried to resolve antihero token owned by %s",
                user_id,
                ctx.get("user_id"),
            )
            return jsonify({"error": "Unauthorized"}), 403

        # Validate choice_id against the cached choices; resolve {id, text}.
        choices = ctx.get("choices") or []
        chosen_choice = next(
            (c for c in choices if str(c.get("id")) == str(choice_id)), None
        )
        if chosen_choice is None:
            return (
                jsonify(
                    {
                        "error": "invalid choice_id",
                        "valid_choices": [c.get("id") for c in choices],
                    }
                ),
                400,
            )

        try:
            part2 = run_antihero_part2(
                chosen_choice=chosen_choice,
                part1_pages=ctx.get("part1_pages") or [],
                character=ctx.get("character") or "the hero",
                age=ctx.get("age", 16),
                user_tier=ctx.get("user_tier"),
                hero_power=ctx.get("hero_power"),
                hero_costume_color=ctx.get("hero_costume_color"),
                hero_emblem=ctx.get("hero_emblem"),
                hero_catchphrase=ctx.get("hero_catchphrase"),
                hero_secret=ctx.get("hero_secret"),
                hero_tell=ctx.get("hero_tell"),
                hero_line=ctx.get("hero_line"),
                hero_seen_by=ctx.get("hero_seen_by"),
                custom_elements=ctx.get("custom_elements", ""),
                prior_saga=ctx.get("prior_saga"),
                villain_id=ctx.get("villain_id"),
                problem_id=ctx.get("problem_id"),
            )
        except AntiheroGenerationError as exc:
            logger.error("antihero crux part-2 failed: %s", exc)
            return (
                jsonify(
                    {
                        "error": "STORY_FAILED",
                        "message": "Something went wrong finishing your chapter. Please try again.",
                    }
                ),
                502,
            )
        except Exception as exc:  # noqa: BLE001
            logger.exception("antihero crux part-2 unexpected error: %s", exc)
            return (
                jsonify(
                    {
                        "error": "STORY_FAILED",
                        "message": "Something went wrong finishing your chapter. Please try again.",
                    }
                ),
                500,
            )

        # Assemble the full 7-beat story: part-1 pages + part-2 resolution pages.
        part1_pages = ctx.get("part1_pages") or []
        full_pages = list(part1_pages) + list(part2["pages"])
        title = ctx.get("title") or "Untitled Chapter"
        story_body = "\n\n".join(full_pages)

        # Lift saga_state onto superhero_meta, mirroring generate_story_task's
        # shape so the client's existing superhero_meta.saga_state parsing +
        # HeroSaga.recordIssue work unchanged. The raw saga_state (incl.
        # defining_choice / what_it_cost / allies) is preserved.
        superhero_meta = {
            "villain_id": ctx.get("villain_id"),
            "problem_id": ctx.get("problem_id"),
            "hero_power": ctx.get("hero_power") or "strategist",
            "band": "adolescent",
            "saga_state": part2["saga_state"],
        }

        story_id = str(uuid.uuid4())
        story_payload = {
            "id": story_id,
            "title": title,
            "story_text": story_body,
            "theme": "superhero",
            "pages": full_pages,
            "total_pages": len(full_pages),
            "total_words": sum(len(p.split()) for p in full_pages),
            "superhero_meta": superhero_meta,
        }

        # Persist the Story row (skipped for anonymous; mirrors generate_story_task).
        character_id = ctx.get("character_id")
        if user_id and user_id != "anonymous":
            try:
                db.session.add(
                    Story(
                        id=story_id,
                        user_id=str(user_id),
                        character_id=character_id if character_id else None,
                        title=title[:200] if title else None,
                        theme="superhero",
                        content=story_payload,
                    )
                )
                db.session.commit()
                logger.info(
                    "antihero_story_persisted id=%s character_id=%s",
                    story_id,
                    character_id,
                )
            except Exception:  # noqa: BLE001
                db.session.rollback()
                logger.exception(
                    "Failed to persist antihero Story row (story still returned)."
                )

        # Consume the continuation token (one resolution per crux).
        try:
            cache.delete(cache_key)
        except Exception:
            logger.warning(
                "Failed to delete antihero continuation token %s",
                continuation_token,
                exc_info=True,
            )

        audit_log(
            "antihero_resolution_completed",
            user_id=user_id,
            data={"tier": ctx.get("user_tier")},
        )
        return (
            jsonify(
                {
                    "status": "complete",
                    "story": story_payload,
                }
            ),
            200,
        )

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
                    "include_illustrations": payload.get(
                        "include_illustrations", False
                    ),
                    "rhyme_time_mode": payload.get("rhyme_time_mode", False),
                    "learning_to_read_mode": payload.get(
                        "learning_to_read_mode", False
                    ),
                },
            },
        }
        # The frontend expects the result of the task, not the task object itself
        return jsonify(mock_story), 200

    @story_bp.route("/task-status/<task_id>", methods=["GET"])
    @require_auth
    def get_task_status(task_id):
        task = celery.AsyncResult(task_id)

        # R2: once a completed task's Celery result expires (result_expires=1h)
        # its state reads as PENDING and the story would look lost. The full
        # payload is also persisted to the Story row keyed by task_id — recover
        # it from the DB so an expired result never loses a generated story.
        # This also covers a sync generation that overran its timeout (A3): the
        # background thread persists the Story row under recovery_task_id.
        if task.state == "PENDING":
            recovered = _recover_story_from_db(task_id, request.current_user.id)
            if recovered is not None:
                payload, status_code = recovered
                return jsonify(payload), status_code

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

        if task_owner_id is None:
            # Symmetric guard (audit P2#13): refuse to disclose ANY state —
            # including SUCCESS results and FAILURE info — when ownership cannot
            # be verified. A real story task always resolves an owner (cache or
            # result.user_id), so None means missing metadata, not a legit read.
            # The prior guard only covered PENDING/PROCESSING, leaving a SUCCESS
            # task with no owner metadata readable by any authenticated user.
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
            # PERF-01 slice 3: a sync-path task may already be mid-stream
            # before Celery has flipped to PROCESSING. If partial text is
            # in Redis, surface it so the client can render early.
            partial_text = _read_partial_story(task_id)
            if partial_text:
                response["status"] = "processing"
                response["partial_text"] = partial_text
        elif task.state == "PROCESSING":
            meta = task.info or {}
            status_message = meta.get("status") if isinstance(meta, dict) else str(meta)
            response = {
                "status": "processing",
                "message": status_message or "Generating story...",
            }
            # PERF-01 slice 3: include the accumulated streamed text when
            # available so the client can render the in-flight story
            # instead of just a spinner.
            partial_text = _read_partial_story(task_id)
            if partial_text:
                response["partial_text"] = partial_text
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

    @story_bp.route("/cancel-task/<task_id>", methods=["POST"])
    @require_auth
    def cancel_task(task_id):
        """PERF-04: signal an in-flight generation to abandon further work.

        The flag is checked by the worker at the start of generation and (in
        future slices) between phases. Best-effort:
          - 202 when the cancel flag was written to Redis.
          - 503 when Redis is unreachable (no signal sent).
          - 403 on ownership mismatch (same gate as /task-status).
          - 202 with status='accepted' for unknown task ids — UUIDs make
            cross-task interference impossible, and replying 404 would let
            a client probe other users' task ids.
        """
        from ..utils.task_cancellation import request_cancellation

        task = celery.AsyncResult(task_id)
        task_owner_id = _resolve_task_owner(cache, task_id, task)
        if task_owner_id and str(task_owner_id) != str(request.current_user.id):
            logger.warning(
                "IDOR attempt: user %s tried to cancel task %s owned by %s",
                request.current_user.id,
                task_id,
                task_owner_id,
            )
            return jsonify({"error": "Access denied"}), 403

        if task_owner_id is None:
            # Unknown task — accept silently rather than disclose ownership.
            return jsonify({"status": "accepted"}), 202

        if request_cancellation(task_id):
            return jsonify({"status": "accepted"}), 202
        return jsonify({"status": "redis_unavailable"}), 503

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
        from ..utils.sanitizer import sanitize_story_request

        payload = request.get_json(silent=True) or {}
        # Sanitize every free-text field (worldBible, conflictHook, sensoryPalette,
        # etc.) before it reaches the interactive prompt builder — same defense
        # the synchronous /generate-story path gets.
        payload = sanitize_story_request(payload)

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
        owned_character = None
        if character_id:
            char = db.session.get(Character, character_id)
            if not char:
                return jsonify({"error": "Character not found"}), 404
            if char.user_id and str(char.user_id) != str(user_id):
                logger.warning(
                    f"IDOR attempt: User {user_id} tried to generate interactive story for character {character_id}"
                )
                return jsonify({"error": "Unauthorized"}), 403
            owned_character = char

        theme = payload.get("theme", "Adventure")
        tone = payload.get("tone", "whimsical")
        length = payload.get("length", "medium")
        # M-6: clamp the content age band to the verified account / owned
        # Character age — client-declared `age` may only override downward.
        age = _resolve_age(
            payload.get("age"),
            verified_age=_verified_age_anchor(owned_character),
        )
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

            # Two-layer output moderation — keyword filter, then LLM classifier
            # if the keyword layer didn't already flag.
            # M-4: the LLM contextual classifier is wired into the interactive
            # path and FAILS CLOSED for the Sprout band (ages 3-5) — when the
            # classifier errors for a Sprout child the segment is treated as
            # unsafe and replaced with a safe fallback rather than served
            # unmoderated. Older bands keep the deliberate fail-open behaviour.
            from backend.utils.content_moderator import (
                build_safe_fallback_segment,
                is_sprout_band,
                moderate_story_content,
            )

            segment_content = result["segment"]["content"]
            filtered_content, flagged = filter_story_content(segment_content, age)
            result["segment"]["content"] = filtered_content

            # F-01: widen moderation input to cover the segment title and every
            # choice-button label — children see/tap these, not just the body.
            moderation_input = "\n".join(
                [
                    filtered_content,
                    result["segment"].get("title", ""),
                    *[c.get("text", "") for c in result["segment"].get("choices", [])],
                ]
            )
            _, title_choices_flagged = filter_story_content(
                "\n".join(
                    [
                        result["segment"].get("title", ""),
                        *[
                            c.get("text", "")
                            for c in result["segment"].get("choices", [])
                        ],
                    ]
                ),
                age,
            )
            if title_choices_flagged:
                flagged = True
                logger.warning(
                    "Interactive story opening title/choices flagged by content filter"
                )

            if flagged:
                logger.warning("Interactive story opening flagged by content filter")
            else:
                try:
                    llm_safe, llm_reason = moderate_story_content(
                        moderation_input, age, fail_closed=is_sprout_band(age)
                    )
                    if not llm_safe:
                        flagged = True
                        logger.warning(
                            f"Interactive story opening flagged by LLM moderator: {llm_reason!r}"
                        )
                except Exception as moderation_err:
                    # Defensive: moderate_story_content already handles its own
                    # errors, but if something unexpected escapes, fail closed
                    # for Sprout so the youngest children never see unvetted text.
                    logger.warning(
                        f"Interactive story opening LLM moderation error ({moderation_err!r})"
                    )
                    if is_sprout_band(age):
                        flagged = True

            # When the opening segment is unsafe (or unverifiable for Sprout),
            # serve a safe fallback segment instead of the generated content.
            # F-02: also replace choices so unsafe button labels are never shown.
            if flagged:
                fallback = build_safe_fallback_segment(segment_number=1)
                result["segment"]["content"] = fallback["content"]
                result["segment"]["title"] = fallback["title"]
                result["segment"]["image_description"] = fallback["image_description"]
                result["segment"]["choices"] = fallback["choices"]
                result["segment"]["image_url"] = None
                logger.warning(
                    "Interactive story opening replaced with safe fallback segment "
                    f"(story {result.get('story_id')})"
                )

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
            return (
                jsonify(
                    {
                        "error": str(e),
                        "hint": "Interactive story generation failed on the backend.",
                    }
                ),
                500,
            )

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
        from ..utils.sanitizer import sanitize_for_prompt, wrap_user_input

        payload = request.get_json(silent=True) or {}

        story_id = payload.get("story_id")
        choice_id = payload.get("choice_id")
        raw_custom_text = (payload.get("custom_text") or "").strip()[:200]

        # Validate required fields
        if not story_id or not choice_id:
            return jsonify({"error": "story_id and choice_id are required"}), 400

        if choice_id == "custom" and not raw_custom_text:
            return (
                jsonify(
                    {"error": "custom_text is required when choice_id is 'custom'"}
                ),
                400,
            )

        # Audit #5 — self-harm disclosure guard. Before the child's free-text
        # reaches the model, check for a self-harm / suicide disclosure. If found
        # we do NOT generate a story segment from it; we return crisis resources
        # so the client surfaces its CrisisResourcesPanel with warmth. This is
        # the authoritative server-side check (the client has a fast first-line
        # check too). Detect on the RAW text, before injection-stripping.
        if choice_id == "custom" and raw_custom_text:
            from ..utils.crisis_detection import crisis_response, detect_crisis

            if detect_crisis(raw_custom_text):
                # Never log the disclosure text itself.
                logger.warning(
                    "Crisis: self-harm disclosure detected in custom_text for "
                    "story %s (user %s); returning crisis resources, not a story.",
                    story_id,
                    getattr(request.current_user, "id", "?"),
                )
                return jsonify(crisis_response()), 200

        # The "Something Else" free-text choice flows straight into the
        # continuation prompt. Strip injection/HTML/delimiter tokens, hard-cap
        # length, and wrap as [USER_INPUT] so the model treats it as a story
        # choice — never as an instruction. (Finding H-3, CWE-94/1427.)
        custom_text = None
        if choice_id == "custom":
            cleaned_custom = sanitize_for_prompt(raw_custom_text, 200)
            if not cleaned_custom:
                return (
                    jsonify(
                        {"error": "custom_text is required when choice_id is 'custom'"}
                    ),
                    400,
                )
            custom_text = wrap_user_input(cleaned_custom, "player_choice")

        try:
            from backend.models import InteractiveStory

            # Ownership check
            story = db.session.get(InteractiveStory, story_id)
            if not story:
                return jsonify({"error": f"Story {story_id} not found"}), 404

            if str(story.user_id) != str(request.current_user.id):
                logger.warning(
                    f"IDOR attempt: User {request.current_user.id} tried to continue story {story_id}"
                )
                return jsonify({"error": "Access denied"}), 403

            # Initialize service
            service = InteractiveAdventureService(gemini_api_key=api_key)

            # Continue story — pass custom_text so the service can use it
            result = service.continue_story(
                story_id=story_id, choice_id=choice_id, custom_text=custom_text or None
            )

            # Two-layer output moderation — same as the main story path.
            # Layer 1: fast age-band keyword filter.
            # Layer 2: LLM contextual classifier (only if Layer 1 didn't flag).
            # M-4: the classifier FAILS CLOSED for the Sprout band (ages 3-5) —
            # a classifier error means the segment is replaced with a safe
            # fallback rather than served unmoderated. This is important now
            # that free-text custom choices can steer the continuation
            # (Finding H-3). Older bands keep the deliberate fail-open path.
            from backend.utils.content_moderator import (
                build_safe_fallback_segment,
                is_sprout_band,
                moderate_story_content,
            )

            story_age = getattr(story, "age", None) or 5
            segment_content = result["segment"]["content"]
            filtered_content, flagged = filter_story_content(segment_content, story_age)
            result["segment"]["content"] = filtered_content

            # F-01: widen moderation input to cover the segment title and every
            # choice-button label — children see/tap these, not just the body.
            moderation_input = "\n".join(
                [
                    filtered_content,
                    result["segment"].get("title", ""),
                    *[c.get("text", "") for c in result["segment"].get("choices", [])],
                ]
            )
            _, title_choices_flagged = filter_story_content(
                "\n".join(
                    [
                        result["segment"].get("title", ""),
                        *[
                            c.get("text", "")
                            for c in result["segment"].get("choices", [])
                        ],
                    ]
                ),
                story_age,
            )
            if title_choices_flagged:
                flagged = True
                logger.warning(
                    "Interactive continuation title/choices flagged by content filter"
                )

            if flagged:
                logger.warning("Interactive continuation flagged by content filter")
            else:
                try:
                    llm_safe, llm_reason = moderate_story_content(
                        moderation_input,
                        story_age,
                        fail_closed=is_sprout_band(story_age),
                    )
                    if not llm_safe:
                        flagged = True
                        logger.warning(
                            f"Interactive continuation flagged by LLM moderator: {llm_reason!r}"
                        )
                except Exception as moderation_err:
                    # Defensive: fail closed for Sprout if anything unexpected escapes.
                    logger.warning(
                        f"Interactive continuation LLM moderation error ({moderation_err!r})"
                    )
                    if is_sprout_band(story_age):
                        flagged = True

            # When the continuation is unsafe (or unverifiable for Sprout),
            # serve a safe fallback segment instead of the generated content.
            # F-02: also replace choices so unsafe button labels are never shown.
            if flagged:
                fallback = build_safe_fallback_segment(
                    segment_number=result["segment"].get("segment_number", 1),
                    is_opening=False,
                )
                result["segment"]["content"] = fallback["content"]
                result["segment"]["title"] = fallback["title"]
                result["segment"]["image_description"] = fallback["image_description"]
                result["segment"]["choices"] = fallback["choices"]
                result["segment"]["image_url"] = None
                logger.warning(
                    f"Interactive continuation replaced with safe fallback segment "
                    f"(story {story_id})"
                )

            logger.info(
                f"Story {story_id} continued to segment {result['segment']['segment_number']}"
            )
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
            return (
                jsonify(
                    {
                        "error": str(e),
                        "hint": "Continuing interactive story failed on the backend.",
                    }
                ),
                500,
            )

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
                logger.warning(
                    f"IDOR attempt: User {request.current_user.id} tried to read story {story_id}"
                )
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
                logger.warning(
                    f"IDOR attempt: User {request.current_user.id} tried to resume story {story_id}"
                )
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
                "story_id": story.id,
                "title": story.title,
                "current_segment_number": story.current_segment_number,
                "segment": current_segment.to_dict(),
                "inventory": [
                    item.to_dict()
                    for item in story.inventory.filter_by(is_active=True).all()
                ],
                "state": story.state.to_dict() if story.state else None,
                "is_completed": story.is_completed,
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

        logger.warning(
            f"⚠️ CONTENT REPORT - Story ID: {story_id}, Reason: {reason}, Preview: {snippet}"
        )

        return (
            jsonify({"status": "reported", "message": "Thank you for your report"}),
            200,
        )

    @story_bp.route("/generate-illustrations", methods=["POST"])
    @require_auth
    @require_parental_consent
    @limiter.limit(
        lambda: get_tier_limits("expensive") or "100/hour"
    )  # BYOK users get high limit
    def generate_illustrations_endpoint():
        """Generate illustrations for a story scene"""
        try:
            data = request.get_json(silent=True) or {}
            scene_description = sanitize_text(
                data.get("scene_description", ""), max_length=2000, allow_newlines=True
            )
            character_name = sanitize_text(
                data.get("character_name", "the hero"), max_length=100
            )
            style = sanitize_text(
                data.get("style", "children's book illustration"), max_length=200
            )
            num_images = validate_num_images(data.get("num_images", 1), max_allowed=4)
            try:
                age = validate_age(data.get("age", 7))
            except ValueError:
                age = 7  # Default to 7 if invalid
            therapeutic_focus = (
                sanitize_text(data.get("therapeutic_focus", ""), max_length=500) or None
            )
            user_api_key = data.get("user_api_key")  # BYOK support

            # MT-107: Optional power_id triggers per-power visual signature in
            # the prompt (e.g., feeling_sense → empathy halo, invisibility →
            # wisp-edged silhouette). Frontend may send either key.
            power_id = data.get("power_id") or data.get("hero_power")
            if power_id is not None:
                power_id = sanitize_text(str(power_id), max_length=64) or None

            # Get character appearance/avatar details
            character_appearance = data.get("character_appearance") or data.get(
                "appearance"
            )

            # Get companions (could be magical companions, pets, or friends)
            companions = data.get("companions") or data.get("companion_pets") or []

            if not scene_description.strip():
                return jsonify({"error": "Scene description is required"}), 400

            # F-10: keyword-screen the scene description before it reaches the
            # image model. Story page text is moderated upstream, but a modified
            # client can POST an arbitrary scene_description directly. On a flag,
            # fall back to a known-safe generic scene.
            from ..utils.app_helpers import make_filter_story_content

            _, _scene_flagged = make_filter_story_content(logger)(
                scene_description, age
            )
            if _scene_flagged:
                logger.warning(
                    "Illustration scene_description flagged by keyword filter; "
                    "substituting safe fallback scene."
                )
                scene_description = (
                    "a warm, gentle children's book illustration of a sunny "
                    "meadow with friendly animals"
                )

            # Use user's API key if provided, otherwise use the hybrid pipeline.
            # Per-page illustration routing (cost reduction, 2026-05-17):
            #   - All ages (incl. Sprout <=5): Flux Schnell primary, Gemini-
            #     via-OpenRouter fallback when Flux returns empty — so a child
            #     always gets a picture. Sprout was switched off Gemini-primary
            #     to Flux (~13x cheaper); see docs/IMAGE_GEN_AB_TEST_RESULTS.md.
            # MT-131: "Flux" = Cloudflare Workers AI flux-1-schnell first ($0
            # at current scale), Replicate Flux Schnell second — see
            # _generate_flux_illustration.
            # BYOK users always use their own Gemini key regardless of age.
            # Every non-BYOK page is metered against the monthly illustration
            # quota (Sprout uses a separate, generous cap — see ai_quota.py);
            # a cache hit on a re-read serves the stored image and does NOT
            # consume quota.
            generator = None
            using_user_key = False
            using_flux_schnell = False
            served_from_cache = False
            current_user = getattr(request, "current_user", None)
            current_user_id = (
                getattr(current_user, "id", None) if current_user else None
            )
            # Sprout band (age <=5) uses the generous Sprout illustration cap.
            is_sprout = age <= 5

            if user_api_key and not disable_gemini_image:
                generator = GeminiImageGenerator(api_key=user_api_key)
                using_user_key = True
            elif user_api_key and disable_gemini_image:
                logger.info(
                    "DISABLE_GEMINI_IMAGE active; ignoring user_api_key for illustrations."
                )

            illustrations = []
            quota_exhausted = False
            quota_used = 0
            quota_limit = 0

            # Persistent cache lookup (non-BYOK only). A story re-read produces
            # identical inputs → identical key → a hit returns the stored image
            # without billing a provider and without consuming quota. The cache
            # layer degrades open: any DB fault behaves as a miss.
            cache_key = None
            if generator is None and num_images == 1:
                try:
                    from ..services.illustration_cache_service import (
                        compute_cache_key,
                        get_cached_illustration,
                    )
                except ImportError:
                    from services.illustration_cache_service import (
                        compute_cache_key,
                        get_cached_illustration,
                    )
                cache_key = compute_cache_key(
                    scene_description=scene_description,
                    character_name=character_name,
                    style=style,
                    age=age,
                    therapeutic_focus=therapeutic_focus,
                    companions=companions,
                    power_id=power_id,
                    character_appearance=character_appearance,
                )
                cached = get_cached_illustration(cache_key)
                if cached and cached.get("image_data"):
                    from datetime import datetime as _dt
                    from datetime import timezone as _tz

                    served_from_cache = True
                    using_flux_schnell = str(cached.get("provider") or "").startswith(
                        "flux"
                    )
                    illustrations = [
                        {
                            "id": f"cache-{cache_key[:12]}",
                            "prompt": scene_description,
                            "image_data": cached["image_data"],
                            "format": cached.get("format", "png"),
                            "provider": cached.get("provider"),
                            "generated_at": _dt.now(_tz.utc).isoformat(),
                        }
                    ]
                    logger.info(
                        "Illustration cache HIT key=%s provider=%s — skipping provider + quota",
                        cache_key[:12],
                        cached.get("provider"),
                    )

            if served_from_cache:
                pass  # cache supplied `illustrations`; skip provider + quota.
            elif generator is not None:
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
                # Server-key path — ALL non-BYOK ages are metered against the
                # monthly illustration quota. Sprout (age <=5) uses a separate,
                # generous cap (is_sprout=True; see ai_quota.py). A cache hit
                # above already short-circuited and never reaches here, so a
                # re-read never consumes quota.
                if current_user_id:
                    try:
                        from ..utils.ai_quota import check_illustration_quota
                    except ImportError:
                        from utils.ai_quota import check_illustration_quota
                    user_tier = (
                        getattr(current_user, "subscription_tier", "free") or "free"
                    )
                    allowed, quota_used, quota_limit = check_illustration_quota(
                        current_user_id,
                        user_tier.lower(),
                        num_images,
                        is_sprout=is_sprout,
                    )
                    if not allowed:
                        quota_exhausted = True
                        logger.info(
                            "Illustration quota exhausted for user=%s tier=%s sprout=%s used=%d/%d",
                            current_user_id,
                            user_tier,
                            is_sprout,
                            quota_used,
                            quota_limit,
                        )

                if quota_exhausted:
                    return (
                        jsonify(
                            {
                                "illustrations": [],
                                "count": 0,
                                "code": "ILLUSTRATION_QUOTA_EXCEEDED",
                                "quota_used": quota_used,
                                "quota_limit": quota_limit,
                                "message": (
                                    "You've used all your free illustrations this month. "
                                    "Upgrade for more, or wait until next month."
                                ),
                            }
                        ),
                        200,
                    )

                # Primary provider for ALL ages: Flux Schnell. Flux = Cloudflare
                # first, then Replicate fallback (see _generate_flux_illustration);
                # each provider has its own kill-switch env var.
                illustrations = _generate_flux_illustration(
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
                        "Flux returned empty for age %d; falling back to Gemini-via-OpenRouter",
                        age,
                    )

                # Fallback for ALL ages: Gemini via OpenRouter, so a child
                # always gets a picture even if Flux is down or empty.
                if not illustrations and image_generator is not None:
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
                logger.warning(
                    f"No illustrations generated for scene: {scene_description[:50]}..."
                )
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
                    if not new_img.get("image_data") and image_url.startswith(
                        "data:image"
                    ):
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
                            logger.info(
                                f"Downloading illustration from {image_url[:50]}..."
                            )
                            # Stream the response to check size before loading into memory
                            img_resp = requests.get(image_url, stream=True, timeout=10)
                            img_resp.raise_for_status()

                            # Enforce 5MB limit via Content-Length header if available
                            content_length = img_resp.headers.get("Content-Length")
                            MAX_SIZE = 5 * 1024 * 1024  # 5MB

                            if content_length and int(content_length) > MAX_SIZE:
                                logger.warning(
                                    f"Image too large directly from headers: {content_length}"
                                )
                                continue

                            # Stream content to enforce limit physically
                            image_bytes = bytearray()
                            for chunk in img_resp.iter_content(chunk_size=8192):
                                image_bytes.extend(chunk)
                                if len(image_bytes) > MAX_SIZE:
                                    logger.warning(
                                        "Image exceeded 5MB limit during download"
                                    )
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
                                    img.thumbnail(
                                        (1024, 1024), Image.Resampling.LANCZOS
                                    )
                                    buffer = io.BytesIO()
                                    img.save(buffer, format="PNG")
                                    image_bytes = buffer.getvalue()
                            except Exception as resize_err:
                                logger.warning(
                                    f"Failed to resize downloaded image: {resize_err}"
                                )

                            b64_data = base64.b64encode(image_bytes).decode("utf-8")
                            new_img["image_data"] = b64_data
                            logger.info(
                                "Successfully converted image URL to base64 data"
                            )
                        except Exception as e:
                            logger.error(
                                f"Error processing illustration image data: {str(e)}"
                            )
                    elif not new_img.get("image_data") and _looks_like_base64_image(
                        image_url
                    ):
                        new_img["image_data"] = re.sub(r"\s+", "", image_url)

                    # Ensure image_id is present (frontend expects it)
                    if "id" in img:
                        new_img["image_id"] = img["id"]

                    # Ensure scene_description is present (frontend expects it)
                    if "prompt" in img:
                        new_img["scene_description"] = img["prompt"]

                    if not new_img.get("image_data"):
                        logger.warning(
                            "Illustration missing image_data after normalization; skipping entry"
                        )
                        continue

                    transformed_illustrations.append(new_img)
            except Exception as e:
                logger.error(f"Error in illustration transformation: {str(e)}")
                transformed_illustrations = illustrations  # Fallback to original

            # Persist a freshly generated image so a re-read is free. Skipped
            # for BYOK (user pays Google) and for a cache hit (already stored).
            # Only single-image requests are cached — the key identifies one
            # image. The cache layer never raises.
            if (
                cache_key
                and not served_from_cache
                and not using_user_key
                and len(transformed_illustrations) == 1
            ):
                first = transformed_illustrations[0]
                img_data = first.get("image_data")
                if img_data:
                    try:
                        from ..services.illustration_cache_service import (
                            store_illustration,
                        )
                    except ImportError:
                        from services.illustration_cache_service import (
                            store_illustration,
                        )
                    store_illustration(
                        cache_key,
                        img_data,
                        image_format=first.get("format"),
                        provider=(
                            "flux_schnell"
                            if using_flux_schnell
                            else "gemini_openrouter"
                        ),
                    )

            # Increment monthly quota for ALL non-BYOK ages (Sprout included).
            # A cache hit (served_from_cache) is excluded — a re-read is free.
            # BYOK is excluded — the user pays Google directly.
            if (
                len(transformed_illustrations) > 0
                and not using_user_key
                and not served_from_cache
                and current_user_id
            ):
                try:
                    from ..utils.ai_quota import increment_illustration_quota
                except ImportError:
                    from utils.ai_quota import increment_illustration_quota
                user_tier_for_increment = (
                    getattr(current_user, "subscription_tier", "free") or "free"
                ).lower()
                increment_illustration_quota(
                    current_user_id,
                    user_tier_for_increment,
                    len(transformed_illustrations),
                )

            _meter_in_response = not using_user_key and not served_from_cache
            return (
                jsonify(
                    {
                        "illustrations": transformed_illustrations,
                        "count": len(transformed_illustrations),
                        "used_user_key": using_user_key,
                        "cached": served_from_cache,
                        "provider": (
                            "flux_schnell"
                            if using_flux_schnell
                            else (
                                "gemini_byok" if using_user_key else "gemini_openrouter"
                            )
                        ),
                        "quota_used": (
                            quota_used + len(transformed_illustrations)
                            if _meter_in_response
                            else None
                        ),
                        "quota_limit": quota_limit if _meter_in_response else None,
                        "debug_info": {},
                    }
                ),
                200,
            )

        except Exception as exc:
            logger.exception("Illustration generation failed")
            return (
                jsonify(
                    {
                        "error": str(exc),
                        "hint": "Image generation failed. Check your API key quota or try again later.",
                    }
                ),
                500,
            )

    @story_bp.route("/generate-coloring-pages", methods=["POST"])
    @require_auth
    @require_premium  # M-8: coloring pages are a premium capability — enforce server-side
    @require_parental_consent
    @limiter.limit("10 per hour")
    def generate_coloring_pages_endpoint():
        """Generate coloring book pages for story scene(s)"""
        try:
            data = request.get_json(silent=True) or {}

            # Support both singular 'scene_description' and plural 'scenes'
            scene_description = sanitize_text(
                data.get("scene_description", ""), max_length=2000, allow_newlines=True
            )
            scenes = data.get("scenes", [])

            # If scenes list is provided, use it, otherwise fall back to scene_description
            if not scenes and scene_description:
                scenes = [{"description": scene_description}]

            if not scenes:
                return (
                    jsonify({"error": "Scene description or scenes list is required"}),
                    400,
                )

            character_name = sanitize_text(
                data.get("character_name", "the hero"), max_length=100
            )

            # Enforce single image generation for coloring pages
            num_images_per_scene = 1

            try:
                age = validate_age(data.get("age", 7))
            except ValueError:
                age = 7  # Default to 7 if invalid

            # F-10: keyword-screen every scene description before it reaches the
            # image model. On a flag, substitute a known-safe generic scene.
            from ..utils.app_helpers import make_filter_story_content

            _coloring_filter = make_filter_story_content(logger)
            _SAFE_COLORING_SCENE = (
                "a gentle children's coloring page of a sunny meadow with "
                "friendly animals"
            )
            for _scene in scenes:
                if not isinstance(_scene, dict):
                    continue
                _desc = (
                    _scene.get("description") or _scene.get("scene_description") or ""
                )
                _, _scene_flagged = _coloring_filter(_desc, age)
                if _scene_flagged:
                    logger.warning(
                        "Coloring scene description flagged by keyword filter; "
                        "substituting safe fallback scene."
                    )
                    if "description" in _scene:
                        _scene["description"] = _SAFE_COLORING_SCENE
                    if "scene_description" in _scene:
                        _scene["scene_description"] = _SAFE_COLORING_SCENE
            therapeutic_focus = (
                sanitize_text(data.get("therapeutic_focus", ""), max_length=500) or None
            )
            user_api_key = data.get("user_api_key")

            # Get character appearance/avatar details
            character_appearance = data.get("character_appearance") or data.get(
                "appearance"
            )

            # Get companions (could be magical companions, pets, or friends)
            companions = data.get("companions") or data.get("companion_pets") or []

            generator = None
            if user_api_key and not disable_gemini_image:
                try:
                    generator = GeminiImageGenerator(api_key=user_api_key)
                except Exception as e:
                    logger.exception("Failed to init user-provided image generator")
                    return (
                        jsonify(
                            {
                                "error": "Invalid or unavailable image API key",
                                "hint": str(e),
                            }
                        ),
                        400,
                    )
            elif user_api_key and disable_gemini_image:
                logger.info(
                    "DISABLE_GEMINI_IMAGE active; ignoring user_api_key for coloring pages."
                )
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
                    current_desc = sanitize_text(
                        scene_item, max_length=2000, allow_newlines=True
                    )
                    scene_title = "Coloring Page"
                else:
                    current_desc = sanitize_text(
                        scene_item.get("description", ""),
                        max_length=2000,
                        allow_newlines=True,
                    )
                    scene_title = sanitize_text(
                        scene_item.get("title", "Coloring Page"), max_length=100
                    )

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
                                logger.info(
                                    f"Downloading coloring page from {image_url[:50]}..."
                                )
                                img_resp = requests.get(
                                    image_url, stream=True, timeout=10
                                )
                                img_resp.raise_for_status()

                                content_length = img_resp.headers.get("Content-Length")
                                MAX_SIZE = 5 * 1024 * 1024  # 5MB
                                if content_length and int(content_length) > MAX_SIZE:
                                    logger.warning(
                                        f"Coloring page too large from headers: {content_length}"
                                    )
                                    continue

                                image_bytes = bytearray()
                                for chunk in img_resp.iter_content(chunk_size=8192):
                                    image_bytes.extend(chunk)
                                    if len(image_bytes) > MAX_SIZE:
                                        logger.warning(
                                            "Coloring page exceeded 5MB limit during download"
                                        )
                                        break
                                if len(image_bytes) > MAX_SIZE:
                                    continue

                                try:
                                    validate_image_size(image_bytes)
                                except ValueError as size_err:
                                    logger.warning(
                                        f"Coloring page validation failed: {size_err}"
                                    )
                                    continue

                                # Resize to max 1024x1024 for consistency
                                try:
                                    with Image.open(io.BytesIO(image_bytes)) as img:
                                        img.thumbnail(
                                            (1024, 1024), Image.Resampling.LANCZOS
                                        )
                                        buffer = io.BytesIO()
                                        img.save(buffer, format="PNG")
                                        image_bytes = buffer.getvalue()
                                except Exception as resize_err:
                                    logger.warning(
                                        f"Failed to resize coloring page: {resize_err}"
                                    )

                                page["image_data"] = base64.b64encode(
                                    image_bytes
                                ).decode("utf-8")
                                logger.info(
                                    "Successfully converted coloring page URL to base64 data"
                                )
                            except Exception as e:
                                logger.error(
                                    f"Error processing coloring page image data: {str(e)}"
                                )
                        elif _looks_like_base64_image(image_url):
                            page["image_data"] = re.sub(r"\s+", "", image_url)

                    if not page.get("image_data"):
                        logger.warning(
                            "Coloring page missing image_data after normalization; skipping entry"
                        )
                        continue

                    all_coloring_pages.append(page)

            return (
                jsonify(
                    {
                        "coloring_pages": all_coloring_pages,
                        "count": len(all_coloring_pages),
                    }
                ),
                200,
            )

        except Exception as e:
            logger.exception("Coloring page generation failed")
            return (
                jsonify({"error": "Failed to generate coloring pages", "hint": str(e)}),
                500,
            )

    @story_bp.route("/generate-illustrations-mock", methods=["POST"])
    def generate_illustrations_mock_endpoint():
        """
        Mock illustrations endpoint for testing and development.
        Returns placeholder images instantly without calling any AI model.
        """
        import base64
        import io
        import uuid
        from datetime import datetime

        from PIL import Image, ImageDraw, ImageFont

        try:
            data = request.get_json(silent=True) or {}
            scene_description = data.get("scene_description", "A magical scene")
            character_name = data.get("character_name", "Hero")
            num_images = min(int(data.get("num_images", 1)), 4)

            logger.info(
                f"[MOCK] Generating {num_images} illustration(s) for: {scene_description[:50]}..."
            )

            illustrations = []
            for i in range(num_images):
                # Create simple placeholder image
                img = Image.new("RGB", (1024, 768), color="#FFE4B5")  # Moccasin color
                draw = ImageDraw.Draw(img)

                # Try to load font
                try:
                    font_title = ImageFont.truetype("arial.ttf", 60)
                    font_desc = ImageFont.truetype("arial.ttf", 30)
                except Exception:
                    font_title = ImageFont.load_default()
                    font_desc = font_title

                # Draw title
                title = f"Illustration {i+1}"
                bbox = draw.textbbox((0, 0), title, font=font_title)
                x = (1024 - (bbox[2] - bbox[0])) // 2
                draw.text((x, 100), title, fill="#8B4513", font=font_title)

                # Draw scene description (truncated)
                desc = (
                    scene_description[:60] + "..."
                    if len(scene_description) > 60
                    else scene_description
                )
                bbox_desc = draw.textbbox((0, 0), desc, font=font_desc)
                x_desc = (1024 - (bbox_desc[2] - bbox_desc[0])) // 2
                draw.text((x_desc, 200), desc, fill="#654321", font=font_desc)

                # Draw character name
                char_text = f"Starring: {character_name}"
                bbox_char = draw.textbbox((0, 0), char_text, font=font_desc)
                x_char = (1024 - (bbox_char[2] - bbox_char[0])) // 2
                draw.text((x_char, 300), char_text, fill="#654321", font=font_desc)

                # Draw MOCK watermark
                bbox_mock = draw.textbbox((0, 0), "MOCK ILLUSTRATION", font=font_desc)
                x_mock = (1024 - (bbox_mock[2] - bbox_mock[0])) // 2
                draw.text(
                    (x_mock, 700), "MOCK ILLUSTRATION", fill="#A0522D", font=font_desc
                )

                # Convert to base64
                buffer = io.BytesIO()
                img.save(buffer, format="PNG")
                img_base64 = base64.b64encode(buffer.getvalue()).decode("utf-8")

                illustrations.append(
                    {
                        "id": f"mock-illust-{uuid.uuid4()}",
                        "image_data": img_base64,
                        "format": "png",
                        "prompt": scene_description,
                        "generated_at": datetime.now().isoformat(),
                        "is_mock": True,
                        "cost": 0.0,
                    }
                )

            return (
                jsonify({"illustrations": illustrations, "count": len(illustrations)}),
                200,
            )

        except Exception as e:
            logger.exception(f"Error in mock illustration generation: {e}")
            return jsonify({"error": str(e)}), 500

    @story_bp.route("/generate-coloring-pages-mock", methods=["POST"])
    def generate_coloring_pages_mock_endpoint():
        """
        Mock coloring pages endpoint for testing and development.
        Returns placeholder black & white images instantly without calling any AI model.
        """
        import base64
        import io
        import uuid
        from datetime import datetime

        from PIL import Image, ImageDraw, ImageFont

        try:
            data = request.get_json(silent=True) or {}
            scene_description = data.get("scene_description", "")
            scenes = data.get("scenes", [])

            if not scenes and scene_description:
                scenes = [{"description": scene_description, "title": "Coloring Page"}]

            if not scenes:
                return (
                    jsonify({"error": "Scene description or scenes list is required"}),
                    400,
                )

            character_name = data.get("character_name", "Hero")
            num_images_per_scene = min(int(data.get("num_images", 1)), 3)

            logger.info(
                f"[MOCK] Generating {num_images_per_scene} coloring page(s) per scene, {len(scenes)} scene(s)"
            )

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
                    img = Image.new("RGB", (1024, 1024), color="white")
                    draw = ImageDraw.Draw(img)

                    # Try to load font
                    try:
                        font_title = ImageFont.truetype("arial.ttf", 50)
                        font_small = ImageFont.truetype("arial.ttf", 30)
                    except Exception:
                        font_title = ImageFont.load_default()
                        font_small = font_title

                    # Draw simple shapes (outlines only - coloring page style)
                    # Circle
                    draw.ellipse([200, 200, 400, 400], outline="black", width=5)
                    # Star shape (simplified)
                    draw.polygon(
                        [
                            (512, 100),
                            (550, 200),
                            (650, 200),
                            (570, 270),
                            (600, 370),
                            (512, 310),
                            (424, 370),
                            (454, 270),
                            (374, 200),
                            (474, 200),
                        ],
                        outline="black",
                        width=4,
                    )
                    # Rectangle with character name
                    draw.rectangle([100, 500, 924, 650], outline="black", width=5)

                    # Draw title
                    title = f"{scene_title} {i+1}"
                    bbox = draw.textbbox((0, 0), title, font=font_title)
                    x = (1024 - (bbox[2] - bbox[0])) // 2
                    draw.text((x, 700), title, fill="black", font=font_title)

                    # Draw character name
                    char_text = f"{character_name}"
                    bbox_char = draw.textbbox((0, 0), char_text, font=font_small)
                    x_char = (1024 - (bbox_char[2] - bbox_char[0])) // 2
                    draw.text((x_char, 560), char_text, fill="black", font=font_small)

                    # Draw MOCK label
                    draw.text((850, 20), "MOCK", fill="black", font=font_small)

                    # Convert to base64
                    buffer = io.BytesIO()
                    img.save(buffer, format="PNG")
                    img_base64 = base64.b64encode(buffer.getvalue()).decode("utf-8")

                    all_coloring_pages.append(
                        {
                            "id": f"mock-color-{uuid.uuid4()}",
                            "image_data": img_base64,
                            "format": "png",
                            "prompt": current_desc,
                            "scene_title": scene_title,
                            "generated_at": datetime.now().isoformat(),
                            "is_mock": True,
                            "cost": 0.0,
                        }
                    )

            return (
                jsonify(
                    {
                        "coloring_pages": all_coloring_pages,
                        "count": len(all_coloring_pages),
                    }
                ),
                200,
            )

        except Exception as e:
            logger.exception(f"Error in mock coloring page generation: {e}")
            return jsonify({"error": str(e)}), 500

    return story_bp
