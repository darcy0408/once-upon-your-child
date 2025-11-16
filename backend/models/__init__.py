try:
    from .models import db, Character
except ImportError:
    from models import db, Character
