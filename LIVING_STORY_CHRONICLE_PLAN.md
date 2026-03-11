# Living Story Chronicle — Complete Implementation Plan

**Version**: 2.0 | **Target age**: ALL ages (3+, age-adaptive)
**Dependency order**: Phase 1 (backend) and Phase 2 (Isar models) are fully independent of each other and can be done in parallel. Phase 3 depends on Phase 2 completing and `flutter pub run build_runner build` being run. Phase 4 depends on Phase 3. Phase 5 depends on Phase 3. Phase 6 depends on Phases 4 and 5. Phase 7 tasks can be done in any order after Phase 6 is complete.

---

## QUICK START INDEX — Read This First

This plan is broken into 7 phases and 20 tasks. Implement them in the order shown below unless the "Parallel" column says otherwise. Every task has: an exact file path, exact search text, exact replacement text, and a concrete test command you can run immediately.

| # | Task | File | Action | Parallel? |
|---|------|------|---------|-----------|
| 1.1 | Create chronicle prompt service | `backend/services/chronicle_prompt_service.py` | CREATE | Yes (with 1.2, 2.x) |
| 1.2 | Create chronicle routes | `backend/routes/chronicle_routes.py` | CREATE | Yes (with 1.1, 2.x) |
| 1.3 | Register blueprint in app.py | `backend/app.py` | MODIFY | After 1.1 and 1.2 |
| 1.4 | Add chronicle_context param to prompt builder | `backend/services/interactive_adventure_prompt_builder.py` | MODIFY | After 1.1 |
| 1.5 | Thread chronicle_context through story route | `backend/routes/story_routes.py` + `backend/services/interactive_adventure_service.py` | MODIFY | After 1.4 |
| 2.1 | Create ChronicleLocal Isar model | `lib/models/local/chronicle_local.dart` | CREATE | Yes (with 1.x) |
| 2.2 | Create ChapterMemoryLocal Isar model | `lib/models/local/chapter_memory_local.dart` | CREATE | Yes (with 1.x) |
| 2.3 | Register new Isar schemas | `lib/services/isar_service_io.dart` | MODIFY | After 2.1 and 2.2 |
| — | Run codegen | terminal | COMMAND | After 2.3: `flutter pub run build_runner build --delete-conflicting-outputs` |
| 3.1 | Add chronicleUrl helpers | `lib/config/environment.dart` | MODIFY | After codegen |
| 3.2 | Create ChronicleService | `lib/services/chronicle_service.dart` | CREATE | After codegen |
| 4.1 | Add chronicle params to PickAPathAdventureScreen | `lib/pick_a_path_adventure_screen.dart` | MODIFY | After 3.2 |
| 5.1 | Create ChronicleScreen | `lib/screens/chronicle_screen.dart` | CREATE | After 3.2 |
| 5.2 | Create ChroniclesListScreen | `lib/screens/chronicles_list_screen.dart` | CREATE | After 3.2 |
| 6.1 | Add "My Chronicles" to home menu | `lib/main_story.dart` | MODIFY | After 5.1 and 5.2 |
| 6.2 | Age gate (initially 11+, removed in 7.1) | `lib/screens/chronicles_list_screen.dart` | MODIFY | After 6.1 |
| 7.1 | Remove age gate — open to all ages | `lib/screens/chronicles_list_screen.dart` | MODIFY | After 6.2 |
| 7.2 | Session length limit by age band | `lib/pick_a_path_adventure_screen.dart` | MODIFY | After 7.1 |
| 7.3 | Auto-TTS for ages 3–7 | `lib/pick_a_path_adventure_screen.dart` | MODIFY | After 7.2 |
| 7.4 | Age-adaptive choice tiles | `lib/pick_a_path_adventure_screen.dart` | MODIFY | After 7.3 |
| 7.5 | Parent co-pilot bottom sheet | `lib/pick_a_path_adventure_screen.dart` | MODIFY | After 7.4 |
| 7.6 | Age-adaptive completion screen | `lib/pick_a_path_adventure_screen.dart` | MODIFY | After 7.5 |
| 7.7 | Age-adaptive ChronicleScreen | `lib/screens/chronicle_screen.dart` | MODIFY | After 7.6 |
| 7.8 | Age-adaptive labels | `lib/screens/chronicle_screen.dart` + `lib/screens/chronicles_list_screen.dart` | MODIFY | After 7.7 |
| 7.9 | Backend age-appropriate vocabulary | `backend/services/chronicle_prompt_service.py` | MODIFY | Anytime after 1.1 |

**RULE: Never modify any code in a file beyond what is explicitly described in the task. Do not refactor, clean up, or improve code you are not instructed to change.**

---

## PHASE 1 — Backend

### Task 1.1 — Create `backend/services/chronicle_prompt_service.py`

**File**: `/c/dev/story-weaver-app/backend/services/chronicle_prompt_service.py`
**Action**: Create this file with the exact contents below.

```python
"""
Chronicle Prompt Service
Builds Gemini prompts for chapter summarization and arc compression.
"""
import json
import logging
import os
from typing import Dict, List, Optional, Any

from google import genai
from google.genai import types

logger = logging.getLogger(__name__)


class ChroniclePromptService:
    """Builds and executes prompts for Living Story Chronicle operations."""

    SUMMARIZE_SYSTEM = (
        "You are a story archivist. You read a completed interactive story chapter "
        "and extract a compact memory packet in strict JSON. Be precise and concise."
    )

    COMPRESS_SYSTEM = (
        "You are a story archivist. You compress five chapter summaries into a single "
        "arc summary paragraph in strict JSON."
    )

    def __init__(self, gemini_api_key: Optional[str] = None):
        self.api_key = gemini_api_key or os.getenv("GEMINI_API_KEY")
        if not self.api_key:
            raise ValueError("GEMINI_API_KEY not set")
        self._client = genai.Client(api_key=self.api_key)
        self._model_name = os.getenv("GEMINI_MODEL", "gemini-2.0-flash")
        self._json_config = types.GenerateContentConfig(
            response_mime_type="application/json",
            max_output_tokens=1000,
            temperature=0.3,
        )

    def summarize_chapter(
        self,
        chapter_number: int,
        chapter_text: str,
        character_name: str,
        choice_made_to_start: Optional[str],
        existing_world_facts: List[str],
        existing_unresolved_threads: List[str],
    ) -> Dict[str, Any]:
        """
        Call Gemini to summarize one completed chapter.

        Returns a dict matching this schema:
        {
          "summary_bullets": ["...", ...],        # 5-8 bullets
          "new_world_facts": ["..."],              # new canonical facts
          "character_growth": "...",              # single sentence
          "cliffhanger": "...",                   # how the chapter ended
          "new_unresolved_threads": ["..."],      # new open plot threads
          "resolved_threads": ["..."],            # threads closed this chapter
          "character_state_update": {
            "growth": "...",
            "items_gained": ["..."],
            "items_lost": ["..."],
            "relationships": ["..."]
          }
        }
        """
        existing_facts_str = (
            "\n".join(f"- {f}" for f in existing_world_facts)
            if existing_world_facts
            else "None yet."
        )
        existing_threads_str = (
            "\n".join(f"- {t}" for t in existing_unresolved_threads)
            if existing_unresolved_threads
            else "None yet."
        )
        choice_line = (
            f'The reader chose: "{choice_made_to_start}" to begin this chapter.'
            if choice_made_to_start
            else "This was the first chapter."
        )

        prompt = f"""{self.SUMMARIZE_SYSTEM}

CHAPTER {chapter_number} TEXT FOR CHARACTER "{character_name}":
{chapter_text}

CONTEXT:
{choice_line}

EXISTING WORLD FACTS (already known — only add NEW facts):
{existing_facts_str}

EXISTING UNRESOLVED THREADS (already tracked — identify which are closed, which are new):
{existing_threads_str}

Return ONLY valid JSON matching this exact schema:
{{
  "summary_bullets": ["bullet 1", "bullet 2", "bullet 3", "bullet 4", "bullet 5"],
  "new_world_facts": ["fact 1"],
  "character_growth": "One sentence describing how {character_name} changed.",
  "cliffhanger": "The last 1-2 sentences of the chapter or a cliffhanger hook for next time.",
  "new_unresolved_threads": ["new thread 1"],
  "resolved_threads": ["closed thread 1"],
  "character_state_update": {{
    "growth": "One sentence on character growth.",
    "items_gained": ["item 1"],
    "items_lost": [],
    "relationships": ["ally: Name — description"]
  }}
}}"""

        response = self._client.models.generate_content(
            model=self._model_name,
            contents=prompt,
            config=self._json_config,
        )
        text = response.text if hasattr(response, "text") else ""
        return json.loads(text)

    def compress_arc(
        self,
        arc_number: int,
        chapter_start: int,
        chapter_end: int,
        chapter_summaries: List[Dict[str, Any]],
        character_name: str,
    ) -> Dict[str, str]:
        """
        Compress 5 chapter summaries into one arc summary paragraph.

        Returns:
        {
          "arc_summary": "Arc N (Ch X-Y): One paragraph summary..."
        }
        """
        summaries_text = ""
        for i, mem in enumerate(chapter_summaries):
            ch_num = chapter_start + i
            bullets = "\n".join(
                f"  - {b}" for b in (mem.get("summary_bullets") or [])
            )
            summaries_text += f"\nChapter {ch_num}:\n{bullets}\n"

        prompt = f"""{self.COMPRESS_SYSTEM}

CHARACTER: {character_name}
ARC {arc_number} covers Chapters {chapter_start}–{chapter_end}.

CHAPTER SUMMARIES:
{summaries_text}

Return ONLY valid JSON:
{{
  "arc_summary": "Arc {arc_number} (Ch {chapter_start}-{chapter_end}): One paragraph (3-5 sentences) covering key events, choices made, and character growth."
}}"""

        response = self._client.models.generate_content(
            model=self._model_name,
            contents=prompt,
            config=self._json_config,
        )
        text = response.text if hasattr(response, "text") else ""
        return json.loads(text)
```

**Test condition**: Run `python -c "from backend.services.chronicle_prompt_service import ChroniclePromptService; print('OK')"` from the project root inside the venv. No ImportError.

---

### Task 1.2 — Create `backend/routes/chronicle_routes.py`

**File**: `/c/dev/story-weaver-app/backend/routes/chronicle_routes.py`
**Action**: Create this file with the exact contents below.

```python
"""
Chronicle Routes
Endpoints for Living Story Chronicle: chapter summarization and arc compression.
"""
import logging
from flask import Blueprint, jsonify, request

try:
    from backend.middleware.auth import require_auth
    from backend.services.chronicle_prompt_service import ChroniclePromptService
except ImportError:
    from middleware.auth import require_auth
    from services.chronicle_prompt_service import ChroniclePromptService

logger = logging.getLogger(__name__)

chronicle_bp = Blueprint("chronicle", __name__)


def create_chronicle_blueprint(api_key: str, limiter) -> Blueprint:
    """Factory function matching the pattern of other blueprints in this app."""

    @chronicle_bp.route("/chronicle/summarize-chapter", methods=["POST"])
    @limiter.limit("20 per minute")
    @require_auth
    def summarize_chapter():
        """
        Summarize a completed chapter into a compact memory packet.

        Request body:
            chapter_number: int (required)
            chapter_text: str (required) — full concatenated text of the chapter
            character_name: str (required)
            choice_made_to_start: str (optional) — the choice that began this chapter
            existing_world_facts: list[str] (optional)
            existing_unresolved_threads: list[str] (optional)

        Returns: JSON matching ChroniclePromptService.summarize_chapter() schema.
        """
        payload = request.get_json(silent=True) or {}

        chapter_number = payload.get("chapter_number")
        chapter_text = payload.get("chapter_text", "")
        character_name = payload.get("character_name", "Hero")
        choice_made_to_start = payload.get("choice_made_to_start")
        existing_world_facts = payload.get("existing_world_facts") or []
        existing_unresolved_threads = payload.get("existing_unresolved_threads") or []

        if not chapter_number or not chapter_text:
            return jsonify({"error": "chapter_number and chapter_text are required"}), 400

        if len(chapter_text) > 50000:
            return jsonify({"error": "chapter_text too long (max 50000 chars)"}), 400

        try:
            service = ChroniclePromptService(gemini_api_key=api_key)
            result = service.summarize_chapter(
                chapter_number=int(chapter_number),
                chapter_text=chapter_text,
                character_name=character_name,
                choice_made_to_start=choice_made_to_start,
                existing_world_facts=existing_world_facts,
                existing_unresolved_threads=existing_unresolved_threads,
            )
            return jsonify(result), 200
        except Exception as e:
            logger.exception("Chapter summarization failed")
            return jsonify({"error": str(e)}), 500

    @chronicle_bp.route("/chronicle/compress-arc", methods=["POST"])
    @limiter.limit("10 per minute")
    @require_auth
    def compress_arc():
        """
        Compress 5 chapter memories into one arc summary paragraph.

        Request body:
            arc_number: int (required)
            chapter_start: int (required) — first chapter number in the arc
            chapter_end: int (required) — last chapter number in the arc
            chapter_summaries: list[dict] (required) — list of 5 memory objects,
                each having a "summary_bullets" key (list of strings)
            character_name: str (required)

        Returns: {"arc_summary": "Arc N (Ch X-Y): ..."}
        """
        payload = request.get_json(silent=True) or {}

        arc_number = payload.get("arc_number")
        chapter_start = payload.get("chapter_start")
        chapter_end = payload.get("chapter_end")
        chapter_summaries = payload.get("chapter_summaries") or []
        character_name = payload.get("character_name", "Hero")

        if not arc_number or not chapter_start or not chapter_end:
            return jsonify({"error": "arc_number, chapter_start, and chapter_end are required"}), 400

        if len(chapter_summaries) != 5:
            return jsonify({"error": "chapter_summaries must contain exactly 5 entries"}), 400

        try:
            service = ChroniclePromptService(gemini_api_key=api_key)
            result = service.compress_arc(
                arc_number=int(arc_number),
                chapter_start=int(chapter_start),
                chapter_end=int(chapter_end),
                chapter_summaries=chapter_summaries,
                character_name=character_name,
            )
            return jsonify(result), 200
        except Exception as e:
            logger.exception("Arc compression failed")
            return jsonify({"error": str(e)}), 500

    return chronicle_bp
```

