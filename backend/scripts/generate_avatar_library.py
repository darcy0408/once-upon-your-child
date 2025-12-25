"""
Avatar Library Generator
One-time script to generate 35 high-quality pre-made avatars

Usage:
    python backend/scripts/generate_avatar_library.py

Output:
    - 35 PNG images in backend/static/avatar_library/
    - 35 thumbnail images in backend/static/avatar_library/thumbs/
    - metadata file backend/static/avatar_library/avatars.json
"""

import os
import sys
import json
import base64
from pathlib import Path
from PIL import Image
import io
from datetime import datetime

# Add backend to path
sys.path.insert(0, str(Path(__file__).parent.parent))

from data.avatar_templates import AVATAR_TEMPLATES
from gemini_image_generator import GeminiImageGenerator

# Paths
SCRIPT_DIR = Path(__file__).parent
BACKEND_DIR = SCRIPT_DIR.parent
STATIC_DIR = BACKEND_DIR / "static"
AVATAR_LIBRARY_DIR = STATIC_DIR / "avatar_library"
THUMBS_DIR = AVATAR_LIBRARY_DIR / "thumbs"

# Ensure directories exist
AVATAR_LIBRARY_DIR.mkdir(parents=True, exist_ok=True)
THUMBS_DIR.mkdir(parents=True, exist_ok=True)


def build_avatar_prompt(template: dict) -> str:
    """Build detailed prompt for avatar generation"""

    style_details = {
        'pixar': 'Pixar 3D animation style with rounded features, expressive large eyes, smooth rendering, vibrant colors, professional Disney/Pixar quality',
        'watercolor': 'Soft watercolor illustration style with gentle brush strokes, pastel colors, artistic and dreamy, hand-painted quality',
        'cartoon': '2D cartoon animation style with bold outlines, vibrant colors, dynamic and expressive, professional animated series quality',
        'clay': 'Claymation style with textured appearance, playful 3D modeling, tactile and charming, stop-motion animation quality'
    }

    age_descriptors = {
        (1, 6): 'very young child',
        (7, 9): 'young child',
        (10, 12): 'pre-teen child',
        (13, 17): 'young teenager'
    }

    age_desc = 'child'
    for age_range, desc in age_descriptors.items():
        if age_range[0] <= template['age'] <= age_range[1]:
            age_desc = desc
            break

    prompt = f"""
Create a beautiful portrait avatar in {style_details[template['style']]}.

CHARACTER DESCRIPTION:
- Name: {template['name']}
- Age: {template['age']} years old ({age_desc})
- Gender presentation: {template['gender']}
- Skin tone: {template['skin_tone']}
- Hair: {template['hair_style']}, {template['hair_color']}
- Outfit: {template['outfit']}
- Expression: {template['expression']}
- Personality: {', '.join(template['tags'][:3])}

COMPOSITION:
- Portrait orientation (shoulders up, facing forward)
- Centered subject
- Simple gradient or soft-focus background
- Professional quality, polished and appealing
- Age-appropriate and child-friendly

STYLE REQUIREMENTS:
- Art style: {template['style']} - {style_details[template['style']]}
- NON-photorealistic: Clearly stylized artwork, not a photograph
- Vibrant, appealing colors
- Expressive and friendly
- Professional illustration quality
- Safe and appropriate for children ages 3-17

CRITICAL SAFETY:
- NEVER photorealistic or photo-like
- ALWAYS clearly stylized artwork
- Age-appropriate content only
- Positive, uplifting emotional tone
- Inclusive and respectful representation

OUTPUT: A single beautiful avatar portrait in {template['style']} style showing {template['name']}, a {age_desc} with {template['hair_color']} {template['hair_style']} hair, {template['skin_tone']} skin, wearing {template['outfit']}, with a {template['expression']} expression.
"""

    return prompt.strip()


def generate_avatar(template: dict, image_generator: GeminiImageGenerator) -> bytes:
    """Generate a single avatar image"""
    print(f"  Building prompt for {template['name']}...")
    prompt = build_avatar_prompt(template)

    print(f"  Calling Gemini API...")
    try:
        # Use the character avatar generation method
        result = image_generator.generate_character_avatar(
            prompt=prompt,
            character_name=template['name'],
            age=template['age'],
            style=template['style'],
            num_images=1
        )

        if result and len(result) > 0:
            # Extract base64 image
            image_base64 = result[0]['base64']
            # Decode to bytes
            image_bytes = base64.b64decode(image_base64)
            return image_bytes
        else:
            raise Exception("No image generated")

    except Exception as e:
        print(f"  ❌ Error generating {template['id']}: {e}")
        return None


