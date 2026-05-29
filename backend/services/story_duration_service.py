"""
Story Duration and Page Management Service

Handles duration-to-word-count mapping, page splitting, and validation
for age-appropriate story generation.
"""

import logging
import re
from typing import Dict, List, Tuple

logger = logging.getLogger(__name__)


class StoryDuration:
    """Duration configuration for story length"""

    FIVE_MINUTES = "5_minutes"
    TEN_MINUTES = "10_minutes"

    # Map old length parameters to durations
    LEGACY_MAPPING = {
        "quick": FIVE_MINUTES,
        "standard": TEN_MINUTES,
        "epic": TEN_MINUTES,
    }


class DurationConfig:
    """Configuration for story duration by age"""

    # Age 5 requirements (as specified by user)
    AGE_5_CONFIG = {
        StoryDuration.FIVE_MINUTES: {
            "min_words": 450,
            "max_words": 700,
            "min_pages": 5,
            "max_pages": 8,
            "words_per_page": 90,  # ~450-700 / 5-8 = 70-140 words per page
            "target_description": "5-minute story for age 5",
        },
        StoryDuration.TEN_MINUTES: {
            "min_words": 900,
            "max_words": 1400,
            "min_pages": 8,
            "max_pages": 12,
            "words_per_page": 110,  # ~900-1400 / 8-12 = 90-140 words per page
            "target_description": "10-minute story for age 5",
        },
    }

    # Generic age configurations (for other ages)
    DEFAULT_CONFIG = {
        StoryDuration.FIVE_MINUTES: {
            "min_words": 300,
            "max_words": 500,
            "min_pages": 3,
            "max_pages": 6,
            "words_per_page": 100,
            "target_description": "5-minute story",
        },
        StoryDuration.TEN_MINUTES: {
            "min_words": 600,
            "max_words": 900,
            "min_pages": 5,
            "max_pages": 10,
            "words_per_page": 120,
            "target_description": "10-minute story",
        },
    }

    @classmethod
    def get_config(cls, duration: str, age: int) -> Dict:
        """Get configuration for given duration and age"""
        if age <= 5:
            config_set = cls.AGE_5_CONFIG
        else:
            config_set = cls.DEFAULT_CONFIG

        return config_set.get(duration, config_set[StoryDuration.FIVE_MINUTES])


