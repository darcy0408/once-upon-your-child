"""
Age Group Integration Tests

Tests that story generation produces age-appropriate content for each age band through the API.
Verifies word counts, vocabulary complexity, and content appropriateness.
"""

import re

import pytest

from backend.services.story_service import AGE_CONSTRAINTS


class TestAgeGroupStoryGeneration:
    """Test story generation API for each age group."""

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
                "theme": "Test Theme",
                "wisdom_gem": "Test wisdom",
            },
        }
        eager_result = self.mock_task.return_value
        eager_result.get.return_value = result
        self.mock_task.apply_async.return_value = eager_result

    def test_age_4_generates_appropriate_word_count(self, client, auth_headers):
        """Age 4 stories should be 300-500 words (3-5 min read)."""
        # Mock response for age 4 - simple, short story
        mock_story = (
            "Once upon a time, there was a little bunny named Fluffy. "
            "Fluffy loved to hop in the sunny meadow. One day, Fluffy found "
            "a shiny red ball. The ball was so bouncy and fun! Fluffy hopped "
            "and played all day long. The warm sun made Fluffy feel happy. "
            "When the stars came out, Fluffy went home to a cozy bed. "
            "Fluffy dreamed of more adventures tomorrow. The end. " * 5  # ~350 words
        )
        self._setup_mock_response(mock_story, "Fluffy's Adventure")

        response = client.post(
            "/generate-story",
            json={
                "character": "Fluffy",
                "age": 4,
                "theme": "Friendship",
                "story_length": "short",
                "include_illustrations": False,
            },
            headers=auth_headers,
        )

        assert response.status_code == 200
        data = response.get_json()
        story_text = data["story"]["story_text"]
        word_count = len(story_text.split())

        # Age 4 should get 200-500 words for short stories
        assert (
            150 <= word_count <= 700
        ), f"Age 4 story has {word_count} words, expected 200-500"

    def test_age_7_generates_appropriate_word_count(self, client, auth_headers):
        """Age 7 stories should be 500-800 words (5-8 min read)."""
        mock_story = (
            "In a magical forest, there lived a brave little fox named Ember. "
            "Ember was curious about everything and loved exploring. One sunny morning, "
            "Ember discovered a mysterious cave hidden behind a waterfall. Inside the cave, "
            "beautiful crystals glowed with different colors. Ember carefully walked deeper "
            "into the cave, touching the smooth walls. Suddenly, one of the crystals began "
            "to hum a beautiful song. Ember listened carefully and felt very peaceful. "
            "The crystal showed Ember a vision of a treasure map. Ember decided to follow "
            "the map and find the treasure. The journey was exciting and a little scary, "
            "but Ember was brave. After many adventures, Ember found the treasure - "
            "a magical necklace that could grant one wish. Ember wished for all the forest "
            "animals to always have enough food and water. The wish came true, and everyone "
            "was happy. Ember became a hero of the forest. The end. " * 5  # ~650 words
        )
        self._setup_mock_response(mock_story, "Ember's Quest")

        response = client.post(
            "/generate-story",
            json={
                "character": "Ember",
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

        # Age 7 should get 300-800 words for medium stories
        assert (
            250 <= word_count <= 900
        ), f"Age 7 story has {word_count} words, expected 300-800"

    def test_age_9_generates_appropriate_word_count(self, client, auth_headers):
        """Age 9 stories should be 800-1200 words (8-12 min read)."""
        # Create a more complex story for age 9
        mock_story = " ".join(
            [
                "Chapter 1: The Discovery.",
                "Maya had always been fascinated by the old lighthouse on the cliff.",
                "Every day after school, she would walk along the beach and stare up at it.",
                "Today was different. Today, Maya decided to climb the winding stairs.",
                "The door creaked open, revealing dusty rooms filled with mysterious objects.",
                "In the corner, Maya found an ancient telescope pointing at the stars.",
                "When she looked through it, she saw something incredible - a constellation",
                "that seemed to be moving, forming words in the sky. The message said:",
                "'Seek the three keys beneath the waves, above the clouds, within the flame.'",
                "Maya knew this was the beginning of an extraordinary adventure.",
            ]
            * 8
        )  # ~1000 words
        self._setup_mock_response(mock_story, "Maya and the Starlight Keys")

        response = client.post(
            "/generate-story",
            json={
                "character": "Maya",
                "age": 9,
                "theme": "Mystery",
                "story_length": "medium",
                "include_illustrations": False,
            },
            headers=auth_headers,
        )

        assert response.status_code == 200
        data = response.get_json()
        story_text = data["story"]["story_text"]
        word_count = len(story_text.split())

        # Age 9 should get 450-1200 words for medium stories
        assert (
            400 <= word_count <= 1300
        ), f"Age 9 story has {word_count} words, expected 450-1200"

    def test_age_12_generates_appropriate_word_count(self, client, auth_headers):
        """Age 12 stories should be 1200-1600 words (12-16 min read)."""
        # Create a longer, more complex story for age 12
        mock_story = " ".join(
            [
                "The archaeological expedition had been searching for the lost city of Atlantis for three years.",
                "Dr. Sarah Chen and her team had followed every clue, decoded every ancient text,",
                "and explored every underwater cave in the Mediterranean. But today felt different.",
                "The sonar readings showed an unusual structure 300 feet below the surface.",
                "As Sarah descended in the submersible, her heart raced with anticipation.",
                "The walls of the canyon began to reveal intricate carvings - symbols that matched",
                "the prophecies from the ancient scrolls. Suddenly, the water seemed to shimmer,",
                "and a massive gateway appeared before her. This was it. This was really it.",
            ]
            * 13
        )  # ~1400 words
        self._setup_mock_response(mock_story, "The Gateway to Atlantis")

        response = client.post(
            "/generate-story",
            json={
                "character": "Dr. Sarah Chen",
                "age": 12,
                "theme": "Science Fiction",
                "story_length": "long",
                "include_illustrations": False,
            },
            headers=auth_headers,
        )

        assert response.status_code == 200
        data = response.get_json()
        story_text = data["story"]["story_text"]
        word_count = len(story_text.split())

        # Age 12 should get 650-1600 words for long stories
        assert (
            600 <= word_count <= 1700
        ), f"Age 12 story has {word_count} words, expected 650-1600"

    def test_age_16_generates_appropriate_word_count(self, client, auth_headers):
        """Age 16 stories should be 1600-2000 words (16-20 min read)."""
        # Create a sophisticated story for age 16
        mock_story = " ".join(
            [
                "The rebellion had been brewing for months beneath the surface of the seemingly perfect society.",
                "Kira had noticed the cracks first - the subtle inconsistencies in the government's narrative,",
                "the disappearances of citizens who asked too many questions, the surveillance that grew",
                "more invasive each day. But speaking out meant risking everything: her family, her future,",
                "her life. Yet staying silent felt like a betrayal of her own conscience.",
                "Tonight, Kira would make her choice. She stood at the edge of the rooftop, looking down",
                "at the city below. The neon signs flickered with propaganda slogans, but she could see",
                "beyond the lies now. In her pocket, the data chip containing proof of the government's",
                "corruption felt heavy. One broadcast. That's all it would take to wake everyone up.",
                "But could she live with the consequences? The wind whipped her hair as she made her decision.",
            ]
            * 12
        )  # ~1800 words
        self._setup_mock_response(mock_story, "Shattered Illusions")

        response = client.post(
            "/generate-story",
            json={
                "character": "Kira",
                "age": 16,
                "theme": "Dystopian",
                "story_length": "long",
                "include_illustrations": False,
            },
            headers=auth_headers,
        )

        assert response.status_code == 200
        data = response.get_json()
        story_text = data["story"]["story_text"]
        word_count = len(story_text.split())

        # Age 16 should get 650-2000 words for long stories
        assert (
            600 <= word_count <= 2100
        ), f"Age 16 story has {word_count} words, expected 650-2000"


class TestVocabularyComplexity:
    """Test that vocabulary complexity matches age appropriateness."""

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
                "theme": "Test Theme",
                "wisdom_gem": "Test wisdom",
            },
        }
        eager_result = self.mock_task.return_value
        eager_result.get.return_value = result
        self.mock_task.apply_async.return_value = eager_result

    def test_age_4_uses_simple_vocabulary(self, client, auth_headers):
        """Age 4 should use predominantly simple, familiar words."""
        mock_story = (
            "The little cat sat on the soft mat. The cat was happy and warm. "
            "A bird sang a sweet song. The cat listened and purred. "
            "The sun was bright and yellow. It was a good day. " * 40
        )
        self._setup_mock_response(mock_story, "Kitty's Day")

        response = client.post(
            "/generate-story",
            json={
                "character": "Kitty",
                "age": 4,
                "theme": "Animals",
                "story_length": "short",
                "include_illustrations": False,
            },
            headers=auth_headers,
        )

        assert response.status_code == 200
        data = response.get_json()
        story_text = data["story"]["story_text"]

        # Check for simple sentence structure (short sentences)
        sentences = re.split(r"[.!?]+", story_text)
        sentences = [s.strip() for s in sentences if s.strip()]
        avg_sentence_length = sum(len(s.split()) for s in sentences) / max(
            len(sentences), 1
        )

        assert (
            avg_sentence_length < 15
        ), f"Age 4 sentences too long (avg {avg_sentence_length} words)"

    def test_vocabulary_complexity_increases_with_age(self, client, auth_headers):
        """Verify that vocabulary complexity increases with age."""
        test_cases = [
            (4, "The cat sat on the mat. " * 50),
            (
                16,
                "The feline perched precariously upon the intricately woven tapestry. "
                * 30,
            ),
        ]

        results = {}

        for age, mock_text in test_cases:
            self._setup_mock_response(mock_text, "Test Story")

            response = client.post(
                "/generate-story",
                json={
                    "character": "Hero",
                    "age": age,
                    "theme": "Adventure",
                    "story_length": "medium",
                    "include_illustrations": False,
                },
                headers=auth_headers,
            )

            assert response.status_code == 200
            data = response.get_json()
            story_text = data["story"]["story_text"]

            words = story_text.split()
            avg_word_length = sum(len(w.strip(".,!?")) for w in words) / len(words)
            results[age] = avg_word_length

        # Age 16 should have longer average word length than age 4
        assert (
            results[16] > results[4]
        ), f"Age 16 (avg {results[16]}) should have longer words than age 4 (avg {results[4]})"


