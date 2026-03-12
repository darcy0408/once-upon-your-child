import pytest
import json
from unittest.mock import MagicMock, patch
import uuid
from datetime import datetime, timezone

from backend.services.interactive_adventure_service import InteractiveAdventureService
from backend.models import InteractiveStory, StorySegment, StoryChoice, Character, StoryState
from backend.database import db

@pytest.fixture
def mock_genai_client():
    with patch('google.genai.Client') as mock:
        client = MagicMock()
        mock.return_value = client
        yield client

@pytest.fixture
def interactive_service(mock_genai_client):
    with patch.dict('os.environ', {'GEMINI_API_KEY': 'test-key'}):
        service = InteractiveAdventureService()
        service.image_generator = MagicMock()
        return service

def test_create_story_success(app, interactive_service, test_user, test_character, mock_genai_client):
    """Test successful interactive story creation"""
    # Mock Gemini response
    mock_response = MagicMock()
    mock_response.text = json.dumps({
        'title': 'The Crystal Forest',
        'content': 'You stand at the edge of a shimmering forest.',
        'is_ending': False,
        'inventory': ['Magic Map'],
        'story_state': {
            'location': 'Forest Entrance',
            'goal': 'Find the Heart of the Woods',
            'key_clues': ['Whispering leaves'],
            'companion_status': 'Excited'
        },
        'choices': [
            {'id': 'choice_1', 'text': 'Enter the forest'},
            {'id': 'choice_2', 'text': 'Wait and watch'}
        ],
        'image_description': 'A beautiful shimmering forest with glowing trees'
    })
    mock_genai_client.models.generate_content.return_value = mock_response

    with app.app_context():
        db.session.merge(test_user)
        db.session.merge(test_character)
        db.session.commit()
        
        result = interactive_service.create_story(
            user_id=test_user.id,
            character_id=test_character.id,
            theme='Magic',
            tone='whimsical',
            length='short'
        )

        assert 'story_id' in result
        assert result['title'] == 'The Crystal Forest'
        
        # Cleanup story before test_user is deleted by fixture teardown
        story = db.session.get(InteractiveStory, result['story_id'])
        db.session.delete(story)
        db.session.commit()

def test_continue_story_success(app, interactive_service, test_user, test_character, mock_genai_client):
    """Test successful interactive story continuation"""
    with app.app_context():
        db.session.merge(test_user)
        db.session.merge(test_character)
        
        story = InteractiveStory(
            id=str(uuid.uuid4()),
            user_id=test_user.id,
            character_id=test_character.id,
            title='Test Adventure',
            theme='Adventure',
            tone='fantasy',
            length='short',
            age=7,
            current_segment_number=1
        )
        db.session.add(story)
        
        state = StoryState(
            id=str(uuid.uuid4()),
            story_id=story.id,
            current_location='Start',
            current_goal='Explore'
        )
        db.session.add(state)
        
        segment = StorySegment(
            id=str(uuid.uuid4()),
            story_id=story.id,
            segment_number=1,
            content='Beginning...'
        )
        db.session.add(segment)
        db.session.flush()
        
        choice = StoryChoice(
            id=str(uuid.uuid4()),
            segment_id=segment.id,
            choice_number=1,
            text='Next step'
        )
        db.session.add(choice)
        story.current_segment_id = segment.id
        db.session.commit()

        mock_response = MagicMock()
        mock_response.text = json.dumps({
            'content': 'You moved forward.',
            'is_ending': True,
            'inventory': ['Magic Map', 'Golden Key'],
            'story_state': {'location': 'Deep Cave', 'goal': 'Find exit'},
            'choices': []
        })
        mock_genai_client.models.generate_content.return_value = mock_response

        result = interactive_service.continue_story(story.id, choice.id)
        assert result['is_completed'] is True
        
        # Cleanup
        db.session.delete(story)
        db.session.commit()

def test_get_story_success(app, interactive_service, test_user):
    """Test retrieving a full story"""
    with app.app_context():
        db.session.merge(test_user)
        story_id = str(uuid.uuid4())
        story = InteractiveStory(
            id=story_id,
            user_id=test_user.id,
            title='Full Story',
            theme='Theme',
            tone='tone',
            length='short',
            age=5
        )
        db.session.add(story)
        db.session.commit()

        result = interactive_service.get_story(story_id)
        assert result['title'] == 'Full Story'
        
        # Cleanup
        db.session.delete(story)
        db.session.commit()

def test_continue_story_already_completed(app, interactive_service, test_user):
    """Test continuation of completed story"""
    with app.app_context():
        db.session.merge(test_user)
        story = InteractiveStory(
            id=str(uuid.uuid4()),
            user_id=test_user.id,
            is_completed=True,
            title='Done',
            theme='Done',
            tone='Done',
            length='short',
            age=10
        )
        db.session.add(story)
        db.session.commit()
        
        with pytest.raises(ValueError, match="Story .* is already completed"):
            interactive_service.continue_story(story.id, "any-choice")
            
        # Cleanup
        db.session.delete(story)
        db.session.commit()


def test_create_story_persists_big_feelings_context_in_state(
    app, interactive_service, test_user, test_character, mock_genai_client
):
    """Big Feelings interactive setup should be stored in story state for continuation prompts."""
    mock_response = MagicMock()
    mock_response.text = json.dumps({
        'title': 'Milo and the Big Breeze',
        'content': 'Milo felt so mad when someone said no.',
        'is_ending': False,
        'inventory': [],
        'story_state': {
            'location': 'Playroom',
            'goal': 'Feel better',
            'key_clues': ['hot face'],
            'companion_status': 'close by'
        },
        'choices': [
            {'id': 'choice_1', 'text': 'Take a dragon breath'},
            {'id': 'choice_2', 'text': 'Roar, then stop'}
        ],
        'image_description': 'A warm playroom with a child taking a calming breath'
    })
    mock_genai_client.models.generate_content.return_value = mock_response

    with app.app_context():
        db.session.merge(test_user)
        db.session.merge(test_character)
        db.session.commit()

        result = interactive_service.create_story(
            user_id=test_user.id,
            character_id=test_character.id,
            theme='Big Feelings',
            tone='whimsical',
            length='short',
            big_feelings_context={
                'current_feeling': {'emotion_name': 'Mad'},
                'trigger': 'someone said no',
                'body_signal': 'Hot face',
                'coping_tool': 'Take a dragon breath',
                'repair_goal': 'Help fix it',
            },
        )

        story = db.session.get(InteractiveStory, result['story_id'])
        assert story is not None
        assert story.state is not None
        assert story.state.additional_state['big_feelings_context']['trigger'] == 'someone said no'
        assert story.state.additional_state['big_feelings_context']['coping_tool'] == 'Take a dragon breath'

        db.session.delete(story)
        db.session.commit()
