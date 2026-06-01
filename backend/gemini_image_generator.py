"""
Gemini Image Generation Service
Uses Google's Gemini 1.5 Pro via the Gemini API
"""

import base64
import io
import logging
import os
import uuid
from concurrent.futures import ThreadPoolExecutor
from concurrent.futures import TimeoutError as FuturesTimeoutError
from datetime import datetime

from PIL import Image

logger = logging.getLogger(__name__)

# Image-side content filter applied to every Gemini image-generation call.
# Mirrors _CHILD_SAFETY_SETTINGS from story_generation_service.py so that
# both the text and image paths enforce the same children's-audience thresholds.
#   BLOCK_LOW_AND_ABOVE  — near-zero tolerance (sexual content, hate, harassment)
#   BLOCK_MEDIUM_AND_ABOVE — blocks moderate+ harm; allows mild age-appropriate
#                            danger/conflict that can appear in children's stories.
try:
    from google.genai import types as _genai_types_init

    _CHILD_IMAGE_SAFETY_SETTINGS = [
        _genai_types_init.SafetySetting(
            category="HARM_CATEGORY_SEXUALLY_EXPLICIT",
            threshold="BLOCK_LOW_AND_ABOVE",
        ),
        _genai_types_init.SafetySetting(
            category="HARM_CATEGORY_DANGEROUS_CONTENT",
            threshold="BLOCK_MEDIUM_AND_ABOVE",
        ),
        _genai_types_init.SafetySetting(
            category="HARM_CATEGORY_HARASSMENT",
            threshold="BLOCK_LOW_AND_ABOVE",
        ),
        _genai_types_init.SafetySetting(
            category="HARM_CATEGORY_HATE_SPEECH",
            threshold="BLOCK_LOW_AND_ABOVE",
        ),
    ]
    del _genai_types_init
except ImportError:
    _CHILD_IMAGE_SAFETY_SETTINGS = []


# MT-107: Per-power visual signatures for Explorer-band Superhero Mode.
# Keys are power_ids from backend/data/superhero_matrix.py EXPLORER_POWERS.
# Only powers whose narrative identity demands a distinct silhouette appear
# here; other powers (super_speed, flying, etc.) rely on action posture.
_POWER_VISUAL_OVERRIDES: dict[str, str] = {
    "feeling_sense": (
        "POWER VISUAL SIGNATURE — Feeling Sense: render a soft pastel halo "
        "(empathy glow) around the hero's head and shoulders in EVERY frame. "
        "The glow is a gentle pink-and-gold gradient, slightly translucent, "
        "about 1.5x the diameter of the head, with feathered diffuse edges — "
        "never sharp, never lens-flare. It signals the hero is sensing "
        "another character's emotions. Keep it subtle, dreamlike, warm."
    ),
    "invisibility": (
        "POWER VISUAL SIGNATURE — Soft Step (invisibility): render the hero "
        "with a translucent, wisp-edged silhouette. The body is ~70% opaque "
        "in the core and fades to ~25% opacity at the edges with soft, smoky "
        "wisp-like dissipation. Background is faintly visible THROUGH the "
        "outer edges of the hero's outline. Eyes and face remain readable. "
        "Effect should feel like a ghostly shimmer, not a glitch."
    ),
}

# Human-readable descriptors for the costume choices captured by the Flutter
# superhero flow (lib/screens/wizard_steps/superhero_costume_screen.dart +
# superhero_power_screen.dart). Used to build the avatar→superhero transform
# prompt. Keys must stay aligned with the option ids in those screens.
_SUPERHERO_COLOR_NAMES: dict[str, str] = {
    "red": "bold red",
    "blue": "bright blue",
    "green": "vivid green",
    "yellow": "sunny yellow",
    "purple": "royal purple",
    "pink": "vibrant pink",
}

_SUPERHERO_CAPE_DESC: dict[str, str] = {
    "none": "no cape",
    "matching": "a flowing cape that matches the suit color",
    "rainbow": "a flowing rainbow-striped cape",
}

_SUPERHERO_EMBLEM_DESC: dict[str, str] = {
    "star": "a five-pointed star",
    "lightning": "a lightning bolt",
    "heart": "a heart",
    "moon": "a crescent moon",
    "paw": "a paw print",
    "rainbow": "a rainbow arc",
    "bolt": "a trident bolt",
    "comet": "a streaking comet",
}

# Action posture per power for powers without a full visual signature override.
_SUPERHERO_POWER_POSE: dict[str, str] = {
    "super_speed": "in a dynamic running pose with motion streaks",
    "flying": "soaring upward in a heroic flying pose, cape billowing",
    "super_strength": "in a confident strong stance, fists ready",
    "super_hearing": "alert and listening, head tilted attentively",
    "super_smile": "beaming a big warm confident smile",
    "super_hugs": "arms open in a warm welcoming pose",
    "super_whisper": "calm and reassuring, one finger to lips gently",
    "super_sharing": "offering an open friendly hand",
    "strategist": "thoughtful and poised, surveying the scene cleverly",
    "gadgeteer": "holding a clever hand-built gadget, ready to use it",
}


