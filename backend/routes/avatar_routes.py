"""
Avatar Routes - API endpoints for magical avatar generation
"""

import concurrent.futures
import logging
import os
import time

from flask import (
    Blueprint,
    after_this_request,
    current_app,
    jsonify,
    make_response,
    request,
)

_AVATAR_TIMEOUT_SECONDS = 30

# Avatar rate-limit Redis keys self-evict after slightly more than one hour so
# old hour-buckets never accumulate (S-05 memory-leak fix).
_AVATAR_RL_TTL_SECONDS = 3700

# Emitted once per process when the rate limiter falls back to the in-process
# dict, so a Redis outage is visible in logs without spamming every request.
_avatar_rl_fallback_warned = False

# Every account gets ONE free AI photo-avatar — the "magic moment" that lets a
# child see themselves as a cartoon hero; further custom avatars require a paid
# tier. Premium/BYOK users are unlimited. Enforced in generate_custom_avatar.
FREE_CUSTOM_AVATARS = 1

try:
    from backend.database import db
    from backend.middleware.auth import require_auth, require_parental_consent
    from backend.routes.subscription_routes import _user_is_premium, require_premium
    from backend.utils.app_helpers import get_user_identifier, get_user_tier
except ImportError:
    from database import db
    from middleware.auth import require_auth, require_parental_consent
    from routes.subscription_routes import _user_is_premium, require_premium
    from utils.app_helpers import get_user_identifier, get_user_tier

logger = logging.getLogger(__name__)

# Lazy import to avoid circular dependencies
_avatar_service = None


def get_avatar_service():
    """Lazy-load avatar service to avoid circular imports."""
    global _avatar_service
    if _avatar_service is None:
        from backend.services.avatar_generation_service import AvatarGenerationService

        _avatar_service = AvatarGenerationService()
    return _avatar_service


def _tier_limit(free, premium):
    """Return a dynamic limit callable for flask_limiter based on user tier."""

    def get_limit():
        tier = (get_user_tier() or "free").lower()
        if tier == "byok":
            return "10000 per hour"  # effectively unlimited
        if tier in ("premium", "family"):
            return f"{premium} per hour"
        return f"{free} per hour"

    return get_limit


def _get_avatar_rl_redis():
    """
    Return a Redis client for the avatar rate limiter, or None if Redis is not
    configured / not reachable.

    Reuses the exact connection pattern used elsewhere in the backend (the JWT
    blocklist in app.py and ``backend/utils/ai_quota._get_redis``): read
    ``REDIS_URL`` then ``REDIS_PRIVATE_URL``, build the client with
    ``redis.from_url(..., socket_connect_timeout=1)``, and verify it with a
    ``ping()`` so an unreachable Redis falls back instead of hanging.
    """
    redis_url = os.getenv("REDIS_URL") or os.getenv("REDIS_PRIVATE_URL")
    if not redis_url:
        return None
    try:
        import redis as redis_lib

        client = redis_lib.from_url(redis_url, socket_connect_timeout=1)
        client.ping()
        return client
    except Exception:
        return None


def _warn_avatar_rl_fallback(reason: str) -> None:
    """Log the in-process-fallback warning at most once per process."""
    global _avatar_rl_fallback_warned
    if not _avatar_rl_fallback_warned:
        _avatar_rl_fallback_warned = True
        logger.warning(
            "Avatar rate limiter: Redis unavailable (%s) — falling back to "
            "per-process in-memory counter. Counts will under-count across "
            "gunicorn workers.",
            reason,
        )


def _prune_stale_avatar_buckets(counts: dict, current_hour: int) -> None:
    """
    Drop in-process counter entries whose hour-bucket is older than the current
    hour. Keys are ``f"{user_key}:{hour_bucket}"``; without pruning the dict
    grows unbounded (S-05 memory-leak fix on the fallback path).
    """
    stale = []
    for key in counts:
        bucket_part = key.rsplit(":", 1)[-1]
        try:
            if int(bucket_part) < current_hour:
                stale.append(key)
        except ValueError:
            # Malformed key — drop it rather than leak it.
            stale.append(key)
    for key in stale:
        counts.pop(key, None)


def _check_avatar_rate_limit(user_key: str, limit: int) -> tuple[bool, int]:
    """
    Check and increment per-user hourly rate limit for generate-avatar.
    Increments the counter BEFORE checking, so all requests (including 400s) count.
    Returns (is_over_limit, new_count).
    Works regardless of flask-limiter's RATELIMIT_ENABLED setting.

    The counter lives in Redis (key ``avatar:rl:{user_key}:{hour_bucket}``) so
    it is shared across gunicorn workers; on the first INCR an EXPIRE of
    ~3700s is set so the key self-evicts after its hour. If Redis is not
    configured or a Redis call raises, it falls back to a per-process dict
    (pruned of stale hour-buckets so it cannot leak memory).
    """
    now = int(time.time())
    hour_bucket = now // 3600

    # --- Preferred path: shared Redis counter (cross-worker, self-evicting) ---
    redis_client = _get_avatar_rl_redis()
    if redis_client is not None:
        redis_key = f"avatar:rl:{user_key}:{hour_bucket}"
        try:
            # Increment-before-check: every request (incl. 400s) counts.
            new_count = redis_client.incr(redis_key)
            if new_count == 1:
                # First increment for this hour-bucket — arm self-eviction.
                redis_client.expire(redis_key, _AVATAR_RL_TTL_SECONDS)
            if new_count > limit:
                # Over-limit requests are rejected and must NOT be counted —
                # roll the INCR back so the counter never climbs past `limit`
                # (matches the in-process path's early-return-before-increment).
                try:
                    redis_client.decr(redis_key)
                except Exception:
                    pass
                return True, limit
            return False, new_count
        except Exception as exc:
            _warn_avatar_rl_fallback(str(exc))
            # fall through to in-process counter

    else:
        _warn_avatar_rl_fallback("REDIS_URL not configured")

    # --- Fallback path: per-process dict (pruned so it cannot leak) ---
    counter_key = f"{user_key}:{hour_bucket}"

    if not hasattr(current_app, "_avatar_generate_counts"):
        current_app._avatar_generate_counts = {}

    counts = current_app._avatar_generate_counts
    _prune_stale_avatar_buckets(counts, hour_bucket)

    current = counts.get(counter_key, 0)

    if current >= limit:
        return True, current

    counts[counter_key] = current + 1
    return False, counts[counter_key]


