"""
TTS Routes — ElevenLabs high-quality narration endpoints.

POST /tts/synthesize
  Body: { "text": str, "voice_id": str (optional) }
  Returns: { "audio_base64": str, "format": "mp3", "voice_id": str }
  Returns 503 if ELEVENLABS_API_KEY not set so Flutter can fall back to
  on-device flutter_tts gracefully.

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

    import os
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


def create_tts_blueprint(limiter, require_auth):
    tts_bp = Blueprint("tts", __name__)

    @tts_bp.route("/tts/voices", methods=["GET"])
    def voices():
        """Return the curated ElevenLabs voice list for the Flutter voice picker."""
        voice_list, default_id = _get_voice_list()
        return jsonify({"voices": voice_list, "default_voice_id": default_id})

    @tts_bp.route("/tts/synthesize", methods=["POST"])
    @require_auth
    @limiter.limit("500 per hour", key_func=lambda: request.current_user.id if hasattr(request, 'current_user') and request.current_user else request.remote_addr)
    def synthesize():
        """
        Generate ElevenLabs MP3 narration for a story text.
        Returns base64-encoded MP3 audio.
        Returns 503 if ELEVENLABS_API_KEY is missing so the client falls back
        to on-device TTS.
        """
        service = _get_tts_service()
        if service is None:
            return jsonify({
                "error": "TTS service unavailable",
                "message": "ElevenLabs API key not configured. "
                           "Set ELEVENLABS_API_KEY in backend/.env.",
            }), 503

        # Per-user daily TTS quota check
        try:
            from backend.utils.ai_quota import check_tts_quota, increment_tts_quota
            from backend.utils.audit import audit_log
        except ImportError:
            from utils.ai_quota import check_tts_quota, increment_tts_quota
            from utils.audit import audit_log

        user_id = request.current_user.id if hasattr(request, 'current_user') and request.current_user else None
        user_tier = getattr(request.current_user, 'subscription_tier', 'free') or 'free'
        if user_id:
            allowed, tts_count, tts_limit = check_tts_quota(user_id, user_tier)
            if not allowed:
                audit_log('tts_quota_exceeded', user_id=user_id, data={'tier': user_tier, 'count': tts_count, 'limit': tts_limit})
                return jsonify({
                    "error": "Daily narration limit reached",
                    "code": "TTS_QUOTA_EXCEEDED",
                    "daily_limit": tts_limit,
                    "syntheses_used": tts_count,
                }), 429

        data = request.get_json(force=True, silent=True) or {}
        text = (data.get("text") or "").strip()
        if not text:
            return jsonify({"error": "text is required"}), 400

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

        word_timestamps = []
        try:
            if character_voice_id:
                # Dialogue-differentiated synthesis: narrator + character voices.
                # Timestamps not supported across multi-voice segments.
                logger.info(
                    "Dialogue synthesis (%d chars) — narrator=%s character=%s",
                    len(text), voice_id, character_voice_id,
                )
                audio_bytes = service.generate_speech_with_dialogue(
                    text=text,
                    narrator_voice_id=voice_id,
                    character_voice_id=character_voice_id,
                )
            elif len(text) > 5000:
                # Long story — chunked synthesis to avoid ElevenLabs truncation.
                # Timestamps not supported for chunked mode.
                logger.info("Long story (%d chars) — using chunked synthesis", len(text))
                audio_bytes = service.generate_speech_chunked(text=text, voice_id=voice_id)
            else:
                # Short story — use with-timestamps endpoint for accurate word highlighting.
                audio_bytes, word_timestamps = service.generate_speech_with_timestamps(
                    text=text, voice_id=voice_id, speed=speed
                )
        except Exception as e:
            logger.error("ElevenLabs TTS synthesis error: %s", e)
            if "quota_exceeded" in str(e):
                return jsonify({
                    "error": "TTS_QUOTA_EXCEEDED",
                    "message": "ElevenLabs quota exhausted.",
                }), 503
            return jsonify({"error": "TTS_FAILED", "message": "Narration is unavailable right now. Please try again in a moment."}), 500

        if not audio_bytes:
            return jsonify({"error": "Empty audio returned"}), 500

        if user_id:
            increment_tts_quota(user_id, user_tier)

        return jsonify({
            "audio_base64": base64.b64encode(audio_bytes).decode("utf-8"),
            "format": "mp3",
            "voice_id": voice_id,
            "word_timestamps": word_timestamps,  # [] when not available (dialogue/chunked)
        })

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
            return jsonify({"error": "STT service unavailable", "message": "ELEVENLABS_API_KEY not configured"}), 503

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
            return jsonify({"error": "STT_FAILED", "message": "Voice transcription is unavailable right now. Please try again in a moment."}), 500

    return tts_bp
