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

OpenAI / Azure list prices (verified 2026-08-24 against the official pricing
pages; MT-402):
  gpt-5-mini:              $0.25/1M input, $2.00/1M output tokens
  gpt-4o-mini:             $0.15/1M input, $0.60/1M output tokens
  gpt-image-2:             $5/1M text-in, $8/1M image-in, $30/1M image-out tokens
  gpt-4o-mini-transcribe:  $0.003/minute ($0.006 for gpt-4o-transcribe)
  Azure standard neural TTS: $16/1M characters (500K/month free grant, so
                           early real bills run below this estimate)
"""

from __future__ import annotations

import logging
import os
from datetime import datetime, timedelta, timezone
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


# USD per 1M tokens (input, output). Unknown models fall back to gpt-5-mini —
# the workhorse text model — rather than silently costing $0.
_OPENAI_TEXT_RATES = {
    "gpt-5-mini": (0.25, 2.00),
    "gpt-4o-mini": (0.15, 0.60),
}
_OPENAI_TEXT_DEFAULT_MODEL = "gpt-5-mini"

# Fallback when a gpt-image response carries no usage block: a 1024x1024 call
# lands around ~1k output tokens (~$0.03); round up rather than under-count.
OPENAI_IMAGE_FLAT_ESTIMATE_USD = 0.04


def openai_text_cost(
    input_tokens: int,
    output_tokens: int,
    model: str = _OPENAI_TEXT_DEFAULT_MODEL,
) -> float:
    """Cost of an OpenAI chat-completions call (story text, moderation, vision)."""
    rate_in, rate_out = _OPENAI_TEXT_RATES.get(
        model, _OPENAI_TEXT_RATES[_OPENAI_TEXT_DEFAULT_MODEL]
    )
    return (
        max(0, input_tokens) * rate_in + max(0, output_tokens) * rate_out
    ) / 1_000_000


def openai_image_cost(
    text_input_tokens: int = 0,
    image_input_tokens: int = 0,
    output_tokens: int = 0,
) -> float:
    """Cost of a gpt-image-2 generate/edit call from its usage block."""
    return (
        max(0, text_input_tokens) * 5.00
        + max(0, image_input_tokens) * 8.00
        + max(0, output_tokens) * 30.00
    ) / 1_000_000


def openai_transcription_cost(
    seconds: float, model: str = "gpt-4o-mini-transcribe"
) -> float:
    """Cost of an OpenAI speech-to-text call (billed per audio minute)."""
    per_minute = {
        "gpt-4o-mini-transcribe": 0.003,
        "gpt-4o-transcribe": 0.006,
    }.get(model, 0.006)
    return max(0.0, seconds) / 60.0 * per_minute


def azure_tts_cost(characters: int) -> float:
    """Cost of an Azure AI Speech standard-neural TTS call."""
    return (max(0, characters) / 1000) * 0.016


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
        "provider": provider,
        "feature": feature,
        "cost_usd": round(cost_usd, 6),
        "success": success,
    }
    if units is not None:
        payload["units"] = units
    if unit_kind is not None:
        payload["unit_kind"] = unit_kind
    if extra:
        payload.update(extra)

    audit_log("api_cost_incurred", user_id=user_id, data=payload)

    try:
        _check_budget()
    except Exception:
        # Monitoring must never break the request that paid for the call.
        logger.warning("cost_tracker: budget check failed", exc_info=True)


# ---- Budget monitoring (MT-402) ----
#
# Alert-only by design: hard per-user and global generation CAPS already live
# in backend/utils/ai_quota.py; this layer answers "how many dollars today?"
# and shouts when the answer crosses a line. Alerts fire at most once per
# period, deduped through a budget_alert_sent audit row so the multi-process
# web workers and Celery all see the same state. (Two processes crossing the
# line in the same instant can each send one alert — acceptable for an alarm.)


def _budget_limits() -> tuple[float, float]:
    """(daily, weekly) alert thresholds in USD. Env-overridable."""

    def _read(name: str, default: float) -> float:
        raw = os.getenv(name)
        if not raw:
            return default
        try:
            return float(raw)
        except ValueError:
            return default

    return _read("AI_BUDGET_DAILY_USD", 10.0), _read("AI_BUDGET_WEEKLY_USD", 50.0)


def _period_starts(now: datetime) -> tuple[datetime, datetime]:
    """(start of UTC day, start of UTC ISO week) containing ``now``."""
    day_start = now.replace(hour=0, minute=0, second=0, microsecond=0)
    week_start = day_start - timedelta(days=now.weekday())
    return day_start, week_start


def _spend_since(cutoff: datetime) -> float:
    """SUM of api_cost_incurred cost_usd at/after ``cutoff`` (UTC)."""
    from sqlalchemy import func

    from backend.database import db
    from backend.models.audit_log import AuditLog

    total = (
        db.session.query(func.sum(AuditLog.event_data["cost_usd"].as_float()))
        .filter(
            AuditLog.event_type == "api_cost_incurred",
            AuditLog.created_at >= cutoff,
        )
        .scalar()
    )
    return float(total or 0.0)


def _check_budget() -> None:
    now = datetime.now(timezone.utc)
    day_start, week_start = _period_starts(now)
    daily_limit, weekly_limit = _budget_limits()

    daily = _spend_since(day_start)
    if daily > daily_limit:
        _alert_once("daily", daily, daily_limit, day_start)

    weekly = _spend_since(week_start)
    if weekly > weekly_limit:
        _alert_once("weekly", weekly, weekly_limit, week_start)


def _alert_once(
    period: str, actual: float, limit: float, period_start: datetime
) -> None:
    from backend.database import db
    from backend.models.audit_log import AuditLog

    already_sent = (
        db.session.query(AuditLog.id)
        .filter(
            AuditLog.event_type == "budget_alert_sent",
            AuditLog.created_at >= period_start,
            AuditLog.event_data["period"].as_string() == period,
        )
        .first()
    )
    if already_sent:
        return

    message = (
        f"AI budget alert: {period} spend ${actual:.2f} has passed the "
        f"${limit:.2f} limit"
    )
    logger.warning(message)
    _post_slack_alert(message)
    audit_log(
        "budget_alert_sent",
        data={"period": period, "actual_usd": round(actual, 2), "limit_usd": limit},
    )


def _post_slack_alert(message: str) -> None:
    webhook = os.getenv("SLACK_WEBHOOK_URL")
    if not webhook:
        return
    try:
        import requests

        requests.post(webhook, json={"text": message}, timeout=5)
    except Exception as exc:
        logger.warning("cost_tracker: Slack alert failed (%s)", exc)


# ---- Reporting (the /admin/cost-report endpoint) ----


def get_cost_report(days: int = 7) -> dict[str, Any]:
    """Aggregate api_cost_incurred rows for the admin cost report.

    Replaces the retired in-memory ``backend/cost_tracking.py`` report, which
    only ever saw one process's events — and, since nothing called its
    ``track_cost``, reported $0 forever (MT-402).
    """
    from backend.database import db
    from backend.models.audit_log import AuditLog

    days = min(max(int(days), 1), 90)
    now = datetime.now(timezone.utc)
    rows = (
        db.session.query(AuditLog.event_data, AuditLog.created_at)
        .filter(
            AuditLog.event_type == "api_cost_incurred",
            AuditLog.created_at >= now - timedelta(days=days),
        )
        .all()
    )

    def _round_map(mapping: dict[str, float]) -> dict[str, float]:
        return {key: round(value, 6) for key, value in mapping.items()}

    total = 0.0
    daily: dict[str, float] = {}
    features: dict[str, dict[str, Any]] = {}
    providers: dict[str, float] = {}
    models: dict[str, float] = {}
    for event_data, created_at in rows:
        data = event_data or {}
        try:
            cost = float(data.get("cost_usd") or 0.0)
        except (TypeError, ValueError):
            cost = 0.0
        total += cost
        day = created_at.date().isoformat()
        daily[day] = daily.get(day, 0.0) + cost
        feature = str(data.get("feature") or "unknown")
        bucket = features.setdefault(feature, {"cost_usd": 0.0, "calls": 0})
        bucket["cost_usd"] += cost
        bucket["calls"] += 1
        provider = str(data.get("provider") or "unknown")
        providers[provider] = providers.get(provider, 0.0) + cost
        model = str(data.get("model") or "unknown")
        models[model] = models.get(model, 0.0) + cost

    day_start, week_start = _period_starts(now)
    daily_limit, weekly_limit = _budget_limits()
    return {
        "period_days": days,
        "total_cost_usd": round(total, 6),
        "total_calls": len(rows),
        "daily_breakdown": _round_map(daily),
        "feature_breakdown": {
            key: {"cost_usd": round(value["cost_usd"], 6), "calls": value["calls"]}
            for key, value in features.items()
        },
        "provider_breakdown": _round_map(providers),
        "model_breakdown": _round_map(models),
        "budget": {
            "daily_limit_usd": daily_limit,
            "weekly_limit_usd": weekly_limit,
            "today_usd": round(_spend_since(day_start), 6),
            "this_week_usd": round(_spend_since(week_start), 6),
        },
        "generated_at": now.isoformat(),
    }
