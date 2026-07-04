"""
Provider-agnostic image-prompt helper functions.

These are pure functions (no I/O, no vendor SDK calls) used to build
prompt text / metadata for character illustration requests. They started
life inside `backend/gemini_image_generator.py` but are consumed by
multiple image-generation providers (OpenAI, Replicate, Gemini, ...), so
they live here as shared utilities rather than in one vendor's module.
"""

# MT-107: Per-power visual signatures for Explorer-band Superhero Mode.
# Keys are power_ids from backend/data/superhero_matrix.py EXPLORER_POWERS.
# Only powers whose narrative identity demands a distinct silhouette appear
# here; other powers (super_speed, flying, etc.) rely on action posture.
_POWER_VISUAL_OVERRIDES: dict[str, str] = {
    "feeling_sense": (
        "POWER VISUAL SIGNATURE — Feeling Sense: render a soft pastel halo "
        "(empathy glow) around the hero's head and shoulders in EVERY frame. "
        "The glow is a gentle pink-and-gold gradient, slightly translucent, "
        "about 1.5x the diameter of the head, with feathered diffuse edges — "
        "never sharp, never lens-flare. It signals the hero is sensing "
        "another character's emotions. Keep it subtle, dreamlike, warm."
    ),
    "invisibility": (
        "POWER VISUAL SIGNATURE — Soft Step (invisibility): render the hero "
        "with a translucent, wisp-edged silhouette. The body is ~70% opaque "
        "in the core and fades to ~25% opacity at the edges with soft, smoky "
        "wisp-like dissipation. Background is faintly visible THROUGH the "
        "outer edges of the hero's outline. Eyes and face remain readable. "
        "Effect should feel like a ghostly shimmer, not a glitch."
    ),
}

# Human-readable descriptors for the costume choices captured by the Flutter
# superhero flow (lib/screens/wizard_steps/superhero_costume_screen.dart +
# superhero_power_screen.dart). Used to build the avatar→superhero transform
# prompt. Keys must stay aligned with the option ids in those screens.
_SUPERHERO_COLOR_NAMES: dict[str, str] = {
    "red": "bold red",
    "blue": "bright blue",
    "green": "vivid green",
    "yellow": "sunny yellow",
    "purple": "royal purple",
    "pink": "vibrant pink",
}

_SUPERHERO_CAPE_DESC: dict[str, str] = {
    "none": "no cape",
    "matching": "a flowing cape that matches the suit color",
    "rainbow": "a flowing rainbow-striped cape",
}

_SUPERHERO_EMBLEM_DESC: dict[str, str] = {
    "star": "a five-pointed star",
    "lightning": "a lightning bolt",
    "heart": "a heart",
    "moon": "a crescent moon",
    "paw": "a paw print",
    "rainbow": "a rainbow arc",
    "bolt": "a trident bolt",
    "comet": "a streaking comet",
}

# Action posture per power for powers without a full visual signature override.
_SUPERHERO_POWER_POSE: dict[str, str] = {
    "super_speed": "in a dynamic running pose with motion streaks",
    "flying": "soaring upward in a heroic flying pose, cape billowing",
    "super_strength": "in a confident strong stance, fists ready",
    "super_hearing": "alert and listening, head tilted attentively",
    "super_smile": "beaming a big warm confident smile",
    "super_hugs": "arms open in a warm welcoming pose",
    "super_whisper": "calm and reassuring, one finger to lips gently",
    "super_sharing": "offering an open friendly hand",
    "strategist": "thoughtful and poised, surveying the scene cleverly",
    "gadgeteer": "holding a clever hand-built gadget, ready to use it",
}


def build_superhero_transform_prompt(
    *,
    costume_color: str | None = None,
    cape_style: str | None = None,
    emblem: str | None = None,
    power: str | None = None,
) -> str:
    """Build the avatar→superhero transform prompt from costume/power choices.

    Pure function (no I/O) so it is cheap to unit test. Preserves the child's
    facial likeness, enforces a non-photorealistic Pixar style, and adds only
    the chosen costume + a power-appropriate action pose. Unknown/None ids are
    skipped gracefully so partial selections still produce a valid prompt.
    """
    color_desc = _SUPERHERO_COLOR_NAMES.get(costume_color or "", "a bright")
    cape_desc = _SUPERHERO_CAPE_DESC.get(cape_style or "", "a flowing cape")
    emblem_desc = _SUPERHERO_EMBLEM_DESC.get(emblem or "")
    pose_desc = _SUPERHERO_POWER_POSE.get(power or "", "in a confident hero pose")

    chest = f" with {emblem_desc} emblem on the chest" if emblem_desc else ""

    parts = [
        "This is a Pixar-style storybook character illustration of a child. ",
        "Keep the child's FACE, hair, skin tone, and likeness EXACTLY the same — ",
        "do not change their identity. ",
        "Re-dress them as a friendly, kid-appropriate superhero: ",
        f"a {color_desc} superhero suit{chest}, and {cape_desc}. ",
        f"Pose the hero {pose_desc}. ",
        "Comic-book lighting, bright heroic colors, non-photorealistic, ",
        "clearly a cartoon character, square format. ",
        "Wholesome and non-violent — no weapons, no scary or aggressive content. ",
    ]

    # Layer on a full visual signature for powers that define one (empathy
    # halo, invisibility shimmer, etc.).
    override = _POWER_VISUAL_OVERRIDES.get(power or "")
    if override:
        parts.append(override)

    return "".join(parts)


