"""
Google Cloud Text-to-Speech Service
Provides high-quality, natural-sounding narration for stories
"""

import os
from typing import Optional, List
import re

# Try to import Google Cloud TTS, but don't fail if it's not available
try:
    from google.cloud import texttospeech
    GOOGLE_TTS_AVAILABLE = True
except ImportError:
    GOOGLE_TTS_AVAILABLE = False
    texttospeech = None  # Placeholder for type hints

class TTSService:
    def __init__(self):
        """Initialize Google Cloud TTS client"""
        if not GOOGLE_TTS_AVAILABLE:
            raise ImportError(
                "Google Cloud Text-to-Speech is not available. "
                "Install it with: pip install google-cloud-texttospeech"
            )
        self.client = texttospeech.TextToSpeechClient()

    def add_natural_pauses(self, text: str) -> str:
        """
        Add SSML markup for natural pauses and emphasis
        Makes the narration sound more human
        """
        # Add longer pause after periods (end of sentences)
        text = re.sub(r'\.(\s+)', '.<break time="800ms"/>\\1', text)

        # Add pause after commas
        text = re.sub(r',(\s+)', ',<break time="400ms"/>\\1', text)

        # Add pause after exclamation/question marks
        text = re.sub(r'!(\s+)', '!<break time="800ms"/>\\1', text)
        text = re.sub(r'\?(\s+)', '?<break time="800ms"/>\\1', text)

        # Add emphasis to dialogue (words in quotes)
        text = re.sub(r'"([^"]+)"', r'<emphasis level="moderate">\1</emphasis>', text)

        # Wrap in SSML speak tags
        ssml = f'<speak>{text}</speak>'
        return ssml

    def generate_speech(
        self,
        text: str,
        voice_name: str = "en-US-Neural2-F",
        speaking_rate: float = 1.0,
        pitch: float = 0.0,
        use_ssml: bool = True,
        output_path: Optional[str] = None
    ) -> bytes:
        """
        Generate speech audio from text

        Args:
            text: The story text to narrate
            voice_name: Google Cloud voice name (e.g., "en-US-Neural2-F" for female)
            speaking_rate: Speed (0.25 to 4.0, default 1.0)
            pitch: Voice pitch (-20.0 to 20.0, default 0.0)
            use_ssml: Whether to add natural pauses and emphasis
            output_path: Optional path to save MP3 file

        Returns:
            Audio content as bytes (MP3 format)
        """
        # Prepare input
        if use_ssml:
            ssml_text = self.add_natural_pauses(text)
            synthesis_input = texttospeech.SynthesisInput(ssml=ssml_text)
        else:
            synthesis_input = texttospeech.SynthesisInput(text=text)

        # Voice configuration
        voice = texttospeech.VoiceSelectionParams(
            language_code="en-US",
            name=voice_name,
        )

        # Audio configuration
        audio_config = texttospeech.AudioConfig(
            audio_encoding=texttospeech.AudioEncoding.MP3,
            speaking_rate=speaking_rate,
            pitch=pitch,
        )

        # Generate speech
        response = self.client.synthesize_speech(
            input=synthesis_input,
            voice=voice,
            audio_config=audio_config,
        )

        # Optionally save to file
        if output_path:
            with open(output_path, "wb") as out:
                out.write(response.audio_content)

        return response.audio_content

    @staticmethod
    def get_available_voices() -> List[dict]:
        """
        Get list of recommended voices for storytelling

        Returns list of voice options with details
        """
        return [
            {
                "id": "en-US-Neural2-F",
                "name": "Warm Female Voice",
                "gender": "female",
                "description": "Friendly and warm, perfect for storytelling",
                "recommended": True,
            },
            {
                "id": "en-US-Neural2-A",
                "name": "Clear Female Voice",
                "gender": "female",
                "description": "Clear and expressive, great for children",
            },
            {
                "id": "en-US-Neural2-C",
                "name": "Gentle Female Voice",
                "gender": "female",
                "description": "Gentle and soothing, ideal for bedtime stories",
            },
            {
                "id": "en-US-Neural2-D",
                "name": "Friendly Male Voice",
                "gender": "male",
                "description": "Friendly and engaging male narrator",
            },
            {
                "id": "en-US-Neural2-J",
                "name": "Energetic Male Voice",
                "gender": "male",
                "description": "Dynamic and energetic, great for adventures",
            },
            {
                "id": "en-GB-Neural2-A",
                "name": "British Female Voice",
                "gender": "female",
                "description": "British accent, elegant storytelling",
            },
            {
                "id": "en-GB-Neural2-B",
                "name": "British Male Voice",
                "gender": "male",
                "description": "British accent, classic narrator style",
            },
            {
                "id": "en-AU-Neural2-A",
                "name": "Australian Female Voice",
                "gender": "female",
                "description": "Australian accent, friendly and upbeat",
            },
        ]


# Mock TTS service for testing without API key
class MockTTSService:
    """Mock service that returns placeholder audio"""

    def generate_speech(self, text: str, **kwargs) -> bytes:
        """Return empty bytes as placeholder"""
        print(f"[MockTTS] Would generate speech for {len(text)} characters")
        return b""  # Empty audio

    @staticmethod
    def get_available_voices() -> List[dict]:
        """Return mock voice list"""
        return TTSService.get_available_voices()

    def add_natural_pauses(self, text: str) -> str:
        """Mock method"""
        return f"<speak>{text}</speak>"
