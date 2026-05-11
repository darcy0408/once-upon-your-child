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
            style_modifier = "warm rounded 3D storybook animation, soft lighting, clear facial expressions, child-safe emotional scene"
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

    def generate_story_illustration_flux_schnell(
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
    ) -> list:
        """Per-page story illustration via Replicate Flux Schnell (~$0.003/image).

        Used as the primary illustration provider for ages 6+ per the hybrid
        recommendation in docs/IMAGE_GEN_AB_TEST_RESULTS.md. Quality 8/10 vs
        Gemini's 10/10, but 12.5× cheaper, unlocking Family $14.99 pricing.

        Returns the same {id, prompt, image_data, format, generated_at} dict
        shape as generate_story_illustration() so callers can swap providers
        without touching response handling. Returns [] on any error so the
        endpoint's existing fallback path takes over.
        """
        if self.mock_mode:
            logger.info("MOCK_TESTING_MODE enabled - skipping Flux Schnell")
            return []
        if not self.api_key:
            logger.warning("Replicate API token not set; Flux Schnell skipped")
            return []

        prompt = self._build_prompt(
            scene_description, character_name, style, age,
            therapeutic_focus, character_appearance, companions,
        )
        import time
        t0 = time.time()

        try:
            create = requests.post(
                "https://api.replicate.com/v1/models/black-forest-labs/flux-schnell/predictions",
                headers={
                    "Authorization": f"Bearer {self.api_key}",
                    "Content-Type": "application/json",
                    "Prefer": "wait",
                },
                json={
                    "input": {
                        "prompt": prompt,
                        "num_outputs": max(1, min(num_images, 4)),
                        "aspect_ratio": "1:1",
                        "output_format": "png",
                        "output_quality": 90,
                    }
                },
                timeout=70,
            )
            if create.status_code not in (200, 201):
                logger.warning(
                    "Flux Schnell create failed: %d %s",
                    create.status_code, create.text[:200],
                )
                self._log_cost_event(False, num_images, user_id, age,
                                     error=f"create {create.status_code}")
                return []

            body = create.json()
            if body.get("status") != "succeeded":
                pid = body.get("id")
                deadline = time.time() + 90
                while time.time() < deadline:
                    time.sleep(1.5)
                    poll = requests.get(
                        f"https://api.replicate.com/v1/predictions/{pid}",
                        headers={"Authorization": f"Bearer {self.api_key}"},
                        timeout=15,
                    )
                    if poll.status_code != 200:
                        logger.warning("Flux Schnell poll failed: %d", poll.status_code)
                        self._log_cost_event(False, num_images, user_id, age,
                                             error=f"poll {poll.status_code}")
                        return []
                    body = poll.json()
                    if body.get("status") == "succeeded":
                        break
                    if body.get("status") in ("failed", "canceled"):
                        logger.warning(
                            "Flux Schnell %s: %s",
                            body.get("status"), body.get("error"),
                        )
                        self._log_cost_event(False, num_images, user_id, age,
                                             error=str(body.get("status")))
                        return []
                else:
                    logger.warning("Flux Schnell prediction timed out")
                    self._log_cost_event(False, num_images, user_id, age,
                                         error="timeout")
                    return []

            output = body.get("output") or []
            urls = output if isinstance(output, list) else [output] if isinstance(output, str) else []
            urls = [u for u in urls if u]
            if not urls:
                logger.warning("Flux Schnell returned no output URLs")
                self._log_cost_event(False, num_images, user_id, age,
                                     error="no_output")
                return []

            images = self._download_images(urls, prompt)
            self._log_cost_event(len(images) > 0, len(images), user_id, age)
            logger.info(
                "Flux Schnell %d image(s) in %.1fs",
                len(images), time.time() - t0,
            )
            return images

        except Exception as e:
            logger.exception("Flux Schnell error: %s", e)
            self._log_cost_event(False, num_images, user_id, age, error=str(e)[:120])
            return []

    def _log_cost_event(
        self,
        success: bool,
        num_images: int,
        user_id: str | None,
        age: int,
        error: str | None = None,
    ) -> None:
        """Forward a Flux Schnell call to cost_tracker. Never raises."""
        try:
            from backend.services.cost_tracker import log_api_cost
            log_api_cost(
                provider='replicate',
                feature='story_illustration',
                cost_usd=0.003 * num_images if success else 0.0,
                user_id=user_id,
                units=num_images if success else 0,
                unit_kind='images',
                success=success,
                extra={
                    'model': 'flux-schnell',
                    'age': age,
                    **({'error': error} if error else {}),
                },
            )
        except Exception:
            logger.debug("cost_tracker logging failed", exc_info=True)

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

    def generate_custom_avatar(
        self,
        base_image_bytes: bytes,
        prompt: str,
        character_name: str = "the hero",
        age: int = 8,
        num_images: int = 1,
        **_,
    ) -> list:
        """
        Generate a Pixar-style cartoon avatar from a reference photo.

        Uses PhotoMaker-Style (tencentarc/photomaker-style) — purpose-built for
        photo → animated character style transfer. ~$0.015–0.035/image.
        No child-photo safety policy restrictions unlike Gemini.
        """
        self._ensure_api_key()

        photo_b64 = base64.b64encode(base_image_bytes).decode("utf-8")
        photo_data_url = f"data:image/jpeg;base64,{photo_b64}"

        # PhotoMaker-Style requires the trigger word "img" in the prompt
        # to anchor the face reference from the uploaded photo
        if "img" not in prompt:
            anchored_prompt = f"a storybook character img, {prompt.strip()}"
        else:
            anchored_prompt = prompt

        payload = {
            "version": "tencentarc/photomaker-style",
            "input": {
                "input_image": photo_data_url,
                "prompt": anchored_prompt,
                "negative_prompt": (
                    "nsfw, ugly, deformed, photorealistic, photograph, realistic, "
                    "blurry, low quality, watermark, text, logo"
                ),
                "style_name": "Pixar/Disney Character",
                "num_outputs": max(1, min(num_images, 4)),
                "style_strength_ratio": 35,
                "num_inference_steps": 50,
                "guidance_scale": 5,
            },
        }

        logger.info(f"Replicate PhotoMaker: generating avatar for {character_name}")

        # Use latest-version endpoint (no hash required)
        create_url = "https://api.replicate.com/v1/models/tencentarc/photomaker-style/predictions"
        headers = {
            "Authorization": f"Token {self.api_key}",
            "Content-Type": "application/json",
            "Prefer": "wait",
        }

        resp = requests.post(create_url, headers=headers, json={"input": payload["input"]}, timeout=70)
        resp.raise_for_status()
        prediction = resp.json()

        # Poll if not immediately completed
        if prediction.get("status") != "succeeded":
            pred_id = prediction.get("id")
            deadline = datetime.now().timestamp() + 90
            poll_headers = {"Authorization": f"Token {self.api_key}"}
            while datetime.now().timestamp() < deadline:
                import time
                time.sleep(3)
                poll_resp = requests.get(
                    f"https://api.replicate.com/v1/predictions/{pred_id}",
                    headers=poll_headers,
                    timeout=30,
                )
                poll_resp.raise_for_status()
                prediction = poll_resp.json()
                status = prediction.get("status")
                if status == "succeeded":
                    break
                if status in ("failed", "canceled"):
                    raise RuntimeError(f"Replicate prediction {status}: {prediction.get('error')}")
            else:
                raise TimeoutError(f"Replicate prediction {pred_id} timed out")

        output_urls = prediction.get("output") or []
        if not output_urls:
            raise RuntimeError("Replicate PhotoMaker returned no output images")

        results = []
        for i, image_url in enumerate(output_urls[:num_images]):
            try:
                if isinstance(image_url, str) and image_url.startswith("http"):
                    dl = requests.get(image_url, timeout=30)
                    dl.raise_for_status()
                    image_b64 = base64.b64encode(dl.content).decode("utf-8")
                elif isinstance(image_url, str):
                    image_b64 = image_url.split(",", 1)[-1] if "," in image_url else image_url
                else:
                    continue

                results.append({
                    "id": f"{uuid.uuid4()}_{i}",
                    "prompt": prompt,
                    "image_data": image_b64,
                    "format": "png",
                    "generated_at": datetime.now().isoformat(),
                    "provider": "replicate-photomaker-style",
                })
            except Exception as e:
                logger.error(f"Replicate: failed to process output image {i}: {e}")

        logger.info(f"Replicate PhotoMaker: generated {len(results)} avatar(s) for {character_name}")
        return results
