"""
TTS Routes — tiered narration fallback chain.

Default provider order on /tts/synthesize (cost-optimized — see F-01 in
audit-reports/10-finops):
  1. Gemini Flash TTS (~$0.054/1k chars) — the default paid voice
  2. Edge TTS (free) — final online fallback before on-device TTS

ElevenLabs (~$0.18/1k chars, ~3.3x Gemini) is an OPT-IN premium voice: used
only when the request sets "premium_voice": true, or requests dialogue-
differentiated narration via "character_voice_id" (a multi-voice feature only
ElevenLabs supports). When opted in it serves first, then falls through to
Gemini then Edge if unavailable or over its monthly character budget.
The 'provider' field in the response indicates which tier served the request.

POST /tts/synthesize
  Body: { "text": str, "voice_id": str (optional) }
  Returns: { "audio_base64": str, "format": "mp3", "voice_id": str, "provider": str }
  Returns 503 only if all three providers fail — clients then fall back to
  on-device flutter_tts.

GET /tts/voices
  Returns: { "voices": [...] }  — curated voice list for the picker UI.

POST /tts/transcribe
  Body: multipart form-data with "audio" file (webm/mp4/wav/mp3)
  Returns: { "text": str }
  Used for Speech-to-Text via ElevenLabs.
"""

import base64
import logging

from flask import Blueprint, jsonify, request

logger = logging.getLogger(__name__)

# Lazy-initialise so the app still starts without an API key configured
_tts_service = None


def _get_tts_service():
    global _tts_service
    if _tts_service is not None:
        return _tts_service

    try:
        from backend.elevenlabs_tts_service import ElevenLabsTTSService
    except ImportError:
        try:
            from elevenlabs_tts_service import ElevenLabsTTSService
        except ImportError:
            logger.warning("elevenlabs_tts_service module not found")
            return None

    try:
        _tts_service = ElevenLabsTTSService()
        logger.info("ElevenLabs TTS initialised successfully")
        return _tts_service
    except (ImportError, ValueError) as e:
        logger.warning("ElevenLabs TTS unavailable: %s", e)
        return None
    except Exception as e:
        logger.warning("ElevenLabs TTS init error: %s", e)
        return None


def _get_voice_list():
    """Return curated voices even when the service is not initialised."""
    try:
        from backend.elevenlabs_tts_service import CURATED_VOICES, DEFAULT_VOICE_ID
    except ImportError:
        try:
            from elevenlabs_tts_service import CURATED_VOICES, DEFAULT_VOICE_ID
        except ImportError:
            return [], "21m00Tcm4TlvDq8ikWAM"
    return CURATED_VOICES, DEFAULT_VOICE_ID


# Gemini Flash TTS — overflow tier between ElevenLabs and Edge. Costs ~$0.054/1k
# chars vs ElevenLabs' $0.18/1k, used when ElevenLabs is unavailable or over
# budget so paying users keep a high-quality voice instead of dropping to Edge.
_gemini_service = None


def _get_gemini_service():
    """Lazy-init the Gemini Flash TTS service."""
    global _gemini_service
    if _gemini_service is not None:
        return _gemini_service

    try:
        from backend.gemini_tts_service import GeminiTTSService
    except ImportError:
        try:
            from gemini_tts_service import GeminiTTSService
        except ImportError:
            logger.warning("gemini_tts_service module not found")
            return None

    try:
        _gemini_service = GeminiTTSService()
        logger.info("Gemini Flash TTS initialised successfully")
        return _gemini_service
    except (ImportError, ValueError) as e:
        logger.warning("Gemini Flash TTS unavailable: %s", e)
        return None
    except Exception as e:
        logger.warning("Gemini Flash TTS init error: %s", e)
        return None


def _gemini_synthesize(text, voice_id, speed):
    """
    Synthesize narration via Gemini Flash TTS.
    Returns (audio_bytes, word_timestamps) or None if unavailable.
    Word timestamps are always [] — Gemini TTS does not provide alignment.
    """
    service = _get_gemini_service()
    if service is None:
        return None
    try:
        return service.generate_speech_with_timestamps(
            text=text, voice_id=voice_id, speed=speed
        )
    except Exception as e:
        logger.error("Gemini Flash TTS failed: %s", e)
        return None


