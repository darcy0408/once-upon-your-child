import pytest
from app import app, db, Character
import uuid

@pytest.fixture
def test_app():
    app.config['TESTING'] = True
    app.config['SQLALCHEMY_DATABASE_URI'] = 'sqlite:///:memory:'
    with app.app_context():
        db.create_all()
        yield app
        db.drop_all()

def test_create_character_required_fields(test_app):
    """Test creating a character with only the required fields."""
    char_id = str(uuid.uuid4())
    char = Character(id=char_id, name='Test', age=10)
    db.session.add(char)
    db.session.commit()

    retrieved_char = db.session.get(Character, char_id)
    assert retrieved_char is not None
    assert retrieved_char.name == 'Test'
    assert retrieved_char.age == 10
    assert retrieved_char.id == char_id

def test_create_character_all_fields(test_app):
    """Test creating a character with all fields."""
    char_id = str(uuid.uuid4())
    char_data = {
        "id": char_id,
        "name": "Full Character",
        "age": 8,
        "gender": "Female",
        "role": "Adventurer",
        "magic_type": "Nature",
        "challenge": "Overcoming shyness",
        "character_type": "Everyday Kid",
        "superhero_name": "Mega Girl",
        "mission": "To protect the forest",
        "hair": "Brown",
        "eyes": "Green",
        "outfit": "A green tunic",
        "personality_traits": ["Brave", "Curious"],
        "siblings": ["A younger brother"],
        "friends": ["A talking squirrel"],
        "likes": ["Climbing trees"],
        "dislikes": ["Loud noises"],
        "fears": ["The dark"],
        "strengths": ["Kindness"],
        "goals": ["To map the entire forest"],
        "comfort_item": "A smooth stone"
    }
    char = Character(**char_data)
    db.session.add(char)
    db.session.commit()

    retrieved_char = db.session.get(Character, char_id)
    assert retrieved_char is not None
    for key, value in char_data.items():
        assert getattr(retrieved_char, key) == value

def test_character_to_dict(test_app):
    """Test the to_dict method of the Character model."""
    char_id = str(uuid.uuid4())
    char = Character(id=char_id, name='Dict Test', age=12)
    db.session.add(char)
    db.session.commit()

    retrieved_char = db.session.get(Character, char_id)
    char_dict = retrieved_char.to_dict()

    assert char_dict['id'] == char_id
    assert char_dict['name'] == 'Dict Test'
    assert char_dict['age'] == 12
    assert char_dict['created_at'] is not None
