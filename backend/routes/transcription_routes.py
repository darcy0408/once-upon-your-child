"""
Transcription route — server-side speech-to-text for the web build.

WHY THIS EXISTS
---------------
Voice input on native builds uses the on-device recognizer via
``speech_to_text``: fast, often fully offline, and the audio never leaves the
phone. That path is the best available and this route deliberately does NOT
replace it.

The web build has no equivalent. Browsers expose ``webkitSpeechRecognition``,
but it is unusable in the one place families are most likely to install the
app: an iOS home-screen PWA never delivers a result, while still reporting the
API as available (so the mic button renders and then hangs — see PR #30). The
API is also absent entirely in some browsers.

``getUserMedia`` DOES work in an iOS standalone PWA. So the web client records
audio itself and posts it here for transcription.

PRIVACY
-------
This route sends a child's VOICE to an external vendor, which is a stronger
disclosure than any other call in the app. Accordingly:

- It sits behind ``require_auth`` AND ``require_parental_consent``, like every
  other child-data vendor call.
- Audio is held in memory only, for the duration of the request. It is never
  written to disk, never logged, and never stored in the database.
- Only the resulting text is returned. Nothing about the audio is retained.
- The upload is hard-capped (see ``MAX_AUDIO_BYTES``) — these are name-length
  utterances, not dictation.

PRIVACY_POLICY.md, privacy_policy_screen.dart and parental_consent_screen.dart
must name the provider used here. They currently describe only the on-device
browser/OS recognizers, so they need updating BEFORE this route is enabled.

DORMANT BY DEFAULT
------------------
The route fails CLOSED: without ``TRANSCRIPTION_ENABLED=true`` every request
returns 503, mirroring ``IAP_VERIFICATION_ENABLED``. It ships inert so the
backend half can land and be reviewed without any child's voice reaching a
vendor the policy has not yet disclosed. Flip the flag only once BOTH the
policy surfaces name the provider and a client actually calls this route.

POST /api/transcribe
  Body: multipart/form-data with an ``audio`` file part
  Returns: { "text": str }
  400  — no audio part, empty upload, or an unsupported content type
  413  — audio exceeds MAX_AUDIO_BYTES
  503  — disabled by flag, not configured, or the provider failed
"""

import logging
import os

from flask import Blueprint, jsonify, request

logger = logging.getLogger(__name__)

# Utterances here are hero names and one-line story ideas. 4MB is far more
# than that needs and still bounds what an authenticated client can upload.
MAX_AUDIO_BYTES = 4 * 1024 * 1024

# Containers a browser MediaRecorder realistically produces, plus the formats
# iOS Safari emits. Anything else is rejected rather than forwarded blindly.
ALLOWED_CONTENT_TYPES = {
    "audio/webm",
    "audio/ogg",
    "audio/mp4",
    "audio/mpeg",
    "audio/wav",
    "audio/x-wav",
    "audio/aac",
}

# Extension handed to the provider SDK. The provider sniffs the container, but
# it requires a filename with a plausible extension.
_CONTENT_TYPE_EXTENSIONS = {
    "audio/webm": "webm",
    "audio/ogg": "ogg",
    "audio/mp4": "mp4",
    "audio/mpeg": "mp3",
    "audio/wav": "wav",
    "audio/x-wav": "wav",
    "audio/aac": "aac",
}

DEFAULT_MODEL = "gpt-4o-mini-transcribe"


def _base_content_type(raw: str) -> str:
    """Strip codec parameters — MediaRecorder sends 'audio/webm;codecs=opus'."""
    return (raw or "").split(";")[0].strip().lower()


def _build_client(api_key):
    """Construct the OpenAI client.

    Kept as a module function (not an inline import) so tests can stub the SDK
    without the ``openai`` package being installed — mirrors
    ``openai_story_generator._build_client``.
    """
    import openai  # lazy: see docstring

    return openai.OpenAI(api_key=api_key, timeout=30.0, max_retries=1)


