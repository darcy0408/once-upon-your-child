try:
    from . import character_repository
except ImportError:
    import repositories.character_repository as character_repository

__all__ = ['character_repository']
