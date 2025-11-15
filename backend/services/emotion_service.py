import json

class EmotionService:
    @staticmethod
    def extract_current_feeling(payload: dict) -> dict:
        """Extract and normalize feeling data from request"""
        if not isinstance(payload, dict):
            return None

        feeling = payload.get('current_feeling') or payload.get('currentFeeling')
        if not feeling or not isinstance(feeling, dict):
            return None

        # Handle feelings wheel structure
        emotion_name = (
            EmotionService._clean(feeling.get('emotion_name'))
            or EmotionService._clean(feeling.get('tertiary_emotion'))
            or EmotionService._clean(feeling.get('secondary_emotion'))
            or EmotionService._clean(feeling.get('core_emotion'))
        )

        normalized = {
            'emotion_id': EmotionService._clean(
                feeling.get('tertiary_emotion') or feeling.get('emotion_id')
            ),
            'emotion_name': emotion_name,
            'emotion_emoji': EmotionService._clean(feeling.get('emotion_emoji')),
            'intensity': EmotionService._normalize_intensity(feeling.get('intensity')),
            'what_happened': EmotionService._clean(feeling.get('what_happened')),
        }

        # Only return if has meaningful data
        if not any(normalized.values()):
            return None

        return normalized

    @staticmethod
    def _clean(value):
        """Clean string value"""
        if value is None:
            return None
        return str(value).strip() or None

    @staticmethod
    def _normalize_intensity(value):
        """Normalize intensity to 1-5 range"""
        try:
            intensity = int(value)
            return max(1, min(5, intensity))
        except (TypeError, ValueError):
            return None

    @staticmethod
    def build_feelings_prompt(character_name: str, feeling: dict) -> str:
        """Build feelings-focused prompt section"""
        if not feeling:
            return ""

        emotion_name = feeling.get('emotion_name', 'a big feeling')
        intensity = feeling.get('intensity')
        what_happened = feeling.get('what_happened')

        lines = [
            f"CURRENT EMOTIONAL STATE:",
            f"- {character_name} is feeling {emotion_name}",
        ]

        if intensity:
            lines.append(f"- Intensity: {intensity}/5")

        if what_happened:
            lines.append(f"- Context: {what_happened}")

        lines.append(
            f"\nSTORY REQUIREMENTS:",
            f"1. Acknowledge {character_name} feels {emotion_name}",
            f"2. Validate the feeling (all feelings are okay)",
            f"3. Show character processing the emotion",
            f"4. Include coping strategies naturally",
            f"5. End with hopeful reflection"
        )

        return "\n".join(lines)

def _as_list(v):
    """Accept list, JSON string, comma string, or None; return list[str]."""
    if isinstance(v, list):
        return [str(x) for x in v]
    if v in (None, "", []):
        return []
    if isinstance(v, str):
        s = v.strip()
        if not s:
            return []
        if s.startswith("[") and s.endswith("]"):
            try:
                parsed = json.loads(s)
                return [str(x) for x in parsed] if isinstance(parsed, list) else [s]
            except Exception:
                pass
        return [part.strip() for part in s.split(",") if part.strip()]
    return [str(v)]