**Test condition**: `python -c "from backend.routes.chronicle_routes import create_chronicle_blueprint; print('OK')"` inside the venv. No ImportError.

---

### Task 1.3 — Register the chronicle blueprint in `backend/app.py`

**File**: `/c/dev/story-weaver-app/backend/app.py`

**Find this exact block** (lines ~510–527):
```python
    try:
        from backend.routes.story_routes import create_story_blueprint
        from backend.routes.character_routes import create_character_blueprint
        from backend.routes.admin_routes import create_admin_blueprint
        from backend.routes.avatar_routes import avatar_bp
        from backend.routes.avatar_gallery_routes import avatar_gallery_bp
        from backend.routes.health_routes import create_health_blueprint
        from backend.routes.utility_routes import create_utility_blueprint
        from backend.routes.therapist_routes import create_therapist_blueprint
    except ImportError:
        from routes.story_routes import create_story_blueprint
        from routes.character_routes import create_character_blueprint
        from routes.admin_routes import create_admin_blueprint
        from routes.avatar_routes import avatar_bp
        from routes.avatar_gallery_routes import avatar_gallery_bp
        from routes.health_routes import create_health_blueprint
        from routes.utility_routes import create_utility_blueprint
        from routes.therapist_routes import create_therapist_blueprint
```

**Replace with**:
```python
    try:
        from backend.routes.story_routes import create_story_blueprint
        from backend.routes.character_routes import create_character_blueprint
        from backend.routes.admin_routes import create_admin_blueprint
        from backend.routes.avatar_routes import avatar_bp
        from backend.routes.avatar_gallery_routes import avatar_gallery_bp
        from backend.routes.health_routes import create_health_blueprint
        from backend.routes.utility_routes import create_utility_blueprint
        from backend.routes.therapist_routes import create_therapist_blueprint
        from backend.routes.chronicle_routes import create_chronicle_blueprint
    except ImportError:
        from routes.story_routes import create_story_blueprint
        from routes.character_routes import create_character_blueprint
        from routes.admin_routes import create_admin_blueprint
        from routes.avatar_routes import avatar_bp
        from routes.avatar_gallery_routes import avatar_gallery_bp
        from routes.health_routes import create_health_blueprint
        from routes.utility_routes import create_utility_blueprint
        from routes.therapist_routes import create_therapist_blueprint
        from routes.chronicle_routes import create_chronicle_blueprint
```

**Then find** the block near line 548 that registers `therapist_bp`:
```python
    therapist_bp = create_therapist_blueprint(logger=logger, limiter=limiter)

    app.register_blueprint(story_bp)
```

**After `therapist_bp = create_therapist_blueprint(...)` and before `app.register_blueprint(story_bp)`, insert**:
```python
    chronicle_bp = create_chronicle_blueprint(api_key=api_key, limiter=limiter)
```

**Then find** this line (approximately line 555):
```python
    app.register_blueprint(therapist_bp)
```

**After it, insert**:
```python
    app.register_blueprint(chronicle_bp)
```

**Test condition**: Start the Flask backend (`python backend/run.py`). In the startup log, look for the line `=== Registered routes: ...`. Confirm `/chronicle/summarize-chapter` and `/chronicle/compress-arc` appear in the printed route list.

---

### Task 1.4 — Modify `backend/services/interactive_adventure_prompt_builder.py` to accept `chronicle_context`

**File**: `/c/dev/story-weaver-app/backend/services/interactive_adventure_prompt_builder.py`

**Step A — Add `chronicle_context` parameter to `build_opening_prompt` signature.**

Find the exact signature starting at line 249:
```python
    @classmethod
    def build_opening_prompt(
        cls,
        child_name: str,
        age: int,
        length: str,
        theme: str,
        tone: str,
        character: Optional[Dict] = None,
        companions: Optional[List[Dict]] = None,
        interests: Optional[List[str]] = None,
        must_include: Optional[List[str]] = None,
        avoid: Optional[List[str]] = None,
        fears_or_sensitivities: Optional[List[str]] = None,
        spark_tool: Optional[str] = None,
        mood_physics: Optional[Dict] = None,
        conflict_hook: Optional[str] = None,
        sensory_palette: Optional[str] = None,
        world_bible: str = "",
        life_challenge: Optional[str] = None,
        personality_sliders: Optional[Dict[str, int]] = None
    ) -> str:
```

Replace with:
```python
    @classmethod
    def build_opening_prompt(
        cls,
        child_name: str,
        age: int,
        length: str,
        theme: str,
        tone: str,
        character: Optional[Dict] = None,
        companions: Optional[List[Dict]] = None,
        interests: Optional[List[str]] = None,
        must_include: Optional[List[str]] = None,
        avoid: Optional[List[str]] = None,
        fears_or_sensitivities: Optional[List[str]] = None,
        spark_tool: Optional[str] = None,
        mood_physics: Optional[Dict] = None,
        conflict_hook: Optional[str] = None,
        sensory_palette: Optional[str] = None,
        world_bible: str = "",
        life_challenge: Optional[str] = None,
        personality_sliders: Optional[Dict[str, int]] = None,
        chronicle_context: Optional[Dict] = None,
    ) -> str:
```

**Step B — Inject the chronicle block into the prompt string.**

Find the exact line in the `prompt = f"""` block at approximately line 383:
```python
{('- **WORLD BIBLE** (CRITICAL — follow this for setting consistency): ' + world_bible) if world_bible else ''}
```

Directly after that line (keeping it intact), add this new f-string section. The entire replacement block looks like this — find the two-line stretch below and replace with the four-line stretch:

Find:
```python
{('- **WORLD BIBLE** (CRITICAL — follow this for setting consistency): ' + world_bible) if world_bible else ''}
{challenge_instruction}
```

Replace with:
```python
{('- **WORLD BIBLE** (CRITICAL — follow this for setting consistency): ' + world_bible) if world_bible else ''}
{cls._build_chronicle_block(chronicle_context) if chronicle_context else ''}
{challenge_instruction}
```

**Step C — Add the `_build_chronicle_block` static method** at the bottom of the class, directly before the existing `_build_companion_context` static method (line ~589):

Find:
```python
    @staticmethod
    def _build_companion_context(companions: Optional[List[Dict]]) -> str:
```

Insert above it:
```python
    @staticmethod
    def _build_chronicle_block(ctx: Dict) -> str:
        """Format the chronicle context block for injection into the opening prompt."""
        if not ctx:
            return ""
        chapter_count = ctx.get("chapter_count", 0)
        character_state = ctx.get("character_state", "No state recorded yet.")
        world_facts = ctx.get("world_facts") or []
        arc_summaries = ctx.get("arc_summaries") or []
        recent_memories = ctx.get("recent_memories") or []
        unresolved_threads = ctx.get("unresolved_threads") or []
        last_chapter_ending = ctx.get("last_chapter_ending", "")

        facts_str = "\n".join(f"  - {f}" for f in world_facts) if world_facts else "  None yet."
        arcs_str = "\n".join(f"  {a}" for a in arc_summaries) if arc_summaries else "  None yet."

        memories_lines = []
        for i, mem in enumerate(recent_memories[-3:]):
            ch = mem.get("chapter_number", "?")
            bullets = mem.get("summary_bullets") or []
            bullets_str = " ".join(f"[{b}]" for b in bullets[:3])
            memories_lines.append(f"  Chapter {ch}: {bullets_str}")
        memories_str = "\n".join(memories_lines) if memories_lines else "  No recent chapters yet."

        threads_str = "\n".join(f"  - {t}" for t in unresolved_threads) if unresolved_threads else "  None open."

        ending_line = (
            f'\nLAST SESSION ENDED WITH: "{last_chapter_ending}"\nTHE NEXT CHAPTER MUST continue from exactly where this left off.'
            if last_chapter_ending
            else ""
        )

        return f"""
**LIVING CHRONICLE (Chapters 1-{chapter_count} completed — treat this as absolute canon)**:
CHARACTER STATE: {character_state}
WORLD FACTS (established canon — never contradict these):
{facts_str}
STORY ARCS SO FAR:
{arcs_str}
RECENT CHAPTERS:
{memories_str}
OPEN STORY THREADS (must eventually resolve):
{threads_str}{ending_line}
"""

```

**Test condition**: In the venv, run:
```
python -c "
from backend.services.interactive_adventure_prompt_builder import InteractiveAdventurePromptBuilder
ctx = {'chapter_count': 3, 'character_state': 'brave', 'world_facts': ['The forest is sentient'], 'arc_summaries': [], 'recent_memories': [], 'unresolved_threads': ['Find the missing key'], 'last_chapter_ending': 'The door slammed shut.'}
p = InteractiveAdventurePromptBuilder.build_opening_prompt(child_name='Alex', age=12, length='medium', theme='Magic', tone='whimsical', chronicle_context=ctx)
assert 'LIVING CHRONICLE' in p
assert 'The forest is sentient' in p
assert 'The door slammed shut.' in p
print('OK')
"
```
No assertion errors.

---

### Task 1.5 — Thread `chronicle_context` through the story route and service

**File A**: `/c/dev/story-weaver-app/backend/routes/story_routes.py`

Find (around line 438):
```python
        world_bible = payload.get("worldBible", "")
        conflict_hook = payload.get("conflictHook", "")
        sensory_palette = payload.get("sensoryPalette", "")
```

Replace with:
```python
        world_bible = payload.get("worldBible", "")
        conflict_hook = payload.get("conflictHook", "")
        sensory_palette = payload.get("sensoryPalette", "")
        chronicle_context = payload.get("chronicle_context")
```

Find (around line 447):
```python
            result = service.create_story(
                user_id=user_id,
                character_id=character_id,
                theme=theme,
                tone=tone,
                length=length,
                age=age,
                interests=interests,
                must_include=must_include,
                avoid=avoid,
                life_challenge=life_challenge,
                personality_sliders=personality_sliders,
                world_bible=world_bible,
                conflict_hook=conflict_hook,
                sensory_palette=sensory_palette,
            )
```

Replace with:
```python
            result = service.create_story(
                user_id=user_id,
                character_id=character_id,
                theme=theme,
                tone=tone,
                length=length,
                age=age,
                interests=interests,
                must_include=must_include,
                avoid=avoid,
                life_challenge=life_challenge,
                personality_sliders=personality_sliders,
                world_bible=world_bible,
                conflict_hook=conflict_hook,
                sensory_palette=sensory_palette,
                chronicle_context=chronicle_context,
            )
```

**File B**: `/c/dev/story-weaver-app/backend/services/interactive_adventure_service.py`

Find the `create_story` method signature (around line 61):
```python
    def create_story(
        self,
        user_id: str,
        character_id: Optional[str],
        theme: str,
        tone: str,
        length: str,
        age: Optional[int] = None,
        interests: Optional[List[str]] = None,
        must_include: Optional[List[str]] = None,
        avoid: Optional[List[str]] = None,
        fears_or_sensitivities: Optional[List[str]] = None,
        life_challenge: Optional[str] = None,
        personality_sliders: Optional[Dict[str, int]] = None,
        world_bible: str = "",
        conflict_hook: str = "",
        sensory_palette: str = "",
    ) -> Dict[str, Any]:
```

Replace with:
```python
    def create_story(
        self,
        user_id: str,
        character_id: Optional[str],
        theme: str,
        tone: str,
        length: str,
        age: Optional[int] = None,
        interests: Optional[List[str]] = None,
        must_include: Optional[List[str]] = None,
        avoid: Optional[List[str]] = None,
        fears_or_sensitivities: Optional[List[str]] = None,
        life_challenge: Optional[str] = None,
        personality_sliders: Optional[Dict[str, int]] = None,
        world_bible: str = "",
        conflict_hook: str = "",
        sensory_palette: str = "",
        chronicle_context: Optional[Dict] = None,
    ) -> Dict[str, Any]:
```

Find the call to `build_opening_prompt` inside `create_story` (around line 149):
```python
        prompt = InteractiveAdventurePromptBuilder.build_opening_prompt(
            child_name=child_name,
            age=character_age,
            length=length,
            theme=theme,
            tone=tone,
            character=character_dict,
            companions=companions if companions else None,
            interests=interests,
            must_include=must_include,
            avoid=avoid,
            fears_or_sensitivities=fears_or_sensitivities,
            life_challenge=life_challenge,
            personality_sliders=personality_sliders,
            world_bible=world_bible,
            conflict_hook=conflict_hook,
            sensory_palette=sensory_palette,
        )
```

Replace with:
```python
        prompt = InteractiveAdventurePromptBuilder.build_opening_prompt(
            child_name=child_name,
            age=character_age,
            length=length,
            theme=theme,
            tone=tone,
            character=character_dict,
            companions=companions if companions else None,
            interests=interests,
            must_include=must_include,
            avoid=avoid,
            fears_or_sensitivities=fears_or_sensitivities,
            life_challenge=life_challenge,
            personality_sliders=personality_sliders,
            world_bible=world_bible,
            conflict_hook=conflict_hook,
            sensory_palette=sensory_palette,
            chronicle_context=chronicle_context,
        )
```

**Test condition**: Use curl or Postman. POST to `/generate-interactive-story` with a valid auth token and body:
```json
{
  "character_id": "<any valid id>",
  "theme": "Magic",
  "tone": "whimsical",
  "length": "short",
  "chronicle_context": {
    "chapter_count": 2,
    "character_state": "brave",
    "world_facts": ["The Crystal Tower is real"],
    "arc_summaries": [],
    "recent_memories": [],
    "unresolved_threads": ["The mirror spoke"],
    "last_chapter_ending": "You heard footsteps behind you."
  }
}
```
Response is 200 with a valid segment. The word "LIVING CHRONICLE" will not appear in the response (it was in the prompt, not the output), but the story content should reference the context. Confirm no 500 error.

