
import os
import time
from pathlib import Path
from google import genai
from google.genai import types
from dotenv import load_dotenv

# Load environment variables
dotenv_path = Path('backend/.env')
if dotenv_path.exists():
    load_dotenv(dotenv_path=dotenv_path)
else:
    load_dotenv()

GEMINI_API_KEY = os.getenv('GEMINI_API_KEY')
client = genai.Client(api_key=GEMINI_API_KEY)
MODEL_NAME = 'models/imagen-4.0-generate-001'

def generate_sample(prompt, output_path):
    try:
        print(f"Generating sample: {output_path.name}")
        response = client.models.generate_images(
            model=MODEL_NAME,
            prompt=prompt,
            config=types.GenerateImagesConfig(
                number_of_images=1,
                output_mime_type='image/jpeg'
            )
        )
        if response.generated_images:
            image_bytes = response.generated_images[0].image.image_bytes
            output_path.parent.mkdir(parents=True, exist_ok=True)
            with open(output_path, 'wb') as f:
                f.write(image_bytes)
            print(f"Saved: {output_path}")
    except Exception as e:
        print(f"Error: {e}")

def main():
    base_dir = Path("style_samples")
    
    samples = [
        # STYLE A: MATURE CINEMATIC 3D
        ("3D_Hero.jpg", "Cinematic digital illustration, high-fidelity 3D render. A determined teenage hero with Middle Eastern features, sleek dark tactical gear with glowing blue energy lines, holding a sophisticated crystalline sword. Dramatic twilight city background with volumetric lighting. Mature proportions, atmospheric depth."),
        ("3D_Healer.jpg", "Cinematic digital illustration, high-fidelity 3D render. A serene teenage healer with East Asian features, wearing flowing ivory robes with glowing silver embroidery, hands emitting a soft ethereal golden light. Bioluminescent forest background, soft focus, high-end production quality."),
        
        # STYLE B: SOPHISTICATED GRAPHIC NOVEL
        ("Novel_Hero.jpg", "Graphic novel illustration, high-contrast ink work, charcoal tones with a single electric blue accent. A teenage hero with Middle Eastern features stands in a strong pose, the blue accent illuminating their eyes and the edge of a crystalline sword. Dramatic shadows, gritty texture, sophisticated and literary mood."),
        ("Novel_Healer.jpg", "Graphic novel illustration, high-contrast ink work, charcoal tones with a single warm gold accent. A teenage healer with East Asian features, hands cupped around a glowing golden flame that casts long shadows. Minimalist background, bold linework, mature and artistic aesthetic.")
    ]

    for filename, prompt in samples:
        generate_sample(prompt, base_dir / filename)
        time.sleep(20)

if __name__ == "__main__":
    main()
