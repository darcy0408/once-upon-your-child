import requests
import json

# Test creating a character with pets
url = "http://localhost:5000/create-character"
data = {
    "name": "Test Pet Owner",
    "age": 8,
    "gender": "Girl",
    "role": "Adventurer",
    "pets": [
        {
            "name": "Fluffy",
            "species": "Cat",
            "personality": "Playful and curious"
        }
    ]
}

print("Creating character with pet...")
print(f"Request data: {json.dumps(data, indent=2)}")
print()

response = requests.post(url, json=data)
print(f"Response status: {response.status_code}")
print(f"Response body: {json.dumps(response.json(), indent=2)}")

# Now get the character to verify pets were saved
if response.status_code == 201:
    char_id = response.json().get('id')
    get_url = f"http://localhost:5000/characters/{char_id}"
    get_response = requests.get(get_url)
    print(f"\nGET character response:")
    print(f"Status: {get_response.status_code}")
    print(f"Body: {json.dumps(get_response.json(), indent=2)}")
