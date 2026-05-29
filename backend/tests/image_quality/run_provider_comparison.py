#!/usr/bin/env python3
"""
Story Weaver — Image Generation Provider A/B Comparison

Generates the same set of story-page illustrations across multiple providers
so a human can review them side-by-side. Output goes to:

    backend/tests/image_quality/results/{provider}/{age}_p{page}.png
    backend/tests/image_quality/results/manifest.json
    backend/tests/image_quality/results/prompts.json

Providers tested:
  - gemini       Gemini 2.5 Flash Image (current production primary, $0.039/img)
  - sdxl         Replicate bytedance/sdxl-lightning-4step (~$0.003/img)
  - flux_schnell Replicate black-forest-labs/flux-schnell (~$0.003/img)

Test matrix (45 images by default):
  5 age bands x 3 pages x 3 providers = 45 images

Usage from repo root:
    python backend/tests/image_quality/run_provider_comparison.py

Optional overrides:
    --providers gemini,sdxl,flux_schnell   subset
    --ages sprout,explorer                 subset of age bands
    --pages 1                              fewer pages per band
    --dry-run                              build prompts and write prompts.json
                                           but do NOT call any API

Reads GEMINI_API_KEY and REPLICATE_API_TOKEN from backend/.env automatically.
"""

from __future__ import annotations

import argparse
import json
import os
import sys
import time
from datetime import datetime
from pathlib import Path

_HERE = Path(__file__).resolve().parent
_BACKEND_DIR = _HERE.parent.parent
_REPO_ROOT = _BACKEND_DIR.parent
_ENV_FILE = _BACKEND_DIR / ".env"
if _ENV_FILE.exists():
    from dotenv import load_dotenv

    load_dotenv(dotenv_path=_ENV_FILE, override=False)

sys.path.insert(0, str(_REPO_ROOT))

RESULTS_DIR = _HERE / "results"
RESULTS_DIR.mkdir(parents=True, exist_ok=True)


