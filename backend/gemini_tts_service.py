"""
Gemini 3.1 Flash TTS — overflow tier above Edge in the narration fallback chain.

Used when ElevenLabs is unavailable (no API key, monthly char-budget exhausted,
or runtime error) but a paying user still expects a high-quality voice. Costs
~$0.054/1k characters versus ElevenLabs' ~$0.18/1k, with comparable quality and
inline expressive-tag control (e.g. [whispers], [excited]).

Returns MP3 bytes so the response shape matches ElevenLabsTTSService — Gemini
itself returns PCM 24kHz mono 16-bit, which is transcoded via pydub.
"""

import io
import logging
import os
import re
from typing import List, Optional, Tuple

logger = logging.getLogger(__name__)

try:
    from google import genai
    from google.genai import types as genai_types

    GEMINI_GENAI_AVAILABLE = True
except ImportError:
    GEMINI_GENAI_AVAILABLE = False
    genai = None
    genai_types = None

try:
    from pydub import AudioSegment

    PYDUB_AVAILABLE = True
except ImportError:
    PYDUB_AVAILABLE = False
    AudioSegment = None


GEMINI_TTS_MODEL = "gemini-3.1-flash-tts-preview"

# Curated subset of Gemini's 30 prebuilt voices, picked for kids' storytelling.
# Voice IDs use Gemini's prebuilt name so the SDK call accepts them directly.
CURATED_VOICES: List[dict] = [
    {
        "id": "Leda",
        "name": "Warm Female (Leda)",
        "gender": "female",
        "description": "Warm and expressive — Gemini equivalent of Matilda",
        "recommended": True,
        "age_hint": "all ages",
    },
    {
        "id": "Aoede",
        "name": "Gentle Female (Aoede)",
        "gender": "female",
        "description": "Soft and calming — great for bedtime stories",
        "recommended": False,
        "age_hint": "all ages",
    },
    {
        "id": "Callirrhoe",
        "name": "Playful Female (Callirrhoe)",
        "gender": "female",
        "description": "Bright and animated — engaging for younger kids",
        "recommended": False,
        "age_hint": "ages 3-7",
    },
    {
        "id": "Kore",
        "name": "Clear Female (Kore)",
        "gender": "female",
        "description": "Crisp and articulate — good for adventure stories",
        "recommended": False,
        "age_hint": "all ages",
    },
    {
        "id": "Charon",
        "name": "Deep Male (Charon)",
        "gender": "male",
        "description": "Rich, resonant narrator — classic storybook feel",
        "recommended": False,
        "age_hint": "all ages",
    },
    {
        "id": "Puck",
        "name": "Lively Male (Puck)",
        "gender": "male",
        "description": "Energetic and playful — fun for action tales",
        "recommended": False,
        "age_hint": "ages 6+",
    },
    {
        "id": "Fenrir",
        "name": "Strong Male (Fenrir)",
        "gender": "male",
        "description": "Bold and dramatic — heroic adventures",
        "recommended": False,
        "age_hint": "ages 8+",
    },
    {
        "id": "Zephyr",
        "name": "Warm Male (Zephyr)",
        "gender": "male",
        "description": "Friendly and engaging male narrator",
        "recommended": False,
        "age_hint": "all ages",
    },
]

DEFAULT_VOICE_ID = "Leda"

# Map the curated ElevenLabs voice IDs (used in the Flutter voice picker) to the
# closest Gemini prebuilt voice, so a user's selected voice survives a fallback
# from ElevenLabs to Gemini without surprising them.
_ELEVENLABS_TO_GEMINI = {
    "XrExE9yKIg1WjnnlVkGX": "Leda",  # Matilda → warm female
    "21m00Tcm4TlvDq8ikWAM": "Aoede",  # Rachel → calm female
    "ThT5KcBeYPX3keUQqHPh": "Aoede",  # Dorothy (British) → calm female
    "jBpfuIE2acCO8z3wKNLl": "Callirrhoe",  # Gigi (childlike) → playful female
    "JBFqnCBsd6RMkjVDRZzb": "Charon",  # George (British) → deep male
    "IKne3meq5aSn9XLyUdCD": "Zephyr",  # Charlie (Australian) → warm male
    "N2lVS1w4EtoT3dr4eOWO": "Puck",  # Callum → lively male
    "D38z5RcWu1voky8WS1ja": "Charon",  # Fin (Irish) → deep male
}


def gemini_voice_for(elevenlabs_voice_id: str) -> str:
    """Map an ElevenLabs voice ID to the closest Gemini prebuilt voice."""
    return _ELEVENLABS_TO_GEMINI.get(
        (elevenlabs_voice_id or "").strip(), DEFAULT_VOICE_ID
    )


def _pcm_to_mp3(pcm_bytes: bytes, sample_rate: int = 24000) -> bytes:
    """
    Transcode Gemini's PCM 24kHz mono 16-bit output to MP3.

    Requires pydub (already a dep for ElevenLabs chunking) and ffmpeg in PATH.
    """
    if not PYDUB_AVAILABLE:
        raise RuntimeError("pydub not installed. Run: pip install pydub")

    segment = AudioSegment(
        data=pcm_bytes,
        sample_width=2,
        frame_rate=sample_rate,
        channels=1,
    )
    buf = io.BytesIO()
    segment.export(buf, format="mp3", bitrate="128k")
    return buf.getvalue()