class PageSplitter:
    """Smart page splitting that respects sentence boundaries"""

    # Sentence ending patterns
    SENTENCE_ENDINGS = re.compile(r"([.!?]+\s+)|([.!?]+$)")

    # Paragraph breaks
    PARAGRAPH_BREAK = re.compile(r"\n\n+")

    @classmethod
    def split_into_pages(
        cls,
        text: str,
        target_words_per_page: int = 100,
        min_pages: int = 5,
        max_pages: int = 8,
    ) -> List[str]:
        """
        Split story text into pages, respecting sentence and paragraph boundaries.

        Args:
            text: The story text to split
            target_words_per_page: Target words per page
            min_pages: Minimum number of pages required
            max_pages: Maximum number of pages allowed

        Returns:
            List of page texts
        """
        # Clean the text
        text = text.strip()

        if not text:
            return [text]

        # First, try to split by paragraphs
        paragraphs = cls.PARAGRAPH_BREAK.split(text)
        paragraphs = [p.strip() for p in paragraphs if p.strip()]

        # If we have natural paragraph breaks, use them
        if len(paragraphs) >= min_pages:
            pages = cls._split_by_paragraphs(
                paragraphs, target_words_per_page, min_pages, max_pages
            )
        else:
            # Otherwise, split by sentences
            pages = cls._split_by_sentences(
                text, target_words_per_page, min_pages, max_pages
            )

        # Ensure we have the right number of pages
        if len(pages) < min_pages:
            logger.warning(
                f"Generated only {len(pages)} pages, expected at least {min_pages}"
            )
        elif len(pages) > max_pages:
            # Merge pages if we have too many
            pages = cls._merge_pages(pages, max_pages)

        return pages

    @classmethod
    def _split_by_paragraphs(
        cls,
        paragraphs: List[str],
        target_words_per_page: int,
        min_pages: int,
        max_pages: int,
    ) -> List[str]:
        """Split by grouping paragraphs into pages"""
        pages = []
        current_page = []
        current_word_count = 0

        for para in paragraphs:
            para_words = len(para.split())

            # If adding this paragraph would exceed target, start new page
            if (
                current_page
                and current_word_count + para_words > target_words_per_page * 1.5
            ):
                pages.append("\n\n".join(current_page))
                current_page = [para]
                current_word_count = para_words
            else:
                current_page.append(para)
                current_word_count += para_words

        # Add remaining paragraphs as final page
        if current_page:
            pages.append("\n\n".join(current_page))

        return pages

    @classmethod
    def _split_by_sentences(
        cls, text: str, target_words_per_page: int, min_pages: int, max_pages: int
    ) -> List[str]:
        """Split by grouping sentences into pages, balanced across desired page count.

        Computes a desired page count from the total body length, clamped to
        [min_pages, max_pages], then derives a per-page word target from that.
        Avoids the lopsided-tail bug where naive greedy packing leaves a final
        page with only a sentence or two.
        """
        sentences = cls._split_into_sentences(text)

        if not sentences:
            return [text]

        total_words = sum(len(s.split()) for s in sentences)
        natural_pages = max(1, total_words // max(1, target_words_per_page))
        desired_pages = max(min_pages, min(max_pages, natural_pages))
        adjusted_target = max(15, total_words // max(1, desired_pages))

        pages: List[str] = []
        current: List[str] = []
        current_words = 0

        for sentence in sentences:
            sentence_words = len(sentence.split())
            # Start a new page if adding would overshoot the per-page target by >15%,
            # but only when we still have room before hitting desired_pages-1
            # (so the final page has at least one sentence).
            would_overshoot = current_words + sentence_words > adjusted_target * 1.15
            has_room_for_more_pages = len(pages) + 1 < desired_pages
            if current and would_overshoot and has_room_for_more_pages:
                pages.append(" ".join(current))
                current = [sentence]
                current_words = sentence_words
            else:
                current.append(sentence)
                current_words += sentence_words

        if current:
            pages.append(" ".join(current))

        return pages

    @classmethod
    def _split_into_sentences(cls, text: str) -> List[str]:
        """Split text into individual sentences"""
        # Split on sentence endings
        parts = re.split(r"([.!?]+)", text)

        sentences = []
        for i in range(0, len(parts) - 1, 2):
            sentence = parts[i].strip()
            if i + 1 < len(parts):
                sentence += parts[i + 1]
            if sentence:
                sentences.append(sentence.strip())

        # Handle last part if it doesn't end with punctuation
        if len(parts) % 2 == 1 and parts[-1].strip():
            sentences.append(parts[-1].strip())

        return sentences

    @classmethod
    def _merge_pages(cls, pages: List[str], target_count: int) -> List[str]:
        """Merge pages to reach target count"""
        if len(pages) <= target_count:
            return pages

        # Calculate how many pages to merge
        merge_ratio = len(pages) / target_count

        merged = []
        current_merge = []

        for i, page in enumerate(pages):
            current_merge.append(page)

            # Check if we should finalize this merged page
            if len(merged) < target_count - 1:
                # Not the last page - use ratio to decide
                if len(current_merge) >= merge_ratio:
                    merged.append("\n\n".join(current_merge))
                    current_merge = []
            else:
                # Last page - collect remaining
                pass

        # Add any remaining pages as the final merged page
        if current_merge:
            merged.append("\n\n".join(current_merge))

        return merged

    @classmethod
    def count_words(cls, text: str) -> int:
        """Count words in text"""
        return len(text.split())


class StoryValidator:
    """Validates generated stories meet requirements"""

    @classmethod
    def validate_story(
        cls, story_text: str, pages: List[str], duration: str, age: int
    ) -> Tuple[bool, List[str]]:
        """
        Validate story meets requirements.

        Returns:
            (is_valid, list_of_issues)
        """
        config = DurationConfig.get_config(duration, age)
        issues = []

        # Count total words
        total_words = PageSplitter.count_words(story_text)

        # Check word count
        if total_words < config["min_words"]:
            issues.append(
                f"Story too short: {total_words} words (minimum {config['min_words']})"
            )

        if total_words > config["max_words"]:
            issues.append(
                f"Story too long: {total_words} words (maximum {config['max_words']})"
            )

        # Check page count
        if len(pages) < config["min_pages"]:
            issues.append(
                f"Too few pages: {len(pages)} pages (minimum {config['min_pages']})"
            )

        if len(pages) > config["max_pages"]:
            issues.append(
                f"Too many pages: {len(pages)} pages (maximum {config['max_pages']})"
            )

        # Check that pages end on sentence boundaries
        for i, page in enumerate(pages):
            if not cls._ends_on_sentence_boundary(page):
                issues.append(f"Page {i+1} does not end on a sentence boundary")

        is_valid = len(issues) == 0
        return is_valid, issues

    @classmethod
    def _ends_on_sentence_boundary(cls, text: str) -> bool:
        """Check if text ends on a sentence boundary"""
        text = text.strip()
        if not text:
            return False

        # Should end with sentence-ending punctuation
        return text[-1] in ".!?"


class AdventureStepGenerator:
    """Generates kid-friendly adventure step labels"""

    # Age 5 plot arc (8 steps for 5-8 pages, or 12 steps for 8-12 pages)
    AGE_5_PLOT_ARC_5MIN = [
        "🌟 Step 1: A Magical Beginning",
        "🚪 Step 2: Through the Wonder Door",
        "🎨 Step 3: A Colorful Discovery",
        "😮 Step 4: Uh-Oh Moment",
        "🤔 Step 5: A Silly Idea",
        "💪 Step 6: Being Brave & Kind",
        "✨ Step 7: Everything Sparkles!",
        "🏠 Step 8: Home with a Smile",
    ]

    AGE_5_PLOT_ARC_10MIN = [
        "🌟 Step 1: A Cozy Start",
        "🚪 Step 2: Something Magical Appears",
        "🎨 Step 3: A Fun Discovery",
        "🎭 Step 4: Meeting New Friends",
        "😮 Step 5: A Little Problem",
        "🤪 Step 6: Trying Something Silly",
        "🤔 Step 7: Thinking of a Better Way",
        "💪 Step 8: Using Kindness & Smarts",
        "✨ Step 9: The Sparkly Moment!",
        "🎉 Step 10: Happy Celebration",
        "🏠 Step 11: Coming Back Home",
        "💭 Step 12: A Warm Glow",
    ]

    @classmethod
    def generate_steps(cls, duration: str, age: int, num_pages: int) -> List[str]:
        """Generate adventure step labels for the story"""
        if age <= 5:
            if duration == StoryDuration.FIVE_MINUTES:
                # Use 5-minute arc and trim/extend to match page count
                base_steps = cls.AGE_5_PLOT_ARC_5MIN
            else:
                # Use 10-minute arc
                base_steps = cls.AGE_5_PLOT_ARC_10MIN

            # Trim or extend to match page count
            if len(base_steps) > num_pages:
                # Trim from the middle, keeping beginning and end
                return cls._trim_steps(base_steps, num_pages)
            elif len(base_steps) < num_pages:
                # Extend by duplicating middle steps
                return cls._extend_steps(base_steps, num_pages)
            else:
                return base_steps
        else:
            # For other ages, generate generic steps
            return [f"Step {i+1}" for i in range(num_pages)]

    @classmethod
    def _trim_steps(cls, steps: List[str], target_count: int) -> List[str]:
        """Trim steps to target count, keeping first and last"""
        if len(steps) <= target_count:
            return steps

        # Always keep first and last
        keep_first = 2
        keep_last = 2
        middle_to_keep = target_count - keep_first - keep_last

        if middle_to_keep < 0:
            # Very short, just return first N
            return steps[:target_count]

        # Calculate which middle steps to keep
        middle_steps = steps[keep_first:-keep_last]
        step_interval = len(middle_steps) / middle_to_keep

        selected_middle = []
        for i in range(middle_to_keep):
            idx = int(i * step_interval)
            selected_middle.append(middle_steps[idx])

        return steps[:keep_first] + selected_middle + steps[-keep_last:]

    @classmethod
    def _extend_steps(cls, steps: List[str], target_count: int) -> List[str]:
        """Extend steps to target count by duplicating middle"""
        if len(steps) >= target_count:
            return steps

        # Duplicate middle steps
        middle_idx = len(steps) // 2
        to_add = target_count - len(steps)

        result = steps[:middle_idx]
        for i in range(to_add):
            # Add variations of middle steps
            original_step = steps[middle_idx + (i % (len(steps) - middle_idx))]
            result.append(original_step + " (continued)")
        result.extend(steps[middle_idx:])

        return result[:target_count]
