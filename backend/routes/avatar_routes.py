"""
Avatar Routes - API endpoints for magical avatar generation
"""
from flask import Blueprint, request, jsonify, make_response
import logging
from functools import wraps
import threading
import time

try:
    from backend.utils.app_helpers import get_user_tier, get_user_identifier
    from backend.middleware.auth import require_auth
except ImportError:
    from utils.app_helpers import get_user_tier, get_user_identifier
    from middleware.auth import require_auth

logger = logging.getLogger(__name__)

# Create blueprint
avatar_bp = Blueprint('avatar', __name__)

# Lazy import to avoid circular dependencies
_avatar_service = None
_RATE_LIMIT_WINDOW_SECONDS = 3600
_rate_limit_hits = {}
_rate_limit_lock = threading.Lock()


def _resolve_hourly_limit(user_tier: str, free: int, premium: int, byok):
    """Resolve hourly limit for a user tier."""
    tier = (user_tier or 'free').lower()
    if tier == 'byok':
        return byok
    if tier in ('premium', 'family'):
        return premium
    return free


def get_avatar_service():
    """Lazy-load avatar service to avoid circular imports."""
    global _avatar_service
    if _avatar_service is None:
        from backend.services.avatar_generation_service import AvatarGenerationService
        _avatar_service = AvatarGenerationService()
    return _avatar_service


def rate_limit_by_user_tier(free=5, premium=50, byok=None):
    """
    Rate limiting decorator for avatar generation.

    Args:
        free: Requests per hour for free tier users
        premium: Requests per hour for premium users
        byok: Requests per hour for BYOK users (None = unlimited)
    """
    def decorator(f):
        @wraps(f)
        def wrapped(*args, **kwargs):
            user_tier = get_user_tier()
            resolved_limit = _resolve_hourly_limit(user_tier, free, premium, byok)

            # Unlimited tier (e.g., BYOK when byok=None)
            if resolved_limit is None:
                return f(*args, **kwargs)

            now = time.time()
            key = f"{request.endpoint}:{get_user_identifier()}:{(user_tier or 'free').lower()}"

            with _rate_limit_lock:
                hits = _rate_limit_hits.setdefault(key, [])
                cutoff = now - _RATE_LIMIT_WINDOW_SECONDS
                hits[:] = [ts for ts in hits if ts > cutoff]

                if len(hits) >= int(resolved_limit):
                    retry_after = _RATE_LIMIT_WINDOW_SECONDS if not hits else int(max(1, _RATE_LIMIT_WINDOW_SECONDS - (now - hits[0])))
                    rate_limited_response = make_response(jsonify({
                        'status': 'error',
                        'error_code': 'RATE_LIMIT_EXCEEDED',
                        'message': get_error_message('rate_limit'),
                        'user_tier': user_tier or 'free',
                        'limit_per_hour': int(resolved_limit),
                        'retry_after_seconds': retry_after
                    }), 429)
                    rate_limited_response.headers['X-Avatar-RateLimit-Limit'] = str(int(resolved_limit))
                    rate_limited_response.headers['X-Avatar-RateLimit-Remaining'] = "0"
                    rate_limited_response.headers['X-Avatar-RateLimit-Reset'] = str(retry_after)
                    rate_limited_response.headers['X-Avatar-RateLimit-Tier'] = (user_tier or 'free').lower()
                    return rate_limited_response

                hits.append(now)
                remaining = max(0, int(resolved_limit) - len(hits))
                reset_in = int(max(1, _RATE_LIMIT_WINDOW_SECONDS - (now - hits[0])))

            response = make_response(f(*args, **kwargs))
            response.headers['X-Avatar-RateLimit-Limit'] = str(int(resolved_limit))
            response.headers['X-Avatar-RateLimit-Remaining'] = str(remaining)
            response.headers['X-Avatar-RateLimit-Reset'] = str(reset_in)
            response.headers['X-Avatar-RateLimit-Tier'] = (user_tier or 'free').lower()
            return response
        return wrapped
    return decorator