def _seconds_until_next_hour() -> int:
    """Seconds remaining until the next clock hour boundary."""
    now = int(time.time())
    return 3600 - (now % 3600)


def _run_with_timeout(fn, /, *args, **kwargs):
    """
    Run ``fn(*args, **kwargs)`` in a worker thread, bounded by
    ``_AVATAR_TIMEOUT_SECONDS``.

    On timeout this raises ``concurrent.futures.TimeoutError`` and returns
    *promptly* — it does NOT block waiting for the orphaned worker thread to
    finish. (MT-155: the previous ``with ThreadPoolExecutor()`` pattern's
    ``__exit__`` called ``shutdown(wait=True)``, so a 30s timeout actually
    blocked the client for the full ~110s generation runtime.)

    The executor is shut down with ``wait=False, cancel_futures=True`` so the
    request thread is released immediately; the orphaned generation thread is
    left to drain on its own. Behaviour on the success path is unchanged.
    """
    executor = concurrent.futures.ThreadPoolExecutor(max_workers=1)
    try:
        future = executor.submit(fn, *args, **kwargs)
        return future.result(timeout=_AVATAR_TIMEOUT_SECONDS)
    finally:
        # wait=False: do NOT block on the (possibly still-running) worker.
        # cancel_futures=True: drop any not-yet-started work (Python 3.9+).
        executor.shutdown(wait=False, cancel_futures=True)


def _is_valid_image(image_bytes: bytes) -> bool:
    """
    Validate uploaded image data by inspecting magic bytes.

    Accepts only PNG, JPEG, WebP and GIF — prevents a client from uploading
    a non-image (e.g. HTML, SVG, an executable) by relabelling the form field.
    """
    if not image_bytes or len(image_bytes) < 12:
        return False
    if image_bytes.startswith(b"\x89PNG\r\n\x1a\n"):
        return True
    if image_bytes.startswith(b"\xff\xd8\xff"):
        return True
    if image_bytes.startswith(b"RIFF") and image_bytes[8:12] == b"WEBP":
        return True
    if image_bytes.startswith((b"GIF87a", b"GIF89a")):
        return True
    return False


