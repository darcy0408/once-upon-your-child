import unittest
import requests
import json
import time
import os
import sys

# Add project root to path
sys.path.append(os.path.abspath(os.path.join(os.path.dirname(__file__), '..')))

BASE_URL = "http://localhost:5000"

# Skip all tests in this file unless RUN_LIVE_TESTS=1 (requires running backend)
_server_available = os.environ.get('RUN_LIVE_TESTS') == '1'


class TestBackendInteractiveFlow(unittest.TestCase):
    def setUp(self):
        self.user_id = "test_user_flow"
        self.character_name = "FlowTester"

    @unittest.skipUnless(_server_available, "Live server not running (set RUN_LIVE_TESTS=1)")
    def test_full_interactive_adventure(self):
        """
        Simulates a user playing a full interactive adventure.
        1. Start Story
        2. Make choices until end
        3. Verify state updates and inventory
        """
        print("\n=== STARTING FULL INTERACTIVE ADVENTURE TEST ===")
        
        # 1. Start Story
        payload = {
            "user_id": self.user_id,
            "theme": "Magic",
            "length": "short", # 3-4 segments
            "age": 8,
            "character": {
                "name": self.character_name,
                "age": 8
            }
        }
        
        response = requests.post(f"{BASE_URL}/generate-interactive-story", json=payload)
        
        if response.status_code != 200:
            print(f"FAILED to start story: {response.text}")
            return
            
        self.assertEqual(response.status_code, 200)
        data = response.json()
        
        story_id = data['story_id']
        segment = data['segment']
        print(f"Story Started: ID={story_id}")
        print(f"Segment 1: {segment['title']}")
        
        current_segment = segment
        segment_count = 1
        max_segments = 10 # Safety break
        
        while not data.get('is_completed', False) and segment_count < max_segments:
            # Verify we have choices
            choices = segment.get('choices', [])
            if not choices and not data.get('is_completed'):
                 print("ERROR: No choices found in non-ending segment!")
                 break
            
            # Pick first choice
            choice = choices[0]
            print(f"--> Choosing: {choice['text']} (ID: {choice['id']})")
            
            # Send choice
            cont_payload = {
                "story_id": story_id,
                "choice_id": choice['id']
            }
            
            # Wait a bit to avoid rate limits if using real API
            time.sleep(1)
            
            resp = requests.post(f"{BASE_URL}/continue-interactive-story", json=cont_payload)
            self.assertEqual(resp.status_code, 200)
            
            data = resp.json()
            segment = data['segment']
            segment_count += 1
            
            print(f"Segment {segment['segment_number']}: {segment['content'][:50]}...")
            
            # Check Inventory
            inventory = data.get('inventory', [])
            if inventory:
                print(f"   Inventory: {[i['name'] for i in inventory]}")
                
            # Check State
            state = data.get('state', {})
            if state:
                print(f"   Location: {state.get('current_location')}")

        self.assertTrue(data.get('is_completed'), "Story should be marked as completed")
        print(f"=== STORY COMPLETED IN {segment_count} SEGMENTS ===")

if __name__ == '__main__':
    unittest.main()