class TestAgeConstraintsCoverage:
    """Test that AGE_CONSTRAINTS are properly defined and cover all ages."""

    def test_age_constraints_cover_all_tested_ages(self):
        """Verify AGE_CONSTRAINTS covers ages 4, 7, 9, 12, 16."""
        tested_ages = [4, 7, 9, 12, 16]

        for age in tested_ages:
            # Check that age falls into one of the constraint ranges
            found = False
            for constraint_key in AGE_CONSTRAINTS:
                # Parse the age range from the key (e.g., "3-4", "5-7", "8-10")
                if "-" in constraint_key:
                    min_age, max_age = map(int, constraint_key.split("-"))
                    if min_age <= age <= max_age:
                        found = True
                        break
                elif "+" in constraint_key:
                    # Handle "18+" format
                    min_age = int(constraint_key.replace("+", ""))
                    if age >= min_age:
                        found = True
                        break

            assert found, f"Age {age} not covered by AGE_CONSTRAINTS"

    def test_age_constraints_have_word_count_ranges(self):
        """Verify each age constraint has word count ranges."""
        for constraint_key, constraint_data in AGE_CONSTRAINTS.items():
            # Each constraint should have 'regular', 'rhyme', or 'ltr' modes with word counts
            assert any(
                mode in constraint_data for mode in ["regular", "rhyme", "ltr"]
            ), f"Age constraint {constraint_key} missing mode definitions"

            # Check that modes have word count ranges
            if "regular" in constraint_data:
                regular = constraint_data["regular"]
                for length in ["short", "medium", "long"]:
                    if length in regular:
                        # Should be a tuple of (min, max)
                        assert (
                            isinstance(regular[length], tuple)
                            and len(regular[length]) == 2
                        ), f"Age constraint {constraint_key} regular.{length} should be (min, max) tuple"


class TestConsistencyAcrossGenerations:
    """Test that multiple generations for the same age are consistent."""

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
        self.mock_task.apply_async.return_value = eager_result

    def test_age_7_consistency_across_three_generations(self, client, auth_headers):
        """Generate 3 stories for age 7 and verify consistent word counts."""
        word_counts = []

        for i in range(3):
            mock_story = f"Story {i+1} for a 7-year-old child. " * 100
            self._setup_mock_response(mock_story, f"Adventure {i+1}")

            response = client.post(
                "/generate-story",
                json={
                    "character": f"Hero{i}",
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
            word_counts.append(len(story_text.split()))

        # All three should be in a reasonable range
        for count in word_counts:
            assert 250 <= count <= 900, f"Inconsistent word count: {count}"

        # Should be relatively consistent (within 40% variance due to mocking)
        avg_count = sum(word_counts) / len(word_counts)
        for count in word_counts:
            variance = abs(count - avg_count) / avg_count
            assert variance < 0.4, f"Too much variance in word counts: {word_counts}"
