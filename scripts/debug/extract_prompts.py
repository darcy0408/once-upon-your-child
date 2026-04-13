import json
from pathlib import Path

def main():
    tasks = []
    
    # --- CRITICAL — Blank/Empty Files (render nothing in production) ---
    
    # assets/images/scenarios/
    scenarios = [
        ("sparkle_cave.png", "Generate a bold cartoon illustration image for a children's therapeutic storytelling app. A magical glowing cave filled with giant pink and purple crystals, soft golden light streaming from within, with a small cozy entrance framed by glowing flowers. The image should feel wonder-filled, safe and magical. Art style: bold cartoon, high contrast, warm sparkly colours. No text overlays. Aspect ratio: 1:1. Professional quality, child-safe, therapeutically appropriate."),
        ("cloud_castle.png", "Generate a bold cartoon illustration image for a children's therapeutic storytelling app. A whimsical castle made entirely of fluffy pink and white clouds floating in a sunny sky, with rainbow bridges and tiny friendly birds. The image should feel dreamy, safe and joyful. Art style: bold bright cartoon, soft cloud textures, warm pastel sky. No text overlays. Aspect ratio: 1:1. Professional quality, child-safe, therapeutically appropriate."),
        ("sleeping_dragon.png", "Generate a bold cartoon illustration image for a children's therapeutic storytelling app. A friendly baby dragon curled up asleep on a soft grassy hill, surrounded by glowing fireflies and wildflowers, with a peaceful moonlit sky. The image should feel cozy, calm and non-threatening. Art style: bold 3D cartoon, warm earthy tones with soft glow. No text overlays. Aspect ratio: 1:1. Professional quality, child-safe, therapeutically appropriate."),
        ("magic_door.png", "Generate a bold cartoon illustration image for a children's therapeutic storytelling app. An ornate glowing doorway standing in a magical forest, framed by twisted trees with glowing leaves and soft golden light streaming through the keyhole. The image should feel mysterious and inviting, not scary. Art style: bold cartoon, warm golden and emerald tones. No text overlays. Aspect ratio: 1:1. Professional quality, child-safe, therapeutically appropriate."),
        ("rainbow_land.png", "Generate a bold cartoon illustration image for a children's therapeutic storytelling app. A cheerful landscape of rolling hills in every colour of the rainbow, with giant lollipop trees, friendly creatures peeking out, and a bright glowing sky. The image should feel joyful, safe and playful. Art style: bold saturated cartoon, very high contrast, child-friendly. No text overlays. Aspect ratio: 1:1. Professional quality, child-safe, therapeutically appropriate."),
        ("glowing_forest.png", "Generate a bright cartoon illustration image for a children's therapeutic storytelling app. An enchanted forest at twilight where the trees and flowers glow with soft bioluminescent light in blues and greens, with fireflies drifting through the mist. The image should feel wondrous, calm and safe. Art style: bright cartoon with luminous glow effects. No text overlays. Aspect ratio: 1:1. Professional quality, child-safe, therapeutically appropriate."),
        ("confidence.png", "Generate a warm illustration style image for a children's therapeutic storytelling app. A child standing tall on top of a hill with arms open wide, a glowing golden light radiating from their chest, surrounded by cheering woodland creatures. The image should feel empowering, joyful and uplifting. Art style: bright cartoon, warm golden sunrise tones. No text overlays. Aspect ratio: 1:1. Professional quality, child-safe, therapeutically appropriate."),
        ("feelings_quest.png", "Generate a warm illustration style image for a children's therapeutic storytelling app. A treasure map unfurled on a magical table, showing a winding path through a landscape labelled with emotion symbols — hearts, stars, clouds and rainbows — leading to a glowing chest. The image should feel adventurous, emotionally clear and inviting. Art style: bright warm cartoon, parchment and gold tones. No text overlays. Aspect ratio: 1:1. Professional quality, child-safe, therapeutically appropriate."),
        ("transitions.png", "Generate a warm illustration style image for a children's therapeutic storytelling app. A child walking across a beautiful bridge from one season to another — one side is autumn, the other spring — with a gentle warm sunrise in the background. The image should feel hopeful, transitional and peaceful. Art style: bright semi-realistic cartoon illustration, warm colour palette. No text overlays. Aspect ratio: 1:1. Professional quality, child-safe, therapeutically appropriate."),
        ("safe_space.png", "Generate a warm illustration style image for a children's therapeutic storytelling app. A cozy glowing treehouse nestled in a gentle forest at dusk, with warm light pouring from the windows, a soft hammock, friendly animals nearby, and stars beginning to appear in the sky. The image should feel safe, nurturing and peaceful. Art style: warm cartoon with soft lighting. No text overlays. Aspect ratio: 1:1. Professional quality, child-safe, therapeutically appropriate."),
        ("making_friends.png", "Generate a warm illustration style image for a children's therapeutic storytelling app. A diverse group of cartoon children of different ethnicities sitting in a circle in a park, laughing and sharing food, with a colourful kite flying overhead. The image should feel joyful, inclusive and warm. Art style: bright friendly cartoon, diverse characters, warm outdoor setting. No text overlays. Aspect ratio: 1:1. Professional quality, child-safe, therapeutically appropriate."),
    ]
    for filename, prompt in scenarios:
        tasks.append({"output_path": f"assets/images/scenarios/{filename}", "prompt": prompt})

    # assets/images/companions/
    bands = ["sprout", "explorer", "adventurer", "adolescent", "creator", "adult"]
    
    # Sprout (3-5)
    sprout_comps = [
        ("fluffy_dragon.png", "Generate a bold cartoon illustration image for a children's therapeutic storytelling app. An extremely cute, round baby dragon with pastel purple scales, giant sparkly eyes, tiny soft wings, and a friendly toothy grin, shown full-body against a transparent background. The image should feel completely safe, lovable and huggable. Art style: bold 3D cartoon, high contrast, simple shapes, very warm pastel colours. No text overlays. Aspect ratio: 1:1. Professional quality, child-safe, therapeutically appropriate."),
        ("magic_bunny.png", "Generate a bold cartoon illustration image for a children's therapeutic storytelling app. An adorable fluffy bunny with a tiny sparkling wand tucked behind one ear, big dewy eyes, and a magical shimmer around it, shown full-body against a transparent background. Art style: bold 3D cartoon, soft whites and lavender. No text overlays. Aspect ratio: 1:1. Professional quality, child-safe, therapeutically appropriate."),
        ("shining_puppy.png", "Generate a bold cartoon illustration image for a children's therapeutic storytelling app. A cheerful golden puppy with a glowing star on its collar, floppy ears, wagging tail and a huge smile, shown full-body against a transparent background. Art style: bold 3D cartoon, warm golden tones. No text overlays. Aspect ratio: 1:1. Professional quality, child-safe, therapeutically appropriate."),
        ("tiny_fairy.png", "Generate a bold cartoon illustration image for a children's therapeutic storytelling app. A tiny, friendly fairy with translucent rainbow wings, a warm smile and a glowing wand, dressed in soft flower-petal clothes, shown full-body against a transparent background. Art style: bold 3D cartoon, vibrant but soft colours. No text overlays. Aspect ratio: 1:1. Professional quality, child-safe, therapeutically appropriate."),
    ]
    for filename, prompt in sprout_comps:
        tasks.append({"output_path": f"assets/images/companions/sprout/{filename}", "prompt": prompt})
        
    # Explorer (6-8)
    explorer_comps = [
        ("bloom_sprite.png", "Generate a bright cartoon illustration image for a children's therapeutic storytelling app. A cheerful nature sprite with leafy wings, flower-crown hair, and a mischievous smile, surrounded by floating petals, shown full-body against a transparent background. Art style: bright expressive cartoon, diverse friendly character, greens and pinks. No text overlays. Aspect ratio: 1:1. Professional quality, child-safe, therapeutically appropriate."),
        ("ember_dragon.png", "Generate a bright cartoon illustration image for a children's therapeutic storytelling app. A young adventurous dragon with orange ember-glow scales, expressive eyes and small flame-tipped wings, looking friendly and curious, shown full-body against a transparent background. Art style: bright expressive cartoon, warm oranges and teals. No text overlays. Aspect ratio: 1:1. Professional quality, child-safe, therapeutically appropriate."),
        ("moon_owl.png", "Generate a bright cartoon illustration image for a children's therapeutic storytelling app. A wise-looking owl with silver-blue feathers, large amber eyes and a crescent moon marking on its chest, shown perched and full-body against a transparent background. Art style: bright expressive cartoon, silver-blue and gold tones. No text overlays. Aspect ratio: 1:1. Professional quality, child-safe, therapeutically appropriate."),
        ("star_fox.png", "Generate a bright cartoon illustration image for a children's therapeutic storytelling app. A sleek adventurous fox with star-patterned fur and a mischievous-but-friendly expression, shown full-body against a transparent background. Art style: bright expressive cartoon, amber and midnight blue. No text overlays. Aspect ratio: 1:1. Professional quality, child-safe, therapeutically appropriate."),
    ]
    for filename, prompt in explorer_comps:
        tasks.append({"output_path": f"assets/images/companions/explorer/{filename}", "prompt": prompt})

    # Adventurer (9-11)
    adventurer_comps = [
        ("iron_golem.png", "Generate a semi-realistic illustration image for a children's therapeutic storytelling app. A friendly stone golem companion with mossy patches and warm glowing eyes, built from ancient rocks but clearly gentle and protective, shown full-body against a transparent background. The image should feel strong but safe. Art style: semi-realistic illustration, nuanced earthy tones. No text overlays. Aspect ratio: 1:1. Professional quality, child-safe, therapeutically appropriate."),
        ("shadow_lynx.png", "Generate a semi-realistic illustration image for a children's therapeutic storytelling app. An elegant lynx companion with dark smoky fur and glowing amber eyes, shown in a calm sitting pose against a transparent background. The image should feel mysterious but safe and companionable. Art style: semi-realistic illustration, dark greys and warm amber. No text overlays. Aspect ratio: 1:1. Professional quality, child-safe, therapeutically appropriate."),
        ("storm_hawk.png", "Generate a semi-realistic illustration image for a children's therapeutic storytelling app. A powerful hawk with storm-grey feathers and subtle electric blue wing-tip markings, wings slightly spread in a confident pose, against a transparent background. Art style: semi-realistic illustration, cool blues and silver. No text overlays. Aspect ratio: 1:1. Professional quality, child-safe, therapeutically appropriate."),
        ("void_sprite.png", "Generate a semi-realistic illustration image for a children's therapeutic storytelling app. A small ethereal sprite made of swirling dark starfield energy, with a luminous calm face and small glowing hands, shown full-body against a transparent background. Art style: semi-realistic illustration, deep purples and soft gold starlight. No text overlays. Aspect ratio: 1:1. Professional quality, child-safe, therapeutically appropriate."),
    ]
    for filename, prompt in adventurer_comps:
        tasks.append({"output_path": f"assets/images/companions/adventurer/{filename}", "prompt": prompt})

    # Adolescent (12-14)
    adolescent_comps = [
        ("iron_golem.png", "Generate a digital art illustration image for a children's therapeutic storytelling app. A large but clearly gentle stone guardian with ancient carved runes on its body, moss-covered shoulders and warm amber-glowing eyes, shown in a calm standing pose against a transparent background. The image should feel protective and loyal. Art style: digital art, slightly stylised, nuanced earthy and warm tones. No text overlays. Aspect ratio: 1:1. Professional quality, child-safe, therapeutically appropriate."),
        ("shadow_lynx.png", "Generate a digital art illustration image for a children's therapeutic storytelling app. A sleek, elegant lynx with dark fur and subtle glowing violet markings, shown in a confident stance against a transparent background. The image should feel cool, authentic and slightly mysterious but safe. Art style: digital art, slightly stylised, authentic. No text overlays. Aspect ratio: 1:1. Professional quality, child-safe, therapeutically appropriate."),
        ("storm_hawk.png", "Generate a digital art illustration image for a children's therapeutic storytelling app. A majestic hawk with storm-grey and electric blue feathers, shown mid-flight with wings spread against a transparent background. The image should feel powerful, free and purposeful. Art style: digital art, slightly stylised, cool blues and silver. No text overlays. Aspect ratio: 1:1. Professional quality, child-safe, therapeutically appropriate."),
        ("void_sprite.png", "Generate a digital art illustration image for a children's therapeutic storytelling app. An ethereal cosmic sprite made of swirling dark energy and tiny stars, with a luminous calm face and flowing form, shown full-body against a transparent background. Art style: digital art, deep purples and golds, slightly stylised. No text overlays. Aspect ratio: 1:1. Professional quality, child-safe, therapeutically appropriate."),
    ]
    for filename, prompt in adolescent_comps:
        tasks.append({"output_path": f"assets/images/companions/adolescent/{filename}", "prompt": prompt})

    # Creator (15-17) & Adult (18+)
    creator_adult_comps = [
        ("iron_golem.png", "Generate a clean realistic digital art image for a children's therapeutic storytelling app. An ancient stone guardian with beautifully detailed carved runes across its body, warm golden light glowing from cracks in the stone, shown in a calm dignified stance against a transparent background. Art style: clean realistic digital art, detailed stone textures, warm ambient glow. No text overlays. Aspect ratio: 1:1. Professional quality, child-safe, therapeutically appropriate."),
        ("shadow_lynx.png", "Generate a clean realistic digital art image for a children's therapeutic storytelling app. A powerful, serene lynx with deeply dark fur and subtle luminous violet eye markings, shown in profile with a calm gaze, against a transparent background. Art style: clean realistic digital art, understated, mature but appropriate. No text overlays. Aspect ratio: 1:1. Professional quality, child-safe, therapeutically appropriate."),
        ("storm_hawk.png", "Generate a clean realistic digital art image for a children's therapeutic storytelling app. A majestic hawk with storm-grey and electric blue feathers, shown mid-flight with wings fully spread against a transparent background. The image should feel powerful, free and purposeful. Art style: clean realistic digital art, understated, mature but appropriate. No text overlays. Aspect ratio: 1:1. Professional quality, child-safe, therapeutically appropriate."),
        ("void_sprite.png", "Generate a clean realistic digital art image for a children's therapeutic storytelling app. An ethereal sprite made of swirling dark energy and tiny stars, with a calm luminous face and flowing cosmic form, shown full figure against a transparent background. Art style: clean digital art, deep purples and golds, mature but appropriate. No text overlays. Aspect ratio: 1:1. Professional quality, child-safe, therapeutically appropriate."),
    ]
    for b in ["creator", "adult"]:
        for filename, prompt in creator_adult_comps:
            tasks.append({"output_path": f"assets/images/companions/{b}/{filename}", "prompt": prompt})

    # assets/images/scenes/
    
    # Sprout (3-5)
    sprout_scenes = [
        ("candy_forest.png", "Generate a bold cartoon illustration image for a children's therapeutic storytelling app. A magical forest made of giant candy canes, gumdrops and lollipop trees, with friendly animals peeking from behind sweet bushes, under a bright rainbow sky. The image should feel joyful, safe and deliciously fun. Art style: bold bright 3D cartoon, high contrast, very warm colours. No text overlays. Aspect ratio: 1:1. Professional quality, child-safe, therapeutically appropriate."),
        ("cozy_cottage.png", "Generate a bold cartoon illustration image for a children's therapeutic storytelling app. A charming little storybook cottage with a thatched roof, flower window boxes, and a glowing warm light from within, nestled in a soft green meadow with butterflies. Art style: bold bright 3D cartoon, warm homey tones. No text overlays. Aspect ratio: 1:1. Professional quality, child-safe, therapeutically appropriate."),
        ("friendly_ocean.png", "Generate a bold cartoon illustration image for a children's therapeutic storytelling app. A bright tropical beach with a calm turquoise ocean, friendly smiling fish jumping from the waves, a treasure chest on the sand, and a cheerful sun above. Art style: bold bright 3D cartoon, vivid blues and yellows. No text overlays. Aspect ratio: 1:1. Professional quality, child-safe, therapeutically appropriate."),
        ("rainbow_mountain.png", "Generate a bold cartoon illustration image for a children's therapeutic storytelling app. A majestic mountain with each layer a different colour of the rainbow, topped with a golden star, fluffy cloud paths winding up the sides, and happy creatures waving from the slopes. Art style: bold bright 3D cartoon. No text overlays. Aspect ratio: 1:1. Professional quality, child-safe, therapeutically appropriate."),
    ]
    for filename, prompt in sprout_scenes:
        tasks.append({"output_path": f"assets/images/scenes/sprout/{filename}", "prompt": prompt})

    # Explorer (6-8)
    explorer_scenes = [
        ("enchanted_forest.jpg", "Generate a bright cartoon illustration image for a children's therapeutic storytelling app. An ancient enchanted forest with towering glowing trees, a mossy stone path, fireflies, and gentle mystical creatures partially visible between the roots. The image should feel wondrous and safe. Art style: bright expressive cartoon, rich greens and warm amber light. No text overlays. Aspect ratio: 16:9. Professional quality, child-safe, therapeutically appropriate."),
        ("cloud_castle.jpg", "Generate a bright cartoon illustration image for a children's therapeutic storytelling app. A grand white castle floating on a cloud island in a blue sky, with rainbow banners and friendly cloud creatures waving from the ramparts. Art style: bright expressive cartoon, sky blues and white. No text overlays. Aspect ratio: 16:9. Professional quality, child-safe, therapeutically appropriate."),
        ("ocean_depths.jpg", "Generate a bright cartoon illustration image for a children's therapeutic storytelling app. A colourful underwater world with coral towers, friendly sea creatures, glowing jellyfish lanterns, and shafts of light from the surface above. Art style: bright expressive cartoon, vivid teals and corals. No text overlays. Aspect ratio: 16:9. Professional quality, child-safe, therapeutically appropriate."),
        ("star_village.jpg", "Generate a bright cartoon illustration image for a children's therapeutic storytelling app. A village built on floating star-shaped platforms in outer space, with cozy glowing homes, rainbow bridges between stars, and friendly star-people waving hello. Art style: bright expressive cartoon, deep space purples and gold starlight. No text overlays. Aspect ratio: 16:9. Professional quality, child-safe, therapeutically appropriate."),
    ]
    for filename, prompt in explorer_scenes:
        tasks.append({"output_path": f"assets/images/scenes/explorer/{filename}", "prompt": prompt})

    # Adventurer (9-11)
    adventurer_scenes = [
        ("ruined_citadel.jpg", "Generate a semi-realistic illustration image for a children's therapeutic storytelling app. The exterior of an ancient ruined citadel overgrown with vines and glowing plants, moonlight streaming through crumbling arches, with a sense of mystery and discovery. Art style: semi-realistic illustration, moody blues and mossy greens. No text overlays. Aspect ratio: 16:9. Professional quality, child-safe, therapeutically appropriate."),
        ("orbital_station.jpg", "Generate a semi-realistic illustration image for a children's therapeutic storytelling app. A sleek but aged space station orbiting a vivid blue planet, docking bays glowing with activity, stars and nebulae visible through large observation windows. Art style: semi-realistic illustration, cool blues and functional amber lighting. No text overlays. Aspect ratio: 16:9. Professional quality, child-safe, therapeutically appropriate."),
        ("deep_archive.jpg", "Generate a semi-realistic illustration image for a children's therapeutic storytelling app. A vast underground library with soaring shelves disappearing into mist, glowing lanterns on floating platforms, and ancient books with luminous pages. Art style: semi-realistic illustration, warm amber and dark brown. No text overlays. Aspect ratio: 16:9. Professional quality, child-safe, therapeutically appropriate."),
        ("tidal_shrine.jpg", "Generate a semi-realistic illustration image for a children's therapeutic storytelling app. An ancient stone shrine at the edge of the ocean, partially submerged at high tide, glowing runes carved into the rocks, waves crashing softly around it under a dramatic sky. Art style: semi-realistic illustration, teal ocean and stone grey. No text overlays. Aspect ratio: 16:9. Professional quality, child-safe, therapeutically appropriate."),
    ]
    for filename, prompt in adventurer_scenes:
        tasks.append({"output_path": f"assets/images/scenes/adventurer/{filename}", "prompt": prompt})

    # Adolescent (12-14)
    adolescent_scenes = [
        ("ruined_citadel.jpg", "Generate a digital art illustration image for a children's therapeutic storytelling app. The interior of a ruined citadel at night, moonlight breaking through collapsed roof, ancient mosaics still visible on the walls, a sense of lost civilisation and discovery. Art style: digital art, slightly stylised, moody cool tones with warm torch light. No text overlays. Aspect ratio: 16:9. Professional quality, child-safe, therapeutically appropriate."),
        ("orbital_station.jpg", "Generate a digital art illustration image for a children's therapeutic storytelling app. The interior of a space station with large panoramic windows overlooking a glowing planet, teens in functional space suits working together at holographic consoles. Art style: digital art, slightly stylised, cool blues and warm amber accents. No text overlays. Aspect ratio: 16:9. Professional quality, child-safe, therapeutically appropriate."),
        ("deep_archive.jpg", "Generate a digital art illustration image for a children's therapeutic storytelling app. A vast digital archive space — part library, part data centre — with floating holographic pages, ancient and modern merged, glowing pathways through the stacks. Art style: digital art, cool blues and warm amber data-glow. No text overlays. Aspect ratio: 16:9. Professional quality, child-safe, therapeutically appropriate."),
        ("tidal_shrine.jpg", "Generate a digital art illustration image for a children's therapeutic storytelling app. An ancient tidal shrine at sunset, the tide rolling in around carved stone pillars, bioluminescent algae glowing in the water, a single lantern burning at the altar. Art style: digital art, slightly stylised, warm sunset purples and teal water. No text overlays. Aspect ratio: 16:9. Professional quality, child-safe, therapeutically appropriate."),
    ]
    for filename, prompt in adolescent_scenes:
        tasks.append({"output_path": f"assets/images/scenes/adolescent/{filename}", "prompt": prompt})

    # Creator (15-17) & Adult (18+)
    def adapt_scene_prompt(prompt):
        return prompt.replace("Art style: digital art, slightly stylised,", "Art style: clean realistic digital art, understated, mature but appropriate.")
    
    for b in ["creator", "adult"]:
        for filename, prompt in adolescent_scenes:
            tasks.append({"output_path": f"assets/images/scenes/{b}/{filename}", "prompt": adapt_scene_prompt(prompt)})

    # --- HIGH PRIORITY — Inappropriate Content ---
    tasks.append({"output_path": "assets/images/backgrounds/adolescent/story_page_bg.jpg", "prompt": "Generate a digital art background image for a children's therapeutic storytelling app. A calming teen study space with a desk by a rain-streaked window at night, soft desk lamp, open notebook, and plants, creating a quiet reflective atmosphere. The image should feel safe, authentic and contemplative. Art style: clean digital illustration, cool night blues with warm lamp light. No text overlays. Aspect ratio: 1:1. Professional quality, child-safe, therapeutically appropriate."})
    tasks.append({"output_path": "assets/images/backgrounds/adult/story_page_bg.jpg", "prompt": "Generate a clean realistic digital art background image for a children's therapeutic storytelling app. A warm minimalist library with floor-to-ceiling bookshelves, a comfortable reading chair by a window with soft natural light and a steaming cup of tea. The image should feel safe, intellectual and calming. Art style: clean realistic digital art, warm neutral tones. No text overlays. Aspect ratio: 1:1. Professional quality, child-safe, therapeutically appropriate."})
    tasks.append({"output_path": "assets/images/backgrounds/adventurer/story_page_bg.jpg", "prompt": "Generate a semi-realistic illustration background image for a children's therapeutic storytelling app. A young adventurer (10 years old, gender-neutral) reading a glowing map in a cozy candlelit study filled with artefacts, soft warm light. The image should feel curious and safe. Art style: semi-realistic illustration, warm amber tones. No text overlays. Aspect ratio: 1:1. Professional quality, child-safe, therapeutically appropriate."})
    tasks.append({"output_path": "assets/images/backgrounds/creator/story_page_bg.jpg", "prompt": "Generate a clean realistic digital art background image for a children's therapeutic storytelling app. A creative studio space with a large desk covered in drawings, art supplies and a glowing screen, walls covered with pinned stories and sketches, warm afternoon light. The image should feel creative, productive and inspiring. Art style: clean digital illustration, warm creative-space tones. No text overlays. Aspect ratio: 1:1. Professional quality, child-safe, therapeutically appropriate."})

    # --- HIGH PRIORITY — All Identical Placeholder (themes) ---
    themes = [
        ("adventure.png", "Generate a bright cartoon illustration image for a children's therapeutic storytelling app. A circular icon showing a young adventurer with a backpack climbing a mountain path toward a glowing horizon, stars and sky behind. Art style: bright expressive cartoon. No text overlays. Aspect ratio: 1:1. Professional quality, child-safe, therapeutically appropriate."),
        ("animals.png", "Generate a bright cartoon illustration image for a children's therapeutic storytelling app. A circular icon showing a diverse group of friendly animals — a fox, owl, bunny and bear — gathered together in a warm forest clearing. Art style: bright expressive cartoon. No text overlays. Aspect ratio: 1:1. Professional quality, child-safe, therapeutically appropriate."),
        ("forest.png", "Generate a bright cartoon illustration image for a children's therapeutic storytelling app. A circular icon showing the entrance to a glowing magical forest at dawn, with fireflies and an inviting mossy path leading inward. Art style: bright expressive cartoon. No text overlays. Aspect ratio: 1:1. Professional quality, child-safe, therapeutically appropriate."),
        ("friendship.png", "Generate a bright cartoon illustration image for a children's therapeutic storytelling app. A circular icon showing two diverse children high-fiving joyfully, surrounded by sparkles and hearts. Art style: bright expressive cartoon, diverse characters. No text overlays. Aspect ratio: 1:1. Professional quality, child-safe, therapeutically appropriate."),
        ("magic.png", "Generate a bright cartoon illustration image for a children's therapeutic storytelling app. A circular icon showing an open spellbook with glowing runes, stars and a swirling magical aura rising from its pages. Art style: bright expressive cartoon. No text overlays. Aspect ratio: 1:1. Professional quality, child-safe, therapeutically appropriate."),
        ("princess.png", "Generate a bright cartoon illustration image for a children's therapeutic storytelling app. A circular icon showing a confident young princess — diverse, not stereotypically white — in practical armour with a small crown, holding a glowing staff. Art style: bright expressive cartoon. No text overlays. Aspect ratio: 1:1. Professional quality, child-safe, therapeutically appropriate."),
    ]
    for filename, prompt in themes:
        tasks.append({"output_path": f"assets/images/themes/{filename}", "prompt": prompt})

    # --- HIGH PRIORITY — Feelings Faces Clipart Replacement ---
    feeling_template = "Generate a bold cartoon illustration image for a children's therapeutic storytelling app. A warm expressive round face clearly showing the emotion [EMOTION], with natural skin tones, full colour rendering on a transparent background. The expression should be unmistakably clear and appropriate for children aged 6–12. Art style: bold 3D cartoon, warm neutral skin (ethnically inclusive). No text overlays. Aspect ratio: 1:1. Professional quality, child-safe, therapeutically appropriate."
    
    feelings_core = ["happy", "sad", "angry", "fearful", "disgusted", "surprised", "bad"]
    feelings_secondary = ["content", "interested", "playful", "proud"]
    feelings_tertiary = ["stimulated", "cheeky", "confident", "content", "curious", "free", "inquisitive", "joyful", "successful"] # aroused -> stimulated
    
    for f in feelings_core:
        tasks.append({"output_path": f"assets/images/feelings_faces/core/{f}.png", "prompt": feeling_template.replace("[EMOTION]", f)})
    for f in feelings_secondary:
        tasks.append({"output_path": f"assets/images/feelings_faces/secondary/{f}.png", "prompt": feeling_template.replace("[EMOTION]", f)})
    for f in feelings_tertiary:
        tasks.append({"output_path": f"assets/images/feelings_faces/tertiary/{f}.png", "prompt": feeling_template.replace("[EMOTION]", f)})

    # --- MEDIUM PRIORITY — Age-Inappropriate UI Characters ---
    # Adolescent characters
    adol_chars = [
        ("boy_character.png", "Generate a digital art illustration image for a children's therapeutic storytelling app. A friendly teenage boy aged around 13, with natural messy hair, a hoodie and jeans, neutral ethnicity, confident but approachable expression. Portrait from shoulders up, transparent background. Art style: digital art, slightly stylised but authentic teen look. No text overlays. Aspect ratio: 1:1. Professional quality, child-safe, therapeutically appropriate."),
        ("girl_character.png", "Generate a digital art illustration image for a children's therapeutic storytelling app. A friendly teenage girl aged around 13, natural hair in a ponytail, wearing a casual jacket, neutral ethnicity, warm confident expression, minimal natural styling. Portrait from shoulders up, transparent background. Art style: digital art, slightly stylised but authentic teen look. No text overlays. Aspect ratio: 1:1. Professional quality, child-safe, therapeutically appropriate."),
    ]
    ethnicities = ["_asian", "_black", "_hispanic", "_south_asian"]
    for filename, base_prompt in adol_chars:
        # Main one
        tasks.append({"output_path": f"assets/images/ui/adolescent/{filename}", "prompt": base_prompt})
        # Variants
        for eth in ethnicities:
            v_filename = filename.replace(".png", f"{eth}.png")
            v_prompt = base_prompt.replace("neutral ethnicity", f"{eth.strip('_')} ethnicity")
            tasks.append({"output_path": f"assets/images/ui/adolescent/{v_filename}", "prompt": v_prompt})

    # Adult characters
    adult_chars = [
        ("man_character_white.png", "Generate a clean realistic digital art illustration image for a children's therapeutic storytelling app. A confident young person (17 years old, male, Caucasian) with a thoughtful expression, casual clothing — plain shirt, no suit — transparent background. Portrait from shoulders up. Art style: clean realistic digital art, understated. No text overlays. Aspect ratio: 1:1. Professional quality, child-safe, therapeutically appropriate."),
        ("woman_character_white.png", "Generate a clean realistic digital art illustration image for a children's therapeutic storytelling app. A confident young person (17 years old, female, Caucasian) with a warm expression, casual clothing, transparent background. Portrait from shoulders up. Art style: clean realistic digital art, understated. No text overlays. Aspect ratio: 1:1. Professional quality, child-safe, therapeutically appropriate."),
    ]
    for filename, base_prompt in adult_chars:
        tasks.append({"output_path": f"assets/images/ui/adult/{filename}", "prompt": base_prompt})
        for eth in ethnicities:
            v_filename = filename.replace("_white.png", f"{eth}.png")
            v_prompt = base_prompt.replace("Caucasian", f"{eth.strip('_')}")
            tasks.append({"output_path": f"assets/images/ui/adult/{v_filename}", "prompt": v_prompt})

    # Creator characters
    tasks.append({"output_path": "assets/images/ui/creator/creator_white.png", "prompt": "Generate a clean realistic digital art illustration image for a children's therapeutic storytelling app. A young creative person (age 16, female, Caucasian) with an energised, inspired expression, holding a pencil or stylus, surrounded by soft swirls of creative energy. Portrait from shoulders up, transparent background. Art style: clean digital art, warm creative atmosphere. No text overlays. Aspect ratio: 1:1. Professional quality, child-safe, therapeutically appropriate."})
    tasks.append({"output_path": "assets/images/ui/creator/creator_black.png", "prompt": "Generate a clean realistic digital art illustration image for a children's therapeutic storytelling app. A young creative person (age 16, male, Black) with a confident, inspired expression, sketchbook in hand, creative energy around them. Portrait from shoulders up, transparent background. Art style: clean digital art, warm creative atmosphere. No text overlays. Aspect ratio: 1:1. Professional quality, child-safe, therapeutically appropriate."})

    # --- MEDIUM PRIORITY — UI Continue/Make-Magic Buttons ---
    tasks.append({"output_path": "assets/images/ui/adolescent/continue_button.png", "prompt": "Generate a digital art UI button image for a children's therapeutic storytelling app. A sleek dark circle button with a glowing teal forward-pointing arrow at centre, with subtle star particles around the edge. Transparent background. Art style: digital art, cool dark tones with teal glow. No text. Aspect ratio: 1:1. Professional quality, child-safe."})
    tasks.append({"output_path": "assets/images/ui/adult/continue_button.png", "prompt": "Generate a clean realistic digital art UI button image for a children's therapeutic storytelling app. A clean dark circular button with a minimal glowing forward arrow, subtle aurora-light edge glow. Transparent background. No characters. Art style: clean minimal digital art. No text. Aspect ratio: 1:1. Professional quality, child-safe."})

    # --- MEDIUM PRIORITY — Placeholder/Legacy Root Images ---
    tasks.append({"output_path": "assets/images/character_placeholder.png", "prompt": "Generate a warm illustration style image for a children's therapeutic storytelling app. A softly glowing circular silhouette of a child figure surrounded by sparkles and gentle light, suggesting potential and magic, with a welcoming aura. The image should feel warm, hopefull and inviting. Art style: soft 3D cartoon with pastel glow. No text overlays. Aspect ratio: 1:1. Professional quality, child-safe, therapeutically appropriate."})
    tasks.append({"output_path": "assets/images/hero_placeholder.jpg", "prompt": "Generate a warm illustration style image for a children's therapeutic storytelling app. A gentle glowing outline of a child hero figure inside a soft golden circle, surrounded by tiny stars and sparkles on a warm cream background. The image should feel inviting, magical and gender-neutral. Art style: soft 3D cartoon, warm golden tones. No text overlays. Aspect ratio: 1:1. Professional quality, child-safe, therapeutically appropriate."})
    
    legacy_icons = {
        "cat.png": "An adorable, friendly cat character with large expressive eyes, soft tabby fur, and a warm smile, shown full-body icon-style against a transparent background. Art style: bold 3D cartoon, high contrast, warm colours.",
        "dog.png": "A cheerful dog character with floppy ears, a wagging tail and a huge grin, shown full-body icon-style against a transparent background. Art style: bold 3D cartoon, warm golden browns.",
        "owl.png": "A friendly owl character with large expressive eyes, soft brown and cream feathers, wearing tiny spectacles, shown full-body icon-style against a transparent background. Art style: bold 3D cartoon, warm earthy tones.",
        "dragon.png": "A cute baby dragon with bright scales and sparkly eyes, small friendly wings, shown full-body icon-style against a transparent background. Art style: bold 3D cartoon, vivid but warm colours.",
        "robot.png": "A friendly round robot companion with a cheerful LED face, small helpful arms, and a glowing heart on its chest panel, shown full-body icon-style against a transparent background. Art style: bold 3D cartoon, soft metallic with warm light accents.",
        "horse.png": "A beautiful friendly horse with a flowing mane, bright eyes and a warm expression, shown full-body icon-style against a transparent background. Art style: bold 3D cartoon, warm chestnut and cream tones.",
        "fairy.png": "A joyful fairy with translucent shimmering wings, a glowing wand and a delighted expression, shown full-body icon-style against a transparent background. Art style: bold 3D cartoon, bright magical tones."
    }
    for filename, desc in legacy_icons.items():
        tasks.append({"output_path": f"assets/images/{filename}", "prompt": f"Generate a bold cartoon illustration image for a children's therapeutic storytelling app. {desc} No text overlays. Aspect ratio: 1:1. Professional quality, child-safe, therapeutically appropriate."})

    # --- MEDIUM PRIORITY — Feelings/adult band ---
    adult_feelings = [
        ("happy.png", "A young person (age 16–17, ethnically ambiguous) laughing freely with head tilted back, warm sunlight, genuine joy. Portrait style, circular crop, transparent outer background. Art style: clean realistic digital art, warm natural light."),
        ("sad.png", "A young person (age 16–17, ethnically ambiguous) with a gently sad expression, looking slightly downward, soft rain visible through a window behind them. Portrait style, circular crop. Art style: clean realistic digital art, cool melancholy blues."),
        ("angry.png", "A young person (age 16–17, ethnically ambiguous) with an angry expression, furrowed brow, looking directly at camera, warm orange lighting. Portrait style, circular crop. Art style: clean realistic digital art."),
        ("calm.png", "A young person (age 16–17, ethnically ambiguous) with a calm expression, eyes closed, peaceful smile, soft golden hour light. Portrait style, circular crop. Art style: clean realistic digital art."),
        ("confused.png", "A young person (age 16–17, ethnically ambiguous) with a confused expression, one eyebrow raised, tilting head. Portrait style, circular crop. Art style: clean realistic digital art."),
        ("excited.png", "A young person (age 16–17, ethnically ambiguous) with an excited expression, wide eyes, big smile, bright vibrant lighting. Portrait style, circular crop. Art style: clean realistic digital art."),
        ("scared.png", "A young person (age 16–17, ethnically ambiguous) with a scared expression, eyes wide, slightly pulled back. Portrait style, circular crop. Art style: clean realistic digital art, cool shadows."),
        ("surprised.png", "A young person (age 16–17, ethnically ambiguous) with a surprised expression, mouth slightly open, eyebrows raised. Portrait style, circular crop. Art style: clean realistic digital art.")
    ]
    for filename, desc in adult_feelings:
        tasks.append({"output_path": f"assets/images/feelings/adult/{filename}", "prompt": f"Generate a clean realistic digital art image for a children's therapeutic storytelling app. {desc} No text overlays. Aspect ratio: 1:1. Professional quality, child-safe, therapeutically appropriate."})

    # --- LOWER PRIORITY — Review Items ---
    tasks.append({"output_path": "assets/images/backgrounds/adolescent/splash_bg.jpg", "prompt": "Generate a digital art background image for a children's therapeutic storytelling app. A teenage figure (clothed in a hoodie) standing at the edge of a cliff looking up at a vast starfield and galaxy, expression one of wonder and possibility. The image should feel profound, hopeful and authentic for teens aged 12–14. Art style: digital art, cool blues and purples. No text overlays. Aspect ratio: 16:9. Professional quality, child-safe, therapeutically appropriate."})
    tasks.append({"output_path": "assets/images/backgrounds/adult/splash_bg.jpg", "prompt": "Generate a clean realistic digital art background image for a children's therapeutic storytelling app. A young person (17, gender-neutral) standing at a rooftop at dawn overlooking a glowing city, holding a notebook, expression thoughtful and hopeful. Art style: clean realistic digital art, warm dawn light. No text overlays. Aspect ratio: 1:1. Professional quality, child-safe, therapeutically appropriate."})
    tasks.append({"output_path": "assets/images/feelings/sprout/excited.png", "prompt": "Generate a bold cartoon illustration image for a children's therapeutic storytelling app. A joyfully bouncing round creature with star-shaped eyes, arms wide, surrounded by fireworks and sparkles, expressing pure excitement. Transparent background. Art style: bold 3D cartoon, vibrant pinks and reds. No text overlays, no watermarks. Aspect ratio: 1:1. Professional quality, child-safe, therapeutically appropriate."})
    tasks.append({"output_path": "assets/images/feelings/sprout/calm.png", "prompt": "Generate a bold cartoon illustration image for a children's therapeutic storytelling app. A softly glowing round creature with closed happy eyes, a gentle smile and a peaceful lotus pose, surrounded by soft sparkles and butterflies. The image should feel serenely calm and clearly contented. Art style: bold 3D cartoon, soft mint greens and warm whites. No text overlays. Aspect ratio: 1:1. Professional quality, child-safe, therapeutically appropriate."})

    # Save to JSON
    with open("image_tasks.json", "w") as f:
        json.dump(tasks, f, indent=2)
    
    print(f"Total tasks: {len(tasks)}")

if __name__ == "__main__":
    main()
