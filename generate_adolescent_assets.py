
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
    age_band = "adolescents"
    base_dir = Path(f"age_band_assets/{age_band}")
    
    # MATURE CINEMATIC 3D STYLE BASE (13-15)
    style_base = "High-fidelity cinematic 3D digital illustration. Sophisticated lighting, realistic textures, volumetric atmosphere, subsurface scattering, refined electric gold and obsidian gradients. Realistic adolescent proportions."

    assets = [
        # UI
        ("ui", "name_input_frame.png", f"{style_base} A sleek horizontal crystalline terminal frame, thin neon-gold glowing edges, sharp diamond-cut geometry. Deep obsidian transparent glass center.", "PNG", True),
        ("ui", "make_magic_normal.png", f"{style_base} A wide sophisticated 3D button, obsidian to deep charcoal gradient. Thin refined electric gold border. Clean white serif 3D text CREATE STORY. Golden quill icon.", "PNG", True),
        ("ui", "make_magic_pressed.png", f"{style_base} Same as CREATE STORY button but compressed with an inner shadow, gold glow dimmed, darker gradient.", "PNG", True),
        ("ui", "continue_button.png", f"{style_base} A sleek 3D rounded button, deep charcoal face, thin electric gold border. Right-pointing angular gold arrow icon.", "PNG", True),
        
        # GENDER / CHARACTER BASE (Distinctly not androgynous for 13-15)
        ("ui", "boy_character.png", f"{style_base} A teenage boy with determined eyes, stylized short dark hair, wearing a sleek modern tactical vest over a dark shirt. Mature 14-year-old proportions.", "PNG", True),
        ("ui", "girl_character.png", f"{style_base} A teenage girl with confident eyes, long hair in a practical braid, wearing a sleek modern adventure-ready jacket. Mature 14-year-old proportions.", "PNG", True),

        # ORBS
        ("orbs", "progress_idle.png", f"{style_base} A sophisticated 3D circular orb, dark obsidian, thin muted gold crystalline border. Very faint central ember.", "PNG", True),
        ("orbs", "progress_active.png", f"{style_base} A sophisticated 3D circular orb, charcoal to electric gold gradient. Bright neon gold ring with outer glow. Internal energy lines.", "PNG", True),
        ("orbs", "progress_done.png", f"{style_base} A sophisticated 3D circular orb, rich neon gold fill, high inner radiance. Sharp white geometric checkmark.", "PNG", True),

        # ARCHETYPES (Diverse, Mature Cinematic Scenes)
        ("archetypes", "brave_hero.jpg", f"{style_base} A Middle Eastern teenage hero in sleek energy-infused dark armor, holding a glowing gold energy blade. Standing on a dramatic twilight skyscraper ledge overlooking a city.", "JPEG", False),
        ("archetypes", "kind_healer.jpg", f"{style_base} A Caucasian teenage healer in white robes with glowing gold runes, emitting a soft golden healing aura. Standing in a bioluminescent crystal cave.", "JPEG", False),
        ("archetypes", "clever_inventor.jpg", f"{style_base} A Black teenage inventor with short twisted hair, wearing a high-tech utility vest, surrounded by floating holographic schematics in a modern lab.", "JPEG", False),
        ("archetypes", "speedy_explorer.jpg", f"{style_base} An East Asian teenage explorer in sophisticated gear, holding a glowing neon digital map. Standing on a vast alien mountain tundra at dusk.", "JPEG", False),
        ("archetypes", "mighty_guardian.jpg", f"{style_base} A South Asian teenage guardian in sleek protective dark armor with a glowing gold lion emblem, holding a massive energy shield in ancient ruins.", "JPEG", False),
        ("archetypes", "gentle_dreamer.jpg", f"{style_base} A Hispanic teenage dreamer seated cross-legged in mid-air, surrounded by orbiting glowing digital books in a vibrant nebula space library.", "JPEG", False),

        # FEELINGS (Diverse, Mature 3D Faces)
        ("feelings", "happy.png", f"{style_base} A diverse teenage face, sophisticated confident 3D smile. Amber-gold gradient background. Minimalist sun symbol.", "PNG", True),
        ("feelings", "sad.png", f"{style_base} A diverse teenage face, thoughtful downcast eyes. Muted cool indigo background. Minimalist crescent moon symbol.", "PNG", True),
        ("feelings", "angry.png", f"{style_base} A diverse teenage face, furrowed brows, intense focused power. Ember-red background. Minimalist lightning bolt symbol.", "PNG", True),
        ("feelings", "scared.png", f"{style_base} A diverse teenage face, wide alert eyes, geometric pupils. Dark violet background. Minimalist wide-eye symbol.", "PNG", True),
        ("feelings", "surprised.png", f"{style_base} A diverse teenage face, wide circular eyes, O-shaped mouth. Bright teal background. Minimalist starburst symbol.", "PNG", True),
        ("feelings", "calm.png", f"{style_base} A diverse teenage face, closed eyes, serene expression. Deep ocean-teal background. Minimalist ripple symbol.", "PNG", True),
        ("feelings", "excited.png", f"{style_base} A diverse teenage face, sharp dynamic eyes, ecstatic smile. Neon-gold background. Minimalist energy lines symbol.", "PNG", True),
        ("feelings", "confused.png", f"{style_base} A diverse teenage face, asymmetrical brows, head tilted. Gray-blue background. Minimalist question mark symbol.", "PNG", True),

        # COMPANIONS (Sleek Pixar 3D)
        ("companions", "shadow_lynx.png", f"{style_base} A sleek high-fidelity 3D shadow lynx, luminous violet eyes, electric blue fur markings. Sophisticated creature design.", "PNG", True),
        ("companions", "iron_golem.png", f"{style_base} A powerful high-fidelity 3D golem, smooth obsidian stone and gold crystal joints. Solid protective pose.", "PNG", True),
        ("companions", "storm_hawk.png", f"{style_base} A massive high-fidelity 3D storm hawk, metallic silver feathers, wingtips crackling with gold electrical energy.", "PNG", True),
        ("companions", "void_sprite.png", f"{style_base} A small high-fidelity 3D ethereal sprite, translucent body with visible galaxies inside, iridescent wings.", "PNG", True),

        # SCENE CARDS (Full Scenes)
        ("scenes", "ruined_citadel.jpg", f"{style_base} Crumbling ancient 3D citadel at twilight, bioluminescent moss, warm amber light from archways. Cinematic atmospheric depth.", "JPEG", False),
        ("scenes", "orbital_station.jpg", f"{style_base} Sleek high-tech 3D space station in low orbit, planet visible below, interior corridors visible through glass.", "JPEG", False),
        ("scenes", "deep_archive.jpg", f"{style_base} Impossibly large underground 3D library, vaulted ceilings, stacks of illuminated books, floating digital manuscripts.", "JPEG", False),
        ("scenes", "tidal_shrine.jpg", f"{style_base} Ancient 3D shrine on a sea stack, dramatic ocean waves, bioluminescent coral light and moon-glimmer.", "JPEG", False),

        # BACKGROUNDS
        ("backgrounds", "splash_bg.jpg", f"{style_base} Sophisticated deep space panorama, star clusters, electric gold and violet nebula clouds. Cinematic horizon.", "JPEG", False),
        ("backgrounds", "story_page_bg.jpg", f"{style_base} Sophisticated deep rich midnight blue background, gradually lighter toward center. Faint vertical crystalline borders.", "JPEG", False),
    ]

    summary = []
    for subfolder, filename, prompt, fmt, black_bg in assets:
        output_path = base_dir / subfolder / filename
        if generate_image(prompt, output_path, format=fmt, force_black_bg=black_bg):
            summary.append(str(output_path))
            time.sleep(20) 
            
    logger.info(f"Adolescent ({age_band}) Cinematic style batch complete!")

if __name__ == "__main__":
    main()
