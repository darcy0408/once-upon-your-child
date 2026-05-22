"""Generation layer for the eval harness.

Faithfully replicates the prompt-assembly + Gemini call that
`backend/tasks/story_tasks.py` performs, WITHOUT importing Celery.

Scope note: this measures **prompt + model quality** — one assembled
prompt, one Gemini call. It deliberately does NOT replay the production
retry/validation/moderation loop (that lives inside the Celery task and
is a separate concern). The rubrics score the model's first-pass output,
which is what "current production prompts" means in the audit spec.

Builders are called exactly as story_tasks.py calls them (see lines
839-981 of that file). The Gemini call reuses the production model
resolution, safety settings, and text extraction so the only thing this
module adds is response/usage capture for token accounting.
"""

from __future__ import annotations

import time
from dataclasses import dataclass

from .providers import load_env

# Representative age per band key. The builders need an int age.
BAND_TO_AGE = {
    "3-4": 4,
    "5-7": 6,
    "8-10": 9,
    "11-13": 12,
    "13-15": 14,
    "15-18": 16,
    "adult": 30,
}

# Gemini pricing per 1M tokens (USD). Flash-Lite is the free-tier model.
# Update if Google changes rates.
GEMINI_PRICING = {
    "gemini-2.5-flash-lite": {"input": 0.10, "output": 0.40},
    "gemini-2.5-flash": {"input": 0.30, "output": 2.50},
}


@dataclass
class GenerationOutput:
    text: str
    model: str
    prompt: str
    input_tokens: int | None
    output_tokens: int | None
    cost_usd: float
    refused: bool
    error: str | None = None


def _estimate_cost(model: str, in_tok: int | None, out_tok: int | None) -> float:
    rates = GEMINI_PRICING.get(model)
    if not rates or in_tok is None or out_tok is None:
        return 0.0
    return (in_tok / 1_000_000 * rates["input"]
            + out_tok / 1_000_000 * rates["output"])


def build_prompt(mode: str, age_band: str, test_input, story_length: str = "short") -> str:
    """Assemble the production prompt for one cell.

    `test_input` is a backend.eval.test_set.TestInput.
    Mirrors the builder selection in story_tasks.generate_story_task.
    """
    # Imported lazily so a missing backend dep can't break `--dry-run`.
    from backend.services.story_service import (
        AdvancedStoryEngine,
        _build_bedtime_prompt,
        _build_learning_to_read_prompt,
        _build_rhyme_time_prompt,
    )
    from backend.services.prompt_service import PromptService

    age = BAND_TO_AGE[age_band]
    name = test_input.character_name
    theme = test_input.theme
    custom = test_input.custom_elements or ""
    char_details: dict = {}

    if mode == "superhero":
        from backend.data.superhero_matrix import pick_pairing
        band = "explorer" if 6 <= age <= 8 else "sprout"
        villain_id, problem_id = pick_pairing("super_smile", band=band)
        return PromptService.build_story_prompt(
            character=name, theme="superhero", age=age,
            hero_power="super_smile",
            superhero_villain_id=villain_id,
            superhero_problem_id=problem_id,
        )
    if mode == "bedtime":
        return _build_bedtime_prompt(
            character_name=name, age=age, theme=theme,
            mood="calming", story_length=story_length,
        )
    if mode in ("ltr_limerick", "ltr_seussian"):
        # story_service picks the limerick vs Seussian branch internally;
        # both eval modes route through the same builder. See F-10.
        return _build_learning_to_read_prompt(
            character_name=name, theme=theme, age=age,
            character_details=char_details, story_length=story_length,
            custom_elements=custom,
        )
    if mode == "rhyme_time":
        return _build_rhyme_time_prompt(
            character_name=name, theme=theme, age=age,
            character_details=char_details, story_length=story_length,
            custom_elements=custom,
        )
    # standard
    engine = AdvancedStoryEngine()
    return engine.generate_enhanced_prompt(
        character=name, theme=theme, age=age,
        custom_elements=custom,
        therapeutic_prompt=test_input.therapeutic_prompt or "",
        feelings_prompt=test_input.feelings_prompt,
        character_details=char_details,
        story_length=story_length,
    )


def generate(mode: str, age_band: str, test_input, user_tier: str = "free",
             story_length: str = "short") -> GenerationOutput:
    """Build the prompt and run one Gemini generation. Returns text + metrics."""
    load_env()
    # Reuse production model resolution / safety settings / extraction.
    from google import genai
    from google.genai import types
    from backend.services.story_generation_service import (
        _resolve_text_model, _CHILD_SAFETY_SETTINGS, _extract_text, _SAFETY_FALLBACK,
    )
    import os

    prompt = build_prompt(mode, age_band, test_input, story_length)
    model = _resolve_text_model(user_tier)
    api_key = os.environ.get("GEMINI_API_KEY")
    if not api_key:
        return GenerationOutput("", model, prompt, None, None, 0.0,
                                refused=True, error="GEMINI_API_KEY not set")

    client = genai.Client(api_key=api_key)
    try:
        resp = client.models.generate_content(
            model=model,
            contents=prompt,
            config=types.GenerateContentConfig(safety_settings=_CHILD_SAFETY_SETTINGS),
        )
    except Exception as exc:  # noqa: BLE001
        return GenerationOutput("", model, prompt, None, None, 0.0,
                                refused=True, error=f"{type(exc).__name__}: {exc}")

    text = _extract_text(resp)
    refused = text is None
    usage = getattr(resp, "usage_metadata", None)
    in_tok = getattr(usage, "prompt_token_count", None)
    out_tok = getattr(usage, "candidates_token_count", None)
    return GenerationOutput(
        text=text or _SAFETY_FALLBACK,
        model=model,
        prompt=prompt,
        input_tokens=in_tok,
        output_tokens=out_tok,
        cost_usd=_estimate_cost(model, in_tok, out_tok),
        refused=refused,
    )