# ── Test matrix: one representative scene per age band, 3 pages each ────────
# Each entry covers a different beat (intro / midpoint / climax) of a short
# illustrated children's story. The character_appearance dict is text-only
# (no photo reference) — this matches the cheapest-provider capability set.
TEST_CASES = [
    {
        "band": "sprout",
        "age": 3,
        "character_name": "Lily",
        "character_appearance": {
            "hair": "short curly brown hair",
            "skin": "light tan skin",
            "outfit": "yellow raincoat with duck pockets",
            "gender": "girl",
        },
        "companions": [{"name": "Bubbles", "species": "dolphin"}],
        "therapeutic_focus": "courage and kindness",
        "pages": [
            "Lily stands on a sandy beach holding a blue bucket, smiling at the gentle ocean waves at sunrise.",
            "Lily wades knee-deep in clear turquoise water, giggling as Bubbles the dolphin pops up beside her with a friendly splash.",
            "Lily and Bubbles ride together on a wave under a pink-and-orange sunset sky, both looking joyful.",
        ],
    },
    {
        "band": "explorer",
        "age": 7,
        "character_name": "Max",
        "character_appearance": {
            "hair": "messy black hair",
            "skin": "warm medium-brown skin",
            "outfit": "green hooded explorer cloak with brass buttons",
            "gender": "boy",
        },
        "companions": [{"name": "Sparkle", "species": "unicorn"}],
        "therapeutic_focus": "wonder and friendship",
        "pages": [
            "Max steps onto a glowing moss path at the edge of a magical forest at dusk, eyes wide with curiosity.",
            "Max and Sparkle the unicorn discover a clearing of giant glowing mushrooms, with fireflies swirling around them.",
            "Max sits on Sparkle's back as they leap across a moonlit creek surrounded by floating star-shaped flowers.",
        ],
    },
    {
        "band": "adventurer",
        "age": 10,
        "character_name": "Zoe",
        "character_appearance": {
            "hair": "long wavy auburn hair tied back",
            "skin": "fair skin with freckles",
            "outfit": "weathered leather adventurer jacket and goggles",
            "gender": "girl",
        },
        "companions": [
            {"name": "Finn", "description": "a brave explorer friend with a torch"}
        ],
        "therapeutic_focus": "perseverance and teamwork",
        "pages": [
            "Zoe and Finn stand at the entrance of a vast crystal cave, raising a torch that reflects rainbow shards across the walls.",
            "Zoe carefully balances on a narrow rock bridge over a chasm of glowing blue crystals while Finn watches from behind.",
            "Zoe and Finn discover a hidden chamber with a giant glowing crystal heart at its center, faces lit with awe.",
        ],
    },
    {
        "band": "creator",
        "age": 13,
        "character_name": "Sam",
        "character_appearance": {
            "hair": "short undercut with teal-dyed tips",
            "skin": "olive skin",
            "outfit": "denim jacket covered in art-club pins and a sketchbook bag",
            "gender": "non-binary teen",
        },
        "companions": [],
        "therapeutic_focus": "creativity and identity",
        "pages": [
            "Sam walks into an empty modern art gallery after hours, sketchbook in hand, examining a strange empty frame on the wall.",
            "Sam holds up a sketch and notices it matches the missing painting, with a thoughtful, focused expression.",
            "Sam stands in front of a wall covered in colorful artwork they completed, looking proud and a little surprised.",
        ],
    },
    {
        "band": "adolescent",
        "age": 16,
        "character_name": "Jordan",
        "character_appearance": {
            "hair": "shoulder-length straight black hair",
            "skin": "deep brown skin",
            "outfit": "navy varsity jacket and headphones around the neck",
            "gender": "teen",
        },
        "companions": [],
        "therapeutic_focus": "self-discovery and resilience",
        "pages": [
            "Jordan sits alone on a school rooftop at golden hour, looking out over the city with a contemplative expression.",
            "Jordan stands on a starting line at a track, taking a deep breath, surrounded by other runners blurred in motion.",
            "Jordan crosses a finish line, arms raised, with a small group of friends cheering from the sideline.",
        ],
    },
]


# ── Per-provider cost estimates (used for run accounting only) ──────────────
PROVIDER_COSTS_USD = {
    "gemini": 0.039,  # Gemini 2.5 Flash Image, billed per image
    "sdxl": 0.003,  # bytedance/sdxl-lightning-4step (avg of 0.0017–0.003)
    "flux_schnell": 0.003,  # black-forest-labs/flux-schnell
}


# ─── Prompt builder (mirrors GeminiImageGenerator with text-only appearance) ─
def _age_descriptor(age: int) -> tuple[str, str]:
    if age <= 5:
        return (
            "soft rounded shapes, expressive faces, warm glowing colors, simple readable scenes, toy-like 3D storybook charm",
            "young children (ages 3-5)",
        )
    if age <= 11:
        return (
            "balanced details with fun elements, engaging and colorful",
            "children (ages 6-11)",
        )
    if age <= 17:
        return (
            "intricate artwork with rich details, sophisticated and relatable for teens",
            "teenagers (ages 12-17)",
        )
    return (
        "sophisticated, nuanced artwork with depth and symbolism",
        "adults (18+)",
    )


def _build_character_description(name: str, appearance: dict | None) -> str:
    desc = f"Main character: {name}"
    if not appearance:
        return desc
    bits = []
    if appearance.get("hair"):
        bits.append(f"hair: {appearance['hair']}")
    if appearance.get("skin"):
        bits.append(f"skin tone: {appearance['skin']}")
    if appearance.get("outfit"):
        bits.append(f"wearing: {appearance['outfit']}")
    if appearance.get("gender"):
        bits.append(f"gender: {appearance['gender']}")
    if bits:
        desc += f" ({', '.join(bits)})"
    return desc