---

## PHASE 2 — Isar Models

**Prerequisite**: Phase 2 tasks 2.1–2.3 must all be complete before running `build_runner`. The generated `.g.dart` files produced by `build_runner` must exist before Phase 3.

### Task 2.1 — Create `lib/models/local/chronicle_local.dart`

**File**: `/c/dev/story-weaver-app/lib/models/local/chronicle_local.dart`
**Action**: Create with exact contents below.

```dart
import 'package:isar/isar.dart';
part 'chronicle_local.g.dart';

@collection
class ChronicleLocal {
  Id id = Isar.autoIncrement;

  @Index()
  late String chronicleId; // UUID

  @Index()
  late String characterId; // CharacterLocal.characterId

  late String characterName;
  late int characterAge;
  late String title;
  late String genre; // fantasy, sci-fi, mystery, etc.
  late DateTime createdAt;
  late DateTime lastPlayedAt;
  int chapterCount = 0;
  bool isActive = true;

  /// JSON-encoded List<String> of arc summary strings
  String? arcSummariesJson;

  /// JSON-encoded List<Map> of last 3 chapter memory objects
  /// Each map has keys: chapter_number, summary_bullets, cliffhanger
  String? recentMemoriesJson;

  /// JSON-encoded List<String> of established world fact strings
  String? worldFactsJson;

  /// JSON-encoded Map: {growth: str, items: [str], relationships: [str]}
  String? characterStateJson;

  /// JSON-encoded List<String> of open plot thread strings
  String? unresolvedThreadsJson;

  String? lastChoiceMade;

  /// Last 1-2 sentences of the previous chapter for continuity
  String? lastChapterEnding;

  /// Base64-encoded PNG cover image (optional)
  String? coverImageBase64;
}
```

**Test condition**: File compiles without errors (validated in Task 2.3).

---

### Task 2.2 — Create `lib/models/local/chapter_memory_local.dart`

**File**: `/c/dev/story-weaver-app/lib/models/local/chapter_memory_local.dart`
**Action**: Create with exact contents below.

```dart
import 'package:isar/isar.dart';
part 'chapter_memory_local.g.dart';

@collection
class ChapterMemoryLocal {
  Id id = Isar.autoIncrement;

  @Index()
  late String chronicleId;

  late int chapterNumber;
  late DateTime createdAt;

  /// The choice text the player made to begin this chapter (null for Ch 1)
  String? choiceMadeToStartChapter;

  /// JSON-encoded List<String> of 5-8 bullet summary strings
  String? summaryBulletsJson;

  /// JSON-encoded List<String> of new canonical world fact strings
  String? newWorldFactsJson;

  /// One sentence describing character growth this chapter
  String? characterGrowthNote;

  /// How the chapter ended / cliffhanger hook
  String? cliffhanger;

  /// JSON-encoded List<String> of new unresolved plot threads
  String? newThreadsJson;

  /// JSON-encoded List<String> of threads closed this chapter
  String? resolvedThreadsJson;

  /// Full concatenated chapter text (for re-reading and summarization input)
  String? fullChapterText;
}
```

**Test condition**: File compiles without errors (validated in Task 2.3).

---

### Task 2.3 — Register new schemas in `lib/services/isar_service_io.dart`

**File**: `/c/dev/story-weaver-app/lib/services/isar_service_io.dart`

**Step A — Add imports.** Find the import block at the top of the file:
```dart
import '../models/local/character_local_io.dart';
import '../avatar_models.dart';
import '../models/local/story_local_io.dart';
```

Replace with:
```dart
import '../models/local/character_local_io.dart';
import '../avatar_models.dart';
import '../models/local/story_local_io.dart';
import '../models/local/chronicle_local.dart';
import '../models/local/chapter_memory_local.dart';
```

**Step B — Register schemas.** Find:
```dart
    _isar = await Isar.open(
      [StoryLocalSchema, CharacterLocalSchema],
      directory: dir.path,
      inspector: true,
    );
```

Replace with:
```dart
    _isar = await Isar.open(
      [
        StoryLocalSchema,
        CharacterLocalSchema,
        ChronicleLocalSchema,
        ChapterMemoryLocalSchema,
      ],
      directory: dir.path,
      inspector: true,
    );
```

**Step C — Run code generation.** In the project root (where `pubspec.yaml` lives), run:
```
flutter pub run build_runner build --delete-conflicting-outputs
```

This generates `chronicle_local.g.dart` and `chapter_memory_local.g.dart`. The command must complete with exit code 0 and the two generated files must exist at:
- `lib/models/local/chronicle_local.g.dart`
- `lib/models/local/chapter_memory_local.g.dart`

**Test condition**: `flutter analyze` exits with no errors related to the new model files. The generated files contain `ChronicleLocalSchema` and `ChapterMemoryLocalSchema`.

---

## PHASE 3 — ChronicleService (Flutter Orchestration)

**Prerequisite**: Phase 2 complete including `build_runner` run.

### Task 3.1 — Add `chronicleUrl` helpers to `lib/config/environment.dart`

**File**: `/c/dev/story-weaver-app/lib/config/environment.dart`

Find:
```dart
  static String get continueInteractiveStoryUrl =>
      '$backendUrl/continue-interactive-story';
  static String get createCharacterUrl => '$backendUrl/create-character';
```

Replace with:
```dart
  static String get continueInteractiveStoryUrl =>
      '$backendUrl/continue-interactive-story';
  static String get summarizeChapterUrl =>
      '$backendUrl/chronicle/summarize-chapter';
  static String get compressArcUrl =>
      '$backendUrl/chronicle/compress-arc';
  static String get createCharacterUrl => '$backendUrl/create-character';
```

**Test condition**: `flutter analyze lib/config/environment.dart` exits with 0 errors.

---

### Task 3.2 — Create `lib/services/chronicle_service.dart`

**File**: `/c/dev/story-weaver-app/lib/services/chronicle_service.dart`
**Action**: Create with exact contents below.

```dart
import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:isar/isar.dart';
import 'package:uuid/uuid.dart';

import '../config/environment.dart';
import '../models/local/chapter_memory_local.dart';
import '../models/local/chronicle_local.dart';
import 'api_service_manager.dart';
import 'isar_service.dart';

/// Orchestrates the Living Story Chronicle: persistence, history assembly,
/// chapter summarization, and arc compression.
class ChronicleService {
  static const _uuid = Uuid();

  // -------------------------------------------------------------------------
  // ISAR READ HELPERS
  // -------------------------------------------------------------------------

  /// Return all chronicles for a given characterId, newest-last-played first.
  static Future<List<ChronicleLocal>> getChroniclesForCharacter(
      String characterId) async {
    final isar = await IsarService.getInstance();
    return isar.chronicleLocals
        .filter()
        .characterIdEqualTo(characterId)
        .and()
        .isActiveEqualTo(true)
        .sortByLastPlayedAtDesc()
        .findAll();
  }

  /// Return a single chronicle by chronicleId string.
  static Future<ChronicleLocal?> getChronicle(String chronicleId) async {
    final isar = await IsarService.getInstance();
    return isar.chronicleLocals
        .filter()
        .chronicleIdEqualTo(chronicleId)
        .findFirst();
  }

  /// Return all chapter memories for a chronicle, sorted by chapterNumber asc.
  static Future<List<ChapterMemoryLocal>> getChapterMemories(
      String chronicleId) async {
    final isar = await IsarService.getInstance();
    return isar.chapterMemoryLocals
        .filter()
        .chronicleIdEqualTo(chronicleId)
        .sortByChapterNumber()
        .findAll();
  }

  // -------------------------------------------------------------------------
  // CREATE / UPDATE CHRONICLE
  // -------------------------------------------------------------------------

  /// Create a brand-new ChronicleLocal and persist it. Returns the new chronicle.
  static Future<ChronicleLocal> createChronicle({
    required String characterId,
    required String characterName,
    required int characterAge,
    required String title,
    required String genre,
  }) async {
    final isar = await IsarService.getInstance();
    final chronicle = ChronicleLocal()
      ..chronicleId = _uuid.v4()
      ..characterId = characterId
      ..characterName = characterName
      ..characterAge = characterAge
      ..title = title
      ..genre = genre
      ..createdAt = DateTime.now()
      ..lastPlayedAt = DateTime.now()
      ..chapterCount = 0
      ..isActive = true;

    await isar.writeTxn(() async {
      await isar.chronicleLocals.put(chronicle);
    });
    return chronicle;
  }

  /// Update the chronicle after a chapter completes. Merges new world facts,
  /// updates recentMemories (keep last 3), updates characterState,
  /// merges unresolved threads, and bumps chapterCount.
  static Future<void> updateChronicleAfterChapter({
    required String chronicleId,
    required ChapterMemoryLocal memory,
    required Map<String, dynamic> characterStateUpdate,
    required String lastChapterEnding,
    required String choiceMade,
  }) async {
    final isar = await IsarService.getInstance();
    final chronicle = await getChronicle(chronicleId);
    if (chronicle == null) return;

    // Decode existing data
    final existingFacts =
        _decodeStringList(chronicle.worldFactsJson);
    final existingThreads =
        _decodeStringList(chronicle.unresolvedThreadsJson);
    final existingMemories =
        _decodeMemoryList(chronicle.recentMemoriesJson);

    // Merge new world facts (deduplicate)
    final newFacts = _decodeStringList(memory.newWorldFactsJson);
    final mergedFacts = {...existingFacts, ...newFacts}.toList();

    // Merge threads: remove resolved, add new
    final resolvedThreads = _decodeStringList(memory.resolvedThreadsJson);
    final newThreads = _decodeStringList(memory.newThreadsJson);
    final mergedThreads = existingThreads
        .where((t) => !resolvedThreads.contains(t))
        .toList()
      ..addAll(newThreads);

    // Build compact memory entry for recentMemories list
    final memEntry = {
      'chapter_number': memory.chapterNumber,
      'summary_bullets': _decodeStringList(memory.summaryBulletsJson),
      'cliffhanger': memory.cliffhanger ?? '',
    };
    final updatedMemories = [...existingMemories, memEntry];
    // Keep last 3 only
    final trimmedMemories = updatedMemories.length > 3
        ? updatedMemories.sublist(updatedMemories.length - 3)
        : updatedMemories;

    // Build characterState string
    final growth = characterStateUpdate['growth'] as String? ?? '';
    final items =
        (characterStateUpdate['items_gained'] as List?)?.cast<String>() ?? [];
    final relationships =
        (characterStateUpdate['relationships'] as List?)?.cast<String>() ?? [];
    final characterStateMap = {
      'growth': growth,
      'items': items,
      'relationships': relationships,
    };

    await isar.writeTxn(() async {
      chronicle
        ..chapterCount = chronicle.chapterCount + 1
        ..lastPlayedAt = DateTime.now()
        ..lastChoiceMade = choiceMade
        ..lastChapterEnding = lastChapterEnding
        ..worldFactsJson = jsonEncode(mergedFacts)
        ..unresolvedThreadsJson = jsonEncode(mergedThreads)
        ..recentMemoriesJson = jsonEncode(trimmedMemories)
        ..characterStateJson = jsonEncode(characterStateMap);
      await isar.chronicleLocals.put(chronicle);
    });
  }

  /// Append an arc summary to the chronicle's arcSummariesJson list.
  static Future<void> appendArcSummary({
    required String chronicleId,
    required String arcSummary,
  }) async {
    final isar = await IsarService.getInstance();
    final chronicle = await getChronicle(chronicleId);
    if (chronicle == null) return;

    final existing = _decodeStringList(chronicle.arcSummariesJson);
    existing.add(arcSummary);

    await isar.writeTxn(() async {
      chronicle.arcSummariesJson = jsonEncode(existing);
      await isar.chronicleLocals.put(chronicle);
    });
  }

  // -------------------------------------------------------------------------
  // CHAPTER MEMORY PERSISTENCE
  // -------------------------------------------------------------------------

  /// Persist a ChapterMemoryLocal to Isar.
  static Future<void> saveChapterMemory(ChapterMemoryLocal memory) async {
    final isar = await IsarService.getInstance();
    await isar.writeTxn(() async {
      await isar.chapterMemoryLocals.put(memory);
    });
  }

  // -------------------------------------------------------------------------
  // PAYLOAD BUILDER — used by PickAPathAdventureScreen before /generate-interactive-story
  // -------------------------------------------------------------------------

  /// Assemble the chronicle_context dict to inject into the
  /// POST /generate-interactive-story payload.
  static Future<Map<String, dynamic>?> buildChapterStartPayload(
      String chronicleId) async {
    final chronicle = await getChronicle(chronicleId);
    if (chronicle == null) return null;

    final worldFacts = _decodeStringList(chronicle.worldFactsJson);
    final arcSummaries = _decodeStringList(chronicle.arcSummariesJson);
    final recentMemories = _decodeMemoryList(chronicle.recentMemoriesJson);
    final unresolvedThreads =
        _decodeStringList(chronicle.unresolvedThreadsJson);
    final characterState = _decodeMap(chronicle.characterStateJson);

    final characterStateStr = characterState.isNotEmpty
        ? 'Growth: ${characterState['growth'] ?? ''} | '
            'Items: ${(characterState['items'] as List?)?.join(', ') ?? 'none'} | '
            'Allies: ${(characterState['relationships'] as List?)?.join(', ') ?? 'none'}'
        : 'No state recorded yet.';

    return {
      'chapter_count': chronicle.chapterCount,
      'character_state': characterStateStr,
      'world_facts': worldFacts,
      'arc_summaries': arcSummaries,
      'recent_memories': recentMemories,
      'unresolved_threads': unresolvedThreads,
      'last_chapter_ending': chronicle.lastChapterEnding ?? '',
    };
  }

  // -------------------------------------------------------------------------
  // BACKEND CALLS
  // -------------------------------------------------------------------------

  /// POST /chronicle/summarize-chapter. Returns the parsed JSON map.
  static Future<Map<String, dynamic>> callSummarizeChapter({
    required int chapterNumber,
    required String chapterText,
    required String characterName,
    String? choiceMadeToStart,
    List<String> existingWorldFacts = const [],
    List<String> existingUnresolvedThreads = const [],
  }) async {
    final headers = await ApiServiceManager.authHeaders();
    final uri = Uri.parse(Environment.summarizeChapterUrl);
    final response = await http
        .post(
          uri,
          headers: headers,
          body: jsonEncode({
            'chapter_number': chapterNumber,
            'chapter_text': chapterText,
            'character_name': characterName,
            if (choiceMadeToStart != null)
              'choice_made_to_start': choiceMadeToStart,
            'existing_world_facts': existingWorldFacts,
            'existing_unresolved_threads': existingUnresolvedThreads,
          }),
        )
        .timeout(const Duration(seconds: 45));

    if (response.statusCode != 200) {
      throw Exception(
          'summarize-chapter failed: ${response.statusCode} ${response.body}');
    }
    return jsonDecode(response.body) as Map<String, dynamic>;
  }

  /// POST /chronicle/compress-arc. Returns {"arc_summary": "..."}.
  static Future<Map<String, dynamic>> callCompressArc({
    required int arcNumber,
    required int chapterStart,
    required int chapterEnd,
    required List<Map<String, dynamic>> chapterSummaries,
    required String characterName,
  }) async {
    final headers = await ApiServiceManager.authHeaders();
    final uri = Uri.parse(Environment.compressArcUrl);
    final response = await http
        .post(
          uri,
          headers: headers,
          body: jsonEncode({
            'arc_number': arcNumber,
            'chapter_start': chapterStart,
            'chapter_end': chapterEnd,
            'chapter_summaries': chapterSummaries,
            'character_name': characterName,
          }),
        )
        .timeout(const Duration(seconds: 30));

    if (response.statusCode != 200) {
      throw Exception(
          'compress-arc failed: ${response.statusCode} ${response.body}');
    }
    return jsonDecode(response.body) as Map<String, dynamic>;
  }

  // -------------------------------------------------------------------------
  // FULL CHAPTER COMPLETION HANDLER
  // Called by PickAPathAdventureScreen after _isCompleted becomes true.
  // -------------------------------------------------------------------------

  /// Runs the full post-chapter pipeline in the background:
  /// 1. Calls /chronicle/summarize-chapter
  /// 2. Saves ChapterMemoryLocal to Isar
  /// 3. Updates ChronicleLocal (merges facts, state, threads)
  /// 4. If chapterCount (after increment) % 5 == 0, calls /chronicle/compress-arc
  ///    and appends the arc summary
  ///
  /// This method never throws — errors are logged and swallowed so they don't
  /// interrupt the UI. Call with unawaited() from the screen.
  static Future<void> handleChapterComplete({
    required String chronicleId,
    required int chapterNumber,
    required String chapterText,
    required String characterName,
    required String lastChapterEnding,
    required String choiceMadeToStart,
  }) async {
    try {
      final chronicle = await getChronicle(chronicleId);
      if (chronicle == null) return;

      final existingFacts = _decodeStringList(chronicle.worldFactsJson);
      final existingThreads = _decodeStringList(chronicle.unresolvedThreadsJson);

      // Step 1: Summarize chapter
      final summaryResult = await callSummarizeChapter(
        chapterNumber: chapterNumber,
        chapterText: chapterText,
        characterName: characterName,
        choiceMadeToStart: choiceMadeToStart.isNotEmpty ? choiceMadeToStart : null,
        existingWorldFacts: existingFacts,
        existingUnresolvedThreads: existingThreads,
      );

      // Step 2: Build and save ChapterMemoryLocal
      final memory = ChapterMemoryLocal()
        ..chronicleId = chronicleId
        ..chapterNumber = chapterNumber
        ..createdAt = DateTime.now()
        ..choiceMadeToStartChapter =
            choiceMadeToStart.isNotEmpty ? choiceMadeToStart : null
        ..summaryBulletsJson =
            jsonEncode(summaryResult['summary_bullets'] ?? [])
        ..newWorldFactsJson =
            jsonEncode(summaryResult['new_world_facts'] ?? [])
        ..characterGrowthNote =
            summaryResult['character_growth'] as String?
        ..cliffhanger = summaryResult['cliffhanger'] as String?
        ..newThreadsJson =
            jsonEncode(summaryResult['new_unresolved_threads'] ?? [])
        ..resolvedThreadsJson =
            jsonEncode(summaryResult['resolved_threads'] ?? [])
        ..fullChapterText = chapterText;

      await saveChapterMemory(memory);

      // Step 3: Update ChronicleLocal
      final stateUpdate = (summaryResult['character_state_update']
              as Map<String, dynamic>?) ??
          {};
      await updateChronicleAfterChapter(
        chronicleId: chronicleId,
        memory: memory,
        characterStateUpdate: stateUpdate,
        lastChapterEnding: lastChapterEnding,
        choiceMade: choiceMadeToStart,
      );

      // Step 4: Arc compression every 5 chapters
      final newChapterCount = chronicle.chapterCount + 1;
      if (newChapterCount % 5 == 0) {
        final arcNumber = newChapterCount ~/ 5;
        final chapterStart = (arcNumber - 1) * 5 + 1;
        final chapterEnd = arcNumber * 5;
        final allMemories = await getChapterMemories(chronicleId);
        final arcMemories = allMemories
            .where((m) =>
                m.chapterNumber >= chapterStart &&
                m.chapterNumber <= chapterEnd)
            .toList();

        if (arcMemories.length == 5) {
          final compressResult = await callCompressArc(
            arcNumber: arcNumber,
            chapterStart: chapterStart,
            chapterEnd: chapterEnd,
            chapterSummaries: arcMemories
                .map((m) => {
                      'summary_bullets':
                          _decodeStringList(m.summaryBulletsJson),
                    })
                .toList(),
            characterName: characterName,
          );
          final arcSummary =
              compressResult['arc_summary'] as String? ?? '';
          if (arcSummary.isNotEmpty) {
            await appendArcSummary(
                chronicleId: chronicleId, arcSummary: arcSummary);
          }
        }
      }
    } catch (e) {
      // Swallow errors so the UI is never blocked
      // ignore: avoid_print
      print('[ChronicleService] handleChapterComplete error: $e');
    }
  }

  // -------------------------------------------------------------------------
  // PRIVATE HELPERS
  // -------------------------------------------------------------------------

  static List<String> _decodeStringList(String? json) {
    if (json == null || json.isEmpty) return [];
    try {
      final decoded = jsonDecode(json);
      if (decoded is List) return decoded.cast<String>();
    } catch (_) {}
    return [];
  }

  static List<Map<String, dynamic>> _decodeMemoryList(String? json) {
    if (json == null || json.isEmpty) return [];
    try {
      final decoded = jsonDecode(json);
      if (decoded is List) {
        return decoded.whereType<Map<String, dynamic>>().toList();
      }
    } catch (_) {}
    return [];
  }

  static Map<String, dynamic> _decodeMap(String? json) {
    if (json == null || json.isEmpty) return {};
    try {
      final decoded = jsonDecode(json);
      if (decoded is Map<String, dynamic>) return decoded;
    } catch (_) {}
    return {};
  }
}
```

