"""
Replicate Image Generation Service
Uses SDXL-Lightning for fast, cheap image generation (~$0.003 per image)
"""

import base64
import io
import logging
import os
import uuid
from datetime import datetime
import requests

logger = logging.getLogger(__name__)


class ReplicateImageGenerator:
    def __init__(self, api_key=None):
        """Initialize with Replicate API key"""
        self.api_key = api_key or os.getenv("REPLICATE_API_TOKEN")
        self.mock_mode = os.getenv("MOCK_TESTING_MODE", "false").lower() == "true"
        # Using SDXL-Lightning for speed and cost (~$0.003 per image)
        self.model = "bytedance/sdxl-lightning-4step:5599ed30703defd1d160a25a63321b4dec97101d98b4674bcc56e41f62f35637"

    def _ensure_api_key(self):
        if not self.api_key:
            raise RuntimeError("REPLICATE_API_TOKEN not set. Get one at https://replicate.com/account/api-tokens")

    def generate_story_illustration(
        self,
        scene_description: str,
        character_name: str = "the hero",
        style: str = "children's book illustration",
        num_images: int = 1,
        age: int = 7,
        therapeutic_focus: str | None = None,
        character_appearance: dict | None = None,
        companions: list | None = None
    ) -> list:
        """
        Generate story illustrations using Replicate SDXL-Lightning.

        Cost: ~$0.003 per image (ONLY when MOCK_TESTING_MODE=false)
        Speed: ~2-4 seconds

        Returns empty list in mock mode to avoid costs during testing.
        """
        # Skip image generation in mock/testing mode to avoid costs
        if self.mock_mode:
            logger.info("MOCK_TESTING_MODE enabled - skipping image generation (no cost)")
            return []

        if not self.api_key:
            logger.warning("Replicate API token not set; skipping illustration generation")
            return []

        # Build the prompt
        prompt = self._build_prompt(
            scene_description,
            character_name,
            style,
            age,
            therapeutic_focus,
            character_appearance,
            companions
        )

        try:
            logger.info(f"Generating image with Replicate: {prompt[:100]}...")

            # Call Replicate API
            response = requests.post(
                "https://api.replicate.com/v1/predictions",
                headers={
                    "Authorization": f"Bearer {self.api_key}",
                    "Content-Type": "application/json",
                },
                json={
                    "version": self.model.split(":")[1],
                    "input": {
                        "prompt": prompt,
                        "width": 1024,
                        "height": 1024,
                        "num_outputs": num_images,
                        "scheduler": "K_EULER",
                        "num_inference_steps": 4,  # Lightning is optimized for 4 steps
                    }
                },
                timeout=30
            )

            if response.status_code != 201:
                logger.error(f"Replicate API error: {response.status_code} - {response.text}")
                return []

            prediction = response.json()
            prediction_id = prediction["id"]

            # Poll for completion (SDXL-Lightning is fast, usually 2-4 seconds)
            max_attempts = 30
            for attempt in range(max_attempts):
                import time
                time.sleep(1)

                status_response = requests.get(
                    f"https://api.replicate.com/v1/predictions/{prediction_id}",
                    headers={"Authorization": f"Bearer {self.api_key}"},
                    timeout=10
                )

                if status_response.status_code != 200:
                    logger.error(f"Status check failed: {status_response.status_code}")
                    return []

                status_data = status_response.json()
                status = status_data.get("status")

                if status == "succeeded":
                    output_urls = status_data.get("output", [])
                    return self._download_images(output_urls, prompt)
                elif status == "failed":
                    logger.error(f"Image generation failed: {status_data.get('error')}")
                    return []
                elif status in ["starting", "processing"]:
                    continue
                else:
                    logger.warning(f"Unknown status: {status}")

            logger.warning("Image generation timed out")
            return []

        except Exception as e:
            logger.exception(f"Error generating image with Replicate: {e}")
            return []

    def _build_prompt(
        self,
        scene_description: str,
        character_name: str,
        style: str,
        age: int,
        therapeutic_focus: str | None,
        character_appearance: dict | None,
        companions: list | None
    ) -> str:
        """Build optimized prompt for SDXL"""

        # Age-appropriate style adjustments
        if age <= 5:
            style_modifier = "simple, colorful, cartoon style"
        elif age <= 11:
            style_modifier = "vibrant children's book illustration"
        else:
            style_modifier = "detailed storybook art"

        # Build character description
        char_desc = character_name
        if character_appearance:
            details = []
            if character_appearance.get('age'):
                details.append(f"{character_appearance['age']} years old")
            if character_appearance.get('gender'):
                details.append(character_appearance['gender'])
            if details:
                char_desc = f"{character_name} ({', '.join(details)})"

        # Build companions text
        comp_text = ""
        if companions and len(companions) > 0:
            comp_names = []
            for comp in companions:
                if isinstance(comp, dict):
                    name = comp.get('name', 'companion')
                    species = comp.get('species', '')
                    if species:
                        comp_names.append(f"{name} the {species}")
                    else:
                        comp_names.append(name)
            if comp_names:
                comp_text = f" with {', '.join(comp_names)}"

        # Construct final prompt
        prompt = f"{style_modifier}, {scene_description}, featuring {char_desc}{comp_text}, bright and engaging, safe for children, high quality digital art, colorful, friendly atmosphere"

        # Add therapeutic focus if specified
        if therapeutic_focus:
            prompt += f", promoting {therapeutic_focus}"

        # Keep prompt under 500 chars for best results
        if len(prompt) > 500:
            prompt = prompt[:497] + "..."

        return prompt

    def _download_images(self, urls: list, prompt: str) -> list:
        """Download images from URLs and convert to base64"""
        images = []

        for i, url in enumerate(urls):
            try:
                # Download image
                img_response = requests.get(url, timeout=30)
                if img_response.status_code != 200:
                    logger.error(f"Failed to download image from {url}")
                    continue

                # Convert to base64
                image_data = img_response.content
                base64_data = base64.b64encode(image_data).decode('utf-8')

                images.append({
                    'id': f"{uuid.uuid4()}_{i}",
                    'prompt': prompt,
                    'image_data': base64_data,
                    'format': 'png',
                    'generated_at': datetime.now().isoformat(),
                })

                logger.info(f"Successfully downloaded and encoded image {i}")

            except Exception as e:
                logger.error(f"Failed to process image {i}: {e}")

        return images

    def generate_coloring_page(
        self,
        scene_description: str,
        character_name: str = "the hero",
        num_images: int = 1,
        age: int = 7,
        therapeutic_focus: str | None = None,
        character_appearance: dict | None = None,
        companions: list | None = None
    ) -> list:
        """
        Generate coloring pages (black and white line art).
        """
        # Modify prompt for coloring page style
        coloring_prompt = f"black and white line art coloring page, {scene_description}, simple outlines, no shading, suitable for children age {age}, clean lines, high contrast"

        return self.generate_story_illustration(
            scene_description=coloring_prompt,
            character_name=character_name,
            style="coloring page",
            num_images=num_images,
            age=age,
            therapeutic_focus=therapeutic_focus,
            character_appearance=character_appearance,
            companions=companions
        )
