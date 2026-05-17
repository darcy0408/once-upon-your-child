"""
Microsoft Edge TTS — free fallback narration service.

Used when ElevenLabs is unavailable (no API key configured) or its monthly
quota / character budget is exhausted. Produces natural-sounding neural MP3
audio so the app never has to drop to the robotic on-device flutter_tts voice
while the device is online. Requires no API key.
"""

import asyncio
import concurrent.futures
import logging
from typing import List, Tuple

logger = logging.getLogger(__name__)

try:
    import edge_tts
    EDGE_TTS_AVAILABLE = True
except ImportError:
    EDGE_TTS_AVAILABLE = False
    edge_tts = None


# Closest Edge neural voice for each curated ElevenLabs voice, so the free
# fallback keeps roughly the gender/accent the user picked in the voice picker.
# Keys mirror CURATED_VOICES in elevenlabs_tts_service.py.
_ELEVENLABS_TO_EDGE = {
    "XrExE9yKIg1WjnnlVkGX": "en-US-JennyNeural",    # Matilda — warm US female
    "21m00Tcm4TlvDq8ikWAM": "en-US-AriaNeural",     # Rachel — calm US female
    "ThT5KcBeYPX3keUQqHPh": "en-GB-SoniaNeural",    # Dorothy — British female
    "jBpfuIE2acCO8z3wKNLl": "en-US-AnaNeural",      # Gigi — childlike US female
    "JBFqnCBsd6RMkjVDRZzb": "en-GB-RyanNeural",     # George — British male
    "IKne3meq5aSn9XLyUdCD": "en-AU-WilliamNeural",  # Charlie — Australian male
    "N2lVS1w4EtoT3dr4eOWO": "en-US-GuyNeural",      # Callum — US male
    "D38z5RcWu1voky8WS1ja": "en-IE-ConnorNeural",   # Fin — Irish male
}

# Warm storytelling default when the requested voice has no mapping.
DEFAULT_EDGE_VOICE = "en-US-JennyNeural"


def edge_voice_for(elevenlabs_voice_id: str) -> str:
    """Map an ElevenLabs voice ID to the closest Edge neural voice."""
    return _ELEVENLABS_TO_EDGE.get((elevenlabs_voice_id or "").strip(), DEFAULT_EDGE_VOICE)


def _speed_to_rate(speed: float) -> str:
    """Convert an ElevenLabs-style speed (0.7–1.2) to an Edge rate string."""
    pct = int(round((speed - 1.0) * 100))
    return f"{pct:+d}%"


def _run_async(coro):
    """Run a coroutine to completion from sync code, even if a loop is live."""
    try:
        asyncio.get_running_loop()
    except RuntimeError:
        return asyncio.run(coro)
    # A loop is already running (e.g. under an async worker) — isolate in a thread.
    with concurrent.futures.ThreadPoolExecutor(max_workers=1) as ex:
        return ex.submit(lambda: asyncio.run(coro)).result()


class EdgeTTSService:
    """Free Microsoft Edge neural TTS — the ElevenLabs narration fallback."""

    @staticmethod
    def available() -> bool:
        return EDGE_TTS_AVAILABLE

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
                      closest Edge neural voice.
            speed: Speaking rate multiplier (0.7–1.2); 1.0 is normal speed.

        Returns:
            (audio_bytes, word_timestamps) where word_timestamps is a list of
            {start_ms, end_ms} dicts, one per word, in order.
        """
        if not EDGE_TTS_AVAILABLE:
            raise RuntimeError("edge-tts not installed. Run: pip install edge-tts")

        voice = edge_voice_for(voice_id)
        rate = _speed_to_rate(speed)

        async def _run() -> Tuple[bytes, List[dict]]:
            communicate = edge_tts.Communicate(
                text, voice, rate=rate, boundary="WordBoundary"
            )
            audio = bytearray()
            words: List[dict] = []
            async for chunk in communicate.stream():
                ctype = chunk.get("type")
                if ctype == "audio":
                    audio.extend(chunk["data"])
                elif ctype == "WordBoundary":
                    # offset/duration are in 100-nanosecond ticks.
                    start_ms = int(chunk["offset"] / 10000)
                    end_ms = int((chunk["offset"] + chunk["duration"]) / 10000)
                    words.append({"start_ms": start_ms, "end_ms": end_ms})
            return bytes(audio), words

        audio_bytes, word_timestamps = _run_async(_run())
        logger.info(
            "Edge TTS: %d bytes, %d words for %d chars (voice=%s rate=%s)",
            len(audio_bytes), len(word_timestamps), len(text), voice, rate,
        )
        return audio_bytes, word_timestamps
