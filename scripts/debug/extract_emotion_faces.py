#!/usr/bin/env python3
"""
Extract individual emotion faces from composite images.
Crops each face and saves as a separate PNG file for the feelings wheel.
"""

from PIL import Image
import os

# Define the emotions and their positions in each composite image
# Format: filename -> [(emotion_name, x, y, width, height), ...]

COMPOSITE_IMAGES = {
    # Accepted.jpeg - 4x2 grid (Accepted, Respected, Valued, Powerful on top, Powerful variants + Courageous + Creative on bottom)
    "Accepted.jpeg": {
        "grid": (4, 2),
        "emotions": ["accepted", "respected", "valued", "powerful", "powerful", "powerful", "courageous", "creative"],
        "skip_duplicates": True
    },

    # peaceful.jpeg - 4x2 grid (Peaceful, Loving, Thankful, Trusting on top, Trusting, Sensitive variations, Intimate on bottom)
    "peaceful.jpeg": {
        "grid": (4, 2),
        "emotions": ["peaceful", "loving", "thankful", "trusting", "trusting", "sensitive", "sensitive", "intimate"],
        "skip_duplicates": True
    },

    # optimistic.jpeg - 4x2 grid (Optimistic, Hopeful, Inspired, Excited on top, Excited, Energetic variations, Eager on bottom)
    "optimistic.jpeg": {
        "grid": (4, 2),
        "emotions": ["optimistic", "hopeful", "inspired", "excited", "excited", "energetic", "energetic", "eager"],
        "skip_duplicates": True
    },

    # bored.png - 4x2 grid (Bored, Apathetic, Indifferent, Blowly on top, Scared, Helpless, Frightened on bottom)
    "bored.png": {
        "grid": (4, 2),
        "emotions": ["bored", "apathetic", "indifferent", "blowly", "scared", "helpless", "frightened"],
        "partial_row": 3  # Only 3 items in bottom row
    },

    # Mad.png - 4x2 grid (Mad, Furious, Jealous, Aggressive on top, Aggressive, Provoked, Auctiole, Hostile on bottom)
    "Mad.png": {
        "grid": (4, 2),
        "emotions": ["mad", "furious", "jealous", "aggressive", "aggressive", "provoked", "auctiole", "hostile"],
        "skip_duplicates": True
    },

    # amazed.jpg - 3x2 grid (Amazed, Awe, Astonished on top, Confused, Perplexed, Disillusioned on bottom)
    "amazed.jpg": {
        "grid": (3, 2),
        "emotions": ["amazed", "awe", "astonished", "confused", "perplexed", "disillusioned"]
    },

    # startled.jpg - 3x2 grid (Startled, Dismayed, Shocked on top, Tired, Unfocused, Sleepy on bottom)
    "startled.jpg": {
        "grid": (3, 2),
        "emotions": ["startled", "dismayed", "shocked", "tired", "unfocused", "sleepy"]
    },

    # stressed.jpg - 3x2 grid (Stressed, Out of Control, Overwhelmed on top, Busy, Rushed, Pressured on bottom)
    "stressed.jpg": {
        "grid": (3, 2),
        "emotions": ["stressed", "out_of_control", "overwhelmed", "busy", "rushed", "pressured"]
    },

    # anxious.jpg - 3x2 grid (Anxious, Overwhelmed, Worried on top, Insecure, Inadequate, Inferior on bottom)
    "anxious.jpg": {
        "grid": (3, 2),
        "emotions": ["anxious", "overwhelmed", "worried", "insecure", "inadequate", "inferior"],
        "skip_duplicates": True
    },

    # weak.jpg - 3x2 grid (Weak, Worthless, Insignificant on top, Rejected, Excluded, Persecuted on bottom)
    "weak.jpg": {
        "grid": (3, 2),
        "emotions": ["weak", "worthless", "insignificant", "rejected", "excluded", "persecuted"]
    },

    # threatened.jpg - 3x2 grid (Threatened, Nervous, Exposed on top, Let Down, Betrayed, Resentful on bottom)
    "threatened.jpg": {
        "grid": (3, 2),
        "emotions": ["threatened", "nervous", "exposed", "let_down", "betrayed", "resentful"]
    },

    # humiliated.jpg - 3x2 grid (Humiliated, Disrespected, Ridiculed on top, Bitter, Indignant, Violated on bottom)
    "humiliated.jpg": {
        "grid": (3, 2),
        "emotions": ["humiliated", "disrespected", "ridiculed", "bitter", "indignant", "violated"]
    },

    # frustrated.jpeg - 4x2 grid (Frustrated, Infuriated, Annoyed, Annoyed on top, Distant, Withdrawn, Numb on bottom)
    "frustrated.jpeg": {
        "grid": (4, 2),
        "emotions": ["frustrated", "infuriated", "annoyed", "annoyed", "distant", "withdrawn", "numb"],
        "skip_duplicates": True,
        "partial_row": 3  # Only 3 items in bottom row
    },

    # critical.jpg - 4x2 grid (Critical, Skeptical, Dismissive, Disapproving on top, Disapproving, Judgmental, Embarrassed on bottom)
    "critical.jpg": {
        "grid": (4, 2),
        "emotions": ["critical", "skeptical", "dismissive", "disapproving", "disapproving", "judgmental", "embarrassed"],
        "skip_duplicates": True,
        "partial_row": 3  # Only 3 items in bottom row
    },

    # depressed.jpeg - 3x2 grid (Depressed, Inferior, Empty on top, Guilty, Remorseful, Ashamed on bottom)
    "depressed.jpeg": {
        "grid": (3, 2),
        "emotions": ["depressed", "inferior", "empty", "guilty", "remorseful", "ashamed"],
        "skip_duplicates": True
    },

    # dispair.jpeg - 3x2 grid (Despair, Powerless, Grief on top, Vulnerable, Fragile, Victimized on bottom)
    "dispair.jpeg": {
        "grid": (3, 2),
        "emotions": ["despair", "powerless", "grief", "vulnerable", "fragile", "victimized"],
        "skip_duplicates": True
    },

    # dissappointed.jpg - 4x2 grid (Disappointed, Appalled, Revolted, Snawed on top, Awful, Nauseated, Detestable on bottom)
    "dissappointed.jpg": {
        "grid": (4, 2),
        "emotions": ["disappointed", "appalled", "revolted", "snawed", "awful", "nauseated", "detestable"],
        "partial_row": 3  # Only 3 items in bottom row
    }
}


