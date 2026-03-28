from google import genai
from google.genai import types
import os

# 1. SETUP - Using the API Key from your PowerShell environment
client = genai.Client(api_key=os.environ["GOOGLE_API_KEY"])
MODEL_ID = "imagen-4.0-generate-001" # Updated to available model
OUTPUT_DIR = "assets/images/feelings/sprout/"

# 2. STYLE DEFINITION - Matching your existing 8 images
STYLE_PREFIX = (
    "A 3D-rendered cute squishy blob character on a solid black background (#000000). "
    "The character is a soft, round bean shape with simple cartoon face features and small stubby arms. "
    "Subtle matching-color glow effect around the character. High quality, 512x512. "
)

# 3. DATA - The 12 missing feelings
missing_feelings = {
    "bothered": "Slightly greenish-yellow blob, annoyed expression, one eyebrow raised, arms crossed, small zigzag lines around head.",
    "bouncy": "Bright orange blob mid-bounce, huge grin, arms up, motion lines below, energetic sparkles.",
    "gloomy": "Dark blue-gray blob, droopy eyes looking down, small rain cloud above head, arms hanging limp.",
    "grossed_out": "Green blob, tongue sticking out, squinted eyes, one arm pushing away, small green stink waves.",
    "hurt_mad": "Reddish-purple blob, watery angry eyes, clenched fists, small bandage on the side.",
    "hyper": "Bright yellow-orange blob spinning, huge wide eyes, big grin, speed lines and stars.",
    "impatient": "Orange-yellow blob tapping one arm, furrowed brow, looking to the side, small clock nearby.",
    "let_down": "Pale blue blob, deflated posture, sagging shape, sad eyes looking to side, small fallen star nearby.",
    "red_faced": "Bright red blob, embarrassed expression, hands covering cheeks, small sweat drops.",
    "stuck": "Gray-brown blob, confused expression, arms pushing against invisible walls, question mark above head.",
    "what_if_y": "Pale purple blob, wide worried eyes looking up, thought bubbles with question marks, arms hugging self.",
    "wish_i_could_hide": "Soft blue-green blob partially hiding behind a corner, only peeking eyes visible, shy expression."
}

# 4. EXECUTION LOOP
if not os.path.exists(OUTPUT_DIR):
    os.makedirs(OUTPUT_DIR)

for name, details in missing_feelings.items():
    file_path = os.path.join(OUTPUT_DIR, f"{name}.png")
    
    if os.path.exists(file_path):
        print(f"⏩ {name} already exists, skipping.")
        continue

    print(f"🎨 Generating {name}...")
    try:
        response = client.models.generate_images(
            model=MODEL_ID,
            prompt=STYLE_PREFIX + details,
            config=types.GenerateImagesConfig(
                output_mime_type="image/png",
                number_of_images=1
            )
        )
        
        # Save the bytes to the PNG file
        with open(file_path, "wb") as f:
            f.write(response.generated_images[0].image.image_bytes)
        print(f"✅ Saved: {file_path}")
        
    except Exception as e:
        print(f"❌ Failed to generate {name}: {e}")

print("\n✨ Generation complete. Check your sprout folder!")