def build_superhero_transform_prompt(
    *,
    costume_color: str | None = None,
    cape_style: str | None = None,
    emblem: str | None = None,
    power: str | None = None,
) -> str:
    """Build the avatar→superhero transform prompt from costume/power choices.

    Pure function (no I/O) so it is cheap to unit test. Preserves the child's
    facial likeness, enforces a non-photorealistic Pixar style, and adds only
    the chosen costume + a power-appropriate action pose. Unknown/None ids are
    skipped gracefully so partial selections still produce a valid prompt.
    """
    color_desc = _SUPERHERO_COLOR_NAMES.get(costume_color or "", "a bright")
    cape_desc = _SUPERHERO_CAPE_DESC.get(cape_style or "", "a flowing cape")
    emblem_desc = _SUPERHERO_EMBLEM_DESC.get(emblem or "")
    pose_desc = _SUPERHERO_POWER_POSE.get(power or "", "in a confident hero pose")

    chest = f" with {emblem_desc} emblem on the chest" if emblem_desc else ""

    parts = [
        "This is a Pixar-style storybook character illustration of a child. ",
        "Keep the child's FACE, hair, skin tone, and likeness EXACTLY the same — ",
        "do not change their identity. ",
        "Re-dress them as a friendly, kid-appropriate superhero: ",
        f"a {color_desc} superhero suit{chest}, and {cape_desc}. ",
        f"Pose the hero {pose_desc}. ",
        "Comic-book lighting, bright heroic colors, non-photorealistic, ",
        "clearly a cartoon character, square format. ",
        "Wholesome and non-violent — no weapons, no scary or aggressive content. ",
    ]

    # Layer on a full visual signature for powers that define one (empathy
    # halo, invisibility shimmer, etc.).
    override = _POWER_VISUAL_OVERRIDES.get(power or "")
    if override:
        parts.append(override)

    return "".join(parts)


def _power_visual_block(power_id: str | None) -> str:
    if not power_id:
        return ""
    override = _POWER_VISUAL_OVERRIDES.get(power_id.strip().lower())
    return f"\n{override}\n" if override else ""


def _humanize(value) -> str:
    """Turn a Flutter enum `.name` (camelCase) into readable words.

    The Flutter app serialises CharacterAppearance enums via `.name`, so the
    illustration payload carries values like `lightBrown`, `strawberryBlonde`,
    `mediumTan`, `veryLong`. Insert spaces before internal capitals and
    lowercase so the image model reads natural language ("light brown").
    """
    if value is None:
        return ""
    text = str(value).strip()
    if not text:
        return ""
    out = []
    for i, ch in enumerate(text):
        if ch.isupper() and i > 0 and not text[i - 1].isupper():
            out.append(" ")
        out.append(ch)
    return "".join(out).replace("_", " ").lower().strip()


def build_appearance_details(character_appearance: dict | None) -> list:
    """Extract human-readable appearance phrases from a character_appearance dict.

    MT-129: the Flutter app (`story_result_screen._characterAppearanceForBackend`)
    sends snake_case keys derived from the saved Character / GeneratedAvatar —
    `hair_color`, `hair_length`, `hair_style`, `eye_color`, `skin_tone`,
    `clothing_style`, `clothing_colors`. Older / simpler callers may instead
    send the flat `hair` / `skin` / `outfit` keys. Previously the generators
    only read `hair`/`skin`/`outfit`/`gender`, so the rich avatar-derived
    fields (eye colour, skin tone, hairstyle) were silently dropped and the
    model rendered a generic child. Read BOTH key conventions here so the
    illustrated character actually matches the created character.

    Does NOT include the avatar reference image — callers handle that
    separately via `custom_avatar_base64`.
    """
    if not character_appearance:
        return []

    ca = character_appearance
    details: list[str] = []

    # --- Hair: combine length + style + colour into one phrase ---------------
    hair_color = _humanize(ca.get("hair_color")) or _humanize(ca.get("hair"))
    hair_length = _humanize(ca.get("hair_length"))
    hair_style = _humanize(ca.get("hair_style") or ca.get("hairstyle"))
    hair_parts = [p for p in (hair_length, hair_style, hair_color) if p]
    if hair_parts:
        details.append(f"hair: {' '.join(hair_parts)}")

    # --- Eyes ----------------------------------------------------------------
    eye_color = _humanize(ca.get("eye_color") or ca.get("eyes"))
    if eye_color:
        details.append(f"eye color: {eye_color}")

    # --- Skin ----------------------------------------------------------------
    skin = _humanize(ca.get("skin_tone")) or _humanize(ca.get("skin"))
    if skin:
        details.append(f"skin tone: {skin}")

    # --- Clothing ------------------------------------------------------------
    clothing_style = _humanize(ca.get("clothing_style"))
    clothing_colors = _humanize(ca.get("clothing_colors"))
    outfit = _humanize(ca.get("outfit"))
    if outfit:
        details.append(f"wearing: {outfit}")
    elif clothing_style or clothing_colors:
        clothing_phrase = " ".join(p for p in (clothing_colors, clothing_style) if p)
        details.append(f"wearing: {clothing_phrase} clothing")

    # --- Gender --------------------------------------------------------------
    gender = _humanize(ca.get("gender"))
    if gender:
        details.append(f"gender: {gender}")

    # --- Distinguishing feature (MT-129) -------------------------------------
    # A single notable visual cue from photo analysis (e.g. "round glasses",
    # "freckles", "curly bangs"). High recognisability signal — passed verbatim.
    distinguishing = _humanize(ca.get("distinguishing"))
    if distinguishing:
        details.append(f"notable feature: {distinguishing}")

    return details


def _detect_mime_type(data: bytes) -> str:
    """Detect image MIME type from magic bytes."""
    if data[:8] == b"\x89PNG\r\n\x1a\n":
        return "image/png"
    if data[:3] == b"\xff\xd8\xff":
        return "image/jpeg"
    if data[:6] in (b"GIF87a", b"GIF89a"):
        return "image/gif"
    if data[:4] == b"RIFF" and data[8:12] == b"WEBP":
        return "image/webp"
    return "image/jpeg"  # fallback


