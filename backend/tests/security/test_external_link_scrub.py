"""Security tests: output-side external-link scrub (audit P1#2).

`scrub_external_links` is the deterministic net on final child-visible story
text. It must strip web addresses / emails a model was coaxed into emitting,
while leaving ordinary prose (including plain numbers) untouched.
"""

import pytest

from backend.utils.sanitizer import scrub_external_links, scrub_external_links_deep


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


def test_deep_scrub_walks_nested_structure_preserving_shape():
    # scrub_external_links_deep scrubs every string leaf in a dict/list/tuple
    # while leaving non-string leaves and the container shape intact.
    payload = {
        "nemesis": "The Whisper, who says: reach me at t.me/vanishhelp.",
        "allies": ["Mara", "the mentor — email helper@evil.com for help"],
        "issue_count": 3,
        "flags": (True, "the map is at www.free-toys-now.com"),
        "nested": {"next_hook": "Find the rest at bit.ly/secret-cave, hero."},
    }
    cleaned = scrub_external_links_deep(payload)
    blob = str(cleaned)
    for needle in (
        "t.me",
        "vanishhelp",
        "helper@evil.com",
        "www.",
        "bit.ly",
        "secret-cave",
    ):
        assert needle not in blob, f"{needle!r} survived deep scrub"
    # non-string leaves + container types preserved
    assert cleaned["issue_count"] == 3
    assert cleaned["flags"][0] is True
    assert isinstance(cleaned["flags"], tuple)
    assert cleaned["allies"][0] == "Mara"


def test_deep_scrub_saga_state_egress_payload_is_removed():
    # The real superhero saga_state shape (single-shot Adolescent/Creator path).
    # An injected link in any free-text field must not survive to the client —
    # it would also round-trip into the next Issue's prompt as prior_saga.
    saga_state = {
        "nemesis": "The Collector, who whispers: find me at t.me/vanishhelp.",
        "nemesis_status": "circling",
        "what_changed": "She let one person see her.",
        "what_it_cost": "The comfort of the mask.",
        "next_hook": "A note appears: vanishhelp@proton.me is always open.",
        "allies": ["Mara", "reach the guide at www.free-toys-now.com"],
        "defining_choice": "She chose to be known.",
    }
    cleaned = scrub_external_links_deep(saga_state)
    blob = str(cleaned)
    for needle in ("t.me", "vanishhelp", "proton.me", "www.", "free-toys-now"):
        assert needle not in blob, f"{needle!r} survived saga_state scrub"
    # benign narrative text is untouched
    assert cleaned["defining_choice"] == "She chose to be known."
    assert cleaned["allies"][0] == "Mara"


def test_deep_scrub_leaves_clean_saga_state_identical():
    saga_state = {
        "nemesis": "The Doubt Dragon",
        "nemesis_status": "wounded but circling",
        "allies": ["Pip", "Bramble"],
        "what_changed": "She learned her voice could be steady.",
        "defining_choice": "She told someone the truth.",
    }
    assert scrub_external_links_deep(saga_state) == saga_state


def test_deep_scrub_handles_scalars_and_none():
    assert scrub_external_links_deep(None) is None
    assert scrub_external_links_deep(7) == 7
    out = scrub_external_links_deep("reach me at t.me/vanishhelp")
    assert "t.me" not in out and "vanishhelp" not in out
