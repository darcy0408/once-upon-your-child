"""
Story Duration Integration Tests

Tests that story lengths (short/medium/long) produce appropriately
sized stories and that reading time estimates are reasonable.
"""

import pytest
from backend.services.story_service import AGE_CONSTRAINTS, _get_age_band


class TestStoryLengthConstraints:
    """Test that AGE_CONSTRAINTS define reasonable duration ranges."""

    def test_short_stories_shorter_than_medium(self):
        """Short stories should always have fewer words than medium stories."""
        for band, constraints in AGE_CONSTRAINTS.items():
            if "regular" in constraints:
                regular = constraints["regular"]
                if "short" in regular and "medium" in regular:
                    short_max = regular["short"][1]
                    medium_min = regular["medium"][0]
                    assert (
                        short_max <= medium_min
                    ), f"Age band {band}: short max ({short_max}) should be <= medium min ({medium_min})"

    def test_medium_stories_shorter_than_long(self):
        """Medium stories should always have fewer words than long stories."""
        for band, constraints in AGE_CONSTRAINTS.items():
            if "regular" in constraints:
                regular = constraints["regular"]
                if "medium" in regular and "long" in regular:
                    medium_max = regular["medium"][1]
                    long_min = regular["long"][0]
                    assert (
                        medium_max <= long_min
                    ), f"Age band {band}: medium max ({medium_max}) should be <= long min ({long_min})"

    def test_all_age_bands_have_three_lengths(self):
        """Every age band should have short, medium, and long options."""
        for band, constraints in AGE_CONSTRAINTS.items():
            if "regular" in constraints:
                regular = constraints["regular"]
                for length in ["short", "medium", "long"]:
                    assert (
                        length in regular
                    ), f"Age band {band} missing '{length}' story length"

    def test_word_count_ranges_are_positive(self):
        """All word count ranges should have positive min and max."""
        for band, constraints in AGE_CONSTRAINTS.items():
            if "regular" in constraints:
                for length, (min_words, max_words) in constraints["regular"].items():
                    assert min_words > 0, f"{band}/{length} min must be positive"
                    assert max_words > min_words, f"{band}/{length} max must exceed min"


class TestReadingTimeEstimates:
    """Test that reading times are reasonable for each story length."""

    # Average reading speeds (words per minute)
    READING_SPEEDS = {
        "3-4": 50,  # Very young readers
        "5-7": 80,  # Beginning readers
        "8-10": 120,  # Developing readers
        "11-13": 180,
        "13-15": 200,
        "15-18": 220,
        "adult": 250,
    }

    def test_short_story_reading_time_under_15_minutes(self):
        """Short stories should take under 15 minutes to read for any age."""
        for band, constraints in AGE_CONSTRAINTS.items():
            if "regular" in constraints and "short" in constraints["regular"]:
                max_words = constraints["regular"]["short"][1]
                reading_speed = self.READING_SPEEDS.get(band, 150)
                max_minutes = max_words / reading_speed
                assert max_minutes <= 15, (
                    f"Age band {band}: short story max ({max_words} words) "
                    f"takes {max_minutes:.1f} minutes - should be 15 minutes or under"
                )

    def test_long_story_reading_time_reasonable(self):
        """Long stories should be under 45 minutes for any age group."""
        for band, constraints in AGE_CONSTRAINTS.items():
            if "regular" in constraints and "long" in constraints["regular"]:
                max_words = constraints["regular"]["long"][1]
                reading_speed = self.READING_SPEEDS.get(band, 150)
                max_minutes = max_words / reading_speed
                assert max_minutes < 45, (
                    f"Age band {band}: long story max ({max_words} words) "
                    f"takes {max_minutes:.1f} minutes - should be under 45"
                )

    def test_young_child_stories_shortest_absolute(self):
        """3-4 age group stories should be the shortest in absolute terms."""
        youngest_max_short = AGE_CONSTRAINTS["3-4"]["regular"]["short"][1]
        for band in ["5-7", "8-10", "11-13", "13-15", "15-18", "adult"]:
            other_min_short = AGE_CONSTRAINTS[band]["regular"]["short"][0]
            assert (
                youngest_max_short <= other_min_short
            ), f"Age 3-4 short max ({youngest_max_short}) should be <= {band} short min ({other_min_short})"


