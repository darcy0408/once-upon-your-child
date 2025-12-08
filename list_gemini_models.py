import os
import google.generativeai as genai

# !!! IMPORTANT !!!
# Replace 'YOUR_GEMINI_API_KEY' with your actual Gemini API Key.
# You can find this in your Railway project's environment variables.
# Do NOT commit your API key to source control.
from dotenv import load_dotenv

load_dotenv(dotenv_path='backend/.env')
GEMINI_API_KEY = os.getenv('GEMINI_API_KEY')
print(f"DEBUG: Loaded API Key: {GEMINI_API_KEY[:5]}...{GEMINI_API_KEY[-4:] if GEMINI_API_KEY else ''}")
print(f"DEBUG: Current working directory: {os.getcwd()}")

if not GEMINI_API_KEY or GEMINI_API_KEY == "YOUR_GEMINI_API_KEY":
    print("Error: Please replace 'YOUR_GEMINI_API_KEY' with your actual API key.")
    exit()

genai.configure(api_key=GEMINI_API_KEY)

print("Listing available Gemini models:")
for m in genai.list_models():
    # Only show models that support text generation (generateContent)
    if "generateContent" in m.supported_generation_methods:
        print(f"  Name: {m.name}")
        print(f"  Display Name: {m.display_name}")
        print(f"  Version: {m.version}")
        print(f"  Supported Methods: {m.supported_generation_methods}")
        print("-" * 20)
