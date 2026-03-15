
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
            logger.info(f"Generating Upper-YA style: {output_path.name}")
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
    age_band = "older_adolescents"
    base_dir = Path(f"age_band_assets/{age_band}")
    
    # UPPER-YA CINEMATIC STYLE BASE (15-18)
    # Style: High-Fidelity Cinematic 3D but with MORE atmospheric maturity — moodier lighting, more realistic proportions, slightly more complex environments.
    style_base = "Upper-YA high-fidelity cinematic 3D digital illustration. Moody chiaroscuro lighting, photorealistic 3D textures, atmospheric perspective, subsurface scattering, platinum and obsidian accents. Realistic late-teen proportions. Sophisticated and mature tone."

    assets = [
        # UI Elements
        ("ui", "name_input_frame.png", f"{style_base} A premium minimal 3D crystalline interface frame, thin etched platinum edges, subtle inner white glow. Smoked obsidian glass center.", "PNG", True),
        ("ui", "make_magic_normal.png", f"{style_base} A wide sleek 3D button, smoked glass to deep obsidian gradient. Refined platinum crystalline border. Sharp white sans-serif 3D text START JOURNEY. Minimalist quill symbol.", "PNG", True),
        ("ui", "make_magic_normal_clicked.png", f"{style_base} Same as the START JOURNEY button but compressed, platinum glow radiating outwards, background gradient shifting to a brighter silver.", "PNG", True),
        ("ui", "make_magic_pressed.png", f"{style_base} Same as START JOURNEY button but physically depressed, platinum glow intensifying on edges, smoked glass darkening.", "PNG", True),
        ("ui", "continue_button.png", f"{style_base} A premium 3D rounded button, deep obsidian face, thin platinum border. Right-pointing angular platinum arrow icon.", "PNG", True),
        ("ui", "continue_button_clicked.png", f"{style_base} Same as the obsidian continue button but physically depressed, platinum border glowing intensely, face showing subtle motion blur.", "PNG", True),
        
        # GENDER / CHARACTER BASE (Diverse variants for 15-18)
        ("ui", "boy_character.png", f"{style_base} A 17-year-old Caucasian boy with intense thoughtful eyes, stylized dark hair, wearing a premium minimal tech-wear jacket. Realistic late-adolescent proportions.", "PNG", True),
        ("ui", "boy_character_asian.png", f"{style_base} A 17-year-old East Asian boy with intense thoughtful eyes, stylized dark hair, wearing a premium minimal tech-wear jacket. Realistic late-adolescent proportions.", "PNG", True),
        ("ui", "boy_character_black.png", f"{style_base} A 17-year-old Black boy with intense thoughtful eyes, short faded natural hair, wearing a premium minimal tech-wear jacket. Realistic late-adolescent proportions.", "PNG", True),
        ("ui", "boy_character_hispanic.png", f"{style_base} A 17-year-old Hispanic boy with intense thoughtful eyes, wavy dark hair, wearing a premium minimal tech-wear jacket. Realistic late-adolescent proportions.", "PNG", True),
        ("ui", "boy_character_south_asian.png", f"{style_base} A 17-year-old South Asian boy with intense thoughtful eyes, dark hair, wearing a premium minimal tech-wear jacket. Realistic late-adolescent proportions.", "PNG", True),

        ("ui", "girl_character.png", f"{style_base} A 17-year-old Caucasian girl with resolute eyes, hair tied back, wearing a premium minimal adventure-ready high-collar jacket. Realistic late-adolescent proportions.", "PNG", True),
        ("ui", "girl_character_asian.png", f"{style_base} A 17-year-old East Asian girl with resolute eyes, straight dark hair, wearing a premium minimal adventure-ready high-collar jacket. Realistic late-adolescent proportions.", "PNG", True),
        ("ui", "girl_character_black.png", f"{style_base} A 17-year-old Black girl with resolute eyes, braided hair, wearing a premium minimal adventure-ready high-collar jacket. Realistic late-adolescent proportions.", "PNG", True),
        ("ui", "girl_character_hispanic.png", f"{style_base} A 17-year-old Hispanic girl with resolute eyes, wavy dark hair, wearing a premium minimal adventure-ready high-collar jacket. Realistic late-adolescent proportions.", "PNG", True),
        ("ui", "girl_character_south_asian.png", f"{style_base} A 17-year-old South Asian girl with resolute eyes, long dark hair, wearing a premium minimal adventure-ready high-collar jacket. Realistic late-adolescent proportions.", "PNG", True),

        # ORBS
        ("orbs", "progress_idle.png", f"{style_base} A sophisticated 3D circular orb, matte obsidian, thin muted platinum crystalline ring. Faint pin-prick of light at center.", "PNG", True),
        ("orbs", "progress_active.png", f"{style_base} A sophisticated 3D circular orb, obsidian to electric platinum gradient. Luminous crystalline ring with intense inner glow. Internal energy filaments.", "PNG", True),
        ("orbs", "progress_done.png", f"{style_base} A sophisticated 3D circular orb, rich platinum fill, high inner radiance. Minimalist geometric checkmark symbol.", "PNG", True),

        # FEELINGS (Diverse, Mature 3D Faces)
        ("feelings", "happy.png", f"{style_base} A diverse late-teen face, subtle sophisticated 3D smile. Platinum-silver gradient background. Minimalist geometric sun symbol.", "PNG", True),
        ("feelings", "sad.png", f"{style_base} A diverse late-teen face, contemplative downcast eyes, moody shadows. Deep charcoal circle. Minimalist geometric moon symbol.", "PNG", True),
        ("feelings", "angry.png", f"{style_base} A diverse late-teen face, furrowed brows, intense focused intensity. Dark crimson circle. Minimalist geometric lightning symbol.", "PNG", True),
        ("feelings", "scared.png", f"{style_base} A diverse late-teen face, wide alert eyes, sharp focus. Dark indigo circle. Minimalist geometric wide-eye symbol.", "PNG", True),
        ("feelings", "surprised.png", f"{style_base} A diverse late-teen face, wide eyes, slightly open mouth. Deep teal circle. Minimalist geometric starburst symbol.", "PNG", True),
        ("feelings", "calm.png", f"{style_base} A diverse late-teen face, closed eyes, serene focused expression. Deep slate circle. Minimalist geometric ripple symbol.", "PNG", True),
        ("feelings", "excited.png", f"{style_base} A diverse late-teen face, sharp dynamic eyes, confident ecstatic smile. Electric gold circle. Minimalist geometric energy symbol.", "PNG", True),
        ("feelings", "confused.png", f"{style_base} A diverse late-teen face, asymmetrical brows, head slightly tilted. Dark slate-blue circle. Minimalist geometric question mark symbol.", "PNG", True),

        # COMPANIONS (Mature 3D)
        ("companions", "shadow_lynx.png", f"{style_base} A majestic high-fidelity 3D shadow lynx, luminous violet eyes, realistic dark fur with electric blue patterns. Alert sophisticated pose.", "PNG", True),
        ("companions", "iron_golem.png", f"{style_base} A massive high-fidelity 3D golem, smooth matte obsidian stone and silver crystal joints. Formidable protective pose.", "PNG", True),
        ("companions", "storm_hawk.png", f"{style_base} A massive high-fidelity 3D storm hawk, metallic silver-black feathers, wingtips crackling with white electrical energy. Commanding pose.", "PNG", True),
        ("companions", "void_sprite.png", f"{style_base} A small high-fidelity 3D ethereal sprite, translucent silver body containing visible nebula clouds, sharp iridescent wings.", "PNG", True),

        # ARCHETYPES (Diverse, Upper-YA Cinematic Scenes)
        ("archetypes", "brave_hero.jpg", f"{style_base} A Caucasian teen hero in sleek obsidian energy armor, holding a glowing white-hot energy blade. Standing on a dramatic storm-swept cliffside at night with crashing waves.", "JPEG", False),
        ("archetypes", "kind_healer.jpg", f"{style_base} A Hispanic teen healer in flowing robes with glowing silver runes, emitting an ethereal silver healing mist. Standing in a majestic bioluminescent crystal sanctuary.", "JPEG", False),
        ("archetypes", "clever_inventor.jpg", f"{style_base} A South Asian teen inventor with shoulder-length wavy hair, wearing a refined utility vest, surrounded by complex 3D holographic light-arrays in a dark high-tech studio.", "JPEG", False),
        ("archetypes", "speedy_explorer.jpg", f"{style_base} A Black teen explorer in sophisticated detailed gear, holding a glowing neon pulse-map. Standing in a vast alien desert under three massive moons at dusk.", "JPEG", False),
        ("archetypes", "mighty_guardian.jpg", f"{style_base} A Middle Eastern teen guardian in sleek protective dark armor with a glowing silver wolf-head emblem, holding a massive translucent energy shield before a celestial gateway.", "JPEG", False),
        ("archetypes", "gentle_dreamer.jpg", f"{style_base} An East Asian teen dreamer seated cross-legged in zero-gravity, surrounded by floating luminous digital scrolls in a vibrant cosmic nebula garden.", "JPEG", False),

        # SCENE CARDS
        ("scenes", "ruined_citadel.jpg", f"{style_base} Crumbling ancient 3D citadel at deep twilight, majestic architecture, bioluminescent flora, warm amber light from interior halls. Epic scale.", "JPEG", False),
        ("scenes", "orbital_station.jpg", f"{style_base} Sleek high-tech 3D orbital station, earth visible below, dramatic lighting through panoramic glass windows.", "JPEG", False),
        ("scenes", "deep_archive.jpg", f"{style_base} Impossibly large underground 3D library, soaring arches, stacks of illuminated ancient books, floating digital manuscripts. Atmospheric.", "JPEG", False),
        ("scenes", "tidal_shrine.jpg", f"{style_base} Ancient 3D shrine on a sea stack, dramatic moonlight, bioluminescent coral light, crashing waves at dusk. Cinematic depth.", "JPEG", False),

        # BACKGROUNDS
        ("backgrounds", "splash_bg.jpg", f"{style_base} Epic deep space panorama, star clusters, electric platinum and violet nebula clouds. Cinematic horizon with a distant star.", "JPEG", False),
        ("backgrounds", "story_page_bg.jpg", f"{style_base} Sophisticated dark smoked-glass background, gradually lighter toward center. Faint vertical platinum crystalline borders.", "JPEG", False),
    ]

    summary = []
    for subfolder, filename, prompt, fmt, black_bg in assets:
        output_path = base_dir / subfolder / filename
        if generate_image(prompt, output_path, format=fmt, force_black_bg=black_bg):
            summary.append(str(output_path))
            time.sleep(20) 
            
    logger.info(f"Older Adolescent ({age_band}) Upper-YA Cinematic style batch complete!")

if __name__ == "__main__":
    main()