class GeminiImageGenerator:
    def __init__(self, api_key=None):
        """Initialize with Gemini API key"""
        primary = api_key or os.getenv("GEMINI_API_KEY")
        self._model_name = "gemini-2.5-flash-image"
        self._request_timeout_seconds = int(
            os.getenv("GEMINI_IMAGE_REQUEST_TIMEOUT_SECONDS", "120")
        )
        # Build rotation pool: primary key + GOOGLE_API_KEY_2/3/4
        rotation_keys = [
            os.getenv("GOOGLE_API_KEY_2"),
            os.getenv("GOOGLE_API_KEY_3"),
            os.getenv("GOOGLE_API_KEY_4"),
        ]
        self._api_keys = [k for k in ([primary] + rotation_keys) if k]
        self._client = None
        self.api_key = self._api_keys[0] if self._api_keys else None
        if self.api_key:
            from google import genai

            self._client = genai.Client(api_key=self.api_key)

    def _client_for_key(self, api_key: str):
        from google import genai

        return genai.Client(api_key=api_key)

    def _call_with_rotation(self, fn):
        """Try fn(client) with each key in the rotation pool on ResourceExhausted."""
        from google.genai import errors as genai_errors

        last_exc = None
        for key in self._api_keys:
            client = self._client_for_key(key)
            try:
                return fn(client)
            except genai_errors.ClientError as e:
                if (
                    e.status_code == 429
                    or "ResourceExhausted" in str(e)
                    or "RESOURCE_EXHAUSTED" in str(e)
                ):
                    logger.warning(
                        f"Gemini image key quota exhausted, rotating to next key"
                    )
                    last_exc = e
                    continue
                raise
        raise last_exc or RuntimeError("All Gemini image API keys exhausted")

    def _ensure_client(self):
        if not self._client:
            raise RuntimeError("Gemini client is not initialized")

    def _process_image_response(self, response, prompt) -> list:
        """Helper to process the response from generate_content and extract images from Nano Banana."""
        images = []
        try:
            if hasattr(response, "candidates") and response.candidates:
                for i, candidate in enumerate(response.candidates):
                    if hasattr(candidate, "content") and hasattr(
                        candidate.content, "parts"
                    ):
                        for part in candidate.content.parts:
                            # Nano Banana returns images differently - check for inline_data attribute
                            if hasattr(part, "inline_data") and part.inline_data:
                                try:
                                    image_data = part.inline_data.data

                                    # Resize image to max 1024x1024 to save memory
                                    try:
                                        with Image.open(io.BytesIO(image_data)) as img:
                                            img.thumbnail(
                                                (1024, 1024), Image.Resampling.LANCZOS
                                            )
                                            buffer = io.BytesIO()
                                            img.save(buffer, format="PNG")
                                            image_data = buffer.getvalue()
                                    except Exception as e:
                                        logger.warning(f"Failed to resize image: {e}")

                                    # Data is already bytes, encode to base64
                                    images.append(
                                        {
                                            "id": f"{uuid.uuid4()}_{i}",
                                            "prompt": prompt,
                                            "image_data": base64.b64encode(
                                                image_data
                                            ).decode("utf-8"),
                                            "format": "png",
                                            "generated_at": datetime.now().isoformat(),
                                        }
                                    )
                                    logger.info(
                                        f"Successfully extracted image {i} from Nano Banana response"
                                    )
                                except Exception as e:
                                    logger.error(
                                        f"Failed to extract image data from part: {e}"
                                    )
            else:
                logger.warning("Response has no candidates or unexpected structure")
        except Exception:
            logger.exception("Error processing image response from Nano Banana")

        return images

    def _generate_content_with_timeout(self, contents, *, with_rotation: bool = False):
        """
        Call ``models.generate_content`` bounded by ``_request_timeout_seconds``.

        ``contents`` may be a plain prompt string or a list of parts (prompt +
        reference image). On timeout this raises ``FuturesTimeoutError`` and
        returns promptly — the executor is shut down with ``wait=False`` so the
        orphaned API thread does not pin the request (MT-155).

        When ``with_rotation`` is True the call is retried across the
        GEMINI_API_KEY / GOOGLE_API_KEY_2..4 rotation pool on quota errors;
        the per-attempt timeout still applies to each key.
        """
        from google.genai import types

        config = types.GenerateContentConfig(
            response_modalities=["IMAGE"],
            safety_settings=_CHILD_IMAGE_SAFETY_SETTINGS,
        )

        def _invoke(client):
            executor = ThreadPoolExecutor(max_workers=1)
            future = executor.submit(
                client.models.generate_content,
                model=self._model_name,
                contents=contents,
                config=config,
            )
            try:
                return future.result(timeout=self._request_timeout_seconds)
            finally:
                executor.shutdown(wait=False, cancel_futures=True)

        if with_rotation:
            return self._call_with_rotation(_invoke)
        return _invoke(self._client)

    def _read_avatar_details(self, avatar: dict) -> list:
        """Extract appearance strings from avatar dict.
        Supports both flat camelCase keys (Flutter mapper output) and nested
        'attributes' dict (raw GeneratedAvatar.toJson() format)."""
        details = []
        attrs = avatar.get("attributes") or {}
        hair_style = (
            avatar.get("hairStyle") or attrs.get("hair_style") or attrs.get("hairStyle")
        )
        hair_color = (
            avatar.get("hairColor") or attrs.get("hair_color") or attrs.get("hairColor")
        )
        skin_color = (
            avatar.get("skinColor") or attrs.get("skin_tone") or attrs.get("skinTone")
        )
        top_type = avatar.get("topType") or attrs.get("outfit") or attrs.get("topType")
        if hair_style:
            details.append(f"hairstyle: {hair_style}")
        if hair_color:
            details.append(f"hair color: {hair_color}")
        if skin_color:
            details.append(f"skin: {skin_color}")
        if top_type:
            details.append(f"clothing: {top_type}")
        return details

    def generate_story_illustration(
        self,
        scene_description: str,
        character_name: str = "the hero",
        style: str = "children's book illustration",
        num_images: int = 1,
        age: int = 7,
        therapeutic_focus: str | None = None,
        character_appearance: dict | None = None,
        companions: list | None = None,
        user_id: str | None = None,
        power_id: str | None = None,
    ) -> list:
        """
        Generate therapeutic story illustrations using Gemini 1.5 Pro.
        """
        if not self._client:
            logger.warning(
                "Gemini image generator unavailable; skipping illustration generation"
            )
            return []
        # Determine detail level based on age
        if age <= 5:
            detail_level = "soft rounded shapes, expressive faces, warm glowing colors, simple readable scenes, toy-like 3D storybook charm"
            age_descriptor = "young children (ages 3-5)"
        elif age <= 11:
            detail_level = "balanced details with fun elements, engaging and colorful"
            age_descriptor = "children (ages 6-11)"
        elif age <= 17:
            detail_level = "intricate artwork with rich details, sophisticated and relatable for teens"
            age_descriptor = "teenagers (ages 12-17)"
        else:
            detail_level = "sophisticated, nuanced artwork with depth and symbolism, suitable for adult reflection"
            age_descriptor = "adults (18+)"

        # Build therapeutic context
        therapeutic_context = ""
        if therapeutic_focus:
            therapeutic_context = f"\nTherapeutic focus: Emphasize {therapeutic_focus} through positive, empowering imagery"

        # Build character appearance description
        character_description = f"Main character: {character_name}"
        reference_image_bytes = None

        if character_appearance:
            appearance_details = []

            # Check for custom avatar image
            custom_avatar_b64 = character_appearance.get("custom_avatar_base64")
            if custom_avatar_b64:
                try:
                    if "," in custom_avatar_b64:
                        custom_avatar_b64 = custom_avatar_b64.split(",", 1)[1]
                    reference_image_bytes = base64.b64decode(custom_avatar_b64)
                    appearance_details.append(
                        "This character MUST look exactly like the provided reference photo"
                    )
                except Exception as e:
                    logger.warning(f"Failed to decode custom avatar image: {e}")

            # MT-129: physical characteristics. Reads BOTH the rich snake_case
            # keys the Flutter app sends (hair_color/eye_color/skin_tone/etc.)
            # AND the legacy flat hair/skin/outfit keys — see
            # build_appearance_details() for the full key contract.
            appearance_details.extend(build_appearance_details(character_appearance))

            # Add avatar details if available
            if character_appearance.get("avatar"):
                appearance_details.extend(
                    self._read_avatar_details(character_appearance["avatar"])
                )

            if appearance_details:
                character_description += f" ({', '.join(appearance_details)})"

        # Build companions description
        companions_text = ""
        if companions and len(companions) > 0:
            companion_descriptions = []
            for companion in companions:
                if isinstance(companion, dict):
                    comp_name = companion.get("name", "companion")
                    comp_type = companion.get("type", "")
                    if comp_type:
                        companion_descriptions.append(f"{comp_name} (a {comp_type})")
                    else:
                        companion_descriptions.append(comp_name)
                elif isinstance(companion, str):
                    companion_descriptions.append(companion)

            if companion_descriptions:
                companions_text = f"\nCompanions/Friends: {', '.join(companion_descriptions)} - IMPORTANT: Include these characters in the scene!"

        # Strip text-rendering cues from the scene description. The story narration
        # uses ALL-CAPS onomatopoeia ("TINKLE TINKLE", "STOMP-STOMP") and *asterisk
        # emphasis* per the story prompt — but Imagen interprets those as "render
        # this as visible text in the image" and outputs gibberish like
        # "Willihrs litte leokied" or "Playbinbe". Lowercase loud words and remove
        # asterisk emphasis before substituting into the visual prompt.
        import re as _re_visual

        visual_scene = scene_description
        visual_scene = _re_visual.sub(r"\*+([^*]+)\*+", r"\1", visual_scene)
        visual_scene = _re_visual.sub(
            r"\b([A-Z]{3,}(?:[-\s]+[A-Z]{3,})*)\b",
            lambda m: m.group(1).lower(),
            visual_scene,
        )

        prompt = f"""
Create {num_images} vibrant, engaging {style} that depicts this exact scene from the story.

ABSOLUTE RULE: This is a pure illustration with ZERO readable text. No letters, no words, no captions,
no speech bubbles, no signs with writing, no scrolls, no labels, no banners, no scribbles that resemble
text. If the scene description below contains words in quotes or capitals, those represent SOUNDS the
characters make — depict them through facial expression, motion lines, or sparkle effects, never as
visible writing in the image.

SCENE (depict the action/setting, never the words): {visual_scene}
{character_description}
Target audience: {age_descriptor} (person is {age} years old)
Detail level: {detail_level}{therapeutic_context}{companions_text}
{_power_visual_block(power_id)}
CRITICAL REQUIREMENTS:
- The illustration MUST match the SCENE description above (same setting, action, and mood).
- The main character MUST match the selected character exactly: {character_description}
- Keep character appearance consistent with the provided description (hair/skin/outfit/etc).
- If a reference photo is provided, match the character's facial features and likeness precisely.
- If companions are listed, they MUST appear in the illustration and be clearly visible as companions{companions_text if companions_text else ""}

Visual requirements:
- Full color, vibrant and appealing
- Positive, uplifting emotional tone
- Show characters in action, expressing emotions appropriately
- Include diverse, inclusive representations
- Age-appropriate content for {age_descriptor}
- For ages 3-5, prefer warm rounded storybook animation, soft edges, clear emotional readability, and zero harsh or scary visual elements
- Dynamic composition with balanced elements
- Professional illustration quality
- No text or words in the image
- Therapeutic value: promote emotional expression, growth, and positivity
- Respectful, safe, and appropriate for the intended age group
- MATCH THE CHARACTER APPEARANCE EXACTLY as described above

Style: {style}, optimized for {age_descriptor}
"""

        try:
            from google.genai import types

            logger.info(
                "Calling Gemini image generation with prompt preview: %s",
                prompt[:200].replace("\n", " "),
            )

            # Prepare contents
            contents = [prompt]
            if reference_image_bytes:
                contents.append(
                    types.Part.from_bytes(
                        data=reference_image_bytes, mime_type="image/png"
                    )
                )

            # Generate images with Gemini
            response = self._client.models.generate_content(
                model=self._model_name,
                contents=contents,
                config=types.GenerateContentConfig(
                    response_modalities=["IMAGE"],
                    safety_settings=_CHILD_IMAGE_SAFETY_SETTINGS,
                ),
            )
            images = self._process_image_response(response, prompt)
            candidate_count = len(getattr(response, "candidates", []) or [])
            logger.info(
                "Gemini image generation returned %s candidates and %s image(s)",
                candidate_count,
                len(images),
            )
            try:
                from backend.services.cost_tracker import (
                    gemini_image_cost,
                    log_api_cost,
                )

                log_api_cost(
                    provider="gemini_image",
                    feature="story_illustration",
                    cost_usd=gemini_image_cost(len(images)),
                    user_id=user_id,
                    units=len(images),
                    unit_kind="images",
                    success=len(images) > 0,
                    extra={"model": self._model_name, "age": age},
                )
            except Exception:
                logger.debug("cost_tracker logging failed", exc_info=True)
            return images
        except FuturesTimeoutError:
            logger.warning(
                "Gemini image generation timed out after %ss",
                self._request_timeout_seconds,
            )
            try:
                from backend.services.cost_tracker import log_api_cost

                log_api_cost(
                    provider="gemini_image",
                    feature="story_illustration",
                    cost_usd=0.0,
                    user_id=user_id,
                    success=False,
                    extra={"error": "timeout", "model": self._model_name},
                )
            except Exception:
                logger.debug("cost_tracker logging failed", exc_info=True)
            return []
        except Exception as e:
            # Check for quota errors
            error_msg = str(e).lower()
            if "429" in str(e) or "quota" in error_msg or "exceeded" in error_msg:
                logger.warning(
                    "Gemini API quota exceeded. Please check your billing or wait for quota reset."
                )
                logger.warning(f"Quota error details: {str(e)[:200]}")
            elif "resource_exhausted" in error_msg or "rate" in error_msg:
                logger.warning(
                    "Gemini API rate limit reached. Requests are being throttled."
                )
            else:
                logger.exception("Error generating image with Gemini")
            try:
                from backend.services.cost_tracker import log_api_cost

                log_api_cost(
                    provider="gemini_image",
                    feature="story_illustration",
                    cost_usd=0.0,
                    user_id=user_id,
                    success=False,
                    extra={"error": str(e)[:120], "model": self._model_name},
                )
            except Exception:
                logger.debug("cost_tracker logging failed", exc_info=True)
            return []

    def generate_coloring_page(
        self,
        scene_description: str,
        character_name: str = "the hero",
        num_images: int = 1,
        age: int = 7,
        therapeutic_focus: str | None = None,
        character_appearance: dict | None = None,
        companions: list | None = None,
    ) -> list:
        """
        Generate therapeutic coloring book pages with black and white line art.
        """
        if not self._client:
            logger.warning(
                "Gemini image generator unavailable; skipping coloring page generation"
            )
            return []
        # Determine intricacy based on age
        if age <= 5:
            intricacy = "very simple shapes with large coloring areas, minimal details, easy for small hands"
            line_thickness = "very thick, bold lines"
            age_descriptor = "young children (ages 3-5)"
        elif age <= 11:
            intricacy = "moderate details with interesting elements to color, balanced complexity"
            line_thickness = "medium-thick lines"
            age_descriptor = "children (ages 6-11)"
        elif age <= 17:
            intricacy = "highly detailed Zentangle-inspired patterns or intricate manga-style art, sophisticated designs for focused coloring"
            line_thickness = "varied line weights with fine detail work"
            age_descriptor = "teenagers (ages 12-17)"
        else:
            intricacy = "complex, intricate patterns with fine details, meditative and sophisticated designs"
            line_thickness = "varied line weights with intricate detail work"
            age_descriptor = "adults (18+)"

        # Build therapeutic context
        therapeutic_context = ""
        if therapeutic_focus:
            therapeutic_context = f"\nTherapeutic purpose: Design promotes {therapeutic_focus} through calming, positive imagery"

        # Build character appearance description
        character_description = f"Main character: {character_name}"
        reference_image_bytes = None

        if character_appearance:
            appearance_details = []

            # Check for custom avatar image
            custom_avatar_b64 = character_appearance.get("custom_avatar_base64")
            if custom_avatar_b64:
                try:
                    if "," in custom_avatar_b64:
                        custom_avatar_b64 = custom_avatar_b64.split(",", 1)[1]
                    reference_image_bytes = base64.b64decode(custom_avatar_b64)
                    appearance_details.append(
                        "This character MUST look exactly like the provided reference photo"
                    )
                except Exception as e:
                    logger.warning(f"Failed to decode custom avatar image: {e}")

            # MT-129: physical characteristics — reads both the rich
            # snake_case keys and the legacy flat keys (see
            # build_appearance_details()).
            appearance_details.extend(build_appearance_details(character_appearance))

            # Add avatar details if available
            if character_appearance.get("avatar"):
                appearance_details.extend(
                    self._read_avatar_details(character_appearance["avatar"])
                )

            if appearance_details:
                character_description += f" ({', '.join(appearance_details)})"

        # Build companions description
        companions_text = ""
        if companions and len(companions) > 0:
            companion_descriptions = []
            for companion in companions:
                if isinstance(companion, dict):
                    comp_name = companion.get("name", "companion")
                    comp_type = companion.get("type", "")
                    if comp_type:
                        companion_descriptions.append(f"{comp_name} (a {comp_type})")
                    else:
                        companion_descriptions.append(comp_name)
                elif isinstance(companion, str):
                    companion_descriptions.append(companion)

            if companion_descriptions:
                companions_text = f"\nCompanions/Friends: {', '.join(companion_descriptions)} - IMPORTANT: Include these characters in the scene!"

        prompt = f"""
Create {num_images} whimsical, high-quality therapeutic coloring book page(s) featuring elements from a personalized story.

Story context: {scene_description}
{character_description}
Target audience: {age_descriptor} (person is {age} years old)
Intricacy level: {intricacy}
Line style: {line_thickness}{therapeutic_context}{companions_text}

Critical requirements:
- BLACK LINE ART ONLY on pure white background
- ABSOLUTELY NO colors, fills, shading, or gray tones
- 100% black outlines for coloring
- {intricacy}
- Balanced composition covering 70%+ of the page with interesting things to color
- High contrast for easy visibility
- Positive, uplifting content only
- Age-appropriate for {age_descriptor}
- No text or words in the image
- Printable quality (suitable for app display or printing)
- MATCH THE CHARACTER APPEARANCE EXACTLY: {character_description}
- If a reference photo is provided, match the character's facial features and likeness precisely.
- If companions are listed, they MUST appear in the coloring page{companions_text if companions_text else ""}

DELIGHTFUL DETAILS FOR CHILDREN:
- Incorporate fun, magical background elements related to the story
- Add interesting patterns (stars, swirls, flowers, gears) in the environment
- Include small hidden details like tiny forest creatures, hidden stars, or little bugs for the child to discover and color
- Ensure the scene feels full of wonder and discovery
- Use clear, closed shapes so that coloring stays within the lines easily

Design style: Clean line art coloring page, therapeutic and story-based, full of whimsical details for {age_descriptor}
        Output: Pure black lines on white background only
"""

        try:
            from google.genai import types

            logger.info(
                "Calling Gemini coloring page generation with prompt preview: %s",
                prompt[:200].replace("\n", " "),
            )

            # Prepare contents
            contents = [prompt]
            if reference_image_bytes:
                contents.append(
                    types.Part.from_bytes(
                        data=reference_image_bytes, mime_type="image/png"
                    )
                )

            # Generate images with Gemini
            response = self._client.models.generate_content(
                model=self._model_name,
                contents=contents,
                config=types.GenerateContentConfig(
                    response_modalities=["IMAGE"],
                    safety_settings=_CHILD_IMAGE_SAFETY_SETTINGS,
                ),
            )
            images = self._process_image_response(response, prompt)
            candidate_count = len(getattr(response, "candidates", []) or [])
            logger.info(
                "Gemini coloring generation returned %s candidates and %s image(s)",
                candidate_count,
                len(images),
            )
            return images
        except FuturesTimeoutError:
            logger.warning(
                "Gemini coloring generation timed out after %ss",
                self._request_timeout_seconds,
            )
            return []
        except Exception:
            logger.exception("Error generating coloring page with Gemini")
            return []

    def generate_custom_avatar(
        self,
        base_image_bytes: bytes,
        prompt: str,
        character_name: str,
        age: int,
        num_images: int = 1,
    ) -> list:
        """
        Generate a custom magical avatar based on a reference photo.

        Args:
            base_image_bytes: Bytes of the reference photo
            prompt: Complete avatar generation prompt
            character_name: Character's name
            age: Character age
            num_images: Number of variations (default: 1)

        Returns:
            List of image dicts with base64-encoded PNG data
        """
        if not self._client:
            logger.warning(
                "Gemini image generator unavailable; skipping custom avatar generation"
            )
            return []

        try:
            from google.genai import types

            logger.info(
                f"Generating custom avatar for {character_name} using reference photo"
            )

            mime_type = _detect_mime_type(base_image_bytes)
            contents = [
                prompt,
                types.Part.from_bytes(data=base_image_bytes, mime_type=mime_type),
            ]

            # MT-155: bound the Gemini call with a per-attempt timeout (was an
            # unbounded synchronous call — a single slow image generation could
            # run ~110s and was the root cause of the /generate-custom-avatar
            # 504s). Key rotation also kicks in here on quota exhaustion.
            response = self._generate_content_with_timeout(contents, with_rotation=True)

            # Process response and extract images
            images = self._process_image_response(response, prompt)

            candidate_count = len(getattr(response, "candidates", []) or [])
            logger.info(
                f"Custom avatar generation returned {candidate_count} candidates and {len(images)} image(s)"
            )

            return images

        except FuturesTimeoutError:
            logger.warning(
                "Gemini custom avatar generation timed out after %ss for %s",
                self._request_timeout_seconds,
                character_name,
            )
            return []
        except Exception as e:
            logger.exception(f"Error generating custom avatar with Gemini: {e}")
            return []

    def tweak_gallery_avatar(
        self,
        image_bytes: bytes,
        hair_length: str | None = None,
        eye_color: str | None = None,
    ) -> list:
        """
        Edit a curated gallery avatar by changing specific features.

        Sends the WebP image bytes to Gemini along with a precise edit instruction
        that asks the model to change only the requested attributes and keep
        everything else identical.
        """
        if not self._client:
            logger.warning(
                "Gemini image generator unavailable; skipping gallery avatar tweak"
            )
            return []

        changes = []
        if hair_length:
            changes.append(f"hair style to {hair_length}")
        if eye_color:
            changes.append(f"eye color to {eye_color}")

        if not changes:
            logger.warning("tweak_gallery_avatar called with no changes requested")
            return []

        changes_text = " and ".join(changes)
        prompt = (
            "This is a Pixar-style storybook character illustration. "
            "Keep EVERYTHING exactly the same — face shape, skin tone, facial features, "
            "clothing, background, art style, pose, and all other details. "
            f"ONLY change: {changes_text}. "
            "Do not alter anything else whatsoever. "
            "Output the full character with only those specific changes applied."
        )

        try:
            from google.genai import types

            logger.info(f"Tweaking gallery avatar: {changes_text}")

            contents = [
                types.Part.from_bytes(data=image_bytes, mime_type="image/webp"),
                prompt,
            ]

            response = self._client.models.generate_content(
                model=self._model_name,
                contents=contents,
                config=types.GenerateContentConfig(
                    response_modalities=["IMAGE"],
                    safety_settings=_CHILD_IMAGE_SAFETY_SETTINGS,
                ),
            )

            images = self._process_image_response(response, prompt)
            logger.info(f"Gallery avatar tweak returned {len(images)} image(s)")
            return images

        except Exception as e:
            logger.exception(f"Error tweaking gallery avatar with Gemini: {e}")
            return []

    def transform_to_superhero(
        self,
        image_bytes: bytes,
        *,
        costume_color: str | None = None,
        cape_style: str | None = None,
        emblem: str | None = None,
        power: str | None = None,
        mime_type: str = "image/webp",
    ) -> list:
        """Re-render an existing character avatar as a superhero portrait.

        Takes the child's already-generated avatar as a reference and adds the
        chosen costume (color + cape + emblem) and a power-themed action pose,
        while preserving face/hair/skin likeness. Child-safe, non-photorealistic.
        Mirrors :meth:`tweak_gallery_avatar`'s call shape.
        """
        if not self._client:
            logger.warning(
                "Gemini image generator unavailable; skipping superhero transform"
            )
            return []

        prompt = build_superhero_transform_prompt(
            costume_color=costume_color,
            cape_style=cape_style,
            emblem=emblem,
            power=power,
        )

        try:
            from google.genai import types

            logger.info("Transforming avatar to superhero portrait")

            contents = [
                types.Part.from_bytes(data=image_bytes, mime_type=mime_type),
                prompt,
            ]

            response = self._client.models.generate_content(
                model=self._model_name,
                contents=contents,
                config=types.GenerateContentConfig(
                    response_modalities=["IMAGE"],
                    safety_settings=_CHILD_IMAGE_SAFETY_SETTINGS,
                ),
            )

            images = self._process_image_response(response, prompt)
            logger.info(f"Superhero transform returned {len(images)} image(s)")
            return images

        except Exception as e:
            logger.exception(f"Error transforming avatar to superhero: {e}")
            return []

    def generate_character_avatar(
        self,
        prompt: str,
        character_name: str,
        age: int,
        style: str = "pixar",
        num_images: int = 1,
        user_id: str | None = None,
    ) -> list:
        """
        Generate a magical, non-photorealistic character avatar for children.

        This method is specifically designed for avatar generation with strict
        safety controls to ensure non-photorealistic, child-safe output.

        Args:
            prompt: Complete avatar generation prompt (from AvatarPromptService)
            character_name: Character's name
            age: Character age (3-17)
            style: Art style (pixar|watercolor|cartoon|clay)
            num_images: Number of avatar variations to generate (default: 1)

        Returns:
            List of image dicts with base64-encoded PNG data
        """
        if not self._client:
            logger.warning(
                "Gemini image generator unavailable; skipping avatar generation"
            )
            return []

        # Add Gemini-specific safety reinforcement to the prompt
        # The prompt already comes with safety rules from AvatarPromptService
        # We add model-specific parameters here
        enhanced_prompt = f"""{prompt}

CRITICAL REMINDER FOR IMAGE MODEL:
- This is for a {age}-year-old child's personalized story character
- Output MUST be {style} artistic style - absolutely NO photorealism
- Portrait orientation, shoulders up, frontal view
- Professional children's character design quality
- Magical, whimsical, and delightful
- 1:1 aspect ratio (square format) for avatar display
"""

        try:
            logger.info(f"Generating {style} avatar for {character_name}, age {age}")
            logger.debug(
                f"Avatar prompt preview: {enhanced_prompt[:250].replace(chr(10), ' ')}..."
            )

            # Generate avatar with Gemini
            response = self._generate_content_with_timeout(enhanced_prompt)

            # Process response and extract images
            images = self._process_image_response(response, enhanced_prompt)

            candidate_count = len(getattr(response, "candidates", []) or [])
            logger.info(
                f"Avatar generation returned {candidate_count} candidates and {len(images)} image(s)"
            )

            if not images:
                logger.warning(f"No images generated for avatar: {character_name}")

            try:
                from backend.services.cost_tracker import (
                    gemini_image_cost,
                    log_api_cost,
                )

                log_api_cost(
                    provider="gemini_image",
                    feature="character_avatar",
                    cost_usd=gemini_image_cost(len(images)),
                    user_id=user_id,
                    units=len(images),
                    unit_kind="images",
                    success=len(images) > 0,
                    extra={"model": self._model_name, "style": style, "age": age},
                )
            except Exception:
                logger.debug("cost_tracker logging failed", exc_info=True)
            return images

        except FuturesTimeoutError:
            logger.warning(
                "Gemini avatar generation timed out after %ss for %s",
                self._request_timeout_seconds,
                character_name,
            )
            try:
                from backend.services.cost_tracker import log_api_cost

                log_api_cost(
                    provider="gemini_image",
                    feature="character_avatar",
                    cost_usd=0.0,
                    user_id=user_id,
                    success=False,
                    extra={"error": "timeout", "model": self._model_name},
                )
            except Exception:
                logger.debug("cost_tracker logging failed", exc_info=True)
            return []
        except Exception as e:
            logger.exception(f"Error generating character avatar with Gemini: {e}")
            try:
                from backend.services.cost_tracker import log_api_cost

                log_api_cost(
                    provider="gemini_image",
                    feature="character_avatar",
                    cost_usd=0.0,
                    user_id=user_id,
                    success=False,
                    extra={"error": str(e)[:120], "model": self._model_name},
                )
            except Exception:
                logger.debug("cost_tracker logging failed", exc_info=True)
            return []

    def generate_pet_avatar(
        self,
        photo_bytes: bytes,
        species: str,
        breed_description: str,
        owner_favorite_color: str,
        pet_name: str = "your pet",
        num_images: int = 1,
        prompt: str = None,
    ) -> list:
        """
        Generate a magical pet companion avatar based on a reference photo and metadata.

        Args:
            photo_bytes: Bytes of the pet's photo
            species: Pet's species (e.g., dog, cat, hamster)
            breed_description: Description of the pet's breed/markings
            owner_favorite_color: Favorite color of the owner (for accessories)
            pet_name: Pet's name (optional)
            num_images: Number of variations (default: 1)
            prompt: Optional pre-built prompt (if not provided, one will be built)

        Returns:
            List of image dicts with base64-encoded PNG data
        """
        if not self._client:
            logger.warning(
                "Gemini image generator unavailable; skipping pet avatar generation"
            )
            return []

        # If prompt is not provided, build a basic one, but usually it should come from the service
        if not prompt:
            prompt = f"""
Create a magical Pixar-style 3D animated character portrait of {pet_name}, a {species}.
Breed/Appearance: {breed_description}
Owner's Favorite Color: {owner_favorite_color}

MANDATORY REQUIREMENTS:
- Match the breed characteristics and unique markings of the pet in the reference photo.
- Include a magical collar or harness in a jewel-tone version of {owner_favorite_color}.
- Professional children's book illustration style with soft cinematic lighting.
- Whimsical, painterly storybook forest background with glowing mushrooms.
- Non-photorealistic, clearly stylized and magical.
"""

        try:
            from google.genai import types

            logger.info(
                f"Generating magical pet avatar for {pet_name} ({species}) using reference photo"
            )

            mime_type = _detect_mime_type(photo_bytes)
            contents = [
                prompt,
                types.Part.from_bytes(data=photo_bytes, mime_type=mime_type),
            ]

            # MT-155: bounded, rotation-aware call (previously an unbounded
            # synchronous generate_content under _call_with_rotation).
            response = self._generate_content_with_timeout(contents, with_rotation=True)

            images = self._process_image_response(response, prompt)

            candidate_count = len(getattr(response, "candidates", []) or [])
            logger.info(
                f"Pet avatar generation returned {candidate_count} candidates and {len(images)} image(s)"
            )

            return images

        except FuturesTimeoutError:
            logger.warning(
                "Gemini pet avatar generation timed out after %ss for %s",
                self._request_timeout_seconds,
                pet_name,
            )
            return []
        except Exception as e:
            logger.exception(f"Error generating pet avatar with Gemini: {e}")
            return []


# Example usage
if __name__ == "__main__":
    generator = GeminiImageGenerator()

    # Test story illustration
    print("Generating story illustration...")
    illustrations = generator.generate_story_illustration(
        scene_description="A brave 7-year-old girl named Isabella discovers a glowing magic crystal in an enchanted forest",
        character_name="Isabella",
        style="vibrant children's book illustration",
    )

    if illustrations:
        print(f"✓ Generated {len(illustrations)} illustration(s)")
        print(f"  Prompt: {illustrations[0]['prompt'][:100]}...")
    else:
        print("✗ Failed to generate illustration")

    # Test coloring page
    print("\nGenerating coloring page...")
    coloring_pages = generator.generate_coloring_page(
        scene_description="Isabella holding a rainbow-colored magic crystal, surrounded by friendly forest animals",
        character_name="Isabella",
    )

    if coloring_pages:
        print(f"✓ Generated {len(coloring_pages)} coloring page(s)")
    else:
        print("✗ Failed to generate coloring page")
