try:
    from .story_generation_service import StoryGenerationService
    from .prompt_service import PromptService
    from .emotion_service import EmotionService
    from . import character_service
    from . import story_service
except ImportError:
    from services.story_generation_service import StoryGenerationService
    from services.prompt_service import PromptService
    from services.emotion_service import EmotionService
    import services.character_service as character_service
    import services.story_service as story_service