"""
Avatar Generation Service - Generates safe, magical child avatars using Gemini 2.0
"""

import base64
import logging
import os
import re
import uuid
from datetime import datetime
from typing import Dict, List, Optional

try:
    from backend.utils.lazy_import import load_first_available
except ImportError:
    from utils.lazy_import import load_first_available
from .avatar_prompt_service import AvatarPromptService

logger = logging.getLogger(__name__)

# Strict length cap for free-text avatar fields (refinement_note,
# breed_description, appearance_description) before they are interpolated
# into an image prompt. Photo-based avatars are CSAM-adjacent surface;
# unbounded free text here is a content-injection risk (Finding C-3, CWE-1427).
MAX_AVATAR_FREE_TEXT = 200


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

        disable_gemini = os.getenv("DISABLE_GEMINI_IMAGE", "").strip().lower() in (
            "1",
            "true",
            "yes",
        )
        # Direct Gemini is OFF by default for the same reason as the shared
        # image generator in app.py and STORY_GEN_PROVIDER='openai': Gemini's
        # API ToS forbid child-directed apps (MT-137), so a missing OpenAI key
        # must NOT silently route a child's avatar to a direct Gemini call.
        # Reachable only via an explicit local/dev opt-in.
        allow_direct_gemini = os.getenv(
            "ALLOW_DIRECT_GEMINI_IMAGE", ""
        ).strip().lower() in ("1", "true", "yes")

        # Primary avatar generator. MT-295: OpenAI (gpt-image-2) is the PRIMARY
        # provider — its API permits child-directed apps with COPPA safeguards,
        # unlike Gemini, whose ToS prohibit them. A spike confirmed gpt-image-2
        # stylizes a child's photo into a cartoon avatar with strong likeness.
        if self.image_generator is None:
            openai_key = os.getenv("OPENAI_API_KEY")
            if openai_key:
                OpenAIImageGenerator = load_first_available(
                    [
                        ("backend.openai_image_generator", "OpenAIImageGenerator"),
                        ("openai_image_generator", "OpenAIImageGenerator"),
                    ]
                )
                try:
                    if OpenAIImageGenerator is None:
                        raise ImportError("OpenAIImageGenerator could not be imported")
                    self.image_generator = OpenAIImageGenerator(api_key=openai_key)
                    logger.info(
                        "AvatarGenerationService initialized with OpenAIImageGenerator (gpt-image-2)"
                    )
                except Exception as e:
                    logger.error(f"Failed to initialize OpenAIImageGenerator: {e}")
                    self.image_generator = None

        # Direct Gemini fallback — OFF by default. Only when there is NO OpenAI
        # key, Gemini is explicitly opted in (ALLOW_DIRECT_GEMINI_IMAGE=1), and
        # not force-disabled. Gemini's ToS forbid child-directed apps, so
        # production must never reach this branch; it stays for local/dev only.
        if self.image_generator is None and allow_direct_gemini and not disable_gemini:
            GeminiImageGenerator = load_first_available(
                [
                    ("backend.gemini_image_generator", "GeminiImageGenerator"),
                    ("gemini_image_generator", "GeminiImageGenerator"),
                ]
            )
            try:
                if GeminiImageGenerator is None:
                    raise ImportError("GeminiImageGenerator could not be imported")
                self.image_generator = GeminiImageGenerator()
                logger.warning(
                    "AvatarGenerationService fell back to GeminiImageGenerator via "
                    "ALLOW_DIRECT_GEMINI_IMAGE=1 — Gemini's ToS prohibit "
                    "child-directed apps; local/dev only, never production"
                )
            except Exception as e:
                logger.error(f"Failed to initialize GeminiImageGenerator: {e}")
                self.image_generator = None
        elif self.image_generator is None:
            if disable_gemini:
                logger.info(
                    "Gemini image generation disabled via DISABLE_GEMINI_IMAGE=1"
                )
            else:
                logger.warning(
                    "AvatarGenerationService has no image generator: no OPENAI_API_KEY "
                    "and direct Gemini fallback is off by default (Gemini ToS forbid "
                    "child apps). Set OPENAI_API_KEY, or ALLOW_DIRECT_GEMINI_IMAGE=1 "
                    "for local dev only."
                )

        # Fallback for photo→avatar: prefer Replicate (PhotoMaker-Style) over OpenRouter
        # because OpenRouter's Gemini model has the same child-photo safety restrictions
        if self.fallback_generator is None:
            replicate_token = os.getenv("REPLICATE_API_TOKEN")
            if replicate_token:
                ReplicateImageGenerator = load_first_available(
                    [
                        (
                            "backend.replicate_image_generator",
                            "ReplicateImageGenerator",
                        ),
                        ("replicate_image_generator", "ReplicateImageGenerator"),
                    ]
                )
                try:
                    if ReplicateImageGenerator is None:
                        raise ImportError(
                            "ReplicateImageGenerator could not be imported"
                        )
                    self.fallback_generator = ReplicateImageGenerator(
                        api_key=replicate_token
                    )
                    logger.info(
                        "AvatarGenerationService initialized with Replicate PhotoMaker fallback"
                    )
                except Exception as e:
                    logger.warning(f"Failed to initialize Replicate fallback: {e}")
                    self.fallback_generator = None
            else:
                # Fall back to OpenRouter if no Replicate token
                OpenRouterImageGenerator = load_first_available(
                    [
                        (
                            "backend.openrouter_image_generator",
                            "OpenRouterImageGenerator",
                        ),
                        ("openrouter_image_generator", "OpenRouterImageGenerator"),
                    ]
                )
                try:
                    if OpenRouterImageGenerator is None:
                        raise ImportError(
                            "OpenRouterImageGenerator could not be imported"
                        )
                    self.fallback_generator = OpenRouterImageGenerator()
                    logger.info(
                        "AvatarGenerationService initialized with OpenRouter fallback"
                    )
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
        refinement_note: Optional[str] = None,
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
        if gender.lower() not in ["boy", "girl"]:
            raise ValueError("Gender must be 'boy' or 'girl'")
        if not photo_bytes:
            raise ValueError("Photo bytes are required")

        # 'character/storybook hero' wording avoids Gemini safety classifier triggers
        # (words like 'child/children/person' + photo = policy rejection)
        band_style = self._hero_style_for_age(age)

        # ── Photo feature extraction (best-effort) ────────────────────────────
        photo_descriptors = self._analyze_photo_features(photo_bytes)
        photo_context = ""
        if photo_descriptors:
            parts = []
            if photo_descriptors.get("hair_style"):
                parts.append(f"Hair: {photo_descriptors['hair_style']}")
            if photo_descriptors.get("skin_tone"):
                parts.append(f"Skin tone: {photo_descriptors['skin_tone']}")
            if photo_descriptors.get("distinguishing"):
                parts.append(f"Notable: {photo_descriptors['distinguishing']}")
            if parts:
                photo_context = "Photo Analysis — " + "; ".join(parts) + "."

        # MT-129: surface the avatar's appearance in the returned attributes so
        # the saved character carries real features and downstream story
        # illustrations match the avatar instead of rendering a generic child.
        # `hair_style`/`skin_tone`/`distinguishing` are the photo-inferred
        # descriptors from `_analyze_photo_features`; the rest are the parent's
        # wizard inputs. Previously only the wizard inputs were returned and the
        # photo-derived features were discarded after prompt assembly.
        avatar_attributes = {
            "character_name": character_name,
            "age": age,
            "gender": gender,
            "eye_color": eye_color,
            "favorite_color": favorite_color,
        }
        for _feat_key in ("hair_style", "skin_tone", "distinguishing"):
            _feat_val = photo_descriptors.get(_feat_key)
            if _feat_val:
                avatar_attributes[_feat_key] = _feat_val

        age_profile = (
            f"Age Styling: Character should appear approximately {age} years old, "
            f"matching the visual maturity level appropriate for a {band_style['band_name']} protagonist. "
            f"Art style: {band_style['art_style']}. "
            f"Proportions: {band_style['proportions']}. "
            f"Costume complexity: {band_style['complexity']}. "
            f"Tone: {band_style['tone']}."
        )

        gender_tailoring = self._gender_wardrobe(gender, band_style["band_name"])

        prompt_template = """
**Magical Storybook Character Creator v4 (Age-Adaptive Edition)**

Transform the reference image into a fully illustrated storybook character
in the following style: {art_style_directive}.
Maintain the character's facial features while converting them into the target art style.

**Core Capabilities**
* Character Stylist: translating reference features into {art_style_directive} character designs.
* Feature Preservation: maintains eye shape, smile lines, AND hair (length, style, color, and texture) in illustrated style.
* {age_profile}
{photo_context}

**Technical Configuration**
* Style: {art_style_directive}. NOT a photograph. NOT hyper-realistic.
* Use the reference image for head shape, skin tone, facial structure, AND hair (length, style, color).
* Lighting Direction: {lighting_style}

**Character Design**
1. Likeness Synthesis: Use reference image for structural likeness. Eye Color: {eye_color} for iris tint.
   Hair: REPLICATE the hair length, style, and color from the reference photo exactly. Do not lengthen, restyle, or feminize/masculinize the hair — keep it true to the reference.
2. Gender Presentation: This character is a {gender}. Render hair, face, and silhouette consistent with a {gender} of this age. Do NOT default to long flowing hair unless the reference photo clearly shows long hair.
3. Wardrobe: {wardrobe}
   Silhouette: {gender_tailoring}
4. Environment: {environment_style}
5. Final Render: Chest-up portrait, center-aligned, 1024x1024 square.

**Output**: {art_style_directive}, soft lighting, fully illustrated, NOT photographic.
**Fallback**: If reference is low quality, use Eye Color: {eye_color} and Favorite Color: {favorite_color}.
"""

        prompt = prompt_template.format(
            age=age,
            age_profile=age_profile,
            art_style_directive=band_style["art_style"],
            eye_color=eye_color,
            favorite_color=favorite_color,
            gender=gender.lower(),
            gender_tailoring=gender_tailoring,
            wardrobe=band_style["wardrobe"].format(favorite_color=favorite_color),
            environment_style=band_style["environment"],
            lighting_style=band_style["lighting"],
            photo_context=f"\n* {photo_context}" if photo_context else "",
        )

        # Append user-requested modifications without changing the base style.
        # refinement_note is free text from the client — sanitize (strip
        # injection/HTML/delimiter tokens) and hard-cap before interpolation.
        if refinement_note:
            from backend.utils.sanitizer import sanitize_for_prompt

            safe_refinement = sanitize_for_prompt(refinement_note, MAX_AVATAR_FREE_TEXT)
            if safe_refinement:
                prompt += (
                    f"\n\n**User-Requested Modifications**\n"
                    f"Apply the following changes to the character's appearance: {safe_refinement}\n"
                    f"Keep all other character attributes, art style, and environment unchanged."
                )
                logger.info(f"Refinement note appended: {safe_refinement!r}")

        # Validate the FULLY ASSEMBLED prompt against the unsafe-content
        # blocklist (sexual / violent / frightening terms). Custom avatars are
        # built from an uploaded child photo + free text — reject, never
        # silently proceed, on a safety failure. (Finding C-3, CWE-1427.)
        is_safe, safety_message = (
            self.prompt_service.validate_photo_avatar_prompt_safety(prompt)
        )
        if not is_safe:
            logger.warning(
                f"Custom avatar prompt failed safety check: {safety_message}"
            )
            raise ValueError(f"Safety validation failed: {safety_message}")

        logger.info(
            f"Generating custom avatar for {character_name}, age {age}, eye_color {eye_color}, fav_color {favorite_color}"
        )

        if self.image_generator is None and self.fallback_generator is None:
            raise Exception(
                "Custom avatar generation is not configured. Set GEMINI_API_KEY, "
                "REPLICATE_API_TOKEN, or OPENROUTER_API_KEY on the backend."
            )

        primary_error = None

        # Try primary generator first.
        try:
            if self.image_generator is None:
                raise Exception("Primary generator unavailable")
            results = self.image_generator.generate_custom_avatar(
                base_image_bytes=photo_bytes,
                prompt=prompt,
                character_name=character_name,
                age=age,
                num_images=1,
            )
            image_base64 = self._extract_base64_from_results(results)
            if not image_base64:
                raise Exception("No image generated for custom avatar")

            avatar_id = str(uuid.uuid4())
            end_time = datetime.now()
            generation_time_ms = int((end_time - start_time).total_seconds() * 1000)

            return {
                "id": avatar_id,
                "image_base64": f"data:image/png;base64,{image_base64}",
                "style": "pixar-custom",
                "attributes": dict(avatar_attributes),
                "generated_at": datetime.now().isoformat(),
                "generation_time_ms": generation_time_ms,
                "version": 3,
            }
        except Exception as e:
            primary_error = e
            logger.error(f"Custom avatar generation failed with primary generator: {e}")

        # Try fallback generator.
        if self.fallback_generator is not None:
            try:
                logger.info("Retrying custom avatar with fallback generator")
                results = self.fallback_generator.generate_custom_avatar(
                    base_image_bytes=photo_bytes,
                    prompt=prompt,
                    character_name=character_name,
                    age=age,
                )
                image_base64 = self._extract_base64_from_results(results)
                if not image_base64:
                    raise Exception("Fallback returned no image")

                avatar_id = str(uuid.uuid4())
                return {
                    "id": avatar_id,
                    "image_base64": f"data:image/png;base64,{image_base64}",
                    "style": "pixar-custom",
                    "attributes": dict(avatar_attributes),
                    "generated_at": datetime.now().isoformat(),
                    "version": 3,
                }
            except Exception as fallback_err:
                logger.error(
                    f"Fallback custom avatar generation also failed: {fallback_err}"
                )
                # If Replicate fails (e.g. model endpoint changes), retry with OpenRouter.
                tertiary_error = None
                try:
                    fallback_provider = type(self.fallback_generator).__name__.lower()
                    if "replicate" in fallback_provider:
                        logger.info(
                            "Replicate fallback failed; retrying custom avatar with OpenRouter"
                        )
                        OpenRouterImageGenerator = load_first_available(
                            [
                                (
                                    "backend.openrouter_image_generator",
                                    "OpenRouterImageGenerator",
                                ),
                                (
                                    "openrouter_image_generator",
                                    "OpenRouterImageGenerator",
                                ),
                            ]
                        )
                        if OpenRouterImageGenerator is None:
                            raise ImportError(
                                "OpenRouterImageGenerator could not be imported"
                            )

                        openrouter = OpenRouterImageGenerator()
                        if openrouter.api_key:
                            results = openrouter.generate_custom_avatar(
                                base_image_bytes=photo_bytes,
                                prompt=prompt,
                                character_name=character_name,
                                age=age,
                            )
                            image_base64 = self._extract_base64_from_results(results)
                            if image_base64:
                                avatar_id = str(uuid.uuid4())
                                return {
                                    "id": avatar_id,
                                    "image_base64": f"data:image/png;base64,{image_base64}",
                                    "style": "pixar-custom",
                                    "attributes": dict(avatar_attributes),
                                    "generated_at": datetime.now().isoformat(),
                                    "version": 3,
                                }
                            tertiary_error = Exception("OpenRouter returned no image")
                        else:
                            tertiary_error = Exception(
                                "OPENROUTER_API_KEY missing for tertiary fallback"
                            )
                except Exception as openrouter_err:
                    tertiary_error = openrouter_err

                if tertiary_error is not None:
                    raise Exception(
                        f"Custom avatar generation failed. Primary: {primary_error}. "
                        f"Fallback: {fallback_err}. Tertiary: {tertiary_error}"
                    )
                raise Exception(
                    f"Custom avatar generation failed. Primary: {primary_error}. "
                    f"Fallback: {fallback_err}"
                )

        raise Exception(f"Custom avatar generation failed: {primary_error}")

    @staticmethod
    def _hero_style_for_age(age: int) -> dict:
        """Return age-band visual style profile for hero avatar generation."""
        if age <= 5:
            return {
                "band_name": "Sprout (3-5)",
                "art_style": "Soft, rounded watercolor-adjacent 3D animation with gentle edges",
                "proportions": "Large head-to-body ratio, chubby limbs, big expressive eyes, round cheeks",
                "complexity": "Simple costume with 2-3 colors max, no fine detail",
                "tone": "Warm, safe, friendly",
                "wardrobe": (
                    "Simple cozy tunic in soft jewel-tone of {favorite_color}, "
                    "with rounded collar and big friendly buttons."
                ),
                "environment": (
                    "Bright whimsical day scene with soft sky glow, pastel highlights, "
                    "sparkly flowers, floating bubbles, and cheerful magical particles."
                ),
                "lighting": "High-key lighting, bright midtones, gentle bloom, uplifting palette.",
            }
        elif age <= 8:
            return {
                "band_name": "Explorer (6-8)",
                "art_style": "Bright cartoon with clear outlines, Pixar-style 3D animation",
                "proportions": "Slightly elongated body, expressive face, rounded features",
                "complexity": "Simple costume with one defining accessory",
                "tone": "Playful, adventurous",
                "wardrobe": (
                    "Hero's tunic of star-spun silk in jewel-tone of {favorite_color}, "
                    "with one signature accessory (belt, scarf, or armband) and subtle sparkle trim."
                ),
                "environment": (
                    "Playful storybook setting with warm light rays, colorful foliage, "
                    "and soft magical sparkles."
                ),
                "lighting": "Soft cinematic lighting with vibrant color contrast.",
            }
        elif age <= 11:
            return {
                "band_name": "Adventurer (9-11)",
                "art_style": "Stylized cartoon with semi-realistic faces, rich color palette",
                "proportions": "Balanced proportions with more anatomical detail, expressive posture",
                "complexity": "Costume with role-specific gear and layered elements",
                "tone": "Capable, cool, relatable",
                "wardrobe": (
                    "Adventure-ready outfit in {favorite_color} tones: layered tunic with "
                    "utility belt, shoulder guard, and constellation-embroidered cape."
                ),
                "environment": (
                    "Dynamic storybook environment with atmospheric depth, wind-swept elements, "
                    "and cinematic scale."
                ),
                "lighting": "Cinematic lighting with balanced contrast and rich texture detail.",
            }
        elif age <= 14:
            return {
                "band_name": "Creator (12-14)",
                "art_style": "Semi-realistic graphic novel style with detailed shading",
                "proportions": "Near-realistic proportions, detailed facial features",
                "complexity": "Detailed outfit reflecting personal style, layered accessories",
                "tone": "Authentic, edgy-lite, identity-forward",
                "wardrobe": (
                    "Stylish modern-fantasy outfit in {favorite_color}: fitted jacket or layered top, "
                    "personal accessories (rings, necklace, or earpiece), celestial embroidery details."
                ),
                "environment": (
                    "Atmospheric environment with moody lighting, architectural elements, "
                    "and subtle magical undertones."
                ),
                "lighting": "Dramatic cinematic lighting with depth, contrast, and subtle rim light.",
            }
        else:
            return {
                "band_name": "Adolescent/Adult (15+)",
                "art_style": "Stylized realistic or anime-influenced illustration with painterly textures",
                "proportions": "Realistic proportions, expressive posture, detailed features",
                "complexity": "Full outfit detail with personal style and expressive posture",
                "tone": "Sophisticated, aspirational, self-expressive",
                "wardrobe": (
                    "Fully realized character outfit in {favorite_color}: tailored silhouette with "
                    "personal flair, subtle magical elements woven into fabric, confident posture."
                ),
                "environment": (
                    "Elegant cinematic environment with layered depth, subtle glow effects, "
                    "and sophisticated magical atmosphere."
                ),
                "lighting": "Cinematic lighting with rich contrast, rim light, and atmospheric haze.",
            }

    @staticmethod
    def _gender_wardrobe(gender: str, band_name: str) -> str:
        """Return gender-specific silhouette description scaled to age band."""
        is_boy = gender.lower() == "boy"
        if "Sprout" in band_name:
            return (
                "Soft rounded smock-style tunic."
                if not is_boy
                else "Simple round-collar tunic with soft trousers."
            )
        elif "Explorer" in band_name:
            return (
                "Heroic: hip-length tunic with dark fitted trousers."
                if is_boy
                else "Whimsical: tunic-dress or hip-length top with leggings."
            )
        elif "Adventurer" in band_name:
            return (
                "Athletic: fitted adventure tunic with utility belt and sturdy boots."
                if is_boy
                else "Dynamic: layered adventure dress over leggings with belt and boots."
            )
        elif "Creator" in band_name:
            return (
                "Modern-fantasy: fitted jacket over dark trousers, personal accessories."
                if is_boy
                else "Expressive: styled jacket or layered top, curated accessories."
            )
        else:
            return (
                "Tailored: confident silhouette with structured layers."
                if is_boy
                else "Refined: flowing or structured silhouette with intentional styling."
            )

    # MT-155: hard cap on the best-effort photo-analysis vision call. This is
    # a non-fatal enrichment step; if Gemini is slow we must not let it eat the
    # request's latency budget. Kept well under the route's 30s timeout so the
    # primary image-generation call still has room to run.
    _PHOTO_ANALYSIS_TIMEOUT_SECONDS = int(
        os.getenv("AVATAR_PHOTO_ANALYSIS_TIMEOUT_SECONDS", "12")
    )

    def _analyze_photo_features(self, photo_bytes: bytes) -> dict:
        """
        Best-effort photo feature extraction (hair_style, skin_tone,
        distinguishing). MT-295: delegates to the active image generator's
        ``analyze_photo_features`` (OpenAI vision) instead of calling Gemini
        directly, so the avatar path never touches Gemini. Returns {} on any
        failure or timeout (non-fatal — MT-155). Legacy generators without the
        method simply yield {} (enrichment skipped, generation proceeds).
        """
        gen = self.image_generator
        if gen is None or not hasattr(gen, "analyze_photo_features"):
            return {}
        try:
            # Bound the vision call with a non-blocking timeout so a slow
            # analysis can't stall the request — on timeout the executor is
            # released (wait=False) and we fall through to {}.
            import concurrent.futures as _cf

            _executor = _cf.ThreadPoolExecutor(max_workers=1)
            try:
                _future = _executor.submit(gen.analyze_photo_features, photo_bytes)
                result = _future.result(timeout=self._PHOTO_ANALYSIS_TIMEOUT_SECONDS)
            finally:
                _executor.shutdown(wait=False, cancel_futures=True)

            if isinstance(result, dict):
                if result:
                    logger.info(f"Photo analysis extracted: {result}")
                return result
            return {}
        except Exception as e:
            logger.warning(f"Photo feature extraction failed (non-fatal): {e}")
            return {}

    def _extract_base64_from_results(
        self, results: Optional[List[Dict]]
    ) -> Optional[str]:
        """Extract clean base64 image data from a generator results list."""
        if not results:
            return None

        for result in results:
            if not isinstance(result, dict):
                continue
            image_base64 = result.get("image_data") or result.get("image_base64")
            if not image_base64 or not isinstance(image_base64, str):
                continue

            image_base64 = image_base64.strip()
            if image_base64.startswith("data:image"):
                image_base64 = (
                    image_base64.split(",", 1)[1]
                    if "," in image_base64
                    else image_base64
                )
            image_base64 = re.sub(r"\s+", "", image_base64)
            if not image_base64:
                continue

            try:
                base64.b64decode(image_base64, validate=True)
                return image_base64
            except Exception:
                continue

        return None

    def transform_to_superhero(
        self,
        photo_bytes: bytes,
        *,
        costume_color: Optional[str] = None,
        cape_style: Optional[str] = None,
        emblem: Optional[str] = None,
        power: Optional[str] = None,
    ) -> dict:
        """Re-render an existing child avatar as a superhero portrait.

        Uses the kid's already-generated avatar as the reference image plus the
        costume/power chosen in the Flutter superhero flow. Returns the same
        response shape as :meth:`generate_custom_avatar` so the client can treat
        it identically. Raises if no generator is configured or no image is
        produced.
        """
        if self.image_generator is None:
            raise Exception(
                "Superhero portrait generation is not configured. "
                "Set GEMINI_API_KEY on the backend."
            )

        mime_type = self._detect_image_mime_type(photo_bytes)
        results = self.image_generator.transform_to_superhero(
            photo_bytes,
            costume_color=costume_color,
            cape_style=cape_style,
            emblem=emblem,
            power=power,
            mime_type=mime_type,
        )
        image_base64 = self._extract_base64_from_results(results)
        if not image_base64:
            raise Exception("No image generated for superhero portrait")

        return {
            "id": str(uuid.uuid4()),
            "image_base64": f"data:image/png;base64,{image_base64}",
            "style": "pixar-superhero",
            "attributes": {
                "costume_color": costume_color,
                "cape_style": cape_style,
                "emblem": emblem,
                "power": power,
            },
            "generated_at": datetime.now().isoformat(),
            "version": 1,
        }

    def _build_pet_avatar_response(
        self,
        *,
        image_base64: str,
        pet_name: str,
        species: str,
        breed_description: str,
        owner_favorite_color: str,
        style: str,
        start_time: datetime,
        provider_used: str,
        transformation_applied: bool,
    ) -> Dict:
        """Build a normalized pet avatar payload."""
        avatar_id = str(uuid.uuid4())
        generation_time_ms = int((datetime.now() - start_time).total_seconds() * 1000)

        return {
            "id": avatar_id,
            "image_base64": image_base64,
            "seed": avatar_id,
            "style": style,
            "attributes": {
                "pet_name": pet_name,
                "species": species,
                "breed_description": breed_description,
                "owner_favorite_color": owner_favorite_color,
            },
            "emotion_data": None,
            "generated_at": datetime.now().isoformat(),
            "generation_time_ms": generation_time_ms,
            "version": 1,
            "provider_used": provider_used,
            "transformation_applied": transformation_applied,
        }

    def _detect_image_mime_type(self, image_bytes: bytes) -> str:
        """Best-effort MIME type detection for returning the original photo."""
        if image_bytes.startswith(b"\x89PNG\r\n\x1a\n"):
            return "image/png"
        if image_bytes.startswith(b"\xff\xd8\xff"):
            return "image/jpeg"
        if image_bytes.startswith(b"RIFF") and image_bytes[8:12] == b"WEBP":
            return "image/webp"
        if image_bytes.startswith((b"GIF87a", b"GIF89a")):
            return "image/gif"
        return "image/jpeg"

    def _extract_pet_color(self, species: str, breed_description: str) -> str:
        """Infer a color phrase for the text-only pet fallback prompt."""
        description = f"{species} {breed_description}".lower()
        color_patterns = [
            "black and white",
            "brown and white",
            "gray and white",
            "orange and white",
            "tan and white",
            "golden",
            "ginger",
            "calico",
            "tuxedo",
            "tabby",
            "black",
            "white",
            "brown",
            "gray",
            "grey",
            "orange",
            "tan",
            "cream",
            "gold",
            "red",
            "blue",
        ]
        for pattern in color_patterns:
            if pattern in description:
                return "gray" if pattern == "grey" else pattern
        return "multicolored"

    def _build_pet_text_fallback_prompt(
        self, species: str, breed_description: str
    ) -> str:
        """Build a text-to-image fallback prompt when photo-to-avatar fails."""
        pet_type = (species or "pet").strip().lower()
        pet_color = self._extract_pet_color(species, breed_description)
        texture = "fur"
        if any(
            word in pet_type
            for word in ("bird", "parrot", "cockatiel", "canary", "chicken", "duck")
        ):
            texture = "feathers"
        elif any(word in pet_type for word in ("fish", "goldfish", "betta", "koi")):
            texture = "scales"
        return (
            f"Pixar-style magical {pet_type}, {pet_color} {texture}, "
            "sparkly eyes, transparent PNG background, 512x512"
        )

    def _pet_style_for_age(self, age: int) -> dict:
        """Return band-specific art style directives for magical pet generation."""
        if age <= 5:
            return {
                "style_name": "Magical Plush Companion",
                "art_style": (
                    "oversized sparkly eyes, extremely soft rounded plush-toy proportions, "
                    "pastel rainbow color grading, extra fluffy fur or feathers, gentle glow aura, "
                    "Pixar baby-character warmth"
                ),
                "environment": (
                    "cozy whimsical nursery forest with giant pastel mushrooms, "
                    "glowing flowers, and floating soap bubbles"
                ),
                "accessory": (
                    "tiny glittering crown or bow with a heart-shaped charm in the owner's favorite color"
                ),
            }
        elif age <= 8:
            return {
                "style_name": "Animated Sidekick",
                "art_style": (
                    "expressive cartoon eyes, vibrant saturated colors, fun dynamic pose, "
                    "animated movie sidekick energy, Pixar 3D animation style"
                ),
                "environment": (
                    "colorful adventure playground with rainbow trees, "
                    "sparkling waterfalls, and friendly woodland creatures"
                ),
                "accessory": (
                    "hero's bandana or small cape in the owner's favorite color with a star emblem"
                ),
            }
        elif age <= 11:
            return {
                "style_name": "Fantasy RPG Companion",
                "art_style": (
                    "fantasy RPG companion portrait, glowing magical aura, "
                    "slightly mystical color grading, detailed fur/scale/feather texture "
                    "with subtle arcane sparkle"
                ),
                "environment": (
                    "enchanted forest glade with bioluminescent plants, "
                    "ancient stone ruins, and drifting magical spores"
                ),
                "accessory": (
                    "enchanted rune collar or arcane harness with a gemstone "
                    "in the owner's favorite color emitting soft light"
                ),
            }
        elif age <= 14:
            return {
                "style_name": "Graphic Novel Companion",
                "art_style": (
                    "stylized graphic novel illustration, bold lines, dramatic contrast, "
                    "cool aesthetic with subtle magical elements"
                ),
                "environment": (
                    "cinematic urban-fantasy rooftop at twilight with glowing city lights "
                    "and drifting magical embers"
                ),
                "accessory": (
                    "sleek metallic collar with a geometric charm in the owner's favorite color"
                ),
            }
        elif age <= 17:
            return {
                "style_name": "Stylized Art Companion",
                "art_style": (
                    "semi-realistic with artistic stylization, rich color depth, "
                    "expressive character design, subtle magical elements"
                ),
                "environment": (
                    "atmospheric misty woodland with dramatic light rays "
                    "and floating luminescent particles"
                ),
                "accessory": (
                    "elegant woven collar with a polished gem pendant in the owner's favorite color"
                ),
            }
        else:
            return {
                "style_name": "Elegant Magical Companion",
                "art_style": (
                    "elegant magical realism, tasteful fantasy, painterly texture, "
                    "refined color palette"
                ),
                "environment": (
                    "serene enchanted garden with soft mist, ancient stone paths, "
                    "and glowing flora"
                ),
                "accessory": (
                    "refined silver collar with a luminous gem in the owner's favorite color"
                ),
            }

    def generate_pet_avatar(
        self,
        pet_name: str,
        species: str,
        breed_description: str,
        owner_favorite_color: str,
        photo_bytes: bytes,
        owner_age: int = 0,
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

        # breed_description is free text from the client and is interpolated
        # raw into the image prompt — sanitize and hard-cap it before use so
        # every downstream consumer (prompt, fallback, response) sees the safe
        # value. (Finding C-3, CWE-1427.)
        from backend.utils.sanitizer import sanitize_for_prompt

        breed_description = sanitize_for_prompt(
            breed_description or "", MAX_AVATAR_FREE_TEXT
        )

        # Build a band-aware prompt based on the owner's age
        band_style = self._pet_style_for_age(owner_age)

        prompt = f"""
**Magical Pet Avatar Creator v2 -- {band_style['style_name']}**

Transform the reference photo into a fully illustrated magical pet companion for Story Weaver.

**Core Requirements**
* Creature Stylist: translate animal features into the target art style below.
* Breed Preservation: MANDATORY -- maintain identifiable traits (coat markings, ear shape, tail carriage) so the owner recognizes their specific pet.
* Magical Enhancement: add subtle magical elements that match the art style.

**Technical Configuration**
* Reference the uploaded photo for body shape, coat markings, and breed anatomy.
* Species: {species}
* Breed/Description: {breed_description}
* Style Anchor: {band_style['art_style']}

**Operational Guidelines**
1. Breed Likeness: use reference photo as primary source; fall back to Species/Breed text if photo quality is low.
2. Bond-Matched Accessory: {band_style['accessory'].format(owner_favorite_color=owner_favorite_color)}
   -- Ensure accessory uses a jewel-tone of the owner's Favorite Color: {owner_favorite_color}
   -- Add gold or silver trim if the accessory color clashes with the pet's coat.
3. Environment: {band_style['environment']}
4. Final Render: full-body or chest-up portrait, expressive eyes, 1024x1024 square.

**Output Specifications**
* Format: single high-resolution square image.
* Style: {band_style['art_style']}

**Fallback**
If reference photo is unclear, use Species/Breed description to generate a representative best-fit pet companion.
"""

        # Validate the fully assembled prompt against the unsafe-content
        # blocklist before any generation call. Reject on failure.
        is_safe, safety_message = (
            self.prompt_service.validate_photo_avatar_prompt_safety(prompt)
        )
        if not is_safe:
            logger.warning(f"Pet avatar prompt failed safety check: {safety_message}")
            raise ValueError(f"Safety validation failed: {safety_message}")

        logger.info(
            f"Generating magical pet avatar for {pet_name} ({species}), owner_age={owner_age}, style={band_style['style_name']}"
        )
        primary_error = None

        if self.image_generator is None:
            logger.warning(
                "Pet avatar primary provider unavailable: Gemini image generation is not configured"
            )
            primary_error = Exception("Gemini image generation is unavailable")
        elif not hasattr(self.image_generator, "generate_pet_avatar"):
            logger.warning(
                "Pet avatar primary provider unavailable: configured generator does not support pet avatars"
            )
            primary_error = Exception(
                "Configured image provider does not support pet avatars"
            )
        else:
            try:
                results = self.image_generator.generate_pet_avatar(
                    photo_bytes=photo_bytes,
                    species=species,
                    breed_description=breed_description,
                    owner_favorite_color=owner_favorite_color,
                    pet_name=pet_name,
                    num_images=1,
                    prompt=prompt,
                )
                image_base64 = self._extract_base64_from_results(results)
                if image_base64:
                    return self._build_pet_avatar_response(
                        image_base64=f"data:image/png;base64,{image_base64}",
                        pet_name=pet_name,
                        species=species,
                        breed_description=breed_description,
                        owner_favorite_color=owner_favorite_color,
                        style="pixar-pet-custom",
                        start_time=start_time,
                        provider_used="gemini",
                        transformation_applied=True,
                    )
                raise Exception("No image generated for pet avatar")
            except Exception as e:
                primary_error = e
                logger.error(
                    f"Pet avatar generation failed with primary generator: {e}"
                )

        if self.fallback_generator is not None:
            try:
                logger.info("Retrying pet avatar with text-to-image fallback generator")
                fallback_prompt = self._build_pet_text_fallback_prompt(
                    species, breed_description
                )
                results = self.fallback_generator.generate_character_avatar(
                    prompt=fallback_prompt,
                    character_name=pet_name,
                    age=6,
                    style="pixar",
                    num_images=1,
                )
                image_base64 = self._extract_base64_from_results(results)
                if image_base64:
                    provider_used = getattr(
                        self.fallback_generator, "__class__", type("x", (), {})
                    ).__name__
                    provider_used = (
                        re.sub(r"ImageGenerator$", "", provider_used).lower()
                        or "fallback"
                    )
                    return self._build_pet_avatar_response(
                        image_base64=f"data:image/png;base64,{image_base64}",
                        pet_name=pet_name,
                        species=species,
                        breed_description=breed_description,
                        owner_favorite_color=owner_favorite_color,
                        style="pixar-pet-fallback",
                        start_time=start_time,
                        provider_used=provider_used,
                        transformation_applied=True,
                    )
                raise Exception("No image generated by fallback provider")
            except Exception as fallback_err:
                logger.error(f"Pet avatar fallback also failed: {fallback_err}")

        original_photo_base64 = base64.b64encode(photo_bytes).decode("utf-8")
        original_photo_mime = self._detect_image_mime_type(photo_bytes)
        if primary_error is not None:
            logger.warning(
                "Returning original pet photo because pet avatar transformation failed: %s",
                primary_error,
            )
        else:
            logger.warning(
                "Returning original pet photo because no pet avatar provider is available"
            )
        return self._build_pet_avatar_response(
            image_base64=f"data:{original_photo_mime};base64,{original_photo_base64}",
            pet_name=pet_name,
            species=species,
            breed_description=breed_description,
            owner_favorite_color=owner_favorite_color,
            style="pet-photo-original",
            start_time=start_time,
            provider_used="original-photo",
            transformation_applied=False,
        )

    def generate_human_companion_avatar(
        self,
        name: str,
        appearance_description: str,
        owner_favorite_color: str,
        photo_bytes: bytes,
        owner_age: int = 0,
    ) -> Dict:
        """
        Generate a Pixar-style human character avatar for a friend companion.

        Uses the reference photo to render a recognisable human character
        rather than an animal, preserving facial likeness.

        Args:
            name: Companion's name
            appearance_description: Free-text description of how they look
            owner_favorite_color: Story owner's favourite colour (for accessories)
            photo_bytes: Bytes of the uploaded photo
            owner_age: Age of the story owner (drives art style)

        Returns:
            Dict with avatar data in the same shape as generate_pet_avatar
        """
        start_time = datetime.now()

        # appearance_description is free text from the client and is
        # interpolated raw into the image prompt — sanitize and hard-cap it
        # before use. (Finding C-3, CWE-1427.)
        from backend.utils.sanitizer import sanitize_for_prompt

        appearance_description = sanitize_for_prompt(
            appearance_description or "", MAX_AVATAR_FREE_TEXT
        )

        band_style = self._pet_style_for_age(owner_age)

        prompt = f"""
**Human Companion Avatar Creator -- {band_style['style_name']}**

Transform the reference photo into a fully illustrated human companion character for Story Weaver.

**Core Requirements**
* Likeness Preservation: MANDATORY — maintain recognisable facial features (face shape, eye colour, hair colour, hair style) so the person is clearly identifiable.
* Human Rendering: render as a person, not an animal. Do NOT turn the subject into any kind of creature.
* Magical Enhancement: add subtle magical elements that fit the story-book style below.

**Technical Configuration**
* Reference the uploaded photo for face shape, skin tone, hair, and overall build.
* Character Name: {name}
* Appearance: {appearance_description if appearance_description else 'as shown in the reference photo'}
* Style Anchor: {band_style['art_style']}

**Operational Guidelines**
1. Facial Likeness: use reference photo as the primary source for all facial features.
2. Bond-Matched Accessory: {band_style['accessory'].format(owner_favorite_color=owner_favorite_color)}
   — Ensure any accessory uses a jewel-tone of the owner's Favourite Colour: {owner_favorite_color}
3. Environment: {band_style['environment']}
4. Final Render: chest-up or full-body portrait, warm and expressive, 1024x1024 square.

**Output Specifications**
* Format: single high-resolution square image.
* Style: {band_style['art_style']}

**Fallback**
If reference photo is unclear, generate a friendly human character matching the appearance description above.
"""

        # Validate the fully assembled prompt against the unsafe-content
        # blocklist before any generation call. Reject on failure.
        is_safe, safety_message = (
            self.prompt_service.validate_photo_avatar_prompt_safety(prompt)
        )
        if not is_safe:
            logger.warning(
                f"Human companion avatar prompt failed safety check: {safety_message}"
            )
            raise ValueError(f"Safety validation failed: {safety_message}")

        logger.info(
            f"Generating human companion avatar for {name}, owner_age={owner_age}, style={band_style['style_name']}"
        )
        primary_error = None

        if self.image_generator is None:
            primary_error = Exception("Gemini image generation is unavailable")
        elif not hasattr(self.image_generator, "generate_pet_avatar"):
            primary_error = Exception(
                "Configured image provider does not support photo-based avatars"
            )
        else:
            try:
                results = self.image_generator.generate_pet_avatar(
                    photo_bytes=photo_bytes,
                    species="Human",
                    breed_description=appearance_description,
                    owner_favorite_color=owner_favorite_color,
                    pet_name=name,
                    num_images=1,
                    prompt=prompt,
                )
                image_base64 = self._extract_base64_from_results(results)
                if image_base64:
                    return self._build_pet_avatar_response(
                        image_base64=f"data:image/png;base64,{image_base64}",
                        pet_name=name,
                        species="Human",
                        breed_description=appearance_description,
                        owner_favorite_color=owner_favorite_color,
                        style="pixar-human-companion",
                        start_time=start_time,
                        provider_used="gemini",
                        transformation_applied=True,
                    )
                raise Exception("No image generated for human companion avatar")
            except Exception as e:
                primary_error = e
                logger.error(
                    f"Human companion avatar generation failed with primary generator: {e}"
                )

        if self.fallback_generator is not None:
            try:
                logger.info(
                    "Retrying human companion avatar with text-to-image fallback generator"
                )
                fallback_prompt = (
                    f"Pixar-style portrait of a human character named {name}. "
                    f"Appearance: {appearance_description}. "
                    f"Warm, expressive, story-book illustration, 1024x1024."
                )
                results = self.fallback_generator.generate_character_avatar(
                    prompt=fallback_prompt,
                    character_name=name,
                    age=owner_age if owner_age > 0 else 10,
                    style="pixar",
                    num_images=1,
                )
                image_base64 = self._extract_base64_from_results(results)
                if image_base64:
                    provider_used = (
                        re.sub(
                            r"ImageGenerator$",
                            "",
                            getattr(
                                self.fallback_generator, "__class__", type("x", (), {})
                            ).__name__,
                        ).lower()
                        or "fallback"
                    )
                    return self._build_pet_avatar_response(
                        image_base64=f"data:image/png;base64,{image_base64}",
                        pet_name=name,
                        species="Human",
                        breed_description=appearance_description,
                        owner_favorite_color=owner_favorite_color,
                        style="pixar-human-fallback",
                        start_time=start_time,
                        provider_used=provider_used,
                        transformation_applied=True,
                    )
                raise Exception("No image generated by fallback provider")
            except Exception as fallback_err:
                logger.error(
                    f"Human companion avatar fallback also failed: {fallback_err}"
                )

        # Last resort: return the original photo unchanged
        original_photo_base64 = base64.b64encode(photo_bytes).decode("utf-8")
        original_photo_mime = self._detect_image_mime_type(photo_bytes)
        if primary_error is not None:
            logger.warning(
                "Returning original photo because human companion avatar transformation failed: %s",
                primary_error,
            )
        else:
            logger.warning(
                "Returning original photo because no avatar provider is available"
            )
        return self._build_pet_avatar_response(
            image_base64=f"data:{original_photo_mime};base64,{original_photo_base64}",
            pet_name=name,
            species="Human",
            breed_description=appearance_description,
            owner_favorite_color=owner_favorite_color,
            style="human-photo-original",
            start_time=start_time,
            provider_used="original-photo",
            transformation_applied=False,
        )


# Error messages for kid-friendly communication
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