**Test condition**: `flutter analyze lib/services/chronicle_service.dart` exits with 0 errors. The method `ChronicleService.buildChapterStartPayload` is callable.

---

## PHASE 4 — Modified `PickAPathAdventureScreen` (Chronicle Mode)

**Prerequisite**: Phase 3 complete.

### Task 4.1 — Add `chronicleId` and `isChronicleMode` parameters to `PickAPathAdventureScreen`

**File**: `/c/dev/story-weaver-app/lib/pick_a_path_adventure_screen.dart`

**Step A — Add import.** Find the import block at the top. After:
```dart
import 'services/interactive_story_service.dart';
```
Add:
```dart
import 'services/chronicle_service.dart';
```

**Step B — Add widget parameters.** Find the constructor parameter block (lines 20–33):
```dart
  const PickAPathAdventureScreen({
    super.key,
    required this.userId,
    required this.character,
    required this.theme,
    this.tone = 'whimsical',
    this.length = 'medium',
    this.interests,
    this.mustInclude,
    this.avoid,
    this.existingStoryId, // For resuming stories
    this.lifeChallenge,
    this.personalitySliders,
  });
```

Replace with:
```dart
  const PickAPathAdventureScreen({
    super.key,
    required this.userId,
    required this.character,
    required this.theme,
    this.tone = 'whimsical',
    this.length = 'medium',
    this.interests,
    this.mustInclude,
    this.avoid,
    this.existingStoryId, // For resuming stories
    this.lifeChallenge,
    this.personalitySliders,
    this.chronicleId, // Living Story Chronicle ID (null = normal story)
  });
```

**Step C — Add field declarations.** Find the final fields block (lines 43–45):
```dart
  final String? lifeChallenge;
  final Map<String, int>? personalitySliders;
```

Replace with:
```dart
  final String? lifeChallenge;
  final Map<String, int>? personalitySliders;
  final String? chronicleId;
```

**Step D — Add convenience getter on the state class.** Find:
```dart
  String? _errorMessage;
  Future<void> Function()? _retryAction;
```

Before that line, add:
```dart
  // Accumulated text for the current chapter (used for Chronicle summarization)
  final StringBuffer _chapterTextBuffer = StringBuffer();

  bool get _isChronicleMode => widget.chronicleId != null;
```

**Step E — Accumulate segment text.** In `_startNewStory()`, find:
```dart
      setState(() {
        _storyId = response.storyId;
        _storyTitle = response.title;
        _currentSegment = response.segment;
        _inventory = response.inventory;
        _state = response.state;
        _isCompleted = response.isCompleted;
        _isLoading = false;
      });
```

After the closing `});`, add:
```dart
      _chapterTextBuffer.write(_currentSegment?.content ?? '');
```

In `_handleChoiceSelected()`, find the inner setState block that sets `_currentSegment`:
```dart
      setState(() {
        _currentSegment = response.segment;
        _inventory = response.inventory;
        _state = response.state;
        _isCompleted = response.isCompleted;
        _isContinuing = false;
      });
```

After the closing `});`, add:
```dart
      _chapterTextBuffer.write('\n\n[Choice: ${choice.text}]\n\n');
      _chapterTextBuffer.write(_currentSegment?.content ?? '');
```

Similarly in `_handleCustomChoice()`, find the same setState block and after it add:
```dart
      _chapterTextBuffer.write('\n\n[Choice: $text]\n\n');
      _chapterTextBuffer.write(_currentSegment?.content ?? '');
```

And in `_handleContinue()`, after its setState block add:
```dart
      _chapterTextBuffer.write('\n\n');
      _chapterTextBuffer.write(_currentSegment?.content ?? '');
```

**Step F — Modify `_startNewStory` to inject chronicle_context when in chronicle mode.** Find the existing call inside `_startNewStory`:
```dart
      final response = await _storyService.startInteractiveStory(
        userId: widget.userId,
        characterId: widget.character.id,
        theme: widget.theme,
        tone: widget.tone,
        length: widget.length,
        age: widget.character.age,
        interests: widget.interests,
        mustInclude: widget.mustInclude,
        avoid: widget.avoid,
        lifeChallenge: widget.lifeChallenge,
        personalitySliders: widget.personalitySliders,
      );
```

Replace with:
```dart
      Map<String, dynamic>? chronicleContext;
      if (_isChronicleMode) {
        chronicleContext = await ChronicleService.buildChapterStartPayload(
            widget.chronicleId!);
      }

      final response = await _storyService.startInteractiveStory(
        userId: widget.userId,
        characterId: widget.character.id,
        theme: widget.theme,
        tone: widget.tone,
        length: widget.length,
        age: widget.character.age,
        interests: widget.interests,
        mustInclude: widget.mustInclude,
        avoid: widget.avoid,
        lifeChallenge: widget.lifeChallenge,
        personalitySliders: widget.personalitySliders,
        chronicleContext: chronicleContext,
      );
```

**Step G — After chapter completion, trigger background summarization.** Find the `if (_isCompleted)` block inside `_handleChoiceSelected` (around line 237):
```dart
      if (_isCompleted) {
        unawaited(
          InteractiveStoryAnalytics.trackStorySaved(
            characterId: widget.character.id,
            theme: widget.theme,
            choiceCount: _currentSegment?.segmentNumber ?? 0,
            segmentCount: _currentSegment?.segmentNumber ?? 0,
            wordCount: _currentSegment?.content.split(' ').length ?? 0,
          ),
        );
      }
```

Replace with:
```dart
      if (_isCompleted) {
        unawaited(
          InteractiveStoryAnalytics.trackStorySaved(
            characterId: widget.character.id,
            theme: widget.theme,
            choiceCount: _currentSegment?.segmentNumber ?? 0,
            segmentCount: _currentSegment?.segmentNumber ?? 0,
            wordCount: _currentSegment?.content.split(' ').length ?? 0,
          ),
        );
        if (_isChronicleMode) {
          _triggerChapterSummarization(choice.text);
        }
      }
```

Apply the same pattern to the `if (_isCompleted)` blocks in `_handleCustomChoice` (use `text` as the choice string) and `_handleContinue` (use `''` as the choice string).

**Step H — Add `_triggerChapterSummarization` method.** Add this new method to the state class, anywhere before `build`:

```dart
  void _triggerChapterSummarization(String choiceMadeText) {
    if (!_isChronicleMode || widget.chronicleId == null) return;

    // Extract last 2 sentences from chapter text as the "ending"
    final fullText = _chapterTextBuffer.toString();
    final sentences = fullText
        .split(RegExp(r'(?<=[.!?])\s+'))
        .where((s) => s.trim().isNotEmpty)
        .toList();
    final lastTwo = sentences.length >= 2
        ? sentences.sublist(sentences.length - 2).join(' ')
        : (sentences.isNotEmpty ? sentences.last : '');

    // Determine chapter number: chronicle.chapterCount + 1
    // We use chapterCount from the chronicle; the service will increment after
    unawaited(
      ChronicleService.getChronicle(widget.chronicleId!).then((chronicle) {
        final chapterNumber = (chronicle?.chapterCount ?? 0) + 1;
        unawaited(
          ChronicleService.handleChapterComplete(
            chronicleId: widget.chronicleId!,
            chapterNumber: chapterNumber,
            chapterText: fullText,
            characterName: widget.character.name,
            lastChapterEnding: lastTwo,
            choiceMadeToStart: choiceMadeText,
          ),
        );
      }),
    );
  }
```