# Patterns where injecting an inline emotion tag noticeably improves narration.
# Conservative — false positives are worse than no tag at all.
_EMOTION_PATTERNS = [
    (re.compile(r"\b(whispered|whispers|whispering)\b", re.IGNORECASE), "[whispers]"),
    (re.compile(r"\b(shouted|yelled|screamed)\b", re.IGNORECASE), "[loudly]"),
    (re.compile(r"\b(laughed|giggled|chuckled)\b", re.IGNORECASE), "[laughs]"),
    (re.compile(r"\b(gasped)\b", re.IGNORECASE), "[gasps]"),
    (re.compile(r"\b(cried|sobbed)\b", re.IGNORECASE), "[sadly]"),
]


def add_emotion_tags(text: str) -> str:
    """
    Insert Gemini inline emotion tags after narrative cues like 'whispered'.

    Tags steer the next clause's delivery. Inserted *after* the cue so the
    cue itself is still spoken, then the following speech reflects the emotion.
    """
    for pattern, tag in _EMOTION_PATTERNS:
        text = pattern.sub(lambda m: f"{m.group(0)} {tag}", text)
    return text


class GeminiTTSService:
    """Gemini 3.1 Flash TTS for kids' story narration."""

    def __init__(self, api_key: Optional[str] = None):
        if not GEMINI_GENAI_AVAILABLE:
            raise ImportError(
                "google-genai not installed. Run: pip install google-genai"
            )
        key = api_key or os.environ.get("GEMINI_API_KEY")
        if not key:
            raise ValueError("GEMINI_API_KEY not set. Add it to backend/.env")
        self.client = genai.Client(api_key=key)
        logger.info("Gemini Flash TTS initialised")

    def generate_speech(
        self,
        text: str,
        voice_id: str = DEFAULT_VOICE_ID,
        use_emotion_tags: bool = True,
    ) -> bytes:
        """
        Generate MP3 audio from text using Gemini 3.1 Flash TTS.

        Args:
            text: Story text. Markdown should already be stripped by the caller
                  (use clean_text_for_tts from elevenlabs_tts_service).
            voice_id: A Gemini prebuilt voice name (e.g. 'Leda', 'Charon') OR
                      an ElevenLabs voice ID — the latter is mapped to the
                      closest Gemini voice automatically.
            use_emotion_tags: If True, inject inline tags like [whispers]
                              after narrative cues to improve expressiveness.

        Returns:
            MP3 audio as bytes.
        """
        # Accept either a Gemini prebuilt name or an ElevenLabs ID for the
        # cross-provider fallback path.
        if voice_id and len(voice_id) > 16 and voice_id not in _GEMINI_VOICE_NAMES:
            gemini_voice = gemini_voice_for(voice_id)
        else:
            gemini_voice = voice_id or DEFAULT_VOICE_ID

        prompt_text = add_emotion_tags(text) if use_emotion_tags else text

        response = self.client.models.generate_content(
            model=GEMINI_TTS_MODEL,
            contents=prompt_text,
            config=genai_types.GenerateContentConfig(
                response_modalities=["AUDIO"],
                speech_config=genai_types.SpeechConfig(
                    voice_config=genai_types.VoiceConfig(
                        prebuilt_voice_config=genai_types.PrebuiltVoiceConfig(
                            voice_name=gemini_voice,
                        )
                    )
                ),
            ),
        )

        pcm_bytes = response.candidates[0].content.parts[0].inline_data.data
        return _pcm_to_mp3(pcm_bytes)

    def generate_speech_with_timestamps(
        self,
        text: str,
        voice_id: str = DEFAULT_VOICE_ID,
        speed: float = 1.0,  # Accepted for API compatibility; Gemini ignores it
        use_emotion_tags: bool = True,
    ) -> Tuple[bytes, List[dict]]:
        """
        Generate MP3 audio. Word timestamps are not provided by Gemini TTS, so
        the second tuple element is always an empty list — synchronized word
        highlighting falls back to text-only display for Gemini-served audio.
        """
        audio_bytes = self.generate_speech(
            text=text, voice_id=voice_id, use_emotion_tags=use_emotion_tags
        )
        return audio_bytes, []

    @staticmethod
    def get_available_voices() -> List[dict]:
        return CURATED_VOICES


class MockGeminiTTSService:
    """Mock service for tests — returns empty bytes without calling the API."""

    def generate_speech(self, text: str, **kwargs) -> bytes:
        logger.info("[MockGeminiTTS] Would generate speech for %d chars", len(text))
        return b""

    def generate_speech_with_timestamps(
        self, text: str, **kwargs
    ) -> Tuple[bytes, List[dict]]:
        logger.info(
            "[MockGeminiTTS] Would generate speech (with-timestamps) for %d chars",
            len(text),
        )
        return b"", []

    @staticmethod
    def get_available_voices() -> List[dict]:
        return CURATED_VOICES


# Set of valid Gemini prebuilt voice names (the 30 documented options). Used by
# generate_speech() to distinguish a Gemini voice name from an ElevenLabs ID.
_GEMINI_VOICE_NAMES = frozenset(
    {
        "Zephyr",
        "Puck",
        "Charon",
        "Kore",
        "Fenrir",
        "Leda",
        "Orus",
        "Aoede",
        "Callirrhoe",
        "Autonoe",
        "Enceladus",
        "Iapetus",
        "Umbriel",
        "Algieba",
        "Despina",
        "Erinome",
        "Algenib",
        "Rasalgethi",
        "Laomedeia",
        "Achernar",
        "Alnilam",
        "Schedar",
        "Gacrux",
        "Pulcherrima",
        "Achird",
        "Zubenelgenubi",
        "Vindemiatrix",
        "Sadachbia",
        "Sadaltager",
        "Sulafat",
    }
)
