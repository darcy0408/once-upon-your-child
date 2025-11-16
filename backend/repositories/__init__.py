try:
    from . import character_repository
except ImportError:
    import character_repository

__all__ = ['character_repository']
