
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
    age_band = "adventurers"
    base_dir = Path(f"age_band_assets/{age_band}")
    
    # CINEMATIC PIXAR STYLE BASE (8-10)
    style_base = "Cinematic Pixar-style 3D digital illustration. Dramatic high-contrast lighting, volumetric fog, high detail 3D render, subsurface scattering, vibrant neon accents. Confident adolescent proportions."
    androgynous_diverse = "The character is androgynous and gender-neutral, identifiable by both boys and girls. Detailed practical adventurer gear."

    assets = [
        # UI
        ("ui", "name_input_frame.png", f"{style_base} A sleek horizontal 3D crystalline frame, electric cyan neon edges, glowing diamond fragments at corners. Translucent midnight-blue glass center.", "PNG", True),
        ("ui", "make_magic_normal.png", f"{style_base} A wide sleek 3D button, deep midnight blue to cosmic violet gradient. Glowing electric cyan crystalline border. Bold white 3D text START ADVENTURE.", "PNG", True),
        ("ui", "make_magic_pressed.png", f"{style_base} Same as normal START ADVENTURE but inset shadow, nebula texture dimmed, crystal edges intensifying their neon glow.", "PNG", True),
        ("ui", "continue_button.png", f"{style_base} A sleek 3D rounded rectangle button, deep midnight blue face, thin crystal cyan border. Right-pointing angular neon arrow icon.", "PNG", True),
        
        # ORBS
        ("orbs", "progress_idle.png", f"{style_base} A 3D circular orb, dark deep-space navy, thin muted crystal cyan border. Faint central glow sleeping inside.", "PNG", True),
        ("orbs", "progress_active.png", f"{style_base} A 3D circular orb, deep midnight to electric violet gradient. Bright neon crystal cyan ring with visible outer glow.", "PNG", True),
        ("orbs", "progress_done.png", f"{style_base} A 3D circular orb, rich neon gold fill, strong inner luminous radiance. Sharp geometric white checkmark embedded.", "PNG", True),

        # ARCHETYPES (Diverse, Androgynous Cinematic Scenes)
        ("archetypes", "brave_hero.jpg", f"{style_base} {androgynous_diverse} A Black child with short twisted hair, wearing a sleek styled jacket with a glowing emblem, holding a glowing energy sword pointing forward. Dramatic sunset cliffside background.", "JPEG", False),
        ("archetypes", "kind_healer.jpg", f"{style_base} {androgynous_diverse} A South Asian child with wavy shoulder-length hair, wearing flowing robes with light-emitting rune stitching, hands emitting a warm golden healing aura. Bioluminescent medical grove background.", "JPEG", False),
        ("archetypes", "clever_inventor.jpg", f"{style_base} {androgynous_diverse} An East Asian child with neutral features, wearing a detailed utility vest and goggles, holding a glowing holographic tool. Atmospheric workshop background with holographic projections.", "JPEG", False),
        ("archetypes", "speedy_explorer.jpg", f"{style_base} {androgynous_diverse} A Middle Eastern child with neutral hair, wearing practical detailed gear and a map case, holding a compass glowing with soft blue light. Alien landscape dusk background.", "JPEG", False),
        ("archetypes", "mighty_guardian.jpg", f"{style_base} {androgynous_diverse} A Hispanic child with neutral features, wearing sleek detailed armor with a glowing shield emblem at the chest. Stone fortress entrance at night background.", "JPEG", False),
        ("archetypes", "gentle_dreamer.jpg", f"{style_base} {androgynous_diverse} A Caucasian child with neutral features, seated cross-legged in mid-air, surrounded by orbiting books and silver light particles. Deep space library background.", "JPEG", False),

        # FEELINGS (Diverse, Androgynous 3D Faces)
        ("feelings", "happy.png", f"{style_base} A diverse, androgynous adolescent face, authentic confident 3D smile. Amber-gold gradient circle background. Stylized sun icon.", "PNG", True),
        ("feelings", "sad.png", f"{style_base} A diverse, androgynous adolescent face, contemplative downcast eyes. Muted cool indigo circle background. Stylized crescent moon.", "PNG", True),
        ("feelings", "angry.png", f"{style_base} A diverse, androgynous adolescent face, furrowed 3D brows, controlled power expression. Ember-red to orange circle. Stylized lightning bolt.", "PNG", True),
        ("feelings", "scared.png", f"{style_base} A diverse, androgynous adolescent face, wide alert 3D eyes, geometric pupils. Dark violet to blue circle background. Stylized wide-eye icon.", "PNG", True),
        ("feelings", "surprised.png", f"{style_base} A diverse, androgynous adolescent face, wide geometric eyes, open mouth. Bright teal circle background. Small starburst shapes.", "PNG", True),
        ("feelings", "calm.png", f"{style_base} A diverse, androgynous adolescent face, closed eyes, relaxed 3D expression. Deep ocean-teal circle background. Concentric ripple lines.", "PNG", True),
        ("feelings", "excited.png", f"{style_base} A diverse, androgynous adolescent face, sharp dynamic eyes, energized expression. Neon-gold to orange circle. Radiating energy lines.", "PNG", True),
        ("feelings", "confused.png", f"{style_base} A diverse, androgynous adolescent face, asymmetrical brows, head tilted. Gray-blue circle background. Integrated question mark design.", "PNG", True),

        # COMPANIONS (Pixar 3D)
        ("companions", "shadow_lynx.png", f"{style_base} A sleek 3D shadow lynx, luminous violet eyes, dark-tipped electric blue fur markings. Alert intelligent pose.", "PNG", True),
        ("companions", "iron_golem.png", f"{style_base} A compact 3D golem, smooth stone and crystal, warm amber eyes, soft gold light at joints. Solid protective pose.", "PNG", True),
        ("companions", "storm_hawk.png", f"{style_base} A large 3D storm hawk, metallic blue-silver feathers, wingtips crackling with faint electrical energy. Commanding pose.", "PNG", True),
        ("companions", "void_sprite.png", f"{style_base} A small 3D ethereal sprite, translucent body containing star-maps, large dark eyes filled with stars, iridescent wings.", "PNG", True),

        # SCENE CARDS (Full Scenes)
        ("scenes", "ruined_citadel.jpg", f"{style_base} Crumbling magnificent ancient citadel at twilight, vines and bioluminescent moss, warm amber light from archways.", "JPEG", False),
        ("scenes", "orbital_station.jpg", f"{style_base} Sleek 3D space station in low orbit, planet visible below in warm blues and greens, interior corridors visible through glass.", "JPEG", False),
        ("scenes", "deep_archive.jpg", f"{style_base} Impossibly large underground library, vaulted ceilings, stacked illuminated bookshelves, floating glowing manuscripts.", "JPEG", False),
        ("scenes", "tidal_shrine.jpg", f"{style_base} Ancient 3D shrine on a sea stack, dramatic ocean waves, bioluminescent coral light and moonlight.", "JPEG", False),

        # BACKGROUNDS
        ("backgrounds", "splash_bg.jpg", f"{style_base} Deep space view, star clusters, electric violet and teal nebula clouds. Lone small island with amber lights in windows.", "JPEG", False),
        ("backgrounds", "story_page_bg.jpg", f"{style_base} Deep rich midnight blue background, gradually lighter toward center. Faint vertical stylized borders on margins.", "JPEG", False),
    ]

    summary = []
    for subfolder, filename, prompt, fmt, black_bg in assets:
        output_path = base_dir / subfolder / filename
        if generate_image(prompt, output_path, format=fmt, force_black_bg=black_bg):
            summary.append(str(output_path))
            time.sleep(20) 
            
    logger.info(f"Adventurer ({age_band}) Pixar style batch complete!")

if __name__ == "__main__":
    main()
