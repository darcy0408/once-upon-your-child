"""
TTS Routes — Google Cloud Neural2 narration endpoint.

POST /tts/synthesize
  Body: { "text": str, "voice_id": str (optional), "speaking_rate": float (optional) }
  Returns: { "audio_base64": str, "format": "mp3", "voice_id": str }
  Falls back to 503 if Google credentials not configured so Flutter can
  fall back to on-device flutter_tts gracefully.
"""

import base64
import logging
from flask import Blueprint, jsonify, request

logger = logging.getLogger(__name__)

tts_bp = Blueprint("tts", __name__)

# Lazy-initialise so the app still starts without Google credentials
_tts_service = None


def _get_tts_service():
    global _tts_service
    if _tts_service is not None:
        return _tts_service

    try:
        from backend.tts_service import TTSService
    except ImportError:
        try:
            from tts_service import TTSService  # running from backend/ dir
        except ImportError:
            logger.warning("tts_service module not found")
            return None

    try:
        _tts_service = TTSService()
        logger.info("Google Cloud TTS initialised")
        return _tts_service
    except ImportError as e:
        logger.warning("google-cloud-texttospeech not installed: %s", e)
        return None
    except Exception as e:
        logger.warning("Google TTS unavailable (credentials?): %s", e)
        return None


@tts_bp.route("/tts/synthesize", methods=["POST"])
def synthesize():
    """
    Generate Neural2 MP3 narration for a story text.
    Returns base64-encoded MP3 audio.
    Returns 503 if credentials are missing so the client falls back to
    on-device TTS.
    """
    service = _get_tts_service()
    if service is None:
        return jsonify({
            "error": "TTS service unavailable",
            "message": "Google Cloud credentials not configured. "
                       "Set GOOGLE_APPLICATION_CREDENTIALS in .env.",
        }), 503

    data = request.get_json(force=True, silent=True) or {}
    text = (data.get("text") or "").strip()
    if not text:
        return jsonify({"error": "text is required"}), 400

    # Default: warm female Neural2 voice, slightly relaxed pace for kids
    voice_id = data.get("voice_id") or "en-US-Neural2-F"
    speaking_rate = float(data.get("speaking_rate") or 0.9)

    # Clamp to safe range
    speaking_rate = max(0.25, min(4.0, speaking_rate))

    # Truncate to 5 000 chars (~1 000 words) to keep latency and cost sane
    if len(text) > 5000:
        logger.info("TTS text truncated from %d to 5000 chars", len(text))
        text = text[:5000]

    try:
        audio_bytes = service.generate_speech(
            text=text,
            voice_name=voice_id,
            speaking_rate=speaking_rate,
            use_ssml=True,
        )
    except Exception as e:
        logger.error("TTS synthesis error: %s", e)
        return jsonify({"error": "Synthesis failed", "message": str(e)}), 500

    if not audio_bytes:
        return jsonify({"error": "Empty audio returned"}), 500

    return jsonify({
        "audio_base64": base64.b64encode(audio_bytes).decode("utf-8"),
        "format": "mp3",
        "voice_id": voice_id,
    })