**Step I — Update `_buildCompletionSection` to show a "Next Chapter" button when in chronicle mode.** Find `_buildCompletionSection`:
```dart
  Widget _buildCompletionSection() {
    return Column(
      children: [
        const Icon(
          Icons.auto_awesome,
          size: 64,
          color: Colors.amber,
        ),
        const SizedBox(height: 16),
        const Text(
          'Adventure Complete!',
          ...
        ),
        const SizedBox(height: 24),
        if (!_storySaved)
          AppButton.primary(
            label: 'Save to Library',
            onPressed: _isSaving ? null : _saveStory,
          ),
        if (_storySaved)
          const Text(
            '✓ Saved to your library!',
            ...
          ),
      ],
    );
  }
```

Replace the `return Column(...)` body as follows — find the exact `children: [` block and replace its full content with:

```dart
        const Icon(
          Icons.auto_awesome,
          size: 64,
          color: Colors.amber,
        ),
        const SizedBox(height: 16),
        Text(
          _isChronicleMode ? 'Chapter Complete!' : 'Adventure Complete!',
          style: const TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
          ),
          textAlign: TextAlign.center,
        ),
        if (_isChronicleMode && _currentSegment != null) ...[
          const SizedBox(height: 12),
          Text(
            _currentSegment!.content.length > 200
                ? '${_currentSegment!.content.substring(0, 200)}...'
                : _currentSegment!.content,
            style: const TextStyle(fontSize: 14, fontStyle: FontStyle.italic),
            textAlign: TextAlign.center,
          ),
        ],
        const SizedBox(height: 24),
        if (_isChronicleMode)
          AppButton.primary(
            label: 'Continue Chronicle',
            icon: Icons.menu_book,
            onPressed: () {
              // Pop back to ChronicleScreen; it will offer "Start Next Chapter"
              Navigator.of(context).pop('chapter_complete');
            },
          ),
        const SizedBox(height: 12),
        if (!_storySaved)
          AppButton.primary(
            label: 'Save to Library',
            onPressed: _isSaving ? null : _saveStory,
          ),
        if (_storySaved)
          const Text(
            '✓ Saved to your library!',
            style: TextStyle(
              color: Colors.green,
              fontWeight: FontWeight.bold,
            ),
          ),
```

**Step J — Update `startInteractiveStory` in `InteractiveStoryService` to accept and forward `chronicleContext`.** Find in `/c/dev/story-weaver-app/lib/services/interactive_story_service.dart`:

```dart
  Future<StartStoryResponse> startInteractiveStory({
    required String userId,
    required String characterId,
    required String theme,
    String tone = 'whimsical',
    String length = 'medium',
    int? age,
    List<String>? interests,
    List<String>? mustInclude,
    List<String>? avoid,
    String? lifeChallenge,
    Map<String, int>? personalitySliders,
  }) async {
```

Replace with:
```dart
  Future<StartStoryResponse> startInteractiveStory({
    required String userId,
    required String characterId,
    required String theme,
    String tone = 'whimsical',
    String length = 'medium',
    int? age,
    List<String>? interests,
    List<String>? mustInclude,
    List<String>? avoid,
    String? lifeChallenge,
    Map<String, int>? personalitySliders,
    Map<String, dynamic>? chronicleContext,
  }) async {
```

Then find the `body: jsonEncode({...})` block in `startInteractiveStory` and add `chronicleContext` to it:

Find:
```dart
            if (personalitySliders != null) 'personality_sliders': personalitySliders,
```

Replace with:
```dart
            if (personalitySliders != null) 'personality_sliders': personalitySliders,
            if (chronicleContext != null) 'chronicle_context': chronicleContext,
```

**Test condition**: `flutter analyze lib/pick_a_path_adventure_screen.dart lib/services/interactive_story_service.dart` exits with 0 errors. Run the app in debug mode and navigate to a Pick-A-Path adventure to confirm no runtime crash at start.

---

## PHASE 5 — ChronicleScreen UI

**Prerequisite**: Phase 3 complete.

### Task 5.1 — Create `lib/screens/chronicle_screen.dart`

**File**: `/c/dev/story-weaver-app/lib/screens/chronicle_screen.dart`
**Action**: Create with exact contents below.

```dart
import 'dart:convert';

import 'package:flutter/material.dart';

import '../models.dart';
import '../models/local/chapter_memory_local.dart';
import '../models/local/chronicle_local.dart';
import '../pick_a_path_adventure_screen.dart';
import '../services/chronicle_service.dart';
import '../theme/app_theme.dart';
import '../widgets/app_button.dart';

/// Displays one Living Story Chronicle: the chapter log and a "Start Next Chapter" button.
class ChronicleScreen extends StatefulWidget {
  const ChronicleScreen({
    super.key,
    required this.chronicle,
    required this.character,
    required this.userId,
  });

  final ChronicleLocal chronicle;
  final Character character;
  final String userId;

  @override
  State<ChronicleScreen> createState() => _ChronicleScreenState();
}

class _ChronicleScreenState extends State<ChronicleScreen> {
  late ChronicleLocal _chronicle;
  List<ChapterMemoryLocal> _memories = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _chronicle = widget.chronicle;
    _loadData();
  }

  Future<void> _loadData() async {
    final memories =
        await ChronicleService.getChapterMemories(_chronicle.chronicleId);
    final fresh =
        await ChronicleService.getChronicle(_chronicle.chronicleId);
    if (!mounted) return;
    setState(() {
      _memories = memories;
      if (fresh != null) _chronicle = fresh;
      _loading = false;
    });
  }

  Future<void> _startNextChapter() async {
    final result = await Navigator.of(context).push<String>(
      MaterialPageRoute(
        builder: (_) => PickAPathAdventureScreen(
          userId: widget.userId,
          character: widget.character,
          theme: _chronicle.genre,
          tone: 'whimsical',
          length: 'medium',
          chronicleId: _chronicle.chronicleId,
        ),
      ),
    );

    // Refresh after returning from the chapter
    if (mounted) {
      await _loadData();
      if (result == 'chapter_complete' && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Chapter saved to your Chronicle!'),
            duration: Duration(seconds: 3),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_chronicle.title),
        backgroundColor: Colors.deepPurple,
        foregroundColor: Colors.white,
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: AppGradients.magicalBackground,
        ),
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : _buildBody(),
      ),
    );
  }

  Widget _buildBody() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildHeader(),
          const SizedBox(height: 20),
          AppButton.primary(
            label: _chronicle.chapterCount == 0
                ? 'Begin Chapter 1'
                : 'Start Chapter ${_chronicle.chapterCount + 1}',
            icon: Icons.menu_book,
            onPressed: _startNextChapter,
          ),
          const SizedBox(height: 24),
          if (_memories.isNotEmpty) _buildChapterLog(),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              _chronicle.characterName,
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              '${_chronicle.chapterCount} chapter${_chronicle.chapterCount == 1 ? '' : 's'} completed',
              style: TextStyle(color: Colors.grey[600]),
            ),
            if (_chronicle.lastChapterEnding != null) ...[
              const SizedBox(height: 8),
              Text(
                '"${_chronicle.lastChapterEnding}"',
                style: const TextStyle(
                  fontStyle: FontStyle.italic,
                  fontSize: 14,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildChapterLog() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Chapter Log',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        ..._memories.reversed.map((mem) => _buildMemoryCard(mem)),
      ],
    );
  }

  Widget _buildMemoryCard(ChapterMemoryLocal mem) {
    final bullets = _decodeStringList(mem.summaryBulletsJson);
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ExpansionTile(
        title: Text(
          'Chapter ${mem.chapterNumber}',
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: mem.cliffhanger != null
            ? Text(
                mem.cliffhanger!,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontStyle: FontStyle.italic, fontSize: 12),
              )
            : null,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (mem.choiceMadeToStartChapter != null) ...[
                  Text(
                    'Started with: "${mem.choiceMadeToStartChapter}"',
                    style: TextStyle(
                        color: Colors.deepPurple[700], fontSize: 13),
                  ),
                  const SizedBox(height: 8),
                ],
                ...bullets.map(
                  (b) => Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('• ',
                            style: TextStyle(fontWeight: FontWeight.bold)),
                        Expanded(child: Text(b, style: const TextStyle(fontSize: 14))),
                      ],
                    ),
                  ),
                ),
                if (mem.characterGrowthNote != null) ...[
                  const SizedBox(height: 8),
                  Text(
                    'Growth: ${mem.characterGrowthNote}',
                    style: TextStyle(
                        color: Colors.green[700],
                        fontSize: 13,
                        fontStyle: FontStyle.italic),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  static List<String> _decodeStringList(String? jsonStr) {
    if (jsonStr == null || jsonStr.isEmpty) return [];
    try {
      final decoded = jsonDecode(jsonStr);
      if (decoded is List) return decoded.cast<String>();
    } catch (_) {}
    return [];
  }
}
```

**Test condition**: `flutter analyze lib/screens/chronicle_screen.dart` exits with 0 errors.

---

### Task 5.2 — Create `lib/screens/chronicles_list_screen.dart`

**File**: `/c/dev/story-weaver-app/lib/screens/chronicles_list_screen.dart`
**Action**: Create with exact contents below.

```dart
import 'package:flutter/material.dart';

import '../models.dart';
import '../models/local/chronicle_local.dart';
import '../services/chronicle_service.dart';
import '../theme/app_theme.dart';
import '../widgets/app_button.dart';
import 'chronicle_screen.dart';

/// Lists all Living Story Chronicles for the current character and lets the
/// user create a new one or continue an existing one.
class ChroniclesListScreen extends StatefulWidget {
  const ChroniclesListScreen({
    super.key,
    required this.character,
    required this.userId,
  });

  final Character character;
  final String userId;

  @override
  State<ChroniclesListScreen> createState() => _ChroniclesListScreenState();
}

class _ChroniclesListScreenState extends State<ChroniclesListScreen> {
  List<ChronicleLocal> _chronicles = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadChronicles();
  }

  Future<void> _loadChronicles() async {
    final list = await ChronicleService.getChroniclesForCharacter(
        widget.character.id);
    if (!mounted) return;
    setState(() {
      _chronicles = list;
      _loading = false;
    });
  }

  Future<void> _createNewChronicle() async {
    // Ask user for a chronicle title and genre
    final result = await showDialog<Map<String, String>>(
      context: context,
      builder: (ctx) => _NewChronicleDialog(
          characterName: widget.character.name),
    );
    if (result == null) return;

    final chronicle = await ChronicleService.createChronicle(
      characterId: widget.character.id,
      characterName: widget.character.name,
      characterAge: widget.character.age,
      title: result['title']!,
      genre: result['genre']!,
    );

    if (!mounted) return;
    await _navigateToChronicle(chronicle);
  }

  Future<void> _navigateToChronicle(ChronicleLocal chronicle) async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ChronicleScreen(
          chronicle: chronicle,
          character: widget.character,
          userId: widget.userId,
        ),
      ),
    );
    if (mounted) await _loadChronicles();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('${widget.character.name}\'s Chronicles'),
        backgroundColor: Colors.deepPurple,
        foregroundColor: Colors.white,
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: AppGradients.magicalBackground,
        ),
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : _buildBody(),
      ),
    );
  }

  Widget _buildBody() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AppButton.primary(
            label: 'Start a New Chronicle',
            icon: Icons.add,
            onPressed: _createNewChronicle,
          ),
          const SizedBox(height: 24),
          if (_chronicles.isEmpty)
            const Center(
              child: Text(
                'No chronicles yet.\nStart one above to begin an endless adventure!',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 16, color: Colors.white70),
              ),
            )
          else
            Expanded(
              child: ListView.builder(
                itemCount: _chronicles.length,
                itemBuilder: (ctx, i) {
                  final c = _chronicles[i];
                  return Card(
                    margin: const EdgeInsets.only(bottom: 12),
                    child: ListTile(
                      leading: const Icon(Icons.menu_book,
                          color: Colors.deepPurple),
                      title: Text(c.title,
                          style: const TextStyle(fontWeight: FontWeight.bold)),
                      subtitle: Text(
                        '${c.chapterCount} chapter${c.chapterCount == 1 ? '' : 's'} • ${c.genre}',
                      ),
                      trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                      onTap: () => _navigateToChronicle(c),
                    ),
                  );
                },
              ),
            ),
        ],
      ),
    );
  }
}

/// Simple dialog to collect chronicle title and genre.
class _NewChronicleDialog extends StatefulWidget {
  const _NewChronicleDialog({required this.characterName});
  final String characterName;

  @override
  State<_NewChronicleDialog> createState() => _NewChronicleDialogState();
}

class _NewChronicleDialogState extends State<_NewChronicleDialog> {
  final _titleController = TextEditingController();
  String _genre = 'Fantasy';

  static const _genres = [
    'Fantasy',
    'Sci-Fi',
    'Mystery',
    'Adventure',
    'Magic',
  ];

  @override
  void initState() {
    super.initState();
    _titleController.text = '${widget.characterName}\'s Chronicle';
  }

  @override
  void dispose() {
    _titleController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('New Chronicle'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _titleController,
            decoration: const InputDecoration(labelText: 'Title'),
            maxLength: 60,
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            value: _genre,
            decoration: const InputDecoration(labelText: 'Genre'),
            items: _genres
                .map((g) =>
                    DropdownMenuItem(value: g, child: Text(g)))
                .toList(),
            onChanged: (v) => setState(() => _genre = v ?? 'Fantasy'),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: () {
            final title = _titleController.text.trim();
            if (title.isEmpty) return;
            Navigator.of(context).pop({'title': title, 'genre': _genre});
          },
          child: const Text('Create'),
        ),
      ],
    );
  }
}
```

