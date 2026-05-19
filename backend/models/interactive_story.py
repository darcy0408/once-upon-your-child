"""
Interactive Adventure Story Models
Models for the new interactive story system with branching narratives,
inventory tracking, and persistent state management.
"""
import uuid
from datetime import datetime, timezone
from backend.database import db


class InteractiveStory(db.Model):
    """
    Main interactive story record with metadata and current progress.
    Supports age-calibrated adventures with branching choices.
    """
    __tablename__ = 'interactive_story'

    id = db.Column(db.String(36), primary_key=True, default=lambda: str(uuid.uuid4()))
    user_id = db.Column(db.String(36), db.ForeignKey('user.id'), nullable=False, index=True)
    character_id = db.Column(db.String(36), db.ForeignKey('character.id'), nullable=True, index=True)

    # Story metadata
    title = db.Column(db.String(200), nullable=False)
    theme = db.Column(db.String(100), nullable=False)  # Adventure, Magic, Dragons, etc.
    tone = db.Column(db.String(50), nullable=False)  # whimsical, mystery, sci-fi, fantasy, cozy-adventure
    length = db.Column(db.String(20), nullable=False)  # short, medium, long
    age = db.Column(db.Integer, nullable=False)  # Target age for content calibration
    world_bible = db.Column(db.Text, nullable=True)  # Rich world description for AI consistency

    # Progress tracking
    current_segment_id = db.Column(db.String(36), db.ForeignKey('story_segment.id', use_alter=True, name='fk_story_current_segment'), nullable=True)
    current_segment_number = db.Column(db.Integer, default=0, nullable=False)
    is_completed = db.Column(db.Boolean, default=False, nullable=False)

    # Timestamps
    created_at = db.Column(db.DateTime, default=lambda: datetime.now(timezone.utc), nullable=False, index=True)
    updated_at = db.Column(db.DateTime, default=lambda: datetime.now(timezone.utc), onupdate=lambda: datetime.now(timezone.utc), nullable=False)

    # Relationships
    segments = db.relationship('StorySegment', backref='story', lazy='dynamic',
                               foreign_keys='StorySegment.story_id',
                               cascade='all, delete-orphan',
                               order_by='StorySegment.segment_number')
    inventory = db.relationship('InventoryItem', backref='story', lazy='dynamic',
                                cascade='all, delete-orphan')
    state = db.relationship('StoryState', backref='story', uselist=False,
                           cascade='all, delete-orphan')

    # Relationship to User and Character
    user = db.relationship('User', backref='interactive_stories')
    character = db.relationship('Character', backref='interactive_stories')

    def to_dict(self):
        """Serialize to dictionary for API responses"""
        return {
            'id': self.id,
            'user_id': self.user_id,
            'character_id': self.character_id,
            'title': self.title,
            'theme': self.theme,
            'tone': self.tone,
            'length': self.length,
            'age': self.age,
            'current_segment_number': self.current_segment_number,
            'is_completed': self.is_completed,
            'created_at': self.created_at.isoformat() if self.created_at else None,
            'updated_at': self.updated_at.isoformat() if self.updated_at else None,
            'inventory': [item.to_dict() for item in self.inventory.filter_by(is_active=True).all()],
            'state': self.state.to_dict() if self.state else None
        }


class StorySegment(db.Model):
    """
    Individual story segment/chapter with narrative content and choices.
    Each segment represents a decision point in the branching story.
    """
    __tablename__ = 'story_segment'

    id = db.Column(db.String(36), primary_key=True, default=lambda: str(uuid.uuid4()))
    story_id = db.Column(db.String(36), db.ForeignKey('interactive_story.id'), nullable=False, index=True)

    # Segment metadata
    segment_number = db.Column(db.Integer, nullable=False)  # Sequential number (1, 2, 3...)
    title = db.Column(db.String(200), nullable=True)  # Optional segment title
    stage_label = db.Column(db.String(100), nullable=True)  # Kid-friendly stage label (e.g., "Play Time!")

    # Output type: CONTINUE (no choices, reader clicks continue) or CHOICE (decision point)
    output_type = db.Column(db.String(20), nullable=False, default='CHOICE')
    word_count = db.Column(db.Integer, nullable=True)  # Actual word count for pacing tracking

    # Content
    content = db.Column(db.Text, nullable=False)  # Story prose (now 350-650 words for immersion)
    image_description = db.Column(db.Text, nullable=True)  # Description for illustration generation
    image_url = db.Column(db.Text, nullable=True)  # Base64 data URI or URL

    # Navigation
    parent_choice_id = db.Column(db.String(36), db.ForeignKey('story_choice.id', use_alter=True, name='fk_segment_parent_choice'), nullable=True)

    # Timestamp
    created_at = db.Column(db.DateTime, default=lambda: datetime.now(timezone.utc), nullable=False)

    # Relationships
    choices = db.relationship('StoryChoice', backref='segment', lazy='dynamic',
                             foreign_keys='StoryChoice.segment_id',
                             cascade='all, delete-orphan',
                             order_by='StoryChoice.choice_number')

    def to_dict(self):
        """Serialize to dictionary for API responses"""
        return {
            'id': self.id,
            'segment_number': self.segment_number,
            'title': self.title,
            'stage_label': self.stage_label,
            'output_type': self.output_type,
            'word_count': self.word_count,
            'content': self.content,
            'image_description': self.image_description,
            'image_url': self.image_url,
            'choices': [choice.to_dict() for choice in self.choices.all()],
            'created_at': self.created_at.isoformat() if self.created_at else None
        }


