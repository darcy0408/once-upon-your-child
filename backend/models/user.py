from backend.database import db
from werkzeug.security import generate_password_hash, check_password_hash
import uuid
from datetime import datetime

class User(db.Model):
    id = db.Column(db.String(36), primary_key=True, default=lambda: str(uuid.uuid4()))
    username = db.Column(db.String(80), unique=True, nullable=False)
    email = db.Column(db.String(120), unique=True, nullable=False)
    password_hash = db.Column(db.String(200), nullable=False)
    created_at = db.Column(db.DateTime, default=datetime.utcnow)

    # Subscription details
    subscription_tier = db.Column(db.String(50), default='free', nullable=False)
    subscription_status = db.Column(db.String(50), default='active', nullable=False)
    current_period_end = db.Column(db.DateTime)
    cancel_at_period_end = db.Column(db.Boolean, default=False)
    stripe_customer_id = db.Column(db.String(255))

    # Relationships
    characters = db.relationship('Character', backref='user', lazy=True)
    progression_data = db.Column(db.JSON, default=dict)

    def set_password(self, password):
        self.password_hash = generate_password_hash(password)

    def check_password(self, password):
        return check_password_hash(self.password_hash, password)

    def to_dict(self):
        return {
            'id': self.id,
            'username': self.username,
            'email': self.email,
            'created_at': self.created_at.isoformat(),
            'subscription_tier': self.subscription_tier,
            'subscription_status': self.subscription_status,
            'current_period_end': self.current_period_end.isoformat() if self.current_period_end else None,
            'cancel_at_period_end': self.cancel_at_period_end,
            'stripe_customer_id': self.stripe_customer_id,
        }
