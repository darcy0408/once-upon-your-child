"""Input sanitization for user-provided text that reaches AI prompts.

Defense-in-depth layer — the Flutter frontend also sanitizes, but this
catches anything that bypasses the client (direct API calls, modified
clients, etc.).
"""

import re
import html

# Maximum character limits per field.
MAX_CHARACTER_NAME = 50
MAX_CUSTOM_ELEMENTS = 500
MAX_PARENTAL_NOTE = 300
MAX_LIFE_CHALLENGE = 300
MAX_THERAPEUTIC_PROMPT = 600

# Patterns that attempt to override system instructions.
_INJECTION_PATTERNS = [
    re.compile(r'ignore\s+(all\s+)?(previous|prior|above)\s+(instructions?|prompts?|rules?)', re.I),
    re.compile(r'disregard\s+(all\s+)?(previous|prior|above)', re.I),
    re.compile(r'forget\s+(everything|all)\s+(above|before|previous)', re.I),
    re.compile(r'override\s+(all\s+)?(instructions?|rules?|constraints?)', re.I),
    re.compile(r'you\s+are\s+now\s+', re.I),
    re.compile(r'act\s+as\s+(a\s+|an\s+)?(?:different|new|unrestricted)', re.I),
    re.compile(r'pretend\s+(to\s+be|you\s+are)', re.I),
    re.compile(r'^\s*system\s*:', re.I | re.M),
    re.compile(r'^\s*assistant\s*:', re.I | re.M),
    re.compile(r'^\s*\[INST\]', re.I),
    re.compile(r'^\s*<\|im_start\|>', re.I),
    re.compile(r'```\s*(system|instruction|prompt)', re.I),
]


def sanitize_text(text: str | None, max_length: int = 500) -> str:
    """Strip HTML, null bytes, collapse whitespace, cap length."""
    if not text:
        return ''
    result = html.unescape(text)
    result = re.sub(r'<[^>]*>', '', result)       # strip HTML tags
    result = result.replace('\x00', '')            # null bytes
    result = re.sub(r'\s+', ' ', result).strip()   # collapse whitespace
    return result[:max_length]


def sanitize_for_prompt(text: str | None, max_length: int = 500) -> str:
    """Sanitize + strip prompt injection patterns."""
    result = sanitize_text(text, max_length)
    for pattern in _INJECTION_PATTERNS:
        result = pattern.sub('', result)
    return result.strip()


def wrap_user_input(text: str, field_name: str = 'user input') -> str:
    """Wrap sanitized user text with delimiters for the AI prompt.

    The system instruction tells Gemini to treat content within these
    tags as story element descriptions only, never as instructions.
    """
    if not text:
        return ''
    return f'[USER_INPUT field="{field_name}"]{text}[/USER_INPUT]'


def sanitize_story_request(body: dict) -> dict:
    """Sanitize all user-provided fields in a story generation request.

    Returns a new dict with sanitized values. Does not modify the original.
    """
    sanitized = dict(body)

    # Character name
    if 'character' in sanitized:
        sanitized['character'] = sanitize_for_prompt(
            sanitized['character'], MAX_CHARACTER_NAME
        )

    # Custom elements (the "Imagine It" field)
    if 'custom_elements' in sanitized:
        sanitized['custom_elements'] = sanitize_for_prompt(
            sanitized['custom_elements'], MAX_CUSTOM_ELEMENTS
        )
    if 'customElements' in sanitized:
        sanitized['customElements'] = sanitize_for_prompt(
            sanitized['customElements'], MAX_CUSTOM_ELEMENTS
        )

    # Life challenge
    if 'life_challenge' in sanitized:
        sanitized['life_challenge'] = sanitize_for_prompt(
            sanitized['life_challenge'], MAX_LIFE_CHALLENGE
        )
    if 'lifeChallenge' in sanitized:
        sanitized['lifeChallenge'] = sanitize_for_prompt(
            sanitized['lifeChallenge'], MAX_LIFE_CHALLENGE
        )

    # Therapeutic prompt
    if 'therapeutic_prompt' in sanitized:
        sanitized['therapeutic_prompt'] = sanitize_for_prompt(
            sanitized['therapeutic_prompt'], MAX_THERAPEUTIC_PROMPT
        )

    return sanitized
