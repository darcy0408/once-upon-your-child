"""
Test Gemini image generation with text-based approach
"""
import os
import sys
from dotenv import load_dotenv
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

load_dotenv()

# Test if we can use Gemini for text generation instead of image generation
import google.generativeai as genai

api_key = os.getenv("GEMINI_API_KEY")
if not api_key:
    print("No Gemini API key found")
    exit(1)

print("Testing Gemini text generation...")
genai.configure(api_key=api_key)

try:
    # Use regular Gemini model for text generation
    model = genai.GenerativeModel("gemini-1.5-flash")
    
    # Test simple text generation
    response = model.generate_content("Write a short description of a happy child reading a book")
    
    if response and response.text:
        print("SUCCESS: Gemini text generation working!")
        print(f"Response: {response.text[:100]}...")
    else:
        print("No response from Gemini")
        
except Exception as e:
    print(f"Error: {e}")
    import traceback
    traceback.print_exc()