@avatar_bp.route('/generate-custom-avatar', methods=['POST'])
@require_auth
@rate_limit_by_user_tier(free=3, premium=20, byok=None)
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
        if 'photo' not in request.files:
            return jsonify({
                'status': 'error',
                'error_code': 'MISSING_PHOTO',
                'message': 'Photo is required'
            }), 400

        photo_file = request.files['photo']
        photo_bytes = photo_file.read()

        # Extract other data from form
        character_name = request.form.get('character_name')
        age = request.form.get('age')
        gender = request.form.get('gender')
        eye_color = request.form.get('eye_color')
        favorite_color = request.form.get('favorite_color')

        # Basic validation
        if not all([character_name, age, gender, eye_color, favorite_color]):
            return jsonify({
                'status': 'error',
                'error_code': 'MISSING_DATA',
                'message': 'All fields (character_name, age, gender, eye_color, favorite_color) are required'
            }), 400

        try:
            age = int(age)
        except ValueError:
            return jsonify({
                'status': 'error',
                'error_code': 'INVALID_AGE',
                'message': 'Age must be a number'
            }), 400

        logger.info(f"Custom avatar request: name={character_name}, age={age}, gender={gender}")

        service = get_avatar_service()

        try:
            avatar_data = service.generate_custom_avatar(
                character_name=character_name,
                age=age,
                gender=gender,
                eye_color=eye_color,
                favorite_color=favorite_color,
                photo_bytes=photo_bytes
            )

            logger.info(f"Custom avatar generated successfully: {avatar_data['id']}")

            return jsonify({
                'status': 'success',
                'avatar': avatar_data
            }), 200

        except ValueError as e:
            logger.warning(f"Custom avatar validation error: {e}")
            return jsonify({
                'status': 'error',
                'error_code': 'VALIDATION_ERROR',
                'message': str(e)
            }), 400

        except Exception as e:
            logger.error(f"Custom avatar generation failed: {e}")
            return jsonify({
                'status': 'error',
                'error_code': 'GENERATION_FAILED',
                'message': f"Our magic paintbrush hit a snag: {str(e)}"
            }), 500

    except Exception as e:
        logger.exception(f"Unexpected error in generate_custom_avatar endpoint: {e}")
        return jsonify({
            'status': 'error',
            'error_code': 'INTERNAL_ERROR',
            'message': 'Something magical went wrong! Let\'s try again! ✨'
        }), 500


@avatar_bp.route('/generate-pet-avatar', methods=['POST'])
@require_auth
@rate_limit_by_user_tier(free=3, premium=20, byok=None)
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
        if 'photo' not in request.files:
            return jsonify({
                'status': 'error',
                'error_code': 'MISSING_PHOTO',
                'message': 'Photo is required'
            }), 400

        photo_file = request.files['photo']
        photo_bytes = photo_file.read()

        # Extract other data from form
        pet_name = request.form.get('pet_name')
        species = request.form.get('species')
        breed_description = request.form.get('breed_description')
        owner_favorite_color = request.form.get('owner_favorite_color')

        # Basic validation
        if not all([pet_name, species, breed_description, owner_favorite_color]):
            return jsonify({
                'status': 'error',
                'error_code': 'MISSING_DATA',
                'message': 'All fields (pet_name, species, breed_description, owner_favorite_color) are required'
            }), 400

        logger.info(f"Pet avatar request: name={pet_name}, species={species}")

        service = get_avatar_service()

        try:
            avatar_data = service.generate_pet_avatar(
                pet_name=pet_name,
                species=species,
                breed_description=breed_description,
                owner_favorite_color=owner_favorite_color,
                photo_bytes=photo_bytes
            )

            logger.info(f"Pet avatar generated successfully: {avatar_data['id']}")

            return jsonify({
                'status': 'success',
                'avatar': avatar_data
            }), 200

        except Exception as e:
            logger.error(f"Pet avatar generation failed: {e}")
            return jsonify({
                'status': 'error',
                'error_code': 'GENERATION_FAILED',
                'message': f"Our magic paintbrush hit a snag with the pet avatar: {str(e)}"
            }), 500

    except Exception as e:
        logger.exception(f"Unexpected error in generate_pet_avatar endpoint: {e}")
        return jsonify({
            'status': 'error',
            'error_code': 'INTERNAL_ERROR',
            'message': 'Something magical went wrong! Let\'s try again! ✨'
        }), 500


