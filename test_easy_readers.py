#!/usr/bin/env python3
"""
Easy Readers Mode Accessibility Test
Tests that learning_to_read_mode works for all age groups and produces appropriate content.
"""

import requests
import json
import re

# Age groups to test
AGE_GROUPS = [4, 7, 10, 14, 18]

def count_words(text):
    """Count words in text."""
    if not text:
        return 0
    words = re.findall(r'\b\w+\b', text)
    return len(words)

def check_rhyme_pattern(text):
    """Check if text follows AABB rhyme pattern."""
    lines = [line.strip() for line in text.split('\n') if line.strip()]
    # Simple check - look for rhyming words at end of lines
    # This is a basic check, not perfect rhyme detection
    rhyme_pairs = []
    for i in range(0, len(lines) - 1, 2):
        if i + 1 < len(lines):
            line1_end = lines[i].split()[-1] if lines[i].split() else ""
            line2_end = lines[i + 1].split()[-1] if lines[i + 1].split() else ""
            rhyme_pairs.append((line1_end.lower(), line2_end.lower()))

    # Check if at least 50% of pairs have some rhyme similarity
    rhyme_score = 0
    for word1, word2 in rhyme_pairs:
        if len(word1) > 2 and len(word2) > 2:
            # Simple rhyme check - last 2-3 letters similar
            if word1[-2:] == word2[-2:] or word1[-3:] == word2[-3:]:
                rhyme_score += 1

    return rhyme_score / max(1, len(rhyme_pairs))

def test_learning_to_read_mode():
    """Test learning to read mode for all age groups."""
    print("🧪 Easy Readers Mode Accessibility Test")
    print("=" * 50)

    results = {}

    for age in AGE_GROUPS:
        print(f"\n📚 Testing Age {age}")

        payload = {
            'character': f'Child{age}',
            'age': age,
            'gender': 'Other',
            'theme': 'Adventure',
            'learning_to_read_mode': True,
            'character_details': {
                'name': f'Child{age}',
                'age': age,
                'gender': 'Other',
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
                rhyme_score = check_rhyme_pattern(story_text)

                # Check requirements
                word_count_ok = 50 <= word_count <= 100
                rhyme_ok = rhyme_score >= 0.3  # At least 30% rhyme pairs

                status = "✅ PASS" if word_count_ok and rhyme_ok else "❌ FAIL"
                print(f"  {status}: {word_count} words, rhyme score: {rhyme_score:.2f}")

                results[age] = {
                    'success': True,
                    'word_count': word_count,
                    'word_count_ok': word_count_ok,
                    'rhyme_score': rhyme_score,
                    'rhyme_ok': rhyme_ok,
                    'overall_pass': word_count_ok and rhyme_ok
                }
            else:
                print(f"  ❌ API Error: {response.status_code}")
                results[age] = {'success': False, 'error': response.status_code}

        except Exception as e:
            print(f"  ❌ Exception: {e}")
            results[age] = {'success': False, 'error': str(e)}

    # Summary
    print("\n" + "=" * 50)
    print("📊 EASY READERS MODE RESULTS")
    print("=" * 50)

    all_passed = True
    for age, data in results.items():
        if data.get('success', False):
            status = "✅ PASS" if data.get('overall_pass', False) else "❌ FAIL"
            print(f"Age {age}: {status} ({data['word_count']} words, rhyme: {data['rhyme_score']:.2f})")
            if not data.get('overall_pass', False):
                all_passed = False
        else:
            print(f"Age {age}: ❌ ERROR - {data.get('error', 'Unknown')}")
            all_passed = False

    overall_status = "🎉 ALL AGES ACCESSIBLE" if all_passed else "⚠️  ACCESSIBILITY ISSUES"
    print(f"\n{overall_status}")

    if not all_passed:
        print("\nIssues found:")
        print("- Word count not within 50-100 range")
        print("- Insufficient rhyming pattern")
        print("- API errors or generation failures")

    return all_passed

if __name__ == "__main__":
    import sys
    success = test_learning_to_read_mode()
    sys.exit(0 if success else 1)