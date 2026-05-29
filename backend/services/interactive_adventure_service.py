"""
Interactive Adventure Service
Orchestrates creation and continuation of interactive branching stories
with inventory, state tracking, and illustrations.
"""

import json
import logging
import re
import uuid
from datetime import datetime, timezone
from typing import Any, Dict, List, Optional

from google import genai
from google.api_core import exceptions as google_exceptions
from google.genai import types

from backend.database import db
from backend.models import (
    Character,
    InteractiveStory,
    InventoryItem,
    StoryChoice,
    StorySegment,
    StoryState,
)
from backend.replicate_image_generator import ReplicateImageGenerator
from backend.services.interactive_adventure_prompt_builder import (
    InteractiveAdventurePromptBuilder,
)
from backend.services.story_service import pseudonymize_hero_name, restore_hero_name

logger = logging.getLogger(__name__)


class InteractiveAdventureService:
    """Service for creating and managing interactive adventure stories"""

    def __init__(self, gemini_api_key: Optional[str] = None):
        """Initialize with Gemini API key"""
        import os

        self.api_key = gemini_api_key or os.getenv("GEMINI_API_KEY")
        if not self.api_key:
            raise ValueError("GEMINI_API_KEY not set")
        self._request_timeout_seconds = int(
            os.getenv("GEMINI_REQUEST_TIMEOUT_SECONDS", "45")
        )

        self._client = genai.Client(api_key=self.api_key)

        # Use Gemini model with JSON mode support
        self._model_name = os.getenv("GEMINI_MODEL", "gemini-2.5-flash")
        logger.info(
            f"Initializing Interactive Adventure Service with model: {self._model_name}"
        )
        # JSON mode config — cap tokens to avoid over-generation (fastest safe limit
        # that still covers the largest age band's per-segment word count + JSON overhead)
        self._json_config = types.GenerateContentConfig(
            response_mime_type="application/json",
            max_output_tokens=1200,
            temperature=0.4,
            thinking_config=types.ThinkingConfig(thinking_budget=0),
        )

        # Initialize image generator (using Replicate for actual image generation)
        # GeminiImageGenerator doesn't work (Gemini can't generate images)
        self.image_generator = ReplicateImageGenerator()

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

        # Generate illustration for first segment
        # In MOCK_TESTING_MODE, this returns instantly (no API call, no cost)
        # Set MOCK_TESTING_MODE=false in .env to enable real image generation
        if segment_data.get("image_description"):
            self._generate_segment_illustration(
                segment, character_dict, companions, character_age
            )
            db.session.commit()

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
        self, story_id: str, choice_id: str, custom_text: str | None = None
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
            # TODO(lint): `parent_choice_id` is computed across all branches
            # (None for continue/custom, choice_id otherwise) but the call at
            # line ~412 passes `parent_choice_id=choice_id` directly, which is
            # the literal string "continue" / "custom" for those branches.
            # Suspected wiring bug — flagged on PR #151.
            parent_choice_id = choice_id  # noqa: F841

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

        # Create new segment
        new_segment = self._create_segment_record(
            story_id=story.id,
            segment_data=segment_data,
            segment_number=next_segment_number,
            parent_choice_id=choice_id,
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

        # Generate illustration for new segment
        # In MOCK_TESTING_MODE, this returns instantly (no API call, no cost)
        # Set MOCK_TESTING_MODE=false in .env to enable real image generation
        if segment_data.get("image_description"):
            character_dict = self._get_character_dict(story)
            companions = self._get_companions(story)
            self._generate_segment_illustration(
                new_segment, character_dict, companions, story.age
            )
            db.session.commit()

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

    def _generate_segment_with_retry(
        self, prompt: str, max_retries: int = 3
    ) -> Dict[str, Any]:
        """Generate segment with retry logic and JSON parsing"""
        import time

        base_delay = 2

        for attempt in range(max_retries):
            try:
                logger.info(f"Generating segment (attempt {attempt + 1}/{max_retries})")
                # Call Gemini directly — no ThreadPoolExecutor overhead
                response = self._client.models.generate_content(
                    model=self._model_name,
                    contents=prompt,
                    config=self._json_config,
                )

                if response and hasattr(response, "text") and response.text:
                    segment_data = self._parse_segment_response(response.text)
                    logger.info("Segment generated successfully")
                    return segment_data
                elif (
                    response and hasattr(response, "candidates") and response.candidates
                ):
                    candidate = response.candidates[0]
                    if hasattr(candidate, "content") and candidate.content.parts:
                        text = candidate.content.parts[0].text
                        segment_data = self._parse_segment_response(text)
                        logger.info("Segment generated from candidates")
                        return segment_data

                logger.warning("No valid response from Gemini")
                if attempt < max_retries - 1:
                    continue

            except json.JSONDecodeError as e:
                logger.error(f"Failed to parse JSON response: {e}")
                if attempt < max_retries - 1:
                    time.sleep(base_delay * (2**attempt))
                    continue

            except google_exceptions.ResourceExhausted as e:
                logger.warning(
                    f"Rate limit exceeded (attempt {attempt + 1}). Retrying..."
                )
                if attempt < max_retries - 1:
                    delay = base_delay * (2**attempt)
                    logger.warning(f"Retrying in {delay}s...")
                    time.sleep(delay)
                    continue
                else:
                    logger.error("Max retries exceeded for rate limit.")
                    raise e

            except Exception as e:
                logger.error(f"Segment generation failed: {e}", exc_info=True)
                if attempt < max_retries - 1:
                    import time

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
                    }
                )

        return companions

    def _build_story_summary(self, story: InteractiveStory) -> str:
        """Build summary of story so far"""
        segments = story.segments.order_by(StorySegment.segment_number).all()

        summary_parts = []
        for seg in segments:
            summary_parts.append(
                f"Segment {seg.segment_number}: {seg.content[:200]}..."
            )

            # Include selected choice if available
            selected_choice = next((c for c in seg.choices if c.is_selected), None)
            if selected_choice:
                summary_parts.append(f"  → Chose: {selected_choice.text}")

        return "\n\n".join(summary_parts)

    def _generate_segment_illustration(
        self,
        segment: StorySegment,
        character_dict: Optional[Dict],
        companions: List[Dict],
        age: int,
    ):
        """Generate illustration for segment asynchronously"""
        try:
            if not segment.image_description:
                return

            character_name = (
                character_dict.get("name", "the hero") if character_dict else "the hero"
            )

            # Build character appearance from dict
            character_appearance = None
            if character_dict:
                # This would need to be expanded based on Character model fields
                character_appearance = {
                    "name": character_dict.get("name"),
                    "age": character_dict.get("age"),
                }

            images = self.image_generator.generate_story_illustration(
                scene_description=segment.image_description,
                character_name=character_name,
                style="whimsical children's book illustration",
                num_images=1,
                age=age,
                character_appearance=character_appearance,
                companions=companions,
            )

            if images and len(images) > 0:
                image_data = images[0].get("image_data")
                if image_data:
                    segment.image_url = f"data:image/png;base64,{image_data}"
                    logger.info(f"Generated illustration for segment {segment.id}")

        except Exception as e:
            logger.error(
                f"Failed to generate illustration for segment {segment.id}: {e}"
            )
            # Don't fail the whole operation if illustration fails
