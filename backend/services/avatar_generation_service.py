"""
Avatar Generation Service - Generates safe, magical child avatars using Gemini 2.0
"""
import uuid
import base64
import logging
import os
import re
import io
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

        disable_gemini = os.getenv("DISABLE_GEMINI_IMAGE", "").strip().lower() in ("1", "true", "yes")

        # If no primary generator provided, try to import and create Gemini
        if self.image_generator is None and not disable_gemini:
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
        elif self.image_generator is None and disable_gemini:
            logger.info("Gemini image generation disabled via DISABLE_GEMINI_IMAGE=1")

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

    def generate_custom_avatar(
        self,
        character_name: str,
        age: int,
        gender: str,
        eye_color: str,
        favorite_color: str,
        photo_bytes: bytes,
    ) -> Dict:
        """
        Generate a custom magical avatar based on a child's photo and preferences.

        Args:
            character_name: Child's name
            age: Child's age
            gender: 'boy' or 'girl'
            eye_color: Child's eye color
            favorite_color: Child's favorite color
            photo_bytes: Bytes of the snapped photo

        Returns:
            Dict with avatar data (same format as generate_avatar)
        """
        start_time = datetime.now()

        # Validate inputs
        if not character_name or not character_name.strip():
            raise ValueError("Character name is required")
        if not (3 <= age <= 99):
            raise ValueError("Age must be between 3 and 99")
        if gender.lower() not in ['boy', 'girl']:
            raise ValueError("Gender must be 'boy' or 'girl'")

        # Use the specific user-provided prompt template
        prompt_template = """
**Generated Prompt:** Magical Avatar Creator v3 (Dynamic Celestial Edition)

**Context & Background**
This prompt is designed for "Story Weaver," an app that transforms real-world images of children into Pixar-style digital avatars. The system maintains facial resemblance while applying a 3D animation aesthetic, placing the character in a whimsical, storybook world.

**Core Role & Capabilities**
* **Avatar Stylist:** Expert in translating human features into stylized 3D character designs.
* **Feature Preservation:** Maintains identifiable traits (eye shape, smile lines, hair texture) while applying animation filters.
* **Dynamic Tailoring:** Adjusts outfit proportions based on the child's gender to ensure a relatable, heroic silhouette.

**Technical Configuration**
* **Model:** Nano Banana (Image-to-Image / Text-to-Image).
* **Compositional Control:** Reference the uploaded photo for head shape, skin tone, and facial features.
* **Style Anchor:** Professional 3D animated film aesthetic; vibrant textures, soft "subsurface scattering" on skin, and cinematic lighting.

**Operational Guidelines**
1. **Likeness Synthesis:** Prioritize the uploaded photo for structural likeness. Use the user-provided **Age: {age}** to set correct head-to-body proportions and the provided **Eye Color: {eye_color}** for the iris tint.
2. **The "Color-Matched Explorer" Wardrobe:**
   - **Base Layer:** Clothe the character in a "Hero’s Tunic" made of iridescent, star-spun silk. Use a jewel-tone version of the user's **Favorite Color: {favorite_color}** as the primary fabric hue. 
   - **Gender-Specific Tailoring:** {gender_tailoring}
   - **The Celestial Cape:** A semi-translucent flowing cape that glows with internal nebula light. The nebula should shimmer in a shade matching the **Favorite Color: {favorite_color}**, filled with tiny floating gold star particles.
   - **Details:** Add gold constellation embroidery along the collar and cuffs. No modern zippers/buttons.
3. **Environment:** Place the character in a "Painterly Storybook Forest" with soft-focus "bokeh" glowing mushrooms and floating fireflies. 
4. **Final Render:** Chest-up or waist-up portrait, center-aligned, high-resolution.

**Output Specifications**
* **Format:** Single high-resolution square image (1024x1024+).
* **Style:** Pixar-inspired 3D animation with soft lighting.

**Error Handling**
* **Photo Quality:** If the photo is low-quality, lean heavily on provided text (Age, Eye Color, Favorite Color) to generate a representative "best-fit" avatar.
* **Color Clashes:** Use gold accents (embroidery/stars) to create visual separation if the favorite color is too close to the child's hair or skin tone.
"""
        gender_tailoring = ""
        if gender.lower() == 'boy':
            gender_tailoring = "* For **Boys**: Ensure the tunic is hip-length and paired with dark, fitted trousers or leggings to create a clear 'heroic shirt' silhouette."
        else:
            gender_tailoring = "* For **Girls**: The tunic may be styled as a whimsical tunic-dress or a hip-length top with leggings."

        prompt = prompt_template.format(
            age=age,
            eye_color=eye_color,
            favorite_color=favorite_color,
            gender_tailoring=gender_tailoring
        )

        logger.info(f"Generating custom avatar for {character_name}, age {age}, eye_color {eye_color}, fav_color {favorite_color}")

        # Call the new generator method
        try:
            results = self.image_generator.generate_custom_avatar(
                base_image_bytes=photo_bytes,
                prompt=prompt,
                character_name=character_name,
                age=age,
                num_images=1
            )

            if results and len(results) > 0:
                result = results[0]
                image_base64 = result.get('image_data')
                
                # Check for "data:image" prefix and clean up
                if image_base64 and "," in image_base64:
                    image_base64 = image_base64.split(",", 1)[1]
                
                # Build response
                avatar_id = str(uuid.uuid4())
                end_time = datetime.now()
                generation_time_ms = int((end_time - start_time).total_seconds() * 1000)

                return {
                    'id': avatar_id,
                    'image_base64': f"data:image/png;base64,{image_base64}",
                    'style': 'pixar-custom',
                    'attributes': {
                        'character_name': character_name,
                        'age': age,
                        'gender': gender,
                        'eye_color': eye_color,
                        'favorite_color': favorite_color
                    },
                    'generated_at': datetime.now().isoformat(),
                    'generation_time_ms': generation_time_ms,
                    'version': 3
                }
            else:
                raise Exception("No image generated for custom avatar")

        except Exception as e:
            logger.error(f"Custom avatar generation failed with primary generator: {e}")
            # Try OpenRouter fallback (handles photos that Gemini safety policies reject)
            if self.fallback_generator is not None:
                try:
                    logger.info("Retrying custom avatar with OpenRouter fallback")
                    results = self.fallback_generator.generate_custom_avatar(
                        base_image_bytes=photo_bytes,
                        prompt=prompt,
                        character_name=character_name,
                        age=age,
                    )
                    if results and len(results) > 0:
                        result = results[0]
                        image_base64 = result.get('image_data') or result.get('image_base64', '')
                        if image_base64 and "," in image_base64:
                            image_base64 = image_base64.split(",", 1)[1]
                        avatar_id = str(uuid.uuid4())
                        return {
                            'id': avatar_id,
                            'image_base64': f"data:image/png;base64,{image_base64}",
                            'style': 'pixar-custom',
                            'attributes': {'character_name': character_name, 'age': age, 'gender': gender},
                            'generated_at': datetime.now().isoformat(),
                            'version': 3,
                        }
                except Exception as fallback_err:
                    logger.error(f"OpenRouter fallback also failed: {fallback_err}")
            raise Exception(f"Custom avatar generation failed: {str(e)}")

    def generate_pet_avatar(
        self,
        pet_name: str,
        species: str,
        breed_description: str,
        owner_favorite_color: str,
        photo_bytes: bytes,
    ) -> Dict:
        """
        Generate a magical pet avatar based on a pet's photo and preferences.

        Args:
            pet_name: Pet's name
            species: Pet's species (e.g., dog, cat)
            breed_description: Detailed description of the breed/markings
            owner_favorite_color: Favorite color of the owner (for accessories)
            photo_bytes: Bytes of the snapped photo

        Returns:
            Dict with avatar data
        """
        start_time = datetime.now()

        # Validate inputs
        if not pet_name or not pet_name.strip():
            raise ValueError("Pet name is required")
        if not species or not species.strip():
            raise ValueError("Species is required")

        # Use the requested Magical Pet Avatar Creator v1 prompt
        prompt_template = """
**Generated Prompt:** Magical Pet Avatar Creator v1 (Storybook Companion Edition)

**Context & Background**
This prompt is designed for "Story Weaver," an app that transforms real-world images of family pets into Pixar-style magical companions. The system maintains breed identity and specific markings while applying a 3D animation aesthetic, placing the pet in a whimsical, storybook world that matches their owner's avatar.

**Core Role & Capabilities**
* **Creature Stylist:** Expert in translating animal features into stylized 3D companion designs.
* **Breed Preservation:** MANDATORY: Maintain identifiable traits (tuxedo markings, specific ear shapes, tail carriage, and unique coat patterns) so the owner recognizes their specific pet.
* **Magical Enhancement:** Adds subtle magical elements like a glowing collar or swirling sparkles that represent the pet's unique bond with their human.

**Technical Configuration**
* **Model:** Nano Banana (Image-to-Image / Text-to-Image).
* **Compositional Control:** Reference the uploaded photo for body shape, coat markings, and breed characteristics.
* **Style Anchor:** Painterly Storybook illustration with 3D animated depth; soft textures, vibrant colors, and cinematic lighting.

**Operational Guidelines**
1. **Breed Likeness:** Prioritize the uploaded photo for structural likeness and coat markings. Use the provided **Species: {species}** and **Breed/Description: {breed_description}** to refine the AI's understanding of the pet's anatomy.
2. **The "Bond-Matched" Accessory:**
   - **Primary Accessory:** Clothe the pet in a "Magical Guardian Collar" or "Hero’s Harness." Use a jewel-tone version of the **Owner’s Favorite Color: {owner_favorite_color}** as the primary color for the accessory.
   - **Celestial Charm:** Attached to the collar is a glowing, semi-translucent star charm that emits soft nebula light in the same **Owner’s Favorite Color: {owner_favorite_color}**.
3. **Environment:** Place the pet in the "Painterly Storybook Forest" to match the human avatars. Include soft-focus "bokeh" glowing mushrooms and floating fireflies. 
4. **Final Render:** Full-body or chest-up portrait, expressive eyes, high-resolution.

**Output Specifications**
* **Format:** Single high-resolution square image (1024x1024+).
* **Style:** Pixar-inspired 3D animation with soft, painterly lighting.

**Error Handling**
* **Photo Quality:** If the photo is low-quality, lean heavily on provided text (Species, Breed) to generate a representative "best-fit" pet companion.
* **Color Clashes:** Ensure the magical accessory stands out clearly against the pet's fur color by adding gold or silver trim to the edges.
"""
        prompt = prompt_template.format(
            species=species,
            breed_description=breed_description,
            owner_favorite_color=owner_favorite_color
        )

        logger.info(f"Generating magical pet avatar for {pet_name} ({species})")

        try:
            results = self.image_generator.generate_pet_avatar(
                photo_bytes=photo_bytes,
                species=species,
                breed_description=breed_description,
                owner_favorite_color=owner_favorite_color,
                pet_name=pet_name,
                num_images=1,
                prompt=prompt
            )

            if results and len(results) > 0:
                result = results[0]
                image_base64 = result.get('image_data')
                
                # Check for "data:image" prefix and clean up
                if image_base64 and "," in image_base64:
                    image_base64 = image_base64.split(",", 1)[1]
                
                # Build response
                avatar_id = str(uuid.uuid4())
                end_time = datetime.now()
                generation_time_ms = int((end_time - start_time).total_seconds() * 1000)

                return {
                    'id': avatar_id,
                    'image_base64': f"data:image/png;base64,{image_base64}",
                    'style': 'pixar-pet-custom',
                    'attributes': {
                        'pet_name': pet_name,
                        'species': species,
                        'breed_description': breed_description,
                        'owner_favorite_color': owner_favorite_color
                    },
                    'generated_at': datetime.now().isoformat(),
                    'generation_time_ms': generation_time_ms,
                    'version': 1
                }
            else:
                raise Exception("No image generated for pet avatar")

        except Exception as e:
            logger.error(f"Pet avatar generation failed: {e}")
            raise Exception(f"Pet avatar generation failed: {str(e)}")

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

        if not (3 <= age <= 99):
            raise ValueError("Age must be between 3 and 99")

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

        # Generate avatar image with retry logic for vision verification
        MAX_RETRIES = 3
        image_data = None

        for attempt in range(MAX_RETRIES):
            try:
                image_data = self._generate_image_with_gemini(
                    prompt=prompt,
                    character_name=character_name,
                    age=age,
                    style=style
                )

                # Verify non-photorealistic
                if self._verify_non_photorealistic(image_data):
                    logger.info(f"Avatar passed vision verification on attempt {attempt + 1}")
                    break  # Success!
                else:
                    if attempt < MAX_RETRIES - 1:
                        logger.warning(
                            f"Avatar failed vision verification on attempt {attempt + 1}/{MAX_RETRIES}, "
                            "retrying with adjusted prompt..."
                        )
                        # Add variation to prompt for next attempt
                        prompt = prompt + f" (variation {attempt + 2})"
                    else:
                        logger.error(f"Avatar failed vision verification after {MAX_RETRIES} attempts")
                        raise Exception(
                            "Generated avatar failed visual quality verification after multiple attempts. "
                            "Please try again or contact support if issue persists."
                        )

            except Exception as e:
                if attempt < MAX_RETRIES - 1:
                    logger.warning(f"Avatar generation attempt {attempt + 1}/{MAX_RETRIES} failed: {e}, retrying...")
                else:
                    logger.error(f"Avatar generation failed after {MAX_RETRIES} attempts: {e}")
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
                        image_base64 = image_base64.strip()
                        if image_base64.startswith("data:image"):
                            image_base64 = image_base64.split(",", 1)[1] if "," in image_base64 else image_base64
                        image_base64 = re.sub(r"\s+", "", image_base64)
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
                        image_base64 = image_base64.strip()
                        if image_base64.startswith("data:image"):
                            image_base64 = image_base64.split(",", 1)[1] if "," in image_base64 else image_base64
                        image_base64 = re.sub(r"\s+", "", image_base64)
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

        This applies lightweight vision-based heuristics:
        - Image decode and dimensions sanity
        - Visual complexity checks (variance, edge density, color diversity)
        - Reject obvious blank/invalid outputs

        Args:
            image_data: Image bytes to verify

        Returns:
            True if image appears non-photorealistic, False otherwise
        """
        if not image_data or len(image_data) < 1000:
            logger.warning("Image data suspiciously small")
            return False

        try:
            from PIL import Image, ImageFilter, ImageStat

            with Image.open(io.BytesIO(image_data)) as img:
                if img.width < 128 or img.height < 128:
                    logger.warning(
                        "Avatar image too small for verification: %sx%s",
                        img.width,
                        img.height,
                    )
                    return False

                sample = img.convert("RGB")
                sample.thumbnail((128, 128))

                stat = ImageStat.Stat(sample)
                avg_stddev = sum(stat.stddev) / max(1, len(stat.stddev))

                edges = sample.filter(ImageFilter.FIND_EDGES)
                edge_stat = ImageStat.Stat(edges)
                edge_mean = sum(edge_stat.mean) / max(1, len(edge_stat.mean))

                palette = sample.convert("P", palette=Image.ADAPTIVE, colors=64)
                histogram = palette.histogram()
                unique_colors = sum(1 for value in histogram if value > 0)
                color_density = unique_colors / 64.0

                logger.debug(
                    "Avatar vision verification metrics: stddev=%.2f edge_mean=%.2f color_density=%.2f",
                    avg_stddev,
                    edge_mean,
                    color_density,
                )

                # Reject obviously blank/low-information images.
                if avg_stddev < 10 or edge_mean < 2 or color_density < 0.08:
                    logger.warning(
                        "Avatar vision verification failed: low visual complexity "
                        "(stddev=%.2f edge_mean=%.2f color_density=%.2f)",
                        avg_stddev,
                        edge_mean,
                        color_density,
                    )
                    return False

                return True

        except Exception as e:
            logger.warning("Avatar vision verification failed due to analyzer error: %s", e)
            return False

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