@avatar_bp.route('/generate-avatar', methods=['POST'])
@require_auth
@rate_limit_by_user_tier(free=5, premium=50, byok=None)
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
    try:
        # Get request data
        data = request.get_json()

        if not data:
            return jsonify({
                'status': 'error',
                'error_code': 'INVALID_REQUEST',
                'message': 'Request body is required'
            }), 400

        # Extract and validate required fields
        character_name = data.get('character_name')
        age = data.get('age')

        if not character_name or not character_name.strip():
            return jsonify({
                'status': 'error',
                'error_code': 'MISSING_CHARACTER_NAME',
                'message': 'Character name is required'
            }), 400

        if age is None or not isinstance(age, int):
            return jsonify({
                'status': 'error',
                'error_code': 'INVALID_AGE',
                'message': get_error_message('invalid_age')
            }), 400

        if not (3 <= age <= 99):
            return jsonify({
                'status': 'error',
                'error_code': 'AGE_OUT_OF_RANGE',
                'message': get_error_message('invalid_age')
            }), 400

        # Extract optional fields
        style = data.get('style', 'pixar').lower()
        features = data.get('features', {})
        emotion_data = data.get('emotion_data')
        seed = data.get('seed')

        # Validate style
        valid_styles = ['pixar', 'watercolor', 'cartoon', 'clay']
        if style not in valid_styles:
            return jsonify({
                'status': 'error',
                'error_code': 'INVALID_STYLE',
                'message': get_error_message('invalid_style'),
                'valid_styles': valid_styles
            }), 400

        logger.info(f"Avatar generation request: name={character_name}, age={age}, style={style}")

        # Get avatar service and generate
        service = get_avatar_service()

        try:
            avatar_data = service.generate_avatar(
                character_name=character_name,
                age=age,
                style=style,
                features=features,
                emotion_data=emotion_data,
                seed=seed
            )

            logger.info(f"Avatar generated successfully: {avatar_data['id']}")

            return jsonify({
                'status': 'success',
                'avatar': avatar_data
            }), 200

        except ValueError as ve:
            # Validation error
            logger.warning(f"Avatar validation error: {ve}")
            return jsonify({
                'status': 'error',
                'error_code': 'VALIDATION_ERROR',
                'message': str(ve)
            }), 400

        except Exception as e:
            # Generation error - offer fallbacks
            logger.error(f"Avatar generation failed: {e}")

            fallback_avatars = service.get_fallback_avatars(style)

            return jsonify({
                'status': 'error',
                'error_code': 'GENERATION_FAILED',
                'message': get_error_message('generation_failed'),
                'fallback_avatars': fallback_avatars
            }), 500

    except Exception as e:
        logger.exception(f"Unexpected error in generate_avatar endpoint: {e}")
        return jsonify({
            'status': 'error',
            'error_code': 'INTERNAL_ERROR',
            'message': 'Something magical went wrong! Let\'s try again! ✨'
        }), 500


