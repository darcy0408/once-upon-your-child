"""
ElevenLabs Text-to-Speech Service
High-quality AI narration for stories using ElevenLabs voices.
"""

import os
import logging
from typing import Optional, List

logger = logging.getLogger(__name__)

try:
    from elevenlabs.client import ElevenLabs
    from elevenlabs import VoiceSettings
    ELEVENLABS_AVAILABLE = True
except ImportError:
    ELEVENLABS_AVAILABLE = False
    ElevenLabs = None
    VoiceSettings = None


# Curated voices for kids' storytelling — picked for warmth, clarity, and age range
CURATED_VOICES: List[dict] = [
    {
        "id": "21m00Tcm4TlvDq8ikWAM",
        "name": "Rachel",
        "gender": "female",
        "accent": "American",
        "description": "Warm and gentle — perfect for bedtime stories",
        "recommended": True,
        "age_hint": "all ages",
    },
    {
        "id": "XrExE9yKIg1WjnnlVkGX",
        "name": "Matilda",
        "gender": "female",
        "accent": "American",
        "description": "Bright and friendly narrator kids love",
        "recommended": False,
        "age_hint": "all ages",
    },
    {
        "id": "ThT5KcBeYPX3keUQqHPh",
        "name": "Dorothy",
        "gender": "female",
        "accent": "British",
        "description": "Classic British storyteller, calm and clear",
        "recommended": False,
        "age_hint": "all ages",
    },
    {
        "id": "jBpfuIE2acCO8z3wKNLl",
        "name": "Gigi",
        "gender": "female",
        "accent": "American",
        "description": "Playful and childlike — great for little ones",
        "recommended": False,
        "age_hint": "ages 3-7",
    },
    {
        "id": "JBFqnCBsd6RMkjVDRZzb",
        "name": "George",
        "gender": "male",
        "accent": "British",
        "description": "Rich British narrator — ideal for adventures",
        "recommended": False,
        "age_hint": "all ages",
    },
    {
        "id": "IKne3meq5aSn9XLyUdCD",
        "name": "Charlie",
        "gender": "male",
        "accent": "Australian",
        "description": "Relaxed and warm Australian storyteller",
        "recommended": False,
        "age_hint": "all ages",
    },
    {
        "id": "N2lVS1w4EtoT3dr4eOWO",
        "name": "Callum",
        "gender": "male",
        "accent": "American",
        "description": "Clear and expressive — great for action tales",
        "recommended": False,
        "age_hint": "ages 8+",
    },
    {
        "id": "D38z5RcWu1voky8WS1ja",
        "name": "Fin",
        "gender": "male",
        "accent": "Irish",
        "description": "Charming Irish lilt — magical and enchanting",
        "recommended": False,
        "age_hint": "all ages",
    },
]

DEFAULT_VOICE_ID = "21m00Tcm4TlvDq8ikWAM"  # Rachel

# eleven_turbo_v2_5 gives the best balance of speed and quality for kids' UX
DEFAULT_MODEL = "eleven_turbo_v2_5"


class ElevenLabsTTSService:
    """ElevenLabs TTS service for high-quality story narration."""

    def __init__(self, api_key: Optional[str] = None):
        if not ELEVENLABS_AVAILABLE:
            raise ImportError(
                "ElevenLabs SDK not installed. Run: pip install elevenlabs"
            )
        key = api_key or os.environ.get("ELEVENLABS_API_KEY")
        if not key:
            raise ValueError(
                "ELEVENLABS_API_KEY not set. Add it to backend/.env"
            )
        self.client = ElevenLabs(api_key=key)
        logger.info("ElevenLabs TTS initialised")

    def generate_speech(
        self,
        text: str,
        voice_id: str = DEFAULT_VOICE_ID,
        stability: float = 0.55,
        similarity_boost: float = 0.80,
        style: float = 0.20,
        model_id: str = DEFAULT_MODEL,
    ) -> bytes:
        """
        Generate MP3 audio from text using ElevenLabs.

        Args:
            text: Story text to narrate (max ~5 000 chars for latency).
            voice_id: ElevenLabs voice ID.
            stability: 0–1 — higher = more consistent but less expressive.
            similarity_boost: 0–1 — higher = closer to original voice style.
            style: 0–1 — emotional exaggeration amount.
            model_id: ElevenLabs model to use.

        Returns:
            MP3 audio as bytes.
        """
        voice_settings = VoiceSettings(
            stability=stability,
            similarity_boost=similarity_boost,
            style=style,
            use_speaker_boost=True,
        )

        audio_generator = self.client.text_to_speech.convert(
            voice_id=voice_id,
            text=text,
            model_id=model_id,
            voice_settings=voice_settings,
            output_format="mp3_44100_128",
        )

        return b"".join(audio_generator)

    @staticmethod
    def get_available_voices() -> List[dict]:
        return CURATED_VOICES


class MockElevenLabsTTSService:
    """Mock service for testing — returns empty bytes without calling API."""

    def generate_speech(self, text: str, **kwargs) -> bytes:
        logger.info("[MockElevenLabsTTS] Would generate speech for %d chars", len(text))
        return b""

    @staticmethod
    def get_available_voices() -> List[dict]:
        return CURATED_VOICES
