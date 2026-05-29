"""
ElevenLabs Text-to-Speech Service
High-quality AI narration for stories using ElevenLabs voices.
"""

import base64
import io
import logging
import os
import re
import time
from typing import List, Optional, Tuple

logger = logging.getLogger(__name__)

try:
    from elevenlabs import VoiceSettings
    from elevenlabs.client import ElevenLabs

    ELEVENLABS_AVAILABLE = True
except ImportError:
    ELEVENLABS_AVAILABLE = False
    ElevenLabs = None
    VoiceSettings = None

try:
    from pydub import AudioSegment

    PYDUB_AVAILABLE = True
except ImportError:
    PYDUB_AVAILABLE = False
    AudioSegment = None


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


# Matches both straight ASCII quotes and Unicode smart quotes (\u201c / \u201d)
# that AI models (Gemini, GPT) typically emit in generated stories.
_DIALOGUE_RE = re.compile(r'["\u201c]([^"\u201c\u201d]{5,})["\u201d]')


def split_narration_dialogue(text: str) -> List[Tuple[str, str]]:
    """
    Split text into alternating narration / dialogue segments.

    Dialogue is identified by double-quoted strings of 5+ characters.
    Returns a list of (segment_text, segment_type) where segment_type is
    'narration' or 'dialogue'. The outer quotes are kept in dialogue
    segments so ElevenLabs uses them for expressive phrasing.

    Falls back to [(text, 'narration')] when no dialogue is found.
    """
    segments: List[Tuple[str, str]] = []
    last_end = 0

    for match in _DIALOGUE_RE.finditer(text):
        start, end = match.start(), match.end()
        if start > last_end:
            narration = text[last_end:start].strip()
            if narration:
                segments.append((narration, "narration"))
        dialogue = match.group(0).strip()
        if dialogue:
            segments.append((dialogue, "dialogue"))
        last_end = end

    if last_end < len(text):
        trailing = text[last_end:].strip()
        if trailing:
            segments.append((trailing, "narration"))

    return segments if segments else [(text, "narration")]


def split_text_into_chunks(text: str, max_chars: int = 4500) -> List[str]:
    """
    Split cleaned story text into chunks suitable for ElevenLabs synthesis.

    Splits on paragraph boundaries (\n\n) to avoid cutting mid-sentence.
    If a single paragraph exceeds max_chars, splits at the last sentence
    boundary (.!?) before the limit.
    """
    paragraphs = text.split("\n\n")
    chunks: List[str] = []
    current = ""

    for para in paragraphs:
        para = para.strip()
        if not para:
            continue

        # If adding this paragraph stays within the limit, accumulate
        separator = "\n\n" if current else ""
        if len(current) + len(separator) + len(para) <= max_chars:
            current += separator + para
        else:
            # Flush the current chunk first
            if current:
                chunks.append(current)
                current = ""

            # If the paragraph itself exceeds max_chars, split at sentence boundaries
            if len(para) > max_chars:
                sentence_end = re.compile(r"(?<=[.!?])\s+")
                sentences = sentence_end.split(para)
                current = ""
                for sentence in sentences:
                    if len(current) + len(sentence) + 1 <= max_chars:
                        current = (current + " " + sentence).strip()
                    else:
                        if current:
                            chunks.append(current)
                        # Hard-split any sentence longer than max_chars (rare)
                        while len(sentence) > max_chars:
                            chunks.append(sentence[:max_chars])
                            sentence = sentence[max_chars:]
                        current = sentence
            else:
                current = para

    if current:
        chunks.append(current)

    return chunks if chunks else [text]


def _make_silence_mp3(duration_ms: int = 600) -> bytes:
    """
    Return a minimal silent MP3 segment for inter-chunk pauses.
    Uses pydub if available; falls back to a pre-baked 600ms silent MP3 frame.
    """
    if PYDUB_AVAILABLE:
        silent = AudioSegment.silent(duration=duration_ms)
        buf = io.BytesIO()
        silent.export(buf, format="mp3")
        return buf.getvalue()
    # Minimal valid MP3 silence fallback (just return empty bytes — ElevenLabs
    # audio will still concatenate cleanly without inter-chunk silence)
    return b""


