import os
import google.generativeai as genai
from dotenv import load_dotenv

load_dotenv()

api_key = os.getenv('GEMINI_API_KEY')
print(f"Key present: {bool(api_key)}")

genai.configure(api_key=api_key)
model_name = 'gemini-2.0-flash-exp'

print(f"Testing model: {model_name}")

try:
    model = genai.GenerativeModel(model_name)
    response = model.generate_content("Write a one sentence story about a cat.")
    print(f"Success! Response: {response.text}")
except Exception as e:
    print(f"Error: {e}")
