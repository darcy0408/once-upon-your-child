import json
import re

def _safe_extract_title_and_gem(text: str, theme: str):
    """Extract title, wisdom gem, and pages from LLM JSON response."""
    clean_text = text.strip()

    # Strip markdown code blocks (```json ... ```)
    clean_text = re.sub(r"^\s*```(?:json)?\s*\n?", "", clean_text, flags=re.IGNORECASE)
    clean_text = re.sub(r"\n?\s*```\s*$", "", clean_text, flags=re.IGNORECASE)

    # Strip markdown bold markers (**) that some LLMs wrap around JSON
    clean_text = re.sub(r"^\s*\*\*\s*", "", clean_text)
    clean_text = re.sub(r"\s*\*\*\s*$", "", clean_text)

    # Save candidate text for fallback (prose mode)
    candidate_text = clean_text

    # Try to locate JSON object
    json_start = clean_text.find('{')
    json_end = clean_text.rfind('}')
    
    sliced_text = clean_text
    if json_start >= 0 and json_end > json_start:
        sliced_text = clean_text[json_start:json_end + 1]

    def _parse_story_data(json_str):
        data = json.loads(json_str)
        title = data.get("title", f"A {theme} Adventure")
        pages_input = data.get("pages", [])
        post_story = data.get("post_story", {})
        wisdom_gem = post_story.get("wisdom_gem") or "You are magic!"

        pages = []
        if isinstance(pages_input, str):
            pages = [pages_input]
        elif isinstance(pages_input, dict):
            # Handle single page as a dict
            page_text = pages_input.get("text", "")
            if page_text:
                pages = [page_text]
        elif isinstance(pages_input, list):
            for p in pages_input:
                if isinstance(p, dict):
                    page_text = p.get("text", "")
                    if page_text:
                        pages.append(page_text)
                elif isinstance(p, str) and p.strip():
                    pages.append(p)

        # If valid JSON but missing 'pages', check for 'story' or 'story_text'
        if not pages:
             if 'story' in data and isinstance(data['story'], str):
                 pages = [data['story']]
             elif 'story_text' in data and isinstance(data['story_text'], str):
                 pages = [data['story_text']]
        
        return title, wisdom_gem, pages, post_story

    try:
        # 1. Try to parse the sliced text (most likely JSON candidate)
        return _parse_story_data(sliced_text)
    except Exception as e:
        print(f"Error parsing: {e}")
        return f"A {theme} Adventure", "You are magic!", [candidate_text], {}

# Test with content from age11-13_standard.json
with open('quality_check_results/20260220_123332/age11-13_standard.json', 'r', encoding='utf-8') as f:
    data = json.load(f)
    story_text = data['story']['story_text']
    
    print("Attempting to parse story_text...")
    title, gem, pages, post = _safe_extract_title_and_gem(story_text, "The Brave Little Firefly")
    print(f"Title: {title}")
    print(f"Pages count: {len(pages)}")
    if len(pages) > 0:
        print(f"First page start: {pages[0][:50]}")
