"""
Hotfix for production image generation
This can be deployed as a separate service or used to patch the existing deployment
"""
import os
import requests
import base64
import uuid
from datetime import datetime

class HotfixOpenRouterImageGenerator:
    def __init__(self, api_key=None):
        self.api_key = api_key or os.getenv("OPENROUTER_API_KEY")
        self.base_url = "https://openrouter.ai/api/v1"

    def generate_story_illustration(self, scene_description: str, character_name: str = "the hero", 
                                  style: str = "children's book illustration", num_images: int = 1, 
                                  age: int = 7, therapeutic_focus: str = None, **kwargs) -> list:
        """Fixed image generation using correct OpenRouter model"""
        
        prompt = f"""
{style}, high quality digital art:

{scene_description}

Main character: {character_name}

Style: colorful, vibrant, child-friendly, professional illustration, ages {age}, engaging, imaginative, no text, clean composition
""".strip()

        images = []
        for i in range(num_images):
            try:
                response = requests.post(
                    f"{self.base_url}/chat/completions",
                    headers={
                        "Authorization": f"Bearer {self.api_key}",
                        "HTTP-Referer": "https://story-weaver-app-production.up.railway.app",
                        "X-Title": "Story Weaver App",
                        "Content-Type": "application/json",
                    },
                    json={
                        "model": "google/gemini-2.5-flash-image",  # FIXED MODEL NAME
                        "modalities": ["image", "text"],
                        "max_tokens": 1000,
                        "messages": [{"role": "user", "content": prompt}],
                    },
                    timeout=60,
                )

                if response.status_code == 200:
                    data = response.json()
                    
                    # Extract image URL
                    image_url = None
                    try:
                        content = data['choices'][0]['message']['content']
                        if content and content.strip().startswith("data:image/"):
                            image_url = content.strip()
                    except (KeyError, IndexError):
                        pass

                    if not image_url:
                        try:
                            raw_images = data['choices'][0]['message'].get('images', [])
                            if raw_images:
                                img_data = raw_images[0]
                                if isinstance(img_data, str):
                                    image_url = img_data
                                elif isinstance(img_data, dict):
                                    if 'url' in img_data:
                                        image_url = img_data['url']
                                    elif 'image_url' in img_data and 'url' in img_data['image_url']:
                                        image_url = img_data['image_url']['url']
                        except (KeyError, IndexError):
                            pass

                    if image_url:
                        images.append({
                            'id': f"{uuid.uuid4()}_{i}",
                            'prompt': prompt,
                            'image_url': image_url,
                            'format': 'png',
                            'generated_at': datetime.now().isoformat(),
                        })
                        
            except Exception as e:
                print(f"Error generating image {i + 1}: {e}")

        return images

# Test the hotfix
if __name__ == "__main__":
    generator = HotfixOpenRouterImageGenerator()
    result = generator.generate_story_illustration(
        scene_description="A happy child with a red balloon",
        character_name="Emma",
        num_images=1
    )
    print(f"Hotfix test: {len(result)} images generated")
    if result:
        print("SUCCESS: Hotfix working!")
    else:
        print("FAILED: Hotfix not working")