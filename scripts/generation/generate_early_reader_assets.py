
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
MODEL_NAME = 'models/imagen-4.0-generate-001'

def generate_image(prompt, output_path, format='PNG', force_black_bg=True):
    """Generate an image using the Imagen API with retry logic and optional black background."""
    
    if output_path.exists():
        logger.info(f"Skipping {output_path.name} (Already exists)")
        return True

    if force_black_bg:
        prompt = f"{prompt} -- THE CHARACTER/ELEMENT MUST BE ISOLATED ON A PURE SOLID BLACK BACKGROUND. NO SCENERY. NO FLOOR. NO SHADOWS. NO GRADIENTS IN THE BACKGROUND. PURE BLACK #000000 ONLY."

    while True:
        try:
            logger.info(f"Generating Pixar-style: {output_path.name}")
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
    age_band = "early_readers"
    base_dir = Path(f"age_band_assets/{age_band}")
    
    # PIXAR STYLE BASE
    style_base = "Disney/Pixar-style 3D digital illustration. Cinematic lighting, soft shadows, high detail 3D render, subsurface scattering on skin, vibrant colors. Cute and friendly proportions."
    androgynous_diverse = "The character is androgynous and gender-neutral, identifiable by both boys and girls. Simple neutral clothing."

    assets = [
        # UI
        ("ui", "name_input_frame.png", f"{style_base} A wide 3D magical parchment scroll frame, ornate gold vine borders, glowing berries at corners. Translucent deep violet center.", "PNG", True),
        ("ui", "make_magic_normal.png", f"{style_base} A wide 3D button with a deep violet to warm purple gradient. Glowing gold decorative border. Golden 3D text MAKE MAGIC. Floating gold sparkles.", "PNG", True),
        ("ui", "make_magic_pressed.png", f"{style_base} Same as normal MAKE MAGIC but darker indigo gradient, dimmed gold glow, sparkle particles compressed downward.", "PNG", True),
        ("ui", "continue_button.png", f"{style_base} A wide 3D rounded button, warm enchanted gold gradient face. Deep violet bold 3D text CONTINUE. Glowing gold arrow icon.", "PNG", True),
        
        # ORBS
        ("orbs", "progress_idle.png", f"{style_base} A 3D translucent deep violet orb, thin gold border. Faint central magical ember sleeping inside.", "PNG", True),
        ("orbs", "progress_active.png", f"{style_base} A radiant 3D orb, rich violet-to-gold gradient. Glowing gold band. Soft white particle sparkles drifting outward.", "PNG", True),
        ("orbs", "progress_done.png", f"{style_base} A glowing 3D enchanted gold orb, bright radiance. White 3D star checkmark embedded in center.", "PNG", True),

        # ARCHETYPES (Diverse, Androgynous Pixar Scenes)
        ("archetypes", "brave_hero.jpg", f"{style_base} {androgynous_diverse} An East Asian child with short neutral hair, wearing a red cape over a simple tunic, holding a glowing golden 3D sword pointing up. Determined joyful expression. Decorative gold vine border.", "JPEG", False),
        ("archetypes", "kind_healer.jpg", f"{style_base} {androgynous_diverse} A Black child with soft curls, wearing a white and gold neutral healer's robe, holding a green 3D lantern radiating soft light. Wise gentle expression. Gold vine border.", "JPEG", False),
        ("archetypes", "clever_inventor.jpg", f"{style_base} {androgynous_diverse} A South Asian child with wavy shoulder-length hair, wearing goggles and a multi-pocket utility vest, holding a glowing 3D mechanical gold gear device. Delighted curiosity. Gold vine border.", "JPEG", False),
        ("archetypes", "speedy_explorer.jpg", f"{style_base} {androgynous_diverse} A Hispanic child with neutral hair under a wide adventurer hat, wearing a practical 3D explorer jacket, holding an ornate glowing blue compass. Confident expression. Gold vine border.", "JPEG", False),
        ("archetypes", "mighty_guardian.jpg", f"{style_base} {androgynous_diverse} A Caucasian child with neutral features, wearing simple stylized silver 3D armor, holding a round shield with a glowing golden sun emblem. Protective calm expression. Gold vine border.", "JPEG", False),
        ("archetypes", "gentle_dreamer.jpg", f"{style_base} {androgynous_diverse} A Middle Eastern child with neutral features, wearing soft blue flowing robes, sitting cross-legged and hovering surrounded by 3D glowing books and silver star particles. Serene expression. Gold vine border.", "JPEG", False),

        # FEELINGS (Diverse, Androgynous 3D Faces)
        ("feelings", "happy.png", f"{style_base} A diverse, androgynous child face with a wide authentic 3D smile and bright eyes. Warm golden circle background. Small 3D sun and stars.", "PNG", True),
        ("feelings", "sad.png", f"{style_base} A diverse, androgynous child face with soft downcast eyes and a gentle 3D frown. Muted blue circle background. Small rain cloud.", "PNG", True),
        ("feelings", "angry.png", f"{style_base} A diverse, androgynous child face with furrowed 3D brows and a tight mouth. Warm orange circle background. Soft glowing flame icon.", "PNG", True),
        ("feelings", "scared.png", f"{style_base} A diverse, androgynous child face with wide 3D eyes and slightly open mouth. Soft lavender circle background. Friendly round ghost icon.", "PNG", True),
        ("feelings", "surprised.png", f"{style_base} A diverse, androgynous child face with raised 3D eyebrows and wide circular eyes. Aqua circle background. 3D confetti stars.", "PNG", True),
        ("feelings", "calm.png", f"{style_base} A diverse, androgynous child face with gently closed eyes and a relaxed 3D expression. Sage green circle background. Crescent moon icon.", "PNG", True),
        ("feelings", "excited.png", f"{style_base} A diverse, androgynous child face with enormous sparkly 3D eyes and a triumphant smile. Coral-to-gold circle. Gold star bursts.", "PNG", True),
        ("feelings", "confused.png", f"{style_base} A diverse, androgynous child face with one raised 3D brow and tilted head. Warm yellow circle background. Thought-bubble question mark.", "PNG", True),

        # COMPANIONS (Pixar 3D)
        ("companions", "star_fox.png", f"{style_base} A sleek 3D golden fox, large expressive eyes, bushy tail tipped with a glowing star. Wearing a simple travel cloak.", "PNG", True),
        ("companions", "moon_owl.png", f"{style_base} A wise 3D owl, silver-white feathers, large luminous eyes, small glowing crescent moon shapes on wing tips.", "PNG", True),
        ("companions", "ember_dragon.png", f"{style_base} A friendly 3D violet dragon, kind eyes, tiny wings, breathing a small puff of warm golden sparkles.", "PNG", True),
        ("companions", "bloom_sprite.png", f"{style_base} A tiny 3D sprite character, humanoid proportions, large translucent rainbow wings, wearing a flower-crown.", "PNG", True),

        # SCENE CARDS (Full Scenes)
        ("scenes", "enchanted_forest.jpg", f"{style_base} Atmospheric painted forest at twilight, pathway of soft golden 3D light leading into depth, fireflies. Gold vine border.", "JPEG", False),
        ("scenes", "cloud_castle.jpg", f"{style_base} Fantastical 3D castle in white and gold on a bank of soft luminous clouds. Sunrise peach-to-violet sky. Gold vine border.", "JPEG", False),
        ("scenes", "ocean_depths.jpg", f"{style_base} Underwater scene, warm luminous blue-teal 3D water, rays of gold sunlight, glowing 3D jellyfish. Gold vine border.", "JPEG", False),
        ("scenes", "star_village.jpg", f"{style_base} Floating village of round 3D cottages on a small asteroid, surrounded by cosmic sky and glowing stars. Gold vine border.", "JPEG", False),

        # BACKGROUNDS
        ("backgrounds", "splash_bg.jpg", f"{style_base} Rich deep indigo sky fading to violet. Luminous full 3D moon casting a wide ivory-gold halo. Enchanted hill silhouettes.", "JPEG", False),
        ("backgrounds", "story_page_bg.jpg", f"{style_base} Full portrait background. Warm parchment ivory with soft texture. Faint vertical gold vine borders on margins.", "JPEG", False),
    ]

    summary = []
    for subfolder, filename, prompt, fmt, black_bg in assets:
        output_path = base_dir / subfolder / filename
        if generate_image(prompt, output_path, format=fmt, force_black_bg=black_bg):
            summary.append(str(output_path))
            time.sleep(20) 
            
    logger.info(f"Early Reader ({age_band}) Pixar style batch complete!")

if __name__ == "__main__":
    main()
