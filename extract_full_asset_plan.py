import re
import json
from pathlib import Path

def extract_prompts_from_plan(file_path):
    content = Path(file_path).read_text(encoding='utf-8')
    tasks = []
    
    # Define the mapping from MD headers to band names
    band_mapping = {
        "Age Band 1: Toddlers (2-4)": "sprout",
        "Age Band 2: Early Readers (5-7)": "explorer",
        "Age Band 3: Older Children (8-12)": "adventurer"
    }
    
    # Split content by Age Band sections
    # Using a more robust regex for headers
    sections = re.split(r'## (Age Band \d+: .*?)\n', content)
    
    for i in range(1, len(sections), 2):
        band_header = sections[i].strip()
        band_content = sections[i+1]
        band_name = band_mapping.get(band_header)
        if not band_name:
            # Try partial match
            for key in band_mapping:
                if key in band_header:
                    band_name = band_mapping[key]
                    break
        
        if not band_name:
            continue
            
        print(f"Processing band: {band_name}")

        # Extract standard assets
        asset_pattern = r'#### (.*?)\n\n(.*?)\n\n```\n(.*?)\n```'
        for match in re.finditer(asset_pattern, band_content, re.DOTALL):
            name = match.group(1).strip()
            prompt = match.group(3).strip()
            
            paths = []
            if "Splash Screen Background" in name:
                paths.append(f"assets/images/backgrounds/{band_name}/splash_bg.jpg")
            elif "App Logo / Title Card" in name:
                paths.append(f"assets/images/ui/{band_name}/app_logo.png")
            elif "Name Input Screen — Decorative Frame" in name or "Name Input Frame" in name:
                paths.append(f"assets/images/ui/{band_name}/name_input_frame.png")
            elif "Age Selector Buttons" in name:
                ages = []
                if band_name == "sprout": ages = [3, 4, 5]
                elif band_name == "explorer": ages = [5, 6, 7]
                elif band_name == "adventurer": ages = [8, 9, 10, 11]
                
                for age in ages:
                    age_path = f"assets/images/ui/{band_name}/age_tile_{age}.png"
                    age_prompt = prompt.replace("numerals 3, 4, and 5", f"numeral {age}").replace("numeral 5, 6, and 7", f"numeral {age}")
                    tasks.append({"output_path": age_path, "prompt": age_prompt})
                continue
            elif "Primary CTA Button — \"MAKE MAGIC\" (Normal State)" in name:
                paths.append(f"assets/images/ui/{band_name}/make_magic_normal.png")
            elif "Primary CTA Button — \"MAKE MAGIC\" (Pressed State)" in name:
                paths.append(f"assets/images/ui/{band_name}/make_magic_pressed.png")
            elif "Primary CTA Button — \"START ADVENTURE\" (Normal State, Ages 9-11)" in name:
                paths.append(f"assets/images/ui/{band_name}/make_magic_normal.png")
            elif "Primary CTA Button — \"START ADVENTURE\" (Pressed State)" in name:
                paths.append(f"assets/images/ui/{band_name}/make_magic_pressed.png")
            elif "Primary CTA Button — \"CREATE STORY\" (Normal State, Ages 12+)" in name:
                for b in ["adolescent", "creator", "adult"]:
                    tasks.append({"output_path": f"assets/images/ui/{b}/make_magic_normal.png", "prompt": prompt})
                continue
            elif "Continue / Next Button" in name or "Continue Button" in name:
                paths.append(f"assets/images/ui/{band_name}/continue_button.png")
            elif "Progress Orb — Idle State" in name or "[IDLE]" in name:
                 paths.append(f"assets/images/orbs/{band_name}/progress_idle.png")
            elif "Progress Orb — Active State" in name or "[ACTIVE]" in name:
                 paths.append(f"assets/images/orbs/{band_name}/progress_active.png")
            elif "Progress Orb — Complete State" in name or "[COMPLETE]" in name:
                 paths.append(f"assets/images/orbs/{band_name}/progress_complete.png")
            elif "Story Page Background" in name:
                paths.append(f"assets/images/backgrounds/{band_name}/story_page_bg.jpg")
            elif "Adventure Choice Buttons" in name:
                paths.append(f"assets/images/ui/{band_name}/choice_button.png")
                
            for p in paths:
                tasks.append({"output_path": p, "prompt": prompt})

        # Specialized extractors for [NAME] blocks
        # We need to find the sections first to avoid mixing them up
        subsections = re.split(r'#### (.*?)\n', band_content)
        for j in range(1, len(subsections), 2):
            sub_header = subsections[j].strip()
            sub_content = subsections[j+1]
            
            folder = None
            if "Archetype Cards" in sub_header: folder = "archetypes"
            elif "Feeling Selection" in sub_header: folder = "feelings"
            elif "Companion" in sub_header: folder = "companions"
            elif "Scene Selection" in sub_header: folder = "scenes"
            elif "Progress Orbs" in sub_header: folder = "orbs" # Handle [IDLE] [ACTIVE] [COMPLETE] here too
            
            if folder:
                for match in re.finditer(r'```\n\[(.*?)\]\n(.*?)\n```', sub_content, re.DOTALL):
                    item_name = match.group(1).lower().replace(' ', '_')
                    item_prompt = match.group(2).strip()
                    
                    if folder == "orbs":
                        path = f"assets/images/orbs/{band_name}/progress_{item_name.lower()}.png"
                    elif folder == "scenes":
                        ext = ".jpg" if "landscape-format" in item_prompt.lower() else ".png"
                        path = f"assets/images/scenes/{band_name}/{item_name}{ext}"
                    else:
                        path = f"assets/images/{folder}/{band_name}/{item_name}.png"
                    
                    tasks.append({"output_path": path, "prompt": item_prompt})

    # Universal Assets
    universal_section = re.search(r'## Cross-Band Universal Assets\n(.*?)(?=\n##|\Z)', content, re.DOTALL)
    if universal_section:
        u_content = universal_section.group(1)
        for match in re.finditer(r'### (.*?)\n\n```\n(.*?)\n```', u_content, re.DOTALL):
            u_name = match.group(1)
            u_prompt = match.group(2).strip()
            path = None
            if "Loading Indicator" in u_name:
                path = "assets/images/ui/universal/loading_indicator.png"
            elif "Voice / Audio Active Indicator" in u_name:
                path = "assets/images/ui/universal/audio_active_indicator.png"
            elif "Microphone / Voice Input Button" in u_name:
                path = "assets/images/ui/universal/mic_button.png"
            
            if path:
                tasks.append({"output_path": path, "prompt": u_prompt})

    return tasks

if __name__ == "__main__":
    tasks = extract_prompts_from_plan("docs/GUI_AGE_BAND_ASSET_PLAN.md")
    # De-duplicate by output_path
    unique_tasks = {}
    for t in tasks:
        unique_tasks[t["output_path"]] = t["prompt"]
    
    final_tasks = [{"output_path": p, "prompt": pr} for p, pr in unique_tasks.items()]
    
    with open("full_plan_image_tasks.json", "w", encoding='utf-8') as f:
        json.dump(final_tasks, f, indent=2)
    print(f"Extracted {len(final_tasks)} unique tasks from the GUI Asset Plan.")
