import re
from typing import Dict, Any
import math

class StoryQualityService:
    """Service for scoring story quality based on multiple metrics"""

    # Therapeutic keywords to look for in stories
    THERAPEUTIC_KEYWORDS = {
        'feel', 'emotion', 'happy', 'sad', 'angry', 'scared', 'brave', 'strong',
        'friend', 'help', 'care', 'love', 'kind', 'share', 'together', 'family',
        'learn', 'grow', 'change', 'better', 'try', 'courage', 'confidence',
        'dream', 'hope', 'smile', 'laugh', 'hug', 'support', 'understand',
        'listen', 'talk', 'share', 'feelings', 'emotions', 'heart', 'mind'
    }

    # Age-appropriate word count targets (rough estimates)
    AGE_WORD_TARGETS = {
        3: 150,   # 3-year-olds: ~150 words
        4: 200,   # 4-year-olds: ~200 words
        5: 250,   # 5-year-olds: ~250 words
        6: 300,   # 6-year-olds: ~300 words
        7: 350,   # 7-year-olds: ~350 words
        8: 400,   # 8-year-olds: ~400 words
        9: 450,   # 9-year-olds: ~450 words
        10: 500,  # 10-year-olds: ~500 words
        11: 550,  # 11-year-olds: ~550 words
        12: 600,  # 12-year-olds: ~600 words
        13: 650,  # 13-year-olds: ~650 words
        14: 700,  # 14-year-olds: ~700 words
        15: 750,  # 15-year-olds: ~750 words
        16: 800,  # 16-year-olds: ~800 words
        17: 850,  # 17-year-olds: ~850 words
    }

    @staticmethod
    def calculate_story_quality(story_text: str, age: int) -> Dict[str, Any]:
        """
        Calculate comprehensive quality score for a story

        Args:
            story_text: The full story text
            age: Target age of the child reader

        Returns:
            Dict with overall score and component scores
        """
        if not story_text or not story_text.strip():
            return {
                'overall_score': 0,
                'length_score': 0,
                'therapeutic_score': 0,
                'readability_score': 0,
                'age_appropriateness_score': 0,
                'word_count': 0,
                'sentence_count': 0,
                'avg_words_per_sentence': 0,
                'grade_level': 0,
                'quality_badge': 'Poor'
            }

        # Basic text analysis
        word_count = len(story_text.split())
        sentences = re.split(r'[.!?]+', story_text)
        sentence_count = len([s for s in sentences if s.strip()])
        avg_words_per_sentence = word_count / max(sentence_count, 1)

        # Calculate component scores
        length_score = StoryQualityService._calculate_length_score(word_count, age)
        therapeutic_score = StoryQualityService._calculate_therapeutic_score(story_text)
        readability_score = StoryQualityService._calculate_readability_score(story_text, age)
        age_appropriateness_score = StoryQualityService._calculate_age_appropriateness_score(
            story_text, age, avg_words_per_sentence
        )

        # Weighted overall score
        overall_score = (
            length_score * 0.25 +           # 25% - Length appropriateness
            therapeutic_score * 0.35 +      # 35% - Therapeutic content
            readability_score * 0.25 +      # 25% - Readability
            age_appropriateness_score * 0.15  # 15% - Age appropriateness
        )

        # Determine quality badge
        quality_badge = StoryQualityService._get_quality_badge(overall_score)

        return {
            'overall_score': round(overall_score),
            'length_score': round(length_score),
            'therapeutic_score': round(therapeutic_score),
            'readability_score': round(readability_score),
            'age_appropriateness_score': round(age_appropriateness_score),
            'word_count': word_count,
            'sentence_count': sentence_count,
            'avg_words_per_sentence': round(avg_words_per_sentence, 1),
            'grade_level': StoryQualityService._calculate_grade_level(avg_words_per_sentence),
            'quality_badge': quality_badge
        }

    @staticmethod
    def _calculate_length_score(word_count: int, age: int) -> float:
        """Calculate score based on story length appropriateness for age"""
        target_words = StoryQualityService.AGE_WORD_TARGETS.get(age, 400)

        # Ideal range is 70-130% of target
        min_ideal = target_words * 0.7
        max_ideal = target_words * 1.3

        if min_ideal <= word_count <= max_ideal:
            return 100.0
        elif word_count < min_ideal:
            # Too short - score decreases as it gets shorter
            ratio = word_count / min_ideal
            return max(20.0, ratio * 80.0 + 20.0)  # Min 20, max 100
        else:
            # Too long - score decreases as it gets longer
            ratio = max_ideal / word_count
            return max(30.0, ratio * 70.0 + 30.0)  # Min 30, max 100

    @staticmethod
    def _calculate_therapeutic_score(story_text: str) -> float:
        """Calculate score based on therapeutic keyword presence"""
        text_lower = story_text.lower()
        found_keywords = set()

        # Count unique therapeutic keywords found
        for keyword in StoryQualityService.THERAPEUTIC_KEYWORDS:
            if keyword in text_lower:
                found_keywords.add(keyword)

        keyword_count = len(found_keywords)
        total_keywords = len(StoryQualityService.THERAPEUTIC_KEYWORDS)

        # Score based on percentage of keywords found
        keyword_ratio = keyword_count / total_keywords

        # Boost score for higher ratios
        if keyword_ratio >= 0.15:  # 15% of keywords
            return min(100.0, keyword_ratio * 120.0)  # Can exceed 100 for excellent coverage
        elif keyword_ratio >= 0.08:  # 8% of keywords
            return keyword_ratio * 100.0
        else:
            return max(10.0, keyword_ratio * 200.0)  # Min 10 for very low coverage

    @staticmethod
    def _calculate_readability_score(story_text: str, age: int) -> float:
        """Calculate readability score using simplified Flesch-Kincaid"""
        word_count = len(story_text.split())
        sentence_count = len(re.split(r'[.!?]+', story_text))

        if sentence_count == 0 or word_count == 0:
            return 50.0

        # Simplified Flesch Reading Ease formula
        # ASL = average sentence length (words per sentence)
        # ASW = average syllables per word (approximated)
        asl = word_count / sentence_count

        # Rough syllable approximation (vowels = syllables)
        vowels = len(re.findall(r'[aeiouAEIOU]', story_text))
        asw = vowels / word_count if word_count > 0 else 0

        # Simplified formula: 206.835 - 1.015 × ASL - 84.6 × ASW
        # But we'll use a simpler version for our purposes
        readability_score = 100.0

        # Penalize very long sentences
        if asl > 15:
            readability_score -= (asl - 15) * 2
        elif asl < 5:
            readability_score -= (5 - asl) * 1.5  # Penalize very short sentences too

        # Penalize complex words (long words)
        long_words = len([w for w in story_text.split() if len(w) > 8])
        long_word_ratio = long_words / word_count if word_count > 0 else 0
        readability_score -= long_word_ratio * 50

        # Age adjustment - younger kids need simpler text
        if age <= 5 and readability_score > 80:
            readability_score = 80  # Cap for very young children
        elif age >= 12 and readability_score < 60:
            readability_score += 10  # Boost for older children

        return max(0.0, min(100.0, readability_score))

    @staticmethod
    def _calculate_age_appropriateness_score(story_text: str, age: int, avg_words_per_sentence: float) -> float:
        """Calculate how appropriate the content is for the target age"""
        score = 100.0

        # Check for age-inappropriate content (simplified check)
        inappropriate_words = {'violence', 'death', 'scary', 'nightmare', 'monster'}
        text_lower = story_text.lower()

        inappropriate_count = sum(1 for word in inappropriate_words if word in text_lower)

        if inappropriate_count > 0:
            # Penalize inappropriate content more for younger ages
            penalty = inappropriate_count * (15 - age) * 2
            score -= penalty

        # Check sentence complexity vs age
        if age <= 5 and avg_words_per_sentence > 8:
            score -= (avg_words_per_sentence - 8) * 3
        elif age <= 8 and avg_words_per_sentence > 12:
            score -= (avg_words_per_sentence - 12) * 2
        elif age >= 12 and avg_words_per_sentence < 10:
            score -= (10 - avg_words_per_sentence) * 1.5  # Older kids can handle complexity

        # Check for positive, developmental content
        positive_indicators = {'learn', 'grow', 'help', 'friend', 'family', 'love', 'kind'}
        positive_count = sum(1 for word in positive_indicators if word in text_lower)

        if positive_count >= 2:
            score += 10  # Bonus for positive content

        return max(0.0, min(100.0, score))

    @staticmethod
    def _calculate_grade_level(avg_words_per_sentence: float) -> float:
        """Estimate grade level using sentence length"""
        # Rough approximation: grade level ≈ sentence length / 2
        return round(avg_words_per_sentence / 2.0, 1)

    @staticmethod
    def _get_quality_badge(overall_score: float) -> str:
        """Convert numerical score to quality badge"""
        if overall_score >= 85:
            return 'Excellent'
        elif overall_score >= 70:
            return 'Great'
        elif overall_score >= 55:
            return 'Good'
        elif overall_score >= 40:
            return 'Fair'
        else:
