
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
            logger.info(f"Generating Adult Fine-Art style: {output_path.name}")
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
    age_band = "adults"
    base_dir = Path(f"age_band_assets/{age_band}")
    
    # REFINED FINE-ART CINEMATIC STYLE BASE (18+)
    style_base = "Refined Fine-Art Cinematic digital illustration. Evocative lighting, sophisticated 3D textures, atmospheric depth, realistic adult proportions, subtle magical elements. Polished and mature aesthetic."

    assets = [
        # UI
        ("ui", "name_input_frame.png", f"{style_base} An ultra-minimalist 3D architectural frame, etched dark platinum and smoked glass, faint internal amber glow. Sophisticated and clean.", "PNG", True),
        ("ui", "make_magic_normal.png", f"{style_base} A wide sleek 3D button, deep charcoal to midnight gradient. Thin refined platinum border. Sharp white 3D text BEGIN JOURNEY. Minimalist pen symbol.", "PNG", True),
        ("ui", "make_magic_normal_clicked.png", f"{style_base} Same as BEGIN JOURNEY button but physically depressed, platinum glow intensified, deeper charcoal gradient.", "PNG", True),
        ("ui", "make_magic_pressed.png", f"{style_base} BEGIN JOURNEY button in its fully pressed state, deep shadow, muted glow.", "PNG", True),
        ("ui", "continue_button.png", f"{style_base} A premium 3D rounded button, deep charcoal face, thin platinum border. Right-pointing minimal platinum arrow icon.", "PNG", True),
        ("ui", "continue_button_clicked.png", f"{style_base} Same as continue button but depressed with increased edge glow.", "PNG", True),
        
        # CHARACTER BASES (Diverse Adult Men and Women)
        ("ui", "man_character_asian.png", f"{style_base} A 25-year-old East Asian man with thoughtful eyes, stylized hair, wearing a refined minimalist dark jacket. Realistic adult proportions.", "PNG", True),
        ("ui", "man_character_black.png", f"{style_base} A 25-year-old Black man with intelligent eyes, short cropped hair, wearing a refined minimalist dark jacket. Realistic adult proportions.", "PNG", True),
        ("ui", "man_character_hispanic.png", f"{style_base} A 25-year-old Hispanic man with resolute eyes, wearing a refined minimalist dark jacket. Realistic adult proportions.", "PNG", True),
        ("ui", "man_character_south_asian.png", f"{style_base} A 25-year-old South Asian man with contemplative eyes, wearing a refined minimalist dark jacket. Realistic adult proportions.", "PNG", True),
        ("ui", "man_character_white.png", f"{style_base} A 25-year-old Caucasian man with calm eyes, wearing a refined minimalist dark jacket. Realistic adult proportions.", "PNG", True),
        
        ("ui", "woman_character_asian.png", f"{style_base} A 25-year-old East Asian woman with intelligent eyes, sleek hair, wearing a refined minimalist dark jacket. Realistic adult proportions.", "PNG", True),
        ("ui", "woman_character_black.png", f"{style_base} A 25-year-old Black woman with resolute eyes, stylized hair, wearing a refined minimalist dark jacket. Realistic adult proportions.", "PNG", True),
        ("ui", "woman_character_hispanic.png", f"{style_base} A 25-year-old Hispanic woman with calm eyes, wearing a refined minimalist dark jacket. Realistic adult proportions.", "PNG", True),
        ("ui", "woman_character_south_asian.png", f"{style_base} A 25-year-old South Asian woman with thoughtful eyes, wearing a refined minimalist dark jacket. Realistic adult proportions.", "PNG", True),
        ("ui", "woman_character_white.png", f"{style_base} A 25-year-old Caucasian woman with contemplative eyes, wearing a refined minimalist dark jacket. Realistic adult proportions.", "PNG", True),

        # ORBS
        ("orbs", "progress_idle.png", f"{style_base} A 3D circular orb, deep matte obsidian, ultra-thin platinum ring. Faint internal light point.", "PNG", True),
        ("orbs", "progress_active.png", f"{style_base} A 3D circular orb, obsidian to silver-blue gradient. Luminous platinum ring with steady inner glow.", "PNG", True),
        ("orbs", "progress_done.png", f"{style_base} A 3D circular orb, rich silver-white fill, high inner radiance. Minimalist checkmark etched into the surface.", "PNG", True),

        # ARCHETYPES (Diverse Adult Cinematic Scenes)
        ("archetypes", "brave_hero.jpg", f"{style_base} A Black adult hero in high-tech matte-black armor, holding a glowing white energy blade. Standing on a vast lunar landscape with Earth visible in the distance.", "JPEG", False),
        ("archetypes", "kind_healer.jpg", f"{style_base} A South Asian adult healer in ivory robes with gold light-runes, hands emitting a soft golden healing mist. Standing in a minimalist Zen garden at night.", "JPEG", False),
        ("archetypes", "clever_inventor.jpg", f"{style_base} An East Asian adult inventor in a minimalist studio, surrounded by complex 3D holographic light-maps and floating blueprints. Cinematic lighting.", "JPEG", False),
        ("archetypes", "speedy_explorer.jpg", f"{style_base} A Hispanic adult explorer in sleek gear, holding a glowing digital pulse-compass. Standing on a dramatic wind-swept salt flat under a galaxy-filled sky.", "JPEG", False),
        ("archetypes", "mighty_guardian.jpg", f"{style_base} A Caucasian adult guardian in heavy minimalist armor with a glowing silver emblem, holding a massive translucent energy shield before an ancient monolithic gateway.", "JPEG", False),
        ("archetypes", "gentle_dreamer.jpg", f"{style_base} A Middle Eastern adult dreamer seated in mid-air, surrounded by orbiting glowing digital scrolls in a deep space observatory.", "JPEG", False),

        # FEELINGS (Diverse Adult 3D Faces)
        ("feelings", "happy.png", f"{style_base} A diverse adult face, subtle authentic 3D smile. Platinum gradient background. Minimalist geometric sun icon.", "PNG", True),
        ("feelings", "sad.png", f"{style_base} A diverse adult face, contemplative downcast eyes, moody atmosphere. Muted charcoal circle. Minimalist geometric moon icon.", "PNG", True),
        ("feelings", "angry.png", f"{style_base} A diverse adult face, focused intensity, furrowed brows. Deep crimson-to-black circle. Minimalist geometric spark icon.", "PNG", True),
        ("feelings", "scared.png", f"{style_base} A diverse adult face, wide alert eyes, sharp focus. Dark indigo circle. Minimalist geometric eye icon.", "PNG", True),
        ("feelings", "surprised.png", f"{style_base} A diverse adult face, wide eyes, neutral-O mouth. Deep teal circle. Minimalist geometric burst icon.", "PNG", True),
        ("feelings", "calm.png", f"{style_base} A diverse adult face, closed eyes, serene focused expression. Deep slate-gray circle. Minimalist geometric ripple icon.", "PNG", True),
        ("feelings", "excited.png", f"{style_base} A diverse adult face, sharp dynamic eyes, confident smile. Deep gold circle. Minimalist geometric energy icon.", "PNG", True),
        ("feelings", "confused.png", f"{style_base} A diverse adult face, head slightly tilted, thoughtful expression. Dark blue-gray circle. Minimalist geometric mark icon.", "PNG", True),

        # COMPANIONS (Mythic 3D)
        ("companions", "shadow_lynx.png", f"{style_base} A majestic mythic shadow lynx, deep violet eyes, obsidian fur with glowing patterns. Sophisticated 3D model.", "PNG", True),
        ("companions", "iron_golem.png", f"{style_base} A massive mythic golem, smooth matte obsidian and silver crystal. Formidable protective architecture.", "PNG", True),
        ("companions", "storm_hawk.png", f"{style_base} A massive mythic hawk, silver-black metallic feathers, wingtips crackling with white energy. Epic 3D model.", "PNG", True),
        ("companions", "void_sprite.png", f"{style_base} A small mythic ethereal sprite, translucent silver body with visible nebula clouds inside. Ethereal wings.", "PNG", True),

        # SCENE CARDS
        ("scenes", "ruined_citadel.jpg", f"{style_base} Magnificent ancient monolith ruins at twilight, minimalist geometry, bioluminescent flora, deep shadows. Epic scale.", "JPEG", False),
        ("scenes", "orbital_station.jpg", f"{style_base} Minimalist 3D space station interior, earth visible through massive glass, dramatic contrast between dark interior and bright planet.", "JPEG", False),
        ("scenes", "deep_archive.jpg", f"{style_base} Impossibly large minimalist 3D library, soaring dark arches, illuminated ancient digital stacks. Atmospheric.", "JPEG", False),
        ("scenes", "tidal_shrine.jpg", f"{style_base} Monolithic 3D shrine on a sea stack, dramatic ocean waves, bioluminescent coral light, moody twilight. Cinematic depth.", "JPEG", False),

        # BACKGROUNDS
        ("backgrounds", "splash_bg.jpg", f"{style_base} Epic minimalist deep space panorama, subtle star clusters, muted violet nebula. Dark and premium feel.", "JPEG", False),
        ("backgrounds", "story_page_bg.jpg", f"{style_base} Sophisticated dark obsidian-glass background, subtle texture. Ultra-minimal platinum borders.", "JPEG", False),
    ]

    summary = []
    for subfolder, filename, prompt, fmt, black_bg in assets:
        output_path = base_dir / subfolder / filename
        if generate_image(prompt, output_path, format=fmt, force_black_bg=black_bg):
            summary.append(str(output_path))
            time.sleep(20) 
            
    logger.info(f"Adult ({age_band}) Fine-Art Cinematic style batch complete!")

if __name__ == "__main__":
    main()
