"""
OpenRouter Image Generation Service
Uses Stable Diffusion via OpenRouter (CHEAP: ~$0.002-0.005 per image!)
Compatible with your existing OpenRouter API key
"""

import os
import re
import requests
import base64
import uuid
from datetime import datetime
import time
import logging

logger = logging.getLogger(__name__)


class OpenRouterImageGenerator:
    def __init__(self, api_key=None):
        """Initialize with OpenRouter API key"""
        self.api_key = api_key or os.getenv("OPENROUTER_API_KEY")
        self.base_url = "https://openrouter.ai/api/v1"

    def _looks_like_base64(self, value: str) -> bool:
        if not isinstance(value, str):
            return False
        stripped = value.strip()
        if stripped.startswith("data:image/") or stripped.startswith("http"):
            return False
        if len(stripped) < 200:
            return False
        return re.fullmatch(r"[A-Za-z0-9+/=\s]+", stripped) is not None

    def _extract_image_payload(self, data: dict) -> str | None:
        try:
            choice = (data.get("choices") or [])[0] or {}
            message = choice.get("message") or {}
        except Exception:
            return None

        content = message.get("content")
        # If content is string, only accept if it's a URL or large base64
        if isinstance(content, str):
            content = content.strip()
            if (
                content.startswith("data:image/")
                or content.startswith("http")
                or self._looks_like_base64(content)
            ):
                return content
            else:
                logger.info(
                    f"OpenRouter: Content is text, not image: {content[:50]}..."
                )

        if isinstance(content, list):
            for item in content:
                if not isinstance(item, dict):
                    continue
                if "image_url" in item:
                    image_url = item.get("image_url")
                    if isinstance(image_url, dict):
                        url = image_url.get("url")
                    else:
                        url = image_url
                    if url:
                        return url
                if "url" in item and item.get("type") in ("image", "image_url"):
                    return item.get("url")
                if "data" in item and item.get("type") in ("image", "image_base64"):
                    return item.get("data")
                if "image" in item and isinstance(item["image"], dict):
                    url = item["image"].get("url") or item["image"].get("data")
                    if url:
                        return url

        raw_images = (
            message.get("images") or choice.get("images") or data.get("images") or []
        )
        if isinstance(raw_images, list) and raw_images:
            img_data = raw_images[0]
            if isinstance(img_data, str):
                if (
                    img_data.startswith("data:image/")
                    or img_data.startswith("http")
                    or self._looks_like_base64(img_data)
                ):
                    return img_data
            if isinstance(img_data, dict):
                if "url" in img_data:
                    return img_data["url"]
                if "image_url" in img_data and isinstance(img_data["image_url"], dict):
                    url = img_data["image_url"].get("url")
                    if url:
                        return url

        return None

    def _download_image_bytes(self, url: str, max_size: int = 5 * 1024 * 1024) -> bytes:
        img_resp = requests.get(url, stream=True, timeout=30)
        img_resp.raise_for_status()
        content_length = img_resp.headers.get("Content-Length")
        if content_length and int(content_length) > max_size:
            raise ValueError(f"Image too large: {content_length} bytes")
        image_bytes = bytearray()
        for chunk in img_resp.iter_content(chunk_size=8192):
            image_bytes.extend(chunk)
            if len(image_bytes) > max_size:
                raise ValueError("Image exceeded size limit during download")
        return bytes(image_bytes)

    def _normalize_image_to_base64(self, image_value: str) -> str | None:
        if not image_value or not isinstance(image_value, str):
            return None
        image_value = image_value.strip()
        if image_value.startswith("data:image/"):
            return image_value.split(",", 1)[1] if "," in image_value else image_value
        if image_value.startswith("http"):
            try:
                image_bytes = self._download_image_bytes(image_value)
                return base64.b64encode(image_bytes).decode("utf-8")
            except Exception as e:
                logger.warning(f"Failed to download avatar image URL: {e}")
                return None
        if self._looks_like_base64(image_value):
            return re.sub(r"\s+", "", image_value)
        return None

    def _build_appearance_text(self, character_appearance: dict | None) -> str:
        """Flatten the appearance attribute dict into a short prompt clause.

        Enum `.name` values from the Flutter client arrive camelCase
        ("lightBrown", "vNeck") — split them back into readable words.
        """
        if not character_appearance:
            return ""
        labels = {
            "hair_color": "hair color",
            "hair_length": "hair length",
            "hair_style": "hair style",
            "eye_color": "eye color",
            "skin_tone": "skin tone",
            "clothing_style": "wearing",
            "clothing_colors": "clothing color",
        }
        parts = []
        for key, label in labels.items():
            value = character_appearance.get(key)
            if value:
                readable = re.sub(r"(?<=[a-z])(?=[A-Z])", " ", str(value)).lower()
                parts.append(f"{label}: {readable}")
        return "; ".join(parts)

    def generate_story_illustration(
        self,
        scene_description: str,
        character_name: str = "the hero",
        style: str = "children's book illustration",
        num_images: int = 1,
        age: int | None = None,
        therapeutic_focus: str | None = None,
        companions: list | None = None,
        character_appearance: dict | None = None,
        **_: dict,
    ) -> list:
        """
        Generate story illustrations using Stable Diffusion via OpenRouter

        Args:
            scene_description: Description of the scene to illustrate
            character_name: Name of the main character
            style: Art style
            num_images: Number of images (note: generates 1 at a time)
            character_appearance: Optional appearance dict. When it carries a
                'custom_avatar_base64' the avatar image is sent as a reference
                so the model matches the character's likeness across pages.

        Returns:
            List of dicts with image URLs or base64 data
        """
        audience = f"ages {age}" if age else "children"
        therapy = (
            f"\nTherapeutic focus: {therapeutic_focus}" if therapeutic_focus else ""
        )
        companion_line = ""
        if companions:
            companion_names = []
            for companion in companions:
                if isinstance(companion, dict):
                    companion_names.append(companion.get("name", "companion"))
                else:
                    companion_names.append(str(companion))
            if companion_names:
                companion_line = (
                    f"\nCompanions (must appear in scene): {', '.join(companion_names)}"
                )

        # Character likeness: a reference avatar image (preferred) keeps the
        # character visually consistent page-to-page; the text attributes are
        # always included as a fallback / reinforcement.
        appearance_text = self._build_appearance_text(character_appearance)
        reference_data_uri = None
        if character_appearance:
            raw_avatar = character_appearance.get("custom_avatar_base64")
            if raw_avatar:
                normalized = self._normalize_image_to_base64(raw_avatar)
                if normalized:
                    reference_data_uri = f"data:image/png;base64,{normalized}"

        character_line = (
            f"Main character (must match selected character): {character_name}"
        )
        if appearance_text:
            character_line += f"\nCharacter appearance: {appearance_text}"

        reference_note = ""
        if reference_data_uri:
            reference_note = (
                "\n\nA reference image of the main character is provided. The "
                "character in the illustration MUST match the reference image's "
                "face, hair, skin tone, and outfit exactly — keep the character "
                "visually identical to the reference, only changing pose and "
                "setting to fit the scene."
            )

        prompt = f"""
{style}, high quality digital art:

SCENE (must be depicted literally): {scene_description}

{character_line}
{companion_line}

Style: colorful, vibrant, child-friendly, professional illustration, {audience}, engaging, imaginative, no text, clean composition{therapy}
""".strip()

        user_text = (
            prompt
            + reference_note
            + "\n\nIMPORTANT: Respond ONLY with the generated image. Do not provide any text description or conversation."
        )
        if reference_data_uri:
            message_content = [
                {"type": "image_url", "image_url": {"url": reference_data_uri}},
                {"type": "text", "text": user_text},
            ]
        else:
            message_content = user_text

        images = []
        for i in range(num_images):
            try:
                logger.info(
                    "OpenRouter story_illustration: Sending request (reference_image=%s) prompt (first 100 chars): %s...",
                    bool(reference_data_uri),
                    prompt[:100],
                )
                response = requests.post(
                    f"{self.base_url}/chat/completions",
                    headers={
                        "Authorization": f"Bearer {self.api_key}",
                        "HTTP-Referer": "https://story-weaver-app-production.up.railway.app",
                        "X-Title": "Story Weaver App",
                        "Content-Type": "application/json",
                    },
                    json={
                        "model": "google/gemini-2.5-flash-image",  # Valid working model on OpenRouter
                        "max_tokens": 1000,
                        "messages": [
                            {
                                "role": "user",
                                "content": message_content,
                            }
                        ],
                    },
                    timeout=60,
                )

                if response.status_code == 200:
                    data = response.json()
                    # Log full response structure (truncated content) for debugging
                    logger.info(
                        f"OpenRouter story_illustration: Response keys: {data.keys()}"
                    )
                    if "choices" in data and len(data["choices"]) > 0:
                        logger.info(
                            f"OpenRouter story_illustration: Choice keys: {data['choices'][0].keys()}"
                        )
                        if "message" in data["choices"][0]:
                            logger.info(
                                f"OpenRouter story_illustration: Message keys: {data['choices'][0]['message'].keys()}"
                            )

                    image_url = self._extract_image_payload(data)

                    if image_url:
                        logger.info(
                            f"OpenRouter story_illustration: Successfully extracted image data. Length: {len(image_url)}"
                        )
                        images.append(
                            {
                                "id": f"{uuid.uuid4()}_{i}",
                                "prompt": prompt,
                                "image_url": image_url,
                                "format": "png",
                                "generated_at": datetime.now().isoformat(),
                            }
                        )
                    else:
                        # If we couldn't find an image, log the raw content for debugging
                        raw_content = str(data)[:1000]  # Log first 1000 chars
                        logger.warning(
                            f"OpenRouter response did not contain a recognized image format. Raw response start: {raw_content}"
                        )
                        # Don't append broken data, just log it
                else:
                    logger.warning(
                        "OpenRouter API error: %s - %s",
                        response.status_code,
                        response.text,
                    )

                # Rate limiting
                if i < num_images - 1:
                    time.sleep(1)

            except Exception as e:
                logger.exception("Error generating image %s", i + 1)

        return images

    def generate_coloring_page(
        self,
        scene_description: str,
        character_name: str = "the hero",
        num_images: int = 1,
        age: int | None = None,
        therapeutic_focus: str | None = None,
        companions: list | None = None,
        **_: dict,
    ) -> list:
        """
        Generate black and white line art for coloring

        Args:
            scene_description: Description of the scene
            character_name: Name of the main character
            num_images: Number of images

        Returns:
            List of dicts with image URLs
        """
        audience = f"ages {age}" if age else "children"
        therapy = (
            f"\nTherapeutic focus: {therapeutic_focus}" if therapeutic_focus else ""
        )
        companion_line = ""
        if companions:
            companion_names = []
            for companion in companions:
                if isinstance(companion, dict):
                    companion_names.append(companion.get("name", "companion"))
                else:
                    companion_names.append(str(companion))
            if companion_names:
                companion_line = (
                    f"\nCompanions (must appear in scene): {', '.join(companion_names)}"
                )

        prompt = f"""
black and white line art coloring book page, children's coloring book style:

SCENE (must be depicted literally): {scene_description}

Main character (must match selected character): {character_name}
{companion_line}

Style: simple black outlines only, no colors, no shading, no gray, thick bold lines, large areas to color, high contrast, white background, suitable for printing, similar to Disney coloring books, {audience}, no text{therapy}
""".strip()

        images = []
        for i in range(num_images):
            try:
                logger.info(
                    f"OpenRouter: Sending request for coloring page prompt (first 100 chars): {prompt[:100]}..."
                )
                response = requests.post(
                    f"{self.base_url}/chat/completions",
                    headers={
                        "Authorization": f"Bearer {self.api_key}",
                        "HTTP-Referer": "https://story-weaver-app-production.up.railway.app",
                        "X-Title": "Story Weaver App",
                        "Content-Type": "application/json",
                    },
                    json={
                        "model": "google/gemini-2.5-flash-image",
                        "max_tokens": 1000,
                        "messages": [
                            {
                                "role": "user",
                                "content": prompt
                                + "\n\nIMPORTANT: Respond ONLY with the generated image. Do not provide any text description or conversation.",
                            }
                        ],
                    },
                    timeout=60,
                )

                if response.status_code == 200:
                    data = response.json()
                    # Log full response structure (truncated content) for debugging
                    logger.info(
                        f"OpenRouter coloring_page: Response keys: {data.keys()}"
                    )

                    image_url = None

                    image_url = self._extract_image_payload(data)

                    if image_url:
                        logger.info(
                            f"OpenRouter coloring_page: Successfully extracted image data. Length: {len(image_url)}"
                        )
                        images.append(
                            {
                                "id": f"{uuid.uuid4()}_{i}",
                                "prompt": prompt,
                                "image_url": image_url,
                                "format": "png",
                                "generated_at": datetime.now().isoformat(),
                            }
                        )
                    else:
                        raw_content = str(data)[:1000]
                        logger.warning(
                            f"OpenRouter response did not contain a recognized image format for coloring page. Raw response start: {raw_content}"
                        )
                else:
                    logger.warning(
                        "OpenRouter API error: %s - %s",
                        response.status_code,
                        response.text,
                    )

                if i < num_images - 1:
                    time.sleep(1)

            except Exception as e:
                logger.exception("Error generating coloring page %s", i + 1)

        return images

    def generate_character_avatar(
        self,
        prompt: str,
        character_name: str = "the hero",
        age: int = 8,
        style: str = "pixar",
        num_images: int = 1,
        **_: dict,
    ) -> list:
        """
        Generate character avatar portrait using Stable Diffusion via OpenRouter

        Args:
            prompt: Full avatar generation prompt (from AvatarPromptService)
            character_name: Name of the character
            age: Character age
            style: Art style (pixar, watercolor, cartoon, clay)
            num_images: Number of images to generate

        Returns:
            List of dicts with image_data (base64) and metadata
        """
        images = []
        for i in range(num_images):
            try:
                logger.info(
                    f"OpenRouter avatar: Generating {style} avatar for {character_name}, age {age}"
                )
                logger.info(
                    f"OpenRouter avatar: Using prompt (first 150 chars): {prompt[:150]}..."
                )

                response = requests.post(
                    f"{self.base_url}/chat/completions",
                    headers={
                        "Authorization": f"Bearer {self.api_key}",
                        "HTTP-Referer": "https://story-weaver-app-production.up.railway.app",
                        "X-Title": "Story Weaver App - Avatar Generation",
                        "Content-Type": "application/json",
                    },
                    json={
                        "model": "google/gemini-2.5-flash-image",  # Use working model
                        "max_tokens": 1000,
                        "messages": [
                            {
                                "role": "user",
                                "content": prompt
                                + "\n\nIMPORTANT: Respond ONLY with the generated image. Do not provide any text description or conversation.",
                            }
                        ],
                    },
                    timeout=90,  # Avatar generation can take longer
                )

                if response.status_code == 200:
                    data = response.json()
                    logger.info(
                        f"OpenRouter avatar: Response received, keys: {data.keys()}"
                    )

                    image_url = self._extract_image_payload(data)

                    if image_url:
                        image_data_base64 = self._normalize_image_to_base64(image_url)
                        if image_data_base64:
                            logger.info(
                                f"OpenRouter avatar: Successfully generated avatar. Data length: {len(image_data_base64)}"
                            )
                            images.append(
                                {
                                    "id": f"{uuid.uuid4()}_{i}",
                                    "prompt": prompt,
                                    "image_data": image_data_base64,  # Return as base64 string
                                    "format": "png",
                                    "generated_at": datetime.now().isoformat(),
                                    "provider": "openrouter-flux",
                                }
                            )
                        else:
                            logger.warning(
                                "OpenRouter avatar image payload could not be normalized to base64"
                            )
                    else:
                        raw_content = str(data)[:1000]
                        logger.warning(
                            f"OpenRouter avatar response did not contain image. Raw response: {raw_content}"
                        )
                else:
                    logger.error(
                        f"OpenRouter avatar API error: {response.status_code} - {response.text}"
                    )

                # Rate limiting
                if i < num_images - 1:
                    time.sleep(1)

            except Exception as e:
                logger.exception(f"Error generating avatar image {i + 1}: {e}")

        return images

    def generate_custom_avatar(
        self,
        base_image_bytes: bytes,
        prompt: str,
        character_name: str = "the hero",
        age: int = 8,
        num_images: int = 1,
        **_: dict,
    ) -> list:
        """
        Generate a custom avatar using a reference photo + text prompt.

        Sends the uploaded photo as a base64-encoded image alongside the
        generation prompt so the model can preserve the child's likeness.
        """
        images = []
        photo_b64 = base64.b64encode(base_image_bytes).decode("utf-8")

        for i in range(num_images):
            try:
                logger.info(
                    f"OpenRouter custom avatar: Generating for {character_name}, age {age}"
                )

                response = requests.post(
                    f"{self.base_url}/chat/completions",
                    headers={
                        "Authorization": f"Bearer {self.api_key}",
                        "HTTP-Referer": "https://story-weaver-app-production.up.railway.app",
                        "X-Title": "Story Weaver App - Custom Avatar Generation",
                        "Content-Type": "application/json",
                    },
                    json={
                        "model": "google/gemini-2.5-flash-image",
                        "max_tokens": 1000,
                        "messages": [
                            {
                                "role": "user",
                                "content": [
                                    {
                                        "type": "image_url",
                                        "image_url": {
                                            "url": f"data:image/jpeg;base64,{photo_b64}"
                                        },
                                    },
                                    {
                                        "type": "text",
                                        "text": prompt
                                        + "\n\nIMPORTANT: Respond ONLY with the generated image. Do not provide any text description or conversation.",
                                    },
                                ],
                            }
                        ],
                    },
                    timeout=120,
                )

                if response.status_code == 200:
                    data = response.json()
                    image_url = self._extract_image_payload(data)

                    if image_url:
                        image_data_base64 = self._normalize_image_to_base64(image_url)
                        if image_data_base64:
                            logger.info(
                                f"OpenRouter custom avatar: Success. Data length: {len(image_data_base64)}"
                            )
                            images.append(
                                {
                                    "id": f"{uuid.uuid4()}_{i}",
                                    "prompt": prompt,
                                    "image_data": image_data_base64,
                                    "format": "png",
                                    "generated_at": datetime.now().isoformat(),
                                    "provider": "openrouter-custom-avatar",
                                }
                            )
                        else:
                            logger.warning(
                                "OpenRouter custom avatar: image payload could not be normalized"
                            )
                    else:
                        raw_content = str(data)[:1000]
                        logger.warning(
                            f"OpenRouter custom avatar: no image in response. Raw: {raw_content}"
                        )
                else:
                    logger.error(
                        f"OpenRouter custom avatar API error: {response.status_code} - {response.text}"
                    )

                if i < num_images - 1:
                    time.sleep(1)

            except Exception as e:
                logger.exception(f"Error generating custom avatar image {i + 1}: {e}")

        return images


