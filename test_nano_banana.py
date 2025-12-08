#!/usr/bin/env python3
"""
Quick test to verify Nano Banana (gemini-2.5-flash-image) works with our API key
"""
import os
import sys
from dotenv import load_dotenv
import google.generativeai as genai

# Load API key
load_dotenv(dotenv_path='backend/.env')
api_key = os.getenv('GEMINI_API_KEY')

if not api_key:
    print("❌ No GEMINI_API_KEY found in backend/.env")
    sys.exit(1)

print(f"✓ API Key loaded: {api_key[:5]}...{api_key[-4:]}")

# Configure Gemini
genai.configure(api_key=api_key)

# Test Nano Banana
print("\n📸 Testing Nano Banana (gemini-2.5-flash-image)...")
try:
    model = genai.GenerativeModel("gemini-2.5-flash-image")
    print(f"✓ Model initialized: {model.model_name}")
    
    # Try to generate a simple test image
    prompt = "A simple, colorful illustration of a happy cat playing with a ball of yarn. Children's book style."
    print(f"\n🎨 Generating test image with prompt: {prompt[:80]}...")
    
    response = model.generate_content(prompt)
    
    print(f"\n📋 Response structure:")
    print(f"  - Has candidates: {hasattr(response, 'candidates')}")
    if hasattr(response, 'candidates'):
        print(f"  - Number of candidates: {len(response.candidates) if response.candidates else 0}")
        if response.candidates:
            candidate = response.candidates[0]
            print(f"  - Candidate has content: {hasattr(candidate, 'content')}")
            if hasattr(candidate, 'content'):
                print(f"  - Content has parts: {hasattr(candidate.content, 'parts')}")
                if hasattr(candidate.content, 'parts'):
                    print(f"  - Number of parts: {len(candidate.content.parts)}")
                    for i, part in enumerate(candidate.content.parts):
                        print(f"\n  📦 Part {i}:")
                        print(f"     - Has inline_data: {hasattr(part, 'inline_data')}")
                        print(f"     - Has mime_type: {hasattr(part, 'mime_type')}")
                        print(f"     - Has text: {hasattr(part, 'text')}")
                        if hasattr(part, 'inline_data') and part.inline_data:
                            data_len = len(part.inline_data.data) if hasattr(part.inline_data, 'data') else 0
                            print(f"     - Image data size: {data_len} bytes")
                            if data_len > 0:
                                print(f"     ✅ IMAGE FOUND!")
                        if hasattr(part, 'text') and part.text:
                            print(f"     - Text: {part.text[:100]}")
    
    print("\n" + "="*60)
    print("✅ Test completed successfully!")
    
except Exception as e:
    print(f"\n❌ Error: {e}")
    import traceback
    traceback.print_exc()
    sys.exit(1)