def _power_visual_block(power_id: str | None) -> str:
    if not power_id:
        return ""
    override = _POWER_VISUAL_OVERRIDES.get(power_id.strip().lower())
    return f"\n{override}\n" if override else ""


def _humanize(value) -> str:
    """Turn a Flutter enum `.name` (camelCase) into readable words.

    The Flutter app serialises CharacterAppearance enums via `.name`, so the
    illustration payload carries values like `lightBrown`, `strawberryBlonde`,
    `mediumTan`, `veryLong`. Insert spaces before internal capitals and
    lowercase so the image model reads natural language ("light brown").
    """
    if value is None:
        return ""
    text = str(value).strip()
    if not text:
        return ""
    out = []
    for i, ch in enumerate(text):
        if ch.isupper() and i > 0 and not text[i - 1].isupper():
            out.append(" ")
        out.append(ch)
    return "".join(out).replace("_", " ").lower().strip()


def build_appearance_details(character_appearance: dict | None) -> list:
    """Extract human-readable appearance phrases from a character_appearance dict.

    MT-129: the Flutter app (`story_result_screen._characterAppearanceForBackend`)
    sends snake_case keys derived from the saved Character / GeneratedAvatar —
    `hair_color`, `hair_length`, `hair_style`, `eye_color`, `skin_tone`,
    `clothing_style`, `clothing_colors`. Older / simpler callers may instead
    send the flat `hair` / `skin` / `outfit` keys. Previously the generators
    only read `hair`/`skin`/`outfit`/`gender`, so the rich avatar-derived
    fields (eye colour, skin tone, hairstyle) were silently dropped and the
    model rendered a generic child. Read BOTH key conventions here so the
    illustrated character actually matches the created character.

    Does NOT include the avatar reference image — callers handle that
    separately via `custom_avatar_base64`.
    """
    if not character_appearance:
        return []

    ca = character_appearance
    details: list[str] = []

    # --- Hair: combine length + style + colour into one phrase ---------------
    hair_color = _humanize(ca.get("hair_color")) or _humanize(ca.get("hair"))
    hair_length = _humanize(ca.get("hair_length"))
    hair_style = _humanize(ca.get("hair_style") or ca.get("hairstyle"))
    hair_parts = [p for p in (hair_length, hair_style, hair_color) if p]
    if hair_parts:
        details.append(f"hair: {' '.join(hair_parts)}")

    # --- Eyes ----------------------------------------------------------------
    eye_color = _humanize(ca.get("eye_color") or ca.get("eyes"))
    if eye_color:
        details.append(f"eye color: {eye_color}")

    # --- Skin ----------------------------------------------------------------
    skin = _humanize(ca.get("skin_tone")) or _humanize(ca.get("skin"))
    if skin:
        details.append(f"skin tone: {skin}")

    # --- Clothing ------------------------------------------------------------
    clothing_style = _humanize(ca.get("clothing_style"))
    clothing_colors = _humanize(ca.get("clothing_colors"))
    outfit = _humanize(ca.get("outfit"))
    if outfit:
        details.append(f"wearing: {outfit}")
    elif clothing_style or clothing_colors:
        clothing_phrase = " ".join(p for p in (clothing_colors, clothing_style) if p)
        details.append(f"wearing: {clothing_phrase} clothing")

    # --- Gender --------------------------------------------------------------
    gender = _humanize(ca.get("gender"))
    if gender:
        details.append(f"gender: {gender}")

    # --- Distinguishing feature (MT-129) -------------------------------------
    # A single notable visual cue from photo analysis (e.g. "round glasses",
    # "freckles", "curly bangs"). High recognisability signal — passed verbatim.
    distinguishing = _humanize(ca.get("distinguishing"))
    if distinguishing:
        details.append(f"notable feature: {distinguishing}")

    return details


def _detect_mime_type(data: bytes) -> str:
    """Detect image MIME type from magic bytes."""
    if data[:8] == b"\x89PNG\r\n\x1a\n":
        return "image/png"
    if data[:3] == b"\xff\xd8\xff":
        return "image/jpeg"
    if data[:6] in (b"GIF87a", b"GIF89a"):
        return "image/gif"
    if data[:4] == b"RIFF" and data[8:12] == b"WEBP":
        return "image/webp"
    return "image/jpeg"  # fallback
