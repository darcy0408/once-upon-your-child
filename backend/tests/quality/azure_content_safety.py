"""Thin Azure AI Content Safety *text* client — defensive moderation second-opinion.

Companion to the regex "rule-brush" in `antihero_safety_batch.py` /
`antihero_redteam_ext.py`. Where those give a keyword CANDIDATE, Content Safety
returns a MODEL severity (0-7) per harm category, so it can catch framings a
regex can't (self-harm rendered as "aesthetic melancholy", substance set-dressing).

Reads AZURE_CONTENT_SAFETY_ENDPOINT / AZURE_CONTENT_SAFETY_KEY from backend/.env
(resource `story-weaver-contentsafety`, F0 free tier: 5k records/mo, 1 req/sec,
10k chars/request -> we chunk + throttle). This is a READ-ONLY analysis call; it
sends text to the owner's own Azure resource (same trust boundary as narration).

    from azure_content_safety import analyze_text
    analyze_text("some story prose") -> {"Hate":0,"SelfHarm":6,"Sexual":0,"Violence":0}
"""

from __future__ import annotations

import os
import time

import requests

CATEGORIES = ["Hate", "SelfHarm", "Sexual", "Violence"]
_API_VERSION = "2024-09-01"
_MAX_CHARS = 9000  # under the 10k API limit, with headroom


def _endpoint_key() -> tuple[str, str]:
    ep = os.environ.get("AZURE_CONTENT_SAFETY_ENDPOINT")
    key = os.environ.get("AZURE_CONTENT_SAFETY_KEY")
    if not ep or not key:
        raise RuntimeError(
            "AZURE_CONTENT_SAFETY_ENDPOINT / AZURE_CONTENT_SAFETY_KEY not set "
            "(expected in backend/.env)"
        )
    return ep.rstrip("/"), key


def _chunks(text: str) -> list[str]:
    """Split long text on line boundaries so each request stays under the limit."""
    text = text or ""
    if len(text) <= _MAX_CHARS:
        return [text] if text.strip() else []
    out: list[str] = []
    cur = ""
    for para in text.split("\n"):
        if len(cur) + len(para) + 1 > _MAX_CHARS:
            if cur.strip():
                out.append(cur)
            cur = para
        else:
            cur = f"{cur}\n{para}" if cur else para
    if cur.strip():
        out.append(cur)
    return out


def shield_prompt(
    user_prompt: str = "",
    documents: list[str] | None = None,
    *,
    throttle: float = 1.1,
    max_retries: int = 6,
) -> dict:
    """Prompt Shields: detect injection/jailbreak in INPUT (not output harm).

    `user_prompt` = text the end-user typed (e.g. custom_elements / hero_secret).
    `documents`   = third-party text embedded into the prompt (indirect injection).
    Returns {"user_attack": bool, "doc_attacks": [bool, ...]}.
    """
    ep, key = _endpoint_key()
    url = f"{ep}/contentsafety/text:shieldPrompt?api-version={_API_VERSION}"
    headers = {"Ocp-Apim-Subscription-Key": key, "Content-Type": "application/json"}
    body = {"userPrompt": user_prompt or "", "documents": documents or []}
    for attempt in range(max_retries):
        r = requests.post(url, headers=headers, json=body, timeout=30)
        if r.status_code == 429:
            time.sleep(2**attempt)
            continue
        r.raise_for_status()
        data = r.json()
        up = data.get("userPromptAnalysis") or {}
        docs = data.get("documentsAnalysis") or []
        time.sleep(throttle)
        return {
            "user_attack": bool(up.get("attackDetected")),
            "doc_attacks": [bool(d.get("attackDetected")) for d in docs],
        }
    raise RuntimeError(f"Prompt Shields threw 429 after {max_retries} retries")


def analyze_text(text: str, *, throttle: float = 1.1, max_retries: int = 6) -> dict:
    """Return max severity (0-7) per harm category across all chunks of `text`.

    Requests EightSeverityLevels (fine granularity for subtle content); falls back
    to FourSeverityLevels if the resource/API rejects it. Retries 429s (F0 is
    1 req/sec) with exponential backoff.
    """
    ep, key = _endpoint_key()
    url = f"{ep}/contentsafety/text:analyze?api-version={_API_VERSION}"
    headers = {"Ocp-Apim-Subscription-Key": key, "Content-Type": "application/json"}
    agg = {c: 0 for c in CATEGORIES}
    output_type = "EightSeverityLevels"

    for chunk in _chunks(text):
        body = {"text": chunk, "categories": CATEGORIES, "outputType": output_type}
        for attempt in range(max_retries):
            r = requests.post(url, headers=headers, json=body, timeout=30)
            if r.status_code == 429:
                time.sleep(2**attempt)
                continue
            if r.status_code == 400 and output_type == "EightSeverityLevels":
                # some resources only support the coarse 4-level output; downgrade
                output_type = "FourSeverityLevels"
                body["outputType"] = output_type
                continue
            r.raise_for_status()
            for ca in r.json().get("categoriesAnalysis", []):
                cat = ca.get("category")
                if cat in agg:
                    agg[cat] = max(agg[cat], int(ca.get("severity", 0)))
            break
        else:
            raise RuntimeError(f"Content Safety threw 429 after {max_retries} retries")
        time.sleep(throttle)  # respect F0's 1 req/sec ceiling
    return agg
