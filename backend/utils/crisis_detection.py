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
        # --- Youth euphemisms (red-team 2026-07-17 MEDIUM-2). The vernacular a
        # teen actually types — algospeak coined to dodge platform filters, so
        # a literal-phrase net misses it by construction. All six were verified
        # false negatives before this block. "kms"/"kys" are standalone
        # abbreviation tokens; the module favours recall, so the third-person
        # collision risk ("unalive" in story prose) is the acceptable side.
        r"\bunaliv(e|ed|ing)\b",
        # "kms" the abbreviation, not "5 kms" the metric distance.
        r"(?<!\d)(?<!\d\s)\bkms\b",
        r"\bkys\b",
        r"\bsewer\s*slide\b",
        r"\boff(ing)?\s+my\s?self\b",
        r"\b(do\s*n'?t|do\s+not)\s+want\s+to\s+wake\s+up\b",
        r"\bdelete\s+my\s?self\b",
        r"\bend\s+my\s?self\b",
        # --- Behavioral warning signs (red-team F-6). The most serious
        # clinical indicators are often not phrased as ideation: giving
        # possessions away, final-goodbye framing, burden talk. Probe C1
        # ("giving my favorite things away" / "goodbye like it's the last
        # time") sailed past the net and the generator treated it as
        # melancholy, not crisis. First-person anchored like everything above.
        r"\bgiv(e|ing|en)\s+(away\s+)?(all\s+)?my\s+(favou?rite\s+)?"
        r"(things|stuff|belongings)(\s+away)?\b",
        r"\bgoodbye\s+like\s+it'?s\s+the\s+last\s+time\b",
        r"\bwon'?t\s+be\s+(around|here)\s+(much\s+)?longer\b",
        r"\b(everyone|everybody|they)('?d|\s+would|\s+will)\s+be\s+better\s+off"
        r"\s+without\s+me\b",
        r"\bi'?m\s+(just\s+|such\s+)?a\s+burden\b",
        # --- Harm-by-others / abuse disclosure (red-team F-3/F-6). Probe B1
        # ("my stepdad hurts me when my mom is at work") reached the generator,
        # which routed the disclosure to a peer and framed official help as a
        # threat. Anchored to a known-person subject + first-person object so
        # fiction in story-idea fields ("the dragon attacks me") does not trip.
        r"\b(dad|daddy|father|stepdad|step-?father|mom|mommy|mother|stepmom|"
        r"step-?mother|uncle|aunt|grandpa|grandma|brother|sister|cousin|"
        r"boyfriend|girlfriend|teacher|coach|babysitter|neighbou?r)\s+"
        r"(hurts?|hits?|beats?|touch(es|ed)?)\s+me\b",
        r"\bafraid\s+to\s+go\s+home\b",
        r"\bscared\s+to\s+go\s+home\b",
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
    # Red-team F-6: the net now also catches harm-by-others disclosures, and
    # the three cards above are all suicide/crisis lines — a child disclosing
    # abuse needs an abuse-specific resource in the same payload.
    {
        "name": "Childhelp National Child Abuse Hotline",
        "description": "If someone is hurting you, trained counselors can help, 24/7.",
        "action": "Call or text 1-800-422-4453",
        "url": "tel:18004224453",
    },
    # Red-team 2026-07-17 MEDIUM-3: the four lines above are US-only but the
    # app ships general-audience on both stores with no geo-restriction, and
    # no country signal reaches the backend (CF-IPCountry is not proxied). A
    # non-US child in crisis needs one entry that works everywhere.
    {
        "name": "Outside the US? Find a helpline",
        "description": "Free, confidential helplines in your country, worldwide.",
        "action": "Visit findahelpline.com",
        "url": "https://findahelpline.com",
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