def create_avatar_blueprint(limiter):
    avatar_bp = Blueprint("avatar", __name__)

    @avatar_bp.route("/generate-custom-avatar", methods=["POST"])
    @require_auth
    @require_parental_consent
    @limiter.limit(_tier_limit(free=3, premium=20))
    def generate_custom_avatar():
        """
        Generate a custom magical avatar based on a child's photo and preferences.
        Expects multipart/form-data with:
        - photo: Image file
        - character_name: str
        - age: int
        - gender: 'boy' | 'girl'
        - eye_color: str
        - favorite_color: str
        """
        try:
            # Check if photo is present
            if "photo" not in request.files:
                return (
                    jsonify(
                        {
                            "status": "error",
                            "error_code": "MISSING_PHOTO",
                            "message": "Photo is required",
                        }
                    ),
                    400,
                )

            photo_file = request.files["photo"]
            _MAX_PHOTO_BYTES = 10 * 1024 * 1024  # 10 MB
            photo_bytes = photo_file.read(_MAX_PHOTO_BYTES + 1)
            if len(photo_bytes) > _MAX_PHOTO_BYTES:
                return (
                    jsonify(
                        {
                            "status": "error",
                            "error_code": "PHOTO_TOO_LARGE",
                            "message": "Photo must be under 10 MB",
                        }
                    ),
                    413,
                )

            if not _is_valid_image(photo_bytes):
                return (
                    jsonify(
                        {
                            "status": "error",
                            "error_code": "INVALID_PHOTO",
                            "message": "Uploaded file is not a valid image (PNG, JPEG, WebP or GIF)",
                        }
                    ),
                    400,
                )

            # Extract other data from form
            character_name = request.form.get("character_name")
            age = request.form.get("age")
            gender = request.form.get("gender")
            eye_color = request.form.get("eye_color")
            favorite_color = request.form.get("favorite_color")
            refinement_note = (
                request.form.get("refinement_note") or ""
            ).strip() or None

            # Refinement is BYOK-only: one free API call is expensive; BYOK users
            # supply their own key so the cost falls on them.
            if refinement_note:
                tier = (get_user_tier() or "free").lower()
                if tier != "byok":
                    return (
                        jsonify(
                            {
                                "status": "error",
                                "error_code": "BYOK_REQUIRED",
                                "message": "Avatar refinement is available for BYOK subscribers. "
                                "Set up your own API key in Parent Controls to unlock this.",
                            }
                        ),
                        403,
                    )

            # Basic validation
            if not all([character_name, age, gender, eye_color, favorite_color]):
                return (
                    jsonify(
                        {
                            "status": "error",
                            "error_code": "MISSING_DATA",
                            "message": "All fields (character_name, age, gender, eye_color, favorite_color) are required",
                        }
                    ),
                    400,
                )

            try:
                age = int(age)
            except ValueError:
                return (
                    jsonify(
                        {
                            "status": "error",
                            "error_code": "INVALID_AGE",
                            "message": "Age must be a number",
                        }
                    ),
                    400,
                )

            # 1-free-avatar gate: every account gets one free AI photo-avatar
            # (the "magic moment"); after that it is a premium feature.
            # Enforced server-side so a tampered client cannot bypass it.
            current_user = request.current_user
            if not _user_is_premium(current_user):
                used = current_user.custom_avatars_generated or 0
                if used >= FREE_CUSTOM_AVATARS:
                    # Funnel instrumentation (MT-249): the child hit the
                    # 1-free-avatar gate — the primary paywall trigger. Recorded
                    # best-effort; record_event never raises into this handler.
                    try:
                        from backend.services.event_tracking_service import (
                            record_event,
                        )
                    except ImportError:
                        from services.event_tracking_service import record_event

                    record_event(
                        "avatar_limit_hit",
                        user_id=getattr(current_user, "id", None),
                        tier=(get_user_tier() or "free").lower(),
                        metadata={"used": used, "limit": FREE_CUSTOM_AVATARS},
                    )
                    return (
                        jsonify(
                            {
                                "status": "error",
                                "error_code": "UPGRADE_REQUIRED",
                                "message": "You've already created your free magic avatar! "
                                "Upgrade to premium to create more.",
                            }
                        ),
                        403,
                    )

            logger.info(
                f"Custom avatar request: name={character_name}, age={age}, gender={gender}"
            )

            service = get_avatar_service()

            try:
                avatar_data = _run_with_timeout(
                    service.generate_custom_avatar,
                    character_name=character_name,
                    age=age,
                    gender=gender,
                    eye_color=eye_color,
                    favorite_color=favorite_color,
                    photo_bytes=photo_bytes,
                    refinement_note=refinement_note,
                )

                logger.info(
                    f"Custom avatar generated successfully: {avatar_data['id']}"
                )

                # Count this generation against the 1-free allowance. Only
                # non-premium users are metered; premium/BYOK are unlimited.
                if not _user_is_premium(current_user):
                    current_user.custom_avatars_generated = (
                        current_user.custom_avatars_generated or 0
                    ) + 1
                    db.session.commit()

                return jsonify({"status": "success", "avatar": avatar_data}), 200

            except concurrent.futures.TimeoutError:
                logger.warning("Custom avatar generation timed out")
                return (
                    jsonify(
                        {
                            "status": "error",
                            "error_code": "TIMEOUT",
                            "message": get_error_message("timeout"),
                        }
                    ),
                    504,
                )

            except ValueError as e:
                logger.warning(f"Custom avatar validation error: {e}")
                return (
                    jsonify(
                        {
                            "status": "error",
                            "error_code": "VALIDATION_ERROR",
                            "message": str(e),
                        }
                    ),
                    400,
                )

            except Exception as e:
                logger.error(f"Custom avatar generation failed: {e}")
                return (
                    jsonify(
                        {
                            "status": "error",
                            "error_code": "GENERATION_FAILED",
                            "message": get_error_message("generation_failed"),
                        }
                    ),
                    500,
                )

        except Exception as e:
            logger.exception(
                f"Unexpected error in generate_custom_avatar endpoint: {e}"
            )
            return (
                jsonify(
                    {
                        "status": "error",
                        "error_code": "INTERNAL_ERROR",
                        "message": "Something magical went wrong! Let's try again! ✨",
                    }
                ),
                500,
            )

    @avatar_bp.route("/transform-superhero", methods=["POST"])
    @require_auth
    @require_premium  # Re-rendering the avatar is an image-gen cost; paid feature.
    @require_parental_consent
    @limiter.limit(_tier_limit(free=0, premium=20))
    def transform_superhero():
        """Re-render an existing child avatar as a superhero portrait.

        Expects multipart/form-data with:
        - photo: the child's existing avatar image (PNG/JPEG/WebP/GIF)
        - costume_color, cape_style, emblem, power: optional choice ids from the
          Flutter superhero flow (superhero_costume_screen / superhero_power_screen).

        Returns the same envelope shape as ``/generate-custom-avatar``:
        ``{"status": "success", "avatar": {... "image_base64": "data:image/png;..."}}``.
        """
        try:
            if "photo" not in request.files:
                return (
                    jsonify(
                        {
                            "status": "error",
                            "error_code": "MISSING_PHOTO",
                            "message": "An existing avatar photo is required",
                        }
                    ),
                    400,
                )

            photo_file = request.files["photo"]
            _MAX_PHOTO_BYTES = 10 * 1024 * 1024  # 10 MB
            photo_bytes = photo_file.read(_MAX_PHOTO_BYTES + 1)
            if len(photo_bytes) > _MAX_PHOTO_BYTES:
                return (
                    jsonify(
                        {
                            "status": "error",
                            "error_code": "PHOTO_TOO_LARGE",
                            "message": "Photo must be under 10 MB",
                        }
                    ),
                    413,
                )

            if not _is_valid_image(photo_bytes):
                return (
                    jsonify(
                        {
                            "status": "error",
                            "error_code": "INVALID_PHOTO",
                            "message": "Uploaded file is not a valid image (PNG, JPEG, WebP or GIF)",
                        }
                    ),
                    400,
                )

            costume_color = request.form.get("costume_color")
            cape_style = request.form.get("cape_style")
            emblem = request.form.get("emblem")
            power = request.form.get("power")

            logger.info(
                "Superhero transform request: color=%s cape=%s emblem=%s power=%s",
                costume_color,
                cape_style,
                emblem,
                power,
            )

            service = get_avatar_service()
            try:
                portrait = _run_with_timeout(
                    service.transform_to_superhero,
                    photo_bytes,
                    costume_color=costume_color,
                    cape_style=cape_style,
                    emblem=emblem,
                    power=power,
                )
                return jsonify({"status": "success", "avatar": portrait}), 200

            except concurrent.futures.TimeoutError:
                logger.warning("Superhero transform timed out")
                return (
                    jsonify(
                        {
                            "status": "error",
                            "error_code": "TIMEOUT",
                            "message": get_error_message("timeout"),
                        }
                    ),
                    504,
                )

            except Exception as e:
                logger.error(f"Superhero transform failed: {e}")
                return (
                    jsonify(
                        {
                            "status": "error",
                            "error_code": "GENERATION_FAILED",
                            "message": get_error_message("generation_failed"),
                        }
                    ),
                    500,
                )

        except Exception as e:
            logger.exception(f"Unexpected error in transform_superhero endpoint: {e}")
            return (
                jsonify(
                    {
                        "status": "error",
                        "error_code": "INTERNAL_ERROR",
                        "message": "Something magical went wrong! Let's try again! ✨",
                    }
                ),
                500,
            )

    @avatar_bp.route("/generate-pet-avatar", methods=["POST"])
    @require_auth
    @require_premium  # M-8: photo->cartoon companion creation is a premium capability (image-gen cost)
    @require_parental_consent
    @limiter.limit(_tier_limit(free=3, premium=20))
    def generate_pet_avatar():
        """
        Generate a magical pet companion avatar based on a pet's photo and metadata.
        Expects multipart/form-data with:
        - photo: Image file
        - pet_name: str
        - species: str
        - breed_description: str
        - owner_favorite_color: str
        """
        try:
            # Check if photo is present
            if "photo" not in request.files:
                return (
                    jsonify(
                        {
                            "status": "error",
                            "error_code": "MISSING_PHOTO",
                            "message": "Photo is required",
                        }
                    ),
                    400,
                )

            # Extract other data from form
            pet_name = request.form.get("pet_name")
            species = request.form.get("species")
            breed_description = request.form.get("breed_description")
            owner_favorite_color = request.form.get("owner_favorite_color")
            owner_age = request.form.get("owner_age", "0")
            companion_type = request.form.get(
                "companion_type", "pet"
            )  # 'human' or 'pet'

            # Basic validation — required-field check runs BEFORE the photo
            # magic-byte validation so a request missing metadata gets the
            # more specific MISSING_DATA error rather than INVALID_PHOTO (L-3).
            if not all([pet_name, species, breed_description, owner_favorite_color]):
                return (
                    jsonify(
                        {
                            "status": "error",
                            "error_code": "MISSING_DATA",
                            "message": "All fields (pet_name, species, breed_description, owner_favorite_color) are required",
                        }
                    ),
                    400,
                )

            photo_file = request.files["photo"]
            _MAX_PHOTO_BYTES = 10 * 1024 * 1024  # 10 MB
            photo_bytes = photo_file.read(_MAX_PHOTO_BYTES + 1)
            if len(photo_bytes) > _MAX_PHOTO_BYTES:
                return (
                    jsonify(
                        {
                            "status": "error",
                            "error_code": "PHOTO_TOO_LARGE",
                            "message": "Photo must be under 10 MB",
                        }
                    ),
                    413,
                )

            if not _is_valid_image(photo_bytes):
                return (
                    jsonify(
                        {
                            "status": "error",
                            "error_code": "INVALID_PHOTO",
                            "message": "Uploaded file is not a valid image (PNG, JPEG, WebP or GIF)",
                        }
                    ),
                    400,
                )

            try:
                owner_age = int(owner_age)
            except (ValueError, TypeError):
                owner_age = 0

            logger.info(
                f"Companion avatar request: name={pet_name}, species={species}, type={companion_type}, owner_age={owner_age}"
            )

            service = get_avatar_service()

            try:

                def _run_companion():
                    if companion_type == "human":
                        return service.generate_human_companion_avatar(
                            name=pet_name,
                            appearance_description=breed_description,
                            owner_favorite_color=owner_favorite_color,
                            photo_bytes=photo_bytes,
                            owner_age=owner_age,
                        )
                    return service.generate_pet_avatar(
                        pet_name=pet_name,
                        species=species,
                        breed_description=breed_description,
                        owner_favorite_color=owner_favorite_color,
                        photo_bytes=photo_bytes,
                        owner_age=owner_age,
                    )

                avatar_data = _run_with_timeout(_run_companion)

                logger.info(
                    f"Companion avatar generated successfully: {avatar_data['id']} (type={companion_type})"
                )

                provider_used = avatar_data.get("provider_used")
                transformation_applied = avatar_data.get("transformation_applied", True)
                status_code = 200 if transformation_applied else 206

                return (
                    jsonify(
                        {
                            "status": "success",
                            "avatar": avatar_data,
                            "provider_used": provider_used,
                            "transformation_applied": transformation_applied,
                        }
                    ),
                    status_code,
                )

            except concurrent.futures.TimeoutError:
                logger.warning("Companion avatar generation timed out")
                return (
                    jsonify(
                        {
                            "status": "error",
                            "error_code": "TIMEOUT",
                            "message": get_error_message("timeout"),
                        }
                    ),
                    504,
                )

            except ValueError as e:
                # Raised by input validation and by the assembled-prompt
                # safety check — reject with a clear 400, never proceed.
                logger.warning(f"Pet/companion avatar validation error: {e}")
                return (
                    jsonify(
                        {
                            "status": "error",
                            "error_code": "VALIDATION_ERROR",
                            "message": str(e),
                        }
                    ),
                    400,
                )

            except Exception as e:
                logger.error(f"Pet avatar generation failed: {e}")
                return (
                    jsonify(
                        {
                            "status": "error",
                            "error_code": "GENERATION_FAILED",
                            "message": get_error_message("generation_failed"),
                        }
                    ),
                    500,
                )

        except Exception as e:
            logger.exception(f"Unexpected error in generate_pet_avatar endpoint: {e}")
            return (
                jsonify(
                    {
                        "status": "error",
                        "error_code": "INTERNAL_ERROR",
                        "message": "Something magical went wrong! Let's try again! ✨",
                    }
                ),
                500,
            )

    @avatar_bp.route("/generate-avatar", methods=["POST"])
    @require_auth
    @require_parental_consent
    def generate_avatar():
        """
        Generate a magical avatar for a child character.

        Request Body:
        {
            "character_name": str (required),
            "age": int (required, 3-17),
            "style": str (optional, default: "pixar"),
            "features": {
                "hair_style": str (optional),
                "hair_color": str (optional),
                "skin_tone": str (optional),
                "outfit": str (optional),
                "expression": str (optional)
            },
            "emotion_data": {
                "core": str (optional),
                "secondary": str (optional),
                "eye_type": str (optional),
                "mouth_type": str (optional),
                "intensity": int (optional, 1-5)
            },
            "seed": str (optional, for re-generation)
        }

        Response:
        {
            "status": "success",
            "avatar": {
                "id": str,
                "image_base64": str,
                "seed": str,
                "style": str,
                "attributes": {...},
                "emotion_data": {...},
                "generated_at": str (ISO),
                "generation_time_ms": int
            }
        }

        Error Response:
        {
            "status": "error",
            "error_code": str,
            "message": str,
            "fallback_avatars": [...]
        }
        """
        # Manual per-user hourly rate limiting (independent of flask-limiter enabled state).
        # Counts ALL requests (including validation failures) so the limit is meaningful.
        tier = (get_user_tier() or "free").lower()
        if tier == "byok":
            rate_limit = None
        elif tier in ("premium", "family"):
            rate_limit = 50
        else:
            rate_limit = 5

        if rate_limit is not None:
            user_key = get_user_identifier()
            is_limited, _ = _check_avatar_rate_limit(user_key, rate_limit)

            if is_limited:
                resp = make_response(
                    jsonify(
                        {
                            "error_code": "RATE_LIMIT_EXCEEDED",
                            "limit_per_hour": rate_limit,
                            "retry_after_seconds": _seconds_until_next_hour(),
                        }
                    ),
                    429,
                )
                resp.headers["X-Avatar-RateLimit-Tier"] = tier
                return resp

            # Attach rate-limit headers to every non-429 response for this request.
            _rl_tier = tier
            _rl_limit = rate_limit

            @after_this_request
            def _add_rate_limit_headers(response):
                response.headers["X-Avatar-RateLimit-Limit"] = str(_rl_limit)
                response.headers["X-Avatar-RateLimit-Tier"] = _rl_tier
                return response

        try:
            # Get request data
            data = request.get_json()

            if not data:
                return (
                    jsonify(
                        {
                            "status": "error",
                            "error_code": "INVALID_REQUEST",
                            "message": "Request body is required",
                        }
                    ),
                    400,
                )

            # Extract and validate required fields
            character_name = data.get("character_name")
            age = data.get("age")

            if not character_name or not character_name.strip():
                return (
                    jsonify(
                        {
                            "status": "error",
                            "error_code": "MISSING_CHARACTER_NAME",
                            "message": "Character name is required",
                        }
                    ),
                    400,
                )

            if age is None or not isinstance(age, int):
                return (
                    jsonify(
                        {
                            "status": "error",
                            "error_code": "INVALID_AGE",
                            "message": get_error_message("invalid_age"),
                        }
                    ),
                    400,
                )

            if not (3 <= age <= 99):
                return (
                    jsonify(
                        {
                            "status": "error",
                            "error_code": "AGE_OUT_OF_RANGE",
                            "message": get_error_message("invalid_age"),
                        }
                    ),
                    400,
                )

            # Extract optional fields
            style = data.get("style", "pixar").lower()
            features = data.get("features", {})
            emotion_data = data.get("emotion_data")
            seed = data.get("seed")

            # Validate style
            valid_styles = ["pixar", "watercolor", "cartoon", "clay"]
            if style not in valid_styles:
                return (
                    jsonify(
                        {
                            "status": "error",
                            "error_code": "INVALID_STYLE",
                            "message": get_error_message("invalid_style"),
                            "valid_styles": valid_styles,
                        }
                    ),
                    400,
                )

            logger.info(
                f"Avatar generation request: name={character_name}, age={age}, style={style}"
            )

            # Get avatar service and generate
            service = get_avatar_service()

            try:
                avatar_data = _run_with_timeout(
                    service.generate_avatar,
                    character_name=character_name,
                    age=age,
                    style=style,
                    features=features,
                    emotion_data=emotion_data,
                    seed=seed,
                )

                logger.info(f"Avatar generated successfully: {avatar_data['id']}")

                return jsonify({"status": "success", "avatar": avatar_data}), 200

            except concurrent.futures.TimeoutError:
                logger.warning("Avatar generation timed out")
                fallback_avatars = service.get_fallback_avatars(style)
                return (
                    jsonify(
                        {
                            "status": "error",
                            "error_code": "TIMEOUT",
                            "message": get_error_message("timeout"),
                            "fallback_avatars": fallback_avatars,
                        }
                    ),
                    504,
                )

            except ValueError as ve:
                logger.warning(f"Avatar validation error: {ve}")
                return (
                    jsonify(
                        {
                            "status": "error",
                            "error_code": "VALIDATION_ERROR",
                            "message": str(ve),
                        }
                    ),
                    400,
                )

            except Exception as e:
                logger.error(f"Avatar generation failed: {e}")
                fallback_avatars = service.get_fallback_avatars(style)
                return (
                    jsonify(
                        {
                            "status": "error",
                            "error_code": "GENERATION_FAILED",
                            "message": get_error_message("generation_failed"),
                            "fallback_avatars": fallback_avatars,
                        }
                    ),
                    500,
                )

        except Exception as e:
            logger.exception(f"Unexpected error in generate_avatar endpoint: {e}")
            return (
                jsonify(
                    {
                        "status": "error",
                        "error_code": "INTERNAL_ERROR",
                        "message": "Something magical went wrong! Let's try again! ✨",
                    }
                ),
                500,
            )

    @avatar_bp.route("/regenerate-avatar", methods=["POST"])
    @require_auth
    @require_parental_consent
    @limiter.limit(_tier_limit(free=3, premium=30))
    def regenerate_avatar():
        """
        Regenerate an avatar using an existing seed (for "re-roll" functionality).

        Request Body:
        {
            "seed": str (required),
            "character_name": str (required),
            "age": int (required),
            "style": str (required),
            "features": {...} (required),
            "variation": bool (optional, default: true)
        }

        Response: Same as /generate-avatar
        """
        try:
            data = request.get_json()

            if not data:
                return (
                    jsonify(
                        {
                            "status": "error",
                            "error_code": "INVALID_REQUEST",
                            "message": "Request body is required",
                        }
                    ),
                    400,
                )

            # For re-roll, we generate a new avatar with the same parameters
            # This gives similar but different results
            character_name = data.get("character_name")
            age = data.get("age")
            style = data.get("style", "pixar")
            features = data.get("features", {})
            emotion_data = data.get("emotion_data")

            # Don't use the seed for re-roll - let it generate a new one
            # This creates variation while keeping same character attributes

            logger.info(
                f"Avatar re-roll request: name={character_name}, age={age}, style={style}"
            )

            service = get_avatar_service()

            try:
                avatar_data = _run_with_timeout(
                    service.generate_avatar,
                    character_name=character_name,
                    age=age,
                    style=style,
                    features=features,
                    emotion_data=emotion_data,
                    seed=None,
                )

                logger.info(f"Avatar re-rolled successfully: {avatar_data['id']}")

                return jsonify({"status": "success", "avatar": avatar_data}), 200

            except concurrent.futures.TimeoutError:
                logger.warning("Avatar re-roll timed out")
                fallback_avatars = service.get_fallback_avatars(style)
                return (
                    jsonify(
                        {
                            "status": "error",
                            "error_code": "TIMEOUT",
                            "message": get_error_message("timeout"),
                            "fallback_avatars": fallback_avatars,
                        }
                    ),
                    504,
                )

            except Exception as e:
                logger.error(f"Avatar re-roll failed: {e}")
                fallback_avatars = service.get_fallback_avatars(style)
                return (
                    jsonify(
                        {
                            "status": "error",
                            "error_code": "REGENERATION_FAILED",
                            "message": get_error_message("generation_failed"),
                            "fallback_avatars": fallback_avatars,
                        }
                    ),
                    500,
                )

        except Exception as e:
            logger.exception(f"Unexpected error in regenerate_avatar endpoint: {e}")
            return (
                jsonify(
                    {
                        "status": "error",
                        "error_code": "INTERNAL_ERROR",
                        "message": "Something magical went wrong! Let's try again! ✨",
                    }
                ),
                500,
            )

    @avatar_bp.route("/fallback-avatars", methods=["GET"])
    def get_fallback_avatars():
        """
        Get list of fallback preset avatars.

        Query Parameters:
            style: Optional style filter (pixar|watercolor|cartoon|clay)

        Response:
        {
            "status": "success",
            "fallback_avatars": [
                {
                    "id": str,
                    "style": str,
                    "preview_url": str
                },
                ...
            ]
        }
        """
        try:
            style = request.args.get("style")

            service = get_avatar_service()
            fallback_avatars = service.get_fallback_avatars(style)

            return (
                jsonify({"status": "success", "fallback_avatars": fallback_avatars}),
                200,
            )

        except Exception as e:
            logger.exception(f"Error getting fallback avatars: {e}")
            return (
                jsonify(
                    {
                        "status": "error",
                        "error_code": "INTERNAL_ERROR",
                        "message": "Could not load fallback avatars",
                    }
                ),
                500,
            )

    @avatar_bp.route("/health", methods=["GET"])
    def health_check():
        """Health check endpoint for avatar service."""
        try:
            service = get_avatar_service()

            # Check if image generator is available
            has_generator = service.image_generator is not None

            return (
                jsonify(
                    {
                        "status": "healthy",
                        "avatar_service": "ready",
                        "image_generator": "ready" if has_generator else "unavailable",
                    }
                ),
                200,
            )

        except Exception as e:
            logger.exception(f"Health check failed: {e}")
            return jsonify({"status": "unhealthy", "error": str(e)}), 500

    @avatar_bp.route("/tweak-gallery-avatar", methods=["POST"])
    @require_auth
    @require_parental_consent
    @limiter.limit(_tier_limit(free=1, premium=5))
    def tweak_gallery_avatar():
        """
        Edit a curated gallery avatar (premium-only).
        Multipart form: image (WebP bytes), hair_length (opt), eye_color (opt).
        """
        # This feature is premium/byok only
        tier = (get_user_tier() or "free").lower()
        if tier not in ("premium", "family", "byok"):
            return (
                jsonify(
                    {
                        "status": "error",
                        "error_code": "PREMIUM_REQUIRED",
                        "message": "Gallery avatar tweaking requires a premium subscription",
                    }
                ),
                403,
            )

        try:
            if "image" not in request.files:
                return (
                    jsonify(
                        {
                            "status": "error",
                            "error_code": "MISSING_IMAGE",
                            "message": "Avatar image is required",
                        }
                    ),
                    400,
                )

            _MAX_IMAGE_BYTES = 10 * 1024 * 1024  # 10 MB
            image_bytes = request.files["image"].read(_MAX_IMAGE_BYTES + 1)
            if len(image_bytes) > _MAX_IMAGE_BYTES:
                return (
                    jsonify(
                        {
                            "status": "error",
                            "error_code": "IMAGE_TOO_LARGE",
                            "message": "Avatar image must be under 10 MB",
                        }
                    ),
                    413,
                )

            if not _is_valid_image(image_bytes):
                return (
                    jsonify(
                        {
                            "status": "error",
                            "error_code": "INVALID_IMAGE",
                            "message": "Uploaded file is not a valid image (PNG, JPEG, WebP or GIF)",
                        }
                    ),
                    400,
                )

            hair_length = request.form.get("hair_length") or None
            eye_color = request.form.get("eye_color") or None

            if not hair_length and not eye_color:
                return (
                    jsonify(
                        {
                            "status": "error",
                            "error_code": "NO_CHANGES",
                            "message": "Please choose at least one thing to change (hair length or eye color)",
                        }
                    ),
                    400,
                )

            logger.info(
                f"Gallery avatar tweak: hair_length={hair_length}, eye_color={eye_color}"
            )

            # MT-327: this previously built a direct GeminiImageGenerator() on
            # the server key, bypassing the prod DISABLE_GEMINI_IMAGE=1 kill
            # switch (Gemini's ToS forbid child-directed apps). Route through
            # the shared AvatarGenerationService like every other avatar
            # endpoint so the same provider gating applies here.
            service = get_avatar_service()
            generator = service.image_generator
            if generator is None or not hasattr(generator, "tweak_gallery_avatar"):
                logger.warning(
                    "Gallery avatar tweak: no eligible image generator configured"
                )
                return (
                    jsonify(
                        {
                            "status": "error",
                            "error_code": "GENERATION_FAILED",
                            "message": get_error_message("generation_failed"),
                        }
                    ),
                    500,
                )
            try:
                images = _run_with_timeout(
                    generator.tweak_gallery_avatar,
                    image_bytes=image_bytes,
                    hair_length=hair_length,
                    eye_color=eye_color,
                )
            except concurrent.futures.TimeoutError:
                logger.warning("Gallery avatar tweak timed out")
                return (
                    jsonify(
                        {
                            "status": "error",
                            "error_code": "TIMEOUT",
                            "message": get_error_message("timeout"),
                        }
                    ),
                    504,
                )

            if not images:
                return (
                    jsonify(
                        {
                            "status": "error",
                            "error_code": "GENERATION_FAILED",
                            "message": get_error_message("generation_failed"),
                        }
                    ),
                    500,
                )

            return (
                jsonify(
                    {
                        "status": "success",
                        "tweaked_image_base64": images[0]["image_data"],
                    }
                ),
                200,
            )

        except Exception as e:
            logger.exception(f"Unexpected error in tweak_gallery_avatar: {e}")
            return (
                jsonify(
                    {
                        "status": "error",
                        "error_code": "INTERNAL_ERROR",
                        "message": "Something magical went wrong! Let's try again! ✨",
                    }
                ),
                500,
            )

    @avatar_bp.route("/generate-avatar-mock", methods=["POST"])
    def generate_avatar_mock():
        """
        Mock avatar generation endpoint for testing and development.

        Returns a simple placeholder avatar instantly without calling any AI model.
        Perfect for development, testing, and staying within API quotas.

        Request/Response: Same format as /generate-avatar
        """
        import uuid
        from datetime import datetime

        try:
            data = request.get_json()

            if not data:
                return (
                    jsonify(
                        {
                            "status": "error",
                            "error_code": "INVALID_REQUEST",
                            "message": "Request body is required",
                        }
                    ),
                    400,
                )

            character_name = data.get("character_name", "Hero")
            age = data.get("age", 7)
            style = data.get("style", "pixar").lower()
            features = data.get("features", {})
            emotion_data = data.get("emotion_data", {})

            logger.info(
                f"[MOCK] Generating avatar for {character_name}, age {age}, style {style}"
            )

            # Generate mock placeholder image
            img_base64 = _generate_mock_placeholder_avatar(character_name, age, style)

            # Return same structure as real endpoint
            avatar_id = str(uuid.uuid4())
            seed = f"mock-{avatar_id[:8]}"

            avatar_data = {
                "id": avatar_id,
                "image_base64": img_base64,
                "seed": seed,
                "style": style,
                "attributes": {
                    "character_name": character_name,
                    "age": age,
                    **features,
                },
                "emotion_data": emotion_data,
                "generated_at": datetime.now().isoformat(),
                "generation_time_ms": 1,  # Instant!
                "is_mock": True,  # Flag to indicate this is mock data
                "cost": 0.0,  # Free!
            }

            return jsonify({"status": "success", "avatar": avatar_data}), 200

        except Exception as e:
            logger.exception(f"Error in mock avatar generation: {e}")
            return (
                jsonify(
                    {"status": "error", "error_code": "MOCK_ERROR", "message": str(e)}
                ),
                500,
            )

    return avatar_bp


