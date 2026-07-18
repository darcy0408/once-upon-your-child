"""
Interactive Adventure Service
Orchestrates creation and continuation of interactive branching stories
with inventory, state tracking, and illustrations.
"""

import json
import logging
import re
import threading
import uuid
from datetime import datetime, timezone
from typing import Any, Dict, List, Optional

from backend.database import db
from backend.models import (
    Character,
    InteractiveStory,
    InventoryItem,
    StoryChoice,
    StorySegment,
    StoryState,
)
from backend.services.interactive_adventure_prompt_builder import (
    InteractiveAdventurePromptBuilder,
)
from backend.services.story_service import (
    _strip_companion_beat_labels,
    _strip_lesson_endings,
    _strip_meta_leakage,
    pseudonymize_hero_name,
    restore_hero_name,
)

logger = logging.getLogger(__name__)

# Template placeholder text the model sometimes echoes back verbatim from the
# generic choice templates in the prompt (e.g. "First choice option
# (Action-oriented)"). A segment whose choices still contain any of these is
# regenerated once; on a second failure the offending choices are dropped so a
# child never sees scaffold text on a button.
_PLACEHOLDER_CHOICE_RE = re.compile(
    r"choice\s+option|action-oriented|\b(first|second|third|fourth)\s+choice\b",
    re.IGNORECASE,
)


