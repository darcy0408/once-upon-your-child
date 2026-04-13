
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
    age_band = "sprouts"
    base_dir = Path(age_band)
    
    # PIXAR STYLE BASE
    style_base = "Disney/Pixar-style 3D digital illustration. Cinematic lighting, soft shadows, high detail 3D render, subsurface scattering on skin, vibrant colors. Cute and friendly proportions."

    assets = [
        # UI
        ("UI", "app_logo.png", f"{style_base} A chunky 3D open storybook with a glowing golden star bursting from its pages. The book has a warm yellow cover. Tiny 3D stars float around it.", "PNG", True),
        ("UI", "name_input_frame.png", f"{style_base} A wide horizontal 3D ornate frame, bubbly golden texture with soft white highlights. 3D sparkle stars at corners. Translucent glass-like center.", "PNG", True),
        ("UI", "make_magic_normal.png", f"{style_base} A very wide 3D rounded button, warm golden yellow face, thick bubbly plum-purple 3D border. White 3D letters spell MAKE MAGIC. Floating 3D sparkle stars.", "PNG", True),
        ("UI", "make_magic_pressed.png", f"{style_base} Same as normal MAKE MAGIC button but physically compressed/pushed down, darker gold, thinner border, no outer glow.", "PNG", True),
        ("UI", "continue_button.png", f"{style_base} A large 3D rounded square button, sky teal color, bold white 3D chevron arrow pointing right. Deep 3D depth.", "PNG", True),
        
        # GENDER / CHARACTER BASE
        ("UI", "boy_character.png", f"{style_base} Adorable young boy character, big curious eyes, messy hair, star-print t-shirt, denim overalls. Joyful expression.", "PNG", True),
        ("UI", "girl_character.png", f"{style_base} Adorable young girl character, bright pigtails with star clips, rainbow-stripe dress. Energetic joyful expression.", "PNG", True),

        # COMPANIONS (PIXAR 3D)
        ("companions", "fluffy_dragon.png", f"{style_base} Adorable chubby baby dragon, lavender scales, soft green belly, tiny stubby wings, enormous sweet eyes. Cuddly 3D character.", "PNG", True),
        ("companions", "tiny_fairy.png", f"{style_base} Tiny cute fairy, large round head, sparkly eyes, rounded translucent glowing wings, simple lavender dress. Holding a star wand.", "PNG", True),
        ("companions", "magic_bunny.png", f"{style_base} Fluffy 3D bunny, enormous soft ears, big gentle eyes, wearing a tiny golden vest. Holding a glowing crystal ball.", "PNG", True),
        ("companions", "shining_puppy.png", f"{style_base} Overjoyed fluffy 3D puppy, enormous eyes, wagging tail, wearing a teal bandana with a glowing star.", "PNG", True),

        # ORBS
        ("orbs", "progress_idle.png", f"{style_base} A perfect 3D sphere, soft lavender-gray, matte finish, simple plum outline. Quiet and waiting.", "PNG", True),
        ("orbs", "progress_active.png", f"{style_base} A glowing 3D golden sphere, radiating warm light, single bright star highlight on the surface. Pulsing with energy.", "PNG", True),
        ("orbs", "progress_done.png", f"{style_base} A bright sky-teal 3D sphere, bold white checkmark embedded in the surface. Sparkle stars floating nearby.", "PNG", True),

        # ARCHETYPES (SCENES - No Black BG needed as these are full cards)
        ("archetypes", "animal_whisperer.jpg", f"{style_base} A gentle toddler-age child with South Asian features sits in a sunny meadow. A circle of friendly 3D animals (bunny, deer, butterfly) surrounds them. Soft golden morning light.", "JPEG", False),
        ("archetypes", "storm_rider.jpg", f"{style_base} A chubby happy East Asian child hero riding a fluffy white 3D storm cloud as if surfing. Friendly zigzag lightning bolts with smiley faces. Peach sunset sky.", "JPEG", False),
        ("archetypes", "quiz_whiz.jpg", f"{style_base} An adorable young Black child with oversized round glasses at a tiny desk. Surrounded by glowing 3D question marks and lightbulb characters. Warm library setting.", "JPEG", False),
        ("archetypes", "heart_healer.jpg", f"{style_base} A gentle young Hispanic child with warm brown skin stands with arms wide. A small 3D bunny and tiny dragon gather around, glowing with pink light. Rose meadow.", "JPEG", False),
        ("archetypes", "lightning_runner.jpg", f"{style_base} A chubby energetic Caucasian child with red hair running so fast they leave 3D rainbow trail lines. Joyful expression. Colorful town blur background.", "JPEG", False),
        ("archetypes", "master_creator.jpg", f"{style_base} A joyful young Middle Eastern child building a magical 3D sandcastle on a golden beach. Tiny 3D creature figures and stars float from the towers. Sunset.", "JPEG", False),

        # BACKGROUNDS
        ("backgrounds", "splash_bg.jpg", f"{style_base} A warm gradient sky, peach to lavender. Large glowing golden 3D star in the center. Rolling cream-colored hills at the bottom.", "JPEG", False),
        ("backgrounds", "story_page_bg.jpg", f"{style_base} A soft warm cream to pale peach gradient background. Tiny simple golden stars at the top. Blank storybook page feel.", "JPEG", False),
        ("backgrounds", "feelings_bg.jpg", f"{style_base} Soft warm sky with large friendly 3D rounded clouds in pastel colors. Looking up from a happy meadow.", "JPEG", False),
    ]

    summary = []
    for subfolder, filename, prompt, fmt, black_bg in assets:
        output_path = base_dir / subfolder / filename
        if generate_image(prompt, output_path, format=fmt, force_black_bg=black_bg):
            summary.append(str(output_path))
            time.sleep(20) 
            
    logger.info("Disney/Pixar style batch complete!")

if __name__ == "__main__":
    main()
