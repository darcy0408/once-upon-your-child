import argparse
import json
import os
import sys
from dataclasses import dataclass, field
from datetime import datetime, timezone
from typing import Any, Dict, List, Tuple

REPO_ROOT = os.path.dirname(os.path.dirname(os.path.dirname(__file__)))
if REPO_ROOT not in sys.path:
    sys.path.append(REPO_ROOT)

from backend.services.story_service import (
    AdvancedStoryEngine,
    AGE_CONSTRAINTS,
    _build_learning_to_read_prompt,
    _build_rhyme_time_prompt,
    _get_age_band,
)
from backend.tasks.story_tasks import (
    _find_missing_custom_elements,
    _parse_custom_elements,
    generate_story_task,
)


@dataclass
class Scenario:
    name: str
    age: int
    gender: str
    story_length: str = "standard"
    rhyme_time_mode: bool = False
    learning_to_read_mode: bool = False
    include_illustrations: bool = False
    custom_elements: str = ""
    companion_pets: List[Dict[str, Any]] = field(default_factory=list)
    companion_characters: List[Dict[str, Any]] = field(default_factory=list)
    additional_characters: List[str] = field(default_factory=list)


def _build_prompt_for_scenario(s: Scenario) -> str:
    if s.learning_to_read_mode:
        return _build_learning_to_read_prompt(
            character_name=_hero_name(s.gender),
            theme="Friendship",
            age=s.age,
            character_details=_character_details(s),
            companion=None,
            companion_pets=s.companion_pets,
            companion_characters=s.companion_characters,
            extra_characters=s.additional_characters,
            story_length=s.story_length,
            custom_elements=s.custom_elements,
        )
    if s.rhyme_time_mode:
        return _build_rhyme_time_prompt(
            character_name=_hero_name(s.gender),
            theme="Adventure",
            age=s.age,
            character_details=_character_details(s),
            companion_pets=s.companion_pets,
            companion_characters=s.companion_characters,
            extra_characters=s.additional_characters,
            story_length=s.story_length,
            custom_elements=s.custom_elements,
        )

    engine = AdvancedStoryEngine()
    return engine.generate_enhanced_prompt(
        character=_hero_name(s.gender),
        theme="Magic",
        companion=None,
        companion_pets=s.companion_pets,
        companion_characters=s.companion_characters,
        spark_tool="Moon Compass",
        mood_physics={
            "mood": "Wonder",
            "worldRule": "Songs open doors",
            "sensoryChange": "Starlight hums",
        },
        conflict_hook="A lost map needs solving.",
        sensory_palette="Warm light, soft wind, cinnamon air.",
        custom_elements=s.custom_elements,
        additional_characters=s.additional_characters,
        therapeutic_prompt="Support friendly connection.",
        feelings_prompt="The child feels curious and hopeful.",
        character_details=_character_details(s),
        story_length=s.story_length,
        story_duration=None,
        age=s.age,
    )


def _character_details(s: Scenario) -> Dict[str, Any]:
    return {
        "name": _hero_name(s.gender),
        "age": s.age,
        "gender": s.gender,
        "pets": s.companion_pets,
        "strengths": ["Kind", "Brave"],
        "specialAbility": "Kindness Beam",
    }


def _hero_name(gender: str) -> str:
    return "Ava" if gender.lower() == "girl" else "Leo"


def _collect_required_phrases(s: Scenario) -> List[str]:
    required = []
    required.extend(_parse_custom_elements(s.custom_elements))
    required.append(_hero_name(s.gender))

    for pet in s.companion_pets:
        name = pet.get("name")
        if name:
            required.append(name)

    for companion in s.companion_characters:
        if isinstance(companion, dict):
            name = companion.get("name")
            if name:
                required.append(name)
        elif companion:
            required.append(str(companion))

    for extra in s.additional_characters:
        if extra:
            required.append(str(extra))

    return required


def _validate_prompt(s: Scenario, prompt: str) -> List[str]:
    issues = []
    required = _parse_custom_elements(s.custom_elements)
    for phrase in required:
        if phrase not in prompt:
            issues.append(f"Prompt missing custom element phrase: {phrase}")

    if s.custom_elements and "use the exact words" not in prompt.lower():
        issues.append("Prompt missing exact-words instruction for custom elements.")

    if s.custom_elements and "concrete scene or outcome" not in prompt:
        issues.append("Prompt missing action-scene instruction for custom elements.")

    for name in _collect_required_phrases(s):
        if name and name not in prompt:
            issues.append(f"Prompt missing required name: {name}")

    return issues


def _validate_story_text(s: Scenario, story_text: str) -> Tuple[List[str], List[str]]:
    issues = []
    warnings = []
    missing = _find_missing_custom_elements(
        _parse_custom_elements(s.custom_elements),
        story_text,
    )
    if missing:
        issues.append(f"Missing custom elements in story: {', '.join(missing)}")

    for name in _collect_required_phrases(s):
        if name.lower() not in story_text.lower():
            issues.append(f"Story missing required name: {name}")

    # Length checks (soft warnings)
    if s.learning_to_read_mode:
        return issues, warnings

    band = _get_age_band(s.age)
    length_key = "medium" if s.story_length == "standard" else s.story_length
    word_count = len(story_text.split())
    if s.rhyme_time_mode:
        low, high = AGE_CONSTRAINTS[band]["rhyme"][length_key]
    else:
        low, high = AGE_CONSTRAINTS[band]["regular"][length_key]

    if word_count < low or word_count > high:
        warnings.append(
            f"Word count {word_count} outside target range {low}-{high} for age band {band}."
        )

    if "REQUEST SUMMARY" in story_text or "CRITICAL:" in story_text:
        issues.append("Story contains internal meta markers.")

    return issues, warnings