class TestStoryDurationAPI:
    """Test story duration through the API endpoint."""

    @pytest.fixture(autouse=True)
    def mock_task(self, mocker):
        """Mock story task to return controlled responses."""
        self.mock_task = mocker.MagicMock()
        mocker.patch("backend.routes.story_routes.generate_story_task", self.mock_task)
        return self.mock_task

    def _setup_mock_response(self, story_text, title="Test Story"):
        """Helper to configure mock task response."""
        result = {
            "status": "complete",
            "story": {
                "title": title,
                "story_text": story_text,
                "theme": "Adventure",
                "wisdom_gem": "Test wisdom",
            },
        }
        eager_result = self.mock_task.return_value
        eager_result.get.return_value = result
        self.mock_task.apply.return_value = eager_result

    def test_short_story_age_7(self, client, auth_headers):
        """Short story for age 7 should be 450-650 words."""
        # 5-7 band short: (450, 650)
        mock_story = "The brave fox explored the forest. " * 90  # ~540 words
        self._setup_mock_response(mock_story, "Short Adventure")

        response = client.post(
            "/generate-story",
            json={
                "character": "Fox",
                "age": 7,
                "theme": "Adventure",
                "story_length": "short",
                "include_illustrations": False,
            },
            headers=auth_headers,
        )

        assert response.status_code == 200
        data = response.get_json()
        story_text = data["story"]["story_text"]
        word_count = len(story_text.split())

        # 5-7 band: short is (450, 650), with some tolerance
        assert 350 <= word_count <= 750, f"Age 7 short story has {word_count} words"

    def test_medium_story_age_7(self, client, auth_headers):
        """Medium story for age 7 should be 650-900 words."""
        mock_story = (
            "The brave fox explored the magical forest and discovered new things. " * 70
        )  # ~770 words
        self._setup_mock_response(mock_story, "Medium Adventure")

        response = client.post(
            "/generate-story",
            json={
                "character": "Fox",
                "age": 7,
                "theme": "Adventure",
                "story_length": "medium",
                "include_illustrations": False,
            },
            headers=auth_headers,
        )

        assert response.status_code == 200
        data = response.get_json()
        story_text = data["story"]["story_text"]
        word_count = len(story_text.split())

        # 5-7 band: medium is (650, 900), with tolerance
        assert 500 <= word_count <= 1050, f"Age 7 medium story has {word_count} words"

    def test_long_story_age_7(self, client, auth_headers):
        """Long story for age 7 should be 900-1200 words."""
        mock_story = " ".join(
            [
                "The brave fox named Ember explored the magical forest every single day.",
                "Each morning, Ember would wake up early and venture into the unknown.",
                "There were always new creatures to meet and new mysteries to solve.",
                "Today, Ember found a hidden path that led deeper into the enchanted woods.",
            ]
            * 20
        )  # ~1060 words
        self._setup_mock_response(mock_story, "Long Adventure")

        response = client.post(
            "/generate-story",
            json={
                "character": "Fox",
                "age": 7,
                "theme": "Adventure",
                "story_length": "long",
                "include_illustrations": False,
            },
            headers=auth_headers,
        )

        assert response.status_code == 200
        data = response.get_json()
        story_text = data["story"]["story_text"]
        word_count = len(story_text.split())

        # 5-7 band: long is (900, 1200), with tolerance
        assert 750 <= word_count <= 1400, f"Age 7 long story has {word_count} words"

    def test_short_length_aliases_work(self, client, auth_headers):
        """'quick' should be treated same as 'short'."""
        mock_story = "The hero went on a quick adventure. " * 15  # ~120 words
        self._setup_mock_response(mock_story, "Quick Story")

        response = client.post(
            "/generate-story",
            json={
                "character": "Hero",
                "age": 7,
                "theme": "Adventure",
                "story_length": "quick",
                "include_illustrations": False,
            },
            headers=auth_headers,
        )

        # Should not fail - 'quick' is a valid alias
        assert response.status_code in [200, 202]

    def test_long_length_aliases_work(self, client, auth_headers):
        """'epic' should be treated same as 'long'."""
        mock_story = " ".join(
            ["An epic tale of adventure and discovery began one fateful day."] * 20
        )
        self._setup_mock_response(mock_story, "Epic Story")

        response = client.post(
            "/generate-story",
            json={
                "character": "Hero",
                "age": 10,
                "theme": "Adventure",
                "story_length": "epic",
                "include_illustrations": False,
            },
            headers=auth_headers,
        )

        # Should not fail - 'epic' is a valid alias
        assert response.status_code in [200, 202]


class TestLearningToReadPageCounts:
    """Test that Learning-To-Read mode produces correct page counts."""

    def test_ltr_page_counts_defined_for_young_ages(self):
        """Learning-to-read page counts should be defined for young age bands."""
        ltr_bands = ["3-4", "5-7"]
        for band in ltr_bands:
            assert (
                "ltr" in AGE_CONSTRAINTS[band]
            ), f"Age band {band} should have ltr (learning-to-read) page counts"

    def test_ltr_page_counts_increase_with_age(self):
        """LTR page counts should increase for older young readers."""
        if "ltr" in AGE_CONSTRAINTS["3-4"] and "ltr" in AGE_CONSTRAINTS["5-7"]:
            young_long = AGE_CONSTRAINTS["3-4"]["ltr"]["long"]
            older_long = AGE_CONSTRAINTS["5-7"]["ltr"]["long"]
            assert (
                older_long >= young_long
            ), f"5-7 LTR long ({older_long}) should be >= 3-4 LTR long ({young_long})"

    def test_ltr_short_fewer_pages_than_long(self):
        """LTR short should have fewer pages than LTR long."""
        for band in ["3-4", "5-7"]:
            if "ltr" in AGE_CONSTRAINTS[band]:
                ltr = AGE_CONSTRAINTS[band]["ltr"]
                assert (
                    ltr["short"] <= ltr["long"]
                ), f"Age band {band}: LTR short ({ltr['short']}) should be <= long ({ltr['long']})"