# Free Edge TTS fallback — used when ElevenLabs is unconfigured or out of budget.
_edge_service = None


def _get_edge_service():
    """Lazy-init the free Microsoft Edge TTS fallback service."""
    global _edge_service
    if _edge_service is not None:
        return _edge_service

    try:
        from backend.edge_tts_service import EdgeTTSService
    except ImportError:
        try:
            from edge_tts_service import EdgeTTSService
        except ImportError:
            logger.warning("edge_tts_service module not found")
            return None

    if not EdgeTTSService.available():
        logger.warning("edge-tts package not installed — no free TTS fallback")
        return None
    _edge_service = EdgeTTSService()
    logger.info("Edge TTS fallback initialised")
    return _edge_service


def _edge_synthesize(text, voice_id, speed):
    """
    Synthesize narration via the free Edge TTS fallback.
    Returns (audio_bytes, word_timestamps) or None if unavailable.
    """
    service = _get_edge_service()
    if service is None:
        return None
    try:
        return service.generate_speech_with_timestamps(
            text=text, voice_id=voice_id, speed=speed
        )
    except Exception as e:
        logger.error("Edge TTS fallback failed: %s", e)
        return None


def create_tts_blueprint(limiter, require_auth):
    tts_bp = Blueprint("tts", __name__)

    @tts_bp.route("/tts/voices", methods=["GET"])
    def voices():
        """Return the curated ElevenLabs voice list for the Flutter voice picker."""
        voice_list, default_id = _get_voice_list()
        return jsonify({"voices": voice_list, "default_voice_id": default_id})

    @tts_bp.route("/tts/synthesize", methods=["POST"])
    @require_auth
    @limiter.limit(
        "500 per hour",
        key_func=lambda: (
            request.current_user.id
            if hasattr(request, "current_user") and request.current_user
            else request.remote_addr
        ),
    )
    def synthesize():
        """
        Generate MP3 narration for a story text.
        Default voice is Gemini Flash TTS; ElevenLabs is an opt-in premium
        voice (premium_voice=true, or character_voice_id for dialogue).
        Returns base64-encoded MP3 audio, or 503 if every provider is
        unavailable so the client falls back to on-device TTS.
        """
        import os

        if os.environ.get("TTS_DISABLED", "").lower() in ("1", "true", "yes"):
            return (
                jsonify(
                    {
                        "error": "TTS service unavailable",
                        "message": "TTS is temporarily disabled.",
                    }
                ),
                503,
            )

        # ElevenLabs is now an OPT-IN premium voice rather than the paid
        # default (F-01: it costs ~3.3x Gemini Flash TTS). It is initialised
        # and attempted only when the client explicitly opts in below; the
        # default paid path is Gemini Flash TTS, then the free Edge tier.
        service = None
        elevenlabs_ok = False

        # Per-user daily TTS quota check (applies to all providers)
        try:
            from backend.utils.ai_quota import (
                check_tts_chars_quota,
                check_tts_quota,
                increment_tts_chars,
                increment_tts_quota,
            )
            from backend.utils.audit import audit_log
        except ImportError:
            from utils.ai_quota import (
                check_tts_chars_quota,
                check_tts_quota,
                increment_tts_chars,
                increment_tts_quota,
            )
            from utils.audit import audit_log

        user_id = (
            request.current_user.id
            if hasattr(request, "current_user") and request.current_user
            else None
        )
        user_tier = getattr(request.current_user, "subscription_tier", "free") or "free"
        if user_id:
            allowed, tts_count, tts_limit = check_tts_quota(user_id, user_tier)
            if not allowed:
                audit_log(
                    "tts_quota_exceeded",
                    user_id=user_id,
                    data={"tier": user_tier, "count": tts_count, "limit": tts_limit},
                )
                return (
                    jsonify(
                        {
                            "error": "Daily narration limit reached",
                            "code": "TTS_QUOTA_EXCEEDED",
                            "daily_limit": tts_limit,
                            "syntheses_used": tts_count,
                        }
                    ),
                    429,
                )

        data = request.get_json(force=True, silent=True) or {}
        text = (data.get("text") or "").strip()
        if not text:
            return jsonify({"error": "text is required"}), 400

        # Opt-in gate for the premium ElevenLabs voice. Dialogue-differentiated
        # narration (character_voice_id) also requires ElevenLabs, since it is
        # the only provider that supports multi-voice synthesis. Without an
        # explicit opt-in the request is served by the default Gemini -> Edge
        # chain below.
        premium_voice = bool(data.get("premium_voice"))
        wants_dialogue = bool((data.get("character_voice_id") or "").strip())
        if premium_voice or wants_dialogue:
            service = _get_tts_service()
            elevenlabs_ok = service is not None

        # Monthly ElevenLabs character-budget check (per-user + global). When
        # the premium budget is depleted we don't fail the request — we fall
        # through to the free Edge TTS voice so narration still sounds natural.
        if user_id and elevenlabs_ok:
            chars_req = len(text)
            ok, cap_reason, used, limit = check_tts_chars_quota(
                user_id, user_tier, chars_req
            )
            if not ok:
                audit_log(
                    "tts_chars_cap_exceeded",
                    user_id=user_id,
                    data={
                        "tier": user_tier,
                        "reason": cap_reason,
                        "used": used,
                        "limit": limit,
                        "requested": chars_req,
                    },
                )
                elevenlabs_ok = False

        # Strip markdown/formatting before sending so we don't waste
        # the per-chunk budget on asterisks and pound signs.
        try:
            from backend.elevenlabs_tts_service import clean_text_for_tts
        except ImportError:
            try:
                from elevenlabs_tts_service import clean_text_for_tts
            except ImportError:
                clean_text_for_tts = lambda t: t  # noqa: E731
        text = clean_text_for_tts(text)

        _, default_voice_id = _get_voice_list()
        voice_id = (data.get("voice_id") or "").strip() or default_voice_id
        character_voice_id = (data.get("character_voice_id") or "").strip() or None
        try:
            speed = float(data.get("speed") or 1.0)
            speed = max(0.7, min(1.2, speed))  # clamp to safe range
        except (ValueError, TypeError):
            speed = 1.0

        audio_bytes = None
        word_timestamps = []
        provider = None

        if elevenlabs_ok:
            try:
                if character_voice_id:
                    # Dialogue-differentiated synthesis: narrator + character voices.
                    # Timestamps not supported across multi-voice segments.
                    logger.info(
                        "Dialogue synthesis (%d chars) — narrator=%s character=%s",
                        len(text),
                        voice_id,
                        character_voice_id,
                    )
                    audio_bytes = service.generate_speech_with_dialogue(
                        text=text,
                        narrator_voice_id=voice_id,
                        character_voice_id=character_voice_id,
                    )
                elif len(text) > 5000:
                    # Long story — chunked synthesis to avoid ElevenLabs truncation.
                    # Timestamps not supported for chunked mode.
                    logger.info(
                        "Long story (%d chars) — using chunked synthesis", len(text)
                    )
                    audio_bytes = service.generate_speech_chunked(
                        text=text, voice_id=voice_id
                    )
                else:
                    # Short story — use with-timestamps endpoint for accurate word highlighting.
                    audio_bytes, word_timestamps = (
                        service.generate_speech_with_timestamps(
                            text=text, voice_id=voice_id, speed=speed
                        )
                    )
                provider = "elevenlabs"
            except Exception as e:
                # Any ElevenLabs failure (exhausted credits, network, API
                # error) falls through to the free Edge TTS voice rather than
                # failing the request.
                logger.error(
                    "ElevenLabs TTS synthesis error — using Edge fallback: %s", e
                )
                elevenlabs_ok = False
                audio_bytes = None

        # Gemini Flash TTS — the DEFAULT paid voice (F-01). Also serves as the
        # fallback when an opted-in ElevenLabs request is unconfigured, over its
        # monthly budget, or returned no audio. ~30% of the ElevenLabs per-char
        # cost; Edge stays below as the final free fallback.
        if not audio_bytes:
            gemini_result = _gemini_synthesize(text, voice_id, speed)
            if gemini_result is not None and gemini_result[0]:
                audio_bytes, word_timestamps = gemini_result
                provider = "gemini"

        # Free Edge TTS fallback — used when both ElevenLabs and Gemini are
        # unavailable, e.g. no GEMINI_API_KEY configured, or Gemini errored.
        if not audio_bytes:
            edge_result = _edge_synthesize(text, voice_id, speed)
            if edge_result is None or not edge_result[0]:
                # No TTS available — client falls back to its on-device voice.
                return (
                    jsonify(
                        {
                            "error": "TTS service unavailable",
                            "message": "Narration is unavailable right now.",
                        }
                    ),
                    503,
                )
            audio_bytes, word_timestamps = edge_result
            provider = "edge"

        if user_id:
            increment_tts_quota(user_id, user_tier)
            # Character budget and cost tracking apply only to paid ElevenLabs use.
            if provider == "elevenlabs":
                increment_tts_chars(user_id, user_tier, len(text))
                try:
                    from backend.services.cost_tracker import (
                        elevenlabs_tts_cost,
                        log_api_cost,
                    )

                    log_api_cost(
                        provider="elevenlabs",
                        feature="tts",
                        cost_usd=elevenlabs_tts_cost(len(text)),
                        user_id=user_id,
                        units=len(text),
                        unit_kind="chars",
                        success=True,
                        extra={"voice_id": voice_id, "tier": user_tier},
                    )
                except Exception:
                    logger.debug("cost_tracker logging failed", exc_info=True)
            elif provider == "gemini":
                # Don't increment the ElevenLabs char budget — Gemini is the
                # overflow tier that exists *because* that budget is exhausted.
                try:
                    from backend.services.cost_tracker import (
                        gemini_tts_cost,
                        log_api_cost,
                    )

                    log_api_cost(
                        provider="gemini",
                        feature="tts",
                        cost_usd=gemini_tts_cost(len(text)),
                        user_id=user_id,
                        units=len(text),
                        unit_kind="chars",
                        success=True,
                        extra={
                            "voice_id": voice_id,
                            "tier": user_tier,
                            "model": "gemini-3.1-flash-tts-preview",
                        },
                    )
                except Exception:
                    logger.debug("cost_tracker logging failed", exc_info=True)

        return jsonify(
            {
                "audio_base64": base64.b64encode(audio_bytes).decode("utf-8"),
                "format": "mp3",
                "voice_id": voice_id,
                "provider": provider,  # 'gemini' (default), 'elevenlabs' (opt-in), or 'edge'
                "word_timestamps": word_timestamps,  # [] when not available (dialogue/chunked)
            }
        )

    @tts_bp.route("/tts/transcribe", methods=["POST"])
    @require_auth
    @limiter.limit("30 per hour", key_func=lambda: request.remote_addr)
    def transcribe():
        """
        Transcribe audio to text using ElevenLabs Speech-to-Text.
        Accepts multipart form-data with an "audio" file field.
        Returns { "text": str } or 503 if STT is unavailable.
        """
        import os

        api_key = os.environ.get("ELEVENLABS_API_KEY")
        if not api_key:
            return (
                jsonify(
                    {
                        "error": "STT service unavailable",
                        "message": "ELEVENLABS_API_KEY not configured",
                    }
                ),
                503,
            )

        if "audio" not in request.files:
            return jsonify({"error": "audio file required"}), 400

        audio_file = request.files["audio"]
        audio_bytes = audio_file.read()
        if not audio_bytes:
            return jsonify({"error": "Empty audio file"}), 400

        try:
            from elevenlabs.client import ElevenLabs

            client = ElevenLabs(api_key=api_key)
            result = client.speech_to_text.convert(
                audio=audio_bytes,
                model_id="scribe_v1",
            )
            text = result.text if hasattr(result, "text") else str(result)
            return jsonify({"text": text.strip()})
        except Exception as e:
            logger.error("ElevenLabs STT error: %s", e)
            return (
                jsonify(
                    {
                        "error": "STT_FAILED",
                        "message": "Voice transcription is unavailable right now. Please try again in a moment.",
                    }
                ),
                500,
            )

    return tts_bp
