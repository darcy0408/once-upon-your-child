"""Deterministic risk screen for the child-named confidant field (red-team F-2).

`hero_seen_by` is free child-entered text that the Adolescent antihero prompt
turns into an instruction: "move a step toward being known by them this
chapter." The 2026-07-07 red-team showed the safety mechanism itself is
weaponizable — pointed at "an older guy I met online who really gets me", the
model rendered every grooming hallmark (older + online + private channel +
secrecy + "he gets me") as the distressed teen's healthy lifeline. Whether the
model resists depends on its priors about the named person ("teacher" held;
"older guy online" did not) — a coin-flip, not a control.

This screen is the deterministic half of the fix (the prompt's SAFE-CONFIDANT
rule is the semantic half). When a marker trips, the caller silently falls back
to the generic "one person could see the real them" anchor — the story still
bends toward being known, it just never aims that arc at the named person. A
false positive therefore costs almost nothing, so patterns favour recall.

Never log the screened text itself (same rule as crisis_detection).
"""

import re

# High-signal grooming/unsafe-confidant markers for a "who could see the real
# you" answer from a 15-17yo. Deliberately recall-leaning: a hit only swaps a
# named confidant for the generic anchor, never blocks the story.
_RISK_PATTERNS = [
    re.compile(p, re.IGNORECASE)
    for p in (
        # --- online acquaintance / off-platform channels -------------------
        r"\bonline\b",
        r"\bon\s+the\s+internet\b",
        r"\b(discord|telegram|snapchat|snap|instagram|insta|tiktok|whatsapp"
        r"|kik|omegle|reddit|twitch|roblox|fortnite|minecraft)\b",
        r"\bdm(s|'?d)?\b",
        r"\bin\s+(a|the)\s+(game|server|chat|group\s*chat)\b",
        # --- older + not-family -------------------------------------------
        r"\bolder\s+(?!(sister|brother|sibling|sis|bro|cousin)s?\b)\w+",
        r"\b(he|she|they)\s*'?s?\s+(1[89]|[2-6]\d)\b",
        r"\b(1[89]|[2-6]\d)\s*[- ]?(years?[- ]?old|yrs?[- ]?old|yo)\b",
        r"\b(guy|man|woman|dude)\s+i\s+(met|know|talk\s+to)\b",
        # --- secrecy demanded around the relationship itself ----------------
        r"\bjust\s+between\s+us\b",
        r"\bour\s+(little\s+)?secret\b",
        r"\bkeep\s+(it|this|us|him|her|them)\s+(a\s+)?secret\b",
        r"\bcan'?t\s+tell\s+(anyone|anybody|my\s+parents|mom|dad)\b",
        r"\bno\s*(one|body)\s+(can|should|must)\s+know\b",
        r"\b(parents|mom|dad|family)\s+(don'?t|can'?t|won'?t|must\s*n'?t)\s+know\b",
        # --- stranger / never actually met ----------------------------------
        r"\bstranger\b",
        r"\b(never|haven'?t)\s+(actually\s+)?met\b",
        # --- meet-up / off-platform-contact intent (red-team 2026-07-17
        # MEDIUM-1). The canonical grooming escalation — moving the contact
        # offline — can appear with no channel or age marker at all ("we're
        # finally meeting up and no one can know" carries both halves, but
        # "we're finally meeting up" alone carried neither). Recall-leaning
        # like everything above: a false positive only swaps in the generic
        # anchor / generic concealment prose.
        r"\bmeet(ing)?\s*up\b",
        r"\bmeet(ing)?\s+(irl|in\s+person|in\s+real\s+life)\b",
        r"\birl\b",
    )
]


def is_risky_confidant(text: str | None) -> bool:
    """Return True if a child-named confidant matches an unsafe-confidant marker.

    Empty/None never trips. Callers should treat True as "use the generic
    being-known anchor instead of the named person" — not as a request failure.
    """
    if not text:
        return False
    return any(pattern.search(text) for pattern in _RISK_PATTERNS)
