"""
TTS Routes — ElevenLabs high-quality narration endpoints.

POST /tts/synthesize
  Body: { "text": str, "voice_id": str (optional) }
  Returns: { "audio_base64": str, "format": "mp3", "voice_id": str }
  Returns 503 if ELEVENLABS_API_KEY not set so Flutter can fall back to
  on-device flutter_tts gracefully.

GET /tts/voices
  Returns: { "voices": [...] }  — curated voice list for the picker UI.
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
    @limiter.limit("20 per hour", key_func=lambda: request.current_user.id if hasattr(request, 'current_user') and request.current_user else request.remote_addr)
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

        data = request.get_json(force=True, silent=True) or {}
        text = (data.get("text") or "").strip()
        if not text:
            return jsonify({"error": "text is required"}), 400

        _, default_voice_id = _get_voice_list()
        voice_id = (data.get("voice_id") or "").strip() or default_voice_id

        # Truncate to 5 000 chars (~1 000 words) to keep latency and cost sane
        if len(text) > 5000:
            logger.info("TTS text truncated from %d to 5000 chars", len(text))
            text = text[:5000]

        try:
            audio_bytes = service.generate_speech(text=text, voice_id=voice_id)
        except Exception as e:
            logger.error("ElevenLabs TTS synthesis error: %s", e)
            return jsonify({"error": "Synthesis failed", "message": str(e)}), 500

        if not audio_bytes:
            return jsonify({"error": "Empty audio returned"}), 500

        return jsonify({
            "audio_base64": base64.b64encode(audio_bytes).decode("utf-8"),
            "format": "mp3",
            "voice_id": voice_id,
        })

    return tts_bp