def _build_companions_text(companions: list | None) -> str:
    if not companions:
        return ""
    parts = []
    for c in companions:
        if isinstance(c, dict):
            name = c.get("name", "companion")
            sp = c.get("species") or c.get("description") or ""
            parts.append(f"{name} ({sp})" if sp else name)
        else:
            parts.append(str(c))
    return f" Companions in scene: {', '.join(parts)}." if parts else ""


def build_prompt(
    scene: str,
    character_name: str,
    character_appearance: dict | None,
    companions: list | None,
    therapeutic_focus: str | None,
    age: int,
    style: str = "children's book illustration",
) -> str:
    detail, audience = _age_descriptor(age)
    char_desc = _build_character_description(character_name, character_appearance)
    companions_text = _build_companions_text(companions)
    therapy = f" Therapeutic tone: {therapeutic_focus}." if therapeutic_focus else ""
    return (
        f"Create a vibrant, engaging {style} that depicts this exact scene from the story. "
        f"SCENE: {scene} {char_desc}. Target audience: {audience}. "
        f"Detail level: {detail}.{therapy}{companions_text} "
        f"Visual requirements: full color, vibrant, positive uplifting tone, "
        f"dynamic composition, professional illustration quality, no text or words in the image, "
        f"age-appropriate for {audience}."
    )


# ─── Provider runners ───────────────────────────────────────────────────────
class ProviderError(Exception):
    pass


def run_gemini(prompt: str, character_name: str, age: int) -> bytes:
    """Returns PNG bytes for one image. Raises ProviderError on failure."""
    api_key = os.getenv("GEMINI_API_KEY")
    if not api_key:
        raise ProviderError("GEMINI_API_KEY not set in env")
    try:
        from google import genai
        from google.genai import types
    except ImportError as e:
        raise ProviderError(f"google-genai SDK not installed: {e}")
    client = genai.Client(api_key=api_key)
    try:
        response = client.models.generate_content(
            model="gemini-2.5-flash-image",
            contents=prompt,
            config=types.GenerateContentConfig(response_modalities=["IMAGE"]),
        )
    except Exception as e:
        raise ProviderError(f"Gemini API error: {e}")
    candidates = getattr(response, "candidates", None) or []
    for cand in candidates:
        content = getattr(cand, "content", None)
        parts = getattr(content, "parts", None) if content else None
        if not parts:
            continue
        for part in parts:
            inline = getattr(part, "inline_data", None)
            if inline and getattr(inline, "data", None):
                return inline.data
    raise ProviderError("Gemini returned no inline_data image part")


def _replicate_predict(
    model_version: str, input_payload: dict, timeout_s: int = 120
) -> str:
    import requests

    api_key = os.getenv("REPLICATE_API_TOKEN")
    if not api_key:
        raise ProviderError("REPLICATE_API_TOKEN not set in env")

    create = requests.post(
        "https://api.replicate.com/v1/predictions",
        headers={
            "Authorization": f"Bearer {api_key}",
            "Content-Type": "application/json",
        },
        json={"version": model_version, "input": input_payload},
        timeout=30,
    )
    if create.status_code not in (200, 201):
        raise ProviderError(
            f"Replicate create failed: {create.status_code} {create.text[:300]}"
        )
    pid = create.json().get("id")
    if not pid:
        raise ProviderError(f"Replicate response missing id: {create.text[:300]}")

    deadline = time.time() + timeout_s
    while time.time() < deadline:
        time.sleep(1.5)
        poll = requests.get(
            f"https://api.replicate.com/v1/predictions/{pid}",
            headers={"Authorization": f"Bearer {api_key}"},
            timeout=15,
        )
        if poll.status_code != 200:
            raise ProviderError(f"Replicate poll failed: {poll.status_code}")
        body = poll.json()
        status = body.get("status")
        if status == "succeeded":
            outputs = body.get("output") or []
            if isinstance(outputs, list) and outputs:
                return outputs[0]
            if isinstance(outputs, str):
                return outputs
            raise ProviderError(f"Replicate succeeded but no output: {body}")
        if status in ("failed", "canceled"):
            raise ProviderError(f"Replicate prediction {status}: {body.get('error')}")
    raise ProviderError("Replicate prediction timed out")