class StoryChoice(db.Model):
    """
    Individual choice option presented to the user at a decision point.
    Tracks selection status and consequence type.
    """
    __tablename__ = 'story_choice'

    id = db.Column(db.String(36), primary_key=True, default=lambda: str(uuid.uuid4()))
    segment_id = db.Column(db.String(36), db.ForeignKey('story_segment.id'), nullable=False, index=True)

    # Choice metadata
    choice_number = db.Column(db.Integer, nullable=False)  # 1-4 depending on story length
    text = db.Column(db.String(500), nullable=False)  # The choice text displayed to user
    consequence_type = db.Column(db.String(100), nullable=True)  # location_change, item_gained, clue_found, etc.

    # Selection tracking
    is_selected = db.Column(db.Boolean, default=False, nullable=False, index=True)
    selected_at = db.Column(db.DateTime, nullable=True)

    def to_dict(self):
        """Serialize to dictionary for API responses"""
        return {
            'id': self.id,
            'choice_number': self.choice_number,
            'text': self.text,
            'consequence_type': self.consequence_type,
            'is_selected': self.is_selected,
            'selected_at': self.selected_at.isoformat() if self.selected_at else None
        }


class InventoryItem(db.Model):
    """
    Items collected by the hero during the adventure.
    Tracked persistently across story segments.
    """
    __tablename__ = 'inventory_item'

    id = db.Column(db.String(36), primary_key=True, default=lambda: str(uuid.uuid4()))
    story_id = db.Column(db.String(36), db.ForeignKey('interactive_story.id'), nullable=False, index=True)

    # Item details
    name = db.Column(db.String(100), nullable=False)
    description = db.Column(db.String(500), nullable=True)

    # Tracking
    acquired_at_segment = db.Column(db.Integer, nullable=False)
    is_active = db.Column(db.Boolean, default=True, nullable=False)  # Can be removed/used

    def to_dict(self):
        """Serialize to dictionary for API responses"""
        return {
            'id': self.id,
            'name': self.name,
            'description': self.description,
            'acquired_at_segment': self.acquired_at_segment,
            'is_active': self.is_active
        }


class StoryState(db.Model):
    """
    Current state of the adventure (location, goal, clues, companion status).
    Updated as the story progresses.
    """
    __tablename__ = 'story_state'

    id = db.Column(db.String(36), primary_key=True, default=lambda: str(uuid.uuid4()))
    story_id = db.Column(db.String(36), db.ForeignKey('interactive_story.id'),
                        nullable=False, unique=True, index=True)

    # Core state fields
    current_location = db.Column(db.String(200), nullable=True)
    current_goal = db.Column(db.String(500), nullable=True)
    key_clues = db.Column(db.JSON, default=list, nullable=False)  # List of clue strings
    companion_status = db.Column(db.String(200), nullable=True)
    time_pressure = db.Column(db.String(200), nullable=True)  # Optional urgency element

    # Flexible state storage for story-specific tracking
    additional_state = db.Column(db.JSON, default=dict, nullable=False)

    # Timestamp
    updated_at = db.Column(db.DateTime, default=lambda: datetime.now(timezone.utc), onupdate=lambda: datetime.now(timezone.utc), nullable=False)

    def to_dict(self):
        """Serialize to dictionary for API responses"""
        return {
            'current_location': self.current_location,
            'current_goal': self.current_goal,
            'key_clues': self.key_clues if self.key_clues else [],
            'companion_status': self.companion_status,
            'time_pressure': self.time_pressure,
            'additional_state': self.additional_state if self.additional_state else {},
            'updated_at': self.updated_at.isoformat() if self.updated_at else None
        }
