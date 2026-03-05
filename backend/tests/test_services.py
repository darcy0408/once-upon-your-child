import pytest
from app import StoryStructures, CompanionDynamics, WisdomGems

def test_get_random_structure():
    """Test that get_random_structure returns a valid structure."""
    structure = StoryStructures.get_random_structure()
    assert structure is not None
    assert "name" in structure
    assert "structure" in structure

def test_get_random_structure_with_theme():
    """Test that get_random_structure returns a structure based on a theme."""
    structure = StoryStructures.get_random_structure("Friendship")
    assert structure is not None
    assert structure["name"] == "The Friendship"

def test_get_companion_info():
    """Test that get_companion_info returns valid information."""
    info = CompanionDynamics.get_companion_info("Loyal Dog")
    assert info is not None
    assert "contribution" in info
    assert info["contribution"] == "sniffs out clues and warns of danger"

def test_get_companion_info_none():
    """Test that get_companion_info returns None for no companion."""
    info = CompanionDynamics.get_companion_info(None)
    assert info is None

def test_get_wisdom():
    """Test that get_wisdom returns a wisdom string."""
    wisdom = WisdomGems.get_wisdom("Adventure")
    assert isinstance(wisdom, str)
    assert wisdom in WisdomGems.THEME_WISDOM["Adventure"]

def test_get_wisdom_default():
    """Test that get_wisdom returns a default wisdom for an unknown theme."""
    wisdom = WisdomGems.get_wisdom("Unknown Theme")
    assert isinstance(wisdom, str)
    assert wisdom in WisdomGems.THEME_WISDOM["Adventure"]
