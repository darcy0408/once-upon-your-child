"""Cloudflare Workers AI Image Generation Service

Runs the *same* Flux Schnell model as the Replicate path
(``@cf/black-forest-labs/flux-1-schnell``) but through Cloudflare Workers AI,
which has a free daily Neuron allocation that covers the app's entire current
illustration volume at $0. Replicate Flux Schnell remains the fallback so a
Cloudflare outage or quota exhaustion doesn't regress illustrations.

See MT-131 / docs/IMAGE_GEN_AB_TEST_RESULTS.md.
"""

import logging
import os
import time
import uuid
from datetime import datetime

import requests

logger = logging.getLogger(__name__)

# Workers AI text-to-image model id — identical model to the Replicate path.
CLOUDFLARE_FLUX_MODEL = "@cf/black-forest-labs/flux-1-schnell"


class CloudflareImageGenerator:
    """Per-page story illustrations via Cloudflare Workers AI Flux Schnell."""

    def __init__(self, account_id=None, api_token=None):
        self.account_id = account_id or os.getenv("CLOUDFLARE_ACCOUNT_ID")
        self.api_token = api_token or os.getenv("CLOUDFLARE_API_TOKEN")
        self.mock_mode = os.getenv("MOCK_TESTING_MODE", "false").lower() == "true"

    def generate_story_illustration_flux(
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
        """Per-page story illustration via Cloudflare Workers AI Flux Schnell.

        Free at current scale (10,000 Neurons/day). Returns the same
        ``{id, prompt, image_data, format, generated_at}`` dict shape as
        ``ReplicateImageGenerator.generate_story_illustration_flux_schnell`` so
        callers can swap providers without touching response handling. Returns
        ``[]`` on any error so the caller's fallback chain takes over.
        """
        if self.mock_mode:
            logger.info("MOCK_TESTING_MODE enabled - skipping Cloudflare Flux")
            return []
        if not self.account_id or not self.api_token:
            logger.warning(
                "CLOUDFLARE_ACCOUNT_ID / CLOUDFLARE_API_TOKEN not set; "
                "Cloudflare Flux skipped"
            )
            return []

        # Reuse the Replicate prompt builder for prompt parity — it already
        # carries the age <= 5 warm-style modifier and the power-id visual
        # override, so both Flux providers render from an identical prompt.
        try:
            from .replicate_image_generator import ReplicateImageGenerator
        except ImportError:
            from replicate_image_generator import ReplicateImageGenerator
        prompt = ReplicateImageGenerator()._build_prompt(
            scene_description, character_name, style, age,
            therapeutic_focus, character_appearance, companions,
            power_id=power_id,
        )

        url = (
            f"https://api.cloudflare.com/client/v4/accounts/"
            f"{self.account_id}/ai/run/{CLOUDFLARE_FLUX_MODEL}"
        )
        t0 = time.time()
        images: list = []
        try:
            # flux-1-schnell has no num_outputs param — one request per image.
            # steps 1-8; 4 is the speed/quality sweet spot for this model.
            for i in range(max(1, min(num_images, 4))):
                resp = requests.post(
                    url,
                    headers={
                        "Authorization": f"Bearer {self.api_token}",
                        "Content-Type": "application/json",
                    },
                    json={"prompt": prompt, "steps": 4},
                    timeout=60,
                )
                if resp.status_code != 200:
                    logger.warning(
                        "Cloudflare Flux HTTP %d: %s",
                        resp.status_code, resp.text[:200],
                    )
                    break
                body = resp.json()
                if not body.get("success"):
                    logger.warning("Cloudflare Flux error: %s", body.get("errors"))
                    break
                # flux-1-schnell returns a base64-encoded JPEG in result.image.
                b64 = (body.get("result") or {}).get("image")
                if not b64:
                    logger.warning("Cloudflare Flux returned no image data")
                    break
                images.append({
                    "id": f"{uuid.uuid4()}_{i}",
                    "prompt": prompt,
                    "image_data": b64,
                    "format": "jpeg",
                    "generated_at": datetime.now().isoformat(),
                    "provider": "cloudflare-flux-schnell",
                })

            self._log_cost_event(len(images) > 0, len(images), user_id, age)
            if images:
                logger.info(
                    "Cloudflare Flux %d image(s) in %.1fs",
                    len(images), time.time() - t0,
                )
            return images

        except Exception as e:
            logger.exception("Cloudflare Flux error: %s", e)
            self._log_cost_event(
                False, num_images, user_id, age, error=str(e)[:120]
            )
            return images

    def _log_cost_event(
        self,
        success: bool,
        num_images: int,
        user_id: str | None,
        age: int,
        error: str | None = None,
    ) -> None:
        """Forward a Cloudflare Flux call to cost_tracker at $0. Never raises.

        Cloudflare Workers AI bills in Neurons against a free daily allocation
        that covers current scale entirely, so ``cost_usd`` is logged as 0.0.
        """
        try:
            from backend.services.cost_tracker import log_api_cost
            log_api_cost(
                provider='cloudflare',
                feature='story_illustration',
                cost_usd=0.0,
                user_id=user_id,
                units=num_images if success else 0,
                unit_kind='images',
                success=success,
                extra={
                    'model': 'flux-1-schnell',
                    'age': age,
                    **({'error': error} if error else {}),
                },
            )
        except Exception:
            logger.debug("cost_tracker logging failed", exc_info=True)
