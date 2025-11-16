try:
    from .story_generation_service import StoryGenerationService
    from .prompt_service import PromptService
    from .emotion_service import EmotionService
except ImportError:
    from services.story_generation_service import StoryGenerationService
    from services.prompt_service import PromptService
    from services.emotion_service import EmotionService