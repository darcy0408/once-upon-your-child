import time
import random
import logging
from google.api_core import exceptions

logger = logging.getLogger("gemini_utils")

def generate_with_retry(model, prompt, max_retries=3, initial_delay=2, **kwargs):
    """
    Generates content using the Gemini model with exponential backoff retry.
    
    Args:
        model: The Gemini GenerativeModel instance.
        prompt: The prompt string.
        max_retries: Maximum number of retries.
        initial_delay: Initial delay in seconds.
        **kwargs: Additional arguments for model.generate_content.
        
    Returns:
        The generation response.
        
    Raises:
        Exception: If all retries fail.
    """
    delay = initial_delay
    
    for attempt in range(max_retries + 1):
        try:
            return model.generate_content(prompt, **kwargs)
        except exceptions.ResourceExhausted as e:
            if attempt == max_retries:
                logger.error(f"Gemini API ResourceExhausted: Max retries ({max_retries}) reached. Error: {e}")
                raise
            
            # Add jitter to avoid thundering herd
            sleep_time = delay + random.uniform(0, 1)
            logger.warning(f"Gemini API ResourceExhausted. Retrying in {sleep_time:.2f}s (Attempt {attempt + 1}/{max_retries})")
            time.sleep(sleep_time)
            delay *= 2  # Exponential backoff
            
        except exceptions.ServiceUnavailable as e:
            if attempt == max_retries:
                logger.error(f"Gemini API ServiceUnavailable: Max retries ({max_retries}) reached. Error: {e}")
                raise
                
            sleep_time = delay + random.uniform(0, 1)
            logger.warning(f"Gemini API ServiceUnavailable. Retrying in {sleep_time:.2f}s (Attempt {attempt + 1}/{max_retries})")
            time.sleep(sleep_time)
            delay *= 2
            
        except Exception as e:
            # Don't retry on other errors (like invalid argument) unless we are sure.
            # For now, let's assume other errors are fatal.
            logger.error(f"Gemini API Error (Non-retriable): {e}")
            raise