# Error messages
ERROR_MESSAGES = {
    "generation_failed": "Oops! Our magic paintbrush needs a moment. Let's try a different magic spell! ✨",
    "timeout": "The magic is taking longer than usual. Want to try a quick starter avatar instead? 🎨",
    "safety_trigger": "Let's try different magic words to create your perfect avatar! 🌟",
    "rate_limit": "You've created lots of magic today! Let's pick from our special collection! 🎁",
    "invalid_style": "That magic style isn't available yet! Let's try Pixar, Watercolor, Cartoon, or Clay! 🎭",
    "invalid_age": "Hmm, that age doesn't seem right. Can you check it? 🤔",
    "no_generator": "Our magic art studio is taking a quick break. Try again in a moment! 🎨",
}


def get_error_message(error_code: str) -> str:
    """Get kid-friendly error message for error code."""
    return ERROR_MESSAGES.get(
        error_code, "Something magical went wrong! Let's try again! ✨"
    )


def _generate_mock_placeholder_avatar(
    character_name: str, age: int, style: str = "pixar"
) -> str:
    """
    Generate a simple placeholder avatar image as base64.

    Creates a colored square with the character's initial and age.
    This is for testing and development - no API calls, instant response.
    """
    import base64
    import io

    from PIL import Image, ImageDraw, ImageFont

    # Color schemes by style
    colors = {
        "pixar": ("#4A90E2", "#FFFFFF"),  # Blue background, white text
        "watercolor": ("#B8E6B8", "#2C5F2C"),  # Soft green, dark green text
        "cartoon": ("#FFB6C1", "#8B008B"),  # Pink, dark magenta text
        "clay": ("#D2B48C", "#8B4513"),  # Tan, saddle brown text
    }

    bg_color, text_color = colors.get(style, colors["pixar"])

    # Create image
    img = Image.new("RGB", (512, 512), color=bg_color)
    draw = ImageDraw.Draw(img)

    # Add character initial and age
    initial = character_name[0].upper() if character_name else "?"

    # Try to use a nice font, fall back to default
    try:
        font = ImageFont.truetype("arial.ttf", 180)
        font_small = ImageFont.truetype("arial.ttf", 80)
    except Exception:
        font = ImageFont.load_default()
        font_small = font

    # Draw text centered
    bbox = draw.textbbox((0, 0), initial, font=font)
    text_width = bbox[2] - bbox[0]
    text_height = bbox[3] - bbox[1]
    position = ((512 - text_width) // 2, (512 - text_height) // 2 - 40)
    draw.text(position, initial, fill=text_color, font=font)

    # Draw age below
    age_text = f"Age {age}"
    bbox_age = draw.textbbox((0, 0), age_text, font=font_small)
    age_width = bbox_age[2] - bbox_age[0]
    age_position = ((512 - age_width) // 2, position[1] + 200)
    draw.text(age_position, age_text, fill=text_color, font=font_small)

    # Add "MOCK" watermark
    mock_bbox = draw.textbbox((0, 0), "MOCK", font=font_small)
    mock_width = mock_bbox[2] - mock_bbox[0]
    draw.text(((512 - mock_width) // 2, 420), "MOCK", fill=text_color, font=font_small)

    # Convert to base64
    buffer = io.BytesIO()
    img.save(buffer, format="PNG")
    img_base64 = base64.b64encode(buffer.getvalue()).decode("utf-8")

    return img_base64
