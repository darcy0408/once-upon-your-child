from ..database import db
from datetime import datetime, timezone


class TherapistClient(db.Model):
    __tablename__ = 'therapist_clients'

    id = db.Column(db.Integer, primary_key=True)
    therapist_id = db.Column(db.String(100), db.ForeignKey('user.id'), nullable=False)
    child_user_id = db.Column(db.String(100), db.ForeignKey('user.id'), nullable=False)
    child_display_name = db.Column(db.String(100), nullable=True)
    therapeutic_goals = db.Column(db.JSON, default=list)
    notes = db.Column(db.Text, default='')
    created_at = db.Column(db.DateTime, default=lambda: datetime.now(timezone.utc))
    updated_at = db.Column(db.DateTime, default=lambda: datetime.now(timezone.utc),
                           onupdate=lambda: datetime.now(timezone.utc))

    __table_args__ = (
        db.UniqueConstraint('therapist_id', 'child_user_id', name='uq_therapist_child'),
    )

    def to_dict(self):
        return {
            'id': self.id,
            'therapist_id': self.therapist_id,
            'child_user_id': self.child_user_id,
            'child_display_name': self.child_display_name,
            'therapeutic_goals': self.therapeutic_goals or [],
            'notes': self.notes or '',
            'created_at': self.created_at.isoformat() if self.created_at else None,
        }
