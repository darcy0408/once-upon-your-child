"""
Check available OpenRouter models
"""
import os
import requests
from dotenv import load_dotenv

load_dotenv()

api_key = os.getenv("OPENROUTER_API_KEY")
if not api_key:
    print("No API key found")
    exit(1)

print("Checking available OpenRouter models...")

try:
    response = requests.get(
        "https://openrouter.ai/api/v1/models",
        headers={
            "Authorization": f"Bearer {api_key}",
        }
    )
    
    if response.status_code == 200:
        models = response.json()
        print(f"Found {len(models.get('data', []))} models")
        
        # Look for image generation models
        image_models = []
        for model in models.get('data', []):
            model_id = model.get('id', '')
            if any(keyword in model_id.lower() for keyword in ['flux', 'dall', 'stable', 'midjourney', 'image']):
                image_models.append({
                    'id': model_id,
                    'name': model.get('name', ''),
                    'pricing': model.get('pricing', {}),
                    'context_length': model.get('context_length', 0)
                })
        
        print(f"\nFound {len(image_models)} potential image models:")
        for model in image_models[:10]:  # Show first 10
            pricing = model['pricing']
            prompt_cost = pricing.get('prompt', 'N/A')
            completion_cost = pricing.get('completion', 'N/A')
            print(f"  {model['id']}")
            print(f"    Name: {model['name']}")
            print(f"    Prompt: ${prompt_cost}, Completion: ${completion_cost}")
            print()
            
    else:
        print(f"Error: {response.status_code} - {response.text}")
        
except Exception as e:
    print(f"Error: {e}")
    import traceback
    traceback.print_exc()