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
            return jsonify({"error": "Transcription failed", "message": str(e)}), 500

    return tts_bp
