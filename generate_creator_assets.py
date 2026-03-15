
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
    age_band = "creators"
    base_dir = Path(f"age_band_assets/{age_band}")
    
    # SLEEK CINEMATIC PIXAR STYLE BASE (11-13)
    style_base = "Sleek Cinematic Pixar-style 3D digital illustration. Dramatic high-contrast lighting, sophisticated 3D render, refined subsurface scattering, electric gold and deep midnight gradients. Mature adolescent proportions."
    androgynous_diverse = "The character is androgynous and gender-neutral, identifiable by both boys and girls. Sophisticated high-tech/fantasy gear."

    assets = [
        # UI
        ("ui", "name_input_frame.png", f"{style_base} A thin refined 3D crystalline frame, neon gold inner glow, sharp diamond-cut edges. Deep midnight-blue transparent glass center.", "PNG", True),
        ("ui", "make_magic_normal.png", f"{style_base} A wide sleek 3D button, dark charcoal to deep midnight gradient. Thin refined neon gold border. Clean white 3D text CREATE STORY. Golden quill icon.", "PNG", True),
        ("ui", "make_magic_pressed.png", f"{style_base} Same as CREATE STORY button but physically compressed, glow concentrated inward, darker gradient.", "PNG", True),
        ("ui", "continue_button.png", f"{style_base} A sleek 3D rounded button, deep midnight blue face, thin neon gold border. Right-pointing angular gold arrow icon.", "PNG", True),
        
        # ORBS
        ("orbs", "progress_idle.png", f"{style_base} A 3D circular orb, dark deep-space navy, thin muted gold border. Very faint central light.", "PNG", True),
        ("orbs", "progress_active.png", f"{style_base} A 3D circular orb, deep midnight to electric gold gradient. Bright neon gold ring with outer glow. Particle energy lines.", "PNG", True),
        ("orbs", "progress_done.png", f"{style_base} A 3D circular orb, rich neon gold fill, strong inner radiance. Sharp white geometric checkmark. Floating crystal shards.", "PNG", True),

        # ARCHETYPES (Diverse, Androgynous Mature Pixar Scenes)
        ("archetypes", "brave_hero.jpg", f"{style_base} {androgynous_diverse} A Middle Eastern child with neutral features, wearing sleek energy-infused armor, holding a glowing gold energy blade. Dramatic twilight city skyline background.", "JPEG", False),
        ("archetypes", "kind_healer.jpg", f"{style_base} {androgynous_diverse} A Caucasian child with neutral features, wearing white robes with glowing gold runes, emitting a soft golden healing aura. Bioluminescent crystal cave background.", "JPEG", False),
        ("archetypes", "clever_inventor.jpg", f"{style_base} {androgynous_diverse} A Black child with short twisted hair, wearing a high-tech utility vest and interface goggles, surrounded by floating holographic schematics. High-tech laboratory background.", "JPEG", False),
        ("archetypes", "speedy_explorer.jpg", f"{style_base} {androgynous_diverse} An East Asian child with neutral hair, wearing sophisticated detailed gear, holding a glowing neon digital map. Alien mountain tundra at dusk background.", "JPEG", False),
        ("archetypes", "mighty_guardian.jpg", f"{style_base} {androgynous_diverse} A South Asian child with neutral features, wearing sleek protective 3D armor with a glowing gold lion-head emblem, holding a massive energy shield. Ancient ruins night background.", "JPEG", False),
        ("archetypes", "gentle_dreamer.jpg", f"{style_base} {androgynous_diverse} A Hispanic child with neutral features, seated cross-legged, surrounded by orbiting glowing digital books and cosmic light particles. Vibrant nebula library background.", "JPEG", False),

        # FEELINGS (Diverse, Androgynous 3D Faces)
        ("feelings", "happy.png", f"{style_base} A diverse, androgynous adolescent face, sophisticated 3D smile. Amber-gold gradient circle background. Minimalist sun symbol.", "PNG", True),
        ("feelings", "sad.png", f"{style_base} A diverse, androgynous adolescent face, thoughtful downcast eyes. Muted cool indigo circle. Minimalist crescent moon symbol.", "PNG", True),
        ("feelings", "angry.png", f"{style_base} A diverse, androgynous adolescent face, furrowed brows, intense focused power. Ember-red circle. Minimalist lightning bolt symbol.", "PNG", True),
        ("feelings", "scared.png", f"{style_base} A diverse, androgynous adolescent face, wide alert eyes, geometric pupils. Dark violet circle. Minimalist wide-eye symbol.", "PNG", True),
        ("feelings", "surprised.png", f"{style_base} A diverse, androgynous adolescent face, wide circular eyes, O-shaped mouth. Bright teal circle. Minimalist starburst symbol.", "PNG", True),
        ("feelings", "calm.png", f"{style_base} A diverse, androgynous adolescent face, closed eyes, serene expression. Deep ocean-teal circle. Minimalist ripple symbol.", "PNG", True),
        ("feelings", "excited.png", f"{style_base} A diverse, androgynous adolescent face, sharp dynamic eyes, ecstatic smile. Neon-gold circle. Minimalist energy lines symbol.", "PNG", True),
        ("feelings", "confused.png", f"{style_base} A diverse, androgynous adolescent face, asymmetrical brows, head tilted. Gray-blue circle. Minimalist question mark symbol.", "PNG", True),

        # COMPANIONS (Sleek Pixar 3D)
        ("companions", "shadow_lynx.png", f"{style_base} A sleek 3D shadow lynx, luminous violet eyes, electric blue fur markings. Sophisticated 3D creature.", "PNG", True),
        ("companions", "iron_golem.png", f"{style_base} A powerful 3D golem, smooth obsidian stone and gold crystal, amber glowing joints. Solid protective 3D creature.", "PNG", True),
        ("companions", "storm_hawk.png", f"{style_base} A massive 3D storm hawk, metallic silver feathers, wingtips crackling with gold electrical energy. Commanding 3D creature.", "PNG", True),
        ("companions", "void_sprite.png", f"{style_base} A small 3D ethereal sprite, translucent body with visible star-maps, dark eyes filled with galaxies. Iridescent 3D wings.", "PNG", True),

        # SCENE CARDS (Full Scenes)
        ("scenes", "ruined_citadel.jpg", f"{style_base} Crumbling ancient 3D citadel at twilight, bioluminescent moss, warm amber light from archways. Cinematic depth.", "JPEG", False),
        ("scenes", "orbital_station.jpg", f"{style_base} Sleek 3D space station in low orbit, planet visible below, interior corridors visible through high-tech glass.", "JPEG", False),
        ("scenes", "deep_archive.jpg", f"{style_base} Impossibly large underground 3D library, vaulted ceilings, stacks of illuminated books, floating manuscripts.", "JPEG", False),
        ("scenes", "tidal_shrine.jpg", f"{style_base} Ancient 3D shrine on a sea stack, dramatic ocean waves, bioluminescent coral light and moon-glimmer.", "JPEG", False),

        # BACKGROUNDS
        ("backgrounds", "splash_bg.jpg", f"{style_base} High-detail deep space, star clusters, electric gold and violet nebula clouds. Lone small habited island.", "JPEG", False),
        ("backgrounds", "story_page_bg.jpg", f"{style_base} Sophisticated deep rich midnight blue background, gradually lighter toward center. Faint vertical crystalline borders.", "JPEG", False),
    ]

    summary = []
    for subfolder, filename, prompt, fmt, black_bg in assets:
        output_path = base_dir / subfolder / filename
        if generate_image(prompt, output_path, format=fmt, force_black_bg=black_bg):
            summary.append(str(output_path))
            time.sleep(20) 
            
    logger.info(f"Creator ({age_band}) Pixar style batch complete!")

if __name__ == "__main__":
    main()
