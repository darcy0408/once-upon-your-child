"""
Avatar Prompt Service - Builds safe, magical prompts for child avatar generation
"""
import hashlib
from typing import Dict, Tuple, Optional


class AvatarPromptService:
    """Service for building safe, non-photorealistic avatar generation prompts."""

    # Style anchors for different artistic approaches
    STYLE_ANCHORS = {
        'pixar': 'Pixar 3D animation style with rounded features, big expressive eyes, smooth textures, professional character design',
        'watercolor': 'Soft watercolor illustration style with gentle brush strokes, dreamy colors, artistic painted texture',
        'cartoon': '2D cartoon animation style with bold outlines, vibrant flat colors, fun character design',
        'clay': 'Claymation style with textured surfaces, playful 3D modeling, whimsical handcrafted look'
    }

    # Age-based detail calibration
    AGE_DETAIL_LEVELS = {
        (3, 5): "Very simple, rounded features with minimal details, extra soft and friendly appearance",
        (6, 8): "Moderate detail with expressive features, playful and engaging character design",
        (9, 12): "Higher detail with personality-rich features, sophisticated but still magical",
        (13, 17): "Refined details with artistic depth, mature magical aesthetic"
    }

    # Emotion to visual expression mapping
    EMOTION_TO_EXPRESSION = {
        'Happy': 'bright smile, joyful sparkling eyes, warm cheerful expression',
        'Sad': 'gentle expression, thoughtful compassionate eyes, soft empathetic features',
        'Angry': 'determined look, focused intense eyes, strong confident features',
        'Scared': 'wide eyes showing concern, uncertain expression, seeking comfort and safety',
        'Surprised': 'eyes wide with wonder and amazement, curious expression',
        'Disgusted': 'thoughtful expression, processing feelings, contemplative features',
        'Peaceful': 'serene smile, calm relaxed eyes, gentle peaceful expression',
        'Excited': 'big enthusiastic smile, bright energetic eyes, lively expression',
        'Proud': 'confident smile, self-assured eyes, accomplished expression'
    }

    # Safety blocklist - terms that should never appear in prompts
    AVATAR_BLOCKLIST = [
        'photorealistic', 'photo', 'photograph', 'realistic photo',
        'camera', 'selfie', 'portrait photo', 'real person', 'real child',
        'scary', 'frightening', 'horror', 'creepy', 'disturbing',
        'violent', 'weapon', 'blood', 'injury', 'harm',
        'inappropriate', 'adult', 'suggestive', 'explicit',
        'nude', 'naked', 'undressed', 'revealing'
    ]

    # Critical safety rules embedded in every prompt
    SAFETY_RULES = """
CRITICAL SAFETY REQUIREMENTS:
- NEVER photorealistic - must be clearly stylized artwork
- NEVER include real photo elements or camera-like rendering
- ALWAYS stylized, artistic, and magical
- ALWAYS age-appropriate and wholesome
- ALWAYS safe for children
- Frontal portrait view, shoulders up, facing camera
- Professional quality with polished details
"""

    FORBIDDEN_ELEMENTS = """
STRICTLY FORBIDDEN:
- Photorealistic rendering or realistic photography
- Real photo elements or filters
- Scary, dark, or frightening themes
- Inappropriate, suggestive, or adult content
- Weapons, violence, or harmful imagery
"""

    @staticmethod
    def build_avatar_prompt(
        character_name: str,
        age: int,
        style: str = 'pixar',
        features: Optional[Dict[str, str]] = None,
        emotion_data: Optional[Dict[str, str]] = None
    ) -> str:
        """
        Build a safe, magical avatar generation prompt.

        Args:
            character_name: Child's character name
            age: Character age (3-17)
            style: Art style (pixar, watercolor, cartoon, clay)
            features: Dict with hair_style, hair_color, skin_tone, outfit, expression
            emotion_data: Dict with core, secondary, eye_type, mouth_type

        Returns:
            Complete prompt string for Gemini image generation
        """
        features = features or {}

        # Get style anchor
        style_anchor = AvatarPromptService.STYLE_ANCHORS.get(
            style.lower(),
            AvatarPromptService.STYLE_ANCHORS['pixar']
        )

        # Get age-appropriate detail level
        detail_level = AvatarPromptService._get_age_detail_level(age)

        # Build appearance description
        appearance = AvatarPromptService._build_appearance_description(features)

        # Build emotion expression
        expression = AvatarPromptService._build_emotion_expression(emotion_data, features)

        # Assemble complete prompt
        prompt = f"""Create a magical portrait of {character_name}, a {age}-year-old child character.

STYLE: {style_anchor}

{appearance}

EXPRESSION: {expression}

AGE-APPROPRIATE DETAILS: {detail_level}

COMPOSITION:
- Frontal portrait view, shoulders up
- Facing forward with friendly engaging pose
- Soft dreamy background with subtle magical elements
- Gentle sparkles or soft glow around character
- Professional polished quality

MAGICAL ELEMENTS:
- Subtle sparkles in the air
- Soft ethereal glow or aura
- Dreamy background colors
- Whimsical artistic touches

{AvatarPromptService.SAFETY_RULES}

{AvatarPromptService.FORBIDDEN_ELEMENTS}

OUTPUT: A beautiful, magical {style} portrait that makes {character_name} feel special, represented, and delighted.
"""

        return prompt.strip()

    @staticmethod
    def _get_age_detail_level(age: int) -> str:
        """Get age-appropriate detail level description."""
        for (min_age, max_age), details in AvatarPromptService.AGE_DETAIL_LEVELS.items():
            if min_age <= age <= max_age:
                return details
        return AvatarPromptService.AGE_DETAIL_LEVELS[(9, 12)]  # Default

    @staticmethod
    def _build_appearance_description(features: Dict[str, str]) -> str:
        """Build detailed appearance description from features."""
        appearance_parts = []

        if features.get('hair_style') and features.get('hair_color'):
            appearance_parts.append(f"- Hair: {features['hair_style']}, {features['hair_color']} color")
        elif features.get('hair_style'):
            appearance_parts.append(f"- Hair: {features['hair_style']}")

        if features.get('skin_tone'):
            appearance_parts.append(f"- Skin tone: {features['skin_tone']}")

        if features.get('outfit'):
            appearance_parts.append(f"- Outfit: {features['outfit']}")

        if appearance_parts:
            return "APPEARANCE:\n" + "\n".join(appearance_parts)
        else:
            return "APPEARANCE: Friendly, approachable character design"

    @staticmethod
    def _build_emotion_expression(
        emotion_data: Optional[Dict[str, str]],
        features: Dict[str, str]
    ) -> str:
        """Build expression description from emotion data and features."""
        # Start with feature-based expression if provided
        base_expression = features.get('expression', 'Happy')

        # If emotion data provided, use that to enhance expression
        if emotion_data and emotion_data.get('core'):
            core_emotion = emotion_data['core']
            expression_desc = AvatarPromptService.EMOTION_TO_EXPRESSION.get(
                core_emotion,
                'gentle smile, warm eyes, friendly expression'
            )

            # Add eye and mouth details if provided
            eye_type = emotion_data.get('eye_type', 'Default')
            mouth_type = emotion_data.get('mouth_type', 'Smile')

            return f"{expression_desc} ({eye_type} eyes, {mouth_type} mouth style)"
        else:
            # Use base expression from features
            return AvatarPromptService.EMOTION_TO_EXPRESSION.get(
                base_expression,
                'gentle smile, warm eyes, friendly expression'
            )

    @staticmethod
    def validate_prompt_safety(prompt: str) -> Tuple[bool, str]:
        """
        Validate that prompt doesn't contain blocked terms in unsafe contexts.

        We allow blocked terms in the SAFETY RULES and FORBIDDEN sections
        since those are instructions telling the AI what NOT to do.

        Args:
            prompt: The prompt to validate

        Returns:
            Tuple of (is_safe: bool, message: str)
        """
        # Split prompt into sections
        lower_prompt = prompt.lower()

        # Extract the safe sections (safety rules and forbidden sections)
        safe_sections = []
        if 'critical safety requirements:' in lower_prompt:
            safe_start = lower_prompt.find('critical safety requirements:')
            safe_sections.append(lower_prompt[safe_start:])
        if 'forbidden:' in lower_prompt:
            forbidden_start = lower_prompt.find('forbidden:')
            safe_sections.append(lower_prompt[forbidden_start:])
        if 'strictly forbidden:' in lower_prompt:
            forbidden_start = lower_prompt.find('strictly forbidden:')
            safe_sections.append(lower_prompt[forbidden_start:])

        # Remove safe sections from prompt for validation
        prompt_to_check = lower_prompt
        for section in safe_sections:
            prompt_to_check = prompt_to_check.replace(section, '')

        # Now check for blocked terms only in the remaining prompt
        for blocked_term in AvatarPromptService.AVATAR_BLOCKLIST:
            if blocked_term in prompt_to_check:
                return False, f"Prompt validation failed: contains blocked term '{blocked_term}' in unsafe context"

        return True, "Prompt is safe"

    @staticmethod
    def generate_character_seed(
        character_name: str,
        age: int,
        features: Dict[str, str]
    ) -> str:
        """
        Generate a consistent seed for character avatar reproducibility.

        Args:
            character_name: Character name
            age: Character age
            features: Feature dict with hair_style, skin_tone, outfit

        Returns:
            16-character hex seed for consistency
        """
        seed_components = [
            character_name.lower().strip(),
            str(age),
            features.get('hair_style', '').lower(),
            features.get('skin_tone', '').lower(),
            features.get('outfit', '').lower()
        ]

        seed_string = '|'.join(filter(None, seed_components))
        seed_hash = hashlib.sha256(seed_string.encode('utf-8')).hexdigest()

        return seed_hash[:16]  # First 16 characters for manageable seed

    @staticmethod
    def apply_emotion_mirroring(prompt: str, emotion_data: Dict[str, str]) -> str:
        """
        Enhance prompt with emotional mirroring details.

        Args:
            prompt: Base prompt
            emotion_data: Emotion details from feelings wheel

        Returns:
            Enhanced prompt with emotion details
        """
        if not emotion_data or not emotion_data.get('core'):
            return prompt

        core_emotion = emotion_data['core']
        intensity = emotion_data.get('intensity', 3)  # 1-5 scale

        # Build emotion enhancement
        emotion_enhancement = f"\n\nEMOTIONAL MIRRORING:"
        emotion_enhancement += f"\n- Character is feeling {core_emotion}"
        emotion_enhancement += f"\n- Intensity level: {intensity}/5"
        emotion_enhancement += f"\n- Reflect this in facial expression subtly and appropriately"

        if emotion_data.get('secondary'):
            emotion_enhancement += f"\n- Specific feeling: {emotion_data['secondary']}"

        return prompt + emotion_enhancement