def run_sdxl_lightning(prompt: str, character_name: str, age: int) -> bytes:
    import requests

    version = "5599ed30703defd1d160a25a63321b4dec97101d98b4674bcc56e41f62f35637"  # bytedance/sdxl-lightning-4step
    url = _replicate_predict(
        version,
        {
            "prompt": prompt,
            "width": 1024,
            "height": 1024,
            "num_outputs": 1,
            "scheduler": "K_EULER",
            "num_inference_steps": 4,
        },
    )
    r = requests.get(url, timeout=30)
    r.raise_for_status()
    return r.content


def run_flux_schnell(prompt: str, character_name: str, age: int) -> bytes:
    import requests

    api_key = os.getenv("REPLICATE_API_TOKEN")
    if not api_key:
        raise ProviderError("REPLICATE_API_TOKEN not set in env")
    create = requests.post(
        "https://api.replicate.com/v1/models/black-forest-labs/flux-schnell/predictions",
        headers={
            "Authorization": f"Bearer {api_key}",
            "Content-Type": "application/json",
            "Prefer": "wait",
        },
        json={
            "input": {
                "prompt": prompt,
                "num_outputs": 1,
                "aspect_ratio": "1:1",
                "output_format": "png",
                "output_quality": 90,
            }
        },
        timeout=70,
    )
    if create.status_code not in (200, 201):
        raise ProviderError(
            f"Flux create failed: {create.status_code} {create.text[:300]}"
        )
    body = create.json()
    if body.get("status") not in ("succeeded", "starting", "processing", None):
        raise ProviderError(f"Flux unexpected status {body.get('status')}: {body}")

    if body.get("status") != "succeeded":
        pid = body.get("id")
        deadline = time.time() + 90
        while time.time() < deadline:
            time.sleep(1.5)
            poll = requests.get(
                f"https://api.replicate.com/v1/predictions/{pid}",
                headers={"Authorization": f"Bearer {api_key}"},
                timeout=15,
            )
            if poll.status_code != 200:
                raise ProviderError(f"Flux poll failed: {poll.status_code}")
            body = poll.json()
            if body.get("status") == "succeeded":
                break
            if body.get("status") in ("failed", "canceled"):
                raise ProviderError(f"Flux {body.get('status')}: {body.get('error')}")
        else:
            raise ProviderError("Flux prediction timed out")

    output = body.get("output") or []
    url = (
        output[0]
        if isinstance(output, list) and output
        else (output if isinstance(output, str) else None)
    )
    if not url:
        raise ProviderError(f"Flux returned no output: {body}")
    r = requests.get(url, timeout=30)
    r.raise_for_status()
    return r.content


PROVIDER_RUNNERS = {
    "gemini": run_gemini,
    "sdxl": run_sdxl_lightning,
    "flux_schnell": run_flux_schnell,
}