class InteractiveAdventureService:
    """Service for creating and managing interactive adventure stories"""

    def __init__(
        self, gemini_api_key: Optional[str] = None, user_tier: Optional[str] = None
    ):
        """Initialize the interactive adventure service.

        MT-137 / ToS COMPLIANCE: a child's story data must NOT be sent to Google
        Gemini — Gemini's API terms forbid child-directed apps, which is the
        whole reason the main story path was moved off Gemini. Interactive
        segments are now generated through the SAME ToS-safe provider chain
        (STORY_GEN_PROVIDER, default 'openai'); 'gemini'/'auto' are coerced to
        'openai' so a child's segment is never routed to Gemini. The legacy
        ``gemini_api_key`` parameter is kept for call-site compatibility but is
        no longer used for text generation.

        Illustrations (latency audit fix A/B): this service no longer performs
        ANY image work in the request path. Segment illustrations are generated
        out-of-band via ``schedule_segment_illustration`` (module-level, spawned
        by the route after moderation passes) on the same Cloudflare-first Flux
        Schnell chain the main story reader uses.
        """
        self._user_tier = user_tier

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
        big_feelings_context: Optional[Dict] = None,
        companions_payload: Optional[List[Dict]] = None,
        character_name: Optional[str] = None,
        include_images: bool = True,
    ) -> Dict[str, Any]:
        """
        Create a new interactive adventure story with opening segment.

        Args:
            user_id: ID of the user creating the story
            character_id: Optional ID of character to use as hero
            theme: Story theme (Adventure, Magic, Dragons, etc.)
            tone: Story tone (whimsical, mystery, sci-fi, fantasy, cozy-adventure)
            length: short, medium, or long
            age: Optional age override
            interests: Topics to incorporate
            must_include: Elements that must appear
            avoid: Elements to avoid
            fears_or_sensitivities: Things to handle carefully
            life_challenge: Optional therapeutic challenge (e.g. "Making Friends")
            personality_sliders: Optional personality traits (0-100)
            include_images: Signals whether the caller wants an illustration for
                this story (audio-only / no-screen clients never render
                segment.image_url). The service itself performs no image work
                either way (latency audit fix A) — the ROUTE uses this flag to
                decide whether to schedule background illustration generation.
                Kept on the service signature for call-site compatibility. Not
                persisted — pass it consistently on every continue_story call
                (see continue_story's docstring for why it isn't persisted).

        Returns:
            Dict with story_id, segment data, inventory, and state
        """
        logger.info(
            f"Creating interactive story for user {user_id}, character {character_id}"
        )

        # Load character if provided
        character = None
        child_name = character_name or "Hero"
        character_dict = None
        companions = list(companions_payload) if companions_payload else []

        if character_id:
            character = Character.query.filter_by(id=character_id).first()
            if character:
                child_name = character.name
                character_age = character.age or age or 8
                character_dict = {
                    "name": character.name,
                    "age": character.age,
                    "gender": character.gender,
                    "personality_traits": character.personality_traits,
                    "strengths": character.strengths,
                    "fears": character.fears,
                    "comfort_item": character.comfort_item,
                    "likes": character.likes,
                }

                # Merge personality sliders if not provided explicitly
                if not personality_sliders and character.personality_sliders:
                    personality_sliders = character.personality_sliders

                # Get companions from character — only if none provided via payload
                if not companions_payload:
                    if character.pets:
                        for pet in character.pets:
                            companions.append(
                                {
                                    "name": pet.get("name"),
                                    "species": pet.get("species"),
                                    "personality": pet.get("personality"),
                                    "color": pet.get("color"),
                                }
                            )

                    if character.friends:
                        for friend in character.friends[:1]:  # Max 1 friend companion
                            companions.append({"name": friend, "role": "friend"})
            else:
                character_age = age or 8
        else:
            character_age = age or 8

        # M-7: pseudonymize the child's real hero name before it reaches the
        # third-party LLM. The prompt (and character dict) carry the opaque
        # HERO_1 token; the real name is substituted back locally after
        # generation so the child still sees their own name.
        hero_token = pseudonymize_hero_name(child_name)
        prompt_character_dict = self._pseudonymize_character_dict(
            character_dict, child_name, hero_token
        )

        # Build opening prompt
        prompt = InteractiveAdventurePromptBuilder.build_opening_prompt(
            child_name=hero_token,
            age=character_age,
            length=length,
            theme=theme,
            tone=tone,
            character=prompt_character_dict,
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
            big_feelings_context=big_feelings_context,
        )

        # Generate first segment
        segment_data = self._generate_segment_with_retry(prompt)
        # M-7: substitute the real hero name back into the model output locally.
        segment_data = self._restore_hero_name_in_segment(
            segment_data, child_name, hero_token
        )
        # Hygiene (audit E): reuse the standard story path's strippers.
        segment_data = self._apply_content_hygiene(segment_data)

        # Create database records
        story = InteractiveStory(
            id=str(uuid.uuid4()),
            user_id=user_id,
            character_id=character_id,
            title=segment_data.get("title", f"{child_name}'s {theme} Adventure"),
            theme=theme,
            tone=tone,
            length=length,
            age=character_age,
            world_bible=world_bible or None,
            current_segment_number=1,
            is_completed=segment_data.get("is_ending", False),
        )
        db.session.add(story)
        db.session.flush()  # Get story.id

        # Create first segment
        segment = self._create_segment_record(
            story_id=story.id,
            segment_data=segment_data,
            segment_number=1,
            parent_choice_id=None,
        )
        db.session.add(segment)
        db.session.flush()

        # Update story's current segment
        story.current_segment_id = segment.id

        # Create inventory items
        inventory_items = []
        for item_name in segment_data.get("inventory", []):
            item = InventoryItem(
                id=str(uuid.uuid4()),
                story_id=story.id,
                name=item_name,
                description=None,
                acquired_at_segment=1,
                is_active=True,
            )
            inventory_items.append(item)
            db.session.add(item)

        # Create story state
        state_data = segment_data.get("story_state", {})
        state = StoryState(
            id=str(uuid.uuid4()),
            story_id=story.id,
            current_location=state_data.get("location"),
            current_goal=state_data.get("goal"),
            key_clues=state_data.get("key_clues", []),
            companion_status=state_data.get("companion_status"),
            time_pressure=state_data.get("time_pressure"),
            additional_state={
                "big_feelings_context": big_feelings_context or {},
            },
        )
        db.session.add(state)

        # Create choices
        for choice_data in segment_data.get("choices", []):
            # Parse choice number from prompt ID (e.g., "choice_1" -> 1)
            try:
                choice_num = int(choice_data.get("id", "choice_1").split("_")[1])
            except (IndexError, ValueError):
                choice_num = 1  # Fallback

            choice = StoryChoice(
                id=str(uuid.uuid4()),  # Always generate unique ID for DB
                segment_id=segment.id,
                choice_number=choice_num,
                text=choice_data.get("text"),
                consequence_type=None,
                is_selected=False,
            )
            db.session.add(choice)

        db.session.commit()

        # Latency audit fix A: NO illustration work happens here. The response
        # returns text-only (segment.image_url is None); the route schedules
        # background generation (schedule_segment_illustration) after
        # moderation passes, and the client fetches the image asynchronously.

        logger.info(f"Created interactive story {story.id} with first segment")

        return {
            "story_id": story.id,
            "title": story.title,
            "segment": segment.to_dict(),
            "inventory": [item.to_dict() for item in inventory_items],
            "state": state.to_dict(),
            "is_completed": story.is_completed,
        }

    def continue_story(
        self,
        story_id: str,
        choice_id: str,
        custom_text: str | None = None,
        include_images: bool = True,
    ) -> Dict[str, Any]:
        """
        Continue story based on user's choice selection.

        Args:
            story_id: ID of the interactive story
            choice_id: ID of the choice user selected, or "custom" for free-text input
            custom_text: Free-text input when choice_id is "custom". The caller
                MUST pass this already sanitized and [USER_INPUT]-wrapped (see
                continue_interactive_story_endpoint) — it is injected directly
                into the continuation prompt.
            include_images: Signals whether the caller wants an illustration for
                the new segment. The service performs no image work either way
                (latency audit fix A) — the ROUTE uses this flag to decide
                whether to schedule background illustration generation.

                Design note: this is intentionally a per-request flag, not a
                preference persisted on the InteractiveStory record. The
                audio-only ("no screen") client is the sole caller of both
                generate + continue for its own story loop and already knows
                it's audio-only on every call, so it can just pass
                include_images=False consistently — no server-side state is
                needed to remember the choice across segments. Persisting a
                per-story "images enabled" column would need a schema
                migration for a preference the only current caller can supply
                for free on each request; if a second client needs the
                preference remembered without resending it, add a nullable
                `images_enabled` column to InteractiveStory then and default
                the per-request flag from it.

        Returns:
            Dict with new segment data, updated inventory, and state
        """
        logger.info(f"Continuing story {story_id} with choice {choice_id}")

        # Load story and validate
        story = InteractiveStory.query.filter_by(id=story_id).first()
        if not story:
            raise ValueError(f"Story {story_id} not found")

        if story.is_completed:
            raise ValueError(f"Story {story_id} is already completed")

        # Handle special "continue" choice ID (for segments with output_type="continue")
        if choice_id == "continue":
            logger.info("Processing CONTINUE segment (no choice required)")
            selected_choice_text = "Continue the adventure"
            parent_choice_id = None
        elif choice_id == "custom" and custom_text:
            # Free-text "Something Else" choice — no DB record, use the text directly
            logger.info(f"Processing custom choice: {custom_text[:50]!r}")
            selected_choice_text = custom_text
            parent_choice_id = None
        else:
            # Load choice and mark as selected
            choice = StoryChoice.query.filter_by(id=choice_id).first()
            if not choice:
                raise ValueError(f"Choice {choice_id} not found")

            choice.is_selected = True
            choice.selected_at = datetime.now(timezone.utc)
            selected_choice_text = choice.text
            parent_choice_id = choice_id

        # Build story context
        story_context = self._build_story_context(story)

        # Get current inventory
        current_inventory = [
            item.name for item in story.inventory.filter_by(is_active=True).all()
        ]

        # Get current state
        current_state = story.state.to_dict() if story.state else {}

        # Build story summary
        story_so_far = self._build_story_summary(story)

        # M-7: pseudonymize the child's real hero name everywhere it would reach
        # the LLM — the character dict, the recap of the story so far, and the
        # selected-choice text. The real name is substituted back locally after
        # generation.
        real_hero_name = (
            (story_context.get("character") or {}).get("name")
            if isinstance(story_context.get("character"), dict)
            else None
        )
        hero_token = pseudonymize_hero_name(real_hero_name)
        prompt_story_context = dict(story_context)
        prompt_story_context["character"] = self._pseudonymize_character_dict(
            story_context.get("character"), real_hero_name, hero_token
        )
        prompt_story_so_far = (
            story_so_far.replace(real_hero_name, hero_token)
            if real_hero_name and story_so_far
            else story_so_far
        )
        prompt_selected_choice = (
            selected_choice_text.replace(real_hero_name, hero_token)
            if real_hero_name and selected_choice_text
            else selected_choice_text
        )

        # Build continuation prompt
        prompt = InteractiveAdventurePromptBuilder.build_continuation_prompt(
            story_context=prompt_story_context,
            selected_choice=prompt_selected_choice,
            current_segment_number=story.current_segment_number,
            inventory=current_inventory,
            story_state=current_state,
            story_so_far=prompt_story_so_far,
        )

        # Generate next segment
        segment_data = self._generate_segment_with_retry(prompt)
        # M-7: substitute the real hero name back into the model output locally.
        segment_data = self._restore_hero_name_in_segment(
            segment_data, real_hero_name, hero_token
        )

        next_segment_number = story.current_segment_number + 1

        # Audit fix D (server-side ending backstop): the per-segment word
        # budget divides the total word count by path_depth, so an adventure
        # that overruns its planned depth breaks pacing — and the model's
        # own `is_ending` is unreliable (the JSON template used to hardcode
        # false). At/beyond path_depth the story completes regardless of
        # what the model returned.
        path_depth = InteractiveAdventurePromptBuilder.get_path_depth(
            story.age or 7, story.length
        )
        if next_segment_number >= path_depth and not segment_data.get(
            "is_ending", False
        ):
            logger.warning(
                "Story %s reached path depth %d without model-declared ending; "
                "forcing completion",
                story_id,
                path_depth,
            )
            segment_data["is_ending"] = True
            segment_data["choices"] = []

        # Hygiene (audit E): reuse the standard story path's strippers. Runs
        # after the ending backstop so lesson-ending stripping applies to
        # forced finales too.
        segment_data = self._apply_content_hygiene(segment_data)

        # Create new segment.
        # MT-195: `parent_choice_id` is the FK to story_choice.id (nullable).
        # We pass the *computed* `parent_choice_id` — which is None for the
        # "continue" / "custom" branches and the real choice.id otherwise —
        # rather than the raw `choice_id` arg (which is the literal string
        # "continue" or "custom" on those branches).
        new_segment = self._create_segment_record(
            story_id=story.id,
            segment_data=segment_data,
            segment_number=next_segment_number,
            parent_choice_id=parent_choice_id,
        )
        db.session.add(new_segment)
        db.session.flush()

        # Update story progress
        story.current_segment_id = new_segment.id
        story.current_segment_number = next_segment_number
        story.is_completed = segment_data.get("is_ending", False)
        story.updated_at = datetime.now(timezone.utc)

        # Update inventory
        new_inventory_names = segment_data.get("inventory", [])
        self._update_inventory(story, new_inventory_names, next_segment_number)

        # Update state
        new_state_data = segment_data.get("story_state", {})
        self._update_state(story, new_state_data)

        # Create choices for new segment (if not ending)
        if not segment_data.get("is_ending", False):
            for choice_data in segment_data.get("choices", []):
                # Parse choice number from prompt ID
                try:
                    choice_num = int(choice_data.get("id", "choice_1").split("_")[1])
                except (IndexError, ValueError):
                    choice_num = 1

                new_choice = StoryChoice(
                    id=str(uuid.uuid4()),  # Always generate unique ID for DB
                    segment_id=new_segment.id,
                    choice_number=choice_num,
                    text=choice_data.get("text"),
                    consequence_type=None,
                    is_selected=False,
                )
                db.session.add(new_choice)

        db.session.commit()

        # Latency audit fix A: NO illustration work happens here — the route
        # schedules background generation after moderation passes and the
        # client fetches the image asynchronously.

        logger.info(f"Story {story_id} continued to segment {next_segment_number}")

        return {
            "story_id": story.id,
            "segment": new_segment.to_dict(),
            "inventory": [
                item.to_dict()
                for item in story.inventory.filter_by(is_active=True).all()
            ],
            "state": story.state.to_dict(),
            "is_completed": story.is_completed,
        }

    def get_story(self, story_id: str) -> Dict[str, Any]:
        """Get full story with all segments"""
        story = InteractiveStory.query.filter_by(id=story_id).first()
        if not story:
            raise ValueError(f"Story {story_id} not found")

        return {
            **story.to_dict(),
            "segments": [seg.to_dict() for seg in story.segments.all()],
        }

    # Helper methods

    @staticmethod
    def _pseudonymize_character_dict(
        character_dict: Optional[Dict], real_name: Optional[str], hero_token: str
    ) -> Optional[Dict]:
        """Return a copy of *character_dict* with the hero name replaced by the
        pseudonym token (M-7). The original dict is left untouched so the real
        name is still available for the local restore step and DB persistence.
        """
        if not character_dict:
            return character_dict
        safe = dict(character_dict)
        if real_name and safe.get("name"):
            safe["name"] = hero_token
        return safe

    @staticmethod
    def _restore_hero_name_in_segment(
        segment_data: Dict[str, Any], real_name: Optional[str], hero_token: str
    ) -> Dict[str, Any]:
        """Substitute the real hero name back into every text field of a parsed
        segment (M-7). Applied locally to provider output before the segment is
        persisted or returned, so the child sees their own name even though the
        provider only ever saw the HERO_1 token.
        """
        if not real_name or not isinstance(segment_data, dict):
            return segment_data
        for key in ("title", "content", "image_description", "stage_label"):
            if isinstance(segment_data.get(key), str):
                segment_data[key] = restore_hero_name(
                    segment_data[key], real_name, hero_token
                )
        for choice in segment_data.get("choices", []) or []:
            if isinstance(choice, dict) and isinstance(choice.get("text"), str):
                choice["text"] = restore_hero_name(
                    choice["text"], real_name, hero_token
                )
        inv = segment_data.get("inventory")
        if isinstance(inv, list):
            segment_data["inventory"] = [
                (
                    restore_hero_name(item, real_name, hero_token)
                    if isinstance(item, str)
                    else item
                )
                for item in inv
            ]
        return segment_data

    def _generate_text(self, prompt: str) -> str:
        """Generate raw model text via the ToS-safe provider chain.

        MT-137: NEVER routes a child's story data to Gemini. Mirrors the main
        story path's provider selection (STORY_GEN_PROVIDER, default 'openai');
        'gemini'/'auto'/unset are coerced to 'openai'. The interactive prompt
        already instructs raw-JSON output, so the chat response is parsed by
        _parse_segment_response exactly as before.
        """
        import os

        provider = (os.getenv("STORY_GEN_PROVIDER") or "openai").strip().lower()
        if provider in ("gemini", "auto", ""):
            provider = "openai"

        if provider == "claude":
            from backend.services.anthropic_story_generator import (
                ClaudeDirectStoryGenerator,
            )

            gen = ClaudeDirectStoryGenerator(user_tier=self._user_tier)
        elif provider == "openrouter":
            from backend.services.openrouter_story_generator import (
                OpenRouterStoryGenerator,
            )

            gen = OpenRouterStoryGenerator(user_tier=self._user_tier)
        elif provider == "tiered":
            # free -> OpenAI, paid -> Claude (mirror the main cost/quality split).
            is_free = (self._user_tier or "").strip().lower() == "free"
            if is_free:
                from backend.services.openai_story_generator import (
                    OpenAIStoryGenerator,
                )

                gen = OpenAIStoryGenerator(user_tier=self._user_tier)
            else:
                from backend.services.anthropic_story_generator import (
                    ClaudeDirectStoryGenerator,
                )

                gen = ClaudeDirectStoryGenerator(user_tier=self._user_tier)
        else:  # 'openai' and any unrecognized value -> OpenAI (ToS-safe default)
            from backend.services.openai_story_generator import OpenAIStoryGenerator

            gen = OpenAIStoryGenerator(user_tier=self._user_tier)

        return gen.generate_story(prompt)

    @staticmethod
    def _has_placeholder_choices(segment_data: Dict[str, Any]) -> bool:
        """True if any returned choice still contains template placeholder text
        (e.g. "First choice option (Action-oriented)") the model was supposed
        to replace."""
        for choice in segment_data.get("choices") or []:
            if isinstance(choice, dict) and _PLACEHOLDER_CHOICE_RE.search(
                str(choice.get("text") or "")
            ):
                return True
        return False

    @staticmethod
    def _drop_placeholder_choices(segment_data: Dict[str, Any]) -> Dict[str, Any]:
        """Remove choices that still contain template placeholder text. If none
        survive, the segment degrades to a continue-style beat (the client
        renders a Continue button for choiceless, non-ending segments)."""
        choices = segment_data.get("choices") or []
        kept = [
            c
            for c in choices
            if not (
                isinstance(c, dict)
                and _PLACEHOLDER_CHOICE_RE.search(str(c.get("text") or ""))
            )
        ]
        if len(kept) != len(choices):
            logger.warning(
                "Dropped %d placeholder choice(s) after retry", len(choices) - len(kept)
            )
        segment_data["choices"] = kept
        return segment_data

    @staticmethod
    def _apply_content_hygiene(segment_data: Dict[str, Any]) -> Dict[str, Any]:
        """Run the standard story path's meta-leakage stripper on segment prose
        (audit E — reused from story_service, not duplicated). Also excises
        leaked companion_beats JSON-schema labels ("Action:"/"Dialogue:"/
        "Bond:" — observed on prod 2026-07-18). Lesson-summary endings are
        additionally stripped on ending segments, mirroring how the main path
        only checks the final page."""
        content = segment_data.get("content")
        if isinstance(content, str) and content.strip():
            content = _strip_companion_beat_labels(content)
            pages = _strip_meta_leakage([content])
            if segment_data.get("is_ending"):
                pages = _strip_lesson_endings(pages)
            if pages and pages[0].strip():
                segment_data["content"] = pages[0]
        return segment_data

    def _generate_segment_with_retry(
        self, prompt: str, max_retries: int = 3
    ) -> Dict[str, Any]:
        """Generate a segment with retry + JSON parsing via the ToS-safe
        provider chain (never Gemini — MT-137). The underlying generators run
        their own 429/backoff internally and return a sentinel string on
        failure, which fails JSON parsing here and triggers a retry.

        Audit fix E: a parsed segment whose choices still contain template
        placeholder text is regenerated once; if the retry still contains
        placeholders they are dropped rather than shown to the child."""
        import time

        base_delay = 2
        placeholder_retried = False

        for attempt in range(max_retries):
            try:
                logger.info(f"Generating segment (attempt {attempt + 1}/{max_retries})")
                text = self._generate_text(prompt)
                if text and text.strip():
                    segment_data = self._parse_segment_response(text)
                    if self._has_placeholder_choices(segment_data):
                        if not placeholder_retried and attempt < max_retries - 1:
                            placeholder_retried = True
                            logger.warning(
                                "Segment choices contain template placeholder "
                                "text; regenerating (one retry max)"
                            )
                            continue
                        segment_data = self._drop_placeholder_choices(segment_data)
                    logger.info("Segment generated successfully")
                    return segment_data

                logger.warning("No valid response from story provider")
                if attempt < max_retries - 1:
                    continue

            except json.JSONDecodeError as e:
                logger.error(f"Failed to parse JSON response: {e}")
                if attempt < max_retries - 1:
                    time.sleep(base_delay * (2**attempt))
                    continue

            except Exception as e:
                logger.error(f"Segment generation failed: {e}", exc_info=True)
                if attempt < max_retries - 1:
                    time.sleep(base_delay * (2**attempt))
                    continue
                raise

        raise RuntimeError("Failed to generate segment after multiple retries")

    @staticmethod
    def _parse_segment_response(raw_text: str) -> Dict[str, Any]:
        """Parse Gemini JSON output with minimal cleanup for common formatting issues."""
        clean_text = (raw_text or "").strip()
        if not clean_text:
            raise json.JSONDecodeError("Empty segment response", clean_text, 0)

        # Strip markdown wrappers some models still add around JSON payloads.
        clean_text = re.sub(
            r"^\s*```(?:json)?\s*\n?", "", clean_text, flags=re.IGNORECASE
        )
        clean_text = re.sub(r"\n?\s*```\s*$", "", clean_text, flags=re.IGNORECASE)
        clean_text = re.sub(r"^\s*\*\*\s*", "", clean_text)
        clean_text = re.sub(r"\s*\*\*\s*$", "", clean_text)

        candidates = [clean_text]

        json_start = clean_text.find("{")
        json_end = clean_text.rfind("}")
        if json_start >= 0 and json_end > json_start:
            candidates.append(clean_text[json_start : json_end + 1])

        # Common Gemini failure mode: trailing commas before } or ]
        candidates.extend(
            re.sub(r",(\s*[}\]])", r"\1", candidate) for candidate in list(candidates)
        )

        last_error: json.JSONDecodeError | None = None
        for candidate in candidates:
            try:
                return json.loads(candidate)
            except json.JSONDecodeError as exc:
                last_error = exc

        if last_error is not None:
            raise last_error
        raise json.JSONDecodeError("Unable to parse segment response", clean_text, 0)

    def _create_segment_record(
        self,
        story_id: str,
        segment_data: Dict,
        segment_number: int,
        parent_choice_id: Optional[str],
    ) -> StorySegment:
        """Create StorySegment database record"""
        content = segment_data.get("content", "")

        # Calculate word count if not provided
        word_count = segment_data.get("word_count")
        if not word_count and content:
            word_count = len(content.split())

        # Get output_type (defaults to CHOICE for backward compatibility)
        output_type = segment_data.get("output_type", "CHOICE")

        return StorySegment(
            id=str(uuid.uuid4()),
            story_id=story_id,
            segment_number=segment_number,
            title=segment_data.get("title"),
            stage_label=segment_data.get("stage_label"),
            output_type=output_type,
            word_count=word_count,
            content=content,
            image_description=segment_data.get("image_description"),
            parent_choice_id=parent_choice_id,
        )

    def _update_inventory(
        self, story: InteractiveStory, new_inventory: List[str], segment_number: int
    ):
        """Update inventory based on new list"""
        current_items = {
            item.name: item for item in story.inventory.filter_by(is_active=True).all()
        }

        # Add new items
        for item_name in new_inventory:
            if item_name not in current_items:
                new_item = InventoryItem(
                    id=str(uuid.uuid4()),
                    story_id=story.id,
                    name=item_name,
                    acquired_at_segment=segment_number,
                    is_active=True,
                )
                db.session.add(new_item)

        # Mark removed items as inactive
        for item_name, item in current_items.items():
            if item_name not in new_inventory:
                item.is_active = False

    def _update_state(self, story: InteractiveStory, new_state_data: Dict):
        """Update story state"""
        if not story.state:
            return

        state = story.state
        state.current_location = new_state_data.get("location", state.current_location)
        state.current_goal = new_state_data.get("goal", state.current_goal)
        state.key_clues = new_state_data.get("key_clues", state.key_clues)
        state.companion_status = new_state_data.get(
            "companion_status", state.companion_status
        )
        state.time_pressure = new_state_data.get("time_pressure", state.time_pressure)
        state.updated_at = datetime.now(timezone.utc)

    def _build_story_context(self, story: InteractiveStory) -> Dict[str, Any]:
        """Build story context for continuation"""
        character_dict = self._get_character_dict(story)

        return {
            "title": story.title,
            "theme": story.theme,
            "tone": story.tone,
            "length": story.length,
            "age": story.age,
            "world_bible": story.world_bible or "",
            "character": character_dict,
            "companions": self._get_companions(story),
            "big_feelings_context": (
                (story.state.additional_state or {}).get("big_feelings_context", {})
                if story.state and story.state.additional_state
                else {}
            ),
        }

    def _get_character_dict(self, story: InteractiveStory) -> Optional[Dict]:
        """Get character dictionary from story"""
        if not story.character:
            return None

        char = story.character
        return {
            "name": char.name,
            "age": char.age,
            "personality_traits": char.personality_traits,
            "strengths": char.strengths,
            "fears": char.fears,
        }

    def _get_companions(self, story: InteractiveStory) -> List[Dict]:
        """Get companions list from character"""
        if not story.character:
            return []

        companions = []
        if story.character.pets:
            for pet in story.character.pets:
                companions.append(
                    {
                        "name": pet.get("name"),
                        "species": pet.get("species"),
                        "personality": pet.get("personality"),
                        "color": pet.get("color"),
                    }
                )

        return companions

    # Word budget for the story-so-far block fed to the continuation prompt
    # (latency/continuity audit, fix C — roughly 1500-2000 words). The full
    # text of the immediately previous segment is always kept; older-segment
    # summaries are dropped OLDEST-first when the budget would overflow.
    MAX_CONTEXT_WORDS = 1800

    def _build_story_summary(self, story: InteractiveStory) -> str:
        """Build the story-so-far context for the continuation prompt.

        Audit fix C: the old implementation truncated every segment to its
        first 200 chars, so anything introduced later in a segment — names,
        objects, the cliffhanger the child just read — was invisible to the
        model. Now:
          * the immediately previous segment is included IN FULL, verbatim,
          * older segments get compact structured summaries (first + last
            sentence, mid-sentence proper nouns, and the choice taken),
          * the whole block is capped at MAX_CONTEXT_WORDS, dropping the
            oldest summaries first.

        Deliberately heuristic — ChroniclePromptService.summarize_chapter is a
        real LLM summarizer, but calling it here would add a second model
        round-trip to every choice tap, which is exactly the latency this
        change removes.
        """
        segments = story.segments.order_by(StorySegment.segment_number).all()
        if not segments:
            return ""

        previous = segments[-1]
        prev_choice = next((c for c in previous.choices if c.is_selected), None)
        prev_parts = [
            f"PREVIOUS SCENE (segment {previous.segment_number}, VERBATIM — "
            "the next segment continues directly from here):",
            (previous.content or "").strip(),
        ]
        if prev_choice:
            prev_parts.append(f"→ The reader just chose: {prev_choice.text}")
        prev_block = "\n".join(prev_parts)

        budget = self.MAX_CONTEXT_WORDS - len(prev_block.split())
        newest_first: List[str] = []
        for seg in reversed(segments[:-1]):
            line = self._summarize_segment_for_context(seg)
            cost = len(line.split())
            if cost > budget:
                break  # this summary and everything older is dropped
            newest_first.append(line)
            budget -= cost

        if newest_first:
            older_block = "\n\n".join(reversed(newest_first))
            return (
                "EARLIER IN THE ADVENTURE (oldest first):\n"
                f"{older_block}\n\n{prev_block}"
            )
        return prev_block

    @staticmethod
    def _summarize_segment_for_context(seg: StorySegment) -> str:
        """Compact single-segment summary: first + last sentence plus proper
        nouns found mid-sentence, so names/objects introduced late in a
        segment survive compression."""
        content = (seg.content or "").strip()
        sentences = [s for s in re.split(r"(?<=[.!?])\s+", content) if s.strip()]
        first = sentences[0] if sentences else ""
        last = sentences[-1] if len(sentences) > 1 else ""
        summary = f"Segment {seg.segment_number}: {first}"
        if last:
            summary += f" [...] {last}"

        # Capitalized words that are NOT sentence-initial are very likely
        # proper nouns (characters, places, named objects).
        nouns: List[str] = []
        seen: set = set()
        for sentence in sentences:
            for word in sentence.split()[1:]:
                match = re.match(r"^[\"'(\[]*([A-Z][a-zA-Z'-]{2,})", word)
                if not match:
                    continue
                name = match.group(1)
                key = name.lower()
                if key not in seen:
                    seen.add(key)
                    nouns.append(name)
        if nouns:
            summary += f" (Names/objects: {', '.join(nouns[:8])})"

        selected_choice = next((c for c in seg.choices if c.is_selected), None)
        if selected_choice:
            summary += f"\n  → Chose: {selected_choice.text}"
        return summary


