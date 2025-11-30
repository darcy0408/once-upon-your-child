"""
OpenRouter Image Generation Service
Uses Stable Diffusion via OpenRouter (CHEAP: ~$0.002-0.005 per image!)
Compatible with your existing OpenRouter API key
"""

import os
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

    def generate_story_illustration(
        self,
        scene_description: str,
        character_name: str = "the hero",
        style: str = "children's book illustration",
        num_images: int = 1,
        age: int | None = None,
        therapeutic_focus: str | None = None,
        **_: dict
    ) -> list:
        """
        Generate story illustrations using Stable Diffusion via OpenRouter

        Args:
            scene_description: Description of the scene to illustrate
            character_name: Name of the main character
            style: Art style
            num_images: Number of images (note: generates 1 at a time)

        Returns:
            List of dicts with image URLs or base64 data
        """
        audience = f"ages {age}" if age else "children"
        therapy = f"\nTherapeutic focus: {therapeutic_focus}" if therapeutic_focus else ""
        prompt = f"""
{style}, high quality digital art:

{scene_description}

Main character: {character_name}

Style: colorful, vibrant, child-friendly, professional illustration, {audience}, engaging, imaginative, no text, clean composition{therapy}
""".strip()

        images = []
        for i in range(num_images):
            try:
                logger.info(f"OpenRouter story_illustration: Sending request for story illustration prompt (first 100 chars): {prompt[:100]}...")
                response = requests.post(
                    f"{self.base_url}/chat/completions",
                    headers={
                        "Authorization": f"Bearer {self.api_key}",
                        "HTTP-Referer": "https://story-weaver-app-production.up.railway.app",
                        "X-Title": "Story Weaver App",
                        "Content-Type": "application/json",
                    },
                    json={
                        "model": "black-forest-labs/flux.2-flex",  # Free image model  # Free image model
                        "messages": [
                            {
                                "role": "user",
                                "content": prompt
                            }
                        ],
                    },
                    timeout=60,
                )

                if response.status_code == 200:
                    data = response.json()
                    logger.info(f"OpenRouter story_illustration: Full response data: {data}")
                    # Flux models return image data as base64 data URIs
                    content = data['choices'][0]['message']['content']
                    logger.info(f"OpenRouter story_illustration: Extracted content (first 100 chars): {content[:100]}...")

                    if content.startswith("data:image/"):
                        image_url = content  # Use the full data URI as the image_url
                        images.append({
                            'id': f"{uuid.uuid4()}_{i}",
                            'prompt': prompt,
                            'image_url': image_url,
                            'format': 'png',
                            'generated_at': datetime.now().isoformat(),
                        })
                    else:
                        logger.warning("OpenRouter response did not contain a data URI for story illustration: %s", content)
                else:
                    logger.warning("OpenRouter API error: %s - %s", response.status_code, response.text)

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
        **_: dict
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
        therapy = f"\nTherapeutic focus: {therapeutic_focus}" if therapeutic_focus else ""
        prompt = f"""
black and white line art coloring book page, children's coloring book style:

{scene_description}

Main character: {character_name}

Style: simple black outlines only, no colors, no shading, no gray, thick bold lines, large areas to color, high contrast, white background, suitable for printing, similar to Disney coloring books, {audience}, no text{therapy}
""".strip()

        images = []
        for i in range(num_images):
            try:
                logger.info(f"OpenRouter: Sending request for coloring page prompt (first 100 chars): {prompt[:100]}...")
                response = requests.post(
                    f"{self.base_url}/chat/completions",
                    headers={
                        "Authorization": f"Bearer {self.api_key}",
                        "HTTP-Referer": "https://story-weaver-app-production.up.railway.app",
                        "X-Title": "Story Weaver App",
                        "Content-Type": "application/json",
                    },
                    json={
                        "model": "black-forest-labs/flux.2-flex",
                        "messages": [
                            {
                                "role": "user",
                                "content": prompt
                            }
                        ],
                    },
                    timeout=60,
                )

                if response.status_code == 200:
                    data = response.json()
                    logger.info(f"OpenRouter coloring_page: Full response data: {data}")
                    content = data['choices'][0]['message']['content']
                    logger.info(f"OpenRouter coloring_page: Extracted content (first 100 chars): {content[:100]}...")

                    if content.startswith("data:image/"):
                        image_url = content  # Use the full data URI as the image_url
                        images.append({
                            'id': f"{uuid.uuid4()}_{i}",
                            'prompt': prompt,
                            'image_url': image_url,
                            'format': 'png',
                            'generated_at': datetime.now().isoformat(),
                        })
                    else:
                        logger.warning("OpenRouter response did not contain a data URI for coloring page: %s", content)
                else:
                    logger.warning("OpenRouter API error: %s - %s", response.status_code, response.text)

                if i < num_images - 1:
                    time.sleep(1)

            except Exception as e:
                logger.exception("Error generating coloring page %s", i + 1)

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
        style="vibrant watercolor children's book illustration"
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
        character_name="Isabella"
    )

    if coloring_pages:
        print(f"✓ Generated {len(coloring_pages)} coloring page(s)")
        print(f"  Image URL: {coloring_pages[0]['image_url']}")
    else:
        print("✗ Failed to generate coloring page")

    print("\n" + "=" * 50)
    print("Cost estimate: ~$0.004 per image (100x cheaper than DALL-E!)")
