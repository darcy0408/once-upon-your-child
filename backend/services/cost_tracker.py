"""Per-call cost attribution.

Writes one ``api_cost_incurred`` row to the existing audit_log table per AI/TTS
call, recording provider, feature, dollar cost, and units (chars / tokens /
images). Aggregation queries (cost-per-user-per-month) read from event_data.

Migration path: when query volume justifies it, swap the inner write to a
dedicated ApiCostLog table — the public function signature stays stable so
call sites need not change.

Cost estimates use 2025-2026 published list prices (Verified):
  Gemini 2.5 Flash:        $0.075/1M input, $0.30/1M output tokens
  Gemini 2.5 Flash Image:  $0.04/image (1 generated image per call)
  Gemini 2.5 Flash Lite:   $0.0375/1M input, $0.15/1M output tokens
  Gemini 3.1 Flash TTS:    $0.054/1k characters (combined input + audio output)
  ElevenLabs Creator:      $0.18/1k characters
  Replicate SDXL-Lightning: $0.003/image
  OpenRouter (passthrough): provider rate × 1.05 markup
"""
from __future__ import annotations

import logging
from typing import Any

from backend.utils.audit import audit_log

logger = logging.getLogger(__name__)


# ---- Cost estimators (return USD as float) ----

def gemini_text_cost(input_tokens: int, output_tokens: int) -> float:
    """Cost of a Gemini 2.5 Flash text generation call."""
    return (input_tokens * 0.075 + output_tokens * 0.30) / 1_000_000


def gemini_text_lite_cost(input_tokens: int, output_tokens: int) -> float:
    """Cost of a Gemini 2.5 Flash Lite call (used for content moderation)."""
    return (input_tokens * 0.0375 + output_tokens * 0.15) / 1_000_000


def gemini_image_cost(num_images: int = 1) -> float:
    """Cost of a Gemini 2.5 Flash Image generation call."""
    return 0.04 * max(0, num_images)


def elevenlabs_tts_cost(characters: int) -> float:
    """Cost of an ElevenLabs Creator-tier TTS call."""
    return (characters / 1000) * 0.18


def gemini_tts_cost(characters: int) -> float:
    """Cost of a Gemini 3.1 Flash TTS call (input + audio output combined)."""
    return (characters / 1000) * 0.054


def replicate_image_cost(num_images: int = 1) -> float:
    """Cost of a Replicate SDXL-Lightning image generation call."""
    return 0.003 * max(0, num_images)


def openrouter_passthrough_cost(base_cost: float) -> float:
    """OpenRouter applies a 5% markup over the underlying provider cost."""
    return base_cost * 1.05


# ---- Public logging API ----

def log_api_cost(
    *,
    provider: str,
    feature: str,
    cost_usd: float,
    user_id: str | None = None,
    units: int | None = None,
    unit_kind: str | None = None,
    success: bool = True,
    extra: dict[str, Any] | None = None,
) -> None:
    """Record a single paid API call.

    Args:
        provider: 'gemini' | 'gemini_image' | 'elevenlabs' | 'replicate' | 'openrouter'
        feature:  'story_text' | 'story_illustration' | 'tts' | 'avatar' | etc.
        cost_usd: estimated USD cost of the call (use the helpers above)
        user_id:  may be None for anonymous / system calls (e.g. moderation pre-auth)
        units:    chars / tokens / images consumed
        unit_kind: 'chars' | 'tokens' | 'images'
        success:  False if the call errored (still costs ~0 but worth logging the attempt)
        extra:    any provider-specific context (model name, chunk index, retry attempt)

    Never raises — audit_log swallows failures.
    """
    payload: dict[str, Any] = {
        'provider': provider,
        'feature': feature,
        'cost_usd': round(cost_usd, 6),
        'success': success,
    }
    if units is not None:
        payload['units'] = units
    if unit_kind is not None:
        payload['unit_kind'] = unit_kind
    if extra:
        payload.update(extra)

    audit_log('api_cost_incurred', user_id=user_id, data=payload)
