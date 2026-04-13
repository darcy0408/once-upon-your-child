import re
import json
from pathlib import Path

def extract_prompts(file_path):
    content = Path(file_path).read_text(encoding='utf-8')
    tasks = []
    
    # Extract based on common patterns in the report
    
    # 1. animal_whisperer
    bands = {
        "Explorer (6-8)": "assets/images/archetypes/explorer/animal_whisperer.png",
        "Adventurer (9-11)": "assets/images/archetypes/adventurer/animal_whisperer.png",
        "Adolescent (12-14)": "assets/images/archetypes/adolescent/animal_whisperer.png",
        "Adult/Creator (15-17+)": ["assets/images/archetypes/adult/animal_whisperer.png", "assets/images/archetypes/creator/animal_whisperer.png"]
    }
    
    for band_name, paths in bands.items():
        pattern = rf"Replacement prompt \u2014 {re.escape(band_name)}:\n(.*?)(?=\n\n|\nReplacement prompt|\n###)"
        match = re.search(pattern, content, re.DOTALL)
        if match:
            prompt = match.group(1).strip()
            if isinstance(paths, list):
                for p in paths:
                    tasks.append({"output_path": p, "prompt": prompt})
            else:
                tasks.append({"output_path": paths, "prompt": prompt})

    # 2. Scenarios
    scenarios = {
        "imagine_it_btn.png and safe_space.png": ["assets/images/scenarios/imagine_it_btn.png", "assets/images/scenarios/safe_space.png"],
        "mystery.png": ["assets/images/scenarios/mystery.png"],
        "survival.png": ["assets/images/scenarios/survival.png"]
    }
    for key, paths in scenarios.items():
        pattern = rf"### {re.escape(key)}.*?\n\n.*?\n\nReplacement prompt:\n(.*?)(?=\n\n|\n###)"
        match = re.search(pattern, content, re.DOTALL)
        if match:
            prompt = match.group(1).strip()
            for p in paths:
                tasks.append({"output_path": p, "prompt": prompt})

    # 3. Scenes
    scenes = {
        "explorer/enchanted_forest.jpg": "assets/images/scenes/explorer/enchanted_forest.jpg",
        "adolescent/orbital_station.jpg": "assets/images/scenes/adolescent/orbital_station.jpg"
    }
    for key, path in scenes.items():
        pattern = rf"### {re.escape(key)}.*?\n\n.*?\n\nReplacement prompt:\n(.*?)(?=\n\n|\n###)"
        match = re.search(pattern, content, re.DOTALL)
        if match:
            prompt = match.group(1).strip()
            tasks.append({"output_path": path, "prompt": prompt})

    # 4. Backgrounds - Splash
    splashes = {
        "sprout/splash_bg.jpg": "assets/images/backgrounds/sprout/splash_bg.jpg",
        "adventurer/splash_bg.jpg": "assets/images/backgrounds/adventurer/splash_bg.jpg",
        "adolescent/splash_bg.jpg": "assets/images/backgrounds/adolescent/splash_bg.jpg",
        "adult/splash_bg.jpg": "assets/images/backgrounds/adult/splash_bg.jpg"
    }
    for key, path in splashes.items():
        pattern = rf"### {re.escape(key)}.*?\n\n.*?\n\nReplacement prompt:\n(.*?)(?=\n\n|\n###)"
        match = re.search(pattern, content, re.DOTALL)
        if match:
            prompt = match.group(1).strip()
            tasks.append({"output_path": path, "prompt": prompt})

    # 5. Themes
    themes = {
        "adventure.png": "assets/images/themes/adventure.png",
        "magic.png": "assets/images/themes/magic.png"
    }
    for key, path in themes.items():
        pattern = rf"Replacement prompt \({re.escape(key)}\):\n(.*?)(?=\n\n|\nReplacement prompt|\n###)"
        match = re.search(pattern, content, re.DOTALL)
        if match:
            prompt = match.group(1).strip()
            tasks.append({"output_path": path, "prompt": prompt})

    # 6. Root Legacy
    root_images = {
        "cat.png": "assets/images/cat.png"
    }
    for key, path in root_images.items():
        pattern = rf"### {re.escape(key)}.*?\n\n.*?\n\nReplacement prompt:\n(.*?)(?=\n\n|\n###)"
        match = re.search(pattern, content, re.DOTALL)
        if match:
            prompt = match.group(1).strip()
            tasks.append({"output_path": path, "prompt": prompt})

    # 7. Safety Flags - CRITICAL
    criticals = {
        "assets/images/backgrounds/adolescent/story_page_bg.jpg": "assets/images/backgrounds/adolescent/story_page_bg.jpg"
    }
    for key, path in criticals.items():
        pattern = rf"### CRITICAL \u2014 {re.escape(key)}.*?\n\nReplacement prompt:\n(.*?)(?=\n\n|\n###)"
        match = re.search(pattern, content, re.DOTALL)
        if match:
            prompt = match.group(1).strip()
            tasks.append({"output_path": path, "prompt": prompt})

    return tasks

if __name__ == "__main__":
    tasks = extract_prompts("full_image_audit_report.md")
    with open("priority_image_tasks.json", "w", encoding='utf-8') as f:
        json.dump(tasks, f, indent=2)
    print(f"Extracted {len(tasks)} priority tasks.")
