from backend.models import Character
from backend.database import db

def get_all_characters():
    return Character.query.all()

def get_character_by_id(character_id):
    return Character.query.get(character_id)

def get_characters_by_ids(character_ids):
    return Character.query.filter(Character.id.in_(character_ids)).all()

def create_character(character_data):
    new_character = Character(**character_data)
    db.session.add(new_character)
    db.session.commit()
    return new_character

def update_character(character, character_data):
    for key, value in character_data.items():
        setattr(character, key, value)
    db.session.commit()
    return character

def delete_character(character):
    db.session.delete(character)
    db.session.commit()