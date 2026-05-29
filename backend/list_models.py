from google import genai
import os

c = genai.Client(api_key=os.getenv("GEMINI_API_KEY"))
for m in c.models.list():
    if "image" in m.name.lower() or "imagen" in m.name.lower():
        print(m.name, getattr(m, "supported_actions", ""))
