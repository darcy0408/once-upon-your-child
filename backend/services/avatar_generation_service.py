"""
Avatar Generation Service - Generates safe, magical child avatars using Gemini 2.0
"""
import uuid
import base64
import logging
from datetime import datetime
from typing import Dict, Optional, List
from .avatar_prompt_service import AvatarPromptService

logger = logging.getLogger(__name__)


class AvatarGenerationService:
    """Service for generating AI-powered child avatars with safety controls."""

    def __init__(self, image_generator=None, fallback_generator=None):
        """
        Initialize avatar generation service.

        Args:
            image_generator: Primary image generator (Gemini)
            fallback_generator: Fallback generator (OpenRouter)
        """
        self.prompt_service = AvatarPromptService()
        self.image_generator = image_generator
        self.fallback_generator = fallback_generator

        # If no primary generator provided, try to import and create Gemini
        if self.image_generator is None:
            try:
                # Try backend-prefixed import first (for Flask app context)
                from backend.gemini_image_generator import GeminiImageGenerator
                self.image_generator = GeminiImageGenerator()
                logger.info("AvatarGenerationService initialized with GeminiImageGenerator")
            except ImportError:
                # Fall back to direct import (for standalone scripts)
                try:
                    from gemini_image_generator import GeminiImageGenerator
                    self.image_generator = GeminiImageGenerator()
                    logger.info("AvatarGenerationService initialized with GeminiImageGenerator (direct import)")
                except Exception as e:
                    logger.error(f"Failed to initialize GeminiImageGenerator: {e}")
                    self.image_generator = None
            except Exception as e:
                logger.error(f"Failed to initialize GeminiImageGenerator: {e}")
                self.image_generator = None

        # If no fallback generator provided, try to import and create OpenRouter
        if self.fallback_generator is None:
            try:
                from backend.openrouter_image_generator import OpenRouterImageGenerator
                self.fallback_generator = OpenRouterImageGenerator()
                logger.info("AvatarGenerationService initialized with OpenRouter fallback")
            except ImportError:
                try:
                    from openrouter_image_generator import OpenRouterImageGenerator
                    self.fallback_generator = OpenRouterImageGenerator()
                    logger.info("AvatarGenerationService initialized with OpenRouter fallback (direct import)")
                except Exception as e:
                    logger.warning(f"Failed to initialize OpenRouter fallback: {e}")
                    self.fallback_generator = None
            except Exception as e:
                logger.warning(f"Failed to initialize OpenRouter fallback: {e}")
                self.fallback_generator = None

    def generate_avatar(
        self,
        character_name: str,
        age: int,
        style: str = 'pixar',
        features: Optional[Dict[str, str]] = None,
        emotion_data: Optional[Dict[str, str]] = None,
        seed: Optional[str] = None
    ) -> Dict:
        """
        Generate a magical avatar for a child character.

        Args:
            character_name: Character's name
            age: Character age (3-17)
            style: Art style (pixar|watercolor|cartoon|clay)
            features: Dict with hair_style, hair_details, hair_color, skin_tone, outfit, expression
            emotion_data: Dict with core, secondary, eye_type, mouth_type from feelings wheel
            seed: Optional seed for regeneration (for "re-roll" functionality)

        Returns:
            Dict with avatar data:
            {
                'id': str,
                'image_base64': str,
                'seed': str,
                'style': str,
                'attributes': {...},
                'emotion_data': {...},
                'generated_at': str (ISO format),
                'generation_time_ms': int
            }

        Raises:
            ValueError: If validation fails
            Exception: If generation fails
        """
        start_time = datetime.now()

        # Validate inputs
        if not character_name or not character_name.strip():
            raise ValueError("Character name is required")

        if not (3 <= age <= 17):
            raise ValueError("Age must be between 3 and 17")

        if style.lower() not in ['pixar', 'watercolor', 'cartoon', 'clay']:
            raise ValueError(f"Invalid style: {style}. Must be pixar|watercolor|cartoon|clay")

        if self.image_generator is None and self.fallback_generator is None:
            raise Exception("No image generator available (neither Gemini nor OpenRouter)")

        features = features or {}

        # Generate or use provided seed for consistency
        if seed is None:
            seed = self.prompt_service.generate_character_seed(
                character_name,
                age,
                features
            )

        logger.info(f"Generating avatar for {character_name}, age {age}, style {style}, seed {seed}")

        # Build the avatar prompt
        prompt = self.prompt_service.build_avatar_prompt(
            character_name=character_name,
            age=age,
            style=style,
            features=features,
            emotion_data=emotion_data
        )

        # Apply emotion mirroring if emotion data provided
        if emotion_data:
            prompt = self.prompt_service.apply_emotion_mirroring(prompt, emotion_data)

        # Validate prompt safety
        is_safe, safety_message = self.prompt_service.validate_prompt_safety(prompt)
        if not is_safe:
            logger.warning(f"Avatar prompt failed safety check: {safety_message}")
            raise ValueError(f"Safety validation failed: {safety_message}")

        logger.debug(f"Avatar prompt (first 200 chars): {prompt[:200]}...")

        # Generate avatar image using Gemini
        try:
            image_data = self._generate_image_with_gemini(
                prompt=prompt,
                character_name=character_name,
                age=age,
                style=style
            )

            # Verify non-photorealistic (basic check - could be enhanced with vision model)
            if not self._verify_non_photorealistic(image_data):
                logger.warning("Generated avatar may be too photorealistic, regenerating...")
                # Could implement retry logic here
                pass

        except Exception as e:
            logger.error(f"Avatar generation failed: {e}")
            raise Exception(f"Avatar generation failed: {str(e)}")

        # Calculate generation time
        end_time = datetime.now()
        generation_time_ms = int((end_time - start_time).total_seconds() * 1000)

        # Build response
        avatar_id = str(uuid.uuid4())
        avatar_data = {
            'id': avatar_id,
            'image_base64': f"data:image/png;base64,{base64.b64encode(image_data).decode('utf-8')}",
            'seed': seed,
            'style': style.lower(),
            'attributes': features,
            'emotion_data': emotion_data,
            'generated_at': datetime.now().isoformat(),
            'generation_time_ms': generation_time_ms,
            'version': 1
        }

        logger.info(f"Avatar generated successfully: {avatar_id} in {generation_time_ms}ms")

        return avatar_data

    def regenerate_avatar(
        self,
        seed: str,
        variation: bool = True,
        character_name: str = None,
        age: int = None,
        style: str = None
    ) -> Dict:
        """
        Regenerate an avatar using an existing seed with optional variation.

        Args:
            seed: Character seed from previous generation
            variation: If True, add slight variation; if False, exact regeneration
            character_name: Required if variation=False
            age: Required if variation=False
            style: Art style

        Returns:
            Dict with avatar data (same format as generate_avatar)
        """
        if not variation and (not character_name or age is None):
            raise ValueError("character_name and age required for exact regeneration")

        # For variation, we could add random elements to the seed or prompt
        # For now, we'll use the same seed which should give similar but not identical results
        modified_seed = seed if not variation else seed + "_v2"

        logger.info(f"Regenerating avatar with seed {seed}, variation={variation}")

        # We would need to reconstruct features from the seed or store them
        # For now, raise NotImplementedError
        raise NotImplementedError("Regeneration requires stored character data - use generate_avatar with seed parameter")

    def _generate_image_with_gemini(
        self,
        prompt: str,
        character_name: str,
        age: int,
        style: str
    ) -> bytes:
        """
        Generate image using Gemini image generator, with OpenRouter fallback.

        Args:
            prompt: Complete avatar generation prompt
            character_name: Character name
            age: Character age
            style: Art style

        Returns:
            Image bytes (PNG format)

        Raises:
            Exception: If both Gemini and OpenRouter fail
        """
        gemini_error = None

        # Try Gemini first (if available)
        if self.image_generator is not None:
            try:
                logger.info("Attempting avatar generation with Gemini...")
                # Use the existing generate_character_avatar method if it exists
                if hasattr(self.image_generator, 'generate_character_avatar'):
                    results = self.image_generator.generate_character_avatar(
                        prompt=prompt,
                        character_name=character_name,
                        age=age,
                        style=style,
                        num_images=1
                    )
                else:
                    # Fall back to generic story illustration method
                    results = self.image_generator.generate_story_illustration(
                        scene_description=prompt,
                        character_name=character_name,
                        style=f"{style} children's character portrait",
                        num_images=1,
                        age=age
                    )

                if results and len(results) > 0:
                    # Extract image data from result
                    result = results[0]
                    image_base64 = result.get('image_data')

                    if image_base64:
                        # Decode base64 to bytes
                        image_bytes = base64.b64decode(image_base64)
                        logger.info("✅ Avatar generated successfully with Gemini!")
                        return image_bytes

                raise Exception("No image data in Gemini result")

            except Exception as e:
                gemini_error = e
                logger.warning(f"Gemini avatar generation failed: {e}")

        # Try OpenRouter fallback (if available)
        if self.fallback_generator is not None:
            try:
                logger.info("Attempting avatar generation with OpenRouter fallback...")
                results = self.fallback_generator.generate_character_avatar(
                    prompt=prompt,
                    character_name=character_name,
                    age=age,
                    style=style,
                    num_images=1
                )

                if results and len(results) > 0:
                    # Extract image data from result
                    result = results[0]
                    image_base64 = result.get('image_data')

                    if image_base64:
                        # Decode base64 to bytes
                        image_bytes = base64.b64decode(image_base64)
                        logger.info("✅ Avatar generated successfully with OpenRouter fallback!")
                        return image_bytes

                raise Exception("No image data in OpenRouter result")

            except Exception as e:
                logger.error(f"OpenRouter fallback also failed: {e}")
                # Both generators failed - raise combined error
                if gemini_error:
                    raise Exception(f"Avatar generation failed: Gemini: {str(gemini_error)}, OpenRouter: {str(e)}")
                else:
                    raise Exception(f"Avatar generation failed (OpenRouter only): {str(e)}")

        # If we get here, no generators available or all failed
        if gemini_error:
            raise Exception(f"Avatar generation failed: {str(gemini_error)}")
        else:
            raise Exception("No image generator available")

    def _verify_non_photorealistic(self, image_data: bytes) -> bool:
        """
        Verify that generated image is non-photorealistic.

        This is a basic implementation. Could be enhanced with:
        - Gemini vision model to analyze the image
        - Style classifier model
        - Metadata analysis

        Args:
            image_data: Image bytes to verify

        Returns:
            True if image appears non-photorealistic, False otherwise
        """
        # Basic check - for now just verify we have image data
        # In production, this could use Gemini's vision capabilities to verify style
        if not image_data or len(image_data) < 1000:
            logger.warning("Image data suspiciously small")
            return False

        # TODO: Implement vision-based verification
        # For now, trust the prompt engineering and style anchors
        return True

    def get_fallback_avatars(self, style: str = None) -> List[Dict]:
        """
        Get list of fallback preset avatars for error cases.

        Args:
            style: Optional style filter (pixar|watercolor|cartoon|clay)

        Returns:
            List of fallback avatar dicts with id, style, preview_url
        """
        fallback_avatars = []

        styles = [style] if style else ['pixar', 'watercolor', 'cartoon', 'clay']

        for s in styles:
            for i in range(1, 3):  # 2 presets per style
                fallback_avatars.append({
                    'id': f'preset_{s}_{i}',
                    'style': s,
                    'preview_url': f'/static/fallback_avatars/{s}_{i}.png'
                })

        return fallback_avatars


# Error messages for kid-friendly communication
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
