"""
OpenAI image generator (gpt-image-2) — avatar provider.

Why this exists (MT-295): Gemini's API terms prohibit child-directed apps, so
Gemini cannot legally back a kids' app. OpenAI's API *permits* serving minors
with COPPA safeguards (same eligibility class as the story-text path, which
already runs on OpenAI). A spike confirmed gpt-image-2 will stylize a child's
photo into a cartoon avatar (no refusal) with strong likeness — so this becomes
the PRIMARY avatar generator, with Replicate PhotoMaker as the fallback. Gemini
is retired from the avatar path.

Drop-in contract: methods mirror GeminiImageGenerator's avatar surface so
``AvatarGenerationService`` can use this interchangeably. Each returns a list of
``{"image_data": "<base64>"}`` dicts (what ``_extract_base64_from_results``
expects).

NOTE: gpt-image-1 deprecates 2026-10-23 — this targets gpt-image-2, which
processes input images at high fidelity automatically (no input_fidelity
param), which is what preserves likeness on the photo→avatar edit path.
"""

import io
import logging
import os
from typing import Dict, List, Optional

logger = logging.getLogger(__name__)

# gpt-image-2: current model (gpt-image-1 deprecates 2026-10-23).
OPENAI_IMAGE_MODEL = os.getenv("OPENAI_IMAGE_MODEL", "gpt-image-2")
# Square portrait — matches the avatar prompts' "1024x1024 square" instruction.
OPENAI_IMAGE_SIZE = os.getenv("OPENAI_IMAGE_SIZE", "1024x1024")
# 'auto' moderation is appropriate for a kids' app; do not lower it.
OPENAI_IMAGE_MODERATION = os.getenv("OPENAI_IMAGE_MODERATION", "auto")