def extract_faces_from_grid(image_path, output_dir, grid_info):
    """Extract individual faces from a grid layout image."""
    try:
        img = Image.open(image_path)
        width, height = img.size

        cols, rows = grid_info["grid"]
        emotions = grid_info["emotions"]
        skip_duplicates = grid_info.get("skip_duplicates", False)
        partial_row = grid_info.get("partial_row", None)

        # Calculate cell dimensions
        cell_width = width // cols
        cell_height = height // rows

        # Track extracted emotions to avoid duplicates
        extracted = set()
        emotion_idx = 0

        for row in range(rows):
            # Determine columns for this row
            cols_in_row = partial_row if (row == rows - 1 and partial_row) else cols

            for col in range(cols_in_row):
                if emotion_idx >= len(emotions):
                    break

                emotion_name = emotions[emotion_idx]
                emotion_idx += 1

                # Skip duplicates if requested
                if skip_duplicates and emotion_name in extracted:
                    continue

                extracted.add(emotion_name)

                # Calculate crop box
                left = col * cell_width
                top = row * cell_height
                right = left + cell_width
                bottom = top + cell_height

                # Add some padding to crop (remove whitespace around face)
                padding = int(min(cell_width, cell_height) * 0.1)
                left += padding
                top += padding
                right -= padding
                bottom -= padding

                # Crop the face
                face = img.crop((left, top, right, bottom))

                # Resize to standard 200x200
                face = face.resize((200, 200), Image.Resampling.LANCZOS)

                # Save as PNG
                output_path = os.path.join(output_dir, f"{emotion_name}.png")
                face.save(output_path, "PNG")
                print(f"  [OK] Extracted: {emotion_name}.png")

    except Exception as e:
        print(f"  [ERROR] Error processing {os.path.basename(image_path)}: {e}")


def main():
    """Main extraction function."""
    source_dir = r"C:\dev\story-weaver-app\feelings wheel images"
    output_dir = r"C:\dev\story-weaver-app\assets\feelings_faces"

    # Ensure output directory exists
    os.makedirs(output_dir, exist_ok=True)

    print("Extracting emotion faces from composite images...\n")

    # Process each composite image
    for filename, grid_info in COMPOSITE_IMAGES.items():
        image_path = os.path.join(source_dir, filename)

        if not os.path.exists(image_path):
            print(f"WARNING: Skipping {filename} (not found)")
            continue

        print(f"Processing {filename}...")
        extract_faces_from_grid(image_path, output_dir, grid_info)

    print(f"\nExtraction complete! All faces saved to:")
    print(f"   {output_dir}")

    # Count total files
    total_files = len([f for f in os.listdir(output_dir) if f.endswith('.png')])
    print(f"\nTotal emotion faces: {total_files}")


if __name__ == "__main__":
    main()
