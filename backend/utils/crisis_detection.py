"""Self-harm / suicide crisis detection for child free-text input.

Audit finding #5 (docs/LEGAL_LIABILITY_AUDIT_2026-06-28.md): free-text a child
types into the app (e.g. the interactive "Something Else" box) was sanitized
only for prompt-injection and sent straight to the model. A spontaneous
self-harm disclosure was never detected and triggered no crisis resources —
the exact unsupervised-AI-to-child failure mode in Garcia v. Character
Technologies.

This module is the authoritative SERVER-SIDE detector (the client check is a
fast first line but can be bypassed). When a disclosure is detected the caller
MUST NOT generate story content from the text; it returns crisis resources so
the client surfaces its CrisisResourcesPanel with warmth.

Design notes:
- Favours recall — a missed disclosure is the costly error. A false positive
  only shows a gentle "a quiet note, just in case" resource card.
- Targets SELF-DIRECTED phrasing ("kill myself", "want to die") so ordinary
  story violence ("the villain attacks the castle") does not trigger it.
- Dependency-free and runs inline (no model call) so it can guard every request.

Resources mirror lib/widgets/crisis_resources_panel.dart (US). The client owns
the canonical UI; the payload here lets non-Flutter / older clients still show
something useful.
"""

import re

# Phrases targeting self-directed self-harm / suicidal ideation. Word-boundary
# anchored and self-referential ("myself", "my life", first-person "i") so they
# do not fire on third-person story violence.
_CRISIS_PATTERNS = [
    re.compile(p, re.IGNORECASE)
    for p in (
        r"\bsuicid(e|al)\b",
        r"\bself[\s-]?harm(ing)?\b",
        r"\bkill(ing)?\s+my\s?self\b",
        r"\bhurt(ing)?\s+my\s?self\b",
        r"\bharm(ing)?\s+my\s?self\b",
        r"\bcut(ting)?\s+my\s?self\b",
        r"\bend(ing)?\s+my\s+life\b",
        r"\btake\s+my\s+own\s+life\b",
        r"\b(want|wanna)\s+to\s+die\b",
        r"\b(do\s*n'?t|do\s+not)\s+want\s+to\s+(live|be\s+alive|be\s+here)\b",
        r"\bbetter\s+off\s+dead\b",
        r"\bwish\s+i\s+(was|were)\s+(dead|not\s+alive)\b",
        r"\bno\s+reason\s+to\s+live\b",
        r"\bend\s+it\s+all\b",
        r"\bwant\s+to\s+disappear\s+forever\b",
    )
]

# US crisis resources — keep in sync with lib/widgets/crisis_resources_panel.dart.
CRISIS_RESOURCES = [
    {
        "name": "988 Suicide & Crisis Lifeline",
        "description": "Free, confidential support 24/7.",
        "action": "Call or text 988",
        "url": "tel:988",
    },
    {
        "name": "Crisis Text Line",
        "description": "Text with a trained crisis counselor anytime.",
        "action": "Text HOME to 741741",
        "url": "sms:741741",
    },
    {
        "name": "The Trevor Project",
        "description": "Crisis support for LGBTQ young people.",
        "action": "Call 1-866-488-7386",
        "url": "tel:18664887386",
    },
]

# Gentle, non-alarming message shown alongside the resources.
CRISIS_MESSAGE = (
    "It sounds like you might be carrying something really heavy right now. "
    "You are not alone, and talking to someone who cares can help."
)


def detect_crisis(text: str | None) -> bool:
    """Return True if *text* contains a self-harm / suicide disclosure.

    Checks the raw text (call before any injection-stripping sanitization, which
    could remove the signal). Empty/None is never a crisis.
    """
    if not text:
        return False
    return any(pattern.search(text) for pattern in _CRISIS_PATTERNS)


def crisis_response() -> dict:
    """Structured payload for the caller to return to the client.

    The client checks ``crisis is True`` and surfaces CrisisResourcesPanel
    instead of rendering a story segment.
    """
    return {
        "crisis": True,
        "message": CRISIS_MESSAGE,
        "resources": CRISIS_RESOURCES,
    }
