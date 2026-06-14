"""
Azure AI Speech — licensed neural TTS narration service.

MT-248 launch-gate: the prior narration chain (Gemini Flash TTS → Edge TTS →
ElevenLabs) is not viable for a commercial kids' app — Gemini and ElevenLabs
bar under-18 use, and the `edge-tts` package is an unofficial wrapper of Edge's
"Read aloud" endpoint that Microsoft's own guidance says is NOT licensed for
commercial use (they direct commercial users to Azure AI Speech). Azure AI
Speech is the licensed replacement: the SAME neural voices as Edge "Read aloud"
(so the audio is essentially unchanged), real-time synthesis that does NOT
retain audio or use it to train models (strong COPPA posture), and word-boundary
events for read-along highlighting parity with the Edge fallback.

This mirrors ``edge_tts_service.EdgeTTSService``'s public shape so it drops into
the same ``/tts/synthesize`` chain. The ``azure-cognitiveservices-speech`` SDK
is imported lazily so the app boots without it; the provider activates only when
``AZURE_SPEECH_KEY`` (+ ``AZURE_SPEECH_REGION``) are set. Going live needs only
``pip install azure-cognitiveservices-speech`` + those two env vars.
"""

import logging
import os
from typing import List, Tuple
from xml.sax.saxutils import escape as _xml_escape

logger = logging.getLogger(__name__)

try:
    import azure.cognitiveservices.speech as speechsdk

    AZURE_SPEECH_AVAILABLE = True
except ImportError:
    AZURE_SPEECH_AVAILABLE = False
    speechsdk = None

# Azure neural voice per curated ElevenLabs voice — identical voice names to the
# Edge fallback (Edge "Read aloud" voices ARE Azure neural voices), so switching
# the user's picked voice from Edge to Azure is audibly seamless. Keys mirror
# CURATED_VOICES in elevenlabs_tts_service.py / _ELEVENLABS_TO_EDGE.
_ELEVENLABS_TO_AZURE = {
    "XrExE9yKIg1WjnnlVkGX": "en-US-JennyNeural",  # Matilda — warm US female
    "21m00Tcm4TlvDq8ikWAM": "en-US-AriaNeural",  # Rachel — calm US female
    "ThT5KcBeYPX3keUQqHPh": "en-GB-SoniaNeural",  # Dorothy — British female
    "jBpfuIE2acCO8z3wKNLl": "en-US-AnaNeural",  # Gigi — childlike US female
    "JBFqnCBsd6RMkjVDRZzb": "en-GB-RyanNeural",  # George — British male
    "IKne3meq5aSn9XLyUdCD": "en-AU-WilliamNeural",  # Charlie — Australian male
    "N2lVS1w4EtoT3dr4eOWO": "en-US-GuyNeural",  # Callum — US male
    "D38z5RcWu1voky8WS1ja": "en-IE-ConnorNeural",  # Fin — Irish male
}

DEFAULT_AZURE_VOICE = "en-US-JennyNeural"


def azure_voice_for(elevenlabs_voice_id: str) -> str:
    """Map an ElevenLabs voice ID to the matching Azure neural voice."""
    return _ELEVENLABS_TO_AZURE.get(
        (elevenlabs_voice_id or "").strip(), DEFAULT_AZURE_VOICE
    )


def _speed_to_rate(speed: float) -> str:
    """Convert an ElevenLabs-style speed (0.7–1.2) to an SSML prosody rate.

    Same relative-percent form the Edge service uses (e.g. 1.1 -> "+10%",
    0.8 -> "-20%"), so playback speed matches the prior fallback.
    """
    pct = int(round((speed - 1.0) * 100))
    return f"{pct:+d}%"


def _build_ssml(text: str, voice: str, rate: str) -> str:
    """Wrap text in SSML with the chosen voice + prosody rate (text escaped)."""
    return (
        '<speak version="1.0" xmlns="http://www.w3.org/2001/10/synthesis" '
        'xml:lang="en-US">'
        f'<voice name="{voice}">'
        f'<prosody rate="{rate}">{_xml_escape(text)}</prosody>'
        "</voice></speak>"
    )


class AzureTTSService:
    """Licensed Azure AI Speech neural TTS — the MT-248 narration provider."""

    @staticmethod
    def available() -> bool:
        """True only when the SDK is installed AND the key/region are set."""
        return bool(
            AZURE_SPEECH_AVAILABLE
            and os.environ.get("AZURE_SPEECH_KEY")
            and os.environ.get("AZURE_SPEECH_REGION")
        )

    def generate_speech_with_timestamps(
        self,
        text: str,
        voice_id: str = "",
        speed: float = 1.0,
    ) -> Tuple[bytes, List[dict]]:
        """
        Synthesize MP3 audio with per-word timestamps.

        Args:
            text: Story text (markdown already stripped by the caller).
            voice_id: The ElevenLabs voice ID the user picked — mapped to the
                      matching Azure neural voice.
            speed: Speaking rate multiplier (0.7–1.2); 1.0 is normal speed.

        Returns:
            (audio_bytes, word_timestamps) where word_timestamps is a list of
            {start_ms, end_ms} dicts, one per word, in order — same shape as the
            Edge fallback, so read-along highlighting works unchanged.

        Audio is synthesized in-memory and returned; nothing is written to disk
        or retained (audio_config=None keeps it out of any file/speaker sink).
        """
        if not AZURE_SPEECH_AVAILABLE:
            raise RuntimeError(
                "azure-cognitiveservices-speech not installed. "
                "Run: pip install azure-cognitiveservices-speech"
            )
        key = os.environ.get("AZURE_SPEECH_KEY")
        region = os.environ.get("AZURE_SPEECH_REGION")
        if not key or not region:
            raise RuntimeError("AZURE_SPEECH_KEY / AZURE_SPEECH_REGION not set")

        voice = azure_voice_for(voice_id)
        rate = _speed_to_rate(speed)

        speech_config = speechsdk.SpeechConfig(subscription=key, region=region)
        speech_config.speech_synthesis_voice_name = voice
        speech_config.set_speech_synthesis_output_format(
            speechsdk.SpeechSynthesisOutputFormat.Audio24Khz48KBitRateMonoMp3
        )
        # audio_config=None -> audio is returned in the result, not played/saved.
        synthesizer = speechsdk.SpeechSynthesizer(
            speech_config=speech_config, audio_config=None
        )

        words: List[dict] = []

        def _on_word_boundary(evt):
            # audio_offset is in 100-nanosecond ticks; duration is a timedelta.
            start_ms = int(evt.audio_offset / 10000)
            dur_ms = int(evt.duration.total_seconds() * 1000)
            words.append({"start_ms": start_ms, "end_ms": start_ms + dur_ms})

        synthesizer.synthesis_word_boundary.connect(_on_word_boundary)

        result = synthesizer.speak_ssml_async(_build_ssml(text, voice, rate)).get()

        if result.reason != speechsdk.ResultReason.SynthesizingAudioCompleted:
            detail = getattr(result, "reason", "unknown")
            cancellation = getattr(result, "cancellation_details", None)
            if cancellation is not None:
                detail = (
                    f"{cancellation.reason}: "
                    f"{getattr(cancellation, 'error_details', '')}"
                )
            raise RuntimeError(f"Azure TTS did not complete ({detail})")

        audio_bytes = bytes(result.audio_data or b"")
        logger.info(
            "Azure AI Speech: %d bytes, %d words for %d chars (voice=%s rate=%s)",
            len(audio_bytes),
            len(words),
            len(text),
            voice,
            rate,
        )
        return audio_bytes, words