**Test condition**: `flutter analyze lib/screens/chronicles_list_screen.dart lib/screens/chronicle_screen.dart` exits with 0 errors.

---

## PHASE 6 — Home/Library Integration (Chronicles Shelf)

**Prerequisite**: Phases 4 and 5 complete.

### Task 6.1 — Add "My Chronicles" to the overflow menu in `lib/main_story.dart`

**File**: `/c/dev/story-weaver-app/lib/main_story.dart`

**Step A — Add import.** Find the imports block. After:
```dart
import 'saved_stories_screen.dart';
```
Add:
```dart
import 'screens/chronicles_list_screen.dart';
```

**Step B — Add the menu item.** Find the popup menu items block. Find this exact entry:
```dart
              const PopupMenuItem<String>(
                value: 'my_stories',
                child: ListTile(
                  leading: Icon(Icons.book),
                  title: Text('My Stories'),
                  contentPadding: EdgeInsets.zero,
                ),
              ),
```

After it, add:
```dart
              const PopupMenuItem<String>(
                value: 'my_chronicles',
                child: ListTile(
                  leading: Icon(Icons.menu_book),
                  title: Text('My Chronicles'),
                  contentPadding: EdgeInsets.zero,
                ),
              ),
```

**Step C — Handle the menu selection.** Find the `onSelected` switch block. Find:
```dart
                case 'my_stories':
                  Navigator.of(context).push(MaterialPageRoute(
                      builder: (_) => const SavedStoriesScreen()));
                  break;
```

After it, add:
```dart
                case 'my_chronicles':
                  if (_selectedCharacter != null) {
                    Navigator.of(context).push(MaterialPageRoute(
                        builder: (_) => ChroniclesListScreen(
                              character: _selectedCharacter!,
                              userId: _userId ?? '',
                            )));
                  } else {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                          content: Text(
                              'Select a character first to view Chronicles.')),
                    );
                  }
                  break;
```

**Test condition**: `flutter analyze lib/main_story.dart` exits with 0 errors. Hot-reload the app, open the overflow menu (three-dot icon), and confirm "My Chronicles" appears. Tapping it with no character selected shows the snackbar. Tapping it with a character navigates to `ChroniclesListScreen`.

---

## PHASE 6 — Age Gate

### Task 6.2 — Gate the Chronicles feature to ages 11+

**File**: `/c/dev/story-weaver-app/lib/main_story.dart`

In the `case 'my_chronicles':` block added in Task 6.1, wrap the navigation:

Find exactly:
```dart
                case 'my_chronicles':
                  if (_selectedCharacter != null) {
                    Navigator.of(context).push(MaterialPageRoute(
                        builder: (_) => ChroniclesListScreen(
                              character: _selectedCharacter!,
                              userId: _userId ?? '',
                            )));
                  } else {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                          content: Text(
                              'Select a character first to view Chronicles.')),
                    );
                  }
                  break;
```

Replace with:
```dart
                case 'my_chronicles':
                  if (_selectedCharacter == null) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                          content: Text(
                              'Select a character first to view Chronicles.')),
                    );
                  } else if (_selectedCharacter!.age < 11) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                          content: Text(
                              'Living Chronicles are for readers aged 11 and up.')),
                    );
                  } else {
                    Navigator.of(context).push(MaterialPageRoute(
                        builder: (_) => ChroniclesListScreen(
                              character: _selectedCharacter!,
                              userId: _userId ?? '',
                            )));
                  }
                  break;
```

**Test condition**: With a character aged 10 or younger selected, tapping "My Chronicles" shows the age snackbar. With a character aged 11+ it opens `ChroniclesListScreen`.

---

## END-TO-END MANUAL TEST WALKTHROUGH

Perform these steps in order to verify the complete feature works.

### Prerequisites
- Backend running locally (`python backend/run.py`). Watch logs in terminal.
- Flutter app running in debug mode on an Android emulator or device.
- At least one existing character with age 12.

---

**Step 1 — Verify backend endpoints exist.**
Run in a terminal:
```
curl -X POST http://localhost:5000/chronicle/summarize-chapter \
  -H "Content-Type: application/json" \
  -d '{"chapter_number": 1, "chapter_text": "Test chapter text.", "character_name": "Alex"}'
```
Expected: HTTP 401 (auth required) or HTTP 200 with a JSON response containing `summary_bullets`. A 404 means the blueprint was not registered — recheck Task 1.3.

**Step 2 — Verify chronicle_context flows to prompt.**
POST to `/generate-interactive-story` with a valid Bearer token and body:
```json
{
  "character_id": "<a valid character id>",
  "theme": "Fantasy",
  "tone": "whimsical",
  "length": "short",
  "chronicle_context": {
    "chapter_count": 1,
    "character_state": "brave, has a silver compass",
    "world_facts": ["The Moonwood Forest is alive"],
    "arc_summaries": [],
    "recent_memories": [{
      "chapter_number": 1,
      "summary_bullets": ["Found a glowing door", "Met the Fox spirit"],
      "cliffhanger": "The door creaked open to reveal blinding light."
    }],
    "unresolved_threads": ["Who stole the Storm Gem?"],
    "last_chapter_ending": "The door creaked open to reveal blinding light."
  }
}
```
Expected: HTTP 200 with a segment whose `content` continues from the context. Confirm "The Moonwood Forest" or similar detail appears. Watch backend logs — you should see the LIVING CHRONICLE block in the Gemini prompt (add `logger.debug(prompt)` temporarily to `create_story` in the service if needed to verify).

**Step 3 — Create a new Chronicle in the app.**
1. Open the app. Select or create a character aged 12.
2. Open the overflow menu (three-dot icon top-right).
3. Tap "My Chronicles".
4. Confirm `ChroniclesListScreen` opens and shows "No chronicles yet."
5. Tap "Start a New Chronicle".
6. In the dialog, set title to "Alex's Great Journey" and genre to "Fantasy". Tap Create.
7. Confirm you arrive at `ChronicleScreen` showing "Alex's Great Journey", "0 chapters completed", and a "Begin Chapter 1" button.

**Step 4 — Play Chapter 1.**
1. Tap "Begin Chapter 1".
2. Confirm `PickAPathAdventureScreen` opens (no `chronicleId`-related crash).
3. Make 2–3 choices to advance the story.
4. Make choices until the story completes (`_isCompleted` = true).
5. Confirm the completion section shows "Chapter Complete!" (not "Adventure Complete!").
6. Confirm a "Continue Chronicle" button is present.

**Step 5 — Verify background summarization.**
1. After the story completes but before tapping "Continue Chronicle", wait 5–10 seconds.
2. Check the backend logs for `Chapter summarization` log lines (from `chronicle_routes.py`).
3. Tap "Continue Chronicle". You return to `ChronicleScreen`.
4. Confirm `ChronicleScreen` now shows "1 chapter completed".
5. Confirm `ChronicleScreen` shows a chapter log entry for Chapter 1 with bullet points.
6. Confirm `lastChapterEnding` is shown on the header card.

**Step 6 — Play Chapter 2 with context injection.**
1. From `ChronicleScreen`, tap "Start Chapter 2".
2. In the backend logs, confirm the Gemini prompt contains "LIVING CHRONICLE (Chapters 1-1 completed".
3. Confirm the story text references the character's prior adventure (some detail from Chapter 1 summary).
4. Make choices and complete the chapter.
5. Confirm `ChronicleScreen` shows "2 chapters completed" after returning.

**Step 7 — Verify arc compression at Chapter 5.**
This step requires completing 5 chapters. For speed, use unit-testing or direct API calls to simulate:
- Call `POST /chronicle/compress-arc` with `arc_number=1`, `chapter_start=1`, `chapter_end=5`, and 5 fake `chapter_summaries` each with `summary_bullets`.
- Expected: HTTP 200 with `{"arc_summary": "Arc 1 (Ch 1-5): ..."}`.
In the app, after naturally completing 5 chapters, confirm the backend logs show "arc compression" and the chronicle's `arcSummariesJson` (viewable via Isar inspector) contains one entry.

**Step 8 — Age gate test.**
1. Switch to or create a character aged 10.
2. Open the overflow menu → "My Chronicles".
3. Confirm the snackbar "Living Chronicles are for readers aged 11 and up." appears and no navigation occurs.

**Step 9 — Confirm no-character guard.**
1. Deselect the current character (if the UI supports it) or ensure `_selectedCharacter` is null.
2. Open overflow → "My Chronicles".
3. Confirm "Select a character first to view Chronicles." snackbar appears.

---

## Critical Files for Implementation

- `/c/dev/story-weaver-app/backend/services/interactive_adventure_prompt_builder.py` - Core logic to modify: add `chronicle_context` parameter and inject the LIVING CHRONICLE block into the opening prompt
- `/c/dev/story-weaver-app/backend/app.py` - Blueprint registration: add import and `app.register_blueprint(chronicle_bp)` for the two new chronicle endpoints
- `/c/dev/story-weaver-app/lib/services/isar_service_io.dart` - Schema registration: the two new Isar collections (`ChronicleLocalSchema`, `ChapterMemoryLocalSchema`) must be added here before `build_runner` can generate the `.g.dart` files
- `/c/dev/story-weaver-app/lib/pick_a_path_adventure_screen.dart` - Chronicle mode integration: accepts `chronicleId`, accumulates chapter text, calls `ChronicleService.handleChapterComplete` on completion, and shows "Chapter Complete" UI
- `/c/dev/story-weaver-app/lib/main_story.dart` - Library entry point: adds "My Chronicles" to the overflow menu with age gate and character guard, navigating to `ChroniclesListScreen`

---

## PHASE 7 — All-Ages Chronicle Adaptation

**Purpose:** Living Story Chronicles work for ALL age bands, not just 11+. Each band gets age-appropriate input, pacing, TTS, and visual design. The backend compression and memory architecture is identical — only the presentation layer changes.

**Dependency:** Phases 1–6 must be complete before Phase 7.

**Age-band reference:**
- Sprout: ages 3–5 (`AgeBand.sprout`)
- Explorer: ages 5–7 (`AgeBand.explorer`)
- Adventurer: ages 8–10 (`AgeBand.adventurer`)
- Creator: ages 11+ (`AgeBand.creator`) — already fully handled by Phases 1–6

---

### Task 7.1 — Remove Age Gate from ChroniclesListScreen

**File:** `lib/main_story.dart` (the overflow menu tap handler added in Phase 6)

**What to find:** The block added in Phase 6 that checks `character.age < 11` and shows a snackbar. It looks like:
```dart
if (character.age < 11) {
  ScaffoldMessenger.of(context).showSnackBar(
    const SnackBar(content: Text('Living Chronicles are for readers aged 11 and up.')),
  );
} else {
  Navigator.of(context).push(...ChroniclesListScreen...);
}
```

**Exactly what to change:**

Remove the age check. Replace with just the character-null guard:
```dart
if (_selectedCharacter == null) {
  ScaffoldMessenger.of(context).showSnackBar(
    const SnackBar(content: Text('Select a character first to view Chronicles.')),
  );
} else {
  Navigator.of(context).push(MaterialPageRoute(
    builder: (_) => ChroniclesListScreen(
      character: _selectedCharacter!,
      userId: _userId ?? '',
    ),
  ));
}
```

Also update the **End-to-End Test Step 8** (in the test walkthrough above) which says to verify the age snackbar — that test step is now obsolete. Replace it with: "Age 5 character — tapping My Chronicles opens ChroniclesListScreen without a snackbar."

**Test condition:** Age 5 character selected → "My Chronicles" opens `ChroniclesListScreen`. Age 12 → same. No character selected → snackbar "Select a character first".

---

### Task 7.2 — Session Length Limit by Age Band

**File:** `lib/pick_a_path_adventure_screen.dart`

**What to find:** The `_targetSegmentCount` getter at line ~98, and the field declarations around line 60–79.

**Exactly what to change:**

Step 1 — Add two fields alongside the existing state fields (after `bool _storySaved = false;`):
```dart
int _segmentsThisSession = 0;
bool _sessionLimitReached = false;
```

Step 2 — Add a new getter after `_targetSegmentCount`:
```dart
/// Max segments to show per sitting, based on age. Chronicle mode only.
/// Outside chronicle mode there is no limit.
int get _maxSegmentsPerSession {
  if (!widget.isChronicleMode) return 9999;
  final age = widget.character.age;
  if (age <= 5)  return 3;   // ~5 minutes
  if (age <= 7)  return 5;   // ~8 minutes
  if (age <= 10) return 8;   // ~15 minutes
  return 9999;               // Creator: no limit
}
```

Step 3 — In every method that advances to a new segment (`_handleChoiceSelected`, `_handleCustomChoice`, `_handleContinue`), find the `setState` block that sets `_currentSegment = response.segment` and add after it:
```dart
_segmentsThisSession++;
if (_segmentsThisSession >= _maxSegmentsPerSession) {
  setState(() => _sessionLimitReached = true);
}
```

Step 4 — In `_buildStoryContent()` (line ~490), update the if/else chain:
```dart
if (_sessionLimitReached && widget.isChronicleMode)
  _buildSessionBreakSection()
else if (_isCompleted)
  _buildCompletionSection()
else if (_currentSegment!.requiresChoice)
  _buildChoicesSection()
else if (_currentSegment!.isContinuation)
  _buildContinueSection(),
```

