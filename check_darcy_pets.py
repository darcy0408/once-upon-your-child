import sys
sys.path.append('backend')

from backend.config import create_app
from backend.models.character import Character
from backend.repositories.character_repository import get_all_characters
import json

# Get all Darcy characters
all_chars = get_all_characters()
darcy_chars = [c for c in all_chars if 'Darcy' in c.name]

print(f"Found {len(darcy_chars)} Darcy characters:\n")
for char in darcy_chars:
    print(f"Name: {char.name}")
    print(f"ID: {char.id}")
    print(f"Pets: {json.dumps(char.pets, indent=2)}")
    print(f"Role: {char.role}")
    print("-" * 50)
