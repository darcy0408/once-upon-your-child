import json
with open('quality_check_results/20260220_123332/age11-13_standard.json', 'r', encoding='utf-8') as f:
    data = json.load(f)
    story_text = data['story']['story_text']
    print(f"Char 3555: {story_text[3550:3600]}")
    # Also find line 21
    lines = story_text.splitlines()
    if len(lines) >= 21:
        print(f"Line 21: {lines[20]}")