Step 5 — Add the session break widget (place after `_buildCompletionSection()`):
```dart
Widget _buildSessionBreakSection() {
  final age = widget.character.age;
  final isSprout = age <= 5;
  return Column(
    children: [
      const SizedBox(height: 16),
      Icon(
        isSprout ? Icons.bedtime_rounded : Icons.bookmark_rounded,
        size: isSprout ? 72 : 56,
        color: Colors.amber,
      ),
      const SizedBox(height: 12),
      Text(
        isSprout
            ? 'Great adventuring! Time for a rest! 🌙'
            : age <= 7
                ? 'Amazing! Your story is saved! Come back for more!'
                : 'Good stopping point. Your chronicle is saved.',
        style: TextStyle(
          fontSize: isSprout ? 22 : 18,
          fontWeight: FontWeight.bold,
        ),
        textAlign: TextAlign.center,
      ),
      const SizedBox(height: 8),
      Text(
        isSprout
            ? 'Your story will be waiting for you!'
            : 'Continue whenever you\'re ready.',
        style: TextStyle(fontSize: isSprout ? 18 : 14, color: Colors.grey[600]),
        textAlign: TextAlign.center,
      ),
      const SizedBox(height: 24),
      AppButton.primary(
        label: isSprout ? 'All done! 🌟' : 'Save & finish for now',
        onPressed: () {
          // Trigger the chronicle chapter-complete handler, then pop
          widget.onChapterComplete?.call(
            _accumulatedChapterText,
            _currentSegment?.content ?? '',
          );
          Navigator.of(context).pop();
        },
      ),
    ],
  );
}
```

**Test condition:** Chronicle mode, age 5 — session break screen appears after 3 segments. Chronicle mode, age 12 — no session limit, story continues until `is_ending: true`. Non-chronicle mode, age 5 — no session limit.

---

### Task 7.3 — Auto-TTS for Ages 3–7

**File:** `lib/pick_a_path_adventure_screen.dart`

**What to find:** The `initState()` method (line ~81) and `dispose()` method.

**Exactly what to change:**

Step 1 — Add import at the top of the file:
```dart
import 'package:flutter_tts/flutter_tts.dart';
```

Step 2 — Add fields after `bool _sessionLimitReached = false;`:
```dart
FlutterTts? _tts;
bool _ttsEnabled = false;
```

Step 3 — In `initState()`, after `super.initState()` and before the existing `if (widget.existingStoryId != null)` block:
```dart
if (widget.character.age <= 7) {
  _initTts();
}
```

Step 4 — Add these two methods after `dispose()`:
```dart
Future<void> _initTts() async {
  _tts = FlutterTts();
  await _tts!.setLanguage('en-US');
  await _tts!.setSpeechRate(widget.character.age <= 5 ? 0.40 : 0.48);
  await _tts!.setPitch(widget.character.age <= 5 ? 1.1 : 1.0);
  if (mounted) setState(() => _ttsEnabled = true);
}

void _speakSegment(String text) {
  if (!_ttsEnabled || _tts == null) return;
  _tts!.stop();
  final clean = text.replaceAll(RegExp(r'\*+'), '').trim();
  _tts!.speak(clean);
}
```

Step 5 — In `dispose()`, add before `super.dispose()`:
```dart
_tts?.stop();
```

Step 6 — After **every** `setState` block that sets `_currentSegment = response.segment` (there are ~5 of these across `_startNewStory`, `_resumeStory`, `_handleChoiceSelected`, `_handleCustomChoice`, `_handleContinue`), add:
```dart
if (_ttsEnabled && _currentSegment != null) {
  _speakSegment(_currentSegment!.content);
}
```

Step 7 — In `_buildSegmentCard()` (line ~503), inside the `AppCard` child `Column`, add a stop button visible only when TTS is active:
```dart
if (_ttsEnabled)
  Align(
    alignment: Alignment.topRight,
    child: IconButton(
      icon: const Icon(Icons.volume_off_rounded, color: Colors.deepPurple),
      tooltip: 'Stop reading',
      onPressed: () => _tts?.stop(),
    ),
  ),
```

**Note:** `flutter_tts` must be in `pubspec.yaml`. If it is not already present (check first with `grep flutter_tts pubspec.yaml`), add `flutter_tts: ^4.0.0` under `dependencies` and run `flutter pub get`.

**Test condition:** Age 5 — TTS reads each segment aloud automatically when it loads. Stop button appears and silences it. Age 12 — no TTS, no button.

---

### Task 7.4 — Age-Adaptive Choice Tiles for Ages 3–7

**File:** `lib/pick_a_path_adventure_screen.dart`

**What to find:** `_buildChoicesSection()` at line ~701.

**Exactly what to change:**

Replace the entire `_buildChoicesSection()` method with a dispatcher, and add three new helper methods. The existing standard layout is extracted into `_buildStandardChoicesSection()` unchanged — just move the existing code into that method name.

```dart
Widget _buildChoicesSection() {
  if (_currentSegment!.choices.isEmpty) {
    return const Center(child: Text('No choices available'));
  }
  return widget.character.age <= 7
      ? _buildYoungChoicesSection()
      : _buildStandardChoicesSection();
}

Widget _buildYoungChoicesSection() {
  final isSprout = widget.character.age <= 5;
  return Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      // Large central mic prompt
      Center(
        child: Column(
          children: [
            Text(
              isSprout ? 'What should happen? 🎙️' : 'Say your choice or tap one!',
              style: TextStyle(
                fontSize: isSprout ? 20 : 17,
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            VoiceMicButton(
              onResult: _handleVoiceResult,
              hint: 'Say what happens next...',
              disabled: _isContinuing,
              size: isSprout ? 72 : 56,
            ),
          ],
        ),
      ),
      const SizedBox(height: 20),
      // Large colored choice tiles
      ..._currentSegment!.choices.asMap().entries.map((entry) {
        final idx = entry.key;
        final choice = entry.value;
        final gradients = [
          [const Color(0xFF7B2FBE), const Color(0xFF9B59B6)],
          [const Color(0xFF1A7A4A), const Color(0xFF27AE60)],
          [const Color(0xFFB7410E), const Color(0xFFE74C3C)],
        ];
        final grad = gradients[idx % gradients.length];
        return Padding(
          padding: const EdgeInsets.only(bottom: 14.0),
          child: GestureDetector(
            onTap: _isContinuing ? null : () => _handleChoiceSelected(choice),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
              decoration: BoxDecoration(
                gradient: LinearGradient(colors: grad),
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: grad[0].withValues(alpha: 0.4),
                    blurRadius: 8,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Text(
                choice.text,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: isSprout ? 18 : 16,
                  fontWeight: FontWeight.w700,
                  height: 1.3,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ),
        );
      }),
      const SizedBox(height: 8),
      _buildYoungSomethingElse(),
      // Parent co-pilot (Sprout only)
      if (isSprout) ...[
        const SizedBox(height: 8),
        TextButton.icon(
          onPressed: _isContinuing ? null : _showParentCopilotSheet,
          icon: const Icon(Icons.family_restroom, color: Colors.orange),
          label: const Text(
            'Grown-up adds to the story...',
            style: TextStyle(color: Colors.orange, fontSize: 14),
          ),
        ),
      ],
    ],
  );
}

Widget _buildYoungSomethingElse() {
  final isSprout = widget.character.age <= 5;
  if (_showCustomInput) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeOut,
      decoration: BoxDecoration(
        border: Border.all(color: Colors.deepPurple.withValues(alpha: 0.4)),
        borderRadius: BorderRadius.circular(16),
        color: Colors.deepPurple.withValues(alpha: 0.05),
      ),
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            _customChoiceController.text,
            style: TextStyle(
              fontSize: isSprout ? 18 : 16,
              fontWeight: FontWeight.w600,
              color: Colors.deepPurple.shade700,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: TextButton(
                  onPressed: () => setState(() {
                    _showCustomInput = false;
                    _customChoiceController.clear();
                  }),
                  child: const Text('Try again'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: ElevatedButton(
                  onPressed: _isContinuing ? null : _handleCustomChoice,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.deepPurple,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: Text(
                    isSprout ? 'Yes! Do that! 🌟' : 'Use this!',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
  return GestureDetector(
    onTap: _isContinuing ? null : () => setState(() => _showCustomInput = true),
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.deepPurple.withValues(alpha: 0.5), width: 2),
        borderRadius: BorderRadius.circular(20),
        color: Colors.deepPurple.withValues(alpha: 0.04),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.mic_rounded, color: Colors.deepPurple, size: 28),
          const SizedBox(width: 10),
          Text(
            isSprout ? 'My own idea! 💡' : 'Something else...',
            style: const TextStyle(
              color: Colors.deepPurple,
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    ),
  );
}

/// Renamed copy of the original _buildChoicesSection — body is unchanged.
Widget _buildStandardChoicesSection() {
    // Safety check: ensure we have choices to display
    if (_currentSegment!.choices.isEmpty) {
      return const Center(
        child: Text('No choices available'),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text(
              'What do you do next?',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(width: 8),
            VoiceMicButton(
              onResult: _handleVoiceResult,
              hint: 'Or say your choice',
              disabled: _isContinuing,
              size: 36,
            ),
          ],
        ),
        const SizedBox(height: 16),
        ..._currentSegment!.choices.asMap().entries.map((entry) {
          final choice = entry.value;
          return Padding(
            padding: const EdgeInsets.only(bottom: 12.0),
            child: AppButton.primary(
              label: choice.text,
              onPressed: _isContinuing ? null : () => _handleChoiceSelected(choice),
            ),
          );
        }),
        // "Something Else" free-text option
        const SizedBox(height: 4),
        if (!_showCustomInput)
          Padding(
            padding: const EdgeInsets.only(bottom: 4.0),
            child: TextButton.icon(
              onPressed: _isContinuing
                  ? null
                  : () => setState(() => _showCustomInput = true),
              icon: const Icon(Icons.auto_awesome, size: 16),
              label: const Text('✨ Do something else...'),
              style: TextButton.styleFrom(
                foregroundColor: Colors.deepPurple,
              ),
            ),
          )
        else
          AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeOut,
            decoration: BoxDecoration(
              border: Border.all(color: Colors.deepPurple.withValues(alpha: 0.4)),
              borderRadius: BorderRadius.circular(12),
              color: Colors.deepPurple.withValues(alpha: 0.05),
            ),
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'What would YOU do?',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: Colors.deepPurple.shade700,
                  ),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _customChoiceController,
                  maxLength: 200,
                  maxLines: 2,
                  autofocus: true,
                  decoration: InputDecoration(
                    hintText: 'Type your own idea...',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    counterStyle: const TextStyle(fontSize: 11),
                  ),
                  onSubmitted: (_) => _handleCustomChoice(),
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: () => setState(() {
                        _showCustomInput = false;
                        _customChoiceController.clear();
                      }),
                      child: const Text('Cancel'),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton.icon(
                      onPressed: _isContinuing ? null : _handleCustomChoice,
                      icon: const Icon(Icons.arrow_forward, size: 16),
                      label: const Text('Let\'s go!'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.deepPurple,
                        foregroundColor: Colors.white,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
      ],
    );
  }
```

**Important:** The `_handleVoiceResult` method already exists and handles both matched and unmatched voice input. For young users, when voice doesn't match a choice, it populates `_customChoiceController.text` and sets `_showCustomInput = true` — which now shows the large confirm card via `_buildYoungSomethingElse()`.

**Test condition:** Age 5 — large colored gradient tiles, central 72px mic button, "My own idea! 💡" tile at bottom. Speaking a non-matching phrase → large confirm card with "Yes! Do that! 🌟". Age 10 — original text button layout, no change.

---

### Task 7.5 — Parent Co-Pilot Bottom Sheet (Sprout Band)

**File:** `lib/pick_a_path_adventure_screen.dart`

**What to find:** Anywhere after `_buildYoungSomethingElse()` — add the new method.

**Exactly what to add:**

```dart
void _showParentCopilotSheet() {
  final controller = TextEditingController();
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: const Color(0xFF1E0538),
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (ctx) => Padding(
      padding: EdgeInsets.only(
        left: 24,
        right: 24,
        top: 24,
        bottom: MediaQuery.of(ctx).viewInsets.bottom + 24,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            '👨‍👧 Add to the story',
            style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          const Text(
            'Type something that happens next — it will appear in the story!',
            style: TextStyle(color: Colors.white60, fontSize: 13),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: controller,
            autofocus: true,
            maxLines: 3,
            style: const TextStyle(color: Colors.white),
            decoration: InputDecoration(
              hintText: 'e.g. "Then Dad appeared with a magic map!"',
              hintStyle: const TextStyle(color: Colors.white38),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: Colors.purple),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: Colors.purple),
              ),
            ),
          ),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: () {
              final text = controller.text.trim();
              if (text.isNotEmpty) {
                Navigator.of(ctx).pop();
                _customChoiceController.text = text;
                _handleCustomChoice();
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.orange,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: const Text(
              'Add this to the story!',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
          ),
        ],
      ),
    ),
  );
}
```

**Test condition:** Age 4, choices visible — "Grown-up adds to the story..." orange button appears. Tap → bottom sheet opens. Enter "Then Mummy flew in on a rainbow!" → tap "Add this to the story!" → next segment incorporates the parent's addition. Age 8 — button not visible.

---

### Task 7.6 — Age-Adaptive Completion Screen

**File:** `lib/pick_a_path_adventure_screen.dart`

**What to find:** `_buildCompletionSection()` at line ~843.

**Exactly what to change:**

Replace the entire method:

```dart
Widget _buildCompletionSection() {
  final age = widget.character.age;
  final isChronicle = widget.isChronicleMode && widget.chronicleId != null;
  final isSprout = age <= 5;

  final String title = isChronicle
      ? (isSprout ? '🌟 Chapter done! Great job!'
          : age <= 7  ? 'Chapter Complete! Amazing! 🎉'
          : age <= 10 ? 'Chapter Complete!'
          :             'Chapter Complete')
      : (isSprout   ? 'The End! 🌈'
          : age <= 7 ? 'Adventure Complete! 🎉'
          :            'Adventure Complete!');

  final String saveLabel = isChronicle
      ? (isSprout ? 'Save my story! ⭐' : age <= 7 ? 'Save it!' : 'Save & continue another day')
      : (isSprout ? 'Keep this story! 📖' : 'Save to Library');

  final String continueLabel = isSprout ? 'Keep going! ➡️'
      : age <= 7  ? 'Next chapter!'
      : age <= 10 ? 'Start next chapter'
      :             'Continue Chronicle';

  return Column(
    children: [
      Icon(
        isChronicle ? Icons.menu_book_rounded : Icons.auto_awesome,
        size: isSprout ? 80 : 64,
        color: Colors.amber,
      ),
      const SizedBox(height: 16),
      Text(
        title,
        style: TextStyle(fontSize: isSprout ? 28 : 24, fontWeight: FontWeight.bold),
        textAlign: TextAlign.center,
      ),
      const SizedBox(height: 24),
      if (!_storySaved) ...[
        AppButton.primary(
          label: saveLabel,
          onPressed: _isSaving ? null : _saveStory,
        ),
        const SizedBox(height: 12),
      ],
      if (_storySaved) ...[
        Text(
          isSprout ? '✓ Saved! Great adventuring!' : '✓ Saved to your library!',
          style: const TextStyle(color: Colors.green, fontWeight: FontWeight.bold),
        ),
        if (isChronicle) ...[
          const SizedBox(height: 12),
          AppButton.secondary(
            label: continueLabel,
            onPressed: () {
              widget.onChapterComplete?.call(
                _accumulatedChapterText,
                _currentSegment?.content ?? '',
              );
              Navigator.of(context).pop();
            },
          ),
        ],
      ],
    ],
  );
}
```