def _build_scenarios() -> List[Scenario]:
    return [
        Scenario(
            name="standard_age5_girl_pets_companions",
            age=5,
            gender="girl",
            custom_elements="ride a dragon, make friends",
            companion_pets=[{"name": "Milo", "species": "dog"}],
            companion_characters=[{"name": "Zara"}],
            additional_characters=["Kai"],
        ),
        Scenario(
            name="standard_age8_boy_simple",
            age=8,
            gender="boy",
            custom_elements="talking tree",
        ),
        Scenario(
            name="rhyme_age7_girl_pets",
            age=7,
            gender="girl",
            rhyme_time_mode=True,
            custom_elements="ride a dragon",
            companion_pets=[{"name": "Pip", "species": "cat"}],
        ),
        Scenario(
            name="ltr_age5_boy_friends",
            age=5,
            gender="boy",
            learning_to_read_mode=True,
            custom_elements="make friends",
            companion_characters=[{"name": "Noah"}],
        ),
        Scenario(
            name="standard_age12_boy_companions",
            age=12,
            gender="boy",
            custom_elements="build a treehouse",
            companion_characters=[{"name": "Lina"}],
            additional_characters=["Sam"],
        ),
    ]


def run_suite(live: bool, max_cases: int | None = None) -> Dict[str, Any]:
    scenarios = _build_scenarios()
    if max_cases is not None:
        scenarios = scenarios[:max_cases]

    results = []
    for scenario in scenarios:
        prompt = _build_prompt_for_scenario(scenario)
        prompt_issues = _validate_prompt(scenario, prompt)

        scenario_result = {
            "name": scenario.name,
            "prompt_issues": prompt_issues,
            "story_issues": [],
            "story_warnings": [],
        }

        if live:
            task_kwargs = {
                "character_id": None,
                "character": _hero_name(scenario.gender),
                "character_details": _character_details(scenario),
                "theme": "Magic",
                "user_id": "test_user",
                "include_illustrations": scenario.include_illustrations,
                "rhyme_time_mode": scenario.rhyme_time_mode,
                "learning_to_read_mode": scenario.learning_to_read_mode,
                "companion_pets": scenario.companion_pets,
                "companion_characters": scenario.companion_characters,
                "additional_characters": scenario.additional_characters,
                "custom_elements": scenario.custom_elements,
                "story_length": scenario.story_length,
                "age": scenario.age,
            }

            result = generate_story_task.apply(kwargs=task_kwargs).get()
            story = (result or {}).get("story", {})
            story_text = story.get("story_text") or ""

            issues, warnings = _validate_story_text(scenario, story_text)
            scenario_result["story_issues"] = issues
            scenario_result["story_warnings"] = warnings

        results.append(scenario_result)

    return {
        "generated_at": datetime.now(timezone.utc).isoformat(),
        "live": live,
        "scenarios": results,
    }


def _write_reports(
    report: Dict[str, Any], output_prefix: str | None
) -> Tuple[str, str]:
    timestamp = datetime.now(timezone.utc).strftime("%Y%m%d_%H%M%S")
    base = output_prefix or f"reports/story_personalization_report_{timestamp}"
    json_path = f"{base}.json"
    md_path = f"{base}.md"

    with open(json_path, "w", encoding="utf-8") as f:
        json.dump(report, f, indent=2)

    lines = [
        "# Story Personalization Suite Report",
        "",
        f"- Generated at: {report['generated_at']}",
        f"- Live model run: {report['live']}",
        "",
    ]
    for scenario in report["scenarios"]:
        lines.append(f"## {scenario['name']}")
        if scenario["prompt_issues"]:
            lines.append("Prompt issues:")
            for issue in scenario["prompt_issues"]:
                lines.append(f"- {issue}")
        else:
            lines.append("Prompt issues: None")

        if report["live"]:
            if scenario["story_issues"]:
                lines.append("Story issues:")
                for issue in scenario["story_issues"]:
                    lines.append(f"- {issue}")
            else:
                lines.append("Story issues: None")

            if scenario["story_warnings"]:
                lines.append("Story warnings:")
                for warning in scenario["story_warnings"]:
                    lines.append(f"- {warning}")
            else:
                lines.append("Story warnings: None")
        lines.append("")

    with open(md_path, "w", encoding="utf-8") as f:
        f.write("\n".join(lines))

    return json_path, md_path


def main() -> None:
    parser = argparse.ArgumentParser(description="Story personalization test suite.")
    parser.add_argument("--live", action="store_true", help="Call live model (Gemini).")
    parser.add_argument(
        "--max-cases", type=int, default=None, help="Limit scenario count."
    )
    parser.add_argument(
        "--output-prefix", type=str, default=None, help="Report path prefix."
    )
    args = parser.parse_args()

    if args.live and not os.getenv("GEMINI_API_KEY"):
        raise SystemExit(
            "GEMINI_API_KEY is not set. Run without --live or set the key."
        )

    report = run_suite(live=args.live, max_cases=args.max_cases)
    json_path, md_path = _write_reports(report, args.output_prefix)
    print(f"Wrote report: {json_path}")
    print(f"Wrote report: {md_path}")


if __name__ == "__main__":
    main()