# Example usage & testing
if __name__ == "__main__":
    # Test with your OpenRouter key
    generator = OpenRouterImageGenerator()

    print("Testing OpenRouter image generation...")
    print("=" * 50)

    # Test story illustration
    print("\n1. Generating story illustration...")
    illustrations = generator.generate_story_illustration(
        scene_description="A brave 7-year-old girl named Isabella with short brown hair and pink highlights discovers a glowing rainbow-colored magic crystal in an enchanted forest",
        character_name="Isabella",
        style="vibrant watercolor children's book illustration",
    )

    if illustrations:
        print(f"✓ Generated {len(illustrations)} illustration(s)")
        print(f"  Image URL: {illustrations[0]['image_url']}")
        print(f"  Prompt: {illustrations[0]['prompt'][:100]}...")
    else:
        print("✗ Failed to generate illustration")

    # Test coloring page
    print("\n2. Generating coloring page...")
    coloring_pages = generator.generate_coloring_page(
        scene_description="Isabella holding a rainbow-colored magic crystal, surrounded by friendly forest animals including a rabbit and a deer",
        character_name="Isabella",
    )

    if coloring_pages:
        print(f"✓ Generated {len(coloring_pages)} coloring page(s)")
        print(f"  Image URL: {coloring_pages[0]['image_url']}")
    else:
        print("✗ Failed to generate coloring page")

    print("\n" + "=" * 50)
    print("Cost estimate: ~$0.004 per image (100x cheaper than DALL-E!)")
