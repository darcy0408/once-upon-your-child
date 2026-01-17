
import re

ALLOWED_STORY_LENGTHS = {'short', 'medium', 'long', 'standard'}

# Image validation constants
MAX_IMAGE_SIZE_BYTES = 10 * 1024 * 1024  # 10MB
MAX_IMAGE_DIMENSION = 4096  # Max width/height in pixels
MIN_IMAGE_DIMENSION = 64    # Min width/height in pixels

def validate_age(age):
    """
    Validate that age is an integer between 0 and 120.
    Returns the integer age.
    Raises ValueError if invalid.
    """
    try:
        age_int = int(age)
    except (TypeError, ValueError):
        raise ValueError("Age must be a valid integer.")
    
    if not (0 <= age_int <= 120):
        raise ValueError("Age must be between 0 and 120.")
        
    return age_int

def validate_story_length(length):
    """
    Validate story length is one of allowlisted values.
    Returns the valid length string.
    Raises ValueError if invalid.
    """
    if not length:
        return 'standard'
    
    if length not in ALLOWED_STORY_LENGTHS:
        raise ValueError(f"Invalid story length. Must be one of: {', '.join(ALLOWED_STORY_LENGTHS)}")
        
    return length

def sanitize_text(text, max_length=100, allow_newlines=False):
    """
    Sanitize text input:
    - Strip whitespace
    - Enforce max length
    - Remove potential HTML tags (basic check)
    """
    if not text:
        return ""
        
    s = str(text).strip()
    
    # Simple HTML tag stripping (naive but effective for basic script injection)
    # Allows benign text, blocks <script>...
    s = re.sub(r'<[^>]*>', '', s)
    
    if not allow_newlines:
        s = s.replace('\n', ' ').replace('\r', '')
        
    if len(s) > max_length:
        s = s[:max_length]

    return s


def validate_num_images(num_images, max_allowed=4):
    """
    Validate number of images requested.
    Returns clamped integer between 1 and max_allowed.
    """
    try:
        n = int(num_images)
    except (TypeError, ValueError):
        return 1

    if n < 1:
        return 1
    if n > max_allowed:
        return max_allowed
    return n


def validate_image_size(image_bytes, max_bytes=None):
    """
    Validate image size in bytes.
    Returns True if valid, raises ValueError if too large.
    """
    if max_bytes is None:
        max_bytes = MAX_IMAGE_SIZE_BYTES

    if not image_bytes:
        raise ValueError("Image data is empty")

    size = len(image_bytes)
    if size > max_bytes:
        max_mb = max_bytes / (1024 * 1024)
        actual_mb = size / (1024 * 1024)
        raise ValueError(f"Image size {actual_mb:.1f}MB exceeds maximum {max_mb:.1f}MB")

    return True


def validate_image_dimensions(width, height, max_dim=None, min_dim=None):
    """
    Validate image dimensions.
    Returns True if valid, raises ValueError if invalid.
    """
    if max_dim is None:
        max_dim = MAX_IMAGE_DIMENSION
    if min_dim is None:
        min_dim = MIN_IMAGE_DIMENSION

    if width < min_dim or height < min_dim:
        raise ValueError(f"Image dimensions {width}x{height} below minimum {min_dim}x{min_dim}")

    if width > max_dim or height > max_dim:
        raise ValueError(f"Image dimensions {width}x{height} exceed maximum {max_dim}x{max_dim}")

    return True