def create_transcription_blueprint(limiter, require_auth):
    transcription_bp = Blueprint("transcription", __name__)

    # A child's voice is child data going to an external vendor, so this sits
    # behind the same consent gate as the other vendor calls. Same
    # backend/bare import fallback the rest of the package uses.
    try:
        from backend.middleware.auth import require_parental_consent
    except ImportError:
        from middleware.auth import require_parental_consent

    @transcription_bp.route("/api/transcribe", methods=["POST"])
    @require_auth
    @require_parental_consent
    @limiter.limit(
        "60 per hour",
        key_func=lambda: (
            request.current_user.id
            if hasattr(request, "current_user") and request.current_user
            else request.remote_addr
        ),
    )
    def transcribe():
        """Transcribe a short spoken utterance to text.

        Returns only the transcript. The audio is never persisted.
        """
        # Fails CLOSED, like IAP_VERIFICATION_ENABLED. This route sends a
        # child's voice to an external vendor that the privacy policy does not
        # yet name — the policy currently describes only the on-device
        # browser/OS recognizers. Do not flip this on until PRIVACY_POLICY.md,
        # privacy_policy_screen.dart and parental_consent_screen.dart disclose
        # the provider AND a client actually calls this route.
        if os.environ.get("TRANSCRIPTION_ENABLED", "").lower() not in (
            "1",
            "true",
            "yes",
        ):
            return (
                jsonify(
                    {
                        "error": "transcription_unavailable",
                        "message": "Voice input is not available.",
                    }
                ),
                503,
            )

        upload = request.files.get("audio")
        if upload is None:
            return (
                jsonify({"error": "audio file part is required"}),
                400,
            )

        content_type = _base_content_type(upload.mimetype)
        if content_type not in ALLOWED_CONTENT_TYPES:
            return (
                jsonify(
                    {
                        "error": "unsupported_audio_type",
                        "message": f"Unsupported audio type: {content_type or 'unknown'}",
                    }
                ),
                400,
            )

        # Read with a one-byte overshoot so an oversized upload is detected
        # without trusting a client-supplied Content-Length.
        audio_bytes = upload.read(MAX_AUDIO_BYTES + 1)
        if len(audio_bytes) > MAX_AUDIO_BYTES:
            return (
                jsonify(
                    {
                        "error": "audio_too_large",
                        "message": "Recording is too long. Try a shorter one.",
                    }
                ),
                413,
            )
        if not audio_bytes:
            return jsonify({"error": "audio file is empty"}), 400

        api_key = os.environ.get("OPENAI_API_KEY")
        if not api_key:
            logger.warning("Transcription requested but OPENAI_API_KEY is unset")
            return (
                jsonify(
                    {
                        "error": "transcription_unavailable",
                        "message": "Voice input is not configured.",
                    }
                ),
                503,
            )

        extension = _CONTENT_TYPE_EXTENSIONS.get(content_type, "webm")
        model = os.environ.get("TRANSCRIPTION_MODEL", DEFAULT_MODEL)

        try:
            client = _build_client(api_key)
            result = client.audio.transcriptions.create(
                model=model,
                file=(f"utterance.{extension}", audio_bytes, content_type),
            )
        except Exception as e:
            # Deliberately does not include the exception text in the response:
            # provider errors are not child-facing copy, and this route's
            # inputs are voice data we do not want echoed anywhere.
            logger.error("Transcription failed: %s", e)
            return (
                jsonify(
                    {
                        "error": "transcription_failed",
                        "message": "Could not understand that. Please try again.",
                    }
                ),
                503,
            )

        try:
            from backend.services.cost_tracker import (
                log_api_cost,
                openai_transcription_cost,
            )

            # The default JSON response carries no duration, so estimate the
            # audio length from the upload size (~4 KB/s for the Opus-family
            # codecs browsers record) — estimate-grade is fine for a $ alarm.
            estimated_seconds = len(audio_bytes) / 4000
            log_api_cost(
                provider="openai",
                feature="transcription",
                cost_usd=openai_transcription_cost(estimated_seconds, model),
                user_id=str(request.current_user.id),
                units=len(audio_bytes),
                unit_kind="bytes",
                extra={"model": model, "estimated": True},
            )
        except Exception:
            logger.debug("cost_tracker logging failed", exc_info=True)

        text = (getattr(result, "text", "") or "").strip()
        return jsonify({"text": text})

    return transcription_bp