def save_avatar_images(template_id: str, image_bytes: bytes):
    """Save full-size and thumbnail images"""

    # Save full-size image
    full_path = AVATAR_LIBRARY_DIR / f"{template_id}.png"
    with open(full_path, 'wb') as f:
        f.write(image_bytes)
    print(f"  ✅ Saved full-size: {full_path}")

    # Create and save thumbnail (256x256)
    try:
        image = Image.open(io.BytesIO(image_bytes))
        image.thumbnail((256, 256), Image.Resampling.LANCZOS)

        thumb_path = THUMBS_DIR / f"{template_id}.png"
        image.save(thumb_path, "PNG")
        print(f"  ✅ Saved thumbnail: {thumb_path}")
    except Exception as e:
        print(f"  ⚠️ Error creating thumbnail: {e}")


def generate_all_avatars(start_from: int = 0, limit: int = None):
    """Generate all avatar library images"""

    print(f"\n{'='*60}")
    print(f"AVATAR LIBRARY GENERATOR")
    print(f"{'='*60}\n")

    # Initialize Gemini
    print("Initializing Gemini Image Generator...")
    image_generator = GeminiImageGenerator()
    print("✅ Ready!\n")

    templates_to_generate = AVATAR_TEMPLATES[start_from:]
    if limit:
        templates_to_generate = templates_to_generate[:limit]

    total = len(templates_to_generate)
    generated_metadata = []

    print(f"Generating {total} avatars (starting from index {start_from})...\n")

    for idx, template in enumerate(templates_to_generate, start=1):
        print(f"[{idx}/{total}] Generating: {template['id']} - {template['name']}")
        print(f"  Style: {template['style']} | Age: {template['age']} | {template['gender']}")

        # Generate the avatar
        image_bytes = generate_avatar(template, image_generator)

        if image_bytes:
            # Save images
            save_avatar_images(template['id'], image_bytes)

            # Add to metadata
            generated_metadata.append({
                "id": template['id'],
                "filename": f"{template['id']}.png",
                "thumbnail": f"thumbs/{template['id']}.png",
                "name": template['name'],
                "style": template['style'],
                "age": template['age'],
                "gender": template['gender'],
                "skin_tone": template['skin_tone'],
                "hair_style": template['hair_style'],
                "hair_color": template['hair_color'],
                "outfit": template['outfit'],
                "expression": template['expression'],
                "tags": template['tags'],
                "generated_at": datetime.now().isoformat()
            })

            print(f"  ✅ Complete!\n")
        else:
            print(f"  ❌ Failed to generate {template['id']}\n")

        # Small delay to avoid rate limiting
        import time
        if idx < total:
            print(f"  Waiting 5 seconds before next generation...")
            time.sleep(5)

    # Save metadata JSON
    metadata_path = AVATAR_LIBRARY_DIR / "avatars.json"
    metadata = {
        "version": "1.0",
        "generated_at": datetime.now().isoformat(),
        "total_avatars": len(generated_metadata),
        "avatars": generated_metadata
    }

    with open(metadata_path, 'w', encoding='utf-8') as f:
        json.dump(metadata, f, indent=2, ensure_ascii=False)

    print(f"\n{'='*60}")
    print(f"✅ GENERATION COMPLETE!")
    print(f"{'='*60}")
    print(f"Generated: {len(generated_metadata)}/{total} avatars")
    print(f"Saved to: {AVATAR_LIBRARY_DIR}")
    print(f"Metadata: {metadata_path}")
    print(f"{'='*60}\n")


def test_single_avatar(template_index: int = 0):
    """Test generation with a single avatar"""
    print(f"\n{'='*60}")
    print(f"TESTING SINGLE AVATAR GENERATION")
    print(f"{'='*60}\n")

    if template_index >= len(AVATAR_TEMPLATES):
        print(f"❌ Invalid template index. Max is {len(AVATAR_TEMPLATES) - 1}")
        return

    template = AVATAR_TEMPLATES[template_index]

    print(f"Testing with: {template['id']} - {template['name']}")
    print(f"Style: {template['style']}\n")

    # Initialize Gemini
    print("Initializing Gemini...")
    image_generator = GeminiImageGenerator()
    print("✅ Ready!\n")

    # Generate
    image_bytes = generate_avatar(template, image_generator)

    if image_bytes:
        # Save test image
        test_dir = AVATAR_LIBRARY_DIR / "test"
        test_dir.mkdir(exist_ok=True)

        test_path = test_dir / f"test_{template['id']}.png"
        with open(test_path, 'wb') as f:
            f.write(image_bytes)

        print(f"\n✅ Test successful!")
        print(f"Saved test image to: {test_path}")
        print(f"You can view it to verify quality before generating all 35.")
    else:
        print(f"\n❌ Test failed")


if __name__ == "__main__":
    import argparse

    parser = argparse.ArgumentParser(description="Generate Avatar Library")
    parser.add_argument('--test', action='store_true', help='Test with a single avatar')
    parser.add_argument('--index', type=int, default=0, help='Template index for test mode')
    parser.add_argument('--start', type=int, default=0, help='Start from this index')
    parser.add_argument('--limit', type=int, default=None, help='Generate only this many')

    args = parser.parse_args()

    if args.test:
        test_single_avatar(args.index)
    else:
        generate_all_avatars(start_from=args.start, limit=args.limit)
