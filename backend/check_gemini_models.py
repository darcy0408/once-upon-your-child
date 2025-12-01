"""
Check available Gemini models
"""
import os
import google.generativeai as genai
from dotenv import load_dotenv

load_dotenv()

api_key = os.getenv("GEMINI_API_KEY")
if not api_key:
    print("No Gemini API key found")
    exit(1)

print("Checking available Gemini models...")
genai.configure(api_key=api_key)

try:
    models = genai.list_models()
    
    print("Available models:")
    for model in models:
        print(f"  {model.name}")
        print(f"    Display name: {model.display_name}")
        print(f"    Supported methods: {model.supported_generation_methods}")
        print()
        
except Exception as e:
    print(f"Error: {e}")
    import traceback
    traceback.print_exc()