# ─── Main orchestrator ──────────────────────────────────────────────────────
def main():
    parser = argparse.ArgumentParser()
    parser.add_argument(
        "--providers",
        default="gemini,sdxl,flux_schnell",
        help="Comma-separated provider keys",
    )
    parser.add_argument("--ages", default="all", help="Comma-separated bands or 'all'")
    parser.add_argument(
        "--pages", type=int, default=3, help="How many pages per band (1-3)"
    )
    parser.add_argument(
        "--dry-run",
        action="store_true",
        help="Build prompts and write prompts.json; skip API calls",
    )
    args = parser.parse_args()

    providers = [p.strip() for p in args.providers.split(",") if p.strip()]
    for p in providers:
        if p not in PROVIDER_RUNNERS:
            print(f"Unknown provider: {p}", file=sys.stderr)
            sys.exit(2)

    bands_filter = (
        None if args.ages == "all" else {a.strip() for a in args.ages.split(",")}
    )
    cases = [c for c in TEST_CASES if not bands_filter or c["band"] in bands_filter]
    pages_per = max(1, min(args.pages, 3))

    # Build prompts
    prompts_record = []
    for case in cases:
        for i, scene in enumerate(case["pages"][:pages_per], start=1):
            prompt = build_prompt(
                scene=scene,
                character_name=case["character_name"],
                character_appearance=case["character_appearance"],
                companions=case["companions"],
                therapeutic_focus=case["therapeutic_focus"],
                age=case["age"],
            )
            prompts_record.append(
                {
                    "band": case["band"],
                    "age": case["age"],
                    "page": i,
                    "scene": scene,
                    "character_name": case["character_name"],
                    "prompt": prompt,
                }
            )

    (RESULTS_DIR / "prompts.json").write_text(json.dumps(prompts_record, indent=2))
    print(f"Wrote {len(prompts_record)} prompts to {RESULTS_DIR / 'prompts.json'}")

    total_imgs = len(prompts_record) * len(providers)
    est_cost = sum(PROVIDER_COSTS_USD[p] for p in providers) * len(prompts_record)
    print(
        f"Plan: {total_imgs} images across {len(providers)} provider(s), "
        f"estimated cost ${est_cost:.3f}"
    )

    if args.dry_run:
        print("Dry run — not calling APIs.")
        return

    manifest = {
        "started_at": datetime.now().isoformat(),
        "providers": providers,
        "bands": [c["band"] for c in cases],
        "pages_per_band": pages_per,
        "results": [],
    }

    for provider in providers:
        prov_dir = RESULTS_DIR / provider
        prov_dir.mkdir(parents=True, exist_ok=True)
        runner = PROVIDER_RUNNERS[provider]
        # Replicate throttles unverified accounts to 6 req/min — pace ourselves.
        per_call_pause = 11.0 if provider in ("sdxl", "flux_schnell") else 0.0

        for rec in prompts_record:
            band = rec["band"]
            page = rec["page"]
            out_path = prov_dir / f"{band}_p{page}.png"
            t0 = time.time()
            entry = {
                "provider": provider,
                "band": band,
                "age": rec["age"],
                "page": page,
                "path": str(out_path.relative_to(RESULTS_DIR)),
            }
            try:
                img_bytes = runner(rec["prompt"], rec["character_name"], rec["age"])
                out_path.write_bytes(img_bytes)
                entry["status"] = "ok"
                entry["bytes"] = len(img_bytes)
                entry["latency_s"] = round(time.time() - t0, 2)
                entry["est_cost_usd"] = PROVIDER_COSTS_USD[provider]
                print(
                    f"  [OK]   {provider} {band} p{page}  {entry['latency_s']}s  "
                    f"{len(img_bytes)//1024}KB"
                )
            except Exception as e:
                entry["status"] = "error"
                entry["error"] = str(e)[:300]
                entry["latency_s"] = round(time.time() - t0, 2)
                print(f"  [FAIL] {provider} {band} p{page}  {str(e)[:200]}")
            manifest["results"].append(entry)
            if per_call_pause:
                time.sleep(per_call_pause)

    manifest["finished_at"] = datetime.now().isoformat()
    ok_count = sum(1 for r in manifest["results"] if r["status"] == "ok")
    actual_cost = sum(
        r.get("est_cost_usd", 0) for r in manifest["results"] if r["status"] == "ok"
    )
    manifest["summary"] = {
        "total_attempts": len(manifest["results"]),
        "successful": ok_count,
        "actual_cost_usd_est": round(actual_cost, 4),
    }
    (RESULTS_DIR / "manifest.json").write_text(json.dumps(manifest, indent=2))
    print(
        f"\nDone: {ok_count}/{len(manifest['results'])} OK  "
        f"~${actual_cost:.3f} estimated cost"
    )


if __name__ == "__main__":
    main()
