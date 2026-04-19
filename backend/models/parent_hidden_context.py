from ..database import db


class ParentHiddenContext(db.Model):
    """Private parent-authored Big Feelings guidance stored per child profile."""

    __tablename__ = "parent_hidden_context"

    id = db.Column(db.Integer, primary_key=True)
    user_id = db.Column(db.String(36), db.ForeignKey("user.id"), nullable=False, index=True)
    child_profile_id = db.Column(db.String(64), nullable=False, index=True)
    feeling = db.Column(db.String(120), nullable=True)   # inferred by story engine
    trigger = db.Column(db.String(320), nullable=False)   # comma-separated, expanded for multi-select
    body_signal = db.Column(db.String(160), nullable=True)  # auto-selected by story engine
    coping_tool = db.Column(db.String(320), nullable=False)  # comma-separated union across triggers
    repair_goal = db.Column(db.String(320), nullable=False)  # comma-separated union across triggers
    created_at = db.Column(db.DateTime, default=db.func.now(), nullable=False)
    updated_at = db.Column(
        db.DateTime,
        default=db.func.now(),
        onupdate=db.func.now(),
        nullable=False,
    )

    __table_args__ = (
        db.UniqueConstraint(
            "user_id",
            "child_profile_id",
            name="uq_parent_hidden_context_user_profile",
        ),
    )

    def to_dict(self):
        return {
            "child_profile_id": self.child_profile_id,
            "feeling": self.feeling,
            "trigger": self.trigger,
            "body_signal": self.body_signal,
            "coping_tool": self.coping_tool,
            "repair_goal": self.repair_goal,
            "created_at": self.created_at.isoformat() if self.created_at else None,
            "updated_at": self.updated_at.isoformat() if self.updated_at else None,
        }
