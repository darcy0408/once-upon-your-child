import os
import time
import logging
from pathlib import Path
from google import genai
from google.genai import types
from dotenv import load_dotenv

# Configure logging
logging.basicConfig(level=logging.INFO, format='%(asctime)s - %(levelname)s - %(message)s')
logger = logging.getLogger(__name__)

# Load environment variables
dotenv_path = Path('backend/.env')
if dotenv_path.exists():
    load_dotenv(dotenv_path=dotenv_path)
else:
    load_dotenv()

GEMINI_API_KEY = os.getenv('GEMINI_API_KEY')
client = genai.Client(api_key=GEMINI_API_KEY)
# Using the newer model if available, or fallback to the one used in other scripts
MODEL_NAME = 'models/imagen-4.0-generate-001'

def generate_image(prompt, output_path, format='PNG'):
    """Generate an image using the Imagen API with retry logic."""
    
    if output_path.exists():
        logger.info(f"Skipping {output_path.name} (Already exists)")
        return True

    while True:
        try:
            logger.info(f"Generating image: {output_path}")
            response = client.models.generate_images(
                model=MODEL_NAME,
                prompt=prompt,
                config=types.GenerateImagesConfig(
                    number_of_images=1,
                    output_mime_type='image/png' if format == 'PNG' else 'image/jpeg'
                )
            )
            
            if response.generated_images:
                image_bytes = response.generated_images[0].image.image_bytes
                output_path.parent.mkdir(parents=True, exist_ok=True)
                with open(output_path, 'wb') as f:
                    f.write(image_bytes)
                logger.info(f"Successfully saved to: {output_path}")
                return True
            else:
                logger.error(f"No image generated for: {output_path.name}")
                return False
                
        except Exception as e:
            error_msg = str(e)
            if '429' in error_msg or 'Too Many Requests' in error_msg:
                logger.warning("429 Too Many Requests. Waiting 60 seconds...")
                time.sleep(60)
                continue
            else:
                logger.error(f"Error generating {output_path.name}: {e}")
                time.sleep(10)
                return False