**Test condition:** Age 5, chronicle mode, saved — shows "🌟 Chapter done! Great job!", "Save my story! ⭐", then after saving "Keep going! ➡️". Age 12, chronicle mode — "Chapter Complete", "Save & continue another day", then "Continue Chronicle". Standalone (non-chronicle), age 5 — "The End! 🌈", "Keep this story! 📖".

---

### Task 7.7 — Visual Chapter Log: Age-Adaptive ChronicleScreen

**File:** `lib/chronicle_screen.dart` (created in Phase 5)

**What to find:** The `_buildChapterLog(List<ChapterMemoryLocal> memories)` method.

**Exactly what to change:**

Replace `_buildChapterLog` with a dispatcher plus two new rendering variants. Keep the existing full-detail log (built in Phase 5) as `_buildFullChapterLog`:

```dart
Widget _buildChapterLog(List<ChapterMemoryLocal> memories) {
  final age = widget.character.age;
  if (age <= 5) return _buildSproutEmojiTrail(memories);
  if (age <= 7) return _buildExplorerCardLog(memories);
  return _buildFullChapterLog(memories); // Phase 5 implementation unchanged
}

/// Ages 3–5: Horizontal scrolling emoji circle trail.
Widget _buildSproutEmojiTrail(List<ChapterMemoryLocal> memories) {
  if (memories.isEmpty) {
    return const Padding(
      padding: EdgeInsets.all(24),
      child: Text('Your adventure trail will appear here! 🌱',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 18, color: Colors.white70)),
    );
  }
  const emojis = ['🌟','🏰','🐉','🗺️','⚔️','🌊','🔮','🦋','🌋','🏆'];
  return SingleChildScrollView(
    scrollDirection: Axis.horizontal,
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
    child: Row(
      children: memories.asMap().entries.expand((entry) {
        final idx = entry.key;
        final memory = entry.value;
        final emoji = emojis[idx % emojis.length];
        return [
          GestureDetector(
            onTap: () => _showChapterDetail(memory),
            child: Column(
              children: [
                Container(
                  width: 72, height: 72,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: const LinearGradient(
                        colors: [Color(0xFF7B2FBE), Color(0xFF9B59B6)]),
                    boxShadow: [BoxShadow(
                        color: Colors.purple.withValues(alpha: 0.4),
                        blurRadius: 8, offset: const Offset(0, 4))],
                  ),
                  child: Center(child: Text(emoji,
                      style: const TextStyle(fontSize: 32))),
                ),
                const SizedBox(height: 6),
                Text('Ch. ${memory.chapterNumber}',
                    style: const TextStyle(
                        color: Colors.white70, fontSize: 12,
                        fontWeight: FontWeight.bold)),
              ],
            ),
          ),
          if (idx < memories.length - 1)
            Padding(
              padding: const EdgeInsets.only(bottom: 24),
              child: Row(
                children: List.generate(4, (_) => Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 3),
                  child: Container(
                    width: 6, height: 6,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.white.withValues(alpha: 0.3),
                    ),
                  ),
                )),
              ),
            ),
        ];
      }).toList(),
    ),
  );
}

/// Ages 5–7: Vertical card list — chapter badge + cliffhanger only.
Widget _buildExplorerCardLog(List<ChapterMemoryLocal> memories) {
  if (memories.isEmpty) {
    return const Padding(
      padding: EdgeInsets.all(24),
      child: Text('Your chapters will appear here! ✨',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 16, color: Colors.white70)),
    );
  }
  return ListView.builder(
    shrinkWrap: true,
    physics: const NeverScrollableScrollPhysics(),
    itemCount: memories.length,
    itemBuilder: (context, idx) {
      final memory = memories[idx];
      return GestureDetector(
        onTap: () => _showChapterDetail(memory),
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.purple.withValues(alpha: 0.3)),
          ),
          child: Row(
            children: [
              Container(
                width: 44, height: 44,
                decoration: const BoxDecoration(
                    shape: BoxShape.circle, color: Color(0xFF7B2FBE)),
                child: Center(child: Text('${memory.chapterNumber}',
                    style: const TextStyle(color: Colors.white,
                        fontWeight: FontWeight.bold, fontSize: 18))),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Text(
                  memory.cliffhanger ?? 'Adventure continues...',
                  style: const TextStyle(color: Colors.white, fontSize: 14, height: 1.4),
                  maxLines: 2, overflow: TextOverflow.ellipsis,
                ),
              ),
              const Icon(Icons.chevron_right_rounded, color: Colors.white38),
            ],
          ),
        ),
      );
    },
  );
}
```

Also add the `_showChapterDetail` bottom sheet (used by all three log variants):

```dart
void _showChapterDetail(ChapterMemoryLocal memory) {
  final age = widget.character.age;
  final isSprout = age <= 5;
  final bullets = memory.summaryBullets; // getter decoding summaryBulletsJson

  showModalBottomSheet(
    context: context,
    backgroundColor: const Color(0xFF1E0538),
    shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
    builder: (_) => Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            isSprout ? 'Chapter ${memory.chapterNumber} 🌟' : 'Chapter ${memory.chapterNumber}',
            style: TextStyle(color: Colors.white,
                fontSize: isSprout ? 24 : 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          if (bullets != null)
            ...bullets.map((b) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(isSprout ? '⭐ ' : '• ',
                      style: const TextStyle(color: Colors.amber, fontSize: 16)),
                  Expanded(child: Text(b,
                      style: TextStyle(color: Colors.white70,
                          fontSize: isSprout ? 16 : 14, height: 1.5))),
                ],
              ),
            )),
          if (memory.cliffhanger != null) ...[
            const SizedBox(height: 12),
            Text(age <= 7 ? 'And then...' : 'Cliffhanger:',
                style: const TextStyle(color: Colors.amber,
                    fontWeight: FontWeight.bold, fontSize: 13)),
            const SizedBox(height: 4),
            Text(memory.cliffhanger!,
                style: TextStyle(color: Colors.white,
                    fontSize: isSprout ? 16 : 14, fontStyle: FontStyle.italic)),
          ],
          const SizedBox(height: 16),
        ],
      ),
    ),
  );
}
```

**Test condition:** Age 5 — horizontal emoji trail with purple circles connected by dots. Tap a circle → bottom sheet with star bullets and "And then..." cliffhanger. Age 7 — vertical card list with number badges. Age 12 — full Phase 5 log unchanged.

---

### Task 7.8 — Age-Adaptive Labels in ChronicleScreen and ChroniclesListScreen

**File:** `lib/chronicle_screen.dart` and `lib/chronicles_list_screen.dart`

**What to find:** Hardcoded strings for screen titles, empty states, and CTA buttons in both screens.

**Exactly what to change:**

In `ChronicleScreen`, add these getters inside the state class:

```dart
String get _screenTitle {
  final age = widget.character.age;
  if (age <= 5) return 'Our Story! 📖';
  if (age <= 7) return 'My Adventure Book';
  if (age <= 10) return 'My Chronicle';
  return _chronicle?.title ?? 'Chronicle';
}

String get _chapterCtaLabel {
  final age = widget.character.age;
  final next = (_chronicle?.chapterCount ?? 0) + 1;
  if (age <= 5) return next == 1 ? 'Start our story! 🌟' : 'Keep going! ➡️';
  if (age <= 7) return next == 1 ? 'Begin the adventure!' : 'Next chapter! 🎉';
  if (age <= 10) return next == 1 ? 'Start Chapter 1' : 'Start Chapter $next';
  return next == 1 ? 'Begin Chronicle' : 'Continue — Chapter $next';
}
```

Replace all hardcoded title/CTA strings in `ChronicleScreen` with `_screenTitle` and `_chapterCtaLabel`.

In `ChroniclesListScreen`, add:

```dart
String get _screenTitle {
  final age = widget.character.age;
  if (age <= 5) return 'Our Stories 📚';
  if (age <= 7) return 'My Adventure Books';
  if (age <= 10) return 'My Chronicles';
  return 'Chronicles';
}

String get _emptyState {
  final age = widget.character.age;
  if (age <= 5) return 'No stories yet!\nStart a new one! 🌟';
  if (age <= 7) return 'No adventures yet!\nStart your first chapter!';
  if (age <= 10) return 'No chronicles yet. Start your first!';
  return 'No chronicles yet.';
}

String get _newLabel {
  final age = widget.character.age;
  if (age <= 5) return 'Start a new story! ✨';
  if (age <= 7) return 'New adventure!';
  return 'New Chronicle';
}
```

Replace all hardcoded strings in `ChroniclesListScreen` with these getters.

**Test condition:** Age 5 — list screen title "Our Stories 📚", empty text "No stories yet! Start a new one! 🌟", button "Start a new story! ✨". Age 12 — "Chronicles", "No chronicles yet.", "New Chronicle".

---

### Task 7.9 — Backend: Age-Appropriate Vocabulary in Chapter Summaries

**File:** `backend/services/chronicle_prompt_service.py`

**What to find:** The `summarize_chapter` method signature and the f-string that builds the user prompt inside it.

**Exactly what to change:**

Step 1 — Add `age: int = 7` parameter to `summarize_chapter`:
```python
def summarize_chapter(
    self,
    chapter_number: int,
    chapter_text: str,
    character_name: str,
    choice_made_to_start: Optional[str],
    existing_world_facts: List[str],
    existing_unresolved_threads: List[str],
    age: int = 7,   # ADD THIS
) -> Dict[str, Any]:
```

Step 2 — Inside the method body, before the `user_prompt` f-string, add:
```python
if age <= 5:
    vocab_note = (
        "\nIMPORTANT: Write ALL summary_bullets in simple words a 4-year-old understands. "
        "Short sentences. Max 2-syllable words. "
        "Use: went, found, saw, helped, ran, jumped — NOT: traversed, encountered, discovered."
    )
elif age <= 7:
    vocab_note = (
        "\nWrite summary_bullets in clear, friendly language for a 6-year-old. "
        "Simple sentences. No abstract vocabulary."
    )
else:
    vocab_note = ""
```

Step 3 — Insert `{vocab_note}` at the end of the user_prompt f-string, before the JSON schema block.

Step 4 — In `backend/routes/chronicle_routes.py`, find the `/chronicle/summarize-chapter` route handler. Extract `age` from the request body and pass it:
```python
age = int(data.get('age', 7))
result = service.summarize_chapter(
    ...,            # existing params
    age=age,        # add this
)
```

Step 5 — In `lib/services/chronicle_service.dart` (created in Phase 3), in `saveChapterAndSummarize`, add `'age': chronicle.characterAge` to the POST body.

**Test condition:** POST `/chronicle/summarize-chapter` with `age: 4` and a chapter text containing "traversed the woodland" — returned `summary_bullets` should say "went to the forest" or similar. With `age: 12` — normal vocabulary in bullets.

---

## Phase 7 — End-to-End Tests (All Ages)

Run these in addition to the Phase 1–6 walkthrough.

**Sprout test (age 5):**
1. Select or create a character aged 5.
2. Open overflow menu → confirm "Our Stories 📚" label (no "My Chronicles").
3. Tap it — opens `ChroniclesListScreen` with title "Our Stories 📚". No snackbar.
4. Confirm empty state: "No stories yet! Start a new one! 🌟".
5. Tap "Start a new story! ✨" → create a chronicle.
6. `ChronicleScreen` title: "Our Story! 📖", CTA: "Start our story! 🌟".
7. Tap CTA → `PickAPathAdventureScreen` opens. Confirm TTS begins reading segment 1 aloud.
8. Confirm choice buttons are large colored gradient tiles.
9. Confirm mic button is large (72px) and centered.
10. Make 3 choices → session break appears: "Great adventuring! Time for a rest! 🌙".
11. Tap "All done! 🌟" → returns to `ChronicleScreen`. Emoji trail shows 1 circle.
12. Tap circle → bottom sheet shows simple bullet points ("went to", "found", etc.).
13. Tap "Keep going! ➡️" → new chapter starts, segment content references previous chapter.
14. In choices section — confirm "Grown-up adds to the story..." button is visible.
15. Tap it → parent co-pilot sheet opens. Enter text → confirm it appears in next segment.

**Explorer test (age 7):**
1. Age 7 character. "My Adventure Books" in overflow.
2. Play 5 segments → session break at 5 with "Amazing! Your story is saved!".
3. Return to `ChronicleScreen` → vertical card log with chapter badge + cliffhanger.
4. Tap card → bottom sheet shows bullets + "And then..." cliffhanger.
5. Continue → new chapter properly continues from previous cliffhanger.

**Adventurer test (age 9):**
1. Age 9 character. "My Chronicles" in overflow.
2. No session limit — story runs until `is_ending: true`.
3. Standard text-button choice layout (no colored tiles).
4. No TTS auto-play.
5. `ChronicleScreen` shows full detail log (Phase 5 design).

**Regression (age 12):**
1. All Phase 1–6 behavior unchanged for Creator band.
2. No auto-TTS, no colored tiles, no session limit, full chapter log, "Continue Chronicle" label.