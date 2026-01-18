"""
Interactive Adventure Service
Orchestrates creation and continuation of interactive branching stories
with inventory, state tracking, and illustrations.
"""
import json
import logging
import uuid
from datetime import datetime, timezone
from typing import Dict, List, Optional, Any

import google.generativeai as genai
from google.api_core import exceptions as google_exceptions

from backend.database import db
from backend.models import (
    InteractiveStory,
    StorySegment,
    StoryChoice,
    InventoryItem,
    StoryState,
    Character
)
from backend.services.interactive_adventure_prompt_builder import InteractiveAdventurePromptBuilder
from backend.gemini_image_generator import GeminiImageGenerator
from backend.replicate_image_generator import ReplicateImageGenerator

logger = logging.getLogger(__name__)


class InteractiveAdventureService:
    """Service for creating and managing interactive adventure stories"""

    def __init__(self, gemini_api_key: Optional[str] = None):
        """Initialize with Gemini API key"""
        import os
        self.api_key = gemini_api_key or os.getenv('GEMINI_API_KEY')
        if not self.api_key:
            raise ValueError("GEMINI_API_KEY not set")

        genai.configure(api_key=self.api_key)

        # Use Gemini model with JSON mode support
        model_name = os.getenv('GEMINI_MODEL', 'gemini-2.0-flash-exp')
        logger.info(f"Initializing Interactive Adventure Service with model: {model_name}")
        self.model = genai.GenerativeModel(
            model_name,
            generation_config={"response_mime_type": "application/json"}
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
        fears_or_sensitivities: Optional[List[str]] = None
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

        Returns:
            Dict with story_id, segment data, inventory, and state
        """
        logger.info(f"Creating interactive story for user {user_id}, character {character_id}")

        # Load character if provided
        character = None
        child_name = "Hero"
        character_dict = None
        companions = []

        if character_id:
            character = Character.query.filter_by(id=character_id).first()
            if character:
                child_name = character.name
                character_age = character.age or age or 8
                character_dict = {
                    'name': character.name,
                    'age': character.age,
                    'gender': character.gender,
                    'personality_traits': character.personality_traits,
                    'strengths': character.strengths,
                    'fears': character.fears,
                    'comfort_item': character.comfort_item,
                    'likes': character.likes
                }

                # Get companions from character
                if character.pets:
                    for pet in character.pets:
                        companions.append({
                            'name': pet.get('name'),
                            'species': pet.get('species'),
                            'personality': pet.get('personality'),
                            'color': pet.get('color')
                        })

                if character.friends:
                    for friend in character.friends[:1]:  # Max 1 friend companion
                        companions.append({
                            'name': friend,
                            'role': 'friend'
                        })
            else:
                character_age = age or 8
        else:
            character_age = age or 8

        # Build opening prompt
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
            fears_or_sensitivities=fears_or_sensitivities
        )

        # Generate first segment
        segment_data = self._generate_segment_with_retry(prompt)

        # Create database records
        story = InteractiveStory(
            id=str(uuid.uuid4()),
            user_id=user_id,
            character_id=character_id,
            title=segment_data.get('title', f"{child_name}'s {theme} Adventure"),
            theme=theme,
            tone=tone,
            length=length,
            age=character_age,
            current_segment_number=1,
            is_completed=segment_data.get('is_ending', False)
        )
        db.session.add(story)
        db.session.flush()  # Get story.id

        # Create first segment
        segment = self._create_segment_record(
            story_id=story.id,
            segment_data=segment_data,
            segment_number=1,
            parent_choice_id=None
        )
        db.session.add(segment)
        db.session.flush()

        # Update story's current segment
        story.current_segment_id = segment.id

        # Create inventory items
        inventory_items = []
        for item_name in segment_data.get('inventory', []):
            item = InventoryItem(
                id=str(uuid.uuid4()),
                story_id=story.id,
                name=item_name,
                description=None,
                acquired_at_segment=1,
                is_active=True
            )
            inventory_items.append(item)
            db.session.add(item)

        # Create story state
        state_data = segment_data.get('story_state', {})
        state = StoryState(
            id=str(uuid.uuid4()),
            story_id=story.id,
            current_location=state_data.get('location'),
            current_goal=state_data.get('goal'),
            key_clues=state_data.get('key_clues', []),
            companion_status=state_data.get('companion_status'),
            time_pressure=state_data.get('time_pressure')
        )
        db.session.add(state)

        # Create choices
        for choice_data in segment_data.get('choices', []):
            # Parse choice number from prompt ID (e.g., "choice_1" -> 1)
            try:
                choice_num = int(choice_data.get('id', 'choice_1').split('_')[1])
            except (IndexError, ValueError):
                choice_num = 1 # Fallback

            choice = StoryChoice(
                id=str(uuid.uuid4()), # Always generate unique ID for DB
                segment_id=segment.id,
                choice_number=choice_num,
                text=choice_data.get('text'),
                consequence_type=None,
                is_selected=False
            )
            db.session.add(choice)

        db.session.commit()

        # Generate illustration for first segment
        # In MOCK_TESTING_MODE, this returns instantly (no API call, no cost)
        # Set MOCK_TESTING_MODE=false in .env to enable real image generation
        if segment_data.get('image_description'):
            self._generate_segment_illustration(segment, character_dict, companions, character_age)
            db.session.commit()

        logger.info(f"Created interactive story {story.id} with first segment")

        return {
            'story_id': story.id,
            'title': story.title,
            'segment': segment.to_dict(),
            'inventory': [item.to_dict() for item in inventory_items],
            'state': state.to_dict(),
            'is_completed': story.is_completed
        }

    def continue_story(self, story_id: str, choice_id: str) -> Dict[str, Any]:
        """
        Continue story based on user's choice selection.

        Args:
            story_id: ID of the interactive story
            choice_id: ID of the choice user selected

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
        current_inventory = [item.name for item in story.inventory.filter_by(is_active=True).all()]

        # Get current state
        current_state = story.state.to_dict() if story.state else {}

        # Build story summary
        story_so_far = self._build_story_summary(story)

        # Build continuation prompt
        prompt = InteractiveAdventurePromptBuilder.build_continuation_prompt(
            story_context=story_context,
            selected_choice=selected_choice_text,
            current_segment_number=story.current_segment_number,
            inventory=current_inventory,
            story_state=current_state,
            story_so_far=story_so_far
        )

        # Generate next segment
        segment_data = self._generate_segment_with_retry(prompt)

        next_segment_number = story.current_segment_number + 1

        # Create new segment
        new_segment = self._create_segment_record(
            story_id=story.id,
            segment_data=segment_data,
            segment_number=next_segment_number,
            parent_choice_id=choice_id
        )
        db.session.add(new_segment)
        db.session.flush()

        # Update story progress
        story.current_segment_id = new_segment.id
        story.current_segment_number = next_segment_number
        story.is_completed = segment_data.get('is_ending', False)
        story.updated_at = datetime.now(timezone.utc)

        # Update inventory
        new_inventory_names = segment_data.get('inventory', [])
        self._update_inventory(story, new_inventory_names, next_segment_number)

        # Update state
        new_state_data = segment_data.get('story_state', {})
        self._update_state(story, new_state_data)

        # Create choices for new segment (if not ending)
        if not segment_data.get('is_ending', False):
            for choice_data in segment_data.get('choices', []):
                # Parse choice number from prompt ID
                try:
                    choice_num = int(choice_data.get('id', 'choice_1').split('_')[1])
                except (IndexError, ValueError):
                    choice_num = 1

                new_choice = StoryChoice(
                    id=str(uuid.uuid4()), # Always generate unique ID for DB
                    segment_id=new_segment.id,
                    choice_number=choice_num,
                    text=choice_data.get('text'),
                    consequence_type=None,
                    is_selected=False
                )
                db.session.add(new_choice)

        db.session.commit()

        # Generate illustration for new segment
        # In MOCK_TESTING_MODE, this returns instantly (no API call, no cost)
        # Set MOCK_TESTING_MODE=false in .env to enable real image generation
        if segment_data.get('image_description'):
            character_dict = self._get_character_dict(story)
            companions = self._get_companions(story)
            self._generate_segment_illustration(new_segment, character_dict, companions, story.age)
            db.session.commit()

        logger.info(f"Story {story_id} continued to segment {next_segment_number}")

        return {
            'story_id': story.id,
            'segment': new_segment.to_dict(),
            'inventory': [item.to_dict() for item in story.inventory.filter_by(is_active=True).all()],
            'state': story.state.to_dict(),
            'is_completed': story.is_completed
        }

    def get_story(self, story_id: str) -> Dict[str, Any]:
        """Get full story with all segments"""
        story = InteractiveStory.query.filter_by(id=story_id).first()
        if not story:
            raise ValueError(f"Story {story_id} not found")

        return {
            **story.to_dict(),
            'segments': [seg.to_dict() for seg in story.segments.all()]
        }

    # Helper methods

    def _generate_segment_with_retry(self, prompt: str, max_retries: int = 3) -> Dict[str, Any]:
        """Generate segment with retry logic and JSON parsing"""
        base_delay = 1

        for attempt in range(max_retries):
            try:
                logger.info(f"Generating segment (attempt {attempt + 1}/{max_retries})")
                response = self.model.generate_content(prompt)

                if response and hasattr(response, 'text') and response.text:
                    # Parse JSON response
                    segment_data = json.loads(response.text)
                    logger.info("Segment generated successfully")
                    return segment_data
                elif response and hasattr(response, 'candidates') and response.candidates:
                    candidate = response.candidates[0]
                    if hasattr(candidate, 'content') and candidate.content.parts:
                        text = candidate.content.parts[0].text
                        segment_data = json.loads(text)
                        logger.info("Segment generated from candidates")
                        return segment_data

                logger.warning("No valid response from Gemini")
                if attempt < max_retries - 1:
                    continue

            except json.JSONDecodeError as e:
                logger.error(f"Failed to parse JSON response: {e}")
                if attempt < max_retries - 1:
                    import time
                    time.sleep(base_delay * (2 ** attempt))
                    continue

            except google_exceptions.ResourceExhausted as e:
                if attempt < max_retries - 1:
                    import time
                    delay = base_delay * (2 ** attempt)
                    logger.warning(f"Rate limit exceeded. Retrying in {delay}s...")
                    time.sleep(delay)
                else:
                    raise e

            except Exception as e:
                logger.error(f"Segment generation failed: {e}", exc_info=True)
                raise

        raise RuntimeError("Failed to generate segment after multiple retries")

    def _create_segment_record(
        self,
        story_id: str,
        segment_data: Dict,
        segment_number: int,
        parent_choice_id: Optional[str]
    ) -> StorySegment:
        """Create StorySegment database record"""
        content = segment_data.get('content', '')

        # Calculate word count if not provided
        word_count = segment_data.get('word_count')
        if not word_count and content:
            word_count = len(content.split())

        # Get output_type (defaults to CHOICE for backward compatibility)
        output_type = segment_data.get('output_type', 'CHOICE')

        return StorySegment(
            id=str(uuid.uuid4()),
            story_id=story_id,
            segment_number=segment_number,
            title=segment_data.get('title'),
            stage_label=segment_data.get('stage_label'),
            output_type=output_type,
            word_count=word_count,
            content=content,
            image_description=segment_data.get('image_description'),
            parent_choice_id=parent_choice_id
        )

    def _update_inventory(self, story: InteractiveStory, new_inventory: List[str], segment_number: int):
        """Update inventory based on new list"""
        current_items = {item.name: item for item in story.inventory.filter_by(is_active=True).all()}

        # Add new items
        for item_name in new_inventory:
            if item_name not in current_items:
                new_item = InventoryItem(
                    id=str(uuid.uuid4()),
                    story_id=story.id,
                    name=item_name,
                    acquired_at_segment=segment_number,
                    is_active=True
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
        state.current_location = new_state_data.get('location', state.current_location)
        state.current_goal = new_state_data.get('goal', state.current_goal)
        state.key_clues = new_state_data.get('key_clues', state.key_clues)
        state.companion_status = new_state_data.get('companion_status', state.companion_status)
        state.time_pressure = new_state_data.get('time_pressure', state.time_pressure)
        state.updated_at = datetime.now(timezone.utc)

    def _build_story_context(self, story: InteractiveStory) -> Dict[str, Any]:
        """Build story context for continuation"""
        character_dict = self._get_character_dict(story)

        return {
            'title': story.title,
            'theme': story.theme,
            'tone': story.tone,
            'length': story.length,
            'age': story.age,
            'character': character_dict,
            'companions': self._get_companions(story)
        }

    def _get_character_dict(self, story: InteractiveStory) -> Optional[Dict]:
        """Get character dictionary from story"""
        if not story.character:
            return None

        char = story.character
        return {
            'name': char.name,
            'age': char.age,
            'personality_traits': char.personality_traits,
            'strengths': char.strengths,
            'fears': char.fears
        }

    def _get_companions(self, story: InteractiveStory) -> List[Dict]:
        """Get companions list from character"""
        if not story.character:
            return []

        companions = []
        if story.character.pets:
            for pet in story.character.pets:
                companions.append({
                    'name': pet.get('name'),
                    'species': pet.get('species'),
                    'personality': pet.get('personality')
                })

        return companions

    def _build_story_summary(self, story: InteractiveStory) -> str:
        """Build summary of story so far"""
        segments = story.segments.order_by(StorySegment.segment_number).all()

        summary_parts = []
        for seg in segments:
            summary_parts.append(f"Segment {seg.segment_number}: {seg.content[:200]}...")

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
        age: int
    ):
        """Generate illustration for segment asynchronously"""
        try:
            if not segment.image_description:
                return

            character_name = character_dict.get('name', 'the hero') if character_dict else 'the hero'

            # Build character appearance from dict
            character_appearance = None
            if character_dict:
                # This would need to be expanded based on Character model fields
                character_appearance = {
                    'name': character_dict.get('name'),
                    'age': character_dict.get('age')
                }

            images = self.image_generator.generate_story_illustration(
                scene_description=segment.image_description,
                character_name=character_name,
                style="whimsical children's book illustration",
                num_images=1,
                age=age,
                character_appearance=character_appearance,
                companions=companions
            )

            if images and len(images) > 0:
                image_data = images[0].get('image_data')
                if image_data:
                    segment.image_url = f"data:image/png;base64,{image_data}"
                    logger.info(f"Generated illustration for segment {segment.id}")

        except Exception as e:
            logger.error(f"Failed to generate illustration for segment {segment.id}: {e}")
            # Don't fail the whole operation if illustration fails
