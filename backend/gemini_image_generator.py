"""
Gemini Image Generation Service
Uses Google's Gemini 1.5 Pro via the Gemini API
"""

import os
import google.generativeai as genai
from PIL import Image
import io
import base64
import uuid
from datetime import datetime

class GeminiImageGenerator:
    def __init__(self, api_key=None):
        """Initialize with Gemini API key"""
        self.api_key = api_key or os.getenv("GEMINI_API_KEY")
        if self.api_key:
            genai.configure(api_key=self.api_key)

        # Use a Gemini 1.5 Pro model for multimodal capabilities
        self.image_model = genai.GenerativeModel("gemini-1.5-pro-latest")

    def _process_image_response(self, response, prompt) -> list:
        """Helper to process the response from generate_content and extract images."""
        images = []
        if response.candidates:
            for i, candidate in enumerate(response.candidates):
                for part in candidate.content.parts:
                    if part.mime_type and part.mime_type.startswith('image/'):
                        image_data = part.inline_data.data
                        images.append({
                            'id': f"{uuid.uuid4()}_{i}",
                            'prompt': prompt,
                            'image_data': base64.b64encode(image_data).decode('utf-8'),
                            'format': 'png',
                            'generated_at': datetime.now().isoformat(),
                        })
        return images

    def generate_story_illustration(
        self,
        scene_description: str,
        character_name: str = "the hero",
        style: str = "children's book illustration",
        num_images: int = 1,
        age: int = 7,
        therapeutic_focus: str | None = None
    ) -> list:
        """
        Generate therapeutic story illustrations using Gemini 1.5 Pro.
        """
        # Determine detail level based on age
        if age <= 5:
            detail_level = "simple, bold shapes with minimal details, cartoonish and fun"
            age_descriptor = "young children (ages 3-5)"
        elif age <= 11:
            detail_level = "balanced details with fun elements, engaging and colorful"
            age_descriptor = "children (ages 6-11)"
        elif age <= 17:
            detail_level = "intricate artwork with rich details, sophisticated and relatable for teens"
            age_descriptor = "teenagers (ages 12-17)"
        else:
            detail_level = "sophisticated, nuanced artwork with depth and symbolism, suitable for adult reflection"
            age_descriptor = "adults (18+)"

        # Build therapeutic context
        therapeutic_context = ""
        if therapeutic_focus:
            therapeutic_context = f"\nTherapeutic focus: Emphasize {therapeutic_focus} through positive, empowering imagery"

        prompt = f"""
Create {num_images} vibrant, engaging {style} that depicts this scene from a therapeutic story.

Scene: {scene_description}
Main character: {character_name}
Target audience: {age_descriptor} (person is {age} years old)
Detail level: {detail_level}{therapeutic_context}

Visual requirements:
- Full color, vibrant and appealing
- Positive, uplifting emotional tone
- Show characters in action, expressing emotions appropriately
- Include diverse, inclusive representations
- Age-appropriate content for {age_descriptor}
- Dynamic composition with balanced elements
- Professional illustration quality
- No text or words in the image
- Therapeutic value: promote emotional expression, growth, and positivity
- Respectful, safe, and appropriate for the intended age group

Style: {style}, optimized for {age_descriptor}
"""

        try:
            # Generate images with Gemini
            response = self.image_model.generate_content(prompt)
            return self._process_image_response(response, prompt)
        except Exception as e:
            print(f"Error generating image with Gemini: {e}")
            return []

    def generate_coloring_page(
        self,
        scene_description: str,
        character_name: str = "the hero",
        num_images: int = 1,
        age: int = 7,
        therapeutic_focus: str | None = None
    ) -> list:
        """
        Generate therapeutic coloring book pages with black and white line art.
        """
        # Determine intricacy based on age
        if age <= 5:
            intricacy = "very simple shapes with large coloring areas, minimal details, easy for small hands"
            line_thickness = "very thick, bold lines"
            age_descriptor = "young children (ages 3-5)"
        elif age <= 11:
            intricacy = "moderate details with interesting elements to color, balanced complexity"
            line_thickness = "medium-thick lines"
            age_descriptor = "children (ages 6-11)"
        elif age <= 17:
            intricacy = "intricate patterns with fine details, sophisticated designs for focused coloring"
            line_thickness = "varied line weights with detail work"
            age_descriptor = "teenagers (ages 12-17)"
        else:
            intricacy = "complex, intricate patterns with fine details, meditative and sophisticated designs"
            line_thickness = "varied line weights with intricate detail work"
            age_descriptor = "adults (18+)"

        # Build therapeutic context
        therapeutic_context = ""
        if therapeutic_focus:
            therapeutic_context = f"\nTherapeutic purpose: Design promotes {therapeutic_focus} through calming, positive imagery"

        prompt = f"""
Create {num_images} therapeutic coloring book page(s) featuring elements from a personalized story.

Story context: {scene_description}
Main character: {character_name}
Target audience: {age_descriptor} (person is {age} years old)
Intricacy level: {intricacy}
Line style: {line_thickness}{therapeutic_context}

Critical requirements:
- BLACK LINE ART ONLY on pure white background
- ABSOLUTELY NO colors, fills, shading, or gray tones
- 100% black outlines for coloring
- Story-relevant elements: characters, settings, key objects from the scene
- {intricacy}
- Balanced composition covering 70%+ of story themes
- High contrast for easy visibility
- Engaging elements tied to the narrative
- Positive, uplifting content only
- Age-appropriate for {age_descriptor}
- Promotes creativity, mindfulness, and emotional processing
- Safe therapeutic content: respectful and appropriate for the intended age
- No text or words in the image
- Printable quality (suitable for app display or printing)

Design style: Clean line art coloring page, therapeutic and story-based, for {age_descriptor}
Output: Pure black lines on white background only
"""

        try:
            # Generate images with Gemini
            response = self.image_model.generate_content(prompt)
            return self._process_image_response(response, prompt)
        except Exception as e:
            print(f"Error generating coloring page with Gemini: {e}")
            return []


# Example usage
if __name__ == "__main__":
    generator = GeminiImageGenerator()

    # Test story illustration
    print("Generating story illustration...")
    illustrations = generator.generate_story_illustration(
        scene_description="A brave 7-year-old girl named Isabella discovers a glowing magic crystal in an enchanted forest",
        character_name="Isabella",
        style="vibrant children's book illustration"
    )

    if illustrations:
        print(f"✓ Generated {len(illustrations)} illustration(s)")
        print(f"  Prompt: {illustrations[0]['prompt'][:100]}...")
    else:
        print("✗ Failed to generate illustration")

    # Test coloring page
    print("\nGenerating coloring page...")
    coloring_pages = generator.generate_coloring_page(
        scene_description="Isabella holding a rainbow-colored magic crystal, surrounded by friendly forest animals",
        character_name="Isabella"
    )

    if coloring_pages:
        print(f"✓ Generated {len(coloring_pages)} coloring page(s)")
    else:
        print("✗ Failed to generate coloring page")