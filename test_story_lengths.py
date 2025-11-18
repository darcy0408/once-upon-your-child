#!/usr/bin/env python3
"""
Story Length Validation Test
Tests that stories generated for different age groups stay within appropriate word count limits.
"""

import requests
import json
import re
from collections import defaultdict

# Age groups and their word count limits
AGE_GROUPS = [
    {'name': 'Early Childhood', 'age': 4, 'min_words': 100, 'max_words': 150},
    {'name': 'Early Elementary', 'age': 7, 'min_words': 150, 'max_words': 250},
    {'name': 'Upper Elementary', 'age': 10, 'min_words': 250, 'max_words': 400},
    {'name': 'Early Teen', 'age': 14, 'min_words': 400, 'max_words': 600},
    {'name': 'Late Teen/Adult', 'age': 18, 'min_words': 600, 'max_words': 800},
]

THEMES = ['Adventure', 'Friendship', 'Magic', 'Space', 'Ocean']
CHARACTERS = [
    {'name': 'Alex', 'gender': 'Other'},
    {'name': 'Jamie', 'gender': 'Other'},
    {'name': 'Taylor', 'gender': 'Other'},
    {'name': 'Morgan', 'gender': 'Other'},
    {'name': 'Casey', 'gender': 'Other'},
]

def count_words(text):
    """Count words in text, handling punctuation and whitespace."""
    if not text:
        return 0
    # Remove extra whitespace and split on whitespace
    words = re.findall(r'\b\w+\b', text)
    return len(words)

def generate_story(age, theme, character_name, character_gender):
    """Generate a story and return word count."""
    payload = {
        'character': character_name,
        'age': age,
        'gender': character_gender,
        'theme': theme,
        'character_details': {
            'name': character_name,
            'age': age,
            'gender': character_gender,
        }
    }

    try:
        response = requests.post(
            'http://127.0.0.1:5000/generate-story',
            json=payload,
            timeout=30
        )

        if response.status_code == 200:
            data = response.json()
            story_text = data.get('story', '')
            word_count = count_words(story_text)
            return word_count, True
        else:
            print(f"Failed to generate story: {response.status_code} - {response.text}")
            return 0, False
    except Exception as e:
        print(f"Error generating story: {e}")
        return 0, False

def main():
    """Test story length enforcement for all age groups."""
    results = {}

    print("🧪 Story Length Validation Test")
    print("=" * 50)

    for age_group in AGE_GROUPS:
        group_name = age_group['name']
        age = age_group['age']
        min_words = age_group['min_words']
        max_words = age_group['max_words']

        print(f"\n📚 Testing {group_name} (Age {age}, {min_words}-{max_words} words)")

        successful_stories = 0
        word_counts = []

        # Generate 5 stories per age group
        for i in range(5):
            theme = THEMES[i % len(THEMES)]
            character = CHARACTERS[i % len(CHARACTERS)]

            print(f"  Generating story {i+1}/5: {character['name']} + {theme}...")

            word_count, success = generate_story(
                age, theme, character['name'], character['gender']
            )

            if success:
                word_counts.append(word_count)
                successful_stories += 1
                print(f"    ✅ {word_count} words")
            else:
                print("    ❌ Failed to generate")

        # Analyze results
        if successful_stories > 0:
            avg_words = sum(word_counts) / len(word_counts)
            min_actual = min(word_counts)
            max_actual = max(word_counts)

            # Check if all stories are within limits
            within_limits = all(min_words <= wc <= max_words for wc in word_counts)

            status = "✅ PASS" if within_limits else "❌ FAIL"
            print(f"\n  Results: {status}")
            print(f"    Generated: {successful_stories}/5 stories")
            print(f"    Word count range: {min_actual}-{max_actual} (target: {min_words}-{max_words})")
            print(f"    Average: {avg_words:.1f} words")
            # Store results
            results[group_name] = {
                'success_rate': successful_stories / 5,
                'within_limits': within_limits,
                'word_counts': word_counts,
                'avg_words': avg_words
            }
        else:
            print("  ❌ No stories generated successfully")
            results[group_name] = {'success_rate': 0, 'within_limits': False}

    # Final summary
    print("\n" + "=" * 50)
    print("📊 FINAL RESULTS SUMMARY")
    print("=" * 50)

    all_passed = True
    for group_name, data in results.items():
        age_group = next(g for g in AGE_GROUPS if g['name'] == group_name)
        status = "✅ PASS" if data['within_limits'] and data['success_rate'] == 1.0 else "❌ FAIL"
        print(f"{status} {group_name}: {data['success_rate']*100:.0f}% success, limits: {data['within_limits']}")

        if not (data['within_limits'] and data['success_rate'] == 1.0):
            all_passed = False

    overall_status = "🎉 ALL TESTS PASSED" if all_passed else "⚠️  SOME TESTS FAILED"
    print(f"\n{overall_status}")

    if not all_passed:
        print("\nRecommendations:")
        print("- Check story generation prompts for word count enforcement")
        print("- Verify age-appropriate content filtering")
        print("- Review Gemini API response processing")

    return all_passed

if __name__ == "__main__":
    success = main()
    exit(0 if success else 1)