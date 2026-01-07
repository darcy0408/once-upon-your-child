"""Helper to convert avatar parameters to natural language descriptions for AI prompts."""


class AvatarToPromptHelper:
    """Convert avataaars parameters to natural language for story generation."""

    @staticmethod
    def avatar_to_description(avatar_params: dict, age: int, context: str = None) -> str:
        """Convert avataaars parameters to natural language description.

        Args:
            avatar_params: Dict of avataaars parameters (e.g., {'top': 'curly', 'hairColor': 'brown'})
            age: Character age
            context: Optional additional context to append

        Returns:
            Natural language description of the character's appearance
        """
        if not avatar_params:
            return f"{age}-year-old child"

        parts = []

        # Age
        parts.append(f"{age}-year-old child")

        # Skin tone
        if 'skinColor' in avatar_params:
            skin_tone = AvatarToPromptHelper._humanize_skin_color(avatar_params['skinColor'])
            parts.append(f"with {skin_tone} skin")

        # Hair
        if 'top' in avatar_params:
            hair_style = AvatarToPromptHelper._humanize_hair_style(avatar_params['top'])
            hair_color = AvatarToPromptHelper._humanize_color(avatar_params.get('hairColor', 'brown'))
            parts.append(f"{hair_color} {hair_style} hair")

        # Facial features
        if 'eyes' in avatar_params:
            expression = AvatarToPromptHelper._humanize_eyes(avatar_params['eyes'])
            if expression:
                parts.append(f"{expression} eyes")

        # Clothing
        if 'clothing' in avatar_params:
            clothing_item = AvatarToPromptHelper._humanize_clothing(avatar_params['clothing'])
            color = AvatarToPromptHelper._humanize_color(avatar_params.get('clothesColor', ''))
            if color:
                parts.append(f"wearing a {color} {clothing_item}")
            else:
                parts.append(f"wearing a {clothing_item}")

        # Accessories
        if 'accessories' in avatar_params and avatar_params['accessories'] != 'blank':
            accessory = AvatarToPromptHelper._humanize_accessory(avatar_params['accessories'])
            if accessory:
                parts.append(f"wearing {accessory}")

        description = ", ".join(parts)

        if context:
            return f"{description}, {context}"

        return description

    @staticmethod
    def to_story_illustration_prompt(avatar_params: dict, age: int, scene: str, emotion: str) -> str:
        """Generate a story illustration prompt.

        Args:
            avatar_params: Avatar customization parameters
            age: Character age
            scene: Scene description
            emotion: Character emotion/action

        Returns:
            Complete AI image generation prompt
        """
        character_desc = AvatarToPromptHelper.avatar_to_description(avatar_params, age)

        return f"""Generate a children's book illustration:
- Character: {character_desc}
- Scene: {scene}
- Emotion/Action: {emotion}
- Style: Warm, friendly, age-appropriate
- Quality: High detail, colorful, expressive
"""

    @staticmethod
    def to_coloring_page_prompt(avatar_params: dict, age: int, activity: str) -> str:
        """Generate a coloring page prompt.

        Args:
            avatar_params: Avatar customization parameters
            age: Character age
            activity: Activity description

        Returns:
            Complete coloring page generation prompt
        """
        character_desc = AvatarToPromptHelper.avatar_to_description(avatar_params, age)

        return f"""Generate a coloring book page:
- Character: {character_desc}
- Activity: {activity}
- Style: Simple black outlines, white background
- Details: Clear shapes, suitable for children ages {age}-{age+2} to color
- No shading, no complex patterns, thick lines
- Full body illustration
"""

    # Helper methods to convert avataaars values to natural language

    @staticmethod
    def _humanize_skin_color(code: str) -> str:
        """Map skin color codes to descriptions."""
        mapping = {
            'light': 'light',
            'tanned': 'tan',
            'yellow': 'light',
            'pale': 'pale',
            'brown': 'brown',
            'darkBrown': 'dark brown',
            'black': 'dark',
        }
        return mapping.get(code, 'medium')

    @staticmethod
    def _humanize_hair_style(style: str) -> str:
        """Map hair style codes to descriptions."""
        mapping = {
            'curly': 'curly',
            'straight': 'straight',
            'bob': 'bob-cut',
            'bun': 'in a bun',
            'long': 'long',
            'short': 'short',
            'dreads': 'dreadlocks',
            'shaggy': 'shaggy',
            'bigHair': 'voluminous',
            'curvy': 'wavy',
            'frizzle': 'frizzy',
            'fro': 'afro',
            'froBand': 'afro with headband',
            'miaWallace': 'sleek bob',
            'longButNotTooLong': 'shoulder-length',
            'shavedSides': 'shaved sides',
            'straight01': 'straight',
            'straight02': 'straight and sleek',
            'straightAndStrand': 'straight with strands',
            'dreads01': 'long dreadlocks',
            'dreads02': 'short dreadlocks',
            'frida': 'updo with flowers',
            'shaggyMullet': 'shaggy mullet',
            'shortCurly': 'short curly',
            'shortFlat': 'short and flat',
            'shortRound': 'short and round',
            'shortWaved': 'short wavy',
            'sides': 'side-parted',
            'theCaesar': 'caesar cut',
            'theCaesarAndSidePart': 'caesar with side part',
            'winterHat1': 'wearing a winter hat',
            'winterHat2': 'wearing a beanie',
            'winterHat3': 'wearing a knit cap',
            'winterHat4': 'wearing a winter beanie',
            'eyepatch': 'wearing an eyepatch',
            'hat': 'wearing a hat',
            'hijab': 'wearing a hijab',
            'turban': 'wearing a turban',
            'noHair': 'no hair',
        }
        # Fallback: convert camelCase to space-separated lowercase
        return mapping.get(style, style.replace('([A-Z])', r' \1').lower())

    @staticmethod
    def _humanize_eyes(eyes: str) -> str:
        """Map eye codes to descriptions."""
        mapping = {
            'happy': 'happy',
            'default': 'friendly',
            'cry': 'teary',
            'surprised': 'wide surprised',
            'hearts': 'loving',
            'close': 'closed',
            'wink': 'winking',
            'winkWacky': 'playfully winking',
            'squint': 'squinting',
            'side': 'looking to the side',
            'dizzy': 'dizzy',
            'eyeRoll': 'rolling',
            'xDizzy': 'dazed',
        }
        return mapping.get(eyes, '')

    @staticmethod
    def _humanize_clothing(clothing: str) -> str:
        """Map clothing codes to descriptions."""
        mapping = {
            'hoodie': 'hoodie',
            'blazerAndShirt': 'blazer with shirt',
            'blazerAndSweater': 'blazer with sweater',
            'collarAndSweater': 'collared sweater',
            'graphicShirt': 'graphic t-shirt',
            'overall': 'overalls',
            'shirtCrewNeck': 'crew neck shirt',
            'shirtScoopNeck': 'scoop neck shirt',
            'shirtVNeck': 'v-neck shirt',
        }
        return mapping.get(clothing, clothing)

    @staticmethod
    def _humanize_accessory(accessory: str) -> str:
        """Map accessory codes to descriptions."""
        mapping = {
            'prescription01': 'round glasses',
            'prescription02': 'square glasses',
            'round': 'round glasses',
            'sunglasses': 'sunglasses',
            'wayfarers': 'wayfarer sunglasses',
            'kurt': 'headband',
            'blank': '',
        }
        return mapping.get(accessory, accessory)

    @staticmethod
    def _humanize_color(color: str) -> str:
        """Humanize color names."""
        if not color:
            return ''

        # Handle hex colors
        if color.startswith('#'):
            return AvatarToPromptHelper._hex_to_color_name(color)

        # Convert camelCase to space-separated lowercase
        import re
        return re.sub(r'([A-Z])', r' \1', color).lower().strip()

    @staticmethod
    def _hex_to_color_name(hex_code: str) -> str:
        """Map common hex colors to names."""
        mapping = {
            '#000000': 'black',
            '#FFFFFF': 'white',
            '#FF0000': 'red',
            '#00FF00': 'green',
            '#0000FF': 'blue',
            '#FFFF00': 'yellow',
            '#FF00FF': 'magenta',
            '#00FFFF': 'cyan',
            '#FFA500': 'orange',
            '#800080': 'purple',
            '#FFC0CB': 'pink',
            '#A52A2A': 'brown',
            '#808080': 'gray',
        }
        return mapping.get(hex_code.upper(), 'colorful')