@avatar_bp.route('/regenerate-avatar', methods=['POST'])
@require_auth
@rate_limit_by_user_tier(free=3, premium=30, byok=None)
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
            return jsonify({
                'status': 'error',
                'error_code': 'INVALID_REQUEST',
                'message': 'Request body is required'
            }), 400

        # For re-roll, we generate a new avatar with the same parameters
        # This gives similar but different results
        character_name = data.get('character_name')
        age = data.get('age')
        style = data.get('style', 'pixar')
        features = data.get('features', {})
        emotion_data = data.get('emotion_data')

        # Don't use the seed for re-roll - let it generate a new one
        # This creates variation while keeping same character attributes

        logger.info(f"Avatar re-roll request: name={character_name}, age={age}, style={style}")

        service = get_avatar_service()

        try:
            avatar_data = service.generate_avatar(
                character_name=character_name,
                age=age,
                style=style,
                features=features,
                emotion_data=emotion_data,
                seed=None  # New seed for variation
            )

            logger.info(f"Avatar re-rolled successfully: {avatar_data['id']}")

            return jsonify({
                'status': 'success',
                'avatar': avatar_data
            }), 200

        except Exception as e:
            logger.error(f"Avatar re-roll failed: {e}")

            fallback_avatars = service.get_fallback_avatars(style)

            return jsonify({
                'status': 'error',
                'error_code': 'REGENERATION_FAILED',
                'message': get_error_message('generation_failed'),
                'fallback_avatars': fallback_avatars
            }), 500

    except Exception as e:
        logger.exception(f"Unexpected error in regenerate_avatar endpoint: {e}")
        return jsonify({
            'status': 'error',
            'error_code': 'INTERNAL_ERROR',
            'message': 'Something magical went wrong! Let\'s try again! ✨'
        }), 500


@avatar_bp.route('/fallback-avatars', methods=['GET'])
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
        style = request.args.get('style')

        service = get_avatar_service()
        fallback_avatars = service.get_fallback_avatars(style)

        return jsonify({
            'status': 'success',
            'fallback_avatars': fallback_avatars
        }), 200

    except Exception as e:
        logger.exception(f"Error getting fallback avatars: {e}")
        return jsonify({
            'status': 'error',
            'error_code': 'INTERNAL_ERROR',
            'message': 'Could not load fallback avatars'
        }), 500


@avatar_bp.route('/health', methods=['GET'])
def health_check():
    """Health check endpoint for avatar service."""
    try:
        service = get_avatar_service()

        # Check if image generator is available
        has_generator = service.image_generator is not None

        return jsonify({
            'status': 'healthy',
            'avatar_service': 'ready',
            'image_generator': 'ready' if has_generator else 'unavailable'
        }), 200

    except Exception as e:
        logger.exception(f"Health check failed: {e}")
        return jsonify({
            'status': 'unhealthy',
            'error': str(e)
        }), 500


@avatar_bp.route('/tweak-gallery-avatar', methods=['POST'])
@require_auth
@rate_limit_by_user_tier(free=0, premium=5, byok=None)
def tweak_gallery_avatar():
    """
    Edit a curated gallery avatar (premium-only).
    Multipart form: image (WebP bytes), hair_length (opt), eye_color (opt).
    """
    try:
        if 'image' not in request.files:
            return jsonify({
                'status': 'error',
                'error_code': 'MISSING_IMAGE',
                'message': 'Avatar image is required'
            }), 400

        image_bytes = request.files['image'].read()
        hair_length = request.form.get('hair_length') or None
        eye_color = request.form.get('eye_color') or None

        if not hair_length and not eye_color:
            return jsonify({
                'status': 'error',
                'error_code': 'NO_CHANGES',
                'message': 'Please choose at least one thing to change (hair length or eye color)'
            }), 400

        logger.info(f"Gallery avatar tweak: hair_length={hair_length}, eye_color={eye_color}")

        try:
            from backend.gemini_image_generator import GeminiImageGenerator
        except ImportError:
            from gemini_image_generator import GeminiImageGenerator

        generator = GeminiImageGenerator()
        images = generator.tweak_gallery_avatar(
            image_bytes=image_bytes,
            hair_length=hair_length,
            eye_color=eye_color,
        )

        if not images:
            return jsonify({
                'status': 'error',
                'error_code': 'GENERATION_FAILED',
                'message': get_error_message('generation_failed')
            }), 500

        return jsonify({
            'status': 'success',
            'tweaked_image_base64': images[0]['image_data']
        }), 200

    except Exception as e:
        logger.exception(f"Unexpected error in tweak_gallery_avatar: {e}")
        return jsonify({
            'status': 'error',
            'error_code': 'INTERNAL_ERROR',
            'message': "Something magical went wrong! Let's try again! ✨"
        }), 500