def _is_quota_exceeded(exc: Exception) -> bool:
    msg = str(exc)
    return "quota_exceeded" in msg or (
        "status_code: 401" in msg and "quota" in msg.lower()
    )


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
            raise ValueError("ELEVENLABS_API_KEY not set. Add it to backend/.env")
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
        speed: float = 1.0,
    ) -> bytes:
        """
        Generate MP3 audio from text using ElevenLabs.

        Args:
            text: Story text to narrate. For stories > 5 000 chars use
                  generate_speech_chunked() instead to avoid truncation.
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

        vs_kwargs = dict(
            stability=stability,
            similarity_boost=similarity_boost,
            style=style,
            use_speaker_boost=True,
        )
        if speed != 1.0:
            vs_kwargs["speed"] = speed
        try:
            voice_settings = VoiceSettings(**vs_kwargs)
        except TypeError:
            vs_kwargs.pop("speed", None)
            voice_settings = VoiceSettings(**vs_kwargs)

        audio_generator = self.client.text_to_speech.convert(
            voice_id=voice_id,
            text=text,
            model_id=model_id,
            voice_settings=voice_settings,
            output_format="mp3_44100_128",
        )

        return b"".join(audio_generator)

    def generate_speech_chunked(
        self,
        text: str,
        voice_id: str = DEFAULT_VOICE_ID,
        stability: float = 0.35,
        similarity_boost: float = 0.80,
        style: float = 0.50,
        model_id: str = DEFAULT_MODEL,
        chunk_size: int = 4500,
        inter_chunk_pause_ms: int = 600,
    ) -> bytes:
        """
        Synthesize full-length stories by chunking at paragraph boundaries.

        Splits text into ≤chunk_size segments, synthesizes each via ElevenLabs,
        and concatenates the MP3 bytes with a short silence between chunks so
        the audio flows naturally at paragraph breaks.

        Args:
            text: Pre-cleaned story text (markdown already stripped).
            chunk_size: Max characters per ElevenLabs API call (default 4500).
            inter_chunk_pause_ms: Silence between chunks in milliseconds.

        Returns:
            Combined MP3 audio bytes for the full story.
        """
        chunks = split_text_into_chunks(text, max_chars=chunk_size)
        logger.info("Chunked synthesis: %d chunks for %d chars", len(chunks), len(text))

        silence = _make_silence_mp3(inter_chunk_pause_ms)
        combined = io.BytesIO()

        for i, chunk in enumerate(chunks):
            if i > 0 and silence:
                combined.write(silence)

            try:
                audio_bytes = self.generate_speech(
                    text=chunk,
                    voice_id=voice_id,
                    stability=stability,
                    similarity_boost=similarity_boost,
                    style=style,
                    model_id=model_id,
                )
                combined.write(audio_bytes)
                logger.debug(
                    "Chunk %d/%d synthesized (%d chars)", i + 1, len(chunks), len(chunk)
                )
            except Exception as e:
                logger.error("Chunk %d/%d synthesis failed: %s", i + 1, len(chunks), e)
                raise

            # Brief delay between ElevenLabs calls to avoid burst rate limits
            if i < len(chunks) - 1:
                time.sleep(0.2)

        return combined.getvalue()

    def generate_speech_with_dialogue(
        self,
        text: str,
        narrator_voice_id: str = DEFAULT_VOICE_ID,
        character_voice_id: str = "D38z5RcWu1voky8WS1ja",  # Fin — magical Irish
        stability: float = 0.35,
        similarity_boost: float = 0.80,
        style: float = 0.50,
        model_id: str = DEFAULT_MODEL,
        inter_segment_pause_ms: int = 300,
    ) -> bytes:
        """
        Synthesize text with dialogue spoken in a different voice from narration.

        Splits the text at double-quoted dialogue (5+ chars), synthesizes each
        narration segment with narrator_voice_id and each dialogue segment with
        character_voice_id, then concatenates with brief silence between segments.

        Falls back to single-voice synthesis when no dialogue is found.
        """
        segments = split_narration_dialogue(text)
        has_dialogue = any(t == "dialogue" for _, t in segments)

        if not has_dialogue:
            # Fast path — same as single-voice synthesis
            if len(text) > 5000:
                return self.generate_speech_chunked(
                    text=text,
                    voice_id=narrator_voice_id,
                    stability=stability,
                    similarity_boost=similarity_boost,
                    style=style,
                    model_id=model_id,
                )
            return self.generate_speech(
                text=text,
                voice_id=narrator_voice_id,
                stability=stability,
                similarity_boost=similarity_boost,
                style=style,
                model_id=model_id,
            )

        silence = _make_silence_mp3(inter_segment_pause_ms)
        combined = io.BytesIO()
        logger.info(
            "Dialogue synthesis: %d segments, narrator=%s character=%s",
            len(segments),
            narrator_voice_id,
            character_voice_id,
        )

        for i, (seg_text, seg_type) in enumerate(segments):
            if i > 0 and silence:
                combined.write(silence)

            voice = narrator_voice_id if seg_type == "narration" else character_voice_id

            if len(seg_text) > 4500:
                audio = self.generate_speech_chunked(
                    text=seg_text,
                    voice_id=voice,
                    stability=stability,
                    similarity_boost=similarity_boost,
                    style=style,
                    model_id=model_id,
                )
            else:
                audio = self.generate_speech(
                    text=seg_text,
                    voice_id=voice,
                    stability=stability,
                    similarity_boost=similarity_boost,
                    style=style,
                    model_id=model_id,
                )
            combined.write(audio)

            if i < len(segments) - 1:
                time.sleep(0.1)

        return combined.getvalue()

    @staticmethod
    def _chars_to_word_timestamps(
        characters: list,
        char_start_times: list,
        char_end_times: list,
    ) -> List[dict]:
        """
        Convert ElevenLabs character-level alignment into word-level timestamps.

        Returns a list of {start_ms, end_ms} dicts, one per word, parallel to
        the tokenised word list on the Flutter side.
        """
        word_timestamps: List[dict] = []
        word_start: Optional[float] = None
        word_end: Optional[float] = None
        in_word = False

        for char, start, end in zip(characters, char_start_times, char_end_times):
            is_space = char in (" ", "\n", "\t", "\r")
            if is_space:
                if in_word:
                    word_timestamps.append(
                        {
                            "start_ms": int(word_start * 1000),
                            "end_ms": int(word_end * 1000),
                        }
                    )
                    word_start = None
                    word_end = None
                    in_word = False
            else:
                if not in_word:
                    word_start = start
                    in_word = True
                word_end = end

        if in_word and word_start is not None:
            word_timestamps.append(
                {"start_ms": int(word_start * 1000), "end_ms": int(word_end * 1000)}
            )

        return word_timestamps

    def generate_speech_with_timestamps(
        self,
        text: str,
        voice_id: str = DEFAULT_VOICE_ID,
        stability: float = 0.35,
        similarity_boost: float = 0.80,
        style: float = 0.50,
        model_id: str = DEFAULT_MODEL,
        speed: float = 1.0,
    ) -> Tuple[bytes, List[dict]]:
        """
        Generate MP3 audio with word-level timestamps for synchronized highlighting.

        Uses the ElevenLabs with-timestamps endpoint to obtain character-level
        alignment, then converts it to per-word start/end times in milliseconds.

        Args:
            speed: Speaking rate multiplier (0.7–1.2). Values below 1.0 slow the
                   voice down — use ~0.85 for Sprout/young-child narration.

        Returns:
            (audio_bytes, word_timestamps) where word_timestamps is a list of
            {start_ms: int, end_ms: int} dicts, one per word, in order.
            Falls back to (generate_speech(...), []) if timestamps unavailable.
        """
        cleaned = clean_text_for_tts(text)
        # Build VoiceSettings; speed is a newer field so pass it defensively.
        vs_kwargs = dict(
            stability=stability,
            similarity_boost=similarity_boost,
            style=style,
            use_speaker_boost=True,
        )
        if speed != 1.0:
            vs_kwargs["speed"] = speed
        try:
            voice_settings = VoiceSettings(**vs_kwargs)
        except TypeError:
            vs_kwargs.pop("speed", None)
            voice_settings = VoiceSettings(**vs_kwargs)

        try:
            response = self.client.text_to_speech.convert_with_timestamps(
                voice_id=voice_id,
                text=cleaned,
                model_id=model_id,
                voice_settings=voice_settings,
                output_format="mp3_44100_128",
            )
            audio_bytes = base64.b64decode(response.audio_base_64)
            alignment = response.alignment
            word_timestamps = self._chars_to_word_timestamps(
                characters=alignment.characters,
                char_start_times=alignment.character_start_times_seconds,
                char_end_times=alignment.character_end_times_seconds,
            )
            logger.info(
                "with-timestamps: %d words for %d chars",
                len(word_timestamps),
                len(cleaned),
            )
            return audio_bytes, word_timestamps
        except Exception as e:
            if _is_quota_exceeded(e):
                raise
            logger.warning("with-timestamps failed, falling back: %s", e)
            audio_bytes = self.generate_speech(
                text=text,
                voice_id=voice_id,
                stability=stability,
                similarity_boost=similarity_boost,
                style=style,
                model_id=model_id,
                speed=speed,
            )
            return audio_bytes, []

    @staticmethod
    def get_available_voices() -> List[dict]:
        return CURATED_VOICES


class MockElevenLabsTTSService:
    """Mock service for testing — returns empty bytes without calling API."""

    def generate_speech(self, text: str, **kwargs) -> bytes:
        logger.info("[MockElevenLabsTTS] Would generate speech for %d chars", len(text))
        return b""

    def generate_speech_chunked(self, text: str, **kwargs) -> bytes:
        logger.info(
            "[MockElevenLabsTTS] Would generate chunked speech for %d chars", len(text)
        )
        return b""

    def generate_speech_with_dialogue(self, text: str, **kwargs) -> bytes:
        logger.info(
            "[MockElevenLabsTTS] Would generate dialogue speech for %d chars", len(text)
        )
        return b""

    @staticmethod
    def get_available_voices() -> List[dict]:
        return CURATED_VOICES
