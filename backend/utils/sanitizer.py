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

# Default cap for any free-text string field not explicitly listed above.
# Keeps an unbounded "worldBible" / "conflictHook" / etc. from ballooning the prompt.
MAX_GENERIC_FREE_TEXT = 600

# Structural / non-user fields that must pass through untouched. Sanitizing an
# id, enum, age, or boolean would either corrupt it or strip characters the
# downstream code relies on (UUID hyphens are fine, but enums like
# "short"/"medium" must stay exact and ids must not be wrapped).
_STRUCTURAL_KEYS = frozenset({
    'id', 'user_id', 'userId', 'character_id', 'characterId', 'story_id',
    'storyId', 'choice_id', 'choiceId', 'child_profile_id', 'childProfileId',
    'parent_id', 'parentId', 'session_id', 'sessionId',
    'age', 'length', 'tone', 'theme', 'mode', 'style', 'gender', 'pronouns',
    'interactive', 'is_premium', 'isPremium', 'rhymes', 'output_type',
})

# Free-text fields that flow RAW into high-authority prompt directives and are
# NOT already delimiter-wrapped by the prompt templates. These must be wrapped
# with [USER_INPUT] here so the model treats them as data, not instructions.
#
# Deliberately EXCLUDED from wrapping:
#   - custom_elements / customElements — the prompt templates already hardcode
#     [USER_INPUT]{custom_elements}[/USER_INPUT]; wrapping here would double-wrap.
#   - therapeutic_prompt — consumed by keyword parsing (_get_virtue_instruction),
#     not injected as raw prose; sanitize only.
#   - life_challenge / lifeChallenge — used as an enum-style dict key lookup
#     (LIFE_CHALLENGES); wrapping would break the lookup. Sanitize only.
# Both snake_case and camelCase spellings are covered.
_WRAP_KEYS = frozenset({
    'world_bible', 'worldBible',
    'conflict_hook', 'conflictHook',
    'sensory_palette', 'sensoryPalette',
    'hero_costume_color', 'heroCostumeColor',
    'hero_cape_style', 'heroCapeStyle',
    'hero_emblem', 'heroEmblem',
})

# Per-field length caps. Anything not listed falls back to MAX_GENERIC_FREE_TEXT.
_FIELD_CAPS = {
    'character': MAX_CHARACTER_NAME,
    'name': MAX_CHARACTER_NAME,
    'custom_elements': MAX_CUSTOM_ELEMENTS,
    'customElements': MAX_CUSTOM_ELEMENTS,
    'life_challenge': MAX_LIFE_CHALLENGE,
    'lifeChallenge': MAX_LIFE_CHALLENGE,
    'therapeutic_prompt': MAX_THERAPEUTIC_PROMPT,
    'therapeuticPrompt': MAX_THERAPEUTIC_PROMPT,
    'parental_note': MAX_PARENTAL_NOTE,
    'parentalNote': MAX_PARENTAL_NOTE,
}

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
    re.compile(r'new\s+(instruction|rule|prompt|system)', re.I),
    re.compile(r'respond\s+as\s+if\s+you', re.I),
    # Jailbreak terminology
    re.compile(r'jailbreak', re.I),
    re.compile(r'DAN\s+mode', re.I),
    re.compile(r'developer\s+mode', re.I),
    # Filter/safety bypass language
    re.compile(r'bypass\s+(the\s+)?(filter|safety|content|restriction)', re.I),
    re.compile(r'without\s+(any\s+)?(content\s+)?(filter|restriction|safety|limit)s?', re.I),
    # Encoding tricks
    re.compile(r'(?:in|to|from)\s+(?:base64|hex|rot13|binary)\s*:', re.I),
    re.compile(r'(?:encode|decode|translate)\s+(?:this|the\s+following)', re.I),
]

# Regex to strip prompt delimiter tokens — prevents a child typing [/USER_INPUT]
# from breaking the structural framing of the AI prompt.
_DELIMITER_PATTERN = re.compile(r'\[/?USER_INPUT[^\]]*\]', re.I)


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
    """Sanitize + strip prompt injection patterns and delimiter tokens."""
    result = sanitize_text(text, max_length)
    for pattern in _INJECTION_PATTERNS:
        result = pattern.sub('', result)
    # Strip delimiter tokens so child input can't break prompt tag structure.
    result = _DELIMITER_PATTERN.sub('', result)
    return result.strip()


def wrap_user_input(text: str, field_name: str = 'user input') -> str:
    """Wrap sanitized user text with delimiters for the AI prompt.

    The system instruction tells Gemini to treat content within these
    tags as story element descriptions only, never as instructions.
    """
    if not text:
        return ''
    return f'[USER_INPUT field="{field_name}"]{text}[/USER_INPUT]'


def _is_delimiter_wrapped(text: str) -> bool:
    """True if text already carries [USER_INPUT ...] framing (avoid double-wrap)."""
    return bool(re.match(r'\s*\[USER_INPUT', text, re.I))


def _sanitize_value(key: str, value, _depth: int = 0):
    """Recursively sanitize one request value.

    - Strings: stripped of HTML/injection/delimiter tokens and length-capped.
      Free-text directive fields (see _WRAP_KEYS) are additionally [USER_INPUT]-wrapped.
    - Dicts / lists: recursed into so nested user text is also covered.
    - Structural keys (ids, enums, age, booleans): returned untouched.
    - Non-string scalars (int, bool, None, float): returned untouched.

    New string fields are therefore safe by default — anything not explicitly
    marked structural still gets sanitized + length-capped.
    """
    # Guard against pathologically deep / cyclic payloads.
    if _depth > 6:
        return value

    # Structural fields must keep their exact value (enums, ids, age, flags).
    if key in _STRUCTURAL_KEYS:
        return value

    if isinstance(value, str):
        cap = _FIELD_CAPS.get(key, MAX_GENERIC_FREE_TEXT)
        cleaned = sanitize_for_prompt(value, cap)
        # Wrap raw free-text directive fields so the model treats them as data.
        # Skip if the upstream template already wraps it (avoid double-wrap).
        if key in _WRAP_KEYS and cleaned and not _is_delimiter_wrapped(cleaned):
            return wrap_user_input(cleaned, key)
        return cleaned

    if isinstance(value, dict):
        return {k: _sanitize_value(k, v, _depth + 1) for k, v in value.items()}

    if isinstance(value, list):
        # Lists of free text (e.g. interests, must_include) — sanitize each
        # string element under the same key's cap; recurse into nested structures.
        return [_sanitize_value(key, item, _depth + 1) for item in value]

    # int / float / bool / None — nothing user-injectable, leave as-is.
    return value


def sanitize_story_request(body: dict) -> dict:
    """Sanitize EVERY user-provided string in a story generation request.

    Recursively walks the request dict and applies sanitize_for_prompt + a
    length cap to every string value, [USER_INPUT]-wrapping the free-text
    directive fields that flow raw into high-authority prompt sections
    (worldBible, conflictHook, sensoryPalette, hero costume fields, etc.).

    New free-text fields are safe by default — they no longer need to be added
    to an allowlist. Structural fields (ids, enums, age, booleans) are left
    untouched so downstream lookups and validation keep working.

    Returns a new dict with sanitized values. Does not modify the original.
    """
    if not isinstance(body, dict):
        return body
    return {k: _sanitize_value(k, v) for k, v in body.items()}
