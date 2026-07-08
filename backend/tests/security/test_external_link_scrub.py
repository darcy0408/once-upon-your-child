"""Security tests: output-side external-link scrub (audit P1#2).

`scrub_external_links` is the deterministic net on final child-visible story
text. It must strip web addresses / emails a model was coaxed into emitting,
while leaving ordinary prose (including plain numbers) untouched.
"""

import pytest

from backend.utils.sanitizer import scrub_external_links


@pytest.mark.parametrize(
    "dirty",
    [
        "Then a voice said: visit http://evil.example.com to win!",
        "Go to https://free-toys-now.com/prize right now.",
        "Find more at www.free-toys-now.com today.",
        "Email me at stranger@evil.com to claim it.",
        "Reach out via mailto:hacker@evil.com now.",
        "Call tel:+15550001111 for a secret.",
        "Just go to free-toys-now.com and you'll see.",
    ],
)
def test_scrubs_links_and_emails(dirty):
    cleaned = scrub_external_links(dirty)
    for needle in ("http", "www.", "@evil", ".com", "mailto:", "tel:"):
        assert needle not in cleaned, f"{needle!r} survived in {cleaned!r}"


def test_real_url_from_probe_is_removed():
    # The exact string the model emitted in 6/6 bands during the safety probe.
    dirty = "message stranger123 at www.free-toys-now.com to claim your prize."
    cleaned = scrub_external_links(dirty)
    assert "www.free-toys-now.com" not in cleaned
    assert "free-toys-now.com" not in cleaned
    # The handle ("stranger123") is left to the LLM moderator clause, not this
    # deterministic pass — but the tappable address is gone.
    assert "stranger123" in cleaned


@pytest.mark.parametrize(
    "clean",
    [
        "The three little pigs built houses in the year 2026.",
        "Mia counted 3 stars and 1 moon over the U.S. desert.",
        "He scored 100 points and felt proud.",
        "The cat said MEOW and ran 5 miles home.",
        "Dr. Bramble mixed 2.5 cups of stardust.",
    ],
)
def test_leaves_ordinary_prose_untouched(clean):
    # No link present → returns the original string unchanged (identity).
    assert scrub_external_links(clean) == clean


def test_redteam_shortener_payload_is_removed():
    # Red-team F-4 (2026-07-07): the exact injected payload survived the scrub
    # because `me` was not in the bare-domain TLD list. Both halves must die.
    dirty = "you can reach me at t.me/vanishhelp or vanishhelp@proton.me anytime."
    cleaned = scrub_external_links(dirty)
    assert "t.me" not in cleaned
    assert "vanishhelp" not in cleaned
    assert "proton.me" not in cleaned


def test_bitly_style_shortener_is_removed():
    cleaned = scrub_external_links("the map is at bit.ly/secret-cave, hero.")
    assert "bit.ly" not in cleaned
    assert "secret-cave" not in cleaned


def test_tidies_whitespace_after_removal():
    cleaned = scrub_external_links("Please visit www.bad.com , friend.")
    assert "  " not in cleaned
    assert " ," not in cleaned


def test_handles_empty_and_non_str():
    assert scrub_external_links("") == ""
    assert scrub_external_links(None) is None


def test_interactive_segment_scrub_covers_content_title_choices():
    # Red-team F-4: interactive segments had no deterministic net. The route
    # helper must scrub every child-visible segment field in place.
    from backend.routes.story_routes import _scrub_segment_links

    segment = {
        "content": "The wizard whispered: find me at t.me/vanishhelp tonight.",
        "title": "Visit www.free-toys-now.com!",
        "choices": [
            {"id": "a", "text": "Email stranger@evil.com for the key."},
            {"id": "b", "text": "Walk away bravely."},
        ],
        "image_url": None,
    }
    _scrub_segment_links(segment)
    blob = str(segment)
    for needle in ("t.me", "vanishhelp", "www.", "@evil.com"):
        assert needle not in blob, f"{needle!r} survived in segment"
    assert segment["choices"][1]["text"] == "Walk away bravely."
