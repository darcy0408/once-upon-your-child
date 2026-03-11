"""
ElevenLabs Text-to-Speech Service
High-quality AI narration for stories using ElevenLabs voices.
"""

import os
import re
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
        "id": "XrExE9yKIg1WjnnlVkGX",
        "name": "Matilda",
        "gender": "female",
        "accent": "American",
        "description": "Warm, expressive storyteller — ElevenLabs' best for children's narration",
        "recommended": True,
        "age_hint": "all ages",
    },
    {
        "id": "21m00Tcm4TlvDq8ikWAM",
        "name": "Rachel",
        "gender": "female",
        "accent": "American",
        "description": "Calm and gentle — great for bedtime stories",
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

DEFAULT_VOICE_ID = "XrExE9yKIg1WjnnlVkGX"  # Matilda — warmest for kids' storytelling

# eleven_multilingual_v2: highest expressiveness, best for children's narration.
# eleven_turbo_v2_5: ~50% faster with only a slight quality trade-off — good
# for interactive/adventure modes where latency matters more.
DEFAULT_MODEL = "eleven_multilingual_v2"


def clean_text_for_tts(text: str) -> str:
    """
    Strip markdown and normalise punctuation so ElevenLabs reads naturally.

    AI-generated stories often contain formatting (**, #, --) that TTS
    models read literally, producing robotic or garbled narration.
    """
    # Remove markdown headers (# Title, ## Section, etc.)
    text = re.sub(r"^#{1,6}\s+", "", text, flags=re.MULTILINE)

    # Bold and italic (**text**, *text*, __text__, _text_)
    text = re.sub(r"\*{1,3}|_{1,3}", "", text)

    # Inline code and code blocks
    text = re.sub(r"```[\s\S]*?```", "", text)
    text = re.sub(r"`[^`]*`", "", text)

    # Markdown links and images  [text](url) → text
    text = re.sub(r"!\[.*?\]\(.*?\)", "", text)
    text = re.sub(r"\[([^\]]+)\]\([^\)]+\)", r"\1", text)

    # Horizontal rules
    text = re.sub(r"^[-*_]{3,}\s*$", "", text, flags=re.MULTILINE)

    # Blockquotes
    text = re.sub(r"^>\s+", "", text, flags=re.MULTILINE)

    # Unordered list bullets (-, *, +)
    text = re.sub(r"^\s*[-*+]\s+", "", text, flags=re.MULTILINE)

    # Ordered list numbers (1. 2. etc.)
    text = re.sub(r"^\s*\d+\.\s+", "", text, flags=re.MULTILINE)

    # Em-dash and double-hyphen → comma-space for a natural pause
    text = re.sub(r"\s*—\s*|\s*--\s*", ", ", text)

    # Ellipsis normalisation — keep as "..." so ElevenLabs pauses naturally
    text = re.sub(r"\.{4,}", "...", text)

    # Remove any remaining HTML tags
    text = re.sub(r"<[^>]+>", "", text)

    # Collapse multiple blank lines to a single paragraph break
    text = re.sub(r"\n{3,}", "\n\n", text)

    return text.strip()


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
        stability: float = 0.35,
        similarity_boost: float = 0.80,
        style: float = 0.50,
        model_id: str = DEFAULT_MODEL,
    ) -> bytes:
        """
        Generate MP3 audio from text using ElevenLabs.

        Args:
            text: Story text to narrate (max ~5 000 chars for latency).
                  Markdown and special formatting are stripped automatically.
            voice_id: ElevenLabs voice ID.
            stability: 0–1 — lower = more expressive natural variation.
                       0.35 gives lively storytelling cadence.
            similarity_boost: 0–1 — higher = truer to original voice character.
                              0.80 keeps voices rich and consistent.
            style: 0–1 — emotional warmth/exaggeration.
                   0.50 gives engaging narration without over-acting.
            model_id: ElevenLabs model. eleven_multilingual_v2 is highest
                      quality; eleven_turbo_v2_5 is ~50% faster for interactive.

        Returns:
            MP3 audio as bytes.
        """
        text = clean_text_for_tts(text)

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