def main():
    assets = [
        # PART 1 — Sprouts Feelings
        ("age_band_assets/sprouts/feelings", "happy.png", "Pixar-style soft 3D rendered creature, perfectly round glowing body radiating warm golden-yellow light from within. Big wide crescent eyes curving upward like a smile, enormous open grin showing tiny rounded teeth. Stubby little arms raised high in celebration, body tilted slightly back with joy. Bright warm rim lighting, soft fill light. Subtle sparkle particles floating around it. Pure black background. 512×512. Hyper-cute, radiates infectious happiness, instantly readable emotion for a 3-year-old."),
        ("age_band_assets/sprouts/feelings", "sad.png", "Pixar-style soft 3D rendered creature, round body in muted dusty blue with a subtle inner glow dimmed down. Eyes are large, heavy-lidded, looking downward with glistening unshed tears. Tiny mouth curved into a small trembling frown. Stubby arms wrapped around itself in a self-hug. A single perfect tear rolling down one cheek catches a soft highlight. Body slightly deflated looking, slouched. Pure black background. 512×512. Deeply sympathetic, not scary, a child should want to hug it."),
        ("age_band_assets/sprouts/feelings", "angry.png", "Pixar-style soft 3D rendered creature, round body flushed deep red-orange, visibly hot with tiny heat shimmer lines rising off the top. Thick furrowed brow pushing down over squinted eyes, mouth pulled into a fierce scowl with tiny clenched teeth. Stubby fists balled at its sides, body leaning forward aggressively. Two small cartoon steam puffs emerging from the sides of its head. Dramatic underlighting in red-orange. Pure black background. 512×512. Clearly angry but still cute — a child laughs at it while recognizing the feeling."),
        ("age_band_assets/sprouts/feelings", "scared.png", "Pixar-style soft 3D rendered creature, round body gone pale white-lavender, inner glow flickering and dim. Enormous round eyes with tiny contracted pupils and visible whites all around, eyebrows raised high in a steep arch. Mouth frozen in a small tense 'o'. Stubby arms pulled tight against the body, shoulders hunched. Body vibrating slightly — use motion blur or subtle repeat ghost image on the edges. Small floating question marks and wavy lines above the head. Cool blue-white rim light from above. Pure black background. 512×512."),
        ("age_band_assets/sprouts/feelings", "surprised.png", "Pixar-style soft 3D rendered creature, round body flashing bright teal-cyan, crackling with tiny electric spark details. Eyes are perfectly round and maximally dilated, eyebrows shot straight up. Mouth a wide perfect 'O' of astonishment. Stubby arms flung outward dramatically, body slightly airborne as if just startled. Tiny star and exclamation-mark shapes floating around the head. Sharp bright lighting, high contrast. Pure black background. 512×512. Pure comedic shock — immediately legible, fun rather than frightening."),
        ("age_band_assets/sprouts/feelings", "calm.png", "Pixar-style soft 3D rendered creature, round body in soft mint-sage green with a steady gentle inner glow like moonlight. Eyes are softly half-closed in peaceful contentment, curved in a gentle relaxed expression. Mouth a gentle small smile. Stubby arms resting loosely at sides, body perfectly still and grounded. Tiny slow-moving soft glow particles drift upward around it like floating lanterns. Very soft diffused light from above, long gentle shadow. Pure black background. 512×512. Radiates stillness — a child should feel calmer just looking at it."),
        ("age_band_assets/sprouts/feelings", "confused.png", "Pixar-style soft 3D rendered creature, round body in warm peach-orange with slightly unsteady inner glow that pulses unevenly. One eye squinting suspiciously, the other wide open — asymmetric expression. Mouth twisted to one side in puzzlement, one stubby arm raised with a tiny finger pointing upward as if about to ask a question. Head tilted 15 degrees to one side. A softly glowing question mark floats near the raised arm. Small swirling lines around the head. Neutral even lighting. Pure black background. 512×512."),
        ("age_band_assets/sprouts/feelings", "excited.png", "Pixar-style soft 3D rendered creature, round body blazing hot magenta-pink, radiating energy like a little sun. Eyes are star-shaped or have star pupils, wide with electric excitement. Enormous open grin, practically vibrating. Both stubby arms waving frantically above its head, body bouncing upward off the ground — show motion blur on the arms and a slight bounce blur at the base. Surrounded by mini stars, sparkles, and tiny fireworks burst shapes. Very high-key bright lighting, almost overexposed with joy. Pure black background. 512×512."),

        # PART 2 — Early Readers White/Light Skin Character Variants
        ("age_band_assets/early_readers/ui", "boy_character_white.png", "Disney/Pixar 3D animation style, children's storybook illustration quality. A cheerful boy age 6-7 with light/fair Caucasian skin, tousled warm chestnut-brown hair with a slight cowlick, bright blue eyes with Pixar-style catchlights, rosy cheeks, and a confident adventurous smile. Wearing a whimsical explorer outfit: a small magical vest covered in star and moon patches over a simple long-sleeve shirt, with a tiny compass charm hanging from the vest. Upper-body portrait composition, character facing slightly left of center, relaxed hero pose. Warm magical rim lighting with subtle fantasy sparkle particles in the background. The character feels brave, friendly, and ready for an adventure. Pure black background for transparency extraction. Match the framing and rendering quality of the other early_readers character variants exactly."),
        ("age_band_assets/early_readers/ui", "girl_character_white.png", "Disney/Pixar 3D animation style, children's storybook illustration quality. A cheerful girl age 6-7 with light/fair Caucasian skin, flowing strawberry-blonde hair with small braided sections and a tiny glowing star-shaped hair clip, bright green eyes with Pixar-style catchlights, rosy freckled cheeks, and a warm adventurous smile. Wearing a whimsical explorer outfit: a small magical cape with crescent moon embroidery over a simple dress, with a delicate bracelet charm. Upper-body portrait composition, character facing slightly right of center, confident friendly pose. Warm magical rim lighting with subtle fantasy sparkle particles in the background. The character feels curious, brave, and enchanting. Pure black background for transparency extraction. Match the framing and rendering quality of the other early_readers character variants exactly."),
    ]

    for folder, filename, prompt in assets:
        output_path = Path(folder) / filename
        generate_image(prompt, output_path)
        time.sleep(10) # Simple delay between requests

if __name__ == "__main__":
    main()
