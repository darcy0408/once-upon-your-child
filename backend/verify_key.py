import os
import time
from dotenv import load_dotenv
from google import genai

load_dotenv()


def verify_setup():
    api_key = os.getenv("GEMINI_API_KEY")
    model_name = os.getenv("GEMINI_MODEL", "gemini-2.5-flash")

    print(f"--- Verifying Setup for {model_name} ---")
    if not api_key:
        print("❌ Error: GEMINI_API_KEY missing in .env")
        return

    client = genai.Client(api_key=api_key)

    for attempt in range(3):
        try:
            print(f"Attempt {attempt + 1}: Testing connectivity...")
            response = client.models.generate_content(
                model=model_name, contents="Reply with 'System Online'."
            )
            print(f"✅ Success! Response: {response.text}")
            return
        except Exception as e:
            if "429" in str(e):
                print("☕ Rate limited (429). Waiting 20 seconds...")
                time.sleep(20)
            else:
                print(f"❌ Error: {e}")
                break


if __name__ == "__main__":
    verify_setup()
