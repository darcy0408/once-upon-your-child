import os
import json
from google import genai
from google.genai import types

# FORCED UPDATE - MARCH 2026
API_KEY = "YOUR_GEMINI_API_KEY" # <--- PUT YOUR KEY HERE
BASE_DIR = "age_band_assets"
MODEL_ID = "gemini-3-flash" 
CACHE_FILE = "audit_cache.json"

client = genai.Client(api_key=API_KEY)

def load_cache():
    if os.path.exists(CACHE_FILE):
        with open(CACHE_FILE, 'r', encoding='utf-8') as f:
            return json.load(f)
    return {}

def save_cache(cache):
    with open(CACHE_FILE, 'w', encoding='utf-8') as f:
        json.dump(cache, f, indent=4)

def audit_file(file_path, cache):
    if file_path in cache: return
    print(f"Auditing: {file_path}...")
    try:
        with open(file_path, 'rb') as f:
            image_data = f.read()
        ext = os.path.splitext(file_path)[1].lower()
        mime_type = 'image/jpeg' if ext in ['.jpg', '.jpeg'] else 'image/png'
        response = client.models.generate_content(
            model=MODEL_ID,
            contents=[
                "Audit this Story Weaver asset for child safety. Reply SAFE or REJECT.",
                types.Part.from_bytes(data=image_data, mime_type=mime_type)
            ]
        )
        cache[file_path] = response.text.strip()
        print(f"Result: {cache[file_path]}")
    except Exception as e:
        print(f"Error: {e}")

def main():
    if not os.path.exists(BASE_DIR): return
    cache = load_cache()
    try:
        for root, _, files in os.walk(BASE_DIR):
            for file in files:
                if file.lower().endswith(('.png', '.jpg', '.jpeg')):
                    audit_file(os.path.join(root, file), cache)
    finally:
        save_cache(cache)
        print("Done.")

if __name__ == '__main__':
    main()
