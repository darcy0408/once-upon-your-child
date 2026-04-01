"""
One-off script: generate the "Super Brave!" sprout archetype image using Imagen 4.
Run from the backend/ directory:  python generate_brave_hero.py
"""

import base64
import os
import sys

def main():
    api_key = os.getenv("GEMINI_API_KEY")
    if not api_key:
        print("ERROR: GEMINI_API_KEY environment variable not set.")
        sys.exit(1)

    from google import genai
    from google.genai import types

    client = genai.Client(api_key=api_key)

    prompt = (
        "3D animated cartoon illustration in the style of Pixar or Disney animation, square format. "
        "A small brave adventurer character with warm dark brown skin tone, "
        "short rounded natural black hair, very large expressive cartoon eyes, big round cheeks — "
        "clearly a cartoon character, not photorealistic. "
        "Gender-neutral adventurer outfit: rust-orange vest over a cream tunic, rolled trousers, small boots. "
        "Standing boldly on a mossy mountain ledge, arms spread wide, chin tilted up with a huge joyful grin, "
        "looking out over a vast magical fantasy landscape: glowing flower-covered hills, "
        "a shimmering rainbow arching across a golden sunset sky, tiny sparkly birds swirling around. "
        "Pose conveys pure bravery and excitement. "
        "Warm golden-hour light, rich saturated jewel-tone colors, soft cinematic lighting. "
        "3D cartoon render style — smooth surfaces, cel-shading hints, volumetric light rays. "
        "No text, no watermarks, no logos."
    )

    model = "gemini-2.5-flash-image"
    print(f"Generating image with {model}...")

    response = client.models.generate_content(
        model=model,
        contents=prompt,
        config=types.GenerateContentConfig(
            response_modalities=["IMAGE", "TEXT"],
        ),
    )

    # Extract image bytes from response
    image_bytes = None
    if hasattr(response, 'candidates') and response.candidates:
        for candidate in response.candidates:
            if hasattr(candidate, 'content') and hasattr(candidate.content, 'parts'):
                for part in candidate.content.parts:
                    if hasattr(part, 'inline_data') and part.inline_data:
                        image_bytes = part.inline_data.data
                        break
            if image_bytes:
                break

    if not image_bytes:
        print("No image returned. Response:")
        print(response)
        sys.exit(1)

    # Convert to JPEG and save
    from PIL import Image
    import io
    img = Image.open(io.BytesIO(image_bytes))
    img = img.convert("RGB")

    out_path = os.path.normpath(os.path.join(
        os.path.dirname(__file__),
        "..", "assets", "images", "archetypes", "sprout", "brave_explorer.jpg"
    ))
    img.save(out_path, "JPEG", quality=92)
    print(f"\nSaved to: {out_path}")


if __name__ == "__main__":
    main()