# Error messages
ERROR_MESSAGES = {
    'generation_failed': "Oops! Our magic paintbrush needs a moment. Let's try a different magic spell! ✨",
    'timeout': "The magic is taking longer than usual. Want to try a quick starter avatar instead? 🎨",
    'safety_trigger': "Let's try different magic words to create your perfect avatar! 🌟",
    'rate_limit': "You've created lots of magic today! Let's pick from our special collection! 🎁",
    'invalid_style': "That magic style isn't available yet! Let's try Pixar, Watercolor, Cartoon, or Clay! 🎭",
    'invalid_age': "Hmm, that age doesn't seem right. Can you check it? 🤔",
    'no_generator': "Our magic art studio is taking a quick break. Try again in a moment! 🎨"
}


def get_error_message(error_code: str) -> str:
    """Get kid-friendly error message for error code."""
    return ERROR_MESSAGES.get(error_code, "Something magical went wrong! Let's try again! ✨")


def _generate_mock_placeholder_avatar(character_name: str, age: int, style: str = "pixar") -> str:
    """
    Generate a simple placeholder avatar image as base64.

    Creates a colored square with the character's initial and age.
    This is for testing and development - no API calls, instant response.
    """
    from PIL import Image, ImageDraw, ImageFont
    import base64
    import io

    # Color schemes by style
    colors = {
        'pixar': ('#4A90E2', '#FFFFFF'),      # Blue background, white text
        'watercolor': ('#B8E6B8', '#2C5F2C'), # Soft green, dark green text
        'cartoon': ('#FFB6C1', '#8B008B'),    # Pink, dark magenta text
        'clay': ('#D2B48C', '#8B4513')        # Tan, saddle brown text
    }

    bg_color, text_color = colors.get(style, colors['pixar'])

    # Create image
    img = Image.new('RGB', (512, 512), color=bg_color)
    draw = ImageDraw.Draw(img)

    # Add character initial and age
    initial = character_name[0].upper() if character_name else '?'
    text = f"{initial}\n{age}"

    # Try to use a nice font, fall back to default
    try:
        font = ImageFont.truetype("arial.ttf", 180)
        font_small = ImageFont.truetype("arial.ttf", 80)
    except:
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
    img.save(buffer, format='PNG')
    img_base64 = base64.b64encode(buffer.getvalue()).decode('utf-8')

    return img_base64


@avatar_bp.route('/generate-avatar-mock', methods=['POST'])
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
            return jsonify({
                'status': 'error',
                'error_code': 'INVALID_REQUEST',
                'message': 'Request body is required'
            }), 400

        character_name = data.get('character_name', 'Hero')
        age = data.get('age', 7)
        style = data.get('style', 'pixar').lower()
        features = data.get('features', {})
        emotion_data = data.get('emotion_data', {})

        logger.info(f"[MOCK] Generating avatar for {character_name}, age {age}, style {style}")

        # Generate mock placeholder image
        img_base64 = _generate_mock_placeholder_avatar(character_name, age, style)

        # Return same structure as real endpoint
        avatar_id = str(uuid.uuid4())
        seed = f"mock-{avatar_id[:8]}"

        avatar_data = {
            'id': avatar_id,
            'image_base64': img_base64,
            'seed': seed,
            'style': style,
            'attributes': {
                'character_name': character_name,
                'age': age,
                **features
            },
            'emotion_data': emotion_data,
            'generated_at': datetime.now().isoformat(),
            'generation_time_ms': 1,  # Instant!
            'is_mock': True,  # Flag to indicate this is mock data
            'cost': 0.0  # Free!
        }

        return jsonify({
            'status': 'success',
            'avatar': avatar_data
        }), 200

    except Exception as e:
        logger.exception(f"Error in mock avatar generation: {e}")
        return jsonify({
            'status': 'error',
            'error_code': 'MOCK_ERROR',
            'message': str(e)
        }), 500
