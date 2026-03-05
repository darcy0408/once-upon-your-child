
import sys
import os
import json
import logging

# Add project root to sys.path
sys.path.append(os.path.abspath(os.path.join(os.path.dirname(__file__), '../..')))

from backend.app import create_app
from backend.database import db

def run_test():
    # Configure logging
    logging.basicConfig(level=logging.INFO)
    print("--- Starting Manual Auth & Persistence Test ---")

    # Initialize App in Testing Mode
    app = create_app('testing')
    
    with app.test_client() as client:
        # Create context to access database
        with app.app_context():
            print("Creating database tables...")
            db.create_all()

            # Test 2.1: Create Character with Auth
            print("\nStep 1: Authenticate as Anonymous User")
            auth_resp = client.post('/auth/anonymous')
            if auth_resp.status_code != 200:
                print(f"❌ Auth failed: {auth_resp.get_json()}")
                return

            auth_data = auth_resp.get_json()
            token = auth_data.get('token') or auth_data.get('access_token')
            user_id = auth_data['user_id']
            print(f"✅ Authenticated. User ID: {user_id}")
            print(f"   Token: {token[:20]}...")

            print("\nStep 2: Create Character")
            character_data = {
                "name": "TestHero",
                "age": 7,
                "gender": "female",
                "personality_traits": ["brave", "curious"],
                "user_id": user_id
            }

            resp = client.post('/create-character',
                               data=json.dumps(character_data),
                               content_type='application/json',
                               headers={'Authorization': f'Bearer {token}'})

            if resp.status_code in [200, 201]:
                char = resp.get_json()
                CHARACTER_ID = char.get('id')
                print(f"✅ Character created: {CHARACTER_ID}")
                print(f"   Name: {char.get('name')}")
            else:
                print(f"❌ Create Character Failed: {resp.status_code}")
                print(f"   Response: {resp.get_json()}")
                return

            # Test 2.2: Retrieve Characters for User
            print("\nStep 3: Retrieve Characters (Persistence Check)")
            
            # Simulate 'Resume Session'
            print("   -> Resuming session with client_id...")
            resume_resp = client.post('/auth/anonymous', json={'client_id': user_id})
            resume_data = resume_resp.get_json()
            resume_token = resume_data.get('token') or resume_data.get('access_token')
            
            if resume_data['user_id'] != user_id:
                print(f"❌ Warning: Resumed user_id {resume_data['user_id']} does not match original {user_id}")
            else:
                print(f"✅ Session resumed successfully for {user_id}")

            print("   -> Fetching characters...")
            resp = client.get('/get-characters',
                              headers={'Authorization': f'Bearer {resume_token}'})

            if resp.status_code == 200:
                characters = resp.get_json()
                print(f"✅ Retrieved {len(characters)} character(s)")
                
                found = any(c['id'] == CHARACTER_ID for c in characters)
                if found:
                    print(f"✅ SUCCESS: Character {CHARACTER_ID} persisted and retrieved.")
                else:
                    print(f"❌ FAILURE: Character {CHARACTER_ID} NOT found in list.")
                    print("List:", json.dumps(characters, indent=2))
            else:
                print(f"❌ Retrieve Failed: {resp.status_code} - {resp.get_json()}")

if __name__ == "__main__":
    run_test()
