"""
Check Nano Banana pricing on OpenRouter
"""
import os
import requests
from dotenv import load_dotenv

load_dotenv()

api_key = os.getenv("OPENROUTER_API_KEY")
if not api_key:
    print("No API key found")
    exit(1)

print("Checking Nano Banana pricing on OpenRouter...")

try:
    response = requests.get(
        "https://openrouter.ai/api/v1/models",
        headers={
            "Authorization": f"Bearer {api_key}",
        }
    )
    
    if response.status_code == 200:
        models = response.json()
        
        # Look specifically for Nano Banana models
        nano_models = []
        for model in models.get('data', []):
            model_id = model.get('id', '')
            model_name = model.get('name', '')
            
            if 'nano' in model_id.lower() or 'nano' in model_name.lower() or 'banana' in model_name.lower():
                pricing = model.get('pricing', {})
                nano_models.append({
                    'id': model_id,
                    'name': model_name,
                    'prompt_cost': pricing.get('prompt', 'N/A'),
                    'completion_cost': pricing.get('completion', 'N/A'),
                    'image_cost': pricing.get('image', 'N/A'),
                    'context_length': model.get('context_length', 0)
                })
        
        print(f"\nFound {len(nano_models)} Nano Banana related models:")
        for model in nano_models:
            print(f"\nModel: {model['id']}")
            print(f"  Name: {model['name']}")
            print(f"  Prompt: ${model['prompt_cost']}")
            print(f"  Completion: ${model['completion_cost']}")
            print(f"  Image: ${model['image_cost']}")
            print(f"  Context: {model['context_length']}")
            
        # Also check the specific model we're using
        print(f"\n" + "="*50)
        print("Checking our specific model: google/gemini-2.5-flash-image")
        
        for model in models.get('data', []):
            if model.get('id') == 'google/gemini-2.5-flash-image':
                pricing = model.get('pricing', {})
                print(f"Found it!")
                print(f"  Name: {model.get('name', 'N/A')}")
                print(f"  Prompt: ${pricing.get('prompt', 'N/A')}")
                print(f"  Completion: ${pricing.get('completion', 'N/A')}")
                print(f"  Image: ${pricing.get('image', 'N/A')}")
                break
        else:
            print("Model not found in list!")
            
    else:
        print(f"Error: {response.status_code} - {response.text}")
        
except Exception as e:
    print(f"Error: {e}")
    import traceback
    traceback.print_exc()