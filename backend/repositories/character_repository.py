from ..database import db
from ..models.character import Character

def add_character(character: Character):
    db.session.add(character)
    db.session.commit()

def get_all_characters():
    return Character.query.order_by(Character.created_at.desc()).all()

def get_characters_by_user(user_id: str):
    """Get all characters belonging to a specific user."""
    return Character.query.filter_by(user_id=user_id).order_by(Character.created_at.desc()).all()

def get_character_by_id(char_id: str):
    return db.session.get(Character, char_id)

def update_character(character: Character):
    db.session.commit()

def delete_character(character: Character):
    db.session.delete(character)
    db.session.commit()

def get_characters_by_ids(character_ids: list):
    return Character.query.filter(Character.id.in_(character_ids)).all()