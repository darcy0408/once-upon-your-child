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
    """
    A service for interacting with Google Cloud Text-to-Speech to generate
    high-quality audio narration.
    """
    def __init__(self):
        """
        Initializes the TTSService client.

        Raises:
            ImportError: If Google Cloud Text-to-Speech library is not available.
        """
        if not GOOGLE_TTS_AVAILABLE:
            raise ImportError(
                "Google Cloud Text-to-Speech is not available. "
                "Install it with: pip install google-cloud-texttospeech"
            )
        self.client = texttospeech.TextToSpeechClient()

    def add_natural_pauses(self, text: str) -> str:
        """
        Adds SSML (Speech Synthesis Markup Language) markup to the text
        to create more natural-sounding pauses and emphasis.

        Specifically, it adds breaks after punctuation and moderate emphasis
        to text enclosed in double quotes.

        Args:
            text (str): The input text to which SSML markup will be added.

        Returns:
            str: The text with SSML markup for natural pauses and emphasis.
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
        Generates speech audio from the provided text using Google Cloud Text-to-Speech.

        Args:
            text (str): The story text to be converted to speech.
            voice_name (str): The name of the voice to use (e.g., "en-US-Neural2-F").
            speaking_rate (float): The speed of the speech (0.25 to 4.0).
            pitch (float): The pitch of the speech (-20.0 to 20.0).
            use_ssml (bool): If True, SSML markup will be added for natural pauses and emphasis.
            output_path (str, optional): If provided, the generated audio will be saved to this path.

        Returns:
            bytes: The audio content as bytes (MP3 format).
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
        Retrieves a list of recommended voices suitable for storytelling.

        Each voice entry includes details such as ID, name, gender,
        description, and a recommendation flag.

        Returns:
            List[dict]: A list of dictionaries, each representing an available voice.
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
    """
    A mock Text-to-Speech service for testing purposes.

    This service simulates the behavior of TTSService without actually
    interacting with the Google Cloud TTS API, returning placeholder data.
    """

    def generate_speech(self, text: str, **kwargs) -> bytes:
        """
        Simulates speech generation by returning empty bytes.

        Logs a message indicating that speech would have been generated for the given text.

        Args:
            text (str): The input text for which speech would be generated.
            **kwargs: Additional keyword arguments, ignored in the mock implementation.

        Returns:
            bytes: An empty bytes object, representing no audio content.
        """
        print(f"[MockTTS] Would generate speech for {len(text)} characters")
        return b""  # Empty audio

    @staticmethod
    def get_available_voices() -> List[dict]:
        """
        Returns a predefined list of mock voices, mirroring the structure
        of the real TTSService.

        Returns:
            List[dict]: A list of dictionaries, each representing a mock voice.
        """
        return TTSService.get_available_voices()

    def add_natural_pauses(self, text: str) -> str:
        """
        Mocks the SSML processing by simply wrapping the text in <speak> tags.

        Args:
            text (str): The input text.

        Returns:
            str: The input text wrapped in <speak> tags.
        """
        return f"<speak>{text}</speak>"