# ---------------------------------------------------------------------------
# Out-of-band segment illustration (latency audit fixes A + B)
#
# The request path returns text-only; these helpers generate the illustration
# in a background thread on the SAME Cloudflare-first Flux Schnell chain the
# main story reader uses (_generate_flux_illustration: Cloudflare Workers AI
# at $0, Replicate Flux Schnell fallback, per-provider kill switches) instead
# of the old synchronous ReplicateImageGenerator poll loop. The client fetches
# the finished image via
# GET /interactive-story/<story_id>/segments/<segment_id>/illustration.
# ---------------------------------------------------------------------------


def generate_segment_illustration(segment_id: str) -> bool:
    """Generate and persist the illustration for one segment (blocking).

    Returns True when an image was generated and stored. Safe to call twice —
    a segment that already has an image (or has no image_description) is a
    no-op. Never raises past its own boundary except for programming errors;
    provider failures return False and leave image_url None so the client's
    poll simply times out gracefully.
    """
    # Lazy import: story_routes imports this module at import time, so a
    # top-level import here would be circular.
    from backend.routes.story_routes import _generate_flux_illustration

    segment = db.session.get(StorySegment, segment_id)
    if segment is None:
        logger.warning("Segment %s not found for illustration", segment_id)
        return False
    if segment.image_url or not segment.image_description:
        return False

    story = segment.story
    service = InteractiveAdventureService()
    character_dict = service._get_character_dict(story) if story else None
    companions = service._get_companions(story) if story else []

    # MT-311#16: the child's real name never reaches the image vendor — the
    # picture doesn't render text, so the name is cosmetic.
    character_appearance = None
    if character_dict:
        character_appearance = {
            "name": "the hero",
            "age": character_dict.get("age"),
        }

    images = _generate_flux_illustration(
        scene_description=segment.image_description,
        character_name="the hero",
        style="whimsical children's book illustration",
        num_images=1,
        age=(story.age if story else 7) or 7,
        character_appearance=character_appearance,
        companions=companions,
    )

    if images and images[0].get("image_data"):
        image_format = images[0].get("format") or "png"
        segment.image_url = (
            f"data:image/{image_format};base64,{images[0]['image_data']}"
        )
        db.session.commit()
        logger.info("Generated illustration for segment %s", segment_id)
        return True

    logger.warning("Illustration providers returned no image for %s", segment_id)
    return False


def schedule_segment_illustration(app, segment_id: str) -> threading.Thread:
    """Kick off background illustration generation for a segment.

    ``app`` must be the real Flask app object (``current_app._get_current_object()``
    from a request context) — the worker thread pushes its own app context.
    Daemon thread: an in-flight illustration never blocks process shutdown;
    the poll endpoint simply reports pending until the client gives up.
    """

    def _run() -> None:
        with app.app_context():
            try:
                generate_segment_illustration(segment_id)
            except Exception:
                logger.exception(
                    "Background illustration failed for segment %s", segment_id
                )
                db.session.rollback()
            finally:
                db.session.remove()

    thread = threading.Thread(
        target=_run,
        name=f"segment-illustration-{segment_id[:8]}",
        daemon=True,
    )
    thread.start()
    return thread
