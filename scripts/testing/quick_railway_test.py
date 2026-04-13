#!/usr/bin/env python3
"""
Quick Railway Test - Custom Elements
"""
import requests
import json

url = "https://story-weaver-app-production.up.railway.app"

# Test health
print("Testing health...")
response = requests.get(f"{url}/health")
print(f"Health: {response.status_code}")
if response.status_code == 200:
    print(response.json())

# Test custom elements story
print("\nTesting custom elements story...")
payload = {
    "character": {
        "name": "Alex",
        "age": 10,
        "personality": "brave",
        "background": "warrior"
    },
    "customElements": [
        {
            "type": "item",
            "name": "magic sword",
            "description": "a glowing sword with magical powers"
        },
        {
            "type": "creature",
            "name": "dragon",
            "description": "a mighty fire-breathing dragon"
        }
    ],
    "theme": "fantasy",
    "length": "short"
}

response = requests.post(f"{url}/generate-story", json=payload, timeout=60)
print(f"Story generation: {response.status_code}")
if response.status_code == 200:
    data = response.json()
    story = data.get("story", "")
    print(f"Story length: {len(story)} characters")
    print(f"Title: {data.get('title', 'No title')}")
    print("Custom elements check:")
    print(f"  Magic sword: {'sword' in story.lower()}")
    print(f"  Dragon: {'dragon' in story.lower()}")
    print(f"\nStory preview: {story[:200]}...")
else:
    print(f"Error: {response.text}")