class OpenAIImageGenerator:
    """Avatar image generator backed by the OpenAI Images API (gpt-image-2)."""

    def __init__(self, api_key: Optional[str] = None):
        self.api_key = api_key or os.getenv("OPENAI_API_KEY")
        if not self.api_key:
            raise ValueError("OPENAI_API_KEY is required for OpenAIImageGenerator")
        try:
            from openai import OpenAI
        except ImportError as exc:  # pragma: no cover - dependency guard
            raise ImportError(
                "The 'openai' package is required for OpenAIImageGenerator"
            ) from exc
        self._client = OpenAI(api_key=self.api_key)
        logger.info("OpenAIImageGenerator initialized (model=%s)", OPENAI_IMAGE_MODEL)

    # ------------------------------------------------------------------
    # Internal helpers
    # ------------------------------------------------------------------
    def _b64_from_response(self, response) -> Optional[str]:
        """gpt-image models return base64 in data[0].b64_json."""
        try:
            data = getattr(response, "data", None) or []
            if not data:
                return None
            b64 = getattr(data[0], "b64_json", None)
            return b64 or None
        except Exception as exc:  # pragma: no cover - defensive
            logger.warning("Could not read b64 from OpenAI image response: %s", exc)
            return None

    @staticmethod
    def _ext_for_bytes(image_bytes: bytes) -> str:
        """Best-effort file extension from magic bytes (for the SDK filename)."""
        if image_bytes.startswith(b"\x89PNG\r\n\x1a\n"):
            return "png"
        if image_bytes.startswith(b"\xff\xd8\xff"):
            return "jpg"
        if image_bytes.startswith(b"RIFF") and image_bytes[8:12] == b"WEBP":
            return "webp"
        return "png"

    def _edit(self, image_bytes: bytes, prompt: str) -> List[Dict]:
        """Photo→avatar via the image EDIT endpoint (reference photo + prompt).

        gpt-image-2 processes the input image at high fidelity automatically,
        which preserves the subject's likeness while the prompt drives the
        cartoon/illustration style.
        """
        # The SDK infers the upload content-type from the filename extension —
        # match it to the actual bytes (gpt-image-2 accepts png/jpg/webp).
        file_obj = io.BytesIO(image_bytes)
        file_obj.name = f"reference.{self._ext_for_bytes(image_bytes)}"
        response = self._client.images.edit(
            model=OPENAI_IMAGE_MODEL,
            image=file_obj,
            prompt=prompt,
            size=OPENAI_IMAGE_SIZE,
        )
        b64 = self._b64_from_response(response)
        return [{"image_data": b64}] if b64 else []

    def _generate(self, prompt: str) -> List[Dict]:
        """Text→image via the GENERATE endpoint (preset / no reference photo)."""
        response = self._client.images.generate(
            model=OPENAI_IMAGE_MODEL,
            prompt=prompt,
            size=OPENAI_IMAGE_SIZE,
            moderation=OPENAI_IMAGE_MODERATION,
        )
        b64 = self._b64_from_response(response)
        return [{"image_data": b64}] if b64 else []

    # ------------------------------------------------------------------
    # Public surface (mirrors GeminiImageGenerator) — Chunk 1: human avatars
    # ------------------------------------------------------------------
    def generate_custom_avatar(
        self,
        base_image_bytes: bytes,
        prompt: str,
        character_name: str = "",
        age: int = 0,
        num_images: int = 1,
    ) -> List[Dict]:
        """Photo → stylized kid avatar (the consented photo-avatar path)."""
        if not base_image_bytes:
            raise ValueError("base_image_bytes is required for a photo avatar")
        logger.info(
            "OpenAI custom avatar: name=%r age=%s (edit/gpt-image-2)",
            character_name,
            age,
        )
        return self._edit(base_image_bytes, prompt)

    def generate_character_avatar(
        self,
        prompt: str,
        character_name: str = "",
        age: int = 0,
        style: str = "pixar",
        num_images: int = 1,
    ) -> List[Dict]:
        """Preset / text-only avatar (no reference photo)."""
        logger.info(
            "OpenAI character avatar: name=%r age=%s style=%s (generate/gpt-image-2)",
            character_name,
            age,
            style,
        )
        return self._generate(prompt)

    # ------------------------------------------------------------------
    # Chunk 2: pet / human-companion avatars + superhero transform
    # ------------------------------------------------------------------
    def generate_pet_avatar(
        self,
        photo_bytes: bytes,
        species: str = "",
        breed_description: str = "",
        owner_favorite_color: str = "",
        pet_name: str = "your pet",
        num_images: int = 1,
        prompt: Optional[str] = None,
    ) -> List[Dict]:
        """Photo → magical pet/companion avatar. Also used (with species='Human')
        by the human-companion flow. The caller (AvatarGenerationService) builds
        the prompt; fall back to a minimal one if not supplied."""
        if not photo_bytes:
            raise ValueError("photo_bytes is required for a pet/companion avatar")
        if not prompt:
            prompt = (
                f"Turn the reference photo into a friendly storybook cartoon "
                f"{species or 'pet'} named {pet_name}. Clearly illustrated, not "
                f"photorealistic; keep recognizable markings. Soft plain "
                f"background, accent color {owner_favorite_color or 'warm'}."
            )
        logger.info(
            "OpenAI pet/companion avatar: species=%r (edit/gpt-image-2)", species
        )
        return self._edit(photo_bytes, prompt)

    def transform_to_superhero(
        self,
        image_bytes: bytes,
        *,
        costume_color: Optional[str] = None,
        cape_style: Optional[str] = None,
        emblem: Optional[str] = None,
        power: Optional[str] = None,
        mime_type: str = "image/png",
    ) -> List[Dict]:
        """Re-render an existing avatar as a superhero portrait via image edit.

        Reuses the shared ``build_superhero_transform_prompt`` so the costume /
        cape / emblem / power wording matches the rest of the app. (That helper
        is a pure prompt-string builder — no Gemini dependency.)
        """
        if not image_bytes:
            raise ValueError("image_bytes is required for a superhero transform")
        try:
            from backend.gemini_image_generator import (
                build_superhero_transform_prompt,
            )
        except ImportError:
            from gemini_image_generator import build_superhero_transform_prompt

        prompt = build_superhero_transform_prompt(
            costume_color=costume_color,
            cape_style=cape_style,
            emblem=emblem,
            power=power,
        )
        logger.info("OpenAI superhero transform (edit/gpt-image-2)")
        return self._edit(image_bytes, prompt)

    # ------------------------------------------------------------------
    # Photo feature analysis (replaces the direct Gemini vision call so the
    # avatar path no longer touches Gemini at all — MT-295).
    # ------------------------------------------------------------------
    def analyze_photo_features(self, photo_bytes: bytes) -> Dict:
        """Best-effort hair/skin/distinguishing-feature extraction via OpenAI
        vision. Returns {} on any failure (non-fatal enrichment)."""
        import base64 as _b64
        import json
        import re

        if not photo_bytes:
            return {}
        model = os.getenv("OPENAI_VISION_MODEL", "gpt-4o-mini")
        ext = self._ext_for_bytes(photo_bytes)
        mime = "image/jpeg" if ext == "jpg" else f"image/{ext}"
        data_url = f"data:{mime};base64,{_b64.b64encode(photo_bytes).decode()}"
        instruction = (
            "Analyze this photo for character-illustration reference. Return ONLY "
            "a JSON object with keys: "
            '"hair_style" (color + style, e.g. "wavy brown shoulder-length"), '
            '"skin_tone" (light/medium/olive/tan/deep), '
            '"distinguishing" (one notable feature like "round glasses" or '
            '"freckles", or ""). Use visually neutral terms only — no racial, '
            "ethnic, or nationality descriptors."
        )
        try:
            resp = self._client.chat.completions.create(
                model=model,
                messages=[
                    {
                        "role": "user",
                        "content": [
                            {"type": "text", "text": instruction},
                            {"type": "image_url", "image_url": {"url": data_url}},
                        ],
                    }
                ],
            )
            text = (resp.choices[0].message.content or "").strip()
            if text.startswith("```"):
                text = re.sub(r"^```(?:json)?\s*", "", text)
                text = re.sub(r"\s*```$", "", text)
            result = json.loads(text)
            return result if isinstance(result, dict) else {}
        except Exception as exc:  # noqa: BLE001 — best-effort enrichment
            logger.warning(
                "OpenAI photo feature extraction failed (non-fatal): %s", exc
            )
            return {}
