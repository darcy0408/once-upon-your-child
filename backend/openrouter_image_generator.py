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
        num_images: int = 1
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
        prompt = f"""
{style}, high quality digital art:

{scene_description}

Main character: {character_name}

Style: colorful, vibrant, child-friendly, professional illustration, ages 4-8, engaging, imaginative, no text, clean composition
""".strip()

        images = []
        for i in range(num_images):
            try:
                # Use Stable Diffusion XL via OpenRouter
                response = requests.post(
                    f"{self.base_url}/images/generations",
                    headers={
                        "Authorization": f"Bearer {self.api_key}",
                        "HTTP-Referer": "http://localhost:5000",  # Your app URL
                        "X-Title": "Story Creator App",
                    },
                    json={
                        "model": "stabilityai/stable-diffusion-xl-base-1.0",  # Cheap & good
                        "prompt": prompt,
                        "n": 1,
                        "size": "1024x1024",
                    },
                    timeout=60,
                )

                if response.status_code == 200:
                    data = response.json()
                    image_url = data['data'][0]['url']

                    images.append({
                        'id': f"{uuid.uuid4()}_{i}",
                        'prompt': prompt,
                        'image_url': image_url,
                        'format': 'png',
                        'generated_at': datetime.now().isoformat(),
                    })
                else:
                    print(f"OpenRouter API error: {response.status_code} - {response.text}")

                # Rate limiting
                if i < num_images - 1:
                    time.sleep(1)

            except Exception as e:
                print(f"Error generating image {i+1}: {e}")

        return images

    def generate_coloring_page(
        self,
        scene_description: str,
        character_name: str = "the hero",
        num_images: int = 1
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
        prompt = f"""
black and white line art coloring book page, children's coloring book style:

{scene_description}

Main character: {character_name}

Style: simple black outlines only, no colors, no shading, no gray, thick bold lines, large areas to color, high contrast, white background, suitable for printing, similar to Disney coloring books, ages 4-8, no text
""".strip()

        images = []
        for i in range(num_images):
            try:
                response = requests.post(
                    f"{self.base_url}/images/generations",
                    headers={
                        "Authorization": f"Bearer {self.api_key}",
                        "HTTP-Referer": "http://localhost:5000",
                        "X-Title": "Story Creator App",
                    },
                    json={
                        "model": "stabilityai/stable-diffusion-xl-base-1.0",
                        "prompt": prompt,
                        "n": 1,
                        "size": "1024x1024",
                    },
                    timeout=60,
                )

                if response.status_code == 200:
                    data = response.json()
                    image_url = data['data'][0]['url']

                    images.append({
                        'id': f"{uuid.uuid4()}_{i}",
                        'prompt': prompt,
                        'image_url': image_url,
                        'format': 'png',
                        'generated_at': datetime.now().isoformat(),
                    })
                else:
                    print(f"OpenRouter API error: {response.status_code} - {response.text}")

                if i < num_images - 1:
                    time.sleep(1)

            except Exception as e:
                print(f"Error generating coloring page {i+1}: {e}")

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
